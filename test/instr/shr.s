; 'shr' unit test

; Basic Test
set b, 0xffff
set a, 8
shr b, a
;! assert(cpu.regB() == 0x00ff);
;! assert(cpu.regA() == 8);
;! assert(cpu.regEX() == 0xff00);

set b, 0xffff
set a, 32
shr b, a
;! assert(cpu.regB() == 0xffff);
;! assert(cpu.regA() == 32);
;! assert(cpu.regEX() == 0x0000);
;! pass();

:crash set pc, crash
