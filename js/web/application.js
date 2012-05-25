var require = function (file, cwd) {
    var resolved = require.resolve(file, cwd || '/');
    var mod = require.modules[resolved];
    if (!mod) throw new Error(
        'Failed to resolve module ' + file + ', tried ' + resolved
    );
    var res = mod._cached ? mod._cached : mod();
    return res;
}

require.paths = [];
require.modules = {};
require.extensions = [".js",".coffee"];

require._core = {
    'assert': true,
    'events': true,
    'fs': true,
    'path': true,
    'vm': true
};

require.resolve = (function () {
    return function (x, cwd) {
        if (!cwd) cwd = '/';
        
        if (require._core[x]) return x;
        var path = require.modules.path();
        cwd = path.resolve('/', cwd);
        var y = cwd || '/';
        
        if (x.match(/^(?:\.\.?\/|\/)/)) {
            var m = loadAsFileSync(path.resolve(y, x))
                || loadAsDirectorySync(path.resolve(y, x));
            if (m) return m;
        }
        
        var n = loadNodeModulesSync(x, y);
        if (n) return n;
        
        throw new Error("Cannot find module '" + x + "'");
        
        function loadAsFileSync (x) {
            if (require.modules[x]) {
                return x;
            }
            
            for (var i = 0; i < require.extensions.length; i++) {
                var ext = require.extensions[i];
                if (require.modules[x + ext]) return x + ext;
            }
        }
        
        function loadAsDirectorySync (x) {
            x = x.replace(/\/+$/, '');
            var pkgfile = x + '/package.json';
            if (require.modules[pkgfile]) {
                var pkg = require.modules[pkgfile]();
                var b = pkg.browserify;
                if (typeof b === 'object' && b.main) {
                    var m = loadAsFileSync(path.resolve(x, b.main));
                    if (m) return m;
                }
                else if (typeof b === 'string') {
                    var m = loadAsFileSync(path.resolve(x, b));
                    if (m) return m;
                }
                else if (pkg.main) {
                    var m = loadAsFileSync(path.resolve(x, pkg.main));
                    if (m) return m;
                }
            }
            
            return loadAsFileSync(x + '/index');
        }
        
        function loadNodeModulesSync (x, start) {
            var dirs = nodeModulesPathsSync(start);
            for (var i = 0; i < dirs.length; i++) {
                var dir = dirs[i];
                var m = loadAsFileSync(dir + '/' + x);
                if (m) return m;
                var n = loadAsDirectorySync(dir + '/' + x);
                if (n) return n;
            }
            
            var m = loadAsFileSync(x);
            if (m) return m;
        }
        
        function nodeModulesPathsSync (start) {
            var parts;
            if (start === '/') parts = [ '' ];
            else parts = path.normalize(start).split('/');
            
            var dirs = [];
            for (var i = parts.length - 1; i >= 0; i--) {
                if (parts[i] === 'node_modules') continue;
                var dir = parts.slice(0, i + 1).join('/') + '/node_modules';
                dirs.push(dir);
            }
            
            return dirs;
        }
    };
})();

require.alias = function (from, to) {
    var path = require.modules.path();
    var res = null;
    try {
        res = require.resolve(from + '/package.json', '/');
    }
    catch (err) {
        res = require.resolve(from, '/');
    }
    var basedir = path.dirname(res);
    
    var keys = (Object.keys || function (obj) {
        var res = [];
        for (var key in obj) res.push(key)
        return res;
    })(require.modules);
    
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        if (key.slice(0, basedir.length + 1) === basedir + '/') {
            var f = key.slice(basedir.length);
            require.modules[to + f] = require.modules[basedir + f];
        }
        else if (key === basedir) {
            require.modules[to] = require.modules[basedir];
        }
    }
};

require.define = function (filename, fn) {
    var dirname = require._core[filename]
        ? ''
        : require.modules.path().dirname(filename)
    ;
    
    var require_ = function (file) {
        return require(file, dirname)
    };
    require_.resolve = function (name) {
        return require.resolve(name, dirname);
    };
    require_.modules = require.modules;
    require_.define = require.define;
    var module_ = { exports : {} };
    
    require.modules[filename] = function () {
        require.modules[filename]._cached = module_.exports;
        fn.call(
            module_.exports,
            require_,
            module_,
            module_.exports,
            dirname,
            filename
        );
        require.modules[filename]._cached = module_.exports;
        return module_.exports;
    };
};

if (typeof process === 'undefined') process = {};

if (!process.nextTick) process.nextTick = (function () {
    var queue = [];
    var canPost = typeof window !== 'undefined'
        && window.postMessage && window.addEventListener
    ;
    
    if (canPost) {
        window.addEventListener('message', function (ev) {
            if (ev.source === window && ev.data === 'browserify-tick') {
                ev.stopPropagation();
                if (queue.length > 0) {
                    var fn = queue.shift();
                    fn();
                }
            }
        }, true);
    }
    
    return function (fn) {
        if (canPost) {
            queue.push(fn);
            window.postMessage('browserify-tick', '*');
        }
        else setTimeout(fn, 0);
    };
})();

if (!process.title) process.title = 'browser';

if (!process.binding) process.binding = function (name) {
    if (name === 'evals') return require('vm')
    else throw new Error('No such module')
};

