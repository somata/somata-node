#!/usr/bin/env coffee
somata = require './'
SomataPipeline = require './pipeline'
fs = require 'fs'
argv = require('yargs').argv

client = new somata.Client

# Set up a readline prompt
PipelineREPL = require 'hashpipe/repl'

pipe = new SomataPipeline({client: client})
    .use('http')
    .use('exec')
    .use('encodings')
    .use(require('hashpipe/modules/redis').connect())
    .use(
        'members': (inp, args, ctx, cb) ->
            client.consul_agent.getNodes cb
        'services': (inp, args, ctx, cb) ->
            client.consul_agent.getServices cb
        'service-nodes': (inp, args, ctx, cb) ->
            client.consul_agent.getServiceNodes args[0], cb
    )
    .set('vars', 'consul_base', client.consul_agent.base_url)
    .alias('deregister', 'val | put $consul_base/catalog/deregister')

repl = new PipelineREPL(pipe)

runWith = (repl, script, cb) ->
    doRunWith = ->
        repl.executeScript script, ->
            cb?() || process.exit()
    if !process.stdin.isTTY
        piped = ''
        process.stdin.on 'data', (data) ->
            piped += data.toString()
        process.stdin.on 'end', ->
            repl.last_out = piped.trim()
            doRunWith()
    else
        setTimeout doRunWith, 500

if script_filename = argv.load || argv.l
    # Execute single script
    console.log "Reading from #{ script_filename }..."
    script = fs.readFileSync(script_filename).toString()
    runWith repl, script, ->
        repl.startReadline()

else if script_filename = argv.run || argv.r
    script = fs.readFileSync(script_filename).toString()
    runWith repl, script

else if script = argv.exec || argv.e
    repl.plain = true
    runWith repl, script

else
    repl.startReadline()

