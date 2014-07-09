os = require 'os'
util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
ConsulAgent = require './consul-agent'
Binding = require './binding'
log = helpers.log

VERBOSE = true

class Service

    # Instatiate a Barge service
    # --------------------------------------------------------------------------

    constructor: (@name, @methods={}, options={}) ->

        # Determine service port
        @binding = options.binding || {}
        @binding.proto = options.proto || 'tcp'
        @binding.port = options.port || helpers.randomPort()

        # Create connections
        @consul_agent = new ConsulAgent
        @service_binding = new Binding @binding
        @service_binding.on 'method', @handleMethod.bind(@)

        # Register the service
        @register()

        # Deregister when quit
        process.on 'SIGINT', =>
            @deregister ->
                process.exit()

    # Handle a method
    # --------------------------------------------------------------------------

    handleMethod: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message, depth: null }" if VERBOSE

        # Find the method
        if _method = @getMethod message.method
            console.log "Got method " + _method

            # Execute the method with the arguments
            log 'Executing ' + message.method if VERBOSE
            _method message.args..., (err, response) =>

                # Respond to the client
                @service_binding.send client_id,
                    id: message.id
                    type: 'response'
                    response: response

        # Method not found for this service
        else
            # TODO: Send a failure message to client
            log.i 'No method ' + message.method

    getMethod: (method_name) ->
        descend = (o, c) ->
            console.log "Descending into `#{ util.inspect o }` with #{ util.inspect c }"
            if c.length == 1
                return o[c[0]].bind(o)
            else
                return descend o[c.shift()], c
        if (method_context = method_name.split('.')).length > 1
            return descend @methods, method_context
        else
            return @methods[method_name]

    # Send a `register` message to the Barge registry
    # --------------------------------------------------------------------------

    register: (cb) ->
        @consul_agent.registerService
            Name: @name
            Port: @binding.port
            Tags: ["proto:#{@binding.proto}"]
        , (err, registered) =>
            log.s "Registered `#{ @name }` on :#{ @binding.port }"
            cb(null, registered) if cb?

    deregister: (cb) ->
        @consul_agent.deregisterService @name, (err, deregistered) =>
            log.e "Deregistered `#{ @name }` from :#{ @binding.port }"
            cb(null, deregistered) if cb?

module.exports = Service