if (!process.cwd) process.cwd = function () { return '.' };

require.define("path", function (require, module, exports, __dirname, __filename) {
function filter (xs, fn) {
    var res = [];
    for (var i = 0; i < xs.length; i++) {
        if (fn(xs[i], i, xs)) res.push(xs[i]);
    }
    return res;
}

// resolves . and .. elements in a path array with directory names there
// must be no slashes, empty elements, or device names (c:\) in the array
// (so also no leading and trailing slashes - it does not distinguish
// relative and absolute paths)
function normalizeArray(parts, allowAboveRoot) {
  // if the path tries to go above the root, `up` ends up > 0
  var up = 0;
  for (var i = parts.length; i >= 0; i--) {
    var last = parts[i];
    if (last == '.') {
      parts.splice(i, 1);
    } else if (last === '..') {
      parts.splice(i, 1);
      up++;
    } else if (up) {
      parts.splice(i, 1);
      up--;
    }
  }

  // if the path is allowed to go above the root, restore leading ..s
  if (allowAboveRoot) {
    for (; up--; up) {
      parts.unshift('..');
    }
  }

  return parts;
}

// Regex to split a filename into [*, dir, basename, ext]
// posix version
var splitPathRe = /^(.+\/(?!$)|\/)?((?:.+?)?(\.[^.]*)?)$/;

// path.resolve([from ...], to)
// posix version
exports.resolve = function() {
var resolvedPath = '',
    resolvedAbsolute = false;

for (var i = arguments.length; i >= -1 && !resolvedAbsolute; i--) {
  var path = (i >= 0)
      ? arguments[i]
      : process.cwd();

  // Skip empty and invalid entries
  if (typeof path !== 'string' || !path) {
    continue;
  }

  resolvedPath = path + '/' + resolvedPath;
  resolvedAbsolute = path.charAt(0) === '/';
}

// At this point the path should be resolved to a full absolute path, but
// handle relative paths to be safe (might happen when process.cwd() fails)

// Normalize the path
resolvedPath = normalizeArray(filter(resolvedPath.split('/'), function(p) {
    return !!p;
  }), !resolvedAbsolute).join('/');

  return ((resolvedAbsolute ? '/' : '') + resolvedPath) || '.';
};

// path.normalize(path)
// posix version
exports.normalize = function(path) {
var isAbsolute = path.charAt(0) === '/',
    trailingSlash = path.slice(-1) === '/';

// Normalize the path
path = normalizeArray(filter(path.split('/'), function(p) {
    return !!p;
  }), !isAbsolute).join('/');

  if (!path && !isAbsolute) {
    path = '.';
  }
  if (path && trailingSlash) {
    path += '/';
  }
  
  return (isAbsolute ? '/' : '') + path;
};


// posix version
exports.join = function() {
  var paths = Array.prototype.slice.call(arguments, 0);
  return exports.normalize(filter(paths, function(p, index) {
    return p && typeof p === 'string';
  }).join('/'));
};


exports.dirname = function(path) {
  var dir = splitPathRe.exec(path)[1] || '';
  var isWindows = false;
  if (!dir) {
    // No dirname
    return '.';
  } else if (dir.length === 1 ||
      (isWindows && dir.length <= 3 && dir.charAt(1) === ':')) {
    // It is just a slash or a drive letter with a slash
    return dir;
  } else {
    // It is a full dirname, strip trailing slash
    return dir.substring(0, dir.length - 1);
  }
};


exports.basename = function(path, ext) {
  var f = splitPathRe.exec(path)[2] || '';
  // TODO: make this comparison case-insensitive on windows?
  if (ext && f.substr(-1 * ext.length) === ext) {
    f = f.substr(0, f.length - ext.length);
  }
  return f;
};


exports.extname = function(path) {
  return splitPathRe.exec(path)[3] || '';
};

});

