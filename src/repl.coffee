hashpipe = require 'hashpipe'
somata = require './'

client = new somata.Client
class SomataPipeline extends hashpipe.Pipeline

# Overwrite pipeline.get to look up service methods
SomataPipeline::get = (t, k) ->

    # Try to resolve it normally first
    found = super

    if !found? and t == 'fns'

        # Check if the key matches [service]:[method]
        if service_method = k.match /(\w+):([\w\.]*)/
            service = service_method[1]
            method = service_method[2] || service

            # Create a pipeline method that invokes the given service
            found = (inp, args, ctx, cb) =>
                client.remote service, method, args..., cb

    return found

# Set up a readline prompt
PipelineREPL = require 'hashpipe/repl'

pipe = new SomataPipeline()
    .use('http')
    .use('encodings')
    .use(
        'members': (inp, args, ctx, cb) ->
            client.consul_agent.getNodes cb
        'services': (inp, args, ctx, cb) ->
            client.consul_agent.getServices cb
        'service-nodes': (inp, args, ctx, cb) ->
            client.consul_agent.getServiceNodes args[0], cb
    )
    .set('vars', 'consul_base', client.consul_agent.options.base_url)

repl = new PipelineREPL(pipe)
repl.startReadline()

