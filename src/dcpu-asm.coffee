#
# dcpu-asm.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# DCPU-16 Assembler
#

Module = {}

decode = require './dcpu-decode'
dasm = require './dcpu-disasm'

Instr = decode.Instr

#
# Class to handle register values.
#
class RegValue
  constructor: (asm, reg) ->
    @mAsm = asm
    @mReg = reg
  emit: (stream) -> []
  encode: () -> @mReg

class MemValue
  #
  # Class to handle all memory values:
  # [register]
  # [register+next word]
  # [next word]
  #
  # To specify a register, pass the Register ID to the ctor.
  # To specify a literal value (next word), pass a LitValue
  # object to the ctor.
  #
  constructor: (asm, reg=undefined, lit=undefined) ->
    @mAsm = asm
    @mReg = reg
    @mLit = lit
  emit: (stream) ->
    if not @mLit? then return
    if @mLit? then stream.push @mLit.value()
  encode: () ->
    if @mLit? and @mReg? and not @mLit.isLabel()
      @mReg + 0x10
    else if @mReg?
      @mReg + 0x8
    else if @mLit?
      0x1e
    else
      console.log "ERROR: MemValue with corrupted state."

#
# Class to handle literal values.
#
# Pass a numeric literal, or a string defining a label to the
# ctor.
#
class LitValue
  constructor: (asm,lit) ->
    @mAsm = asm
    @mLit = lit

    if (n = parseInt lit) then @mLit = n
    if @mLit > 0x1f or @isLabel() then @mAsm.incPc()

  isLabel: () -> isNaN @mLit

  value: () ->
    if @isLabel()
      addr = @mAsm.lookup @mLit
      if not addr?
        console.log "Undefined label '#{@mLit}'"
      return addr
    else
      return @mLit

  emit: (stream) ->
    if @mLit > 0x1e or @isLabel()
      stream.push @value()

  encode: () ->
    if @mLit == -1
      0x20
    else if @mLit > 0x1f or @isLabel()
      0x1f
    else
      @mLit + 0x21

class RawValue
  constructor: (asm, raw) ->
    @mAsm = asm
    @mRaw = raw
  emit: () -> undefined
  encode: () -> @mRaw

class Instruction
  constructor: (asm, opc, vals) ->
    @mAsm = asm
    @mLine = 0
    @mSize = 0
    @mOp = opc
    @mVals = vals

  emit: (stream) ->
    enc = (v.encode() for v in @mVals)
    instr = @mOp | (enc[0] << 5) | (enc[1] << 10)
    stream.push instr
    v.emit stream for v in @mVals

class Data
  constructor: (asm, dat) ->
    @mAsm = asm
    @mData = dat

  emit: (stream) -> stream.push @mData