require.define("/dcpu-decode.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var IStream, Instr, Module, Value;

  Module = {};

  IStream = (function() {

    function IStream(instrs, base) {
      if (base == null) base = 0;
      this.mStream = instrs;
      this.mIndex = base;
    }

    IStream.prototype.nextWord = function() {
      return this.mStream[this.mIndex++];
    };

    IStream.prototype.index = function(v) {
      if (v != null) {
        return this.mIndex = v;
      } else {
        return this.mIndex;
      }
    };

    IStream.prototype.setPC = function(v) {
      return this.index(v);
    };

    IStream.prototype.getPC = function() {
      return this.index();
    };

    return IStream;

  })();

  Value = (function() {
    var _i, _ref, _results;

    _ref = (function() {
      _results = [];
      for (var _i = 0x0; 0x0 <= 0xb ? _i <= 0xb : _i >= 0xb; 0x0 <= 0xb ? _i++ : _i--){ _results.push(_i); }
      return _results;
    }).apply(this), Value.REG_A = _ref[0], Value.REG_B = _ref[1], Value.REG_C = _ref[2], Value.REG_X = _ref[3], Value.REG_Y = _ref[4], Value.REG_Z = _ref[5], Value.REG_I = _ref[6], Value.REG_J = _ref[7], Value.REG_PC = _ref[8], Value.REG_SP = _ref[9], Value.REG_EX = _ref[10], Value.REG_IA = _ref[11];

    Value.VAL_POP = 0x18;

    Value.VAL_PUSH = 0x18;

    Value.VAL_PEEK = 0x19;

    Value.VAL_PICK = 0x1a;

    Value.VAL_SP = 0x1b;

    Value.VAL_PC = 0x1c;

    Value.VAL_EX = 0x1d;

    function Value(stream, enc, raw) {
      if (raw == null) raw = false;
      this.mIStream = stream;
      this.isMem = false;
      this.isReg = false;
      this.mEncoding = enc;
      this.mNext = void 0;
      if (raw) {
        this.mValue = enc;
        return;
      }
      if ((0x00 <= enc && enc <= 0x07)) {
        this.isReg = true;
        this.mValue = enc;
      } else if ((0x08 <= enc && enc <= 0x0f)) {
        this.isMem = true;
        this.isReg = true;
        this.mValue = enc - 0x08;
      } else if ((0x10 <= enc && enc <= 0x17)) {
        this.isMem = true;
        this.isReg = true;
        this.mNext = this.mIStream.nextWord();
        this.mValue = enc - 0x10;
      } else if (enc === Value.VAL_POP) {
        "";
      } else if (enc === Value.VAL_PEEK) {
        "";
      } else if (enc === Value.VAL_PICK) {
        this.mNext = this.mIStream.nextWord();
      } else if (enc === Value.VAL_SP) {
        this.isReg = true;
        this.mValue = Value.REG_SP;
      } else if (enc === Value.VAL_PC) {
        this.isReg = true;
        this.mValue = Value.REG_PC;
      } else if (enc === Value.VAL_EX) {
        this.isReg = true;
        this.mValue = Value.REG_EX;
      } else if (enc === 0x1e) {
        this.isMem = true;
        this.mNext = this.mIStream.nextWord();
        this.mValue = this.mNext;
      } else if (enc === 0x1f) {
        this.mNext = this.mIStream.nextWord();
        this.mValue = this.mNext;
      } else if ((0x20 <= enc && enc <= 0x3f)) {
        if (enc) {
          this.mValue = enc - 0x21;
        } else {
          this.mValue = 0xffff;
        }
      }
    }

    Value.prototype.get = function(cpu) {
      var addr, sp;
      if (this.isMem && this.isReg && (this.mNext != null)) {
        addr = this.mNext;
        addr += cpu.readReg(this.mValue);
        return cpu.readMem(addr);
      } else if (this.isMem && this.isReg) {
        addr = cpu.readReg(this.mValue);
        return cpu.readMem(addr);
      } else if (this.isMem) {
        return cpu.readMem(this.mValue);
      } else if (this.isReg) {
        return cpu.readReg(this.mValue);
      } else if (this.mEncoding === Value.VAL_POP) {
        return cpu.pop();
      } else if (this.mEncoding === Value.VAL_PEEK) {
        return cpu.peek();
      } else if (this.mEncoding === Value.VAL_PICK) {
        sp = cpu.regSP();
        addr = sp + this.mNext;
        return cpu.readMem(addr);
      } else {
        return this.mValue;
      }
    };

    Value.prototype.set = function(cpu, val) {
      var addr, sp;
      if (this.isMem && this.isReg && (this.mNext != null)) {
        addr = this.mNext;
        addr += cpu.readReg(this.mValue);
        return cpu.writeMem(addr, val);
      } else if (this.isMem && this.isReg) {
        addr = cpu.readReg(this.mValue);
        return cpu.writeMem(addr, val);
      } else if (this.isMem) {
        return cpu.writeMem(this.mValue, val);
      } else if (this.isReg) {
        return cpu.writeReg(this.mValue, val);
      } else if (this.mEncoding === Value.VAL_PUSH) {
        return cpu.push(val);
      } else if (this.mEncoding === Value.VAL_PEEK) {
        return console.log("ERROR: Trying to 'set' PEEK");
      } else if (this.mEncoding === Value.VAL_PICK) {
        sp = cpu.regSP();
        addr = sp + this.mNext;
        return cpu.writeMem(addr, val);
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

    Instr.BASIC_OPS = [
      Instr.OPC_ADV = {
        op: 0x00,
        id: "adv",
        cost: 0,
        cond: false
      }, Instr.OPC_SET = {
        op: 0x01,
        id: "set",
        cost: 1,
        cond: false
      }, Instr.OPC_ADD = {
        op: 0x02,
        id: "add",
        cost: 2,
        cond: false
      }, Instr.OPC_SUB = {
        op: 0x03,
        id: "sub",
        cost: 2,
        cond: false
      }, Instr.OPC_MUL = {
        op: 0x04,
        id: "mul",
        cost: 2,
        cond: false
      }, Instr.OPC_MLI = {
        op: 0x05,
        id: "mli",
        cost: 2,
        cond: false
      }, Instr.OPC_DIV = {
        op: 0x06,
        id: "div",
        cost: 3,
        cond: false
      }, Instr.OPC_DVI = {
        op: 0x07,
        id: "dvi",
        cost: 3,
        cond: false
      }, Instr.OPC_MOD = {
        op: 0x08,
        id: "mod",
        cost: 3,
        cond: false
      }, Instr.OPC_MDI = {
        op: 0x09,
        id: "mdi",
        cost: 3,
        cond: false
      }, Instr.OPC_AND = {
        op: 0x0a,
        id: "and",
        cost: 1,
        cond: false
      }, Instr.OPC_BOR = {
        op: 0x0b,
        id: "bor",
        cost: 1,
        cond: false
      }, Instr.OPC_XOR = {
        op: 0x0c,
        id: "xor",
        cost: 1,
        cond: false
      }, Instr.OPC_SHR = {
        op: 0x0d,
        id: "shr",
        cost: 1,
        cond: false
      }, Instr.OPC_ASR = {
        op: 0x0e,
        id: "asr",
        cost: 1,
        cond: false
      }, Instr.OPC_SHL = {
        op: 0x0f,
        id: "shl",
        cost: 1,
        cond: false
      }, Instr.OPC_IFB = {
        op: 0x10,
        id: "ifb",
        cost: 2,
        cond: true
      }, Instr.OPC_IFC = {
        op: 0x11,
        id: "ifc",
        cost: 2,
        cond: true
      }, Instr.OPC_IFE = {
        op: 0x12,
        id: "ife",
        cost: 2,
        cond: true
      }, Instr.OPC_IFN = {
        op: 0x13,
        id: "ifn",
        cost: 2,
        cond: true
      }, Instr.OPC_IFG = {
        op: 0x14,
        id: "ifg",
        cost: 2,
        cond: true
      }, Instr.OPC_IFA = {
        op: 0x15,
        id: "ifa",
        cost: 2,
        cond: true
      }, Instr.OPC_IFL = {
        op: 0x16,
        id: "ifl",
        cost: 2,
        cond: true
      }, Instr.OPC_IFU = {
        op: 0x17,
        id: "ifu",
        cost: 2,
        cond: true
      }, Instr.OPC_ADX = {
        op: 0x1a,
        id: "adx",
        cost: 3,
        cond: false
      }, Instr.OPC_SBX = {
        op: 0x1b,
        id: "sbx",
        cost: 3,
        cond: false
      }, void 0, void 0, Instr.OPC_STI = {
        op: 0x1e,
        id: "sti",
        cost: 2,
        cond: false
      }, Instr.OPC_STD = {
        op: 0x1f,
        id: "std",
        cost: 2,
        cond: false
      }
    ];

    Instr.ADV_OPS = [
      void 0, Instr.ADV_JSR = {
        op: 0x01,
        id: "jsr",
        cost: 3,
        cond: false
      }, void 0, void 0, void 0, void 0, void 0, void 0, Instr.ADV_INT = {
        op: 0x08,
        id: "int",
        cost: 4,
        cond: false
      }, Instr.ADV_IAG = {
        op: 0x09,
        id: "iag",
        cost: 1,
        cond: false
      }, Instr.ADV_IAS = {
        op: 0x0a,
        id: "ias",
        cost: 1,
        cond: false
      }, Instr.ADV_RFI = {
        op: 0x0b,
        id: "rfi",
        cost: 3,
        cond: false
      }, Instr.ADV_IAQ = {
        op: 0x0c,
        id: "iaq",
        cost: 2,
        cond: false
      }, void 0, void 0, void 0, Instr.ADV_HWN = {
        op: 0x10,
        id: "hwn",
        cost: 2,
        cond: false
      }, Instr.ADV_HWQ = {
        op: 0x11,
        id: "hwq",
        cost: 4,
        cond: false
      }, Instr.ADV_HWI = {
        op: 0x12,
        id: "hwi",
        cost: 4,
        cond: false
      }
    ];

    function Instr(stream) {
      var addr, word, _ref;
      this.mIStream = stream;
      this.mAddr = this.mIStream.index();
      addr = this.mIStream.getPC();
      word = this.mIStream.nextWord();
      _ref = this.decode(word), this.mOpc = _ref[0], this.mValA = _ref[1], this.mValB = _ref[2];
      this.mParams = this._getParams();
    }

    Instr.prototype.decode = function(instr) {
      var opcode, valA, valB;
      opcode = instr & this.OPCODE_MASK();
      valB = (instr & this.VALB_MASK()) >> 5;
      valA = (instr & this.VALA_MASK()) >> 10;
      if (opcode === 0) {
        valB = new Value(this.mIStream, valB, true);
      } else {
        valB = new Value(this.mIStream, valB);
      }
      valA = new Value(this.mIStream, valA);
      return [opcode, valB, valA];
    };

    Instr.prototype.opc = function() {
      return this.mOpc;
    };

    Instr.prototype.valA = function() {
      return this.mValA;
    };

    Instr.prototype.valB = function() {
      return this.mValB;
    };

    Instr.prototype.addr = function() {
      return this.mAddr;
    };

    Instr.prototype.cond = function() {
      return this.mParams.cond;
    };

    Instr.prototype.cost = function() {
      return this.mParams.cost;
    };

    Instr.prototype._getParams = function() {
      if (this.mOpc) {
        return Instr.BASIC_OPS[this.mOpc];
      } else {
        return Instr.ADV_OPS[this.mValA.raw()];
      }
    };

    Instr.prototype.OPCODE_MASK = function() {
      return 0x001f;
    };

    Instr.prototype.VALB_MASK = function() {
      return 0x03e0;
    };

    Instr.prototype.VALA_MASK = function() {
      return 0xfc00;
    };

    return Instr;

  })();

  exports.Value = Value;

  exports.Instr = Instr;

  exports.IStream = IStream;

}).call(this);

});

