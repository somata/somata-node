somata = require './'
SomataPipeline = require './pipeline'

client = new somata.Client

# Set up a readline prompt
PipelineREPL = require 'hashpipe/repl'

pipe = new SomataPipeline({client: client})
    .use('http')
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
    .alias('deregister-service', 'key $consul_base/health/service/ $! | get $! @ :Service:ID')

repl = new PipelineREPL(pipe)
repl.startReadline()

