// Generated by CoffeeScript 1.3.1
(function() {
  var $, DcpuWebapp, File, GenericClock, GenericKeyboard, Lem1802, Module, asm, dasm, dcpu, decode, demoProgram, demoProgramMsg;

  Module = {};

  dcpu = require('../dcpu');

  dasm = require('../dcpu-disasm');

  decode = require('../dcpu-decode');

  asm = require('../dcpu-asm');

  Lem1802 = require('../hw/lem1802').Lem1802;

  GenericClock = require('../hw/generic-clock').GenericClock;

  GenericKeyboard = require('../hw/generic-keyboard').GenericKeyboard;

  $ = window.$;

  File = (function() {

    File.name = 'File';

    function File(name) {
      var editor, id, link, node, pane;
      this.mText = "";
      this.mName = name;
      id = name.split(".").join("_");
      $('#projFiles').append("<li><a href='#'><i class='icon-file file-close'></i>" + name + "</a></li>");
      link = $("<a href='#openFile-" + id + "' data-toggle='tab'>" + name + "<i class='icon-remove'></i></a>");
      node = $("<li></li>").append(link);
      $('#openFiles').append(node);
      $("#openFiles a").click(function(e) {
        e.preventDefault();
        return $(this).tab('show');
      });
      editor = $("<textarea id='tmp'></textarea>")[0];
      pane = $("<div id='openFile-" + id + "' class='tab-pane'></div>");
      pane.append(editor);
      $('#openFileContents').append(pane[0]);
      this.mEditor = CodeMirror.fromTextArea(editor, {
        lineNumbers: true,
        mode: "text/x-csrc",
        keyMap: "vim",
        onGutterClick: function(cm, n, e) {
          var info;
          info = cm.lineInfo(n);
          if (info.markerText) {
            return cm.clearMarker(n);
          } else {
            return cm.setMarker(n, "<span style='color: #900'>●</span> %N%");
          }
        }
      });
      $("a[href=#openFile-" + id).tab("show");
      $(".file-close").click(function() {
        return alert("oh hey");
      });
      link.click();
      this.mEditor.refresh();
    }

    File.prototype.text = function(val) {
      if (val != null) {
        return this.mEditor.setValue(val);
      } else {
        return this.mEditor.getValue();
      }
    };

    File.prototype.name = function() {
      return this.mName;
    };

    File.prototype.editor = function() {
      return this.mEditor;
    };

    return File;

  })();

  DcpuWebapp = (function() {

    DcpuWebapp.name = 'DcpuWebapp';

    function DcpuWebapp() {
      var file;
      this.mAsm = null;
      this.mRunTimer = null;
      this.mRunning = false;
      this.mFiles = [];
      this.mInstrCount = 0;
      this.mLoopCount = 0;
      this.mRegs = [$("#RegA"), $("#RegB"), $("#RegC"), $("#RegX"), $("#RegY"), $("#RegZ"), $("#RegI"), $("#RegJ"), $("#RegPC"), $("#RegSP"), $("#RegEX")];
      this.mCpu = new dcpu.Dcpu16();
      this.setupCallbacks();
      this.setupCPU();
      this.updateCycles();
      this.updateRegs();
      this.dumpMemory();
      file = new File("entry.s");
      file.text(demoProgram);
      this.mFiles.push(file);
      this.mFiles["entry.s"] = file;
      file = new File("msg.s");
      file.text(demoProgramMsg);
      this.mFiles.push(file);
      this.mFiles["msg.s"] = file;
      this.mCreateDialog = $("#newFile").modal({
        show: false
      });
      this.mCreateDialog.hide();
      this.assemble();
    }

    DcpuWebapp.prototype.updateRegs = function() {
      var i, v, _i, _len, _ref, _results;
      _ref = this.mRegs;
      _results = [];
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        v = _ref[i];
        _results.push(v.html('0x' + dasm.Disasm.fmtHex(this.mCpu.readReg(i))));
      }
      return _results;
    };

    DcpuWebapp.prototype.updateCycles = function() {
      return $("#cycles").html("" + this.mCpu.mCycles);
    };

    DcpuWebapp.prototype.dumpMemory = function() {
      var base, body, c, col, html, r, row, v, _i, _j, _results;
      base = $("#membase").val();
      if (!base) {
        base = 0;
      }
      base = parseInt(base);
      body = $("#memdump-body");
      body.empty();
      _results = [];
      for (r = _i = 0; _i <= 4; r = ++_i) {
        row = $("<tr><td>" + (dasm.Disasm.fmtHex(base + (r * 8))) + "</td></tr>");
        for (c = _j = 0; _j <= 7; c = ++_j) {
          v = this.mCpu.readMem(base + (r * 8) + c);
          html = "<td>" + (dasm.Disasm.fmtHex(v)) + "</td>";
          col = $(html);
          row.append(col);
        }
        _results.push(body.append(row));
      }
      return _results;
    };

    DcpuWebapp.prototype.error = function(msg) {
      return $("#asm-error").html(msg);
    };

    DcpuWebapp.prototype.assemble = function() {
      var exe, file, jobs, _i, _len, _ref;
      jobs = [];
      _ref = this.mFiles;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        file = _ref[_i];
        this.mAsm = new asm.Assembler();
        jobs.push(this.mAsm.assemble(file.text(), file.name()));
      }
      exe = asm.JobLinker.link(jobs);
      console.log(exe);
      this.mCpu.loadJOB(exe);
      this.mCpu.regPC(0);
      this.dumpMemory();
      return this.updateRegs();
    };

    DcpuWebapp.prototype.runStop = function() {
      if (this.mRunning) {
        return this.stop();
      } else {
        return this.run();
      }
    };

    DcpuWebapp.prototype.run = function() {
      var app, cb;
      app = this;
      cb = function() {
        var target;
        app.mLoopCount++;
        target = app.mLoopCount * (100000 / 20);
        while (app.mCpu.mCycles < target) {
          app.mCpu.step();
        }
        app.updateRegs();
        return app.updateCycles();
      };
      if (this.mRunTimer) {
        clearInterval(this.timer);
      }
      this.mRunTimer = setInterval(cb, 50);
      $("#btnRun").html("<i class='icon-stop'></i>Stop");
      return this.mRunning = true;
    };

    DcpuWebapp.prototype.stop = function() {
      if (this.mRunTimer) {
        clearInterval(this.mRunTimer);
        this.mRunTimer = null;
      }
      $("#btnRun").html("<i class='icon-play'></i>Run");
      return this.mRunning = false;
    };

    DcpuWebapp.prototype.step = function() {
      var editor, i, info;
      this.mCpu.step();
      this.updateRegs();
      this.updateCycles();
      i = this.mCpu.next();
      info = this.mCpu.addr2line(i.addr());
      editor = this.mFiles[info.file].editor();
      if (this.mActiveLine != null) {
        this.mFiles[this.mActiveLine.file].editor().setLineClass(this.mActiveLine.line, null, null);
      }
      editor.setLineClass(info.line, null, "activeline");
      return this.mActiveLine = {
        file: info.file,
        line: info.line
      };
    };

    DcpuWebapp.prototype.reset = function() {
      this.stop();
      this.mCpu.reset();
      this.assemble();
      return this.updateCycles();
    };

    DcpuWebapp.prototype.create = function(f) {
      var file;
      file = new File(f);
      this.mFiles.push(file);
      this.mFiles[f] = file;
      return this.mCreateDialog.modal("toggle");
    };

    DcpuWebapp.prototype.setupCPU = function() {
      var lem;
      lem = new Lem1802(this.mCpu, $("#framebuffer")[0]);
      lem.mScale = 4;
      this.mCpu.addDevice(lem);
      this.mCpu.addDevice(new GenericClock(this.mCpu));
      return this.mCpu.addDevice(new GenericKeyboard(this.mCpu));
    };

    DcpuWebapp.prototype.setupCallbacks = function() {
      var app;
      app = this;
      $("#membase").change(function() {
        var base;
        base = $("#membase").val();
        if (!base) {
          base = 0;
        }
        return app.dumpMemory(parseInt(base));
      });
      $("#btnRun").click(function() {
        return app.runStop();
      });
      $("#btnStop").click(function() {
        return app.runStop();
      });
      $("#btnStep").click(function() {
        return app.step();
      });
      $("#btnReset").click(function() {
        return app.reset();
      });
      return $("#btnAssemble").click(function() {
        return app.assemble();
      });
    };

    return DcpuWebapp;

  })();

  $(function() {
    return window.app = new DcpuWebapp();
  });

  demoProgram = '\
:start  ; Map framebuffer RAM\n\
        set a, 0\n\
        set b, 0x1000\n\
        hwi 0\n\
\n\
        set a, ohhey\n\
        jsr print\n\
\n\
        set a, 0\n\
        set b, 60\n\
        hwi 1\n\
\n\
        set a, 2\n\
        set b, 2\n\
        hwi 1\n\
\n\
        ias isr\n\
\n\
        set a, 1\n\
:loop   hwi 1\n\
        set pc, loop\n\
\n\
:print  set b, 0\n\
:print_loop\n\
        set c, [a]\n\
        ife c, 0\n\
        set pc, pop\n\
        bor c, 0x0f00\n\
        set [0x1000+b], c\n\
        add a, 1\n\
        add b, 1\n\
        set pc, print_loop\n\
:crash  set pc, crash\n\
\n\
:isr    set a, pop\n\
        set pc, pop\n';

  demoProgramMsg = '\
:ohhey  dat "So the linker works (kinda).", 0\
';

}).call(this);
