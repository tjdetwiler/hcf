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

Device = require("./device").Device

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
    if @mTimer
      # Cancel Timer
      clearInterval @mTimer

    if @mRate
      # Start Timer at rate of 60/B ticks per second
      @mRate = Math.floor 60/@mRate
      @mRate = 1000/@mRate
      @mTimer = setInterval @tick(), @mRate

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