require.define("/dcpu-disasm.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var Disasm, Instr, Module, decode;

  Module = {};

  decode = require('./dcpu-decode');

  Instr = decode.Instr;

  Disasm = (function() {

    function Disasm() {}

    Disasm.REG_DISASM = ["A", "B", "C", "X", "Y", "Z", "I", "J", "PC", "SP", "O"];

    Disasm.fmtHex = function(n, pad) {
      var p, str, _, _ref;
      if (pad == null) pad = true;
      str = n.toString(16);
      p = "";
      if (pad) {
        for (_ = 0, _ref = 4 - str.length; 0 <= _ref ? _ <= _ref : _ >= _ref; 0 <= _ref ? _++ : _--) {
          p = p + "0";
        }
      }
      return p.slice(1) + str;
    };

    Disasm.ppNextInstr = function(stream) {
      return this.ppInstr(new Instr(stream));
    };

    Disasm.ppInstr = function(i) {
      var op, va, vb;
      if (i.opc() === 0) {
        if (i.valA().raw() === 0) return "";
        op = Instr.ADV_OPS[i.valA().raw()];
        va = Disasm.ppValue(i.valB());
        return "" + op.id + " " + va;
      } else {
        op = Instr.BASIC_OPS[i.opc()];
        va = Disasm.ppValue(i.valA());
        vb = Disasm.ppValue(i.valB());
        return "" + op.id + " " + va + ", " + vb;
      }
    };

    Disasm.ppValue = function(val) {
      var enc, lit, reg, v;
      enc = val.raw();
      v = "";
      if ((0x00 <= enc && enc <= 0x07)) {
        v = Disasm.REG_DISASM[enc];
      } else if ((0x08 <= enc && enc <= 0x0f)) {
        reg = Disasm.REG_DISASM[enc - 0x8];
        v = "[" + reg + "]";
      } else if ((0x10 <= enc && enc <= 0x17)) {
        lit = val.mNext.toString(16);
        reg = Disasm.REG_DISASM[enc - 0x10];
        v = "[0x" + lit + "+" + reg + "]";
      } else if (enc === 0x18) {
        v = "POP";
      } else if (enc === 0x19) {
        v = "PEEK";
      } else if (enc === 0x1a) {
        v = "PUSH";
      } else if (enc === 0x1b) {
        v = "SP";
      } else if (enc === 0x1c) {
        v = "PC";
      } else if (enc === 0x1d) {
        v = "O";
      } else if (enc === 0x1e) {
        lit = val.mNext.toString(16);
        v = "[0x" + lit + "]";
      } else if (enc === 0x1f) {
        lit = val.mNext.toString(16);
        v = "0x" + lit;
      } else if ((0x20 <= enc && enc <= 0x3f)) {
        v = enc - 0x21;
        if (v < 0) v = 0xffff;
        v = "0x" + (v.toString(16));
      }
      return v;
    };

    return Disasm;

  })();

  exports.Disasm = Disasm;

}).call(this);

});

