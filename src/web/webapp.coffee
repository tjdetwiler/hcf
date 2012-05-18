
$         = require 'jquery-browserify'
dcpu      = require '../dcpu'
dasm      = require '../dcpu-disasm'
decode    = require '../dcpu-decode'
asm       = require '../dcpu-asm'
lem1802   = require '../hw/lem1802'
cpu = new dcpu.Dcpu16()
cpu.onPostExec = (i) ->
  disasm = dasm.Disasm.ppInstr i
  $(".instruction").removeClass "current-instruction"
  id = "#pc#{i.addr()}"
  $(id).addClass "current-instruction"
  window.editor.setLineClass 1, "myclass", "myclass"
regs = []
timer = null

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

updateCycles = () ->
  cycles = "#{cpu.mCycles}"
  $("#cycles").html cycles

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
  state = new asm.Assembler().assemble(text)
  if state.result isnt "success"
    return $("#asm-error").html("Error: Line #{state.line}: #{state.message}")
  $("#asm-error").html("")
  cpu.loadBinary state.code
  cpu.regPC 0
  updateRegs()
  base = $("#membase").val()
  base = 0 if not base
  dumpMemory parseInt base

run = () ->
  cb = () ->
    for i in [0..10001]
      cpu.step()
    updateRegs()
    updateCycles()
  if timer then clearInterval timer
  timer = setInterval cb, 50
  

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
  $("#btnRun").click () ->
    run()
  $("#btnStop").click () ->
    if timer
      clearInterval timer
      timer = null

  canvas = $("#framebuffer")[0]
  fb = new lem1802.Lem1802 cpu, canvas
  cpu.addDevice fb
  updateCycles()

