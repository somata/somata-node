Client = require './client'
helpers = require './helpers'

# TODO: Should the base Client class be more one-off oriented? It's a tradeoff
# between being able to connect one client to many services (as in the case of
# super-api or anything that needs arbitrary connections) vs. having to write
# the extra remote.bind(@, ...) which seems clumsy most of the time. There is
# also the extra logic that has to be built into a client if it connects to many
# services and has to manage disconnects, subscriptions, etc. Is the one to many
# use case not significant enough to bother?

module.exports = class MultiClient
    constructor: ->
        @clients = {}

    request: (service, method, args...) ->
        if not (client = @clients[service])
            @clients[service] = client = new Client(service)
        client.request(method, args...)

    requestCb: (service, method, args..., cb) ->
        helpers.fromPromise @request.bind(@, service, method, args...), cb