require.define("/hw/lem1802.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var Device, Lem1802, Module;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  Module = {};

  Device = require("./device").Device;

  Lem1802 = (function() {

    __extends(Lem1802, Device);

    function Lem1802(cpu, canvas) {
      if (canvas == null) canvas = void 0;
      Lem1802.__super__.constructor.call(this, "LEM1802", cpu);
      this.mCanvas = canvas;
      this.mCtx = canvas != null ? canvas.getContext('2d') : void 0;
      this.mScale = 4;
      this.mScreenAddr = 0;
      this.mFontAddr = 0;
      this.mPaletteAddr = 0;
      this.mScreen = void 0;
      this.mUserFont = void 0;
      this.mUserPalette = void 0;
      this.clear();
    }

    Lem1802.prototype.id = function() {
      return 0x7349f615;
    };

    Lem1802.prototype.mfgr = function() {
      return 0x1c6c8b38;
    };

    Lem1802.prototype.ver = function() {
      return 0x1802;
    };

    Lem1802.prototype.hwInterrupt = function() {
      switch (this.mCpu.regA()) {
        case 0:
          return this.memMapScreen();
        case 1:
          return this.memMapFont();
        case 2:
          return this.memMapPalette();
        case 3:
          return this.setBorderColor();
        default:
          return;
      }
    };

    Lem1802.prototype.reset = function() {
      this.mScreen = void 0;
      this.mScreenAddr = 0;
      this.mUserFont = void 0;
      this.mFontAddr = 0;
      this.mUserPalette = void 0;
      this.mPaletteAddr = 0;
      return this.clear();
    };

    Lem1802.prototype.memMapScreen = function() {
      var base, _;
      base = this.mCpu.regB();
      if (base === 0) {
        this.unmapMemory(this.mScreenAddr);
        this.mScreen = void 0;
      } else {
        this.mapMemory(base, this.VID_RAM_SIZE, this._screenCB());
        this.mScreen = (function() {
          var _ref, _results;
          _results = [];
          for (_ = 0, _ref = this.VID_RAM_SIZE; 0 <= _ref ? _ <= _ref : _ >= _ref; 0 <= _ref ? _++ : _--) {
            _results.push(0);
          }
          return _results;
        }).call(this);
      }
      return this.mScreenAddr = base;
    };

    Lem1802.prototype.memMapFont = function() {
      var base, _;
      base = this.mCpu.regB();
      if (base === 0) {
        this.unmapMemory(this.mFontAddr);
        this.mUserFont = void 0;
      } else {
        this.mapMemory(base, this.FONT_RAM_SIZE, this._fontCB());
        this.mUserFont = (function() {
          var _ref, _results;
          _results = [];
          for (_ = 0, _ref = this.FONT_RAM_SIZE; 0 <= _ref ? _ <= _ref : _ >= _ref; 0 <= _ref ? _++ : _--) {
            _results.push(0);
          }
          return _results;
        }).call(this);
      }
      return this.mFontAddr = base;
    };

    Lem1802.prototype.memMapPalette = function() {
      var base, _;
      base = this.mCpu.regB();
      if (base === 0) {
        this.unmapMemory(this.mPaletteAddr);
        this.mUserPalette = void 0;
      } else {
        this.mapMemory(base, this.PALETTE_RAM_SIZE, this._paletteCB());
        this.mUserPalette = (function() {
          var _ref, _results;
          _results = [];
          for (_ = 0, _ref = this.PALETTE_RAM_SIZE; 0 <= _ref ? _ <= _ref : _ >= _ref; 0 <= _ref ? _++ : _--) {
            _results.push(0);
          }
          return _results;
        }).call(this);
      }
      return this.mPaletteAddr = base;
    };

    Lem1802.prototype.setBorderColor = function() {
      return;
    };

    Lem1802.prototype.readFontRam = function(i) {
      return Lem1802.DFL_FONT[i];
    };

    Lem1802.prototype.readPaletteRam = function(i) {
      var b, g, r, word;
      word = Lem1802.DFL_PALETTE[i];
      b = word & 0xf;
      g = (word >> 4) & 0xf;
      r = (word >> 8) & 0xf;
      return {
        r: r,
        g: g,
        b: b
      };
    };

    Lem1802.prototype.rgbString = function(c) {
      return "rgb(" + (c.r * 16) + ", " + (c.g * 16) + ", " + (c.b * 16) + ")";
    };

    Lem1802.prototype.getChar = function(c) {
      return [this.readFontRam(c * 2), this.readFontRam(c * 2 + 1)];
    };

    Lem1802.prototype.drawChar = function(x, y, c) {
      var bg, bit, fg, i, word, x_, y_, _results;
      if (!(this.mCtx != null)) return;
      bg = (c >> 8) & 0xf;
      fg = (c >> 12) & 0xf;
      c = c & 0x7f;
      x = x * 4;
      y = y * 8;
      c = this.getChar(c);
      this.mCtx.fillStyle = this.rgbString(this.readPaletteRam(bg));
      this.mCtx.fillRect(x * this.mScale, y * this.mScale, 4 * this.mScale, 8 * this.mScale);
      this.mCtx.fillStyle = this.rgbString(this.readPaletteRam(fg));
      _results = [];
      for (i = 31; i >= 0; i--) {
        word = Math.floor(i / 16);
        bit = i % 16;
        if (c[1 - word] & (1 << bit)) {
          x_ = x + 3 - Math.floor(i / 8);
          y_ = y + (i % 8);
          _results.push(this.mCtx.fillRect(x_ * this.mScale, y_ * this.mScale, this.mScale, this.mScale));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    Lem1802.prototype.clear = function() {
      if (!(this.mCtx != null)) return;
      this.mCtx.fillStyle = this.rgbString(this.readPaletteRam(0xf));
      return this.mCtx.fillRect(0, 0, 128 * this.mScale, 96 * this.mScale);
    };

    Lem1802.prototype._screenCB = function() {
      var lem;
      lem = this;
      return function(a, v) {
        var x, y;
        x = a % 32;
        y = Math.floor(a / 32);
        return lem.drawChar(x, y, v);
      };
    };

    Lem1802.prototype._fontCB = function() {
      var lem;
      lem = this;
      return function(a, v) {
        return;
      };
    };

    Lem1802.prototype._paletteCB = function() {
      var lem;
      lem = this;
      return function(a, v) {
        return;
      };
    };

    Lem1802.prototype.VID_RAM_SIZE = 386;

    Lem1802.prototype.FONT_RAM_SIZE = 256;

    Lem1802.prototype.PALETTE_RAM_SIZE = 16;

    Lem1802.DFL_FONT = [0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0000, 0x0000, 0x00be, 0x0000, 0x0600, 0x0600, 0xfe24, 0xfe00, 0x48fe, 0x2400, 0xe410, 0x4e00, 0x2070, 0x2000, 0x0006, 0x0000, 0x3844, 0x8200, 0x8244, 0x3800, 0x1408, 0x1400, 0x2070, 0x2000, 0x80c0, 0x0000, 0x1010, 0x1000, 0x0080, 0x0000, 0xc038, 0x0600, 0xfe82, 0xfe00, 0x82fe, 0x8000, 0xf292, 0x9e00, 0x9292, 0xfe00, 0x1e10, 0xfe00, 0x9e92, 0xf200, 0xfe92, 0xf200, 0x0202, 0xfe00, 0xfe92, 0xfe00, 0x9e92, 0xfe00, 0x0088, 0x0000, 0x80c8, 0x0000, 0x2050, 0x8800, 0x2828, 0x2800, 0x8850, 0x2000, 0x04b2, 0x0c00, 0x70a8, 0x7000, 0xfc12, 0xfc00, 0xfe92, 0x6c00, 0x7c82, 0x4400, 0xfe82, 0x7c00, 0xfe92, 0x9200, 0xfe12, 0x1200, 0x7c82, 0xe400, 0xfe10, 0xfe00, 0x82fe, 0x8200, 0x4080, 0x7e00, 0xfe18, 0xe600, 0xfe80, 0x8000, 0xfe0c, 0xfe00, 0xfe3c, 0xfe00, 0x7c82, 0x7c00, 0xfe12, 0x0c00, 0x7c82, 0xfc00, 0xfe12, 0xec00, 0x4c92, 0x6400, 0x02fe, 0x0200, 0xfe80, 0xfe00, 0x7e80, 0x7e00, 0xfe60, 0xfe00, 0xee10, 0xee00, 0x0ef0, 0x0e00, 0xe292, 0x8e00, 0x00fe, 0x8200, 0x0638, 0xc000, 0x0082, 0xfe00, 0x0402, 0x0400, 0x8080, 0x8080, 0x0002, 0x0400, 0x48a8, 0xf800, 0xfc90, 0x6000, 0x7088, 0x5000, 0x6090, 0xfc00, 0x70a8, 0xb000, 0x20fc, 0x2400, 0xb8a8, 0xf800, 0xfc20, 0xe000, 0x90f4, 0x8000, 0xc090, 0xf400, 0xfc20, 0xd800, 0x04fc, 0x8000, 0xf830, 0xf800, 0xf808, 0xf800, 0x7088, 0x7000, 0xf828, 0x3800, 0x3828, 0xf800, 0xf808, 0x1800, 0xb8a8, 0xe800, 0x10fc, 0x9000, 0xf880, 0xf800, 0x7880, 0x7800, 0xf860, 0xf800, 0xd820, 0xd800, 0x98a0, 0x7800, 0xc8a8, 0x9800, 0x10ee, 0x8200, 0x00fe, 0x0000, 0x82ee, 0x1000, 0x1008, 0x1008, 0x0, 0x0];

    Lem1802.DFL_PALETTE = [0x0fff, 0x0ff0, 0x0f0f, 0x0f00, 0x0ccc, 0x0888, 0x0880, 0x0808, 0x0800, 0x00ff, 0x00f0, 0x0088, 0x0080, 0x000f, 0x0008, 0x0000];

    return Lem1802;

  })();

  exports.Lem1802 = Lem1802;

}).call(this);

});

