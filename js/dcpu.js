// Generated by CoffeeScript 1.3.1
(function() {
  var Dcpu16, Instr, Module, Value;

  Module = {};

  Value = (function() {

    Value.name = 'Value';

    function Value(cpu, enc) {
      this.mCpu = cpu;
      this.isMem = false;
      this.isReg = false;
      this.mEncoding = enc;
      this.mNext = 0;
      if ((0x00 <= enc && enc <= 0x07)) {
        this.isReg = true;
        this.mValue = this.mCpu.readReg(enc);
      } else if ((0x08 <= enc && enc <= 0x0f)) {
        this.isMem = true;
        this.mValue = this.mCpu.readReg(enc - 0x08);
      } else if ((0x10 <= enc && enc <= 0x17)) {
        this.isMem = true;
        this.mNext = this.mCpu.nextWord();
        this.mValue = this.mNext + this.mCpu.readReg(enc - 0x10);
      } else if (enc === 0x18) {
        this.isMem = true;
        this.mValue = this.mCpu.pop();
      } else if (enc === 0x19) {
        this.isMem = true;
        this.mValue = this.mCpu.peek();
      } else if (enc === 0x1a) {
        this.isMem = true;
        this.mValue = this.mCpu.push();
      } else if (enc === 0x1b) {
        this.isReg = true;
        this.mValue = Dcpu16.REG_SP;
      } else if (enc === 0x1c) {
        this.isReg = true;
        this.mValue = Dcpu16.REG_PC;
      } else if (enc === 0x1d) {
        this.isReg = true;
        this.mValue = Dcpu16.REG_O;
      } else if (enc === 0x1e) {
        this.isMem = true;
        this.mNext = this.mCpu.nextWord();
        this.mValue = this.mNext;
      } else if (enc === 0x1f) {
        this.mNext = this.mCpu.nextWord();
        this.mValue = this.mNext;
      } else if ((0x20 <= enc && enc <= 0x1f)) {
        this.mValue = enc - 0x20;
      }
    }

    Value.prototype.get = function() {
      if (this.isMem) {
        return this.mCpu.readMem(this.mValue);
      } else if (this.isReg) {
        return this.mCpu.readReg(this.mValue);
      } else {
        return this.mValue;
      }
    };

    Value.prototype.set = function(val) {
      if (this.isMem) {
        return this.mCpu.writeMem(this.mValue, val);
      } else if (this.isReg) {
        return this.mCpu.writeReg(this.mValue, val);
      } else {
        return console.log("Error: Attempt to 'set' a literal value");
      }
    };

    Value.prototype.raw = function() {
      return this.mEncoding;
    };

    return Value;

  })();

  Instr = (function() {

    Instr.name = 'Instr';

    Instr.prototype.OPCODE_MASK = function() {
      return 0x000f;
    };

    Instr.prototype.VALA_MASK = function() {
      return 0x03f0;
    };

    Instr.prototype.VALB_MASK = function() {
      return 0xfc00;
    };

    function Instr(cpu, enc) {
      var _ref;
      this.mCpu = cpu;
      _ref = this.decode(enc), this.mOpc = _ref[0], this.mValA = _ref[1], this.mValB = _ref[2];
    }

    Instr.prototype.decode = function(instr) {
      var opcode, valA, valB;
      opcode = instr & this.OPCODE_MASK();
      valA = (instr & this.VALA_MASK()) >> 4;
      valB = (instr & this.VALB_MASK()) >> 10;
      return [opcode, new Value(this.mCpu, valA), new Value(this.mCpu, valB)];
    };

    Instr.prototype.execAdv = function(opc, valA) {
      var addr;
      switch (opc) {
        case Dcpu16.ADV_JSR:
          addr = this.mCpu.push();
          this.mCpu.mMemory[addr] = this.mCpu.mRegs[Dcpu16.REG_PC];
          return this.mCpu.mRegs[Dcpu16.REG_PC] = valA.get();
      }
    };

    Instr.prototype.exec = function() {
      var valA, valB;
      valA = this.mValA;
      valB = this.mValB;
      switch (this.mOpc) {
        case Dcpu16.OPC_ADV:
          return this.execAdv(valA.raw(), valB);
        case Dcpu16.OPC_SET:
          return valA.set(valB.get());
        case Dcpu16.OPC_ADD:
          valA.set(valA.get() + valB.get());
          return this.mCycles += 1;
        case Dcpu16.OPC_SUB:
          valA.set(valA.get() - valB.get());
          return this.mCycles += 1;
        case Dcpu16.OPC_MUL:
          valA.set(valA.get() * valB.get());
          return this.mCycles += 1;
        case Dcpu16.OPC_DIV:
          valA.set(valA.get() / valB.get());
          return this.mCycles += 2;
        case Dcpu16.OPC_MOD:
          valA.set(valA.get() % valB.get());
          return this.mCycles += 2;
        case Dcpu16.OPC_SHL:
          valA.set(valA.get() << valB.get());
          return this.mCycles += 1;
        case Dcpu16.OPC_SHR:
          valA.set(valA.get() >> valB.get());
          return this.mCycles += 1;
        case Dcpu16.OPC_AND:
          return valA.set(valA.get() & valB.get());
        case Dcpu16.OPC_BOR:
          return valA.set(valA.get() | valB.get());
        case Dcpu16.OPC_XOR:
          return valA.set(valA.get() ^ valB.get());
        case Dcpu16.OPC_IFE:
          if (valA.get() === valB.get()) {
            this.mCpu.mSkipNext = true;
            return this.mCycles += 1;
          } else {
            return this.mCycles += 2;
          }
          break;
        case Dcpu16.OPC_IFN:
          if (valA.get() !== valB.get()) {
            this.mCpu.mSkipNext = true;
            return this.mCycles += 1;
          } else {
            return this.mCycles += 2;
          }
          break;
        case Dcpu16.OPC_IFG:
          if (valA.get() > valB.get()) {
            this.mCpu.mSkipNext = true;
            return this.mCycles += 1;
          } else {
            return this.mCycles += 2;
          }
          break;
        case Dcpu16.OPC_IFB:
          if ((valA.get() & valB.get()) !== 0) {
            this.mCpu.mSkipNext = true;
            return this.mCycles += 1;
          } else {
            return this.mCycles += 2;
          }
      }
    };

    return Instr;

  })();

  Dcpu16 = (function() {
    var _i, _j, _ref, _ref1, _results, _results1;

    Dcpu16.name = 'Dcpu16';

    _ref = (function() {
      _results = [];
      for (var _i = 0x0; 0x0 <= 0xf ? _i <= 0xf : _i >= 0xf; 0x0 <= 0xf ? _i++ : _i--){ _results.push(_i); }
      return _results;
    }).apply(this), Dcpu16.OPC_ADV = _ref[0], Dcpu16.OPC_SET = _ref[1], Dcpu16.OPC_ADD = _ref[2], Dcpu16.OPC_SUB = _ref[3], Dcpu16.OPC_MUL = _ref[4], Dcpu16.OPC_DIV = _ref[5], Dcpu16.OPC_MOD = _ref[6], Dcpu16.OPC_SHL = _ref[7], Dcpu16.OPC_SHR = _ref[8], Dcpu16.OPC_AND = _ref[9], Dcpu16.OPC_BOR = _ref[10], Dcpu16.OPC_XOR = _ref[11], Dcpu16.OPC_IFE = _ref[12], Dcpu16.OPC_IFN = _ref[13], Dcpu16.OPC_IFG = _ref[14], Dcpu16.OPC_IFB = _ref[15];

    Dcpu16.ADV_JSR = [1][0];

    _ref1 = (function() {
      _results1 = [];
      for (var _j = 0x0; 0x0 <= 0xa ? _j <= 0xa : _j >= 0xa; 0x0 <= 0xa ? _j++ : _j--){ _results1.push(_j); }
      return _results1;
    }).apply(this), Dcpu16.REG_A = _ref1[0], Dcpu16.REG_B = _ref1[1], Dcpu16.REG_C = _ref1[2], Dcpu16.REG_X = _ref1[3], Dcpu16.REG_Y = _ref1[4], Dcpu16.REG_Z = _ref1[5], Dcpu16.REG_I = _ref1[6], Dcpu16.REG_J = _ref1[7], Dcpu16.REG_PC = _ref1[8], Dcpu16.REG_SP = _ref1[9], Dcpu16.REG_O = _ref1[10];

    function Dcpu16(program) {
      var i, x, _k, _l, _len;
      if (program == null) {
        program = [];
      }
      this.mCycles = 0;
      this.mRegs = [];
      this.mSkipNext = false;
      for (x = _k = 0; 0 <= 0xf ? _k <= 0xf : _k >= 0xf; x = 0 <= 0xf ? ++_k : --_k) {
        this.mRegs[x] = 0;
      }
      this.mRegs[Dcpu16.REG_SP] = 0xffff;
      this.mMemory = (function() {
        var _l, _results2;
        _results2 = [];
        for (x = _l = 0; 0 <= 0xffff ? _l <= 0xffff : _l >= 0xffff; x = 0 <= 0xffff ? ++_l : --_l) {
          _results2.push(0);
        }
        return _results2;
      })();
      for (i = _l = 0, _len = program.length; _l < _len; i = ++_l) {
        x = program[i];
        this.mMemory[i] = x;
      }
    }

    Dcpu16.prototype.onPreExec = function(fn) {
      return this.mPreExec = fn;
    };

    Dcpu16.prototype.onPostExec = function(fn) {
      return this.mPostExec = fn;
    };

    Dcpu16.prototype.readReg = function(n) {
      return this.mRegs[n];
    };

    Dcpu16.prototype.writeReg = function(n, val) {
      return this.mRegs[n] = val;
    };

    Dcpu16.prototype.readMem = function(addr) {
      return this.mMemory[addr];
    };

    Dcpu16.prototype.writeMem = function(addr, val) {
      return this.mMemory[addr] = val;
    };

    Dcpu16.prototype.push = function() {
      return --this.mRegs[Dcpu16.REG_SP];
    };

    Dcpu16.prototype.peek = function() {
      return this.mRegs[Dcpu16.REG_SP];
    };

    Dcpu16.prototype.pop = function() {
      return this.mRegs[Dcpu16.REG_SP]++;
    };

    Dcpu16.prototype._r = function(v, n) {
      if (v != null) {
        return this.mRegs[n] = v;
      } else {
        return this.mRegs[n];
      }
    };

    Dcpu16.prototype.regA = function(v) {
      return this._r(v, Dcpu16.REG_A);
    };

    Dcpu16.prototype.regB = function(v) {
      return this._r(v, Dcpu16.REG_B);
    };

    Dcpu16.prototype.regC = function(v) {
      return this._r(v, Dcpu16.REG_C);
    };

    Dcpu16.prototype.regX = function(v) {
      return this._r(v, Dcpu16.REG_X);
    };

    Dcpu16.prototype.regY = function(v) {
      return this._r(v, Dcpu16.REG_Y);
    };

    Dcpu16.prototype.regZ = function(v) {
      return this._r(v, Dcpu16.REG_Z);
    };

    Dcpu16.prototype.regI = function(v) {
      return this._r(v, Dcpu16.REG_I);
    };

    Dcpu16.prototype.regJ = function(v) {
      return this._r(v, Dcpu16.REG_J);
    };

    Dcpu16.prototype.regPC = function(v) {
      return this._r(v, Dcpu16.REG_PC);
    };

    Dcpu16.prototype.regSP = function(v) {
      return this._r(v, Dcpu16.REG_SP);
    };

    Dcpu16.prototype.regO = function(v) {
      return this._r(v, Dcpu16.REG_O);
    };

    Dcpu16.prototype.loadBinary = function(bin, base) {
      var i, x, _k, _len, _results2;
      if (base == null) {
        base = 0;
      }
      _results2 = [];
      for (i = _k = 0, _len = bin.length; _k < _len; i = ++_k) {
        x = bin[i];
        _results2.push(this.mMemory[base + i] = x);
      }
      return _results2;
    };

    Dcpu16.prototype.nextWord = function() {
      var pc;
      this.mCycles++;
      pc = this.mRegs[Dcpu16.REG_PC]++;
      return this.mMemory[pc];
    };

    Dcpu16.prototype.step = function() {
      var i;
      i = new Instr(this, this.nextWord());
      if (this.mSkipNext) {
        this.mSkipNext = false;
        return this.step();
      }
      if (this.mPreExec != null) {
        this.mPreExec(i);
      }
      i.exec();
      if (this.mPostExec != null) {
        return this.mPostExec(i);
      }
    };

    Dcpu16.prototype.run = function() {
      var _results2;
      _results2 = [];
      while (true) {
        _results2.push(this.step());
      }
      return _results2;
    };

    return Dcpu16;

  })();

  exports.Dcpu16 = Dcpu16;

}).call(this);
