; Subtraction test

; Some real basic stuff
set a, 1
set b, 2
sub b, a
;! assert(cpu.regA() == 1);
;! assert(cpu.regB() == 1);

; Negative
set a, 100
set b, 2
sub b, a
;! assert(cpu.regA()  == 100);
;! assert(cpu.regB()  == 0xff9e);
;! assert(cpu.regEX() == 0xffff);
;! pass()

:crash set pc, crash
