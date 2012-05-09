#
# dcpu-decode.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# DCPU-16 Decode Logic
#
# In order to make this suitable for web-deployment, this file should not
# rely on any node.js library functions.
#
Module = {}

class IStream
  constructor: (instrs, base=0) ->
    @mStream = instrs
    @mDecoded = []
    @mIndex = base

  nextWord: () -> @mStream[@mIndex++]
  index: (v=0) -> if v then @mIndex=v else @mIndex

class Value
  #
  # Register Indicies
  #
  [@REG_A, @REG_B, @REG_C, @REG_X,  @REG_Y,
   @REG_Z, @REG_I, @REG_J, @REG_PC, @REG_SP,
   @REG_O] = [0x0..0xa]

  [@VAL_POP, @VAL_PEEK, @VAL_PUSH] = [0x18..0x1a]
  [@VAL_SP, @VAL_PC, @VAL_O] = [0x1b..0x1d]

  constructor: (stream, enc) ->
    @mIStream = stream
    @isMem = false
    @isReg = false
    @mEncoding = enc
    @mNext=0

    #
    # Decode Value
    #
    if 0x00 <= enc <= 0x07
      @isReg = true
      @mValue = enc
    else if 0x08 <= enc <= 0x0f
      @isMem = true
    else if 0x10 <= enc <= 0x17
      @isMem = true
      @mNext = @mIStream.nextWord()
    else if enc == Value.VAL_POP
      ""
    else if enc == Value.VAL_PEEK
      ""
    else if enc == Value.VAL_PUSH
      ""
    else if enc == Value.VAL_SP
      @isReg = true
      @mValue = Value.REG_SP
    else if enc == Value.VAL_PC
      @isReg = true
      @mValue = Value.REG_PC
    else if enc == Value.VAL_O
      @isReg = true
      @mValue = Value.REG_O
    else if enc == 0x1e
      @isMem = true
      @mNext = @mIStream.nextWord()
      @mValue = @mNext
    else if enc == 0x1f
      @mNext = @mIStream.nextWord()
      @mValue = @mNext
    else if 0x20 <= enc <= 0x3f
      @mValue = enc - 0x20

  get: (cpu) ->
    if @isMem
      cpu.readMem @mValue
    else if @isReg
      cpu.readReg @mValue
    else if @mEncoding is Value.VAL_POP
      cpu.pop()
    else if @mEncoding is Value.VAL_PUSH
      console.log "ERROR: Trying to 'get' PUSH"
    else if @mEncoding is Value.VAL_PEEK
      cpu.peek()
    else
      @mValue
    
  set: (cpu,val) ->
    if @isMem
      cpu.writeMem @mValue, val
    else if @isReg
      cpu.writeReg @mValue, val
    else if @mEncoding is Value.VAL_POP
      console.log "ERROR: Trying to 'set' POP"
    else if @mEncoding is Value.VAL_PUSH
      cpu.push val
    else if @mEncoding is Value.VAL_PEEK
      console.log "ERROR: Trying to 'set' PEEK"
    else
      console.log "Error: Attempt to 'set' a literal value"

  raw: () -> @mEncoding


class Instr
  #
  # Opcodes
  #
  [@OPC_ADV, @OPC_SET, @OPC_ADD, @OPC_SUB,
   @OPC_MUL, @OPC_DIV, @OPC_MOD, @OPC_SHL,
   @OPC_SHR, @OPC_AND, @OPC_BOR, @OPC_XOR,
   @OPC_IFE, @OPC_IFN, @OPC_IFG, @OPC_IFB] = [0x0..0xf]

  #
  # Advanced Opcodes
  #
  [@ADV_RSV, @ADV_JSR] = [0..1]

  constructor: (stream) ->
    @mIStream = stream
    [@mOpc, @mValA, @mValB] = @decode @mIStream.nextWord()

  decode: (instr) ->
    opcode = instr & @OPCODE_MASK()
    valA   = (instr & @VALA_MASK()) >> 4
    valB   = (instr & @VALB_MASK()) >> 10
    [opcode, new Value(@mIStream,valA), new Value(@mIStream,valB)]

  opc:  () -> @mOpc
  valA: () -> @mValA
  valB: () -> @mValB

  #
  # Constants... there's probably (hopefully?) a better way to do this.
  #
  OPCODE_MASK: () -> 0x000f
  VALA_MASK  : () -> 0x03f0
  VALB_MASK  : () -> 0xfc00


exports.Value = Value
exports.Instr = Instr
exports.IStream = IStream
