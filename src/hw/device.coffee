#
# hw/device.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# Define generic hardware device interface.
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
  # Loads CPU registers with HW parameters
  #
  query: () -> @fromMfgrId @mfgr(), @id(), @ver()

  #
  # Handles a HW interrupt from the CPU
  #
  hwInterrupt: () -> undefined

  #
  # Sends an interrupt to the CPU
  #
  interrupt: (m) -> undefined

  mapMemory: (base, len) -> undefined
  unmapMemory: (base) -> undefined

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
