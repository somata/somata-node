Connection = require './connection'
Subscription = require './subscription'
{EventEmitter} = require 'events'
helpers = require './helpers'
{log} = helpers
emitters = require './events'

emitters.exit.onExit ->
    process.exit()

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

        @registry_connection.once 'connect', @connectedToRegistry.bind(@)
        @registry_connection.on 'reconnect', @findServices.bind(@)

        @register_subscription = new Subscription {service: 'registry', type: 'register'}
        @register_subscription.on 'register', @registeredService.bind(@)

        @deregister_subscription = new Subscription {service: 'registry', type: 'deregister'}
        @deregister_subscription.on 'deregister', @deregisteredService.bind(@)

    connectedToRegistry: ->
        @connected_to_registry = true

        @register_subscription.subscribe @registry_connection, {keepalive: true}
        @deregister_subscription.subscribe @registry_connection, {keepalive: true}

        @findServices()

    findServices: ->
        @registry_connection.sendMethod null, 'findServices', [], (err, services) =>
            @known_services = services

    registeredService: (new_service) ->
        log.d '[Client.registry_connection.register]', new_service if VERBOSE > 1
        @known_services[new_service.name] ||= {}
        @known_services[new_service.name][new_service.id] = new_service

    deregisteredService: (old_service) ->
        log.d '[Client.registry_connection.deregister]', old_service if VERBOSE > 1
        delete @known_services[old_service.name]?[old_service.id]

        if subscriptions = @service_subscriptions[old_service.name]
            subscriptions.filter((s) -> s.connection.id == old_service.id).forEach (subscription) =>
                subscription.unsubscribe()
                @resubscribe(subscription)

    # Main API of remote and subscribe

    remote: (service, method, args..., cb) ->
        log.d '[remote]', service, method, args
        if connection = @getConnection(service)
            connection.sendMethod null, method, args, cb
        else
            log.e '[remote] No connection'
            cb 'No connection'

    subscribe: (service, type, args..., cb) ->
        if arguments.length == 2 # (options, cb) ->
            options = arguments[0]
            cb = arguments[1]
            {id, service, type, args} = options
        else
            id = helpers.randomString()

        if !@connected_to_registry
            setTimeout (=> @subscribe {id, service, type, args}, cb), 500
            return

        log.d '[subscribe]', service, type, args
        if connection = @getConnection(service)
            s = new Subscription {id, service, type, args, cb}
            s.subscribe connection
            s.on type, cb
            @service_subscriptions[service] ||= []
            @service_subscriptions[service].push s
        else
            log.e '[subscribe] No connection'
            _subscribe = => @subscribe service, type, args..., cb
            setTimeout _subscribe, 1500

    resubscribe: (subscription) ->
        if connection = @getConnection(subscription.service)
            subscription.subscribe connection
        else
            log.e '[resubscribe] no connection'
            _resubscribe = => @resubscribe subscription
            setTimeout _resubscribe, 1500

    # Connections to Services

    getService: (service_name) ->
        if services = @known_services[service_name]
            return services[helpers.randomChoice(Object.keys(services))]
        else
            return null

    getConnection: (service_name) ->
        if service_name == 'registry'
            return @registry_connection
        else if connection = @service_connections[service_name]
            return connection
        else
            if service = @getService(service_name)
                connection = new Connection {id: service.id, host: service.host, port: service.port}
                @service_connections[service_name] = connection
                connection.on 'timeout', =>
                    log.e "[connection.on timeout] #{service_name}"
                    delete @service_connections[service_name]
                    if subscriptions = @service_subscriptions[service_name]
                        for subscription in subscriptions
                            subscription.unsubscribe()
                            @resubscribe(subscription)
                    connection.close()
                return connection
            else
                return null

module.exports = Client