class Assembler
  constructor: () ->
    @mText = ""
    @mLabels = {}
    @mPc = 0
    @mInstrs = []
    @mOpcDict = {}
    for op in Instr.BASIC_OPS
      if op? then @mOpcDict[op.id.toUpperCase()] = op
    for op in Instr.ADV_OPS
      if op? then @mOpcDict[op.id.toUpperCase()] = op

  label: (name, addr) -> @mLabels[name] = addr
  lookup: (name) -> @mLabels[name]
  defined: (name) -> lookup(name)?

  incPc: () -> ++@mPc

  processValue: (val) ->
    val = val.trim()
    reg_regex = ///^([a-zA-Z_]+)///
    ireg_regex = ///^\[\s*([a-zA-Z]+|\d+)\s*\]///
    lit_regex = ///^(0[xX][0-9a-fA-F]+|\d+)///
    ilit_regex = ///^\[\s*(0[xX][0-9a-fA-F]+|\d+)\s*\]///
    arr_regex = ///^
      \[\s*
        ([0-9a-zA-Z]+)\s*\+\s*([0-9a-zA-Z]+) # [alphanum + alphanum]
      \s*\]///

    success = (val) ->
      result: "success"
      value: val

    if match = val.match reg_regex
      #
      # See if its a basic or special register. if not, assume label
      #
      switch match[1]
        when "POP"    then success new RawValue @, 0x18
        when "PEEK"   then success new RawValue @, 0x19
        when "PUSH"   then success new RawValue @, 0x1a
        when "SP"     then success new RawValue @, 0x1b
        when "PC"     then success new RawValue @, 0x1c
        when "O"      then success new RawValue @, 0x1d
        else
          regid = dasm.Disasm.REG_DISASM.indexOf match[1]
          if regid == -1
            return success new LitValue(@, match[1])
          else
            return success new RegValue @, regid
    else if match = val.match ireg_regex
      regid = dasm.Disasm.REG_DISASM.indexOf match[1]
      if regid == -1
        return success new MemValue(@, undefined, new LitValue(@, match[1]))
      else
        return success new MemValue(@, regid, undefined)
    else if match = val.match lit_regex
      return success new LitValue @, parseInt match[1]
    else if match = val.match ilit_regex
      n = parseInt match[1]
      return success (new MemValue @, undefined, new LitValue(@, n))
    else if match = val.match arr_regex
      if (r = dasm.Disasm.REG_DISASM.indexOf match[2]) != -1
        return success new MemValue @, r, new LitValue(@, match[1])
      if (r = dasm.Disasm.REG_DISASM.indexOf match[1]) != -1
        return success new MemValue @, r, new LitValue(@, match[2])
      else
        console.log "match[1]: #{match[1]}"
        console.log "match[2]: #{match[2]}"
        undefined.crash()
        return {result: "fail", message: "Unmatched value #{val}"}
      return success new MemValue @, r, new LitValue(@, n)
    else
      return r =
        result: "fail"
        message: "Unmatched value #{val}"

  processLine: (line) ->
    # input is the raw, untransformed string
    # line is everything uppercase, before the first semicolon
    input = line.trim()
    line = line.split(";")[0].toUpperCase().trim()
    if line is ""
      return r =
        result: "success"

    basic_regex = ///
      (\w+)\s+        #Opcode
      (
        [^,]+         #ValA
      )\s*,\s*(       #ValB
        [^,]+
    )///
    adv_regex = ///
      (\w+)\s+      #Opcode
      (
        [^,]+         #ValA
    )///
    str_regex = ///"([^"]*)"///
    #
    # Either:
    #   > Label
    #   > Instruction
    #   > Directive?
    #
    toks = line.match /[^ \t]+/g
    if input[0] is ":"
      toks = (input.match /[^ \t]+/g)
      @label toks[0][1..].toUpperCase(), @mPc
      # Process rest of line
      return @processLine (toks[1..].join " ")
    else if line[0] is ";"
      # Comment
      return {result: "success"}
    else if toks[0] == "DAT"
      toks = input.match(/[^ \t]+/g)[1..].join(" ").split(",")
      for tok in toks
        tok = tok.trim()
        if tok[0] is ";" then break
        if match = tok.match str_regex
          for c in match[1]
            @mInstrs.push(new Data @, c.charCodeAt(0))
        else if (n = parseInt tok)?
          @mInstrs.push(new Data @, n)
        else
          console.log "Bad Data String: '#{tok}'"
      return {result: "success"}
    else if match = line.match basic_regex
      # Basic Opcode
      [opc, valA, valB] = match[1..3]
      if not @mOpcDict[opc]?
        return r =
          result: "fail"
          message: "Unknown Opcode: #{opc}"

      enc = @mOpcDict[opc].op
      @incPc()
      valA = @processValue valA
      if valA.result isnt "success" then return valA
      valB = @processValue valB
      if valB.result isnt "success" then return valB
      @mInstrs.push new Instruction @,enc, [valA.value, valB.value]
      return r = 
        result: "success"
    else if match = line.match adv_regex
      [opc, valA] = match[1..2]
      if not @mOpcDict[opc]?
        return r =
          result: "fail"
          message: "Unknown Opcode: #{opc}"
      enc = @mOpcDict[opc].op
      @incPc()
      valB = @processValue valA
      if valB.result isnt "success" then return valB
      valA = new RawValue @, enc
      @mInstrs.push new Instruction @, 0, [valA,valB.value]
      return r =
        result: "success"
    else
      return r =
        result: "fail"
        source: line
        message: "Syntax Error"

  emit: (stream) ->
    for i in @mInstrs
      i.emit stream 

  assemble: (text) ->
    prog = []
    lines = text.split "\n"
    index = 1
    for l in lines
      state = @processLine l
      if state.result isnt "success"
        state.line = index
        return state
      index++
    @emit prog
    return r =
      result: "success"
      code: prog

exports.Assembler = Assembler
