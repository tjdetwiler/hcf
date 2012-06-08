fs      = require 'fs'
{exec}  = require 'child_process'
util    = require 'util'

execCallback = (err, stdout, stderr) ->
  console.log stdout
  console.log stderr

run = (cmd) -> exec cmd, execCallback

task 'build:node', 'rebuild the npm package', (options) ->
  util.log "Building npm package"
  run "coffee -c -o lib/ src/*.coffee"
  run "coffee -c -o lib/hw src/hw/*.coffee"
  run "coffee -c -o lib/node src/node/*.coffee"

task 'build:dom', 'rebuild a browser-friendly hcf.js file', (options) ->
  util.log "Building hcf.js"
  run "node_modules/.bin/doubledot-browserify -o hcf.js index.coffee"
