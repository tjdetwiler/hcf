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

class Device
  constructor: (name="?", cpu) ->
    @mName = name
    @mCpu = cpu

  #
  # Hardware ID information. This MUST be overridden by devices
  #
  id: () -> 0
  mfgr: () -> 0
  ver: () -> 0

  #
  # Handles a HW interrupt from the CPU
  #
  hwInterrupt: () -> undefined

  #
  # Resets a peripheral
  #
  reset: () -> undefined

  #
  # Loads CPU registers with HW parameters
  #
  query: () -> @fromMfgrId @mfgr(), @id(), @ver()

  #
  # Sends an interrupt to the CPU
  #
  interrupt: (m) -> @mCpu.interrupt m

  mapMemory: (base, len, cb) -> @mCpu.mapDevice base, len, cb
  unmapMemory: (base) -> @mCpu.unmapDevice base

  #
  # Helper function for 'query' to decompose HW id values into
  # what needs loaded into registers
  #
  fromMfgrId: (mfgr, id, ver) ->
    @mCpu.regA (id) & 0xffff
    @mCpu.regB (id >> 16) & 0xffff
    @mCpu.regC ver
    @mCpu.regX (mfgr) & 0xffff
    @mCpu.regY (mfgr >> 16) & 0xffff

exports.Device = Device
