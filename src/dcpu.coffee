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
    @mExecutors = []
    @mAdvExecutors = []
    for op in Instr.BASIC_OPS
      if op?
        name = "_exec_#{op.id.toLowerCase()}"
        @mExecutors[op.op] = name
    for op in Instr.ADV_OPS
      if op?
        name = "_exec_#{op.id.toLowerCase()}"
        @mAdvExecutors[op.op] = name

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
  reg:      (n,v)   -> @mRegAccess[n](v)
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
  # Also sets the PC to the first instruction of the binary.
  #
  loadBinary: (bin, base=0) ->
    @mMemory[base+i] = x for x,i in bin
    @regPC base

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

  exec: (opc, valA, valB) ->
    f = @mExecutors[opc]
    if not f?
      return console.log "Unable to execute OPC #{opc}"
    this[f] valA, valB

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

  #
  # Instruction Execution Logic
  #
  # Define a function of the name _exec_{opcode}. For example, the
  # instruction SET PC, 0x1000 will be handled by 
  #
  # _exec_adv is a special case for basic opcode '0'.
  #
  _exec_adv: (a,b) ->
    opc =  a.raw()
    f = @mAdvExecutors[opc]
    if not f?
      return console.log "Unable to execute Advanced Opcode #{opc}"
    this[f] b

  _exec_set: (a,b) ->
    a.set @, b.get @

  _exec_add: (a,b) ->
    v = a.get(@) + b.get(@)
    if v > 0xffff
      @regO 1
      v -= 0xffff
    else
      @regO 0
    a.set @,v

  _exec_sub: (a,b) ->
    v = a.get(@) - b.get(@)
    if v < 0
      @regO 0xffff
      v += 0xffff
    else
      @regO 0
    a.set @,v

  _exec_mul: (a,b) ->
    v = a.get(@) * b.get(@)
    a.set @, v & 0xffff
    @regO ((v>>16) & 0xffff)

  _exec_div: (a,b) ->
    if b.get(@) is 0
      a.set 0
    else 
      v = a.get(@) / b.get(@)
      a.set @, v & 0xffff
      @regO (((a.get() << 16)/b.get)&0xffff)

  _exec_mod: (a,b) ->
    if b.get(@) is 0
      a.set 0
    else
      a.set a.get(@) % b.get(@)

  _exec_and: (a,b) ->
    a.set @, a.get(@) & b.get(@)

  _exec_bor: (a,b) ->
    a.set @, a.get(@) | b.get(@)

  _exec_xor: (a,b) ->
    a.set @, a.get(@) ^ b.get(@)

  _exec_shr: (a,b) ->
    a.set @, a.get(@) >> b.get(@)
    @regO (((a.get(@) << 16)>>b.get(@))&0xffff)


  _exec_shl: (a,b) ->
    a.set @, a.get(@) << b.get(@)
    @regO (((a.get(@)<<b.get(@))>>16)&0xffff)

  _exec_ife: (a,b) ->
    if a.get(@) == b.get(@)
      ""
    else
      @mSkipNext=true

  _exec_ifn: (a,b) ->
    if a.get(@) != b.get(@)
      ""
    else
      @mSkipNext=true

  _exec_ifg: (a,b) ->
    if a.get(@) > b.get(@)
      ""
    else
      @mSkipNext=true

  _exec_ifb: (a,b) ->
    if (a.get(@) & b.get(@)) != 0
      ""
    else
      @mSkipNext=true

  #
  # TODO: These
  #
  _exec_mli: (a,b) -> undefined
  _exec_ash: (a,b) -> undefined
  _exec_dvi: (a,b) -> undefined
  _exec_mdi: (a,b) -> undefined
  _exec_ifc: (a,b) -> undefined
  _exec_ifa: (a,b) -> undefined
  _exec_ifl: (a,b) -> undefined
  _exec_ifu: (a,b) -> undefined
  _exec_adf: (a,b) -> undefined
  _exec_sbx: (a,b) -> undefined
  _exec_sti: (a,b) -> undefined
  _exec_std: (a,b) -> undefined

  _exec_jsr: (a)   ->
    @push @regPC()
    @regPC a.get()

  _exec_int: (a)   -> undefined
  _exec_iag: (a)   -> undefined
  _exec_ias: (a)   -> undefined
  _exec_rfi: (a)   -> undefined
  _exec_iaq: (a)   -> undefined
  _exec_hwn: (a)   -> undefined
  _exec_hwq: (a)   -> undefined
  _exec_hwi: (a)   -> undefined
 

exports.Dcpu16 = Dcpu16
