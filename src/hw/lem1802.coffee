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

Device = require("./device").Device

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
    @mBorderColor = 4
    @clear()
    @drawBorder @mBorderColor

  id:   () -> 0x7349f615
  mfgr: () -> 0x1c6c8b38
  ver:  () -> 0x1802

  hwInterrupt: () -> switch @mCpu.regA()
    when 0 then @memMapScreen()
    when 1 then @memMapFont()
    when 2 then @memMapPalette()
    when 3 then @setBorderColor()
    else undefined

  reset: () ->
    @mScreen = undefined
    @mScreenAddr = 0
    @mUserFont = undefined
    @mFontAddr = 0
    @mUserPalette = undefined
    @mPaletteAddr = 0
    @clear()

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

  setBorderColor:   () ->
    @drawBorder @mBorderColor = @mCpu.regB() & 0xf

  readFontRam:    (i) ->
    if @mFont?
      @mFont[i]
    else
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
    [@readFontRam(c*2), @readFontRam(c*2+1)]

  #
  # x - X coordinate to place character
  # y - Y coordinate to place character
  # c - Char data to draw (ascii/color/blink)
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

  drawBorder: (c) ->
    c = c << 8
    for x in [0..@WIDTH+1]
      @drawChar x, 0, c
      @drawChar x, @HEIGHT+1, c
    for y in [0..@HEIGHT+1]
      @drawChar 0, y, c
      @drawChar @WIDTH+1, y, c

  #
  # Clears the screen to black
  #
  clear: () ->
    if not @mCtx? then return
    @mCtx.fillStyle = @rgbString @readPaletteRam 0xf
    @mCtx.fillRect(0, 0, (@WIDTH+2) * 4 * @mScale, (@HEIGHT+2) * 8 * @mScale)
    @drawBorder()

  #
  # Redraws the entire screen.
  #
  redraw: () ->
    for x in [0..@WIDTH-1]
      for y in [0..@HEIGHT-1]
        i = y * @WIDTH+x
        if @mScreen[i] then @drawChar x+1, y+1, @mScreen[i]

  #
  # Memory Mapped Callback Generators
  #
  _screenCB:    () ->
    lem = this
    (a,v) ->
      lem.mScreen[a] = v
      lem.redraw()

  _fontCB:      () ->
    lem = this
    (a,v) ->
      lem.mFont[a] = v
      lem.redraw()

  _paletteCB:   () ->
    lem = this
    (a,v) ->
      lem.mPalette[a] = v
      lem.redraw()

  VID_RAM_SIZE:     386
  FONT_RAM_SIZE:    256
  PALETTE_RAM_SIZE: 16
  WIDTH:            32
  HEIGHT:           12
  BORDER_SIZE:      12

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
    0xfe24,0xfe00,  #35:  '#'
    0x48fe,0x2400,  #36:  '$'
    0xe410,0x4e00,  #37:  '%'
    0x2070,0x2000,  #38:  '&'
    0x0006,0x0000,  #39:  '''
    0x3844,0x8200,  #40:  '('
    0x8244,0x3800,  #41:  ')'
    0x1408,0x1400,  #42:  '*'
    0x2070,0x2000,  #43:  '+'
    0x80c0,0x0000,  #44:  ','
    0x1010,0x1000,  #45:  '-'
    0x0080,0x0000,  #46:  '.'
    0xc038,0x0600,  #47:  '/'
    0xfe82,0xfe00,  #48:  '0'
    0x82fe,0x8000,  #49:  '1'
    0xf292,0x9e00,  #50:  '2'
    0x9292,0xfe00,  #51:  '3'
    0x1e10,0xfe00,  #52:  '4'
    0x9e92,0xf200,  #53:  '5'
    0xfe92,0xf200,  #54:  '6'
    0x0202,0xfe00,  #55:  '7'
    0xfe92,0xfe00,  #56:  '8'
    0x9e92,0xfe00,  #57:  '9'
    0x0088,0x0000,  #58:  ':'
    0x80c8,0x0000,  #59:  ';'
    0x2050,0x8800,  #60:  '<'
    0x2828,0x2800,  #61:  '='
    0x8850,0x2000,  #62:  '>'
    0x04b2,0x0c00,  #63:  '?'
    0x70a8,0x7000,  #64:  '@'
    0xfc12,0xfc00,  #65:  'A'
    0xfe92,0x6c00,  #66:  'B'
    0x7c82,0x4400,  #67:  'C'
    0xfe82,0x7c00,  #68:  'D'
    0xfe92,0x9200,  #69:  'E'
    0xfe12,0x1200,  #70:  'F'
    0x7c82,0xe400,  #71:  'G'
    0xfe10,0xfe00,  #72:  'H'
    0x82fe,0x8200,  #73:  'I'
    0x4080,0x7e00,  #74:  'J'
    0xfe18,0xe600,  #75:  'K'
    0xfe80,0x8000,  #76:  'L'
    0xfe0c,0xfe00,  #77:  'M'
    0xfe3c,0xfe00,  #78:  'N'
    0x7c82,0x7c00,  #79:  'O'
    0xfe12,0x0c00,  #80:  'P'
    0x7c82,0xfc00,  #81:  'Q'
    0xfe12,0xec00,  #82:  'R'
    0x4c92,0x6400,  #83:  'S'
    0x02fe,0x0200,  #84:  'T'
    0xfe80,0xfe00,  #85:  'U'
    0x7e80,0x7e00,  #86:  'V'
    0xfe60,0xfe00,  #87:  'W'
    0xee10,0xee00,  #88:  'X'
    0x0ef0,0x0e00,  #89:  'Y'
    0xe292,0x8e00,  #90:  'Z'
    0x00fe,0x8200,  #91:  '['
    0x0638,0xc000,  #92:  '\'
    0x0082,0xfe00,  #93:  ']'
    0x0402,0x0400,  #94:  '^'
    0x8080,0x8080,  #95:  '_'
    0x0002,0x0400,  #96:  '`'
    0x48a8,0xf800,  #97:  'a'
    0xfc90,0x6000,  #98:  'b'
    0x7088,0x5000,  #99:  'c'
    0x6090,0xfc00,  #100: 'd'
    0x70a8,0xb000,  #101: 'e'
    0x20fc,0x2400,  #102: 'f'
    0xb8a8,0xf800,  #103: 'g'
    0xfc20,0xe000,  #104: 'h'
    0x90f4,0x8000,  #105: 'i'
    0xc090,0xf400,  #106: 'j'
    0xfc20,0xd800,  #107: 'k'
    0x04fc,0x8000,  #108: 'l'
    0xf830,0xf800,  #109: 'm'
    0xf808,0xf800,  #110: 'n'
    0x7088,0x7000,  #111: 'o'
    0xf828,0x3800,  #112: 'p'
    0x3828,0xf800,  #113: 'q'
    0xf808,0x1800,  #114: 'r'
    0xb8a8,0xe800,  #115: 's'
    0x10fc,0x9000,  #116: 't'
    0xf880,0xf800,  #117: 'u'
    0x7880,0x7800,  #118: 'v'
    0xf860,0xf800,  #119: 'w'
    0xd820,0xd800,  #120: 'x'
    0x98a0,0x7800,  #121: 'y'
    0xc8a8,0x9800,  #122: 'z'
    0x10ee,0x8200,  #123: '{'
    0x00fe,0x0000,  #124: '|'
    0x82ee,0x1000,  #125: '}'
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
