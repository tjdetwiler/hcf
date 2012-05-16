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

class RegValue
  constructor: (asm, reg) ->
    @mAsm = asm
    @mReg = reg
  emit: (stream) -> []
  encode: () -> @mReg

class MemValue
  constructor: (asm, reg=undefined, lit=undefined) ->
    @mAsm = asm
    @mReg = reg
    @mLit = lit
    if @mLit? and @mLit > 0x1f then @mAsm.incPc()
  emit: (stream) -> if @mLit? then stream.push @mLit
  encode: () ->
    if @mLit? and @mReg?
      @mReg + 0x10
    else if @mReg?
      @mReg + 0x8
    else if @mLit?
      0x1e
    else
      console.log "ERROR: MemValue with corrupted state."

class LitValue
  constructor: (asm,lit) ->
    @mAsm = asm
    @mLit = lit
    if @mLit > 0x1f then @mAsm.incPc()
  emit: (stream) ->
    if @mLit > 0x1e
      stream.push @mLit
  encode: () ->
    if @mLit == 0xffff
      0x20
    else if @mLit > 0x1f
      0x1f
    else
      @mLit + 0x21

class SpecialValue
  constructor: (asm,enc) ->
    @mEnc = enc
  emit: () -> undefined
  encode: () -> @mEnc

class LabelValue
  constructor: (asm, lbl) ->
    @mAsm = asm
    @mLbl = lbl
    @mAsm.incPc()
  resolve: () ->
    addr = @mAsm.lookup @mLbl
    if not addr?
      console.log "Undefined label '#{@mLbl}'"
    addr
  emit: (stream) ->
    addr = @resolve()
    if not addr?
      return false
    stream.push addr
  encode: () ->
    addr = @resolve()
    if not addr?
      return false
    return 0x1f

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
    reg_regex = ///^([a-zA-Z_]+)$///
    ireg_regex = ///^\[\s*([a-zA-Z]+|\d+)\s*\]$///
    lit_regex = ///^(0[xX][0-9a-fA-F]+|\d+)$///
    ilit_regex = ///^\[\s*(0[xX][0-9a-fA-F]+|\d+)\s*\]$///
    arr_regex = ///^\[\s*(0[xX][0-9a-fA-F]+|\d+)\s*\+\s*([A-Z]+)\s*\]$///

    success = (val) ->
      result: "success"
      value: val

    if match = val.match reg_regex
      #
      # See if its a basic or special register. if not, assume label
      #
      switch match[1]
        when "POP"    then success new SpecialValue @, 0x18
        when "PEEK"   then success new SpecialValue @, 0x19
        when "PUSH"   then success new SpecialValue @, 0x1a
        when "SP"     then success new SpecialValue @, 0x1b
        when "PC"     then success new SpecialValue @, 0x1c
        when "O"      then success new SpecialValue @, 0x1d
        else
          regid = dasm.Disasm.REG_DISASM.indexOf match[1]
          if regid == -1
            return success new LabelValue @, match[1]
          else
            return success new RegValue @, regid
    else if match = val.match ireg_regex
      regid = dasm.Disasm.REG_DISASM.indexOf match[1]
      return success (new MemValue @, regid, undefined)
    else if match = val.match lit_regex
      return success new LitValue @, parseInt match[1]
    else if match = val.match ilit_regex
      n = parseInt match[1]
      return success (new MemValue @, undefined, n)
    else if match = val.match arr_regex
      n = parseInt match[1]
      r = dasm.Disasm.REG_DISASM.indexOf match[2]
      return success new MemValue @, r, n
    else
      return r =
        result: "fail"
        message: "Unmatched value #{val}"

  processLine: (line) ->
    line = line.trim().toUpperCase()
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
    #
    # Either:
    #   > Label
    #   > Instruction
    #   > Directive?
    #
    toks = line.match /[^ \t]+/g
    if line[0] is ":"
      # Label
      @label toks[0][1..], @mPc
      # Process rest of line
      return @processLine (toks[1..].join " ")
    else if line[0] is ";"
      # Comment
      return r = 
        result: "success"
    else if toks[0] == "DAT"
      n = parseInt toks[1]
      # TODO: Multiple words?
      # TODO: Verify n
      @mInstrs.push(new Data @, n)
      return r = 
        result: "success"
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

  emit: (stream) -> i.emit stream for i in @mInstrs

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
