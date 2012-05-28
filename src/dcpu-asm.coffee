#
#  Copyright(C) 2012, Tim Detwiler <timdetwiler@gmail.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This software is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this software.  If not, see <http://www.gnu.org/licenses/>.
#
Module = {}

decode = require './dcpu-decode'
dasm = require './dcpu-disasm'

Instr = decode.Instr
Value = decode.Value

#
# Class to handle register values.
#
class RegValue
  constructor: (asm, reg) ->
    @mAsm = asm
    @mReg = reg
  emit: () ->
  encode: () -> @mReg

class MemValue
  #
  # Class to handle all memory values:
  # [register]
  # [register+next word]
  # [next word]
  #
  # To specify a register, pass the Register ID to the ctor.
  # To specify a literal value (next word), pass a LitValue
  # object to the ctor.
  #
  constructor: (asm, reg=undefined, lit=undefined) ->
    @mAsm = asm
    @mReg = reg
    @mLit = lit

  emit: () ->
    if not @mLit? then return
    return @mLit.value()

  encode: () ->
    if @mLit? and @mReg? and not @mLit.isLabel()
      @mReg + 0x10
    else if @mReg?
      @mReg + 0x8
    else if @mLit?
      0x1e
    else
      console.log "ERROR: MemValue with corrupted state."

#
# Class to handle literal values.
#
# Pass a numeric literal, or a string defining a label to the
# ctor.
#
class LitValue
  constructor: (asm,lit) ->
    @mAsm = asm
    @mLit = lit

    if (n = parseInt lit) then @mLit = n
    if @mLit > 0x1f or @isLabel() then @mAsm.incPc()

  isLabel: () -> isNaN @mLit

  value: () ->
    if @isLabel()
      addr = @mAsm.lookup @mLit
      if not addr?
        console.log "Undefined label '#{@mLit}'"
      return addr
    else
      return @mLit

  emit: () ->
    if @isLabel()
      @mLit
    else if @mLit > 0x1e or @isLabel()
      @value()

  encode: () ->
    if @mLit == -1
      0x20
    else if @mLit > 0x1f or @isLabel()
      0x1f
    else
      @mLit + 0x21

class RawValue
  constructor: (asm, raw) ->
    @mAsm = asm
    @mRaw = raw
  emit: () ->
  encode: () -> @mRaw

class Data
  constructor: (asm, dat) ->
    @mAsm = asm
    @mData = dat
    @mFile = asm.file()
    @mLine = asm.line()

  emit: (stream) ->
    stream.push {val: @mData, file: @mFile, line: @mLine}

class Instruction
  constructor: (asm, opc, vals) ->
    @mAsm = asm
    @mLine = 0
    @mSize = 0
    @mOp = opc
    @mVals = vals
    @mFile = asm.file()
    @mLine = asm.line()

  emit: (stream) ->
    enc = (v.encode() for v in @mVals)
    instr = @mOp | (enc[0] << 5) | (enc[1] << 10)
    stream.push {val: instr, file: @mFile, line: @mLine}
    for v in @mVals
      if (enc = v.emit())?
        stream.push {val: enc, file: @mFile, line: @mLine}

#
# JSON Object File Linker
#
class JobLinker
  @mergeSyms: (a, b, o) ->
    for k,v of b
      if a[k]?
        console.log "Warning, redefinition of symbol '#{k}'"
      else
        a[k] = v+o

  @link: (jobs) ->
    code = []
    syms = {}

    #
    # Merge sections and symbols
    #
    for job in jobs
      @mergeSyms(syms, job.sections[0].sym, code.length)
      code = code.concat job.sections[0].data

    #
    # Resolve
    #
    for v,i in code
      if (addr = syms[v.val])?
        code[i] = {val: addr, file: v.file, line: v.line}
      else if isNaN v.val
        console.log "Error: Undefined Symbol '#{v}'"

    return r =
      format: "job"
      version: 0.1
      source: "Tims Linker"
      sections : [
        {name: ".text", data: code, sym: syms}
      ]

