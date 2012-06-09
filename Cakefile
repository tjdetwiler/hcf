fs      = require 'fs'
{exec}  = require 'child_process'
util    = require 'util'

anyError = false
errorText = ""

execCallback = (err, stdout, stderr) ->
  if err
    anyError = true
    errorText += stderr

# Runs a single command with the default callback.
run = (cmd) -> exec cmd, execCallback

# Installs necessary node modules
task 'install', 'install requisite npm packages', (options) ->
  util.log "Installing node modules"
  util.log "Installing 'doubledot-browserity'"
  run 'npm install doubledot-browserify'
  util.log "Installing 'uglify-js"
  run 'npm install uglify-js'

task 'all', 'full build', (options) ->
  invoke 'build:node'
  invoke 'build:dom'
  invoke 'build:dom:min'

task 'build:node', 'rebuild the npm package', (options) ->
  util.log "Building npm package"
  run "coffee -c index.coffee"
  run "coffee -c -o lib/ src/*.coffee"
  run "coffee -c -o lib/hw src/hw/*.coffee"
  run "coffee -c -o lib/node src/node/*.coffee"

task 'build:dom', 'rebuild a browser-friendly hcf.js file', (options) ->
  util.log "Building hcf.js"
  run "node_modules/.bin/doubledot-browserify -o hcf.js index.coffee"

task 'build:dom:min', 'builds a minified browser-friendly file', (options) ->
  util.log "Building hcf.min.js"
  run "node_modules/.bin/doubledot-browserify -o hcf.js index.coffee"
  run "node_modules/.bin/uglifyjs -o hcf.min.js hcf.js"

task 'clean', 'cleans up the workspace', (options) ->
  util.log "Cleaning"
  run "rm -rf lib/"
  run "rm -f  hcf.js"
  run "rm -f  hcf.min.js"
  run "rm -f  index.js"

process.on "exit", () ->
  if anyError
    console.log errorText
    util.log "Build Failed"
  else
    util.log "Build Succeeded"

