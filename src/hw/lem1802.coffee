#
# hw/lem1802.coffee
# Tim Detwiler <timdetwiler@gmail.com>
#
# LEM1802 Display Device.
# Based on the spec at: http://dcpu.com/highnerd/lem1802.txt
#
Module = {}

device = require "./device"
Device = device.Device

class Lem1802 extends Device
  constructor: (cpu, canvas=undefined) ->
    super "LEM1802", cpu
    @mCanvas = canvas
    @mCtx = if canvas? then canvas.getContext '2d'
    @mScale = 4
    @mScreenAddr = 0
    @mFontAddr = 0
    @mPaletteAddr = 0
    @mScreen = undefined
    @mUserFont = undefined
    @mUserPalette = undefined
    @clear()

  id:   () -> 0x7349f615
  mfgr: () -> 0x1c6c8b38
  ver:  () -> 0x1802

  hwInterrupt: () -> switch @mCpu.regA()
    when 0 then @memMapScreen()
    when 1 then @memMapFont()
    when 2 then @memMapPalette()
    when 3 then @setBorderColor()
    else undefined

  memMapScreen:     () ->
    base = @mCpu.regB()
    if base is 0
      @unmapMemory @mScreenAddr
      @mScreen = undefined
    else
      @mapMemory base, @VID_RAM_SIZE, @_screenCB()
      @mScreen = (0 for _ in [0..@VID_RAM_SIZE])
    @mScreenAddr = base

  memMapFont:       () ->
    base = @mCpu.regB()
    if base is 0
      @unmapMemory @mFontAddr
      @mUserFont = undefined
    else
      @mapMemory base, @FONT_RAM_SIZE, @_fontCB()
      @mUserFont = (0 for _ in [0..@FONT_RAM_SIZE])
    @mFontAddr = base

  memMapPalette:    () ->
    base = @mCpu.regB()
    if base is 0
      @unmapMemory @mPaletteAddr
      @mUserPalette = undefined
    else
      @mapMemory base, @PALETTE_RAM_SIZE, @_paletteCB()
      @mUserPalette = (0 for _ in [0..@PALETTE_RAM_SIZE])
    @mPaletteAddr = base

  setBorderColor:   () -> undefined

  readFontRam:    (i) ->
    Lem1802.DFL_FONT[i]

  readPaletteRam: (i) ->
    word = Lem1802.DFL_PALETTE[i]
    b = word & 0xf
    g = (word >> 4) & 0xf
    r = (word >> 8) & 0xf
    {r:r, g:g, b:b}

  rgbString: (c) ->
    "rgb(#{c.r*16}, #{c.g*16}, #{c.b*16})"

  getChar: (c) ->
    #[@readFontRam(c*2+1), @readFontRam(c*2)]
    [@readFontRam(c*2), @readFontRam(c*2+1)]

  #
  # x - X coordinate to place character
  # y - Y coordinate to place character
  #
  drawChar: (x,y,c) ->
    # Can't draw without a context
    if not @mCtx? then return
    bg = (c >> 8) & 0xf
    fg = (c >> 12) & 0xf
    c = c & 0x7f
    x = x*4
    y = y*8

    c = @getChar c
    @mCtx.fillStyle = @rgbString @readPaletteRam bg
    @mCtx.fillRect(x*@mScale, y*@mScale, 4*@mScale, 8*@mScale)
    @mCtx.fillStyle = @rgbString @readPaletteRam fg
    for i in [31..0]
      word = Math.floor i/16
      bit  = i % 16
      if c[1-word] & (1<<bit)
        x_ = x + 3 - Math.floor i/8
        y_ = y + (i%8)
        @mCtx.fillRect(x_*@mScale,y_*@mScale,@mScale,@mScale)

  clear: () ->
    if not @mCtx? then return
    @mCtx.fillStyle = @rgbString @readPaletteRam 0xf
    @mCtx.fillRect(0, 0, 128 * @mScale, 96 * @mScale)

  #
  # Memory Mapped Callbacks
  #
  _screenCB:    () ->
    lem = this
    (a,v) ->
      console.log "Screen CB"
      x = a % 32
      y = Math.floor a/32
      lem.drawChar x,y,v

  _fontCB:      () ->
    lem = this
    (a,v) ->
      console.log "Font CB"

  _paletteCB:   () ->
    lem = this
    (a,v) ->
      console.log "Palette CB"


  VID_RAM_SIZE:     386
  FONT_RAM_SIZE:    256
  PALETTE_RAM_SIZE: 16

  @DFL_FONT: [
    0x0,0x0,  #0:   NON-PRINT
    0x0,0x0,  #1:   NON-PRINT
    0x0,0x0,  #2:   NON-PRINT 
    0x0,0x0,  #3:   NON-PRINT
    0x0,0x0,  #4:   NON-PRINT
    0x0,0x0,  #5:   NON-PRINT
    0x0,0x0,  #6:   NON-PRINT
    0x0,0x0,  #7:   NON-PRINT
    0x0,0x0,  #8:   NON-PRINT
    0x0,0x0,  #9:   NON-PRINT
    0x0,0x0,  #10:  NON-PRINT
    0x0,0x0,  #11:  NON-PRINT
    0x0,0x0,  #12:  NON-PRINT
    0x0,0x0,  #13:  NON-PRINT
    0x0,0x0,  #14:  NON-PRINT
    0x0,0x0,  #15:  NON-PRINT
    0x0,0x0,  #16:  NON-PRINT
    0x0,0x0,  #17:  NON-PRINT
    0x0,0x0,  #18:  NON-PRINT
    0x0,0x0,  #19:  NON-PRINT
    0x0,0x0,  #20:  NON-PRINT
    0x0,0x0,  #21:  NON-PRINT
    0x0,0x0,  #22:  NON-PRINT
    0x0,0x0,  #23:  NON-PRINT
    0x0,0x0,  #24:  NON-PRINT
    0x0,0x0,  #25:  NON-PRINT
    0x0,0x0,  #26:  NON-PRINT
    0x0,0x0,  #27:  NON-PRINT
    0x0,0x0,  #28:  NON-PRINT
    0x0,0x0,  #29:  NON-PRINT
    0x0,0x0,  #30:  NON-PRINT
    0x0,0x0,  #31:  NON-PRINT
    0x0000,0x0000,  #32:  ' '
    0x00be,0x0000,  #33:  '!'
    0x0600,0x0600,  #34:  '"'
    0x0,0x0,  #35:  '#'
    0x0,0x0,  #36:  '$'
    0x0,0x0,  #37:  '%'
    0x0,0x0,  #38:  '&'
    0x0,0x0,  #39:  '''
    0x0,0x0,  #40:  '('
    0x0,0x0,  #41:  ')'
    0x0,0x0,  #42:  '*'
    0x0,0x0,  #43:  '+'
    0x0,0x0,  #44:  ','
    0x0,0x0,  #45:  '-'
    0x0,0x0,  #46:  '.'
    0x0,0x0,  #47:  '/'
    0x0,0x0,  #48:  '0'
    0x0,0x0,  #49:  '1'
    0x0,0x0,  #50:  '2'
    0x0,0x0,  #51:  '3'
    0x0,0x0,  #52:  '4'
    0x0,0x0,  #53:  '5'
    0x0,0x0,  #54:  '6'
    0x0,0x0,  #55:  '7'
    0x0,0x0,  #56:  '8'
    0x0,0x0,  #57:  '9'
    0x0088,0x0000,  #58:  ':'
    0x80c8,0x0000,  #59:  ';'
    0x0,0x0,  #60:  '<'
    0x2828,0x2800,  #61:  '='
    0x0,0x0,  #62:  '>'
    0x0,0x0,  #63:  '?'
    0x0,0x0,  #64:  '@'
    0xfc12,0xfc00,  #65:  'A'
    0xfe92,0x6c00,  #66:  'B'
    0x7c82,0x4400,  #67:  'C'
    0xfe82,0x7c00,  #68:  'D'
    0xfe92,0x9200,  #69:  'E'
    0xfe12,0x1200,  #70:  'F'
    0x7c82,0x6420,  #71:  'G'
    0xfe10,0xfe00,  #72:  'H'
    0x82fe,0x8200,  #73:  'I'
    0x6282,0x7e00,  #74:  'J'
    0xfe18,0xe600,  #75:  'K'
    0xfe80,0x8000,  #76:  'L'
    0xfe0c,0xfe00,  #77:  'M'
    0xfe3c,0xfe00,  #78:  'N'
    0x7c82,0x7c00,  #79:  'O'
    0xfe12,0x0c00,  #80:  'P'
    0x7c82,0xfc80,  #81:  'Q'
    0xfe12,0xec00,  #82:  'R'
    0x4c92,0x6400,  #83:  'S'
    0x02fe,0x0200,  #84:  'T'
    0xfe80,0xfe00,  #85:  'U'
    0x7e80,0x7e00,  #86:  'V'
    0xfe60,0xfe00,  #87:  'W'
    0xee10,0xee00,  #88:  'X'
    0x0ef0,0x0e00,  #89:  'Y'
    0xc2ba,0x8600,  #90:  'Z'
    0xff81,0x0000,  #91:  '['
    0x0638,0xc000,  #92:  '\'
    0x0081,0xff00,  #93:  ']'
    0x0402,0x0400,  #94:  '^'
    0x8080,0x8080,  #95:  '_'
    0x0002,0x0400,  #96:  '`'
    0x48a4,0xf800,  #97:  'a'
    0xfc90,0x6000,  #98:  'b'
    0x7088,0x5000,  #99:  'c'
    0x6090,0xfc00,  #100: 'd'
    0x7894,0x4800,  #101: 'e'
    0x40fc,0x4400,  #102: 'f'
    0x98a4,0x7800,  #103: 'g'
    0xfc40,0xc000,  #104: 'h'
    0x90f8,0x4000,  #105: 'i'
    0x4090,0x7400,  #106: 'j'
    0xfc40,0xd800,  #107: 'k'
    0x7c80,0x4000,  #108: 'l'
    0xf830,0xf800,  #109: 'm'
    0xf808,0xf800,  #110: 'n'
    0x7088,0x7000,  #111: 'o'
    0xfc24,0x1800,  #112: 'p'
    0x1824,0xf880,  #113: 'q'
    0xf808,0x1800,  #114: 'r'
    0x4894,0x6400,  #115: 's'
    0x10fc,0x9000,  #116: 't'
    0xff80,0xf800,  #117: 'u'
    0x7880,0x7800,  #118: 'v'
    0xf860,0xf800,  #119: 'w'
    0xd820,0xd800,  #120: 'x'
    0x9c90,0x7c00,  #121: 'y'
    0xc464,0x8c00,  #122: 'z'
    0x10ee,0x8100,  #123: '{'
    0x00fe,0x0000,  #124: '|'
    0x81ee,0x1000,  #125: '}'
    0x1008,0x1008,  #126: '~'
    0x0,0x0   #127: 'DEL'
  ]
  @DFL_PALETTE: [
    0x0fff,   #white
    0x0ff0,   #yellow
    0x0f0f,   #fuchsia
    0x0f00,   #red
    0x0ccc,   #silver
    0x0888,   #gray
    0x0880,   #olive
    0x0808,   #purple
    0x0800,   #maroon
    0x00ff,   #aqua
    0x00f0,   #lime
    0x0088,   #teal
    0x0080,   #green
    0x000f,   #blue
    0x0008,   #navy
    0x0000    #black
  ]

exports.Lem1802 = Lem1802
