#
#  Copyright(C) 2012, Tim Detwiler <timdetwiler@gmail.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This software is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this software.  If not, see <http://www.gnu.org/licenses/>.
#
Module = {}

fs              = require 'fs'
cmd             = require './cmd'
dcpu            = require '../dcpu'
asm             = require '../dcpu-asm'
decode          = require '../dcpu-decode'
dasm            = require '../dcpu-disasm'
lem1802         = require '../hw/lem1802'
generic_clock   = require '../hw/generic-clock'

IStream = decode.IStream

class Dcpu16Shell extends cmd.Cmd
  constructor: () ->
    inst = this
    @wordsPerLine = 8
    @mTrace = false
    @prompt = ">> " 
    @asm = new asm.Assembler()
    @dcpu = new dcpu.Dcpu16()
    @dcpu.addDevice new lem1802.Lem1802 @dcpu
    @dcpu.addDevice new generic_clock.GenericClock @dcpu
    @dcpu.onPreExec (cpu, i) ->
      if inst.mTrace
        console.log dasm.Disasm.ppInstr i
    @dcpu.onCondFail (cpu, i) ->
      if inst.mTrace
        console.log "::SKIP: #{dasm.Disasm.ppInstr i}"
    @intro = 
    """

      *******************************************************
      * DCPU-16 Shell                                       *
      * Send Bugs to Tim Detwiler <timdetwiler@gmail.com>   *
      *******************************************************
    """

  do_load: (toks) ->
    fn = toks[0]
    cpu = @dcpu
    fs.readFile fn, "utf8", (err, data) ->
      if not err
        cpu.loadBinary eval("(#{data})").sections[0].data
      else
        console.log "Error loading binary"
  help_load: () -> "Loads a binary into memory."

  do_asm: (toks, done) ->
    fn = toks[0]
    asm = @asm
    cpu = @dcpu
    fs.readFile fn, "utf8", (err, data) ->
      if not err
        prog = asm.assembleAndLink data
        if toks[1]?
          txt = JSON.stringify prog
          fs.writeFile toks[1], txt, (err) ->
            if err then console.log "Error writing out binary"
        else
          cpu.loadJOB prog
      else
        return console.log "Error assembling file"
      done()
  
  #
  # Disassemble
  #
  do_disasm: (toks) ->
    addr = if toks[0]? then parseInt toks[0] else 0
    istream = new IStream @dcpu.mMemory, addr

    while disasm = dasm.Disasm.ppInstr istream
      console.log "#{dasm.Disasm.fmtHex addr} | #{disasm}"
      addr = istream.index()

  #
  # Run the simulation
  #
  do_run: (toks) ->
    @mTrace = false
    @dcpu.run()
  help_run: () -> "Run the Simulator"

  #
  # Single-Step
  #
  do_step: (toks) ->
    @mTrace = true
    @dcpu.step()
  help_step: () ->
    console.log "Executes a single DCPU-16 instruction"

  #
  # Print Registers
  #
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
 SP: 0x#{f @dcpu.regSP()}"
    console.log "EX: 0x#{f @dcpu.regEX()}\t
 IA: 0x#{f @dcpu.regIA()}"
  help_regs: () -> console.log "Print DCPU Registers."

  #
  # Dump memory
  #
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

source_file = undefined
debug_mode = true
shell = new Dcpu16Shell()
init_break = false
interactive = false

for k,i in process.argv
  if k == "-f"
    source_file = process.argv[i+1]
  if k == "-b"
    init_break = true
  if k == "-i"
    interactive = true

if source_file?
  console.log "Running '#{source_file}'"
  shell.do_asm [source_file], () ->
    if not init_break
      shell.do_run()

if interactive
  shell.cmdloop()