require.define("/hw/device.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var Device, Module;

  Module = {};

  Device = (function() {

    function Device(name, cpu) {
      if (name == null) name = "?";
      this.mName = name;
      this.mCpu = cpu;
    }

    Device.prototype.id = function() {
      return 0;
    };

    Device.prototype.mfgr = function() {
      return 0;
    };

    Device.prototype.ver = function() {
      return 0;
    };

    Device.prototype.hwInterrupt = function() {
      return;
    };

    Device.prototype.reset = function() {
      return;
    };

    Device.prototype.query = function() {
      return this.fromMfgrId(this.mfgr(), this.id(), this.ver());
    };

    Device.prototype.interrupt = function(m) {
      return this.mCpu.interrupt(m);
    };

    Device.prototype.mapMemory = function(base, len, cb) {
      return this.mCpu.mapDevice(base, len, cb);
    };

    Device.prototype.unmapMemory = function(base) {
      return this.mCpu.unmapDevice(base);
    };

    Device.prototype.fromMfgrId = function(mfgr, id, ver) {
      this.mCpu.regA(id & 0xffff);
      this.mCpu.regB((id >> 16) & 0xffff);
      this.mCpu.regC(ver);
      this.mCpu.regX(mfgr & 0xffff);
      return this.mCpu.regY((mfgr >> 16) & 0xffff);
    };

    return Device;

  })();

  exports.Device = Device;

}).call(this);

});

