
$ = require 'jquery-browserify'
dcpu = require '../dcpu'
dasm = require '../dcpu-disasm'
decode = require '../dcpu-decode'
cpu = new dcpu.Dcpu16()
prog = [
    0x7c01, 0x0030, 0x7de1, 0x1000, 0x0020, 0x7803, 0x1000, 0xc00d,
    0x7dc1, 0x001a, 0xa861, 0x7c01, 0x2000, 0x2161, 0x2000, 0x8463,
    0x806d, 0x7dc1, 0x000d, 0x9031, 0x7c10, 0x0018, 0x7dc1, 0x001a,
    0x9037, 0x61c1, 0x7dc1, 0x001a, 0x0000, 0x0000, 0x0000, 0x0000
]
cpu.loadBinary prog

onExec = (i) ->
  disasm = dasm.Disasm.ppInstr i
  $(".instruction").removeClass "current-instruction"
  id = "#pc#{i.addr()}"
  $(id).addClass "current-instruction"

cpu.onPostExec onExec

regs = []

updateRegs = () ->
  for v,i in regs
    v.html('0x'+dasm.Disasm.fmtHex cpu.reg(i))

updateDisasm = () ->
  parent = $("#disasm")
  disasm = ""
  addr = 0
  istream = new decode.IStream cpu.mMemory
  while s = dasm.Disasm.ppNextInstr istream
    child = $ "<span
 id='pc#{addr}'
 class='instruction current-instruction'>
#{dasm.Disasm.fmtHex addr} | #{s}</span><br>"
    parent.append child
    addr = istream.index()

$ () ->
  regs = [
    ($ "#RegA"),
    ($ "#RegB"),
    ($ "#RegC"),
    ($ "#RegX"),
    ($ "#RegY"),
    ($ "#RegZ"),
    ($ "#RegI"),
    ($ "#RegJ"),
    ($ "#RegPC"),
    ($ "#RegSP"),
    ($ "#RegO")]
  updateRegs()
  updateDisasm()

  $("#btnStep").click (()->
    cpu.step()
    updateRegs())


