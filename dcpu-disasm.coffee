#
# dcpu-dasm.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# DCPU-16 Disassembly/Decode Logic
#
# This file should be made available for web-deployment, so no node.js library
# fuctions should be used.
#
# TODO: Figure out how to do require and exports while still supporting
#       browsers
#

Module = {}

dcpu = require './dcpu'

class Disasm
  @OPC_DISASM = [
   "ADV", "SET", "ADD", "SUB", "MUL", "DIV", "MOD", "SHL",
   "SHR", "AND", "BOR", "XOR", "IFE", "IFN", "IFG", "IFB"]

  @ADV_OPC_DISASM = [
   "RSV", "JSR"]

  @REG_DISASM = [
   "A", "B", "C", "X", "Y", "Z", "I", "J", "PC", "SP", "O"]

  @ppInstr: (instr) ->
    if instr.mOpc == 0
      # Adv Opc
      process.stdout.write Disasm.ADV_OPC_DISASM[instr.mValA.raw()]
      process.stdout.write " "
      Disasm.ppValue instr.mValB
      process.stdout.write "\n"
    else
      process.stdout.write Disasm.OPC_DISASM[instr.mOpc]
      process.stdout.write " "
      Disasm.ppValue instr.mValA
      process.stdout.write ", "
      Disasm.ppValue instr.mValB
      process.stdout.write "\n"

  @ppValue: (val) ->
    enc = val.raw()
    if 0x00 <= enc <= 0x07
      process.stdout.write Disasm.REG_DISASM[enc]
    else if 0x08 <= enc <= 0x0f
      process.stdout.write "["
      process.stdout.write Disasm.REG_DISASM[enc-0x8]
      process.stdout.write "]"
    else if 0x10 <= enc <= 0x17
      process.stdout.write "["
      process.stdout.write "0x" + val.mNext.toString 16
      process.stdout.write "+"
      process.stdout.write Disasm.REG_DISASM[enc-0x10]
      process.stdout.write "]"
    else if enc == 0x18
      process.stdout.write "POP"
    else if enc == 0x19
      process.stdout.write "PEEK"
    else if enc == 0x1a
      process.stdout.write "PUSH"
    else if enc == 0x1b
      process.stdout.write "SP"
    else if enc == 0x1c
      process.stdout.write "PC"
    else if enc == 0x1d
      process.stdout.write "O"
    else if enc == 0x1e
      process.stdout.write "["
      process.stdout.write "0x" + val.mNext.toString 16
      process.stdout.write "]"
    else if enc == 0x1f
      process.stdout.write "0x" + val.mNext.toString 16
    else if 0x20 <= enc <= 0x3f
      process.stdout.write "0x" + (enc - 0x20).toString 16

exports.Disasm = Disasm