class Assembler
  #
  # Regex's for parsing
  #
  @reg_regex = ///^([a-zA-Z_]+)///
  @ireg_regex = ///^\[\s*([a-zA-Z]+|\d+)\s*\]///
  @lit_regex = ///^(0[xX][0-9a-fA-F]+|\d+)///
  @ilit_regex = ///^\[\s*(0[xX][0-9a-fA-F]+|\d+)\s*\]///
  @arr_regex = ///^\[\s*([0-9a-zA-Z]+)\s*\+\s*([0-9a-zA-Z]+)\s*\]///
  @str_regex = ///"([^"]*)"///
  @basic_regex = ///(\w+)\s+([^,]+)\s*,\s*([^,]+)///
  @adv_regex = ///(\w+)\s+([^,]+)///
  @dir_regex = ///(\.[a-zA-Z0-9]+)(.*)///

  #
  # Line Parsers.
  #
  # match: regular expression to match to each line.
  # f: If a line matches the regex, the match object is passed to the function.
  #
  @LINE_PARSERS = [
    @LP_EMPTY =   {match: /^$/,             f: 'lpEmpty'},
    @LP_DIRECT =  {match: @dir_regex,       f: 'lpDirect'},
    @LP_DAT =     {match: /^[dD][aA][tT].*/,f: 'lpDat'},
    @LP_COMMENT = {match: /^;.*/,           f: 'lpComment'},
    @LP_LABEL =   {match: /^:.*/,           f: 'lpLabel'},
    @LP_ISIMP =   {match: @basic_regex,     f: 'lpIBasic'},
    @LP_IADV =    {match: @adv_regex,       f: 'lpIAdv'},
  ]

  #
  # Value Parsers. Used by ISIMP and IADV line parsers.
  #
  # match: regular expression to match to each value.
  # f: If a line matches the regex, the match object is passed to the function.
  #
  @VALUE_PARSERS = [
    @VP_WORD =    {match: @reg_regex,       f: 'vpWord'},
    @VP_IWORD =   {match: @ireg_regex,      f: 'vpIWord'},
    @VP_LIT =     {match: @lit_regex,       f: 'vpLit'},
    @VP_ILIT =    {match: @ilit_regex,      f: 'vpILit'},
    @VP_ARR =     {match: @arr_regex,       f: 'vpArr'},
  ]

  @DIRECTS = [
    @DIR_GLOBAL =   {id: ".globl",   f: 'dirGlobal'},
    @DIR_GLOBAL0 =  {id: ".global",  f: 'dirGlobal'},
    @DIR_TEXT =     {id: ".text",    f: 'dirText'},
    @DIR_DATA =     {id: ".data",    f: 'dirData'},
  ]

  constructor: () ->
    @mPc = 0
    @mText = ""
    @mLabels = {}
    @mExports = {}
    @mInstrs = {}
    @mOpcDict = {}
    @mSect = ".text"
    for op in Instr.BASIC_OPS
      if op? then @mOpcDict[op.id.toUpperCase()] = op
    for op in Instr.ADV_OPS
      if op? then @mOpcDict[op.id.toUpperCase()] = op
    @mFile = "undefined"
    @mLine = 0

  label: (name, addr) ->
    if not @mLabels[@mSect]?
      @mLabels[@mSect] = {}
    @mLabels[@mSect][name] = addr

  export: (name, addr) ->
    if not @mExports[@mSect]?
      @mExports[@mSect] = {}
    @mExports[@mSect][name] = addr

  lookup:      (name) -> @mLabels[@mSect][name]
  defined:     (name) -> lookup(name)?
  incPc:           () -> ++@mPc

  processValue: (val) ->
    val = val.trim()
    for vp in Assembler.VALUE_PARSERS
      if match = val.match vp.match
        return this[vp.f] match
    console.log "Unmatched value: #{val}"

  processLine: (line) ->
    line = line.trim()
    for lp in Assembler.LINE_PARSERS
      if match = line.match lp.match
        return this[lp.f] match
    console.log "Unmatched line: #{line}"

  out: (i) ->
    if not @mInstrs[@mSect]?
      @mInstrs[@mSect] = []
    @mInstrs[@mSect].push i

  emit: (sec, stream) ->
    for i in @mInstrs[sec]
      i.emit stream 

  assemble: (text, fn = "undefined") ->
    lines = text.split "\n"
    @mFile = fn

    i = 0
    for l in lines
      @mLine = i++
      @processLine l

    #
    # Instruction objects are constained in lists by section.
    #
    sections = []
    for s,i of @mInstrs
      prog = []
      @emit s, prog
      sections.push {name: s, data: prog, sym: @mLabels[s]}

    return r =
      format: "job"
      version: 0.1
      source: "Tims Assembler"
      sections: sections

  assembleAndLink: (text) ->
    job = @assemble text
    exe = JobLinker.link [job]

  line: () -> @mLine
  file: () -> @mFile

  #############################################################################
  # Line Parsers
  #############################################################################
  #
  # Matches an empty line (no action)
  #
  lpEmpty:  (match) ->

  #
  # Matches a directive ('.<directive>')
  #
  lpDirect: (match) ->
    name = match[1].toUpperCase()
    console.log "Directive '#{name}'"
    for d in Assembler.DIRECTS
      if name == d.id.toUpperCase()
        return this[d.f] match

  #
  # Matches a comment line
  #
  lpComment:(match) ->

  #
  # Matches the 'DAT' pseudo-op
  #
  lpDat:    (match) ->
    toks = match[0].match(/[^ \t]+/g)[1..].join(" ").split(",")
    for tok in toks
      tok = tok.trim()
      if tok[0] is ";" then break
      if match = tok.match Assembler.str_regex
        for c in match[1]
          @out(new Data @, c.charCodeAt(0))
      else if (n = parseInt tok)?
        @out(new Data @, n)
      else
        console.log "Bad Data String: '#{tok}'"


  #
  # Matches a Labeled line (:label)
  #
  # Note this parser must recurse since it it legal to have instructions on the
  # same line as a label
  #
  # Ex:
  # :crash set pc, crash
  #
  lpLabel:  (match) ->
    toks = match[0].match /[^ \t]+/g
    @label toks[0][1..], @mPc
    @processLine (toks[1..].join " ")

  #
  # Matches a basic (2-value) instruction
  #
  lpIBasic: (match) ->
    [opc, valA, valB] = match[1..3]
    enc = @mOpcDict[opc.toUpperCase()].op
    @incPc()
    valA = @processValue valA
    valB = @processValue valB
    @out new Instruction(@, enc, [valA, valB])

  #
  # Matches an advanced (1-value) instruction
  #
  lpIAdv:   (match) ->
    [opc, valA] = match[1..2]

    #
    # 'b' is a pseudo-instruction to let the linker attempt to insert a
    # relative branch with 'add pc, imm' or 'sub pc, imm'. This will mean one
    # word shorter instructions for jumps within +/- 30B.
    #
    if opc == 'b'
      return console.log "Branch #{valA}"
    enc = @mOpcDict[opc.toUpperCase()].op
    @incPc()
    valB = @processValue valA
    valA = new RawValue @, enc
    @out new Instruction(@, 0, [valA,valB])

  #############################################################################
  # Value Parsers
  #############################################################################
  #
  # Any word-like matches. This means all of the following are handled:
  #   Regs (A,B,C,X,Y,Z,EX,PC,SP)
  #   Stack Ops (PUSH, POP, PEEK, PICK)
  #   Label references
  #
  vpWord:  (match) ->
    switch match[1].toUpperCase()
      when "POP"    then new RawValue @, Value.VAL_POP
      when "PUSH"   then new RawValue @, Value.VAL_PUSH
      when "PEEK"   then new RawValue @, Value.VAL_PEEK
      when "SP"     then new RawValue @, Value.VAL_SP
      when "PC"     then new RawValue @, Value.VAL_PC
      when "EX"     then new RawValue @, Value.VAL_EX
      else
        regid = dasm.Disasm.REG_DISASM.indexOf match[1].toUpperCase()
        if regid == -1
          return new LitValue(@, match[1])
        else
          return new RegValue(@, regid)

  #
  # Any indirect word-like match
  #   [REG]
  #   [LABEL]
  #
  vpIWord: (match) ->
    regid = dasm.Disasm.REG_DISASM.indexOf match[1].toUpperCase()
    if regid == -1
      return new MemValue(@, undefined, new LitValue(@, match[1]))
    else
      return new MemValue(@, regid, undefined)

  #
  # Matches a literal value (decimal or hex)
  #
  vpLit:  (match) ->
    new LitValue(@, parseInt match[1])

  #
  # Matches an indirect literal value (decimal or hex)
  #
  vpILit: (match) ->
    n = parseInt match[1]
    new MemValue(@, undefined, new LitValue(@, n))

  #
  # Matches the array-indexing value
  #   [WORD+REG]
  #   [REG+WORD]
  #
  # If WORD is not a literal value (decimal or hex), then it is assumed to be
  # a label.
  #
  vpArr:  (match) ->
    if (r = dasm.Disasm.REG_DISASM.indexOf match[2].toUpperCase()) != -1
      return new MemValue(@, r, new LitValue(@, match[1]))
    if (r = dasm.Disasm.REG_DISASM.indexOf match[1].toUpperCase()) != -1
      return new MemValue(@, r, new LitValue(@, match[2]))
    else
      console.log "Unmatched value #{match[0]}"

  #############################################################################
  # Directive Handlers
  #############################################################################
  #
  # Matches the global directive, which exports a symbol
  #
  dirGlobal: (match) ->
    console.log "exporting '#{match[2]}'"
    @export match[2]

exports.Assembler = Assembler
exports.JobLinker = JobLinker
