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
    known_services: {}
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

    registeredService: (err, new_service) ->
        log.d '[Client.registry_connection.register]', new_service if VERBOSE > 1
        @known_services[new_service.name] ||= {}
        @known_services[new_service.name][new_service.id] = new_service

    deregisteredService: (err, old_service) ->
        log.d '[Client.registry_connection.deregister]', old_service if VERBOSE > 1
        delete @service_connections[old_service.name]
        if known = @known_services[old_service.name]?[old_service.id]
            delete @known_services[old_service.name][old_service.id]

        if subscriptions = @service_subscriptions[old_service.name]
            subscriptions.filter((s) -> s.service == old_service.id).forEach (subscription) =>
                # subscription.unsubscribe()
                @resubscribe(subscription)

    # Main API of remote and subscribe

    remote: (service, method, args..., cb) ->
        log.d "[Client.remote] #{service}.#{method}(#{args})"
        @getConnection service, (err, connection) =>
            if connection?
                connection.method method, args..., cb
            else
                log.e '[Client.remote] No connection'
                cb 'No connection'

    subscribe: (service, type, args..., cb) ->
        if arguments.length == 2 # (options, cb) ->
            options = arguments[0]
            cb = arguments[1]
            {id, service, type, args} = options
        else
            id = helpers.randomString()

        if !@connected_to_registry
            console.log 'not subscribed'
            setTimeout (=> @subscribe {id, service, type, args}, cb), 500
            return

        @getConnection service, (err, connection) =>
            if connection?
                log.s '[Client.subscribe]', service, type, args
                # s = new Subscription {id, service, type, args, cb}
                # s.subscribe connection
                # s.on type, cb
                s = connection.subscribe type, args..., cb
                s.cb = cb
                @service_subscriptions[service] ||= []
                @service_subscriptions[service].push s
            else
                log.e '[Client.subscribe] No connection'
                _subscribe = => @subscribe service, type, args..., cb
                setTimeout _subscribe, 1500

    resubscribe: (subscription) ->
        @getConnection subscription.service, (err, connection) =>
            if connection?
                connection.send subscription
            else
                log.e '[Client.resubscribe] no connection'
                _resubscribe = => @resubscribe subscription
                setTimeout _resubscribe, 1500

    # Connections to Services

    getService: (service_id, cb) ->
        @registry_connection.method 'getService', service_id, cb

    getConnection: (service_id, cb) ->
        console.log '[getconnection]', service_id

        if service_id.match /^registry/
            return cb null, @registry_connection

        else if connection = @service_connections[service_id]
            return cb null, connection

        else
            @getService service_id.split('~')[0], (err, service) =>
                console.log 'returning from get service', err, service

                if err or !service?
                    return cb err

                connection = new Connection
                    host: service.host
                    port: service.port
                    service: service
                @service_connections[service_id] = connection

                connection.on 'timeout', =>
                    log.e "[Client.connection.on timeout] #{service_id}"

                    if !connection.keepalive
                        log.w "[Client.connection.on timeout] #{service_id} Closing connection"
                        delete @service_connections[service_id]

                        if subscriptions = @service_subscriptions[service_id]
                            for subscription in subscriptions
                                connection.unsubscribe subscription.id
                                setTimeout =>
                                    @subscribe subscription.service, subscription.type, subscription.cb
                                , 1500
                                # @resubscribe(subscription)
                            delete @service_subscriptions[service_id]

                        connection.close()

                cb null, connection

module.exports = Client
