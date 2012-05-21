#
# dcpu-asm.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# DCPU-16 Assembler
#

Module = {}

decode = require './dcpu-decode'
dasm = require './dcpu-disasm'

Instr = decode.Instr

#
# Class to handle register values.
#
class RegValue
  constructor: (asm, reg) ->
    @mAsm = asm
    @mReg = reg
  emit: (stream) -> []
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
  emit: (stream) ->
    if not @mLit? then return
    if @mLit? then stream.push @mLit.value()
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

  emit: (stream) ->
    if @isLabel()
      stream.push @mLit
    else if @mLit > 0x1e or @isLabel()
      stream.push @value()

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
  emit: () -> undefined
  encode: () -> @mRaw

class Data
  constructor: (asm, dat) ->
    @mAsm = asm
    @mData = dat

  emit: (stream) -> stream.push @mData

class Instruction
  constructor: (asm, opc, vals) ->
    @mAsm = asm
    @mLine = 0
    @mSize = 0
    @mOp = opc
    @mVals = vals

  emit: (stream) ->
    enc = (v.encode() for v in @mVals)
    instr = @mOp | (enc[0] << 5) | (enc[1] << 10)
    stream.push instr
    v.emit stream for v in @mVals

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

    console.log jobs[0].sections[0]

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
      if (addr = syms[v])?
        code[i] = addr
      else if isNaN v
        console.log "Error: Undefined Symbol '#{v}'"

    return r =
      format: "job"
      version: 0.1
      source: "Tims Linker"
      file: "??"
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
  @basic_regex = ///(\w+)\s+([^,]+)\s*,\s*([^,]+)///
  @adv_regex = ///(\w+)\s+([^,]+)///
  @str_regex = ///"([^"]*)"///

  #
  # Line Parsers.
  #
  # match: regular expression to match to each line.
  # f: If a line matches the regex, the match object is passed to the function.
  #
  @LINE_PARSERS = [
    @LP_EMPTY =   {match: /^$/,             f: 'lpEmpty'},
    @LP_DIRECT =  {match: /^\..*/,            f: 'lpDirect'},
    @LP_DAT =     {match: /^[dD][aA][tT].*/,  f: 'lpDat'},
    @LP_COMMENT = {match: /^;.*/,             f: 'lpComment'},
    @LP_LABEL =   {match: /^:.*/,             f: 'lpLabel'},
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
    @mInstrs = {}
    @mOpcDict = {}
    @mSect = ".text"
    for op in Instr.BASIC_OPS
      if op? then @mOpcDict[op.id.toUpperCase()] = op
    for op in Instr.ADV_OPS
      if op? then @mOpcDict[op.id.toUpperCase()] = op

  label: (name, addr) ->
    console.log "labeling #{name}"
    if not @mLabels[@mSect]?
      @mLabels[@mSect] = {}
    @mLabels[@mSect][name] = addr

  lookup:      (name) -> @mLabels[@mSect][name]
  defined:     (name) -> lookup(name)?
  section:        (s) -> @mSect = s
  incPc:           () -> ++@mPc

  processValue: (val) ->
    val = val.trim()
    match = undefined
    for vp in Assembler.VALUE_PARSERS
      if match = val.match vp.match
        return this[vp.f] match
    console.log "Unmatched value: #{val}"

  processLine: (line) ->
    line = line.trim()
    match = undefined
    for lp in Assembler.LINE_PARSERS
      if match = line.match lp.match
        return this[lp.f] match
    console.log "Unmatched line: #{line}"

  out: (i) ->
    console.log i
    if not @mInstrs[@mSect]?
      @mInstrs[@mSect] = []
    @mInstrs[@mSect].push i

  emit: (sec, stream) ->
    for i in @mInstrs[sec]
      console.log i.mOpc
      i.emit stream 

  assemble: (text) ->
    lines = text.split "\n"
    for l in lines
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

  lpEmpty:  (match) ->
  lpDirect: (match) ->
  lpDat:    (match) ->
    console.log "Dat: #{match[0]}"
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

  lpComment:(match) ->

  lpLabel:  (match) ->
    toks = match[0].match /[^ \t]+/g
    @label toks[0][1..], @mPc
    @processLine (toks[1..].join " ")

  lpIBasic: (match) ->
    console.log "Basic #{match[0]}"
    [opc, valA, valB] = match[1..3]
    if not @mOpcDict[opc]?
      return r =
        result: "fail"
        message: "Unknown Opcode: #{opc}"
    enc = @mOpcDict[opc].op
    @incPc()
    valA = @processValue valA
    valB = @processValue valB
    @out new Instruction(@, enc, [valA, valB])

  lpIAdv:   (match) ->
    console.log "Adv #{match[0]}"
    [opc, valA] = match[1..2]
    if not @mOpcDict[opc]?
      return r =
        result: "fail"
        message: "Unknown Opcode: #{opc}"
    enc = @mOpcDict[opc].op
    @incPc()
    valB = @processValue valA
    valA = new RawValue @, enc
    @out new Instruction(@, 0, [valA,valB])

  #
  # Any word-like matches. This means all of the following are handled:
  #   Regs (A,B,C,X,Y,Z,EX,PC,SP)
  #   Stack Ops (PUSH, POP, PEEK, PICK)
  #   Label references
  #
  vpWord:  (match) ->
    switch match[1].toUpperCase()
      when "POP"    then new RawValue @, 0x18
      when "PEEK"   then new RawValue @, 0x19
      when "PUSH"   then new RawValue @, 0x1a
      when "SP"     then new RawValue @, 0x1b
      when "PC"     then new RawValue @, 0x1c
      when "O"      then new RawValue @, 0x1d
      else
        regid = dasm.Disasm.REG_DISASM.indexOf match[1]
        if regid == -1
          return new LitValue(@, match[1])
        else
          return new RegValue(@, regid)

  vpIWord: (match) ->
    regid = dasm.Disasm.REG_DISASM.indexOf match[1]
    if regid == -1
      return new MemValue(@, undefined, new LitValue(@, match[1]))
    else
      return new MemValue(@, regid, undefined)

  vpLit:  (match) ->
    new LitValue(@, parseInt match[1])

  vpILit: (match) ->
    n = parseInt match[1]
    new MemValue(@, undefined, new LitValue(@, n))

  vpArr:  (match) ->
    if (r = dasm.Disasm.REG_DISASM.indexOf match[2]) != -1
      return new MemValue(@, r, new LitValue(@, match[1]))
    if (r = dasm.Disasm.REG_DISASM.indexOf match[1]) != -1
      return new MemValue(@, r, new LitValue(@, match[2]))
    else
      console.log "Unmatched value #{val}"

  dirGlobal: (line) -> undefined

  dirText: (_) -> @section ".text"

  dirData: (_) -> @section ".data"

exports.Assembler = Assembler
exports.JobLinker = JobLinker
