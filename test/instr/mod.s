; 'mod' unit test

set a, 0
set b, 0xffff
mod b, a
;! assert(cpu.regB() == 0);
;! assert(cpu.regA() == 0);

set a, 0x1234
set b, 0x43
mod a, b
;! assert(cpu.regA() == 0x25);
;! assert(cpu.regB() == 0x43);
;! assert(cpu.regEX() == 0);
;! pass();

:crash set pc, crash
