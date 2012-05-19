
:start  ; Map framebuffer RAM
        set a, 0
        set b, 0x1000
        hwi 0

        set i, 0
:loop   set [0x1000], 0
        add 1, i
        ifn i, 10
        set pc, loop

:crash  set pc, crash
