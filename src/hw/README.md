# hcf Device Interface
Many standard peripherals are included, however the basic device interface is also
exported to allow for custom components to be created.

# hcf.Hw.Device (device.coffee)
Defines the generic device interface. A well-formed device will subclass this class and provide the following methods:
    
    id: () -> 0xcafebabe    # 32 bit device id
    mfgr: () -> 0xdeadbeef  # 32 bit manufacturer id
    ver: () -> 0xf00d       # 16 bit version id
    hwInterrupt: () ->      # Called by cpu when hwi is invoked on this device

Some useful functions:

    # interrupts the cpu with message 'n'
    interrupt: (n) ->
   
    # Maps memory from base to bese+len to this device. On a read/write to any
    # address in this range, cb is invoke (as cb(offset) to read, or
    # cb(offest, val) to write, where offset is a relative offeset from base.
    mamMemory: (base, len, cb) ->
    
    # Unmaps memory that was previous mapped using "mapMemory". If any other
    # address is passed, then the behavior is undefined.
    unmapMemory: (base) ->
    
    # Called by the cpu to return to a power-on reset state. Override to provide
    # any reset logic for the device
    reset: () ->

# Included Devices
## hcf.Hw.Lem1802 (lem1802.coffee)
Implements the LEM1802 display device. This peripheral requires an HTML5 canvas element to do the
actual rendering.

    lem = new hcf.Hw.Lem1802 dcpu, $("#mycanvas")
    dcpu.addDevice lem

## hcf.Hw.GenericClock (generic-clock.coffee)
Implements a device that is compatible with the Genric Clock specification.

## hcf.Hw.GenericKeyboard (generic-keyboard) (In Progress)
Implements a device that is compatible with the Generic Keyboard specification.