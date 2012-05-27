#
# web/webapp.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# HTML/JS front-end. 
#
Module = {}

# Imports
dcpu      = require '../dcpu'
dasm      = require '../dcpu-disasm'
decode    = require '../dcpu-decode'
asm       = require '../dcpu-asm'
Lem1802   = require('../hw/lem1802').Lem1802
GenericClock = require('../hw/generic-clock').GenericClock
GenericKeyboard = require('../hw/generic-keyboard').GenericKeyboard

#
# We rely on jQuery being already loaded
#
$         = window.$

class File
  constructor: (name) ->
    @mText = ""
    @mName = name

    id = name.split(".").join("_")
    # Add to project file listing
    $('#projFiles').append(
      "<li><a href='#'><i class='icon-file file-close'></i>#{name}</a></li>")

    # Add to file tabs
    link = $("<a href='#openFile-#{id}' data-toggle='tab'>#{name}<i class='icon-remove'></i></a>")
    node =  $("<li></li>").append link
    $('#openFiles').append node
    $("#openFiles a").click (e) ->
      e.preventDefault()
      $(this).tab 'show'

    # Create Editor
    editor = $("<textarea id='tmp'></textarea>")[0]
    pane = $("<div id='openFile-#{id}' class='tab-pane'></div>")
    pane.append editor
    $('#openFileContents').append pane[0]

    @mEditor = CodeMirror.fromTextArea(editor, {
      lineNumbers: true
      mode: "text/x-dasm"
      keyMap: "vim"
      onGutterClick: (cm,n,e) ->
        info = cm.lineInfo n
        if info.markerText
          cm.clearMarker n
        else
          cm.setMarker n, "<span style='color: #900'>●</span> %N%"
    })

    $("a[href=#openFile-#{id}").tab "show"
    $(".file-close").click () -> alert "oh hey"
    link.click()
    @mEditor.refresh()


  text: (val) ->
    if val?
      @mEditor.setValue val
    else
      @mEditor.getValue()
  name: () -> @mName
  editor: () -> @mEditor

class DcpuWebapp
  constructor: () ->
    @mAsm = null
    @mRunTimer = null
    @mRunning = false
    @mFiles = []
    @mInstrCount = 0
    @mLoopCount = 0
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
    @updateRegs()
    @dumpMemory()

    file = new File "entry.s"
    file.text demoProgram
    @mFiles.push file
    @mFiles["entry.s"] = file

    file = new File "msg.s"
    file.text demoProgramMsg
    @mFiles.push file
    @mFiles["msg.s"] = file

    @mCreateDialog = $("#newFile").modal {
      show: false }
    @mCreateDialog.hide()
    @assemble()

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
    jobs = []
    for file in @mFiles
      @mAsm = new asm.Assembler()
      jobs.push @mAsm.assemble file.text(), file.name()
    exe = asm.JobLinker.link jobs
    console.log exe
    @mCpu.loadJOB exe
    @mCpu.regPC 0
    @dumpMemory()
    @updateRegs()

  runStop: () ->
    if @mRunning
      @stop()
    else
      @run()

  #
  # Run the CPU at approximately 100KHz
  #
  run: () ->
    app = this
    cb = () ->
      app.mLoopCount++
      # FIXME: Parameterize these values (freq and step)
      target = app.mLoopCount * (100000/20)
      while app.mCpu.mCycles < target
        app.mCpu.step()
      app.updateRegs()
      app.updateCycles()

    if @mRunTimer then clearInterval @timer
    @mRunTimer = setInterval cb, 50
    $("#btnRun").html "<i class='icon-stop'></i>Stop"
    @mRunning = true

  stop: () ->
    if @mRunTimer
      clearInterval @mRunTimer
      @mRunTimer = null
    $("#btnRun").html "<i class='icon-play'></i>Run"
    @mRunning = false

  step: () ->
    @mCpu.step()
    @updateRegs()
    @updateCycles()
    i = @mCpu.next()
    info = @mCpu.addr2line i.addr()
    editor = @mFiles[info.file].editor()
    if @mActiveLine?
      @mFiles[@mActiveLine.file].editor().setLineClass(@mActiveLine.line, null, null)
    editor.setLineClass(info.line, null, "activeline")
    @mActiveLine = {file: info.file, line: info.line}

  #
  # Resets the CPU and the UI
  #
  reset: () ->
    @stop()
    @mCpu.reset()
    @assemble()
    @updateCycles()

  create: (f) ->
    file = new File f
    @mFiles.push file
    @mFiles[f] = file
    @mCreateDialog.modal "toggle"

  #
  # Init CPU and Devices
  #
  setupCPU: () ->
    # Setup Devices
    lem = new Lem1802 @mCpu, $("#framebuffer")[0]
    lem.mScale = 4
    @mCpu.addDevice lem
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
    $("#btnRun").click () -> app.runStop()
    $("#btnStop").click () -> app.runStop()
    $("#btnStep").click () -> app.step()
    $("#btnReset").click () -> app.reset()
    $("#btnAssemble").click () -> app.assemble()

#
# On Load
#
$ () ->
  window.app = new DcpuWebapp()


demoProgram = '
:start  ; Map framebuffer RAM\n
        set a, 0\n
        set b, 0x1000\n
        hwi 0\n
\n
        set a, ohhey\n
        jsr print\n
\n
        set a, 0\n
        set b, 60\n
        hwi 1\n
        set a, 1\n
:loop hwi 1\n
        set pc, loop\n
\n
:print  set b, 0\n
:print_loop\n
        set c, [a]\n
        ife c, 0\n
        set pc, pop\n
        bor c, 0x0f00\n
        set [0x1000+b], c\n
        add a, 1\n
        add b, 1\n
        set pc, print_loop\n
:crash  set pc, crash\n'
#\n
#:ohhey  dat "Generic-Clock Test"\n
#        dat 0x0'

demoProgramMsg = '
:ohhey  dat "So the linker works (kinda).", 0
'
