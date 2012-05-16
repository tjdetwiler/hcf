
#
# hw/hmd2043.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# HMD2043 Flo
# Based on the spec at: http://dcpu.com/highnerd/lem1802.txt
#
Module = {}

device = require "./device"
Device = device.Device

class Hmd2043 extends Device
  constructor: (cpu) ->
    super "HMD2043", cpu

  id:   () -> 0x74fa4cae
  mfgr: () -> 0x21544948
  ver:  () -> 0x07c2

  hwInterrupt: () -> switch @mCpu.regA()
    when 0x0000 then @queryMediaPresent()
    when 0x0001 then @queryMediaParameters()
    when 0x0002 then @queryDeviceFlags()
    when 0x0003 then @updateDeviceFlags()
    when 0x0004 then @queryInterruptType()
    when 0x0005 then @setInterruptMessage()
    when 0x0010 then @readSectors()
    when 0x0011 then @writeSectors()
    when 0xffff then @queryMediaQuality()
    else undefined

  queryMediaPresent: () -> undefined
  queryMediaParameters: () -> undefined
  queryDeviceFlags: () -> undefined
  updateDeviceFlags: () -> undefined
  queryInterruptType: () -> undefined
  setInterruptMessage: () -> undefined
  readSectors: () -> undefined
  writeSectors: () -> undefined
  queryMediaQuality: () -> undefined

class Hmu1440
  constructor: () -> undefined

