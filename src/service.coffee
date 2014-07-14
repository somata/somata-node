os = require 'os'
util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
ConsulAgent = require './consul-agent'
Binding = require './binding'
log = helpers.log

VERBOSE = true

# Descend down an object tree {one: {two: 3}} with a path 'one.two'
descend = (o, c) ->
    if c.length == 1
        return o[c[0]].bind(o)
    else
        return descend o[c.shift()], c

class Service

    # Instatiate a Barge service
    # --------------------------------------------------------------------------

    constructor: (@name, @methods={}, options={}) ->
        @id = @name + '~' + helpers.randomString()

        # Determine service port
        @binding = options.binding || {}
        @binding.proto = options.proto || 'tcp'
        @binding.port = options.port || helpers.randomPort()

        # Create connections
        @consul_agent = new ConsulAgent
        @service_binding = new Binding @binding

        # Bind event handlers
        @service_binding.on 'method', @handleMethod.bind(@)
        #@service_binding.on 'status', @handleStatus.bind(@)

        # Register the service
        @register()

        # Deregister when quit
        process.on 'SIGINT', =>
            @deregister ->
                process.exit()

    # Handle a remote method call
    # --------------------------------------------------------------------------

    handleMethod: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message, depth: null }" if VERBOSE

        # Find the method
        method_name = message.method
        if _method = @getMethod method_name

            # Define our response methods

            _sendResponse = (response) =>
                @service_binding.send client_id,
                    id: message.id
                    kind: 'response'
                    response: response

            _sendError = (error) =>
                @service_binding.send client_id,
                    id: message.id
                    kind: 'error'
                    error: error

            # Execute the method with the arguments
            log 'Executing ' + method_name if VERBOSE
            try

                _method message.args..., (err, response) =>
                    if err
                        _sendError err
                    else
                        _sendResponse response

            catch e
                # Catch unhandled errors
                err = e.toString()
                arity_mismatch = (message.args.length != _method.length - 1)
                if arity_mismatch &&
                    e instanceof TypeError &&
                    err.slice(11) == 'undefined is not a function'
                        err = "ArityError? method `#{ method_name }` takes #{ _method.length-1 } arguments."
                _sendError err

        # Method not found for this service
        else
            # TODO: Send a failure message to client
            log.i 'No method ' + message.method

    getMethod: (method_name) ->
        # Look for builtins, having method names starting with a `_`
        if (method_name[0] == '_')
            method_name = method_name.slice(1)
            _method = @[method_name]
            return _method
        # Get a deeper level method from @methods
        if (method_context = method_name.split('.')).length > 1
            return descend @methods, method_context
        # Get a method from @methods
        else
            return @methods[method_name]

    # Handle a subscription request
    # --------------------------------------------------------------------------
    #
    # TODO

    handleSubscription: ->

    # Handle a status request
    # --------------------------------------------------------------------------

    handleStatus: (cb) ->
        cb null,
            health: 'ok'
            uptime: process.uptime()
            memory: process.memoryUsage()
            load: os.loadavg()

    # Register and deregister the service from the registry
    # --------------------------------------------------------------------------
    #
    # TODO: Abstract so that some registry service besides Consul may be used

    register: (cb) ->
        # Register the service itself
        @consul_agent.registerService
            Name: @name
            Id: @id
            Port: @binding.port
            Tags: ["proto:#{@binding.proto}"]
            Check:
                Interval: 60
                TTL: "10s"

        , (err, registered) =>
            # Start the TTL check
            @startChecks()
            log.s "Registered `#{ @name }` on :#{ @binding.port }"
            cb(null, registered) if cb?

    startChecks: ->
        setInterval (=>
            log.i 'checking'
            @consul_agent.checkPass 'service:' + @id, () ->
                log.s 'checked'
        ), 9000

    deregister: (cb) ->
        @consul_agent.deregisterService @id, (err, deregistered) =>
            log.e "Deregistered `#{ @name }` from :#{ @binding.port }"
            cb(null, deregistered) if cb?

module.exports = Service

