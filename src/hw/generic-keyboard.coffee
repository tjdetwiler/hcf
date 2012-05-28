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

  #
  # Handles HWI #0
  #
  clearBuffer: () ->
    @mKeyBuffer = []

  #
  # Handles HWI #1
  #
  nextKey: () -> 
    if @mKeyBuffer.length is 0
      return 0
    key = @mKeyBuffer[0]
    @mKeyBuffer=@mKeyBuffer[1..]
    @mCpu.regC key

  #
  # Handles HWI #2
  #
  isPressed: () -> 
    @mCpu.regC 0

  #
  # Handles HWI #3
  #
  setInterrupts: () -> 
    @mIrqMsg = @mCpu.regB()

exports.GenericKeyboard = GenericKeyboard
