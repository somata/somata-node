os = require 'os'
util = require 'util'
zerorpc = require 'zerorpc'
helpers = require './helpers'
_ = require 'underscore'
ConsulAgent = require './consul-agent'
log = helpers.log

VERBOSE = false

class Service

    # Instatiate a Barge service
    # --------------------------------------------------------------------------

    constructor: (@name, @methods={}, options={}) ->

        # Determine service port
        @protocol = options.protocol || 'tcp'
        @port = options.port || helpers.randomPort()

        # Create connections
        @consul_agent = new ConsulAgent
        @service_binding = new zerorpc.Server @methods

        # Bind and register
        @bind()
        @register()

        # Deregister when quit
        process.on 'SIGINT', =>
            @deregister ->
                process.exit()

    # Bind the service socket
    # --------------------------------------------------------------------------

    bind: ->
        @service_binding.bind helpers.makeBindingAddress @protocol, @port

    # Send a `register` message to the Barge registry
    # --------------------------------------------------------------------------

    register: (cb) ->
        @consul_agent.registerService
            Name: @name
            Port: @port
            Tags: ["protocol:#{@protocol}"]
        , (err, registered) =>
            log.s "Registered `#{ @name }` on :#{ @port }"
            cb(null, registered) if cb?

    deregister: (cb) ->
        @consul_agent.deregisterService @name, (err, deregistered) =>
            log.e "Deregistered `#{ @name }` from :#{ @port }"
            cb(null, deregistered) if cb?

module.exports = Service

