; 'mli' unit test

set a, 0xffff ; -1
set b, 0xffff ; -1
mli b, a

;! assert(cpu.regA() == 0xffff);
;! assert(cpu.regB() == 1);
;! assert(cpu.regEX() == 0);
;! pass();

:crash set pc, crash
