cmd = require './cmd'
dcpu = require './dcpu'

program = [
  0x7c01, 0x0030, 0x7de1, 0x1000, 0x0020, 0x7803, 0x1000, 0xc00d,
  0x7dc1, 0x001a, 0xa861, 0x7c01, 0x2000, 0x2161, 0x2000, 0x8463,
  0x806d, 0x7dc1, 0x000d, 0x9031, 0x7c10, 0x0018, 0x7dc1, 0x001a,
  0x9037, 0x61c1, 0x7dc1, 0x001a, 0x0000, 0x0000, 0x0000, 0x0000
]

class Dcpu16Shell extends cmd.Cmd
  constructor: () ->
    @prompt = ">> " 
    @dcpu = new dcpu.Dcpu16(program)
    @intro = 
    """

      *******************************************************
      * DCPU-16 Shell                                       *
      * Send Bugs to Tim Detwiler <timdetwiler@gamil.com>   *
      *******************************************************
    """

  do_step: (toks) ->
    @dcpu.step()

  help_step: () ->
    console.log "Executes a single DCPU-16 instruction"

new Dcpu16Shell().cmdloop()
