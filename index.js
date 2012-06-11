//
// Export all public Classes.
//
var exports = module.exports = {
  Dcpu16: require('./lib/dcpu').Dcpu16,
  Disasm: require('./lib/dcpu-disasm').Disasm,
  Assembler: require('./lib/dcpu-asm').Assembler,
  JobLinker: require('./lib/dcpu-asm').JobLinker,
  Instr: require('./lib/dcpu-decode').Instr,
  Value: require('./lib/dcpu-decode').Value,
  Hw: {
    Device: require('./lib/hw/device').Device,
    Lem1802: require('./lib/hw/lem1802').Lem1802,
    GenericClock: require('./lib/hw/generic-clock').GenericClock,
    GenericKeyboard: require('./lib/hw/generic-keyboard').GenericKeyboard
  }
}

//
// This allows us to 'browserify' this entire library for inclusion
// in a web browser. Classes can be accessed via window.hcf.Class
//
try {
  window.hcf = exports;
} catch (e) {}
