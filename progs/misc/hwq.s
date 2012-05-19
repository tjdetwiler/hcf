
:start  hwn j
        set i, 0

:loop   ife i, j
        set pc, crash
        hwq i
        add i, 1
        set pc, loop

:crash  set pc, crash
