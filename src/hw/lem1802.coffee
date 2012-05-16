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
    0x0,0x0,  #33:  '!'
    0x0,0x0,  #34:  '"'
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
    0x0,0x0,  #58:  ':'
    0x0,0x0,  #59:  ';'
    0x0,0x0,  #60:  '<'
    0x0,0x0,  #61:  '='
    0x0,0x0,  #62:  '>'
    0x0,0x0,  #63:  '?'
    0x0,0x0,  #64:  '@'
    0xfe09,0x09fe,  #65:  'A'
    0xff89,0x8976,  #66:  'B'
    0x7e81,0x8142,  #67:  'C'
    0xff81,0xc37e,  #68:  'D'
    0xff89,0x8989,  #69:  'E'
    0xff09,0x0900,  #70:  'F'
    0x7e81,0x9172,  #71:  'G'
    0xff08,0x08ff,  #72:  'H'
    0x81ff,0x8100,  #73:  'I'
    0x6181,0xff01,  #74:  'J'
    0xff18,0x6681,  #75:  'K'
    0xff80,0x8080,  #76:  'L'
    0xff06,0x0cff,  #77:  'M'
    0xff0c,0x30ff,  #78:  'N'
    0x7e81,0x817e,  #79:  'O'
    0xff11,0x110e,  #80:  'P'
    0x7e81,0xe1de,  #81:  'Q'
    0x0,0x0,  #82:  'R'
    0x0,0x0,  #83:  'S'
    0x0,0x0,  #84:  'T'
    0xff80,0x80ff,  #85:  'U'
    0x0,0x0,  #86:  'V'
    0x0,0x0,  #87:  'W'
    0x0,0x0,  #88:  'X'
    0x0,0x0,  #89:  'Y'
    0x0,0x0,  #90:  'Z'
    0x0,0x0,  #91:  '['
    0x0,0x0,  #92:  '\'
    0x0,0x0,  #93:  ']'
    0x0,0x0,  #94:  '^'
    0x0,0x0,  #95:  '_'
    0x0,0x0,  #96:  '`'
    0x0,0x0,  #97:  'a'
    0x0,0x0,  #98:  'b'
    0x00ff,0x8100,  #99:  'c'
    0x0,0x0,  #100: 'd'
    0x0,0x0,  #101: 'e'
    0xff09,0x0900,  #102: 'f'
    0x0,0x0,  #103: 'g'
    0x0,0x0,  #104: 'h'
    0x0,0x0,  #105: 'i'
    0x0,0x0,  #106: 'j'
    0xff18,0x6681,  #107: 'k'
    0x0,0x0,  #108: 'l'
    0x0,0x0,  #109: 'm'
    0x0,0x0,  #110: 'n'
    0x0,0x0,  #111: 'o'
    0x0,0x0,  #112: 'p'
    0x0,0x0,  #113: 'q'
    0x0,0x0,  #114: 'r'
    0x0,0x0,  #115: 's'
    0x0,0x0,  #116: 't'
    0xff80,0x80ff,  #117: 'u'
    0x0,0x0,  #118: 'v'
    0x0,0x0,  #119: 'w'
    0x0,0x0,  #120: 'x'
    0x0,0x0,  #121: 'y'
    0x0,0x0,  #122: 'z'
    0x0,0x0,  #123: '{'
    0x0,0x0,  #124: '|'
    0x0,0x0,  #125: '}'
    0x0,0x0,  #126: '~'
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
