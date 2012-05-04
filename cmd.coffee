rl = require 'readline'

Module = {}

class Cmd
  #
  # Ctor
  #
  constructor: () ->
    @prompt = "> "
    @identchars = ""
    @lastcmd = ""
    @intro = ""
    @doc_header = ""
    @misc_header = ""
    @undoc_header = ""
    @ruler = "="

  #
  # Starts the command loop (non-blocking).
  #
  cmdloop: () ->
    cmd = this
    @iface = rl.createInterface process.stdin, process.stdout, null
    @prompt = "> " if @prompt is undefined
    @iface.setPrompt(@prompt)
    @iface.on 'line', (msg) ->
      cmd.onLine(msg)
    console.log @intro
    @iface.prompt()

  #
  # Callback for readline interface.
  #
  onLine: (line) ->
    @onecmd(line.trim())
    @iface.prompt()

  #
  # Processes 'line' as if it were one command issued from the
  # commandline.
  #
  onecmd: (line) ->
    if not line
      return @emptyline()

    @lastcmd = line
    tokens = line.split ' '
    tokens = @filterBuiltin '?', 'help', tokens
    tokens = @filterBuiltin '!', 'shell', tokens
    method = "do_#{tokens[0]}"
    if this[method]
      this[method](tokens[1..])
    else
      @default()

  #
  # Called on unknown command (no do_#{cmd} function defined).
  #
  default:      () -> console.log "Unknown Command"

  #
  # Called when the the command is an empty string.
  #
  emptyline:    () -> @onecmd(@lastcmd)
  precmd:       (line) -> null
  postcmd:      (stop, line) -> null
  preloop:      () -> null
  postloop:     () -> null

  #
  # Function called when there is no help_#{cmd} found.
  #
  defaulthelp:  (cmd) ->
    console.log "No help for command #{cmd}"

  #
  # Returns a list of supported commands. A command is support if a
  # function of the for do_#{cmd} can be found in this object.
  #
  commands:     () ->
    k[3..] for k,v of this when k[0..2] is "do_"

  #
  # Handles special built-in patterns.
  #
  # Ex: Transforms
  #   ["?somecommand"]
  # into
  #   ["help", "somecommand"]
  #
  # More genrally, if vec[0] starts with 'char', then replace 'char'
  # with 'kw', and insert any adjacent chars into a unique array
  # element.
  #
  filterBuiltin: (char, kw, vec) ->
    if vec[0][0] is char
      [kw].concat [vec[0][1..]], vec[1..]
    else
      vec

  #
  # Help Command
  #
  do_help:      (args) ->
    args[1] = "help" if args[1] is undefined
    method = "help_#{args[1]}"
    if this[method]
      @[method]()
    else
      @defaulthelp(args[1])
  help_help:    () ->
    console.log "Usage: help <command>"
    console.log "Available Commands: "
    for cmd in @commands()
      console.log "  #{cmd}"

  #
  # Shell Command
  #
  do_shell: (args) ->
    console.log "Invoked shell on #{args}"
  help_shell: () -> console.log "Does nothing."

exports.Cmd = Cmd

