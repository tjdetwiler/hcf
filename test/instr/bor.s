; 'bor' unit test

set a, 0x5555
set b, 0xaaaa
bor a, b
;! assert(cpu.regA() == 0xffff)
;! assert(cpu.regB() == 0xaaaa)

set a, 0x3381
set b, 0x5527
bor a, b
;! assert(cpu.regA() == 0x77a7)
;! assert(cpu.regB() == 0x5527)
;! pass()

:crash set pc, crash
