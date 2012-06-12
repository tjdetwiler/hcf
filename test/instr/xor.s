; 'xor' unit test

; Basic tests
set a, 0xffff
set b, 0xffff
xor b, a
;! assert(cpu.regA() == 0xffff);
;! assert(cpu.regB() == 0x0);

set a, 0xf0f0
set b, 0xffff
xor b, a
;! assert(cpu.regA() == 0xf0f0);
;! assert(cpu.regB() == 0x0f0f);
;! pass();

:crash set pc, crash
