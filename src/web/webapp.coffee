#
# web/webapp.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# HTML/JS front-end. 
#
Module = {}

# Imports
$         = require 'jquery-browserify'
dcpu      = require '../dcpu'
dasm      = require '../dcpu-disasm'
decode    = require '../dcpu-decode'
asm       = require '../dcpu-asm'
Lem1802   = require('../hw/lem1802').Lem1802
GenericClock = require('../hw/generic-clock').GenericClock
GenericKeyboard = require('../hw/generic-keyboard').GenericKeyboard

# Globals
class DcpuWebapp
  constructor: () ->
    @mAsm = null
    @mRunTimer = null
    @mRegs = [
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
      ($ "#RegEX")]
    @mCpu = new dcpu.Dcpu16()
    @setupCallbacks()
    @setupCPU()
    @updateCycles()
    @assemble()
    @updateRegs()
    @dumpMemory()

  #
  # Refresh the Register Output
  #
  updateRegs: () ->
    for v,i in @mRegs
      v.html('0x'+dasm.Disasm.fmtHex @mCpu.readReg(i))

  #
  # Refresh the Cycle-Count Output
  #
  updateCycles: () -> $("#cycles").html "#{@mCpu.mCycles}"

  #
  # Refresh the Memory-Dump Output
  #
  dumpMemory: () ->
    base = $("#membase").val()
    base = 0 if not base
    base = parseInt base
    body = $ "#memdump-body"
    body.empty()
    for r in [0..4]
      row = $ "<tr><td>#{dasm.Disasm.fmtHex base + (r*8)}</td></tr>"

      for c in [0..7]
        v = @mCpu.readMem base + (r*8) + c
        html = "<td>#{dasm.Disasm.fmtHex v}</td>"
        col = $ html
        row.append col
      body.append row

  #
  # Displays an error message on the page.
  #
  error: (msg) -> $("#asm-error").html msg

  #
  # Load text from UI, assemble it, and load it into the CPU.
  #
  assemble: () ->
    @mAsm = new asm.Assembler()
    state = @mAsm.assemble window.editor.getValue()
    if state.result isnt "success"
      @error "Error: Line #{state.line}: #{state.message}"
    @mCpu.loadBinary state.code
    @mCpu.regPC 0
    @dumpMemory()
    @updateRegs()

  #
  # Run the CPU at approximately 100KHz
  #
  run: () ->
    app = this
    cb = () ->
      for i in [0..10001]
        app.mCpu.step()
      app.updateRegs()
      app.updateCycles()
    if @mRunTimer then clearInterval @timer
    @mRunTimer = setInterval cb, 50

  step: () ->
    @mCpu.step()
    @updateRegs()

  stop: () ->
    if @mRunTimer
      clearInterval @mRunTimer
      @mRunTimer = null

  #
  # Resets the CPU and the UI
  #
  reset: () ->
    @mCpu.reset()
    @assemble()
    @updateCycles()

  #
  # Init CPU and Devices
  #
  setupCPU: () ->
    # Setup Devices
    @mCpu.addDevice new Lem1802 @mCpu, $("#framebuffer")[0]
    @mCpu.addDevice new GenericClock @mCpu
    @mCpu.addDevice new GenericKeyboard @mCpu

  #
  # Wire up DOM event callbacks.
  #
  setupCallbacks: () ->
    app = this
    $("#membase").change () ->
      base = $("#membase").val()
      base = 0 if not base
      app.dumpMemory parseInt base
    $("#btnRun").click () -> app.run()
    $("#btnStep").click ()-> app.step()
    $("#btnStop").click () -> app.stop()
    $("#btnReset").click () -> app.reset()
    $("#btnAssemble").click () -> app.assemble()


#
# On Load
#
$ () -> new DcpuWebapp()
