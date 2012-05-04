Module = {}

class Dcpu16Value
  constructor: (cpu, enc) ->
    @mCpu = cpu
    @isMem = false
    @isReg = false
    @mEncoding = enc

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
      @mValue = @mCpu.nextWord() + @mCpu.readReg enc - 0x10
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
      @mValue = @mCpu.nextWord()
    else if enc == 0x1f
      @mValue = @mCpu.nextWord()
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
      @mCpu.writeMem @mValue val
    else if @isReg
      @mCpu.writeReg @mValue val
    else
      # error
      console.log "Error: Attempt to 'set' a literal value"

  raw: () -> @mEncoding

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
  [@ADV_JSR] = [0..0]

  #
  # Register Indicies
  #
  [@REG_A, @REG_B, @REG_C, @REG_X,  @REG_Y,
   @REG_Z, @REG_I, @REG_J, @REG_PC, @REG_SP,
   @REG_O] = [0x0..0xa]

  constructor: (program = []) ->
    @mCycles = 0
    @mRegs = []
    @mMemory = []
    @mSkipNext = false
    @mRegs[x]   = 0 for x in [0..0xf]
    @mMemory[x] = 0 for x in [0..0xffff]
    @mMemory[x] = program[x] for x in [0..program.length]
 
  #
  # Data Accessors
  #
  readReg:  (n) -> @mRegs[n]
  writeReg: (n,val) -> @mRegs[n] = val
  readMem:  (addr) -> @mMemory[addr]
  writeMem: (addr, val) -> @mMemory[addr] = val
  push:     () -> @mRegs[Dcpu16.REG_SP]++
  peek:     () -> @mRegs[Dcpu16.REG_SP]
  pop:      ()   -> ++@mRegs[Dcpu16.REG_SP]

  #
  # Loads a ramdisk
  #
  loadBinary: (bin) -> @mMemory = bin

  #
  # Fetch one word and increment the PC
  #
  fetchByte: () ->
    @mCycles++
    pc = @mRegs[Dcpu16.REG_PC]++
    console.log "Setting PC to #{pc+1}"
    @mMemory[pc]

  nextWord: () -> @fetchByte()

  decode: (instr) ->
    opcode = instr & @OPCODE_MASK()
    valA   = (instr & @VALA_MASK()) >> 4
    valB   = (instr & @VALB_MASK()) >> 10
    console.log "Decode:"
    console.log "Encoded:#{instr.toString 16}"
    console.log "\topc:  #{opcode.toString 16}"
    console.log "\tvalA: #{valA.toString 16}"
    console.log "\tvalB: #{valB.toString 16}"
    [opcode, new Dcpu16Value @,valA, new Dcpu16Value @,valB]

  #
  # Executes an advanced instruction
  #
  execAdv: (opc, valA) ->
    switch opc
      when @ADV_JSR
        addr = push()
        @mMemory[addr] = @mRegs[Dcpu16.REG_PC]
        @mRegs[Dcpu16.REG_PC] = valA.get()

  #
  # Executes an instruction
  #
  exec: (opc, valA, valB) ->
    #
    # Fetching the first word of the instr takes 1 cycle, so the
    # instructions only need to account for any additional cycles.
    #
    # Values will add cycles themselves when they're fetched.
    #
    switch opc
      when @OPC_ADV
        execAdv valB.raw(), valA
      when @OPC_SET
        console.log "SET"
        valA.set valB.get()
      when @OPC_ADD
        console.log "ADD"
        valA.set valA.get() + valB.get()
        @mCycles += 1
        # TODO: check overflow
      when @OPC_SUB
        valA.set valA.get() - valB.get()
        @mCycles += 1
        # TODO: check underflow
      when @OPC_MUL
        valA.set valA.get() * valB.get()
        @mCycles += 1
        # TODO: set overflow
      when @OPC_DIV
        valA.set valA.get() / valB.get()
        @mCycles += 2
        # TODO: set overflow (div by zero)
      when @OPC_MOD
        valA.set valA.get() % valB.get()
        @mCycles += 2
        # TODO: set overflow
      when @OPC_SHL
        valA.set valA.get() << valB.get()
        @mCycles += 1
      when @OPC_SHR
        valA.get valA.get() >> valB.get()
        @mCycles += 1
      when @OPC_AND
        valA.set valA.get() & valB.get()
      when @OPC_BOR
        valA.set valA.get() | valB.get()
      when @OPC_XOR
        valA.set valA.get() ^ valB.get()
      when @OPC_IFE
        if valA.get() == valB.get()
          @mSkipNext=true
          @mCycles += 1
        else
          @mCycles += 2
      when @OPC_IFN
        if valA.get() != valB.get()
          @mSkipNext=true
          @mCycles += 1
        else
          @mCycles += 2
      when @OPC_IFG
        if valA.get() > valB.get()
          @mSkipNext=true
          @mCycles += 1
        else
          @mCycles += 2
      when @OPC_IFB
        if (valA.get() & valB.get()) != 0
          @mSkipNext=true
          @mCycles += 1
        else
          @mCycles += 2

  step: () ->
    console.log "PC: #{@mRegs[Dcpu16.REG_PC]}"
    instr = @fetchByte()
    console.log "Fetching #{instr}"
    [opc, valA, valB] = @decode instr

    #
    # Failed conditional execution
    #
    if @mSkipNext
      @mSkipNext=false
      return

    console.log "Executing opc #{opc}"
    @exec opc, valA, valB


  run: () -> @step() while true

  #
  # Constants... there's probably (hopefully?) a better way to do this.
  #
  OPCODE_MASK: () -> 0x000f
  VALA_MASK  : () -> 0x03f0
  VALB_MASK  : () -> 0xfc00

exports.Dcpu16 = Dcpu16
