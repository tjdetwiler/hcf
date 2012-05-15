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
    @mScale = 1
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

  readFontRam:    (i) -> Lem1802.DFL_FONT[i]
  readPaletteRam: (i) -> Lem1802.DFL_PALETTE[i]

  getChar: (c) ->
    ascii = c.charCodeAt 0
    [@readFontRam ascii, @readFontRam ascii+1]

  #
  # x - X coordinate to place character
  # y - Y coordinate to place character
  #
  drawChar: (x,y,c) ->
    console.log "Drawing char"
    # Can't draw without a context
    if not @mCtx? then return
    x = x*4
    y = y*8

    c = @getChar c
    for i in [31..0]
      word = Math.floor 1/16
      bit  = i % 16
      if c[1-word] & (1<<bit)
        x_ = x + 3 - Math.floor i/8
        y_ = y + (i%8)
        #TODO: Pull in FG color
        @mCtx.fillStyle = "rgb(200,0,0)"
        @mCtx.fillRect(x_*@mScale,y_*@mScale,@mScale,@mScale)
    #TODO: Pull in BG color
    @mCtx.fillStyle = "rgba(0, 0, 200, 0.5)"
    @mCtx.fillRect(x*@mScale, y*@mScale, 4*@mScale, 8*@mScale)

  clear: () ->
    if not @mCtx? then return
    @mCtx.fillStyle = "rgb(200,0,0)"
    @mCtx.fillRect(0, 0, 150, 150)

  #
  # Memory Mapped Callbacks
  #
  _screenCB:    () ->
    lem = this
    (a,v) ->
      console.log "Screen CB"
      x = a % 32
      y = Math.floor a/32
      lem.drawChar x,y,'f'

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
    0x0,0x0,  #32:  ' '
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
    0x0,0x0,  #65:  'A'
    0x0,0x0,  #66:  'B'
    0x00ff,0x8100,  #67:  'C'
    0x0,0x0,  #68:  'D'
    0x0,0x0,  #69:  'E'
    0xff09,0x0900,  #70:  'F'
    0x0,0x0,  #71:  'G'
    0x0,0x0,  #72:  'H'
    0x0,0x0,  #73:  'I'
    0x0,0x0,  #74:  'J'
    0xff18,0x6681,  #75:  'K'
    0x0,0x0,  #76:  'L'
    0x0,0x0,  #77:  'M'
    0x0,0x0,  #78:  'N'
    0x0,0x0,  #79:  'O'
    0x0,0x0,  #80:  'P'
    0x0,0x0,  #81:  'Q'
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
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
    0x0,
  ]

exports.Lem1802 = Lem1802
