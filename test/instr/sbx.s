; 'sbx' unit test

set b, 1
set a, 3
set ex, 4
sbx b, a
;! assert(cpu.regA() == 3);
;! assert(cpu.regB() == 2);
;! assert(cpu.regEX() == 0x0);

set b, 1
set a, 3
sbx b, a
;! assert(cpu.regA() == 3);
;! assert(cpu.regB() == 0xfffe);
;! assert(cpu.regEX() == 0xffff);

set b, 0x5
set a, 0x1
set ex, 4
sbx b, a
;! assert(cpu.regA() == 1);
;! assert(cpu.regB() == 0x8);
;! assert(cpu.regEX() == 0x0);
;! pass()

:crash set pc, crash
