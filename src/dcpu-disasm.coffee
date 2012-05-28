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

decode = require './dcpu-decode'

Instr = decode.Instr

class Disasm
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

  @ppNextInstr: (stream) -> @ppInstr new Instr stream

  @ppInstr: (i) ->
    if i.opc() == 0
      if i.valA().raw() == 0
        return ""
      op = Instr.ADV_OPS[i.valA().raw()]
      va = Disasm.ppValue i.valB()
      "#{op.id} #{va}"
    else
      op = Instr.BASIC_OPS[i.opc()]
      va = Disasm.ppValue i.valA()
      vb = Disasm.ppValue i.valB()
      "#{op.id} #{va}, #{vb}"

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
      v = enc - 0x21
      if v < 0 then v = 0xffff
      v = "0x#{v.toString 16}"
    return v


exports.Disasm = Disasm
