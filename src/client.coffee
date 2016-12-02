Connection = require './connection'
Subscription = require './subscription'
{EventEmitter} = require 'events'
helpers = require './helpers'
{log} = helpers

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
            proto: REGISTRY_PROTO
            host: REGISTRY_HOST
            port: REGISTRY_PORT

        @registry_connection.once 'connect', @connectedToRegistry.bind(@)
        @registry_connection.on 'reconnect', @findServices.bind(@)

    connectedToRegistry: ->
        @connected_to_registry = true
        register_subscription = new Subscription {type: 'register', cb: @registeredService.bind(@)}
        deregister_subscription = new Subscription {type: 'deregister', cb: @deregisteredService.bind(@)}
        register_subscription.subscribe @registry_connection, {keepalive: true}
        deregister_subscription.subscribe @registry_connection, {keepalive: true}
        @findServices()

    findServices: ->
        @registry_connection.sendMethod null, 'findServices', [], (err, services) =>
            @known_services = services
            log.s '[findServices] found services', Object.keys(services)
            @emit 'found-services'

    registeredService: (new_service) ->
        log.d '[Client.registry_connection.register]', new_service
        @known_services[new_service.name] ||= {}
        @known_services[new_service.name][new_service.id] = new_service

    deregisteredService: (old_service) ->
        log.d '[Client.registry_connection.deregister]', old_service
        delete @known_services[old_service.name]?[old_service.id]

    # Main API of call and subscribe

    call: (service, method, args..., cb) ->
        log.d '[call]', service, method, args
        if connection = @getConnection(service)
            connection.sendMethod null, method, args, cb
        else
            log.e '[call] No connection'
            cb 'No connection'

    subscribe: (service, type, args..., cb) ->
        if !@connected_to_registry
            setTimeout (=> @subscribe service, type, args..., cb), 500
            return

        log.d '[subscribe]', service, type, args
        if connection = @getConnection(service)
            s = new Subscription {service, type, args, cb}
            s.subscribe connection
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
        if connection = @service_connections[service_name]
            return connection
        else
            if service = @getService(service_name)
                connection = new Connection {host: service.host, port: service.port}
                @service_connections[service_name] = connection
                connection.on 'timeout', =>
                    log.e "[connection.on timeout] #{service_name}"
                    delete @service_connections[service_name]
                    for subscription in @service_subscriptions[service_name]
                        subscription.unsubscribe()
                        @resubscribe(subscription)
                    connection.close()
                return connection
            else
                return null

module.exports = Client
