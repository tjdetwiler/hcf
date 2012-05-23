// Generated by CoffeeScript 1.3.1
(function() {
  var Assembler, Data, Instr, Instruction, JobLinker, LitValue, MemValue, Module, RawValue, RegValue, dasm, decode;

  Module = {};

  decode = require('./dcpu-decode');

  dasm = require('./dcpu-disasm');

  Instr = decode.Instr;

  RegValue = (function() {

    RegValue.name = 'RegValue';

    function RegValue(asm, reg) {
      this.mAsm = asm;
      this.mReg = reg;
    }

    RegValue.prototype.emit = function(stream) {
      return [];
    };

    RegValue.prototype.encode = function() {
      return this.mReg;
    };

    return RegValue;

  })();

  MemValue = (function() {

    MemValue.name = 'MemValue';

    function MemValue(asm, reg, lit) {
      if (reg == null) {
        reg = void 0;
      }
      if (lit == null) {
        lit = void 0;
      }
      this.mAsm = asm;
      this.mReg = reg;
      this.mLit = lit;
    }

    MemValue.prototype.emit = function(stream) {
      if (!(this.mLit != null)) {
        return;
      }
      if (this.mLit != null) {
        return stream.push(this.mLit.value());
      }
    };

    MemValue.prototype.encode = function() {
      if ((this.mLit != null) && (this.mReg != null) && !this.mLit.isLabel()) {
        return this.mReg + 0x10;
      } else if (this.mReg != null) {
        return this.mReg + 0x8;
      } else if (this.mLit != null) {
        return 0x1e;
      } else {
        return console.log("ERROR: MemValue with corrupted state.");
      }
    };

    return MemValue;

  })();

  LitValue = (function() {

    LitValue.name = 'LitValue';

    function LitValue(asm, lit) {
      var n;
      this.mAsm = asm;
      this.mLit = lit;
      if ((n = parseInt(lit))) {
        this.mLit = n;
      }
      if (this.mLit > 0x1f || this.isLabel()) {
        this.mAsm.incPc();
      }
    }

    LitValue.prototype.isLabel = function() {
      return isNaN(this.mLit);
    };

    LitValue.prototype.value = function() {
      var addr;
      if (this.isLabel()) {
        addr = this.mAsm.lookup(this.mLit);
        if (!(addr != null)) {
          console.log("Undefined label '" + this.mLit + "'");
        }
        return addr;
      } else {
        return this.mLit;
      }
    };

    LitValue.prototype.emit = function(stream) {
      if (this.isLabel()) {
        return stream.push(this.mLit);
      } else if (this.mLit > 0x1e || this.isLabel()) {
        return stream.push(this.value());
      }
    };

    LitValue.prototype.encode = function() {
      if (this.mLit === -1) {
        return 0x20;
      } else if (this.mLit > 0x1f || this.isLabel()) {
        return 0x1f;
      } else {
        return this.mLit + 0x21;
      }
    };

    return LitValue;

  })();

  RawValue = (function() {

    RawValue.name = 'RawValue';

    function RawValue(asm, raw) {
      this.mAsm = asm;
      this.mRaw = raw;
    }

    RawValue.prototype.emit = function() {
      return;
    };

    RawValue.prototype.encode = function() {
      return this.mRaw;
    };

    return RawValue;

  })();

  Data = (function() {

    Data.name = 'Data';

    function Data(asm, dat) {
      this.mAsm = asm;
      this.mData = dat;
    }

    Data.prototype.emit = function(stream) {
      return stream.push(this.mData);
    };

    return Data;

  })();

  Instruction = (function() {

    Instruction.name = 'Instruction';

    function Instruction(asm, opc, vals) {
      this.mAsm = asm;
      this.mLine = 0;
      this.mSize = 0;
      this.mOp = opc;
      this.mVals = vals;
    }

    Instruction.prototype.emit = function(stream) {
      var enc, instr, v, _i, _len, _ref, _results;
      enc = (function() {
        var _i, _len, _ref, _results;
        _ref = this.mVals;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          v = _ref[_i];
          _results.push(v.encode());
        }
        return _results;
      }).call(this);
      instr = this.mOp | (enc[0] << 5) | (enc[1] << 10);
      stream.push(instr);
      _ref = this.mVals;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        v = _ref[_i];
        _results.push(v.emit(stream));
      }
      return _results;
    };

    return Instruction;

  })();

  JobLinker = (function() {

    JobLinker.name = 'JobLinker';

    function JobLinker() {}

    JobLinker.mergeSyms = function(a, b, o) {
      var k, v, _results;
      _results = [];
      for (k in b) {
        v = b[k];
        if (a[k] != null) {
          _results.push(console.log("Warning, redefinition of symbol '" + k + "'"));
        } else {
          _results.push(a[k] = v + o);
        }
      }
      return _results;
    };

    JobLinker.link = function(jobs) {
      var addr, code, i, job, r, syms, v, _i, _j, _len, _len1;
      code = [];
      syms = {};
      for (_i = 0, _len = jobs.length; _i < _len; _i++) {
        job = jobs[_i];
        this.mergeSyms(syms, job.sections[0].sym, code.length);
        code = code.concat(job.sections[0].data);
      }
      for (i = _j = 0, _len1 = code.length; _j < _len1; i = ++_j) {
        v = code[i];
        if ((addr = syms[v]) != null) {
          code[i] = addr;
        } else if (isNaN(v)) {
          console.log("Error: Undefined Symbol '" + v + "'");
        }
      }
      return r = {
        format: "job",
        version: 0.1,
        source: "Tims Linker",
        sections: [
          {
            name: ".text",
            data: code,
            sym: syms
          }
        ]
      };
    };

    return JobLinker;

  })();

  Assembler = (function() {

    Assembler.name = 'Assembler';

    Assembler.reg_regex = /^([a-zA-Z_]+)/;

    Assembler.ireg_regex = /^\[\s*([a-zA-Z]+|\d+)\s*\]/;

    Assembler.lit_regex = /^(0[xX][0-9a-fA-F]+|\d+)/;

    Assembler.ilit_regex = /^\[\s*(0[xX][0-9a-fA-F]+|\d+)\s*\]/;

    Assembler.arr_regex = /^\[\s*([0-9a-zA-Z]+)\s*\+\s*([0-9a-zA-Z]+)\s*\]/;

    Assembler.str_regex = /"([^"]*)"/;

    Assembler.basic_regex = /(\w+)\s+([^,]+)\s*,\s*([^,]+)/;

    Assembler.adv_regex = /(\w+)\s+([^,]+)/;

    Assembler.dir_regex = /(\.[a-zA-Z0-9]+)(.*)/;

    Assembler.LINE_PARSERS = [
      Assembler.LP_EMPTY = {
        match: /^$/,
        f: 'lpEmpty'
      }, Assembler.LP_DIRECT = {
        match: Assembler.dir_regex,
        f: 'lpDirect'
      }, Assembler.LP_DAT = {
        match: /^[dD][aA][tT].*/,
        f: 'lpDat'
      }, Assembler.LP_COMMENT = {
        match: /^;.*/,
        f: 'lpComment'
      }, Assembler.LP_LABEL = {
        match: /^:.*/,
        f: 'lpLabel'
      }, Assembler.LP_ISIMP = {
        match: Assembler.basic_regex,
        f: 'lpIBasic'
      }, Assembler.LP_IADV = {
        match: Assembler.adv_regex,
        f: 'lpIAdv'
      }
    ];

    Assembler.VALUE_PARSERS = [
      Assembler.VP_WORD = {
        match: Assembler.reg_regex,
        f: 'vpWord'
      }, Assembler.VP_IWORD = {
        match: Assembler.ireg_regex,
        f: 'vpIWord'
      }, Assembler.VP_LIT = {
        match: Assembler.lit_regex,
        f: 'vpLit'
      }, Assembler.VP_ILIT = {
        match: Assembler.ilit_regex,
        f: 'vpILit'
      }, Assembler.VP_ARR = {
        match: Assembler.arr_regex,
        f: 'vpArr'
      }
    ];

    Assembler.DIRECTS = [
      Assembler.DIR_GLOBAL = {
        id: ".globl",
        f: 'dirGlobal'
      }, Assembler.DIR_GLOBAL0 = {
        id: ".global",
        f: 'dirGlobal'
      }, Assembler.DIR_TEXT = {
        id: ".text",
        f: 'dirText'
      }, Assembler.DIR_DATA = {
        id: ".data",
        f: 'dirData'
      }
    ];

    function Assembler() {
      var op, _i, _j, _len, _len1, _ref, _ref1;
      this.mPc = 0;
      this.mText = "";
      this.mLabels = {};
      this.mExports = {};
      this.mInstrs = {};
      this.mOpcDict = {};
      this.mSect = ".text";
      _ref = Instr.BASIC_OPS;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        op = _ref[_i];
        if (op != null) {
          this.mOpcDict[op.id.toUpperCase()] = op;
        }
      }
      _ref1 = Instr.ADV_OPS;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        op = _ref1[_j];
        if (op != null) {
          this.mOpcDict[op.id.toUpperCase()] = op;
        }
      }
    }

    Assembler.prototype.label = function(name, addr) {
      if (!(this.mLabels[this.mSect] != null)) {
        this.mLabels[this.mSect] = {};
      }
      return this.mLabels[this.mSect][name] = addr;
    };

    Assembler.prototype["export"] = function(name, addr) {
      if (!(this.mExports[this.mSect] != null)) {
        this.mExports[this.mSect] = {};
      }
      return this.mExports[this.mSect][name] = addr;
    };

    Assembler.prototype.lookup = function(name) {
      return this.mLabels[this.mSect][name];
    };

    Assembler.prototype.defined = function(name) {
      return lookup(name) != null;
    };

    Assembler.prototype.incPc = function() {
      return ++this.mPc;
    };

    Assembler.prototype.processValue = function(val) {
      var match, vp, _i, _len, _ref;
      val = val.trim();
      _ref = Assembler.VALUE_PARSERS;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        vp = _ref[_i];
        if (match = val.match(vp.match)) {
          return this[vp.f](match);
        }
      }
      return console.log("Unmatched value: " + val);
    };

    Assembler.prototype.processLine = function(line) {
      var lp, match, _i, _len, _ref;
      line = line.trim();
      _ref = Assembler.LINE_PARSERS;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        lp = _ref[_i];
        if (match = line.match(lp.match)) {
          return this[lp.f](match);
        }
      }
      return console.log("Unmatched line: " + line);
    };

    Assembler.prototype.out = function(i) {
      if (!(this.mInstrs[this.mSect] != null)) {
        this.mInstrs[this.mSect] = [];
      }
      return this.mInstrs[this.mSect].push(i);
    };

    Assembler.prototype.emit = function(sec, stream) {
      var i, _i, _len, _ref, _results;
      _ref = this.mInstrs[sec];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        i = _ref[_i];
        _results.push(i.emit(stream));
      }
      return _results;
    };

    Assembler.prototype.assemble = function(text) {
      var i, l, lines, prog, r, s, sections, _i, _len, _ref;
      lines = text.split("\n");
      for (_i = 0, _len = lines.length; _i < _len; _i++) {
        l = lines[_i];
        this.processLine(l);
      }
      sections = [];
      _ref = this.mInstrs;
      for (s in _ref) {
        i = _ref[s];
        prog = [];
        this.emit(s, prog);
        sections.push({
          name: s,
          data: prog,
          sym: this.mLabels[s]
        });
      }
      return r = {
        format: "job",
        version: 0.1,
        source: "Tims Assembler",
        sections: sections
      };
    };

    Assembler.prototype.assembleAndLink = function(text) {
      var exe, job;
      job = this.assemble(text);
      return exe = JobLinker.link([job]);
    };

    Assembler.prototype.lpEmpty = function(match) {};

    Assembler.prototype.lpDirect = function(match) {
      var d, name, _i, _len, _ref;
      name = match[1].toUpperCase();
      console.log("Directive '" + name + "'");
      _ref = Assembler.DIRECTS;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        d = _ref[_i];
        if (name === d.id.toUpperCase()) {
          return this[d.f](match);
        }
      }
    };

    Assembler.prototype.lpComment = function(match) {};

    Assembler.prototype.lpDat = function(match) {
      var c, n, tok, toks, _i, _len, _results;
      toks = match[0].match(/[^ \t]+/g).slice(1).join(" ").split(",");
      _results = [];
      for (_i = 0, _len = toks.length; _i < _len; _i++) {
        tok = toks[_i];
        tok = tok.trim();
        if (tok[0] === ";") {
          break;
        }
        if (match = tok.match(Assembler.str_regex)) {
          _results.push((function() {
            var _j, _len1, _ref, _results1;
            _ref = match[1];
            _results1 = [];
            for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
              c = _ref[_j];
              _results1.push(this.out(new Data(this, c.charCodeAt(0))));
            }
            return _results1;
          }).call(this));
        } else if ((n = parseInt(tok)) != null) {
          _results.push(this.out(new Data(this, n)));
        } else {
          _results.push(console.log("Bad Data String: '" + tok + "'"));
        }
      }
      return _results;
    };

    Assembler.prototype.lpLabel = function(match) {
      var toks;
      toks = match[0].match(/[^ \t]+/g);
      this.label(toks[0].slice(1), this.mPc);
      return this.processLine(toks.slice(1).join(" "));
    };

    Assembler.prototype.lpIBasic = function(match) {
      var enc, opc, valA, valB, _ref;
      _ref = match.slice(1, 4), opc = _ref[0], valA = _ref[1], valB = _ref[2];
      enc = this.mOpcDict[opc.toUpperCase()].op;
      this.incPc();
      valA = this.processValue(valA);
      valB = this.processValue(valB);
      return this.out(new Instruction(this, enc, [valA, valB]));
    };

    Assembler.prototype.lpIAdv = function(match) {
      var enc, opc, valA, valB, _ref;
      _ref = match.slice(1, 3), opc = _ref[0], valA = _ref[1];
      if (opc === 'b') {
        return console.log("Branch " + valA);
      }
      enc = this.mOpcDict[opc.toUpperCase()].op;
      this.incPc();
      valB = this.processValue(valA);
      valA = new RawValue(this, enc);
      return this.out(new Instruction(this, 0, [valA, valB]));
    };

    Assembler.prototype.vpWord = function(match) {
      var regid;
      switch (match[1].toUpperCase()) {
        case "POP":
          return new RawValue(this, 0x18);
        case "PEEK":
          return new RawValue(this, 0x19);
        case "PUSH":
          return new RawValue(this, 0x1a);
        case "SP":
          return new RawValue(this, 0x1b);
        case "PC":
          return new RawValue(this, 0x1c);
        case "EX":
          return new RawValue(this, 0x1d);
        default:
          regid = dasm.Disasm.REG_DISASM.indexOf(match[1].toUpperCase());
          if (regid === -1) {
            return new LitValue(this, match[1]);
          } else {
            return new RegValue(this, regid);
          }
      }
    };

    Assembler.prototype.vpIWord = function(match) {
      var regid;
      regid = dasm.Disasm.REG_DISASM.indexOf(match[1].toUpperCase());
      if (regid === -1) {
        return new MemValue(this, void 0, new LitValue(this, match[1]));
      } else {
        return new MemValue(this, regid, void 0);
      }
    };

    Assembler.prototype.vpLit = function(match) {
      return new LitValue(this, parseInt(match[1]));
    };

    Assembler.prototype.vpILit = function(match) {
      var n;
      n = parseInt(match[1]);
      return new MemValue(this, void 0, new LitValue(this, n));
    };

    Assembler.prototype.vpArr = function(match) {
      var r;
      if ((r = dasm.Disasm.REG_DISASM.indexOf(match[2].toUpperCase())) !== -1) {
        return new MemValue(this, r, new LitValue(this, match[1]));
      }
      if ((r = dasm.Disasm.REG_DISASM.indexOf(match[1].toUpperCase())) !== -1) {
        return new MemValue(this, r, new LitValue(this, match[2]));
      } else {
        return console.log("Unmatched value " + match[0]);
      }
    };

    Assembler.prototype.dirGlobal = function(match) {
      console.log("exporting '" + match[2] + "'");
      return this["export"](match[2]);
    };

    return Assembler;

  })();

  exports.Assembler = Assembler;

  exports.JobLinker = JobLinker;

}).call(this);
