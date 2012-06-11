; Addition test

; Some real basic stuff
set a, 1
set b, 2
add a, b
;! assert(cpu.regA() == 3);
;! assert(cpu.regB() == 2);

; Overflow test
set a, 0xffff
set b, 0xffff
add a, b
;! assert(cpu.regA()  == 0xfffe);
;! assert(cpu.regEX() == 0x1);
;! pass()

:crash set pc, crash
