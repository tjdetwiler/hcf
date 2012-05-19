
:start  set a, 0
        set b, 0x1000
        jsr map

        set a, 1
        set b, 0x2000
        jsr map

        set a, 2
        set b, 0x3000
        jsr map 

        ; These should each to to a mapped region
        set [0x1000], 0x10
        set [0x2000], 0x10
        set [0x3000], 0x10

        set a, 0
        set b, 0
        jsr map

        set a, 1
        set b, 0
        jsr map

        set a, 2
        set b, 0
        jsr map

        ; These should to to general purpose ram
        set [0x1000], 0x10
        set [0x2000], 0x10
        set [0x3000], 0x10

        set pc, crash

; map(mode, base);
; Modes: 0 = SCREEN_RAM
;        1 = FONT_RAM
;        2 = PALETTE_RAM
:map
        hwi 0
        set pc, pop

:crash  set pc, crash
