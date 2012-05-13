
$ = require 'jquery-browserify'
dcpu = require '../dcpu'
dasm = require '../dcpu-disasm'
decode = require '../dcpu-decode'
asm = require '../dcpu-asm'
cpu = new dcpu.Dcpu16()

onExec = (i) ->
  disasm = dasm.Disasm.ppInstr i
  $(".instruction").removeClass "current-instruction"
  id = "#pc#{i.addr()}"
  $(id).addClass "current-instruction"

cpu.onPostExec onExec

regs = []

updateRegs = () ->
  for v,i in regs
    v.html('0x'+dasm.Disasm.fmtHex cpu.readReg(i))

updateDisasm = () ->
  parent = $("#disasm")
  disasm = ""
  addr = 0
  istream = new decode.IStream cpu.mMemory
  while s = dasm.Disasm.ppNextInstr istream
    child = $ "<span
 id='pc#{addr}'
 class='instruction'>
#{dasm.Disasm.fmtHex addr} | #{s}</span><br>"
    parent.append child
    addr = istream.index()

dumpMemory = (base) ->
  body = $ "#memdump-body"
  body.empty()
  for r in [0..4]
    row = $ "<tr><td>#{dasm.Disasm.fmtHex base+ (r*8)}</td></tr>"

    for c in [0..7]
      v = cpu.readMem base + (r*8) + c
      html = "<td>#{dasm.Disasm.fmtHex v}</td>"
      col = $ html
      row.append col
    body.append row

assemble = (text) ->
  prog = new asm.Assembler().assemble(text)
  cpu.loadBinary prog
  cpu.regPC 0
  updateRegs()

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

  btnAssembleClick = () ->
    assemble window.editor.getValue()
    base = $("#membase").val()
    base = 0 if not base
    dumpMemory parseInt base

  updateRegs()
  updateDisasm()
  dumpMemory 0
  btnAssembleClick()

  $("#btnStep").click ()->
    cpu.step()
    updateRegs()
  $("#btnAssemble").click btnAssembleClick
  $("#membase").change () ->
    base = $("#membase").val()
    base = 0 if not base
    dumpMemory parseInt base

