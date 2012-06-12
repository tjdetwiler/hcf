; 'if*' unit test

set a, 0
set b, 0xffff
set c, 1
set x, 0

ifb b, a
  set x, 0xdead
;! assert(cpu.regX() != 0xdead);
ifc b, c
  set x, 0xbeef
;! assert(cpu.regX() != 0xbeef);
ife b, a
  set x, 0xcafe
;! assert(cpu.regX() != 0xcafe);
ifn 0, a
  set x, 0xbabe
;! assert(cpu.regX() != 0xbabe);
ifg 1, b
  set x, 0xf00d
;! assert(cpu.regX() != 0xf00d);
ifa b, a
  set x, 0x1234
;! assert(cpu.regX() != 0x1234);
ifl b, a
  set x, 0xabcd
;! assert(cpu.regX() != 0xabcd);
ifu a, b
  set x, 0x5678
;! assert(cpu.regX() != 0x5678);
;! pass();


:crash set pc, crash
