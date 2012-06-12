hcf
===

Dcpu16 library written in CoffeeScript. The hcf library provides an emulator,
assembler, and disassembler compliant with v1.7 of the DCPU spec.

# Installing - npm (Javascript/Production)
    npm install hcf

# Installing - git (Coffeescript/Development)
    git clone git://github.com/tjdetwiler/hcf.git hcf
    cd hcf
    cake install # install node_modules
    cake all     # build lib/ directory
    
# Basic Usage (Emulator)

    hcf = require('hcf');
  
    prog = [];
    dcpu = new hcf.Dcpu16();
    dcpu.loadBinary(prog);
    dcpu.run();

The above code would execute a DCPU binary at approximately 100KHz.
You can hook into execution events by providing callback methods:

    // onPreExec - Called right before executing Instr 'i'
    dcpu.onPreExec(function(cpu, i) {});
    // onPostExec - Called right after exectuing Instr 'i'
    dcpu.onPostExec(function(cpu, i) {});
    // onPeriondic - Called every 10,000 instructions or so.
    dcpu.onPeriodic(function(cpu) {});
    // onCondFail - Called when an instruction is skipped via conditional execution
    dcpu.onCondFail(function(cpu, i) {});
    // onInstrUndefined - Called when an undefined instruction is executed.
    //   The callback must return true if it wants the CPU to fetch the next instruction.
    //   if a non-true value is returned and the callback doesn't update cpu.mDecoded, the
    //   cpu will be stuck in an infinite loop.
    onInstrUndefined(function(cpu, i) { return true; });

Standard hardware devices are provided as well:

    // LEM requires an HTML5 canvas element
    canvs = $("#myCanvas");
    dcpu.addDevice(new hcf.Hw.Lem1802(dcpu, canvas));
    dcpu.addDevice(new hcf.Hw.GenericClock(dcpu));
    dcpu.addDevice(new hcf.Hw.GenericKeyboard(dcpu));

Register/Memory accessors:

    // Read registers
    a = dpcu.regA();
    b = dcpu.regB();
    c = dcpu.regC();
  
    // Write Registers
    dcpu.regX(0xdead);
    dcpu.regY(dcpu.regA());
    dcpu.regZ(0);
    
    // Special registers too
    pc = dpcu.regPC();
    sp = dcpu.regSP();
    ex = dcpu.regEX();
    ia = dcpu.regIA();
    
    // Memory
    addr = 0x1234;
    word = dcpu.readMem(addr);
    dcpu.writeMem(addr, 0xbeef);
    
Breakpoints for read/write/execute events (In Development):

    // Sets a breakpoint
    // addr - memory address
    // mode - "r", "w", "x", or any combination of them.
    dcpu.breakpoint(0x1000, "rwx", function(cpu, addr, mode) { });