require.define("/hw/generic-clock.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var Device, GenericClock, Module, device;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  Module = {};

  device = require("./device");

  Device = device.Device;

  GenericClock = (function() {

    __extends(GenericClock, Device);

    function GenericClock(cpu) {
      GenericClock.__super__.constructor.call(this, "Generic Clock", cpu);
      this.mCount = 0;
      this.mIrqMsg = 0;
      this.mTimer = null;
    }

    GenericClock.prototype.id = function() {
      return 0x12d0b402;
    };

    GenericClock.prototype.mfgr = function() {
      return 0x0;
    };

    GenericClock.prototype.ver = function() {
      return 0x1;
    };

    GenericClock.prototype.hwInterrupt = function() {
      switch (this.mCpu.regA()) {
        case 0:
          return this.setRate();
        case 1:
          return this.getTicks();
        case 2:
          return this.setInterrupts();
        default:
          return;
      }
    };

    GenericClock.prototype.reset = function() {
      if (this.mTimer) clearInterval(this.mTimer);
      this.mCount = 0;
      return this.mIrqMsg = 0;
    };

    GenericClock.prototype.setRate = function() {
      this.mRate = this.mCpu.regB();
      this.mCount = 0;
      if (this.mTimer) clearInterval(this.mTimer);
      if (this.mRate) {
        this.mRate = Math.floor(60 / this.mRate);
        this.mRate = 1000 / this.mRate;
        return this.mTimer = setInterval(this.tick(), this.mRate);
      }
    };

    GenericClock.prototype.getTicks = function() {
      return this.mCpu.regC(this.mCount);
    };

    GenericClock.prototype.setInterrupts = function() {
      return this.mIrqMsg = this.mCpu.regB();
    };

    GenericClock.prototype.tick = function() {
      var clock;
      clock = this;
      return function() {
        clock.mCount++;
        if (clock.mIrqMsg) return clock.interrupt(clock.mIrqMsg);
      };
    };

    return GenericClock;

  })();

  exports.GenericClock = GenericClock;

}).call(this);

});

