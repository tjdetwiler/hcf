; 'adx' unit test

set b, 1
set a, 3
set ex, 4
adx b, a
;! assert(cpu.regA() == 3);
;! assert(cpu.regB() == 8);
;! assert(cpu.regEX() == 0);

set b, 1
set a, 3
adx b, a
;! assert(cpu.regA() == 3);
;! assert(cpu.regB() == 4);
;! assert(cpu.regEX() == 0);

set b, 0xfffd
set a, 0x1
set ex, 4
adx b, a
;! assert(cpu.regA() == 1);
;! assert(cpu.regB() == 0x2);
;! assert(cpu.regEX() == 1);
;! pass()

:crash set pc, crash
