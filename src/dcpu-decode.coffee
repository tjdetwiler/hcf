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

class Value
  #
  # Register Indicies
  #
  [@REG_A, @REG_B, @REG_C, @REG_X,  @REG_Y,
   @REG_Z, @REG_I, @REG_J, @REG_PC, @REG_SP,
   @REG_O] = [0x0..0xa]

  constructor: (cpu, enc) ->
    @mCpu = cpu
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
      @mValue = @mCpu.readReg enc - 0x08
    else if 0x10 <= enc <= 0x17
      @isMem = true
      @mNext = @mCpu.nextWord()
      @mValue = @mNext + @mCpu.readReg enc - 0x10
    else if enc == 0x18
      @isMem = true
      @mValue = @mCpu.pop()
    else if enc == 0x19
      @isMem = true
      @mValue = @mCpu.peek()
    else if enc == 0x1a
      @isMem = true
      @mValue = @mCpu.push()
    else if enc == 0x1b
      @isReg = true
      @mValue = Value.REG_SP
    else if enc == 0x1c
      @isReg = true
      @mValue = Value.REG_PC
    else if enc == 0x1d
      @isReg = true
      @mValue = Value.REG_O
    else if enc == 0x1e
      @isMem = true
      @mNext = @mCpu.nextWord()
      @mValue = @mNext
    else if enc == 0x1f
      @mNext = @mCpu.nextWord()
      @mValue = @mNext
    else if 0x20 <= enc <= 0x3f
      @mValue = enc - 0x20

  get: () ->
    if @isMem
      @mCpu.readMem @mValue
    else if @isReg
      @mCpu.readReg @mValue
    else
      @mValue
    
  set: (val) ->
    if @isMem
      @mCpu.writeMem @mValue, val
    else if @isReg
      @mCpu.writeReg @mValue, val
    else
      # error
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

  constructor: (cpu, enc) ->
    @mCpu = cpu
    [@mOpc, @mValA, @mValB] = @decode enc

  decode: (instr) ->
    opcode = instr & @OPCODE_MASK()
    valA   = (instr & @VALA_MASK()) >> 4
    valB   = (instr & @VALB_MASK()) >> 10
    [opcode, new Value(@mCpu,valA), new Value(@mCpu,valB)]

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
