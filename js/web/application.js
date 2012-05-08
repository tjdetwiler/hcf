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

require.define("/dcpu.coffee", function (require, module, exports, __dirname, __filename) {
(function() {
  var Dcpu16, Instr, Module, Value;

  Module = {};

  Value = (function() {

    function Value(cpu, enc) {
      this.mCpu = cpu;
      this.isMem = false;
      this.isReg = false;
      this.mEncoding = enc;
      this.mNext = 0;
      if ((0x00 <= enc && enc <= 0x07)) {
        this.isReg = true;
        this.mValue = enc;
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
      } else if ((0x20 <= enc && enc <= 0x3f)) {
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
      var v, valA, valB;
      valA = this.mValA;
      valB = this.mValB;
      switch (this.mOpc) {
        case Dcpu16.OPC_ADV:
          return this.execAdv(valA.raw(), valB);
        case Dcpu16.OPC_SET:
          return valA.set(valB.get());
        case Dcpu16.OPC_ADD:
          this.mCycles += 1;
          v = valA.get() + valB.get();
          if (v > 0xffff) {
            this.mCpu.regO(1);
            v -= 0xffff;
          } else {
            this.mCpu.regO(0);
          }
          return valA.set(v);
        case Dcpu16.OPC_SUB:
          this.mCycles += 1;
          v = valA.get() - valB.get();
          if (v < 0) {
            this.mCpu.regO(0xffff);
            v += 0xffff;
          } else {
            this.mCpu.regO(0);
          }
          return valA.set(v);
        case Dcpu16.OPC_MUL:
          this.mCycles += 1;
          v = valA.get() * valB.get();
          valA.set(v & 0xffff);
          return this.mCpu.regO((v >> 16) & 0xffff);
        case Dcpu16.OPC_DIV:
          this.mCycles += 2;
          if (valB.get() === 0) {
            return regA.set(0);
          } else {
            v = valA.get() / valB.get();
            valA.set(v & 0xffff);
            return this.mCpu.regO(((valA.get() << 16) / valB.get) & 0xffff);
          }
          break;
        case Dcpu16.OPC_MOD:
          this.mCycles += 2;
          if (valB.get() === 0) {
            return regA.set(0);
          } else {
            return valA.set(valA.get() % valB.get());
          }
          break;
        case Dcpu16.OPC_SHL:
          this.mCycles += 1;
          valA.set(valA.get() << valB.get());
          return this.mCpu.regO(((valA.get() << valB.get()) >> 16) & 0xffff);
        case Dcpu16.OPC_SHR:
          this.mCycles += 1;
          valA.set(valA.get() >> valB.get());
          return this.mCpu.regO(((valA.get() << 16) >> valB.get()) & 0xffff);
        case Dcpu16.OPC_AND:
          return valA.set(valA.get() & valB.get());
        case Dcpu16.OPC_BOR:
          return valA.set(valA.get() | valB.get());
        case Dcpu16.OPC_XOR:
          return valA.set(valA.get() ^ valB.get());
        case Dcpu16.OPC_IFE:
          if (valA.get() === valB.get()) {
            return this.mCycles += 2;
          } else {
            this.mCpu.mSkipNext = true;
            return this.mCycles += 1;
          }
          break;
        case Dcpu16.OPC_IFN:
          if (valA.get() !== valB.get()) {
            return this.mCycles += 2;
          } else {
            this.mCpu.mSkipNext = true;
            return this.mCycles += 1;
          }
          break;
        case Dcpu16.OPC_IFG:
          if (valA.get() > valB.get()) {
            return this.mCycles += 2;
          } else {
            this.mCpu.mSkipNext = true;
            return this.mCycles += 1;
          }
          break;
        case Dcpu16.OPC_IFB:
          if ((valA.get() & valB.get()) !== 0) {
            return this.mCycles += 2;
          } else {
            this.mCpu.mSkipNext = true;
            return this.mCycles += 1;
          }
      }
    };

    return Instr;

  })();

  Dcpu16 = (function() {
    var _i, _j, _ref, _ref2, _results, _results2;

    _ref = (function() {
      _results = [];
      for (var _i = 0x0; 0x0 <= 0xf ? _i <= 0xf : _i >= 0xf; 0x0 <= 0xf ? _i++ : _i--){ _results.push(_i); }
      return _results;
    }).apply(this), Dcpu16.OPC_ADV = _ref[0], Dcpu16.OPC_SET = _ref[1], Dcpu16.OPC_ADD = _ref[2], Dcpu16.OPC_SUB = _ref[3], Dcpu16.OPC_MUL = _ref[4], Dcpu16.OPC_DIV = _ref[5], Dcpu16.OPC_MOD = _ref[6], Dcpu16.OPC_SHL = _ref[7], Dcpu16.OPC_SHR = _ref[8], Dcpu16.OPC_AND = _ref[9], Dcpu16.OPC_BOR = _ref[10], Dcpu16.OPC_XOR = _ref[11], Dcpu16.OPC_IFE = _ref[12], Dcpu16.OPC_IFN = _ref[13], Dcpu16.OPC_IFG = _ref[14], Dcpu16.OPC_IFB = _ref[15];

    Dcpu16.ADV_JSR = [1][0];

    _ref2 = (function() {
      _results2 = [];
      for (var _j = 0x0; 0x0 <= 0xa ? _j <= 0xa : _j >= 0xa; 0x0 <= 0xa ? _j++ : _j--){ _results2.push(_j); }
      return _results2;
    }).apply(this), Dcpu16.REG_A = _ref2[0], Dcpu16.REG_B = _ref2[1], Dcpu16.REG_C = _ref2[2], Dcpu16.REG_X = _ref2[3], Dcpu16.REG_Y = _ref2[4], Dcpu16.REG_Z = _ref2[5], Dcpu16.REG_I = _ref2[6], Dcpu16.REG_J = _ref2[7], Dcpu16.REG_PC = _ref2[8], Dcpu16.REG_SP = _ref2[9], Dcpu16.REG_O = _ref2[10];

    function Dcpu16(program) {
      var i, x, _len;
      if (program == null) program = [];
      this.mCycles = 0;
      this.mRegs = [];
      this.mSkipNext = false;
      for (x = 0; 0 <= 0xf ? x <= 0xf : x >= 0xf; 0 <= 0xf ? x++ : x--) {
        this.mRegs[x] = 0;
      }
      this.mRegs[Dcpu16.REG_SP] = 0xffff;
      this.mMemory = (function() {
        var _results3;
        _results3 = [];
        for (x = 0; 0 <= 0xffff ? x <= 0xffff : x >= 0xffff; 0 <= 0xffff ? x++ : x--) {
          _results3.push(0);
        }
        return _results3;
      })();
      for (i = 0, _len = program.length; i < _len; i++) {
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

    Dcpu16.prototype.onCondFail = function(fn) {
      return this.mCondFail = fn;
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
      var i, x, _len, _results3;
      if (base == null) base = 0;
      _results3 = [];
      for (i = 0, _len = bin.length; i < _len; i++) {
        x = bin[i];
        _results3.push(this.mMemory[base + i] = x);
      }
      return _results3;
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
        if (this.mCondFail != null) this.mCondFail(i);
        return this.step();
      }
      if (this.mPreExec != null) this.mPreExec(i);
      i.exec();
      if (this.mPostExec != null) return this.mPostExec(i);
    };

    Dcpu16.prototype.run = function() {
      var _results3;
      this.mRun = true;
      _results3 = [];
      while (this.mRun) {
        _results3.push(this.step());
      }
      return _results3;
    };

    Dcpu16.prototype.stop = function() {
      return this.mRun = false;
    };

    return Dcpu16;

  })();

  exports.Dcpu16 = Dcpu16;

}).call(this);

});

require.define("/webapp.coffee", function (require, module, exports, __dirname, __filename) {
    (function() {
  var dcpu;

  dcpu = require('../dcpu');

  console.log(dcpu);

}).call(this);

});
require("/webapp.coffee");
