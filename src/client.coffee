util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
Connection = require './connection'
{log, randomString} = helpers
{EventEmitter} = require 'events'
emitters = require './events'

VERBOSE = process.env.SOMATA_VERBOSE || false
KEEPALIVE = process.env.SOMATA_KEEPALIVE || true
CONNECTION_KEEPALIVE_MS = 6500
CONNECTION_LINGER_MS = 1500
CONNECTION_RETRY_MS = 2500

class Client
    constructor: (options={}) ->
        _.extend @, options

        @connection_manager = new EventEmitter
        @registry_connection = new Connection port: 8420

        # Keep track of subscriptions
        @service_subscriptions = {}

        # Keep track of existing connections by service name
        @service_connections = {}

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
            log.e err
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
        log.w "[Client.subscribe] #{ service_name }:#{ event_name } not a function: " + cb
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

            # TODO: Move retrying into getServiceConnection?

            if service_connection?

                # If we've got a connection, send a subscription message with it
                service = service_connection.service_instance
                log.i "[Client.subscribe] #{ service.id } : #{ event_name }"

                subscription = service_connection.sendSubscribe subscription_id, event_name, args, cb
                subscription.service = service_name
                subscription.connection = service_connection
                me.service_subscriptions[subscription_id] = subscription

                # TODO
                # Attempt to resubscribe if the service is deregistered but the
                # subscription has not already been ended
                # me.consul_agent.once 'deregister:services/' + service.id, ->
                #     if service_connection.pending_responses[subscription_id]?
                #         delete service_connection.pending_responses[subscription_id]
                #         setTimeout _trySubscribe, 1500

            else
                # TODO: Exponential backoff
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
            sub.connection.sendUnsubscribe sub_id, sub.event_name
            delete @service_subscriptions[sub_id]

# Unsubscribe from every connected subscription

Client::unsubscribeAll = ->
    _.pairs(@service_subscriptions).map ([sub_id, sub], _cb) ->
        sub.connection.sendUnsubscribe sub_id, sub.event_name

# Helper for binding specific services

Client::bindRemote = (service_name) ->
    @remote.bind @, service_name

# Connections and connection managment
# ==============================================================================

# Query for and connect to a service

Client::getServiceConnection = (service_name, cb) ->
    service_name = service_name

    if service_connection = @service_connections[service_name]
        cb null, service_connection
        return

    @registry_connection.sendMethod null, 'getService', [service_name], (err, service_instance) =>
        service_connection = new Connection port: service_instance.port
        service_connection.service_instance = service_instance
        @service_connections[service_name] = service_connection

        # TODO: Let other connections know this is connected
        # @connection_manager.emit 'connected:' + service_name, service_connection

        cb null, service_connection

# TODO
# Disconnecting
# ------------------------------------------------------------------------------

# Check for unhealthy services on an interval and kill connections

Client::purgeDeadServiceConnections = ->
    @getUnhealthyServiceInstances (err, unhealthy_instances) =>
        unhealthy_instances.each (instance) =>
            if @service_connections[instance.Service.Service]?
                @killConnection instance

# Kill an existing connection

Client::killConnection = (instance) ->
    service_name = instance.Service.Service
    service_id = instance.Service.ID
    log.w '[killConnection] ' + service_name if VERBOSE
    if connection = @service_connections[service_name]?[service_id]
        delete @service_connections[service_name][service_id]
        doClose = ->
            log.w "Closing connection to #{ service_name }..." if VERBOSE
            connection.close()
        setTimeout doClose, CONNECTION_LINGER_MS

module.exports = Client

