; 'div' unit test

set a, 0xfff8
set b, 0x2
div a, b
;! assert(cpu.regA() == 0x7ffc)
;! assert(cpu.regB() == 0x2)

set a, 18
set b, 54
div b, a
;! assert(cpu.regA() == 18)
;! assert(cpu.regB() == 3);
;! pass()

:crash set pc, crash
