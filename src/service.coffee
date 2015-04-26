os = require 'os'
util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
{EventEmitter} = require 'events'
emitters = require './events'
ConsulAgent = require './consul-agent'
Binding = require './binding'
log = helpers.log

VERBOSE = process.env.SOMATA_VERBOSE || false
EXTERNAL = process.env.SOMATA_EXTERNAL || false
CHECK_INTERVAL = parseInt(process.env.SOMATA_CHECK_INTERVAL) || 9000
CHECK_TTL = process.env.SOMATA_CHECK_TTL || ((CHECK_INTERVAL / 1000) + 4 + "s")
SERVICE_HOST = process.env.SOMATA_SERVICE_HOST

PREFIX = ''
if process.env.SOMATA_PREFIX?
    PREFIX = process.env.SOMATA_PREFIX + ':'

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
        @name = PREFIX + @name
        @id = @name + '~' + helpers.randomString()

        # Determine options
        _.extend @, options
        @rpc_options ||= {}
        @pub_options ||= {}

        @rpc_options.host = SERVICE_HOST

        # Connect to registry (Consul)
        @consul_agent = new ConsulAgent

        # Bind and register the service
        @bindRPC =>
            @register()

        # Deregister when quit
        emitters.exit.onExit (cb) =>
            @deregister cb

    bindRPC: (cb) ->
        @rpc_binding = new Binding @rpc_options
        @rpc_binding.on 'bind', cb
        @rpc_binding.on 'method', @handleMethod.bind(@)
        @rpc_binding.on 'subscribe', @handleSubscribe.bind(@)
        @rpc_binding.on 'unsubscribe', @handleUnsubscribe.bind(@)

    # Handle a remote method call
    # --------------------------------------------------------------------------

    # Helpers for sending response messages

    sendResponse: (client_id, message_id, response) ->
        @rpc_binding.send client_id,
            id: message_id
            kind: 'response'
            response: response

    sendError: (client_id, message_id, error) ->
        @rpc_binding.send client_id,
            id: message_id
            kind: 'error'
            error: error

    # Interpreting a method call

    handleMethod: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message, depth: null }" if VERBOSE

        # Find the method
        method_name = message.method
        if _method = @getMethod method_name

            # Execute the method with the arguments
            log 'Executing ' + method_name if VERBOSE
            try

                _method message.args..., (err, response) =>
                    if err
                        @sendError client_id, message.id, err
                    else
                        @sendResponse client_id, message.id, response

            # Catch unhandled errors
            catch e
                err = e.toString()
                arity_mismatch = (message.args.length != _method.length - 1)
                if arity_mismatch &&
                    e instanceof TypeError &&
                    err.slice(11) == 'undefined is not a function'
                        err = "ArityError? method `#{ method_name }` takes #{ _method.length-1 } arguments."
                log.e '[ERROR] ' + err
                console.error e.stack
                @sendError client_id, message.id, err

        # Method not found for this service
        else
            # TODO: Send a failure message to client
            log.i 'No method ' + message.method

    # Finding a method from the methods hash

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
        subscription_key = [client_id, subscription_id].join('::')
        log.i "Subscribing <#{ subscription_key }>"
        @subscriptions_by_type[type] ||= []
        @subscriptions_by_type[type].push subscription_key
        @subscriptions_by_client[client_id] ||= []
        @subscriptions_by_client[client_id].push subscription_key

    handleUnsubscribe: (client_id, message) ->
        type = message.type
        subscription_id = message.id
        subscription_key = [client_id, subscription_id].join('::')
        log.w "Unsubscribing <#{ subscription_key }>"
        # TODO: Improve how subscriptions are stored
        for type, subscription_keys of @subscriptions_by_type
            @subscriptions_by_type[type] = _.without subscription_keys, subscription_key
        @subscriptions_by_client[client_id] = _.without @subscriptions_by_client[client_id], subscription_key

    publish: (type, event) ->
        _.map @subscriptions_by_type[type], (subscription_key) =>
            [client_id, subscription_id] = subscription_key.split '::'
            @sendEvent client_id, subscription_id, event

    sendEvent: (client_id, subscription_id, event) ->
        @rpc_binding.send client_id,
            id: subscription_id
            kind: 'event'
            event: event

    end: (type) ->
        _.map @subscriptions_by_type[type], (subscription_key) =>
            [client_id, subscription_id] = subscription_key.split '::'
            @sendEnd client_id, subscription_id
        delete @subscriptions_by_type[type]

    sendEnd: (client_id, subscription_id) ->
        @rpc_binding.send client_id,
            id: subscription_id
            kind: 'end'

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

    serviceTags: ->
        tags = []
        tags.push "proto:#{@rpc_binding.proto}"
        tags.push "host:#{@rpc_binding.host}" if @rpc_binding.proto != 'tcp'
        tags

    register: (cb) ->
        return @registerExternally(cb) if EXTERNAL

        service_description =
            Name: @name
            Id: @id
            Port: @rpc_binding.port
            Tags: @serviceTags()
        if CHECK_INTERVAL > 0
            service_description.Check =
                Interval: CHECK_INTERVAL
                TTL: CHECK_TTL

        # Register the service
        @consul_agent.registerService service_description, (err, registered) =>
            # Start the TTL check
            @startChecks() if CHECK_INTERVAL > 0
            log.s "Registered service `#{ @id }` on #{ @rpc_binding.address }"
            cb(null, registered) if cb?

    registerExternally: (cb) ->
        service_description =
            Node: @id
            Address: @rpc_binding.host
            Service:
                ID: @id
                Service: @name
                Port: @rpc_binding.port
                Tags: ["proto:#{@rpc_binding.proto}"]
        @consul_agent.registerExternalService service_description, (err, registered) =>
            log.s "Registered external service `#{ @id }` on #{ @rpc_binding.host }:#{ @rpc_binding.port }"
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
        return @deregisterExternally(cb) if EXTERNAL

        @consul_agent.deregisterService @id, (err, deregistered) =>
            log.e "[deregister] Deregistered `#{ @id }` from :#{ @rpc_binding.port }"
            cb(null, deregistered) if cb?

    deregisterExternally: (cb) ->
        service_description =
            Node: @name
            ServiceID: @name

        @consul_agent.deregisterExternalService service_description, (err, deregistered) =>
            log.e "[deregisterExternally] Deregistered `#{ @id }` from #{ @rpc_binding.host }:#{ @rpc_binding.port }"
            cb(null, deregistered) if cb?

