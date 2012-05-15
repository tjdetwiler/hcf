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

decode            = require './dcpu-decode'
lem1802           = require './hw/lem1802'
generic_clock     = require './hw/generic-clock'
generic_keyboard  = require './hw/generic-keyboard'

Value = decode.Value
Instr = decode.Instr
IStream = decode.IStream
Lem1802 = lem1802.Lem1802
GenericClock = generic_clock.GenericClock
GenericKeyboard = generic_keyboard.GenericKeyboard

class Dcpu16
  constructor: () ->
    cpu = @
    @mCycles = 0
    @mCCFail = false
    @mIntQueueOn = false
    @mMemory = (0 for x in [0..0xffff])
    @mIStream = new IStream @mMemory
    @mRegStorage = (0 for x in [0..0xf])
    @mRegStorage[Value.REG_SP] = 0xffff
    @mRegAccess = [
      @_regGen(Value.REG_A), @_regGen(Value.REG_B), @_regGen(Value.REG_C),
      @_regGen(Value.REG_X), @_regGen(Value.REG_Y), @_regGen(Value.REG_Z),
      @_regGen(Value.REG_I), @_regGen(Value.REG_J),
      (v) -> cpu.mIStream.index(v), 
      @_regGen(Value.REG_SP), @_regGen(Value.REG_EX), @_regGen(Value.REG_IA)
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

    @mDevices = []
    @mDevices.push new Lem1802 @
    @mDevices.push new GenericClock @
    @mDevices.push new GenericKeyboard @
    @mMappedRegions = []

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
  regEX:    (v)     -> @reg Value.REG_EX, v
  regPC:    (v)     -> @reg Value.REG_PC, v
  regIA:    (v)     -> @reg Value.REG_IA, v
  readReg:  (n)     -> @reg n
  writeReg: (n,val) -> @reg n, val

  #
  # Memory Interface
  #
  # readMem/writeMem - Basic memory access
  # isMapped - Deterimine if an address is mapped to a device
  # mapDevice - Map a block of address space to a device
  # unmapDevice - Unmap a block of device memory
  #
  readMem:  (addr) ->
    region = @isMapped addr
    if region
      region.f addr - region.base
    else
      @mMemory[addr]

  writeMem: (addr, val) ->
    region = @isMapped addr
    if region
      region.f addr - region.base, val
    else
      @mMemory[addr] = val

  isMapped:  (addr) ->
    for region in @mMappedRegions
      if region.base <= addr < region.base + region.len
        return region
    return null

  mapDevice: (addr, len, cb) ->
    @mMappedRegions.push {base: addr, len: len, f: cb}

  unmapDevice: (addr) ->
    newList = []
    for i in [0..@mMappedRegions.length-1]
      region = @mMappedRegions[i]
      if region.base != addr
        newList.push region
    @mMappedRegions = newList

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
    if @mCCFail
      @mCCFail = false
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
    i = Instr.BASIC_OPS[opc]
    if not i? then return

    #
    # If we've failed a conditional instruction, we should keep skipping
    # instructions as long as they are conditionals. This is indicated
    # by the "cond" property of the opcode object.
    #
    if @mCCFail
      @mCCFail = i.cond
      return

    #
    # Lookup and call the instructions executor.
    #
    f = @mExecutors[opc]
    if not f?
      return console.log "Unable to execute OPC #{opc}"
    this[f] valA, valB

  interrupt: (n) ->
    ia = @regIA()

    # Check IA
    if ia == 0
      return

    # Check if interrupt queueing enabled
    if @mIntQueuOn
      # TODO: put interrupt in queue
      return

    @mIntQueueOn = true
    @push @regPC()
    @push @regA()
    @regPC @regIA()
    @regA n

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
      @regEX 1
      v -= 0xffff
    else
      @regEX 0
    a.set @,v

  _exec_sub: (a,b) ->
    v = a.get(@) - b.get(@)
    if v < 0
      @regEX 0xffff
      v += 0xffff
    else
      @regEX 0
    a.set @,v

  _exec_mul: (a,b) ->
    v = a.get(@) * b.get(@)
    a.set @, v & 0xffff
    @regEX ((v>>16) & 0xffff)

  _exec_div: (a,b) ->
    if b.get(@) is 0
      a.set 0
    else 
      v = a.get(@) / b.get(@)
      a.set @, v & 0xffff
      @regEX (((a.get() << 16)/b.get)&0xffff)

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
    @regEX (((a.get(@) << 16)>>b.get(@))&0xffff)

  _exec_shl: (a,b) ->
    a.set @, a.get(@) << b.get(@)
    @regEX (((a.get(@)<<b.get(@))>>16)&0xffff)

  _exec_ifb: (a,b) ->
    if (a.get(@) & b.get(@)) == 0
      @mCCFail=true

  _exec_ifc: (a,b) ->
    if (a.get(@) & b.get(@)) != 0
      @mCCFail=true

  _exec_ife: (a,b) ->
    if a.get(@) != b.get(@)
      @mCCFail=true

  _exec_ifn: (a,b) ->
    if a.get(@) == b.get(@)
      @mCCFail=true

  _exec_ifg: (a,b) ->
    if a.get(@) <= b.get(@)
      @mCCFail=true

  _exec_ifl: (a,b) ->
    if a.get(@) >= b.get(@)
      @mCCFail=true

  _exec_ifa: (a,b) -> undefined
  _exec_ifu: (a,b) -> undefined
  _exec_mli: (a,b) -> undefined
  _exec_ash: (a,b) -> undefined
  _exec_dvi: (a,b) -> undefined
  _exec_mdi: (a,b) -> undefined
  _exec_adf: (a,b) -> undefined
  _exec_sbx: (a,b) -> undefined

  _exec_sti: (a,b) ->
    b.set @, a.get @
    @regJ @regJ() + 1
    @regI @regI() + 1

  _exec_std: (a,b) ->
    b.set @, a.get @
    @regJ @regJ() - 1
    @regI @regI() - 1

  _exec_jsr: (a)   ->
    @push @regPC()
    @regPC a.get()

  _exec_int: (a)   ->
    n = a.get @
    @interrupt n

  _exec_iag: (a)   ->
    a.set @, @regIA()

  _exec_ias: (a)   ->
    @regIA a.get @

  _exec_rfi: (a)   ->
    @mIntQueueOn = false
    @regA @pop()
    @regPC @pop()

  _exec_iaq: (a)   ->
    n = a.get @
    @mIntQueueOn = (n != 0)

  _exec_hwn: (a)   ->
    a.set @, @mDevices.length

  _exec_hwq: (a)   ->
    i = a.get @
    dev = @mDevices[i]
    if dev? then dev.query()

  _exec_hwi: (a)   ->
    i = a.get @
    dev = @mDevices[i]
    if dev? then dev.hwInterrupt()
 

exports.Dcpu16 = Dcpu16
