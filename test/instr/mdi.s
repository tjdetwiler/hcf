; 'mdi' unit test

set a, 0
set b, 0xffff
mdi b, a
;! assert(cpu.regB() == 0);
;! assert(cpu.regA() == 0);

set a, 0xfff9
set b, 16
mdi a, b

set a, a
;! assert(cpu.regA() == 0xfff9);
;! assert(cpu.regB() == 0x0010);
;! assert(cpu.regEX() == 0);
;! pass();

:crash set pc, crash
