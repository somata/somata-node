util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
{EventEmitter} = require 'events'
usage = require 'usage'
emitters = require './events'
Binding = require './binding'
Connection = require './connection'
log = helpers.log

VERBOSE = parseInt process.env.SOMATA_VERBOSE || 0
REGISTRY_PROTO = process.env.SOMATA_REGISTRY_PROTO || 'tcp'
REGISTRY_HOST = process.env.SOMATA_REGISTRY_HOST || '127.0.0.1'
REGISTRY_PORT = process.env.SOMATA_REGISTRY_PORT || 8420
SERVICE_PROTO = process.env.SOMATA_SERVICE_PROTO
SERVICE_HOST = process.env.SOMATA_SERVICE_HOST
SERVICE_PORT = process.env.SOMATA_SERVICE_PORT

module.exports = class SomataService extends EventEmitter

    # Instatiate a Somata service
    # --------------------------------------------------------------------------

    constructor: (@name, @methods={}, options={}) ->
        @id = @name + '~' + helpers.randomString()

        # Determine options
        _.extend @, options
        @rpc_options ||= {}
        @rpc_options.proto ||= SERVICE_PROTO
        @rpc_options.host ||= SERVICE_HOST
        @rpc_options.port ||= SERVICE_PORT

        # Bind and register the service
        @bindRPC =>
            @register()

        # Deregister when quit
        emitters.exit.onExit (cb) =>
            @deregister cb

    bindRPC: (cb) ->
        @rpc_binding = new Binding @rpc_options
        @rpc_binding.on 'bind', cb
        @rpc_binding.on 'ping', @handlePing.bind(@)
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
        if error.toString?
            error = error.toString()
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

            log 'Executing ' + method_name if VERBOSE > 1

            # Execute the named method with given arguments
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
            log.e '[ERROR] No method ' + message.method
            @sendError client_id, message.id, "No method " + message.method

    # Finding a method from the methods hash

    getMethod: (method_name) ->
        # Look for builtins, having method names starting with a `_`
        if (method_name[0] == '_')
            #method_name = method_name.slice(1)
            _method = @[method_name]
            return _method
        if typeof @methods == 'function'
            return @methods(method_name)
        else
            # Get a deeper level method from @methods
            if (method_context = method_name.split('.')).length > 1
                return helpers.descend @methods, method_context
            # Get a method from @methods
            else
                return @methods[method_name]

    # Handle a ping
    # --------------------------------------------------------------------------

    # Map of client_id -> boolean
    known_pings: {}

    handlePing: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message, depth: null }" if VERBOSE > 1
        if @known_pings[client_id]
            response = 'pong'
        else
            @known_pings[client_id] = true
            response = 'hello'
        @gotPing? client_id
        @sendResponse client_id, message.id, response

    # Handle a subscription
    # --------------------------------------------------------------------------

    subscriptions_by_event_name: {}
    subscriptions_by_client: {}

    handleSubscribe: (client_id, message) ->
        event_name = message.type
        subscription_id = message.id
        subscription_key = [client_id, subscription_id].join('::')
        log.i "[Service.handleSubscribe] Subscribing #{client_id} <#{ subscription_key }>"
        @subscriptions_by_event_name[event_name] ||= []
        @subscriptions_by_event_name[event_name].push subscription_key
        @subscriptions_by_client[client_id] ||= []
        @subscriptions_by_client[client_id].push subscription_key

    handleUnsubscribe: (client_id, message) ->
        event_name = message.type
        subscription_id = message.id
        subscription_key = [client_id, subscription_id].join('::')
        log.w "[Service.handleUnsubscribe] Unsubscribing <#{ subscription_key }>"
        # TODO: Improve how subscriptions are stored
        for event_name, subscription_keys of @subscriptions_by_event_name
            @subscriptions_by_event_name[event_name] = _.without subscription_keys, subscription_key
        @subscriptions_by_client[client_id] = _.without @subscriptions_by_client[client_id], subscription_key

    publish: (event_name, event) ->
        _.map @subscriptions_by_event_name[event_name], (subscription_key) =>
            [client_id, subscription_id] = subscription_key.split '::'
            @sendEvent client_id, subscription_id, event, event_name

    sendEvent: (client_id, subscription_id, event, event_name) ->
        log.d "[sendEvent] <#{client_id}> #{subscription_id}" if VERBOSE
        @rpc_binding.send client_id,
            id: subscription_id
            kind: 'event'
            event: event

    end: (event_name) ->
        _.map @subscriptions_by_event_name[event_name], (subscription_key) =>
            [client_id, subscription_id] = subscription_key.split '::'
            @sendEnd client_id, subscription_id
        delete @subscriptions_by_event_name[event_name]

    sendEnd: (client_id, subscription_id) ->
        @rpc_binding.send client_id,
            id: subscription_id
            kind: 'end'

    # Handle a status request
    # --------------------------------------------------------------------------

    _status: (cb) ->
        usage.lookup process.pid, {keepHistory: true}, (err, {memory, cpu}) ->
            uptime = process.uptime()
            cb null, {memory, cpu, uptime}

    # Register and deregister the service from the registry
    # --------------------------------------------------------------------------

    register: ->
        @registry_connection = new Connection
            proto: REGISTRY_PROTO
            port: REGISTRY_PORT
            host: REGISTRY_HOST
        @registry_connection.service_instance = {id: 'registry', name: 'registry'}
        @registry_connection.on 'connect', @registryConnected.bind(@)
        @registry_connection.sendPing()

    registryConnected: ->
        # TODO: Consider re-subscriptions from clients
        @sendRegister()

    sendRegister: (cb) ->
        service_instance =
            id: @id
            name: @name
            proto: @rpc_binding.proto
            host: @rpc_binding.host
            port: @rpc_binding.port
            methods: Object.keys @methods

        @registry_connection.sendMethod null, 'registerService', [service_instance], (err, registered) =>
            log.s "Registered service `#{ @id }` on #{ @rpc_binding.address }"
            cb(null, registered) if cb?

    deregister: (cb) ->
        if @registry_connection.timed_out
            log.e "[deregister] Registry is dead"
            cb() if cb?
        else
            @registry_connection.sendMethod null, 'deregisterService', [@name, @id], (err, deregistered) =>
                log.e "[deregister] Deregistered `#{ @id }` from :#{ @rpc_binding.port }"
                cb(null, deregistered) if cb?
            @registry_connection.on 'failure', ->
                log.e "[deregister] Registry is dead"
                cb() if cb?

