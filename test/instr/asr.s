; 'asr' unit test

set a, 0x2
set b, 0xf003
asr b, a
;! assert(cpu.regA() == 0x2)
;! assert(cpu.regB() == 0xfc00)
;! assert(cpu.regEX() == 0xc000)

set a, 0x1
set b, 0x6
asr b, a
;! assert(cpu.regA() == 0x1)
;! assert(cpu.regB() == 0x3)
;! assert(cpu.regEX() == 0x0)
;! pass()

:crash set pc, crash
