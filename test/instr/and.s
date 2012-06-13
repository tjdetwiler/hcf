; 'and' unit test

set a, 0x5555;
set b, 0xaaaa
and a, b
;! assert(cpu.regA() == 0)
;! assert(cpu.regB() == 0xaaaa)

set a, 0x5555
set b, 0x5555
and a, b
;! assert(cpu.regA() == 0x5555)
;! assert(cpu.regB() == 0x5555)

;! pass()

:crash set pc, crash
