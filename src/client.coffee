Connection = require './connection'
{EventEmitter} = require 'events'
helpers = require './helpers'
{log} = helpers
emitters = require './events'

VERBOSE = parseInt process.env.SOMATA_VERBOSE || 0
REGISTRY_PROTO = process.env.SOMATA_REGISTRY_PROTO || 'tcp'
REGISTRY_HOST = process.env.SOMATA_REGISTRY_HOST || '127.0.0.1'
REGISTRY_PORT = process.env.SOMATA_REGISTRY_PORT || 8420
CONNECTION_LINGER_MS = 1500
CONNECTION_RETRY_MS = 2500

class Client extends EventEmitter
    subscriptions: {}
    service_subscriptions: {}
    service_connections: {}

    constructor: (options={}) ->
        Object.assign @, options

        @connectToRegistry()

    connectToRegistry: ->
        @registry_connection = new Connection
            proto: @registry_proto or REGISTRY_PROTO
            host: @registry_host or REGISTRY_HOST
            port: @registry_port or REGISTRY_PORT
            service: {id: 'registry~0', name: 'registry'}

        @registry_connection.on 'connect', @registryConnected.bind(@)

    registryConnected: ->
        @connected_to_registry = true

        @registry_connection.subscribe 'register', @registeredService.bind(@)
        @registry_connection.subscribe 'deregister', @deregisteredService.bind(@)

        @emit 'registry_connected', true

    registeredService: (new_service) ->
        log.d '[Client.registry_connection.register]', new_service if VERBOSE > 1

    deregisteredService: (old_service) ->
        log.d '[Client.registry_connection.deregister]', old_service if VERBOSE > 1
        delete @service_connections[old_service.name]

        # TODO: Remove existing subscriptions

    # Main API of remote and subscribe
    # --------------------------------------------------------------------------

    remote: (service, method, args..., cb) ->
        log.d "[Client.remote] #{service}.#{method}(#{args})" if VERBOSE > 1
        @getConnection service, (err, connection) =>
            if connection?
                connection.method method, args..., cb
            else
                log.e "[Client.remote] No connection for #{service}"
                cb 'No connection'

    subscribe: (service, type, args..., cb) ->
        if arguments.length == 1 # options containing cb
            subscription = arguments[0]
            {id, service, type, args, cb} = subscription
        id ||= helpers.randomString()

        if !@connected_to_registry
            setTimeout (=> @subscribe {id, service, type, args, cb}), 500
            return

        if typeof service == 'object'
            service_name = service.name
        else
            service_name = service.split('~')[0]

        @getConnection service_name, (err, connection) =>
            if connection?
                log.i '[Client.subscribe]', {service, type, args} if VERBOSE
                subscription = {id, service: connection.service.id, kind: 'subscribe', type, args}

                if connection.connected
                    @sendSubscription connection, subscription, cb
                else
                    connection.on 'connect', => @sendSubscription connection, subscription, cb

                connection.on 'timeout', =>
                    log.e "[Client.subscribe.connection.on timeout] #{helpers.summarizeConnection connection}" if VERBOSE
                    delete @service_subscriptions[connection.service.id]
                    setTimeout =>
                        @subscribe service, type, args..., cb
                    , 500

            else
                log.e '[Client.subscribe] No connection'
                _subscribe = => @subscribe service, type, args..., cb
                setTimeout _subscribe, 1500

    unsubscribe: (subscription_id) ->
        if subscription = @subscriptions[subscription_id]
            @getConnection subscription.service, (err, connection) ->
                if connection?
                    log.w '[Client.unsubscribe]', subscription_id if VERBOSE
                    connection.unsubscribe(subscription.type, subscription.id)

    sendSubscription: (connection, subscription, cb) ->
        eventCb = (message) -> cb message.error or message.event, message
        delete subscription.cb
        connection.send subscription, eventCb
        subscription.cb = cb
        @service_subscriptions[subscription.service.id] ||= []
        @service_subscriptions[subscription.service.id].push subscription
        @subscriptions[subscription.id] = subscription

    # Connections to Services
    # --------------------------------------------------------------------------

    getService: (service_name, cb) ->
        @registry_connection.method 'getService', service_name, cb

    getConnection: (service_id, cb) ->
        service_name = service_id.split('~')[0]

        if service_name == 'registry'
            return cb null, @registry_connection

        else if connection = @service_connections[service_name]
            return cb null, connection

        else
            @getService service_name, (err, service) =>
                if err or !service?
                    return cb err

                connection = new Connection
                    host: service.host
                    port: service.port
                    service: service
                @service_connections[service_name] = connection

                connection.on 'timeout', =>
                    delete @service_connections[service_name]
                    connection.close()

                cb null, connection

    closeConnections: ->
        for service_name, connection of @service_connections
            connection.close()
        @registry_connection.close()

module.exports = Client
