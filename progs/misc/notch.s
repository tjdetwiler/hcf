        SET A, 0x30
        SET [ 0x1000 ] , 0x20
        SUB A,[0x1000]
        IFN A,0x10
        SET PC,crash

        SET I,10
        SET A,0x2000

:loop   SET [ 0x2000 + I ] , [ A ]
        SUB I,1
        IFN I,0
        SET PC,loop

        ; Call a subroutine
        SET X,0x4
        JSR testsub
        SET PC,crash

:testsub
        SHL X,4
        SET PC,POP

:crash  SET PC,crash
