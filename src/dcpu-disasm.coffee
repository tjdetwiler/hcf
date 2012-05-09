#
# dcpu-dasm.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# DCPU-16 Disassembly/Decode Logic
#
# This file should be made available for web-deployment, so no node.js library
# fuctions should be used.
#

Module = {}

decode = require './dcpu-decode'

Instr = decode.Instr

class Disasm
  @OPC_DISASM = [
   "ADV", "SET", "ADD", "SUB", "MUL", "DIV", "MOD", "SHL",
   "SHR", "AND", "BOR", "XOR", "IFE", "IFN", "IFG", "IFB"]

  @ADV_OPC_DISASM = [
   "RSV", "JSR"]

  @REG_DISASM = [
   "A", "B", "C", "X", "Y", "Z", "I", "J", "PC", "SP", "O"]

  #
  # Formats a number to be a 2B hex format
  #
  @fmtHex: (n, pad=true) ->
    str = n.toString 16
    p = ""
    if pad
      p = p + "0" for _ in [0..4-str.length]
    p[1..]+str

  @ppInstr: (stream) ->
    i = new Instr stream
    if i.opc() == 0
      if i.valA().raw() == 0
        return ""
      op = Disasm.ADV_OPC_DISASM[i.valA().raw()]
      va = Disasm.ppValue i.valB()
      "#{op} #{va}"
    else
      op = Disasm.OPC_DISASM[i.opc()]
      console.lo
      va = Disasm.ppValue i.valA()
      vb = Disasm.ppValue i.valB()
      "#{op} #{va}, #{vb}"

  @ppValue: (val) ->
    enc = val.raw()
    v = ""
    if 0x00 <= enc <= 0x07
      v = Disasm.REG_DISASM[enc]
    else if 0x08 <= enc <= 0x0f
      reg = Disasm.REG_DISASM[enc-0x8]
      v = "[#{reg}]"
    else if 0x10 <= enc <= 0x17
      lit = val.mNext.toString 16
      reg = Disasm.REG_DISASM[enc-0x10]
      v = "[0x#{lit}+#{reg}]"
    else if enc == 0x18
      v = "POP"
    else if enc == 0x19
      v = "PEEK"
    else if enc == 0x1a
      v = "PUSH"
    else if enc == 0x1b
      v = "SP"
    else if enc == 0x1c
      v = "PC"
    else if enc == 0x1d
      v = "O"
    else if enc == 0x1e
      lit = val.mNext.toString 16
      v = "[0x#{lit}]"
    else if enc == 0x1f
      lit = val.mNext.toString 16
      v = "0x#{lit}"
    else if 0x20 <= enc <= 0x3f
      lit = val.mNext.toString 16
      v = "0x#{(enc - 0x20).toString 16}"
    return v


exports.Disasm = Disasm
