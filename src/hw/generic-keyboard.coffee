#
# hw/generic-keyboard.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# Generic Keyboard
# Based on the spec at: http://dcpu.com/highnerd/rc_1/keyboard.txt
#
Module = {}

device = require "./device"

Device = device.Device

class GenericKeyboard extends Device
  constructor: (cpu) ->
    super "Generic Keyboard", cpu
    @mKeyBuffer = []

  id:   () -> 0x30cf7406
  mfgr: () -> 0x0
  ver:  () -> 0x1

  hwInterrupt: () -> switch @mCpu.regA()
    when 0 then @clearBuffer()
    when 1 then @nextKey()
    when 2 then @isPressed()
    when 3 then @setInterrupts()
    else undefined

  clearBuffer:    () ->
    @mKeyBuffer = []

  nextKey:        () -> 
    if @mKeyBuffer.length is 0
      return 0
    key = @mKeyBuffer[0]
    @mKeyBuffer=@mKeyBuffer[1..]
    @mCpu.regC key

  isPressed:      () -> 
    @mCpu.regC 0

  setInterrupts:  () -> 
    @mIrqMsg = @mCpu.regB()

exports.GenericKeyboard = GenericKeyboard
