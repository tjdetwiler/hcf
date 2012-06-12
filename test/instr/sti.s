; 'sti' unit test

; Basic Test
set i, 5
set j, 3
sti a, 3
;! assert(cpu.regI() == 6);
;! assert(cpu.regJ() == 4);
;! assert(cpu.regA() == 3);

; Overflow Test
set i, 0xffff
set j, 0xffff
sti a, 34
;! assert(cpu.regI() == 0);
;! assert(cpu.regJ() == 0);
;! assert(cpu.regA() == 34);
;! pass(); 

:crash set pc, crash
