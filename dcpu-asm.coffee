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
    console.log "Lit #{lit}"
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
  emit: (stream) ->
    if @mLit > 0x1f
      stream.push @mLit
  encode: () ->
    if @mLit > 0x1f
      0x1f
    else
      lit + 0x20

class LabelValue extends Value
  constructor: (asm, lbl) ->
    @mAsm = asm
    @mLbl = lbl
  resolve: () ->
    addr = @mAsm.lookup @mLbl
    if not addr?
      console.log "Undefined label '#{@mLbl}'"
    addr
  emit: (stream) ->
    addr = resolve()
    if not addr?
      return false
    stream.push addr
  encode: () ->
    addr = resolve()
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
    console.log @mVals
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
    reg_regex = ///(^[a-zA-Z]+$)///
    ireg_regex = ///\[[a-zA-Z]+\]///
    lit_regex = ///^(0[xX][0-9a-fA-F]+|\d+)$///
    ilit_regex = ///\[(0[xX][0-9a-fA-F]+|\d+)\]///
    arr_regex = ///\[(0[xX][0-9a-fA-F]+|\d+)\+(\w+)\]///

    if match = val.match reg_regex
      regid = dasm.Disasm.REG_DISASM.indexOf match[1]
      new RegValue @, regid
    else if match = val.match ireg_regex
      console.log "Found ireg"
    else if match = val.match lit_regex
      console.log "Found lit"
      new LitValue @, parseInt match[1]
    else if match = val.match ilit_regex
      console.log "Found ilit"
      n = parseInt match[1]
      console.log "ILIT: #{n}"
      new MemValue @, undefined, n
    else if match = val.match arr_regex
      console.log "Found arr"

  processLine: (line) ->
    console.log "Assembling #{line}"
    line = line.trim().toUpperCase()

    basic_regex = ///
      (\w+)\x20       #Opcode
      (               #ValA
        \w+ 
      | \[\w+\]
      | \[\d+\+\w\]
      | \[\d+\] 
      | \d+
      ),(             #ValB    
        \w+
      | \[\w+\]
      | \[\d+\+\w\]
      | \[\d+\]
      | \d+
    )///
    adv_regex = ///
      (\w+)\x20       #Opcode
      (               #ValA
        \w+ 
      | \[\w+\]
      | \[\d+\+\w\]
      | \[\d+\] 
      | \d+
    )///
    #
    # Either:
    #   > Label
    #   > Instruction
    #   > Directive?
    #
    if line[0] is ":"
      # Label
      label toks[1..], @mPc
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

  emit: (stream) -> i.emit stream for i in @mInstrs
  assemble: (text) ->
    lines = text.split "\n"
    console.log lines
    @processLine l for l in lines

    prog = []
    @emit prog
    for w in prog
      console.log dasm.Disasm.fmtHex w
    prog

exports.Assembler = Assembler
