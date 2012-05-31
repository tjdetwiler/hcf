#
# Export all public Classes.
#
exports = {
  Dcpu16: require('./src/dcpu').Dcpu16,
  Disasm: require('./src/dcpu-disasm').Disasm,
  Assembler: require('./src/dcpu-asm').Assembler,
  JobLinker: require('./src/dcpu-asm').JobLinker,
  Instr: require('./src/dcpu-decode').Instr,
  Value: require('./src/dcpu-decode').Value,
  Hw: {
    Device: require('./src/hw/device').Device
    Lem1802: require('./src/hw/lem1802').Lem1802,
    GenericClock: require('./src/hw/generic-clock').GenericClock,
    GenericKeyboard: require('./src/hw/generic-keyboard').GenericKeyboard
  }
}

#
# This allows us to 'browserify' this entire library for inclusion
# in a web browser. Classes can be accessed via window.hcf.Class
#
if window? then window.hcf = exports

