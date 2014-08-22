os = require 'os'
util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
{EventEmitter} = require 'events'
ConsulAgent = require './consul-agent'
Binding = require './binding'
log = helpers.log

VERBOSE = false
CHECK_INTERVAL = 9000

# Descend down an object tree {one: {two: 3}} with a path 'one.two'
descend = (o, c) ->
    if c.length == 1
        return o[c[0]].bind(o)
    else
        return descend o[c.shift()], c

module.exports = class SomataService extends EventEmitter

    # Instatiate a Somata service
    # --------------------------------------------------------------------------

    constructor: (@name, @methods={}, options={}) ->
        @id = @name + '~' + helpers.randomString()

        # Determine options
        @rpc_options = options.rpc_options || {}
        @pub_options = options.pub_options || {}

        # Connect to registry (Consul)
        @consul_agent = new ConsulAgent

        # Bind and register the service
        @checkBindingPort =>
            @bindRPC()
            @register()

        # Deregister when quit
        process.on 'SIGINT', =>
            @deregister ->
                process.exit()

    bindRPC: ->
        @rpc_binding = new Binding @rpc_options
        @rpc_binding.on 'method', @handleMethod.bind(@)
        @rpc_binding.on 'subscribe', @handleSubscribe.bind(@)
        @rpc_binding.on 'unsubscribe', @handleUnsubscribe.bind(@)

    # Handle a remote method call
    # --------------------------------------------------------------------------

    handleMethod: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message, depth: null }" if VERBOSE

        # Find the method
        method_name = message.method
        if _method = @getMethod method_name

            # Define our response methods

            _sendResponse = (response) =>
                @rpc_binding.send client_id,
                    id: message.id
                    kind: 'response'
                    response: response

            _sendError = (error) =>
                @rpc_binding.send client_id,
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
                log.e '[ERROR] ' + err
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

    subscriptions_by_type: {}
    subscriptions_by_client: {}

    handleSubscribe: (client_id, message) ->
        type = message.type
        subscription_id = message.id
        subscription_key = [client_id, subscription_id].join(':')
        log.i "Subscribing <#{ subscription_key }>"
        @subscriptions_by_type[type] ||= []
        @subscriptions_by_type[type].push subscription_key
        @subscriptions_by_client[client_id] ||= []
        @subscriptions_by_client[client_id].push subscription_key

    handleUnsubscribe: (client_id, message) ->
        type = message.type
        subscription_id = message.id
        subscription_key = [client_id, subscription_id].join(':')
        log.w "Unsubscribing <#{ subscription_key }>"
        for type, subscription_keys of @subscriptions_by_type
            @subscriptions_by_type[type] = _.without subscription_keys, subscription_key
        @subscriptions_by_client[client_id] = _.without @subscriptions_by_client[client_id], subscription_key

    publish: (type, event) ->
        if subscription_keys = @subscriptions_by_type[type]
            subscription_keys.forEach (subscription_key) =>
                [client_id, subscription_id] = subscription_key.split ':'
                log.d "Sending <#{ subscription_key }>"
                @rpc_binding.send client_id,
                    id: subscription_id
                    kind: 'event'
                    event: event

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
            Port: @rpc_binding.port
            Tags: ["proto:#{@rpc_binding.proto}"]
            Check:
                Interval: 60
                TTL: "10s"

        , (err, registered) =>
            # Start the TTL check
            @startChecks()
            log.s "Registered `#{ @name }` on :#{ @rpc_binding.port }"
            cb(null, registered) if cb?

    # Check for existing unhealthy instance ports to connect as
    checkBindingPort: (cb) ->
        @consul_agent.getUnhealthyServiceInstances @name, (err, unhealthy_instances) =>
            if unhealthy_instances.length
                @rpc_options.port = (helpers.randomChoice unhealthy_instances).Service.Port
            else
                @rpc_options.port = helpers.randomPort()
            cb()

    startChecks: ->
        setInterval (=>
            @consul_agent.checkPass 'service:' + @id
        ), CHECK_INTERVAL

    deregister: (cb) ->
        @consul_agent.deregisterService @id, (err, deregistered) =>
            log.e "Deregistered `#{ @name }` from :#{ @rpc_binding.port }"
            cb(null, deregistered) if cb?

