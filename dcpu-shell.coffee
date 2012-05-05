#
# dcpu-shell.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# DCPU-16 node.js front-end.
#
# Provide an interface to interact with a DCPU-16 model.
#

fs = require 'fs'
cmd = require './cmd'
dcpu = require './dcpu'
dasm = require './dcpu-disasm'

class Dcpu16Shell extends cmd.Cmd
  constructor: () ->
    @prompt = ">> " 
    @dcpu = new dcpu.Dcpu16()
    @dcpu.onPreExec (i) -> console.log dasm.Disasm.ppInstr i
    @dcpu.onCondFail (i) -> console.log "::SKIP: #{dasm.Disasm.ppInstr i}"
    @intro = 
    """

      *******************************************************
      * DCPU-16 Shell                                       *
      * Send Bugs to Tim Detwiler <timdetwiler@gamil.com>   *
      *******************************************************
    """
    @wordsPerLine = 8

  do_load: (toks) ->
    fn = toks[0]
    cpu = @dcpu
    fs.readFile fn, "utf8", (err, data) ->
      if not err
        cpu.loadBinary eval data
      else
        console.log "Error loading binary"

  do_step: (toks) ->
    @dcpu.step()
  help_step: () ->
    console.log "Executes a single DCPU-16 instruction"

  do_regs: (toks) ->
    f = dasm.Disasm.fmtHex
    console.log "A:  0x#{f @dcpu.regA()}\t
 B:  0x#{f @dcpu.regB()}\t
 C: 0x#{f @dcpu.regC()}"
    console.log "X:  0x#{f @dcpu.regX()}\t
 Y:  0x#{f @dcpu.regY()}\t
 Z: 0x#{f @dcpu.regZ()}"
    console.log "I:  0x#{f @dcpu.regI()}\t
 J:  0x#{f @dcpu.regJ()}"
    console.log "PC: 0x#{f @dcpu.regPC()}\t
 SP: 0x#{f @dcpu.regSP()}\t
 O: 0x#{f @dcpu.regO()}"
  help_regs: () -> console.log "Print DCPU Registers."

  do_dump: (toks) ->
    f = dasm.Disasm.fmtHex
    a = parseInt toks[0]
    if not a?
      return help_dump()
    n = if toks[1]? then parseInt toks[1] else (4*@wordsPerLine)

    console.log "Dumping #{n} bytes at #{f a}"

    for x in [0..(n/@wordsPerLine)-1]
      process.stdout.write "#{f a}| "
      for y in [0..@wordsPerLine-1]
        process.stdout.write "#{f @dcpu.readMem a+y} "
      process.stdout.write "\n"
      a += @wordsPerLine

  help_dump: () -> console.log "Dump memory."

  #
  # Disable "shell" command
  #
  do_shell: undefined
  help_shell: undefined

new Dcpu16Shell().cmdloop()
