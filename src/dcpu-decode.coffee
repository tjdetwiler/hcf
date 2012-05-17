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
  index: (v) -> if v? then @mIndex=v else @mIndex
  setPC: (v) -> index v
  getPC: ( ) -> index()

class Value
  #
  # Register Indicies
  #
  [@REG_A, @REG_B, @REG_C, @REG_X,  @REG_Y,
   @REG_Z, @REG_I, @REG_J, @REG_PC, @REG_SP,
   @REG_EX, @REG_IA] = [0x0..0xb]

  @VAL_POP  = 0x18
  @VAL_PUSH = 0x18
  @VAL_PEEK = 0x19
  @VAL_PICK = 0x1a
  @VAL_SP   = 0x1b
  @VAL_PC   = 0x1c
  @VAL_EX   = 0x1d

  constructor: (stream, enc, raw=false) ->
    @mIStream = stream
    @isMem = false
    @isReg = false
    @mEncoding = enc
    @mNext=undefined

    if raw
      @mValue = enc
      return

    #
    # Decode Value
    #
    if 0x00 <= enc <= 0x07
      @isReg = true
      @mValue = enc
    else if 0x08 <= enc <= 0x0f
      @isMem = true
      @isReg = true
      @mValue = enc - 0x08
    else if 0x10 <= enc <= 0x17
      @isMem = true
      @isReg = true
      @mNext = @mIStream.nextWord()
      @mValue = enc - 0x10
    else if enc == Value.VAL_POP
      ""
    else if enc == Value.VAL_PEEK
      ""
    else if enc == Value.VAL_PICK
      @mNext = @mIStream.nextWord()
    else if enc == Value.VAL_SP
      @isReg = true
      @mValue = Value.REG_SP
    else if enc == Value.VAL_PC
      @isReg = true
      @mValue = Value.REG_PC
    else if enc == Value.VAL_EX
      @isReg = true
      @mValue = Value.REG_EX
    else if enc == 0x1e
      @isMem = true
      @mNext = @mIStream.nextWord()
      @mValue = @mNext
    else if enc == 0x1f
      @mNext = @mIStream.nextWord()
      @mValue = @mNext
    else if 0x20 <= enc <= 0x3f
      if enc
        @mValue = enc - 0x21
      else
        @mValue = 0xffff

  get: (cpu) ->
    if @isMem and @isReg and @mNext?
      addr = @mNext
      addr += cpu.readReg @mValue
      cpu.readMem addr
    else if @isMem and @isReg
      addr = cpu.readReg @mValue
      cpu.readMem addr
    else if @isMem
      cpu.readMem @mValue
    else if @isReg
      cpu.readReg @mValue
    else if @mEncoding is Value.VAL_POP
      cpu.pop()
    else if @mEncoding is Value.VAL_PEEK
      cpu.peek()
    else if @mEncoding is Value.VAL_PICK
      sp = cpu.regSP()
      addr = sp + @mNext
      cpu.readMem addr
    else
      @mValue
    
  set: (cpu,val) ->
    if @isMem and @isReg and @mNext?
      addr = @mNext
      addr += cpu.readReg @mValue
      cpu.writeMem addr, val
    else if @isMem and @isReg
      addr = cpu.readReg @mValue
      cpu.writeMem addr, val
    else if @isMem
      cpu.writeMem @mValue, val
    else if @isReg
      cpu.writeReg @mValue, val
    else if @mEncoding is Value.VAL_PUSH
      cpu.push val
    else if @mEncoding is Value.VAL_PEEK
      console.log "ERROR: Trying to 'set' PEEK"
    else if @mEncoding is Value.VAL_PICK
      sp = cpu.regSP()
      addr = sp + @mNext
      cpu.writeMem addr, val
    else
      console.log "Error: Attempt to 'set' a literal value"

  raw: () -> @mEncoding


