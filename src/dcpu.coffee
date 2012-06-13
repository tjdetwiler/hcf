#
#  Copyright(C) 2012, Tim Detwiler <timdetwiler@gmail.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This software is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this software.  If not, see <http://www.gnu.org/licenses/>.
#
Module = {}

decode = require './dcpu-decode'

Value = decode.Value
Instr = decode.Instr
IStream = decode.IStream

class Dcpu16
  constructor: () ->
    cpu = @
    @mCCFail        = false
    @mIntQueueOn    = false
    @mCycles        = 0
    @mMemory        = []
    @mMappedRegions = []
    @mRegStorage    = []
    @mIStream = new IStream @mMemory
    @mPendInstr = null
    @mPendingIrq = null
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
    @mBreakpoints = []
    @mDevices = []
    @mRunTimer = null
    @mRunning = false
    @mSourceMap = []
    @mDebugMap = undefined
    @reset()

  #
  # Restore CPU to the Power-On Reset state.
  #
  reset: () ->
    @mCCFail = false
    @mMemory[x] = 0 for x in [0..0xffff]
    @mIntQueueOn = false
    @mMappedRegions = []
    @mCycles = 0
    for r in @mRegAccess
      r 0
    @regSP 0xffff
    for d in @mDevices
      d.reset()

  #
  # Event setter functions.
  #
  # onPreExec:  fn(cpu, instr), where instr is the Instruction about to be executed.
  # onPostExec: fn(cpu, instr), where instr is the Instruction just executed.
  # onCondFail: fn(cpu, instr), where instr is the skipped Instruction.
  # onPeriodic: fn(cpu), fired several times a second
  #
  onPreExec:   (fn) -> @mPreExecCb = fn
  onPostExec:  (fn) -> @mPostExecCb = fn
  onCondFail:  (fn) -> @mCondFailCb = fn
  onPeriodic:  (fn) -> @mPeriodic = fn
  onInstrUndefined: (fn) -> @mInstrUndefinedCb = fn

  #
  # Register Accessors
  #
  # Each register has a function 'reg{ID}', where 'ID' is the register name.
  # The functions take one argument which determines the behavior. If the
  # argument is defined, then the register is assigned to the value passed.
  # If the argument is undefined, then the function returns the register value.
  #
  _reg:     (n,v)   -> @mRegAccess[n](v)
  regA:     (v)     -> @_reg Value.REG_A, v
  regB:     (v)     -> @_reg Value.REG_B, v
  regC:     (v)     -> @_reg Value.REG_C, v
  regX:     (v)     -> @_reg Value.REG_X, v
  regY:     (v)     -> @_reg Value.REG_Y, v
  regZ:     (v)     -> @_reg Value.REG_Z, v
  regI:     (v)     -> @_reg Value.REG_I, v
  regJ:     (v)     -> @_reg Value.REG_J, v
  regSP:    (v)     -> @_reg Value.REG_SP, v
  regEX:    (v)     -> @_reg Value.REG_EX, v
  regPC:    (v)     -> @_reg Value.REG_PC, v
  regIA:    (v)     -> @_reg Value.REG_IA, v
  readReg:  (n)     -> @_reg n
  writeReg: (n,val) -> @_reg n, val

  clamp: (val) ->
    if val < 0x10000
      val
    else
      val % 0x10000

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

  addDevice: (dev) -> @mDevices.push dev

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
    @mMemory[sp-1]


  #
  # Loads a ramdisk. Binary should be a JS array of 2B words.
  # Also sets the PC to the first instruction of the binary.
  #
  loadBinary: (bin, base=0) ->
    @mMemory[base+i] = x for x,i in bin
    @regPC base
    @mDecoded = new Instr @mIStream

  loadJOB: (job) ->
    #TODO: support multiple sections
    bin = []
    for x,i in job.sections[0].data
      bin[i] = x.val
      @mSourceMap[i] = x
      if not @mSourceMap[x.file]?
        @mSourceMap[x.file] = []
      @mSourceMap[x.file][x.line] = i
    if job.sections[0].debug?
      @mDebugMap = job.sections[0].debug
    @loadBinary bin

  #
  # Source Map Helpers
  #
  # line2addr (file, line): returns the address of the instruction at file:line
  # addr2line (addr): returns an object with "file" and "line" fields.
  #
  line2addr: (f,l) -> @mSourceMap[f][l]
  addr2line: (a) -> @mSourceMap[a]

  #
  # Runs the CPU at approx 100KHz
  #
  run: () ->
    cpu = this
    cb = () ->
      for i in [0..10345]
        if not cpu.mRunning then break
        cpu.step()
      if cpu.mPeriodic? then cpu.mPeriodic cpu
    if @mRunTimer then clearInterval @timer
    @mRunning = true
    @mRunTimer = setInterval cb, 50

  #
  # Stops continuous execution caused by a call to run()
  #
  stop: () ->
    @mRunning = false
    if @mRunTimer
      clearInterval @mRunTimer
      @mRunTimer = null

  debugCheck: (expr) ->
    assert = (e) ->
      if not e
        process.stderr.write "Assert Failed: '#{expr}'"
        return "fail"
      return "continue"
    pass = () -> "pass"
    fail = (msg) ->
      process.stderr.write "#{msg}\n"
      return "fail"
    cpu = @
    result = eval expr
    if result == "pass"
      console.log "Exiting on Success"
      process.exit 0
    else if result == "fail"
      console.log "Exiting on Failure"
      process.exit 1


  #
  # Execute one instruction (high level). For actual execution logic, see exec.
  #
  step: () ->
    i = @mDecoded

    #
    # Check for execution breakpoint
    #
    if f = @mBreakpoints[i.addr()]
      @stop()
      return f(i.addr(), "x")

    #
    # Check for any simulator debug hooks.
    #
    if @mDebugMap? and exprs = @mDebugMap[i.addr()]
      @debugCheck expr for expr in exprs

    #
    # Verify we have a valid instruction.
    # If the instruction is invalid, we will fetch a new instruction if either
    # our undefined callback is null, or the result of the callback is false
    #
    if !i.valid() and (!@mInstrUndefinedCb? or @mInstrUndefinedCb @, i)
      @mDecoded = new Instr @mIStream
      return

    #
    # Take an IRQ if pending and we're running (no irqs in single-step mode)
    #
    if @mPendingIrq
      #
      # If we've vectored to IA, fetch the correct instruction
      #
      if @doInterrupt @mPendingIrq
        @mPendingIrq = null
        i = new Instr @mIStream

    #
    # Execute and fire events
    #
    if @mPreExecCb? then @mPreExecCb @, i
    @exec i
    if @mPostExecCb? then @mPostExecCb @, i

    #
    # If we've failed a conditional instruction, we should keep skipping
    # instructions as long as they are conditionals.
    #
    while @mCCFail
      i = new Instr @mIStream
      @mCCFail = i.cond()
      if @mCondFailCb? then @mCondFailCb @, i

    @mDecoded = new Instr @mIStream

  #
  # Instruction execution logic
  #
  # TODO: Maybe attach this function to the Instr prototype
  #
  exec: (i) ->
    opc = i.opc()
    valA = i.valA()
    valB = i.valB()
    @mCycles += i.cost()

    #
    # Lookup and call the instructions executor.
    #
    f = @mExecutors[opc]
    if not f?
      return console.log "Unable to execute OPC #{opc}"
    this[f] valA, valB

  #
  # Signals the CPU to take an interrupt
  #
  interrupt: (n) ->
    @mPendingIrq = n

  #
  # Updates CPU state based on signalled interrupt
  #
  doInterrupt: (n) ->
    ia = @regIA()

    # Don't take interrupt if we're single-stepping or we have no IA
    if ia == 0 or not @mRunning
      return false

    # TODO: Check if interrupt queueing enabled
    # TODO: Put interrupt in queue
    @push @mDecoded.addr()
    @push @regA()
    @regPC ia
    @regA n
    return true
  #
  # Sets an execution breakpoint
  #
  # a: Address of the instruction to break on
  # f: Callback when breakpoint is hit. Should be of the form:
  #     (addr, type) ->
  #   addr is breakpoint address
  #   type is "r", "w", or "x" for read/write/execute
  #
  # TODO: Support r/w breakpoints
  #
  breakpoint: (a,f) ->
    @mBreakpoints[a] = f

  catchFire: () ->
    cpu = this
    misbehave = () -> switch cpu.cycles() % 6
      when 0 then cpu.regPC(cpu.regPC+2)
      when 1 then cpu.regA(~cpu.regA)
      when 2 then cpu.mCCFail = true
      when 3 then cpu.interrupt 0xdead
      when 4 then cpu.pop()
      when 5 then cpu.push cpu.regPC()
    setInterval misbehave, 1000

  #
  # Returns the next instruction to be executed.
  #
  next: () -> @mDecoded


  #
  # Signed Operation Helpers
  #
  # signed -> return the value of 'v' (raw hex) in a signed integer
  # signExtend -> turn 'v' (signed number) into raw hex.
  #
  signed: (v) ->
    if v & 0x8000
      -(0x10000 - v)
    else
      v

  signExtend: (v) ->
    if v < 0
      (~(-v) + 1) & 0xffff
    else
      v

  #
  # Generates a register access function
  #
  _regGen: (n) ->
    (v) => 
      if v?
        # overflow check
        @mRegStorage[n]=@clamp v
      else
        @mRegStorage[n]

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
    else
      @regEX 0
    a.set @,v

  _exec_sub: (a,b) ->
    v = a.get(@) - b.get(@)
    if v < 0
      @regEX 0xffff
      v += 0x10000
    else
      @regEX 0
    a.set @,v

  _exec_mul: (a,b) ->
    v = a.get(@) * b.get(@)
    a.set @, v & 0xffff
    @regEX ((v>>16) & 0xffff)

  _exec_mli: (a,b) ->
    v = (@signed a.get @) * (@signed b.get @)
    v = @signExtend v
    a.set @, v & 0xffff
    @regEX ((v>>16) & 0xffff)
    

  _exec_div: (a,b) ->
    if b.get(@) is 0
      a.set @, 0
      @regEX 0
    else 
      v = (a.get @) / (b.get @)
      a.set @, v & 0xffff
      @regEX (((a.get(@) << 16)/b.get(@))&0xffff)

  _exec_dvi: (a,b) ->
    if b.get(@) is 0
      a.set @, 0
      @regEX 0
    else 
      v = (@signed a.get @) / (@signed b.get @)
      a.set @, v & 0xffff
      @regEX ((a.get(@) << 16)/(@signed b.get @))&0xffff

  _exec_mod: (a,b) ->
    if b.get(@) is 0
      a.set @, 0
    else
      a.set @, a.get(@) % b.get(@)

  _exec_mdi: (a,b) ->
    if b.get(@) is 0
      a.set @, 0
    else
      a.set @, (@signed a.get @) % (@signed b.get @)
    

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

  _exec_ifa: (a,b) ->
    if (@signed a.get @) <= (@signed b.get @)
      @mCCFail=true

  _exec_ifu: (a,b) ->
    if (@signed a.get @) >= (@signed b.get @)
      @mCCFail=true

  _exec_adx: (a,b) -> 
    v = a.get(@) + b.get(@) + @regEX()
    if v > 0xffff
      @regEX 1
    else 
      @regEX 0
    a.set @, v & 0xffff

  _exec_sbx: (a,b) -> 
    v = a.get(@) - b.get(@) + @regEX()
    if v < 0
      @regEX 0xffff
    else 
      @regEX 0
    a.set @, v & 0xffff

  _exec_asr: (a,b) -> 
    @regEX (((a.get(@) << 16)>>b.get(@))&0xffff)
    a.set @, @signExtend(@signed(a.get(@)) >> b.get(@))

  _exec_sti: (a,b) ->
    a.set @, b.get @
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
 
  _exec_hcf: (a)   -> @catchFire()

exports.Dcpu16 = Dcpu16
