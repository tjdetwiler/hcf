; 'dvi' unit test

set a, 0xfff8
set b, 0x2
dvi a, b
;! assert(cpu.regA() == 0xfffc)
;! assert(cpu.regB() == 0x2)

set a, 18
set b, 54
dvi b, a
;! assert(cpu.regA() == 18)
;! assert(cpu.regB() == 3);
;! pass()

:crash set pc, crash
