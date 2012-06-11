; Multiplication test

; Overflow test
set a, 0xffff
set b, 0xffff
mul b, a
;! assert(cpu.regB() == 1);
;! assert(cpu.regEX() == 0xfffe);
;! pass()

:crash set pc, crash
