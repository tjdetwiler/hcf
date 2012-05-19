
:start    set a, 0
          ifn a, 0
          ifn a, 0
          ifn a, 0
          ifn a, 0
          ifn a, 0
          ifn a, 0
          ifn a, 0
          ifn a, 0
          ifn a, 0
          ifn a, 0
          set pc, bad
          set pc, good

:bad      set a, 10  
          set pc, crash

:good     set b, 0xffff
          set pc, crash

:crash    set pc, crash
