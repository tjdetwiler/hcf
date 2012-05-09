// Generated by CoffeeScript 1.3.1
(function() {
  var Assembler, Instruction, LabelValue, LitValue, MemValue, Module, RawValue, RegValue, SpecialValue, Value, dasm,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Module = {};

  dasm = require('./dcpu-disasm');

  Value = (function() {

    Value.name = 'Value';

    function Value() {}

    Value.prototype.emit = function() {
      return;
    };

    return Value;

  })();

  RegValue = (function(_super) {

    __extends(RegValue, _super);

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

  })(Value);

  MemValue = (function(_super) {

    __extends(MemValue, _super);

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
      if ((this.mLit != null) && this.mLit > 0x1f) {
        this.mAsm.incPc();
      }
    }

    MemValue.prototype.emit = function(stream) {
      if (this.mLit != null) {
        return stream.push(this.mLit);
      }
    };

    MemValue.prototype.encode = function() {
      if ((this.mLit != null) && (this.mReg != null)) {
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

  })(Value);

  LitValue = (function(_super) {

    __extends(LitValue, _super);

    LitValue.name = 'LitValue';

    function LitValue(asm, lit) {
      this.mAsm = asm;
      this.mLit = lit;
      if (this.mLit > 0x1f) {
        this.mAsm.incPc();
      }
    }

    LitValue.prototype.emit = function(stream) {
      if (this.mLit > 0x1f) {
        return stream.push(this.mLit);
      }
    };

    LitValue.prototype.encode = function() {
      if (this.mLit > 0x1f) {
        return 0x1f;
      } else {
        return this.mLit + 0x20;
      }
    };

    return LitValue;

  })(Value);

  SpecialValue = (function(_super) {

    __extends(SpecialValue, _super);

    SpecialValue.name = 'SpecialValue';

    function SpecialValue(asm, enc) {
      this.mEnc = enc;
    }

    SpecialValue.prototype.encode = function() {
      return this.mEnc;
    };

    return SpecialValue;

  })(Value);

  LabelValue = (function(_super) {

    __extends(LabelValue, _super);

    LabelValue.name = 'LabelValue';

    function LabelValue(asm, lbl) {
      this.mAsm = asm;
      this.mLbl = lbl;
      this.mAsm.incPc();
    }

    LabelValue.prototype.resolve = function() {
      var addr;
      addr = this.mAsm.lookup(this.mLbl);
      if (!(addr != null)) {
        console.log("Undefined label '" + this.mLbl + "'");
      }
      return addr;
    };

    LabelValue.prototype.emit = function(stream) {
      var addr;
      addr = this.resolve();
      if (!(addr != null)) {
        return false;
      }
      return stream.push(addr);
    };

    LabelValue.prototype.encode = function() {
      var addr;
      addr = this.resolve();
      if (!(addr != null)) {
        return false;
      }
      return 0x1f;
    };

    return LabelValue;

  })(Value);

  RawValue = (function(_super) {

    __extends(RawValue, _super);

    RawValue.name = 'RawValue';

    function RawValue(asm, raw) {
      this.mAsm = asm;
      this.mRaw = raw;
    }

    RawValue.prototype.encode = function() {
      return this.mRaw;
    };

    return RawValue;

  })(Value);

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
      instr = this.mOp | (enc[0] << 4) | (enc[1] << 10);
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

  Assembler = (function() {

    Assembler.name = 'Assembler';

    function Assembler() {
      this.mText = "";
      this.mLabels = {};
      this.mPc = 0;
      this.mInstrs = [];
    }

    Assembler.prototype.label = function(name, addr) {
      return this.mLabels[name] = addr;
    };

    Assembler.prototype.lookup = function(name) {
      return this.mLabels[name];
    };

    Assembler.prototype.defined = function(name) {
      return lookup(name) != null;
    };

    Assembler.prototype.isNumber = function(tok) {
      return tok.match(/0[xX][0-9a-zA-Z]+/ || tok.match(/[0-9]+/));
    };

    Assembler.prototype.isReg = function(tok) {
      var _ref;
      return _ref = tok.trim(), __indexOf.call(dasm.Disasm.REG_DISASM, _ref) >= 0;
    };

    Assembler.prototype.incPc = function() {
      return ++this.mPc;
    };

    Assembler.prototype.processValue = function(val) {
      var arr_regex, ilit_regex, ireg_regex, lit_regex, match, n, r, reg_regex, regid;
      val = val.trim();
      reg_regex = /^([a-zA-Z]+)$/;
      ireg_regex = /^\[([a-zA-Z]+|\d+)\]$/;
      lit_regex = /^(0[xX][0-9a-fA-F]+|\d+)$/;
      ilit_regex = /^\[(0[xX][0-9a-fA-F]+|\d+)\]$/;
      arr_regex = /^\[(0[xX][0-9a-fA-F]+|\d+)\+([A-Z]+)\]$/;
      if (match = val.match(reg_regex)) {
        switch (match[1]) {
          case "POP":
            return new SpecialValue(this, 0x18);
          case "PEEK":
            return new SpecialValue(this, 0x19);
          case "PUSH":
            return new SpecialValue(this, 0x1a);
          case "SP":
            return new SpecialValue(this, 0x1b);
          case "PC":
            return new SpecialValue(this, 0x1c);
          case "O":
            return new SpecialValue(this, 0x1d);
          default:
            regid = dasm.Disasm.REG_DISASM.indexOf(match[1]);
            if (regid === -1) {
              return new LabelValue(this, match[1]);
            } else {
              return new RegValue(this, regid);
            }
        }
      } else if (match = val.match(ireg_regex)) {
        regid = dasm.Disasm.REG_DISASM.indexOf(match[1]);
        return new MemValue(this, regid, void 0);
      } else if (match = val.match(lit_regex)) {
        return new LitValue(this, parseInt(match[1]));
      } else if (match = val.match(ilit_regex)) {
        n = parseInt(match[1]);
        return new MemValue(this, void 0, n);
      } else if (match = val.match(arr_regex)) {
        n = parseInt(match[1]);
        r = dasm.Disasm.REG_DISASM.indexOf(match[2]);
        return new MemValue(this, r, n);
      } else {
        console.log("Unmatched value " + val);
        return process.exit(1);
      }
    };

    Assembler.prototype.processLine = function(line) {
      var adv_regex, basic_regex, enc, match, opc, toks, valA, valB, _ref, _ref1;
      line = line.trim().toUpperCase();
      if (line === "") {
        return;
      }
      basic_regex = /(\w+)\x20([^,]+),([^,]+)/;
      adv_regex = /(\w+)\x20([^,]+)/;
      if (line[0] === ":") {
        toks = line.split(" ");
        return this.label(toks[0].slice(1), this.mPc);
      } else if (line[0] === ";") {

      } else if (match = line.match(basic_regex)) {
        _ref = match.slice(1, 4), opc = _ref[0], valA = _ref[1], valB = _ref[2];
        if (__indexOf.call(dasm.Disasm.OPC_DISASM, opc) < 0) {
          console.log("ERROR: Unknown OpCode: " + opc);
          return false;
        }
        enc = dasm.Disasm.OPC_DISASM.indexOf(opc);
        this.incPc();
        valA = this.processValue(valA);
        valB = this.processValue(valB);
        return this.mInstrs.push(new Instruction(this, enc, [valA, valB]));
      } else if (match = line.match(adv_regex)) {
        _ref1 = match.slice(1, 3), opc = _ref1[0], valA = _ref1[1];
        if (__indexOf.call(dasm.Disasm.ADV_OPC_DISASM, opc) < 0) {
          console.log("ERROR: Unknown OpCode: " + opc);
        }
        enc = dasm.Disasm.ADV_OPC_DISASM.indexOf(opc);
        this.incPc();
        valB = this.processValue(valA);
        valA = new RawValue(this, enc);
        return this.mInstrs.push(new Instruction(this, 0, [valA, valB]));
      } else {
        console.log("Syntax Error");
        return console.log(line);
      }
    };

    Assembler.prototype.emit = function(stream) {
      var i, _i, _len, _ref, _results;
      _ref = this.mInstrs;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        i = _ref[_i];
        _results.push(i.emit(stream));
      }
      return _results;
    };

    Assembler.prototype.assemble = function(text) {
      var l, lines, prog, _i, _len;
      lines = text.split("\n");
      for (_i = 0, _len = lines.length; _i < _len; _i++) {
        l = lines[_i];
        this.processLine(l);
      }
      prog = [];
      this.emit(prog);
      return prog;
    };

    return Assembler;

  })();

  exports.Assembler = Assembler;

}).call(this);