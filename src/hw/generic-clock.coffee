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

  getTicks:       () ->
    elapsed = @mCount - @mLastCount
    @mLastCount = @mCount
    @mCpu.regC elapsed

  setInterrupts:  () ->
    @mIrqMsg = @mCpu.regB()

exports.GenericClock = GenericClock
