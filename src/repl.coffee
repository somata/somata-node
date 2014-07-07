pipeline = require 'pipeline'
barge = require 'barge'

client = new barge.Client
class BargePipeline extends pipeline.Pipeline

# Overwrite pipeline.get to look up service methods
BargePipeline::get = (t, k) ->

    # Try to resolve it normally first
    found = super

    if !found? and t == 'fns'

        # Check if the key matches [service].[method]
        if service_method = k.match /(\w+)\.(\w+)/
            service = service_method[1]
            method = service_method[2]

            # Create a pipeline method that invokes the given service
            found = (inp, args, ctx, cb) =>
                client.remote service, method, args..., cb

    return found

# Set up a readline prompt
PipelineREPL = require '../../qnectar/pipeline/repl'

pipe = new BargePipeline()
pipe.use
    'members': (inp, args, ctx, cb) ->
        client.consul_agent.getNodes cb
    'services': (inp, args, ctx, cb) ->
        client.consul_agent.getServices cb
    'service-nodes': (inp, args, ctx, cb) ->
        client.consul_agent.getServiceNodes args[0], cb

repl = new PipelineREPL(pipe)
repl.startReadline()

