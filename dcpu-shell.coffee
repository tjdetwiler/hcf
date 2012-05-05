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

  do_step: (toks) ->
    @dcpu.step()

  help_step: () ->
    console.log "Executes a single DCPU-16 instruction"

new Dcpu16Shell().cmdloop()
