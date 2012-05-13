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
  constructor: () ->
    cpu = @
    @mCycles = 0
    @mSkipNext = false
    @mMemory = (0 for x in [0..0xffff])
    @mIStream = new IStream @mMemory
    @mRegStorage = (0 for x in [0..0xf])
    @mRegStorage[Value.REG_SP] = 0xffff
    @mRegAccess = [
      @_regGen(Value.REG_A), @_regGen(Value.REG_B), @_regGen(Value.REG_C),
      @_regGen(Value.REG_X), @_regGen(Value.REG_Y), @_regGen(Value.REG_Z),
      @_regGen(Value.REG_I), @_regGen(Value.REG_J),
      (v) -> cpu.mIStream.index(v), 
      @_regGen(Value.REG_SP), @_regGen(Value.REG_O)
    ]
 
  #
  # Event setter functions.
  #
  # onPreExec:  fn(instr), where instr is the Instruction about to be executed.
  # onPostExec: fn(instr), where instr is the Instruction just executed.
  # onCondFail: fn(instr), where instr is the skipped Instruction.
  #
  onPreExec: (fn) -> @mPreExec = fn
  onPostExec: (fn) -> @mPostExec = fn
  onCondFail: (fn) -> @mCondFail = fn

  #
  # Register Accessors
  #
  # Each register has a function 'reg{ID}', where 'ID' is the register name.
  # The functions take one argument which determines the behavior. If the
  # argument is defined, then the register is assigned to the value passed.
  # If the argument is undefined, then the function returns the register value.
  #
  reg:      (n,v)     -> @mRegAccess[n](v)
  regA:     (v)     -> @reg Value.REG_A, v
  regB:     (v)     -> @reg Value.REG_B, v
  regC:     (v)     -> @reg Value.REG_C, v
  regX:     (v)     -> @reg Value.REG_X, v
  regY:     (v)     -> @reg Value.REG_Y, v
  regZ:     (v)     -> @reg Value.REG_Z, v
  regI:     (v)     -> @reg Value.REG_I, v
  regJ:     (v)     -> @reg Value.REG_J, v
  regSP:    (v)     -> @reg Value.REG_SP, v
  regO:     (v)     -> @reg Value.REG_O, v
  regPC:    (v)     -> @reg Value.REG_PC, v
  readReg:  (n)     -> @reg n
  writeReg: (n,val) -> @reg n, val

  #
  # Memory Accessors
  #
  # Reads or writes a word or RAM
  #
  readMem:  (addr) -> @mMemory[addr]
  writeMem: (addr, val) -> @mMemory[addr] = val

  #
  # Stack Helpers
  #
  # push: Returns [--SP]
  # peek: Returns [SP]
  # pop:  Returns [SP++]
  #
  push: (v) ->
    sp = @regSP(@regSP()-1)
    @mMemory[sp] = v
  peek: ( ) ->
    sp = @regSP()
    @mMemory[sp]
  pop:  ( ) ->
    sp = @regSP(@regSP()+1)
    @mMemory[sp - 1]


  #
  # Loads a ramdisk. Binary should be a JS array of 2B words.
  #
  loadBinary: (bin, base=0) ->
    @mMemory[base+i] = x for x,i in bin

  #
  # Execution Control
  #
  # step: Execute one instruction
  # run:  Run the CPU at full speed.
  # stop: Stops the CPU.
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

  run: () ->
    @mRun = true
    @step() while @mRun

  stop: () -> @mRun = false

  #
  # Execution Logic
  #
  # exec: Interprets an instruction and updates CPU state.
  # execAdv: Helper for exec to execute an Advanced Instruction
  #
  execAdv: (opc, valA) ->
    switch opc
      when Instr.ADV_JSR
        @push @regPC()
        @regPC valA.get()

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

  #
  # Generates a register access function
  #
  _regGen: (n) ->
    cpu = this
    (v) -> 
      if v?
        cpu.mRegStorage[n]=v
      else
        cpu.mRegStorage[n]

exports.Dcpu16 = Dcpu16
