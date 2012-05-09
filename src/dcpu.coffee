#
# dcpu.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# DCPU-16 Core Implementation.
#
# In order to make this suitable for web-deployment, this file should not
# rely on any node.js library functions.
#
Module = {}

decode = require './dcpu-decode'

Value = decode.Value
Instr = decode.Instr
IStream = decode.IStream

class Dcpu16

  constructor: (program = []) ->
    @mCycles = 0
    @mRegs = []
    @mSkipNext = false
    @mRegs[x]   = 0 for x in [0..0xf]
    @mRegs[Value.REG_SP] = 0xffff
    @mMemory = (0 for x in [0..0xffff])
    @mMemory[i] = x for x,i in program
    @mIStream = new IStream @mMemory
 
  #
  # Events
  #
  onPreExec: (fn) -> @mPreExec = fn
  onPostExec: (fn) -> @mPostExec = fn
  onCondFail: (fn) -> @mCondFail = fn

  #
  # Data Accessors
  #
  readReg:  (n) ->
    if n == Value.REG_PC
      @regPC()
    else
      @mRegs[n]
  writeReg: (n,val) ->
    if n == Value.REG_PC
      @regPC val
    else
      @mRegs[n] = val
  readMem:  (addr) -> @mMemory[addr]
  writeMem: (addr, val) -> @mMemory[addr] = val
  push:     (v) ->
    @mMemory[@mRegs[Value.REG_SP]] = v
    @mRegs[Value.REG_SP]-=1

  peek:     () -> @mMemory[@mRegs[Value.REG_SP]]
  pop:      () -> @mMemory[++@mRegs[Value.REG_SP]]

  reg:      (n,v=0) -> if v? then @mRegs[n]=v else @mRegs[n]
  regA:     (v) -> @reg  Value.REG_A, v
  regB:     (v) -> @reg  Value.REG_B, v
  regC:     (v) -> @reg  Value.REG_C, v
  regX:     (v) -> @reg  Value.REG_X, v
  regY:     (v) -> @reg  Value.REG_Y, v
  regZ:     (v) -> @reg  Value.REG_Z, v
  regI:     (v) -> @reg  Value.REG_I, v
  regJ:     (v) -> @reg  Value.REG_J, v
  regSP:    (v) -> @reg  Value.REG_SP,v
  regO:     (v) -> @reg  Value.REG_O, v
  regPC:    (v) -> @mIStream.index v

  #
  # Loads a ramdisk. Binary should be a JS array of 2B words.
  #
  loadBinary: (bin, base=0) ->
    @mMemory[base+i] = x for x,i in bin

  #
  # Execute a Single Instruction
  #
  step: () ->
    i = new Instr @mIStream
    if @mSkipNext
      @mSkipNext = false
      if @mCondFail? then @mCondFail i
      return @step()

    if @mPreExec? then @mPreExec i
    @exec i.opc(), i.valA(), i.valB()
    if @mPostExec? then @mPostExec i

  #
  # Run the CPU
  #
  run: () ->
    @mRun = true
    @step() while @mRun

  #
  # Stop the CPU
  #
  stop: () -> @mRun = false

  #
  # Executes an advanced instruction
  #
  execAdv: (opc, valA) ->
    switch opc
      when Instr.ADV_JSR
        @push(@mRegs[Value.REG_PC])
        @mRegs[Value.REG_PC] = valA.get()

  exec: (opc, valA, valB) ->
    #
    # Fetching the first word of the instr takes 1 cycle, so the
    # instructions only need to account for any additional cycles.
    #
    # Values will add cycles themselves when they're fetched.
    #
    switch opc
      when Instr.OPC_ADV
        @execAdv valA.raw(), valB
      when Instr.OPC_SET
        valA.set @, valB.get @
      when Instr.OPC_ADD
        @mCycles += 1
        v = valA.get(@) + valB.get(@)
        if v > 0xffff
          @regO 1
          v -= 0xffff
        else
          @regO 0
        valA.set @,v
      when Instr.OPC_SUB
        @mCycles += 1
        v = valA.get(@) - valB.get(@)
        if v < 0
          @regO 0xffff
          v += 0xffff
        else
          @regO 0
        valA.set @,v
      when Instr.OPC_MUL
        @mCycles += 1
        v = valA.get(@) * valB.get(@)
        valA.set @, v & 0xffff
        @regO ((v>>16) & 0xffff)
      when Instr.OPC_DIV
        @mCycles += 2
        if valB.get(@) is 0
          regA.set 0
        else 
          v = valA.get(@) / valB.get(@)
          valA.set @, v & 0xffff
          @regO (((valA.get() << 16)/valB.get)&0xffff)
      when Instr.OPC_MOD
        @mCycles += 2
        if valB.get(@) is 0
          regA.set 0
        else
          valA.set valA.get(@) % valB.get(@)
      when Instr.OPC_SHL
        @mCycles += 1
        valA.set @, valA.get(@) << valB.get(@)
        @regO (((valA.get(@)<<valB.get(@))>>16)&0xffff)
      when Instr.OPC_SHR
        @mCycles += 1
        valA.set @, valA.get(@) >> valB.get(@)
        @regO (((valA.get(@) << 16)>>valB.get(@))&0xffff)
      when Instr.OPC_AND
        valA.set @, valA.get(@) & valB.get(@)
      when Instr.OPC_BOR
        valA.set @, valA.get(@) | valB.get(@)
      when Instr.OPC_XOR
        valA.set @, valA.get(@) ^ valB.get(@)
      when Instr.OPC_IFE
        if valA.get(@) == valB.get(@)
          @mCycles += 2
        else
          @mSkipNext=true
          @mCycles += 1
      when Instr.OPC_IFN
        if valA.get(@) != valB.get(@)
          @mCycles += 2
        else
          @mSkipNext=true
          @mCycles += 1
      when Instr.OPC_IFG
        if valA.get(@) > valB.get(@)
          @mCycles += 2
        else
          @mSkipNext=true
          @mCycles += 1
      when Instr.OPC_IFB
        if (valA.get(@) & valB.get(@)) != 0
          @mCycles += 2
        else
          @mSkipNext=true
          @mCycles += 1


exports.Dcpu16 = Dcpu16
