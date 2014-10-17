hashpipe = require 'hashpipe'

class SomataPipeline extends hashpipe.Pipeline

# Overwrite pipeline.get to look up service methods
SomataPipeline::get = (t, k) ->

    # Try to resolve it normally first
    found = super

    if !found? and t == 'fns'

        # Check if the key matches [service].[method]
        if service_method = k.match /([\w:]+)\.([\w\.]*)/
            service = service_method[1]
            method = service_method[2] || service

            # Create a pipeline method that invokes the given service
            found = (inp, args, ctx, cb) =>
                @client.remote service, method, args..., cb

    return found

module.exports = SomataPipeline
