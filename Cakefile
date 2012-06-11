fs      = require 'fs'
{exec}  = require 'child_process'
util    = require 'util'

anyError = false
errorText = ""

# Generates a callback function for child_process.exec. If a function is passed
# as a parameter, it will be called when the child process finishes.
execCallback = (next) ->
  (err, stdout, stderr) ->
    if err
      anyError = true
      errorText += stderr
    if next? then next()

# Runs a single command with the default callback.
run = (cmd, next) -> exec cmd, execCallback next

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

task 'build:watch', 'watch files for changes and update', (options) ->
  run "coffee -c -w -o lib/ src/*.coffee"
  run "coffee -c -w -o lib/hw src/hw/*.coffee"
  run "coffee -c -w -o lib/node src/node/*.coffee"

task 'build:node', 'rebuild the npm package', (options) ->
  util.log "Building npm package"
  run "coffee -c -o lib/ src/*.coffee"
  run "coffee -c -o lib/hw src/hw/*.coffee"
  run "coffee -c -o lib/node src/node/*.coffee"

task 'build:dom', 'rebuild a browser-friendly hcf.js file', (options) ->
  util.log "Building hcf.js"
  run "node_modules/.bin/doubledot-browserify -o hcf.js index.js"

task 'build:dom:min', 'builds a minified browser-friendly file', (options) ->
  util.log "Building hcf.min.js"
  run "node_modules/.bin/doubledot-browserify -o hcf.js index.js", ()->
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

