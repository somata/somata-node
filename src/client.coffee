util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
Connection = require './connection'
{log, randomString} = helpers
{EventEmitter} = require 'events'
emitters = require './events'

REGISTRY_HOST = process.env.SOMATA_REGISTRY_HOST || '127.0.0.1'
REGISTRY_PORT = process.env.SOMATA_REGISTRY_PORT || 8420
VERBOSE = process.env.SOMATA_VERBOSE || false
KEEPALIVE = process.env.SOMATA_KEEPALIVE || true
CONNECTION_KEEPALIVE_MS = 6500
CONNECTION_LINGER_MS = 1500
CONNECTION_RETRY_MS = 2500

class Client
    constructor: (options={}) ->
        _.extend @, options

        @events = new EventEmitter

        # Keep track of subscriptions
        # subscription_id -> {name, instance, connection}
        @service_subscriptions = {}

        # Keep track of existing connections by service name
        @service_connections = {}

        # Connect to registry
        @registry_connection = new Connection host: REGISTRY_HOST, port: REGISTRY_PORT
        @registry_connection.service_instance = {id: 'registry', name: 'registry'}
        @service_connections['registry'] = @registry_connection
        @registry_connection.sendPing()
        @registry_connection.once 'connect', @registryConnected.bind(@)

        # Deregister when quit
        emitters.exit.onExit (cb) =>
            log.w 'Unsubscribing remote listeners...'
            @unsubscribeAll()
            cb()

        return @

# Remote method calls and event handling
# ==============================================================================

# Calling remote methods
# --------------------------------------

# Execute a service's remote method
#
# TODO: Decide on `call` vs `remote`

Client::call = (service_name, method_name, args..., cb) ->
    if typeof cb != 'function'
        args.push cb if cb?
        if VERBOSE
            cb = -> log.w "#{ service_name }:#{ method_name } completed with no callback."
        else cb = null

    message_id = helpers.randomString 16

    @getServiceConnection service_name, (err, service_connection) =>
        if err
            # TODO: Some way to retry?
            log.e err
            cb err
        else
            service_connection.sendMethod message_id, method_name, args, cb

    return message_id

Client::remote = Client::call

# Subscriptions
# --------------------------------------

# Subscribe to a service's events
#
# TODO: Decide on `on` vs `subscribe`

Client::subscribe = (service_name, event_name, args..., cb) ->

    # Make sure the last argument is a function
    if typeof cb != 'function'
        log.w "[Client.subscribe] #{ service_name }:#{ event_name } not a function: " + cb if VERBOSE
        args.push cb
        cb = -> log.w "#{ service_name }:#{ event_name } event received with no callback."

    # Create a subscription ID to be returned
    subscription_id = "#{ service_name }:#{ event_name }"
    subscription_id += "(#{ args.join(', ') })" if args.length
    subscription_id += randomString(4)

    me = @
    _trySubscribe = ->

        # Look for the service
        me.getServiceConnection service_name, (err, service_connection) ->

            if service_connection?

                # If we've got a connection, send a subscription message with it
                {service_instance} = service_connection
                log.i "[Client.subscribe] #{service_instance.id} : #{event_name}" if VERBOSE

                subscription = service_connection.sendSubscribe subscription_id, event_name, args, cb
                subscription.name = service_name
                subscription.instance = service_instance
                subscription.connection = service_connection
                me.service_subscriptions[subscription_id] = subscription

                # TODO
                # Attempt to resubscribe if the service is deregistered but the
                # subscription has not already been ended
                subscription.connection.once 'reconnect', ->
                    if subscription = me.service_subscriptions[subscription_id]
                        log.i "[Client.subscribe.reconnect] Going to resubscribe #{subscription_id}" if VERBOSE
                        delete subscription.connection.pending_responses[subscription_id]
                        _trySubscribe()

            else
                # TODO: Exponential backoff
                log.w "[Client.subscribe] Going to retry subscription to #{service_name}" if VERBOSE
                setTimeout _trySubscribe, 1500

    _trySubscribe()
    return subscription_id

# Client::on is an alias for Client::subscribe

Client::on = Client::subscribe

# Unsubscribe from matching subscriptions

Client::unsubscribe = (_sub_id) ->
    _.chain(@service_subscriptions).pairs()
        .filter((pair) -> pair[0] == _sub_id)
        .map (pair, _cb) =>
            [sub_id, sub] = pair
            sub.connection.sendUnsubscribe sub_id, sub.type
            delete @service_subscriptions[sub_id]

# Unsubscribe from every connected subscription

Client::unsubscribeAll = ->
    _.pairs(@service_subscriptions).map ([sub_id, sub], _cb) =>
        @getServiceConnection sub.instance.name, (err, service_connection) ->
            service_connection.sendUnsubscribe sub_id, sub.type

# Helper for binding specific services / methods

Client::bindRemote = (bound_args...) ->
    @remote.bind @, bound_args...

Client::bindService = (service_name) ->
    service_obj = {}
    _boundRemote = @remote.bind @, service_name
    @getServiceInstance service_name, (err, service_instance) ->
        if service_instance?
            service_instance.methods.map (method_name) ->
                service_obj[method_name] = (args...) ->
                    _boundRemote(method_name, args...)
    service_obj

# Connections and connection managment
# ==============================================================================

# Query for and connect to a service

Client::getServiceInstance = (service_name, cb) ->
    @registry_connection.sendMethod null, 'getService', [service_name], cb

Client::getServiceConnection = (service_name, cb) ->

    if service_connection = @service_connections[service_name]
        cb null, service_connection
        return

    @getServiceInstance service_name, (err, service_instance) =>
        if err then return cb err

        log.i "New connection to #{service_instance.id}" if VERBOSE
        service_connection = new Connection port: service_instance.port, host: service_instance.host
        service_connection.service_instance = service_instance
        service_connection.on 'failure', =>
            @closeConnection service_instance
        @service_connections[service_name] = service_connection

        # TODO: Let other connections know this is connected
        # @events.emit 'connected:' + service_name, service_connection

        cb null, service_connection

# Disconnecting
# ------------------------------------------------------------------------------

Client::registryConnected = ->
    @subscribe 'registry', 'deregister', @deregistered.bind(@)
    @registry_connection.on 'connect', @registryReconnected.bind(@)

Client:: registryReconnected = ->
    @closeAllConnections()
    @resubscribeAll()

Client::closeAllConnections = ->
    for service_id, service_connection of @service_connections
        if service_id != 'registry'
            @closeConnection service_connection.service_instance

Client::deregistered = (service_instance) ->
    if service_connection = @service_connections[service_instance.name]
        @closeConnection service_instance
        @resubscribe service_instance.id

Client::resubscribe = (service_id) ->
    for subscription_id, subscription of @service_subscriptions
        if subscription.instance.id == service_id
            subscription.connection.emit('reconnect')

Client::resubscribeAll = ->
    for subscription_id, subscription of @service_subscriptions
        service_id = subscription.instance.id
        @resubscribe service_id

# Close an existing connection

Client::closeConnection = (service_instance) ->
    service_name = service_instance.name
    log.w "[closeConnection] #{service_name}" if VERBOSE
    service_connection = @service_connections[service_name]
    delete @service_connections[service_name]
    doClose = ->
        log.d "[closeConnection] Connection to #{service_name} closed after #{CONNECTION_LINGER_MS/1000}s" if VERBOSE
        service_connection.close()
    setTimeout doClose, CONNECTION_LINGER_MS

module.exports = Client

