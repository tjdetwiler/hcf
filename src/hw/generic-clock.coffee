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
    @mIrqMsg = 0
    @mTimer = null

  id:   () -> 0x12d0b402
  mfgr: () -> 0x0
  ver:  () -> 0x1

  hwInterrupt: () -> switch @mCpu.regA()
    when 0 then @setRate()
    when 1 then @getTicks()
    when 2 then @setInterrupts()
    else undefined

  reset: () ->
    if @mTimer then clearInterval @mTimer
    @mCount = 0
    @mIrqMsg = 0

  #
  # Handles HWI #0
  #
  setRate: () ->
    @mRate = @mCpu.regB()
    @mCount = 0
    if @mRate
      # Start Timer at rate of 60/B ticks per second
      console.log "#{@mRate}"
      @mRate = Math.floor 60/@mRate
      console.log "#{@mRate}"
      @mRate = 1000/@mRate
      console.log "#{@mRate}"
      @mTimer = setInterval @tick(), @mRate
    else if @mTimer
      # Cancel Timer
      cancelInterval @mTimer

  #
  # Handles HWI #1
  #
  getTicks: () ->
    @mCpu.regC @mCount

  #
  # Handles HWI #2
  #
  setInterrupts: () ->
    @mIrqMsg = @mCpu.regB()

  #
  # Generates a callback function appropriate for setInterval
  #
  tick: () ->
    clock = this
    () ->
      clock.mCount++
      if clock.mIrqMsg then clock.interrupt clock.mIrqMsg
      
exports.GenericClock = GenericClock
