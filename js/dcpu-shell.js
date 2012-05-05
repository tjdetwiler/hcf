// Generated by CoffeeScript 1.3.1
(function() {
  var Dcpu16Shell, cmd, dasm, dcpu, fs,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  fs = require('fs');

  cmd = require('./cmd');

  dcpu = require('./dcpu');

  dasm = require('./dcpu-disasm');

  Dcpu16Shell = (function(_super) {

    __extends(Dcpu16Shell, _super);

    Dcpu16Shell.name = 'Dcpu16Shell';

    function Dcpu16Shell() {
      this.prompt = ">> ";
      this.dcpu = new dcpu.Dcpu16();
      this.dcpu.onPreExec(dasm.Disasm.ppInstr);
      this.intro = "\n*******************************************************\n* DCPU-16 Shell                                       *\n* Send Bugs to Tim Detwiler <timdetwiler@gamil.com>   *\n*******************************************************";
      this.wordsPerLine = 8;
    }

    Dcpu16Shell.prototype.do_load = function(toks) {
      var cpu, fn;
      fn = toks[0];
      cpu = this.dcpu;
      return fs.readFile(fn, "utf8", function(err, data) {
        if (!err) {
          return cpu.loadBinary(eval(data));
        } else {
          return console.log("Error loading binary");
        }
      });
    };

    Dcpu16Shell.prototype.do_step = function(toks) {
      return this.dcpu.step();
    };

    Dcpu16Shell.prototype.help_step = function() {
      return console.log("Executes a single DCPU-16 instruction");
    };

    Dcpu16Shell.prototype.do_regs = function(toks) {
      var f;
      f = function(r) {
        var n, pad, str, _i, _ref;
        str = r.toString(16);
        pad = "";
        for (n = _i = 0, _ref = 4 - str.length; 0 <= _ref ? _i <= _ref : _i >= _ref; n = 0 <= _ref ? ++_i : --_i) {
          pad = pad + "0";
        }
        return pad + str;
      };
      console.log("A:  0x" + (f(this.dcpu.regA())) + "\t B:  0x" + (f(this.dcpu.regB())) + "\t C: 0x" + (f(this.dcpu.regC())));
      console.log("X:  0x" + (f(this.dcpu.regX())) + "\t Y:  0x" + (f(this.dcpu.regY())) + "\t Z: 0x" + (f(this.dcpu.regZ())));
      console.log("I:  0x" + (f(this.dcpu.regI())) + "\t J:  0x" + (f(this.dcpu.regJ())));
      return console.log("PC: 0x" + (f(this.dcpu.regPC())) + "\t SP: 0x" + (f(this.dcpu.regSP())) + "\t O: 0x" + (f(this.dcpu.regO())));
    };

    Dcpu16Shell.prototype.help_regs = function() {
      return console.log("Print DCPU Registers.");
    };

    Dcpu16Shell.prototype.do_dump = function(toks) {
      var a, f, n, x, y, _i, _j, _ref, _ref1, _results;
      f = dasm.Disasm.fmtHex;
      a = parseInt(toks[0]);
      if (!(a != null)) {
        return help_dump();
      }
      n = toks[1] != null ? parseInt(toks[1]) : 4 * this.wordsPerLine;
      console.log("Dumping " + n + " bytes at " + (f(a)));
      _results = [];
      for (x = _i = 0, _ref = (n / this.wordsPerLine) - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; x = 0 <= _ref ? ++_i : --_i) {
        process.stdout.write("" + (f(a)) + "| ");
        for (y = _j = 0, _ref1 = this.wordsPerLine - 1; 0 <= _ref1 ? _j <= _ref1 : _j >= _ref1; y = 0 <= _ref1 ? ++_j : --_j) {
          process.stdout.write("" + (f(this.dcpu.readMem(a + y))) + " ");
        }
        process.stdout.write("\n");
        _results.push(a += this.wordsPerLine);
      }
      return _results;
    };

    Dcpu16Shell.prototype.help_dump = function() {
      return console.log("Dump memory.");
    };

    Dcpu16Shell.prototype.do_shell = void 0;

    Dcpu16Shell.prototype.help_shell = void 0;

    return Dcpu16Shell;

  })(cmd.Cmd);

  new Dcpu16Shell().cmdloop();

}).call(this);
