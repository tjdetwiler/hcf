#
# hw/generic-clock.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# Generic System Clock
# Based on the spec at: http://dcpu.com/highnerd/rc_1/clock.txt
#
Module = {}

device = require "./device"

Device = device.Device

class GenericClock extends Device
  constructor: (cpu) ->
    super "Generic Clock", cpu
    @mCount = 0
    @mLastCount = 0
    @mIrqMsg = 0

  id:   () -> 0x12d0b402
  mfgr: () -> 0x0
  ver:  () -> 0x1

  hwInterrupt: () -> switch @mCpu.regA()
    when 0 then @setRate()
    when 1 then @getTicks()
    when 2 then @setInterrupts()
    else undefined

  setRate:        () ->
    @mRate = @mCpu.regB()
    if @mRate
      @mRate = Math.floor 60/@mRate
      @mRate = 1000/@mRate
      console.log "Timer ticking every #{@mRate}ms"
      setTimeout @tick(), @mRate

  getTicks:       () ->
    @mCpu.regC @mCount
    @mCount = 0

  setInterrupts:  () ->
    @mIrqMsg = @mCpu.regB()

  tick: () ->
    clock = this
    () ->
      console.log "ticking"
      if clock.mIrqMsg then clock.interrupt clock.mIrqMsg
      clock.mCount++
      if clock.mRate then setTimeout clock.tick(), clock.mRate
      
exports.GenericClock = GenericClock
