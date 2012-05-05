#
# dcpu.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# DCPU-16 Core Implementation.
#
# In order to make this suitable for web-deployment, this file should not
# rely on any node.js library functions, and should be kept small.
#
# TODO: Figure out how to do require and exports while still supporting
#       browsers
#
Module = {}

class Value
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
      @mValue = @mCpu.readReg enc
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
      @mValue = Dcpu16.REG_SP
    else if enc == 0x1c
      @isReg = true
      @mValue = Dcpu16.REG_PC
    else if enc == 0x1d
      @isReg = true
      @mValue = Dcpu16.REG_O
    else if enc == 0x1e
      @isMem = true
      @mNext = @mCpu.nextWord()
      @mValue = @mNext
    else if enc == 0x1f
      @mNext = @mCpu.nextWord()
      @mValue = @mNext
    else if 0x20 <= enc <= 0x1f
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
  # Constants... there's probably (hopefully?) a better way to do this.
  #
  OPCODE_MASK: () -> 0x000f
  VALA_MASK  : () -> 0x03f0
  VALB_MASK  : () -> 0xfc00

  constructor: (cpu, enc) ->
    @mCpu = cpu
    [@mOpc, @mValA, @mValB] = @decode enc

  decode: (instr) ->
    opcode = instr & @OPCODE_MASK()
    valA   = (instr & @VALA_MASK()) >> 4
    valB   = (instr & @VALB_MASK()) >> 10
    [opcode, new Value(@mCpu,valA), new Value(@mCpu,valB)]

  #
  # Executes an advanced instruction
  #
  execAdv: (opc, valA) ->
    switch opc
      when Dcpu16.ADV_JSR
        addr = @mCpu.push()
        @mCpu.mMemory[addr] = @mCpu.mRegs[Dcpu16.REG_PC]
        @mCpu.mRegs[Dcpu16.REG_PC] = valA.get()

  #
  # Executes an instruction
  #
  exec: () ->
    valA = @mValA
    valB = @mValB

    #
    # Fetching the first word of the instr takes 1 cycle, so the
    # instructions only need to account for any additional cycles.
    #
    # Values will add cycles themselves when they're fetched.
    #
    switch @mOpc
      when Dcpu16.OPC_ADV
        @execAdv valA.raw(), valB
      when Dcpu16.OPC_SET
        valA.set valB.get()
      when Dcpu16.OPC_ADD
        valA.set valA.get() + valB.get()
        @mCycles += 1
        # TODO: check overflow
      when Dcpu16.OPC_SUB
        valA.set valA.get() - valB.get()
        @mCycles += 1
        # TODO: check underflow
      when Dcpu16.OPC_MUL
        valA.set valA.get() * valB.get()
        @mCycles += 1
        # TODO: set overflow
      when Dcpu16.OPC_DIV
        valA.set valA.get() / valB.get()
        @mCycles += 2
        # TODO: set overflow (div by zero)
      when Dcpu16.OPC_MOD
        valA.set valA.get() % valB.get()
        @mCycles += 2
        # TODO: set overflow
      when Dcpu16.OPC_SHL
        valA.set valA.get() << valB.get()
        @mCycles += 1
      when Dcpu16.OPC_SHR
        valA.set valA.get() >> valB.get()
        @mCycles += 1
      when Dcpu16.OPC_AND
        valA.set valA.get() & valB.get()
      when Dcpu16.OPC_BOR
        valA.set valA.get() | valB.get()
      when Dcpu16.OPC_XOR
        valA.set valA.get() ^ valB.get()
      when Dcpu16.OPC_IFE
        if valA.get() == valB.get()
          @mCpu.mSkipNext=true
          @mCycles += 1
        else
          @mCycles += 2
      when Dcpu16.OPC_IFN
        if valA.get() != valB.get()
          @mCpu.mSkipNext=true
          @mCycles += 1
        else
          @mCycles += 2
      when Dcpu16.OPC_IFG
        if valA.get() > valB.get()
          @mCpu.mSkipNext=true
          @mCycles += 1
        else
          @mCycles += 2
      when Dcpu16.OPC_IFB
        if (valA.get() & valB.get()) != 0
          @mCpu.mSkipNext=true
          @mCycles += 1
        else
          @mCycles += 2

class Dcpu16
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
  [@ADV_JSR] = [1]

  #
  # Register Indicies
  #
  [@REG_A, @REG_B, @REG_C, @REG_X,  @REG_Y,
   @REG_Z, @REG_I, @REG_J, @REG_PC, @REG_SP,
   @REG_O] = [0x0..0xa]

  constructor: (program = []) ->
    @mCycles = 0
    @mRegs = []
    @mSkipNext = false
    @mRegs[x]   = 0 for x in [0..0xf]
    @mRegs[Dcpu16.REG_SP] = 0xffff
    @mMemory = (0 for x in [0..0xffff])
    @mMemory[i] = x for x,i in program
 
  #
  # Events
  #
  onPreExec: (fn) -> @mPreExec = fn
  onPostExec: (fn) -> @mPostExec = fn
  onCondFail: (fn) -> @mCondFail = fn

  #
  # Data Accessors
  #
  readReg:  (n) -> @mRegs[n]
  writeReg: (n,val) -> @mRegs[n] = val
  readMem:  (addr) -> @mMemory[addr]
  writeMem: (addr, val) -> @mMemory[addr] = val
  push:     () -> --@mRegs[Dcpu16.REG_SP]
  peek:     () -> @mRegs[Dcpu16.REG_SP]
  pop:      () -> @mRegs[Dcpu16.REG_SP]++
  _r:       (v,n) -> if v? then @mRegs[n] = v else @mRegs[n]
  regA:     (v) -> @_r v, Dcpu16.REG_A
  regB:     (v) -> @_r v, Dcpu16.REG_B
  regC:     (v) -> @_r v, Dcpu16.REG_C
  regX:     (v) -> @_r v, Dcpu16.REG_X
  regY:     (v) -> @_r v, Dcpu16.REG_Y
  regZ:     (v) -> @_r v, Dcpu16.REG_Z
  regI:     (v) -> @_r v, Dcpu16.REG_I
  regJ:     (v) -> @_r v, Dcpu16.REG_J
  regPC:    (v) -> @_r v, Dcpu16.REG_PC
  regSP:    (v) -> @_r v, Dcpu16.REG_SP
  regO:     (v) -> @_r v, Dcpu16.REG_O

  #
  # Loads a ramdisk. Binary should be a JS array of 2B words.
  #
  loadBinary: (bin, base=0) ->
    @mMemory[base+i] = x for x,i in bin

  #
  # Fetch one word and increment the PC
  #
  nextWord: () ->
    @mCycles++
    pc = @mRegs[Dcpu16.REG_PC]++
    @mMemory[pc]

  #
  # Execute a Single Instruction
  #
  step: () ->
    i = new Instr @, @nextWord()
    if @mSkipNext
      @mSkipNext = false
      if @mCondFail? then @mCondFail i
      return @step()

    if @mPreExec? then @mPreExec i
    i.exec()
    if @mPostExec? then @mPostExec i

  #
  # Run the CPU
  #
  run: () -> @step() while true

exports.Dcpu16 = Dcpu16