class Instr
  #
  # Opcodes
  #
  @BASIC_OPS =[ @OPC_ADV = {op: 0x00, id: "adv", cost: 0, cond: false},
    @OPC_SET = {op: 0x01, id: "set", cost: 1, cond: false},
    @OPC_ADD = {op: 0x02, id: "add", cost: 2, cond: false},
    @OPC_SUB = {op: 0x03, id: "sub", cost: 2, cond: false},
    @OPC_MUL = {op: 0x04, id: "mul", cost: 2, cond: false},
    @OPC_MLI = {op: 0x05, id: "mli", cost: 2, cond: false},
    @OPC_DIV = {op: 0x06, id: "div", cost: 3, cond: false},
    @OPC_DVI = {op: 0x07, id: "dvi", cost: 3, cond: false},
    @OPC_MOD = {op: 0x08, id: "mod", cost: 3, cond: false},
    @OPC_MDI = {op: 0x09, id: "mdi", cost: 3, cond: false},
    @OPC_AND = {op: 0x0a, id: "and", cost: 1, cond: false},
    @OPC_BOR = {op: 0x0b, id: "bor", cost: 1, cond: false},
    @OPC_XOR = {op: 0x0c, id: "xor", cost: 1, cond: false},
    @OPC_SHR = {op: 0x0d, id: "shr", cost: 1, cond: false},
    @OPC_ASR = {op: 0x0e, id: "asr", cost: 1, cond: false},
    @OPC_SHL = {op: 0x0f, id: "shl", cost: 1, cond: false},
    @OPC_IFB = {op: 0x10, id: "ifb", cost: 2, cond: true},
    @OPC_IFC = {op: 0x11, id: "ifc", cost: 2, cond: true},
    @OPC_IFE = {op: 0x12, id: "ife", cost: 2, cond: true},
    @OPC_IFN = {op: 0x13, id: "ifn", cost: 2, cond: true},
    @OPC_IFG = {op: 0x14, id: "ifg", cost: 2, cond: true},
    @OPC_IFA = {op: 0x15, id: "ifa", cost: 2, cond: true},
    @OPC_IFL = {op: 0x16, id: "ifl", cost: 2, cond: true},
    @OPC_IFU = {op: 0x17, id: "ifu", cost: 2, cond: true},
    @OPC_ADX = {op: 0x1a, id: "adx", cost: 3, cond: false},
    @OPC_SBX = {op: 0x1b, id: "sbx", cost: 3, cond: false},
    undefined,
    undefined,
    @OPC_STI = {op: 0x1e, id: "sti", cost: 2, cond: false},
    @OPC_STD = {op: 0x1f, id: "std", cost: 2, cond: false}
  ]

  #
  # Advanced Opcodes
  #
  @ADV_OPS = [undefined,
  @ADV_JSR = {op: 0x01, id: "jsr", cost: 3, cond: false},
  undefined,
  undefined,
  undefined,
  undefined,
  undefined,
  undefined,
  @ADV_INT = {op: 0x08, id: "int", cost: 4, cond: false},
  @ADV_IAG = {op: 0x09, id: "iag", cost: 1, cond: false},
  @ADV_IAS = {op: 0x0a, id: "ias", cost: 1, cond: false},
  @ADV_RFI = {op: 0x0b, id: "rfi", cost: 3, cond: false},
  @ADV_IAQ = {op: 0x0c, id: "iaq", cost: 2, cond: false},
  undefined,
  undefined,
  undefined,
  @ADV_HWN = {op: 0x10, id: "hwn", cost: 2, cond: false},
  @ADV_HWQ = {op: 0x11, id: "hwq", cost: 4, cond: false},
  @ADV_HWI = {op: 0x12, id: "hwi", cost: 4, cond: false }]

  constructor: (stream) ->
    @mIStream = stream
    @mAddr = @mIStream.index()
    [@mOpc, @mValA, @mValB] = @decode @mIStream.nextWord()

  decode: (instr) ->
    opcode = instr & @OPCODE_MASK()
    valB   = (instr & @VALB_MASK()) >> 5
    valA   = (instr & @VALA_MASK()) >> 10

    if opcode == 0
      valB = new Value @mIStream, valB, true
    else
      valB = new Value @mIStream, valB
    valA = new Value @mIStream, valA

    [opcode, valB, valA]

  opc:  () -> @mOpc
  valA: () -> @mValA
  valB: () -> @mValB
  addr: () -> @mAddr

  #
  # Constants... there's probably (hopefully?) a better way to do this.
  #
  OPCODE_MASK: () -> 0x001f
  VALB_MASK  : () -> 0x03e0
  VALA_MASK  : () -> 0xfc00

exports.Value = Value
exports.Instr = Instr
exports.IStream = IStream
