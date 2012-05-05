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
    @dcpu.onPreExec dasm.Disasm.ppInstr
    @intro = 
    """

      *******************************************************
      * DCPU-16 Shell                                       *
      * Send Bugs to Tim Detwiler <timdetwiler@gamil.com>   *
      *******************************************************
    """

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
    #
    # Blegh, JS/Node don't seem to have built-in support for padding
    #
    f = (r) ->
      str = r.toString 16
      pad = ""
      pad = pad + "0" for n in [0..4-str.length]
      pad+str
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

  #
  # Disable "shell" command
  #
  do_shell: undefined
  help_shell: undefined

new Dcpu16Shell().cmdloop()
