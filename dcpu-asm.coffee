#
# dcpu-asm.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# DCPU-16 Assembler
#

Module = {}

dasm = require './dcpu-disasm'

class Value
  emit: () -> undefined

class RegValue extends Value
  constructor: (asm, reg) -> 
    @mAsm = asm
    @mReg = reg
  emit: (stream) -> []
  encode: () -> @mReg

class MemValue extends Value
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

class LitValue extends Value
  constructor: (asm,lit) -> 
    @mAsm = asm
    @mLit = lit
    if @mLit > 0x1f then @mAsm.incPc()
  emit: (stream) ->
    if @mLit > 0x1f
      stream.push @mLit
  encode: () ->
    if @mLit > 0x1f
      0x1f
    else
      @mLit + 0x20

class SpecialValue extends Value
  constructor: (asm,enc) ->
    @mEnc = enc
  encode: () -> @mEnc

class LabelValue extends Value
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

class Instruction
  constructor: (asm, opc, vals) ->
    @mAsm = asm
    @mLine = 0
    @mSize = 0
    @mOp = opc
    @mVals = vals

  emit: (stream) ->
    if @mOp is dasm.Disasm.OPC_ADV
      # TODO Adanced opcode
      ""
    enc = (v.encode() for v in @mVals)
    instr = @mOp | (enc[0] << 4) | (enc[1] << 10)
    stream.push instr
    v.emit stream for v in @mVals

class Assembler
  constructor: () ->
    @mText = ""
    @mLabels = {}
    @mPc = 0
    @mInstrs = []

  label: (name, addr) -> @mLabels[name] = addr
  lookup: (name) -> @mLabels[name]
  defined: (name) -> lookup(name)?

  isNumber: (tok) -> 
    tok.match ///0[xX][0-9a-zA-Z]+/// or tok.match ///[0-9]+///
  isReg: (tok) -> tok.trim() in dasm.Disasm.REG_DISASM

  incPc: () -> ++@mPc

  processMemOp: (tok) ->
    if isNumber tok
      # Literal memop
      # Determine if it can fit in the instr or not
      ""
    else if isReg tok
      # reg offset
      ""

  processValue: (val) ->
    val = val.trim()
    reg_regex = ///^([a-zA-Z]+)$///
    ireg_regex = ///^\[([a-zA-Z]+|\d+)\]$///
    lit_regex = ///^(0[xX][0-9a-fA-F]+|\d+)$///
    ilit_regex = ///^\[(0[xX][0-9a-fA-F]+|\d+)\]$///
    arr_regex = ///^\[(0[xX][0-9a-fA-F]+|\d+)\+([A-Z]+)\]$///

    if match = val.match reg_regex
      #
      # See if its a basic or special register. if not, assume label
      #
      switch match[1]
        when "PC" then new SpecialValue @, 0x1c
        when "SP" then new SpecialValue @, 0x1b
        when "O" then  new SpecialValue @, 0x1d
        else
          regid = dasm.Disasm.REG_DISASM.indexOf match[1]
          if regid == -1
            new LabelValue @, match[1]
          else
            new RegValue @, regid
    else if match = val.match ireg_regex
      regid = dasm.Disasm.REG_DISASM.indexOf match[1]
      new MemValue @, regid, undefined
    else if match = val.match lit_regex
      new LitValue @, parseInt match[1]
    else if match = val.match ilit_regex
      n = parseInt match[1]
      new MemValue @, undefined, n
    else if match = val.match arr_regex
      n = parseInt match[1]
      r = dasm.Disasm.REG_DISASM.indexOf match[2]
      new MemValue @, r, n
    else
      console.log "Unmatched value #{val}"
      process.exit(1)

  processLine: (line) ->
    line = line.trim().toUpperCase()
    if line is "" then return

    basic_regex = ///
      (\w+)\x20       #Opcode
      ( 
        [^,]+         #ValA
      ),(             #ValB    
        [^,]+
    )///
    #
    # Either:
    #   > Label
    #   > Instruction
    #   > Directive?
    #
    if line[0] is ":"
      # Label
      toks = line.split " "
      @label toks[0][1..], @mPc
    else if line[0] is ";"
      # Comment
      return
    else if match = line.match basic_regex
      # Basic Opcode
      [opc, valA, valB] = match[1..3]
      if opc not in dasm.Disasm.OPC_DISASM
        console.log "ERROR: Unknown OpCode: #{opc}"
        return false
      enc = dasm.Disasm.OPC_DISASM.indexOf opc
      @incPc()
      valA = @processValue valA
      valB = @processValue valB
      @mInstrs.push new Instruction @,enc, [valA, valB]
    else
      console.log "Syntax Error"
      console.log line

  emit: (stream) -> i.emit stream for i in @mInstrs
  assemble: (text) ->
    lines = text.split "\n"
    @processLine l for l in lines

    prog = []
    @emit prog
    prog

exports.Assembler = Assembler