require.define("/hw/generic-keyboard.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var Device, GenericKeyboard, Module;
  var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  Module = {};

  Device = require("./device").Device;

  GenericKeyboard = (function() {

    __extends(GenericKeyboard, Device);

    function GenericKeyboard(cpu) {
      GenericKeyboard.__super__.constructor.call(this, "Generic Keyboard", cpu);
      this.mKeyBuffer = [];
    }

    GenericKeyboard.prototype.id = function() {
      return 0x30cf7406;
    };

    GenericKeyboard.prototype.mfgr = function() {
      return 0x0;
    };

    GenericKeyboard.prototype.ver = function() {
      return 0x1;
    };

    GenericKeyboard.prototype.hwInterrupt = function() {
      switch (this.mCpu.regA()) {
        case 0:
          return this.clearBuffer();
        case 1:
          return this.nextKey();
        case 2:
          return this.isPressed();
        case 3:
          return this.setInterrupts();
        default:
          return;
      }
    };

    GenericKeyboard.prototype.clearBuffer = function() {
      return this.mKeyBuffer = [];
    };

    GenericKeyboard.prototype.nextKey = function() {
      var key;
      if (this.mKeyBuffer.length === 0) return 0;
      key = this.mKeyBuffer[0];
      this.mKeyBuffer = this.mKeyBuffer.slice(1);
      return this.mCpu.regC(key);
    };

    GenericKeyboard.prototype.isPressed = function() {
      return this.mCpu.regC(0);
    };

    GenericKeyboard.prototype.setInterrupts = function() {
      return this.mIrqMsg = this.mCpu.regB();
    };

    return GenericKeyboard;

  })();

  exports.GenericKeyboard = GenericKeyboard;

}).call(this);

});

require.define("/webapp.coffee", function (require, module, exports, __dirname, __filename) {
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

    function File(name) {
      var editor, id, link, node, pane;
      this.mText = "";
      this.mName = name;
      id = name.split(".").join("_");
      $('#projFiles').append("<li><a href='#'><i class='icon-file'></i>" + name + "</a></li>");
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
        keyMap: "vim"
      });
      $("a[href=#openFile-" + id).tab("show");
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

    return File;

  })();

  DcpuWebapp = (function() {

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
      file = new File("msg.s");
      file.text(demoProgramMsg);
      this.mFiles.push(file);
      this.mCreateDialog = $("#newFile").modal({
        show: false
      });
      this.mCreateDialog.hide();
      this.assemble();
    }

    DcpuWebapp.prototype.updateRegs = function() {
      var i, v, _len, _ref, _results;
      _ref = this.mRegs;
      _results = [];
      for (i = 0, _len = _ref.length; i < _len; i++) {
        v = _ref[i];
        _results.push(v.html('0x' + dasm.Disasm.fmtHex(this.mCpu.readReg(i))));
      }
      return _results;
    };

    DcpuWebapp.prototype.updateCycles = function() {
      return $("#cycles").html("" + this.mCpu.mCycles);
    };

    DcpuWebapp.prototype.dumpMemory = function() {
      var base, body, c, col, html, r, row, v, _results;
      base = $("#membase").val();
      if (!base) base = 0;
      base = parseInt(base);
      body = $("#memdump-body");
      body.empty();
      _results = [];
      for (r = 0; r <= 4; r++) {
        row = $("<tr><td>" + (dasm.Disasm.fmtHex(base + (r * 8))) + "</td></tr>");
        for (c = 0; c <= 7; c++) {
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
        jobs.push(this.mAsm.assemble(file.text()));
      }
      exe = asm.JobLinker.link(jobs);
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
        while (app.mCpu.cycles() < target) {
          app.mCpu.step();
        }
        app.updateRegs();
        app.updateCycles();
        if (app.mLoopCount >= 20) return app.mLoopCount = 0;
      };
      if (this.mRunTimer) clearInterval(this.timer);
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
      this.mCpu.step();
      return this.updateRegs();
    };

    DcpuWebapp.prototype.reset = function() {
      this.stop();
      this.mCpu.reset();
      this.assemble();
      return this.updateCycles();
    };

    DcpuWebapp.prototype.create = function(f) {
      this.mFiles.push(new File(f));
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
        if (!base) base = 0;
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
        set a, 1\n\
:loop hwi 1\n\
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
:crash  set pc, crash\n';

  demoProgramMsg = '\
:ohhey  dat "So the linker works (kinda).", 0\
';

}).call(this);

});
require("/webapp.coffee");
