util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
{EventEmitter} = require 'events'
ConsulAgent = require './consul-agent'
Connection = require './connection'
log = helpers.log

VERBOSE = process.env.SOMATA_VERBOSE || false
KEEPALIVE = process.env.SOMATA_KEEPALIVE || true
CONNECTION_TIMEOUT_MS = 6500
CONNECTION_LINGER_MS = 1500
CONNECTION_RETRY_MS = 2500

PREFIX = ''
if process.env.SOMATA_PREFIX?
    PREFIX = process.env.SOMATA_PREFIX + ':'

class Client
    constructor: (options={}) ->
        _.extend @, options
        @setDefaults()

        @consul_agent = new ConsulAgent
        @connection_manager = new EventEmitter

        # Keep track of subscriptions
        @service_subscriptions = {}

        # Keep track of existing connections by service name
        @service_connections = {}

        # Deregister when quit
        process.on 'SIGINT', =>
            @unsubscribeAll()
            if !@parent?
                process.exit()

        return @

# TODO: Define defaults in one consistent place
Client::setDefaults = ->
    _.defaults @,
        save_connections: true

# Remote method calls and event handling
# ==============================================================================

# Calling remote methods
# --------------------------------------

# Execute a service's remote method
#
# TODO: Decide on `call` vs `remote`

Client::call = (service_name, method, args..., cb) ->
    @remote service_name, method, args..., cb

Client::remote = (service_name, method, args..., cb) ->
    if typeof cb != 'function'
        args.push cb if cb?
        if VERBOSE
            cb = -> log.w "#{ service_name }:#{ method } completed with no callback."
        else cb = null

    message_id = helpers.randomString 16

    @getServiceConnection service_name, (err, service_connection) ->
        if err
            log.e err
        else
            service_connection.sendMethod message_id, method, args, cb

    return message_id

# Subscriptions
# --------------------------------------

# Subscribe to a service's events
#
# TODO: Decide on `on` vs `subscribe`

Client::subscribe = (service_name, type, args..., cb) ->

    # Make sure the last argument is a function
    if typeof cb != 'function'
        log.w "[Client.subscribe] #{ service_name }:#{ type } not a function: " + cb
        args.push cb
        cb = -> log.w "#{ service_name }:#{ type } event received with no callback."

    # Create a subscription ID to be returned
    subscription_id = "#{ service_name }:#{ type }"
    subscription_id += "(#{ args.join(', ') })" if args.length
    log.i "[Client.subscribe] subscribing with id=#{ subscription_id }"

    # Look for the service
    @getServiceConnection service_name, (err, service_connection, retry=true) =>

        # TODO: Move into getServiceConnection
        # if err
        #     # Attempt to retry subscription if the service was not found
        #     log.e err + "... retrying in #{ CONNECTION_RETRY_MS/1000 }s"
        #     setTimeout _retrySubscribe, CONNECTION_RETRY_MS

        # If we've got a connection, send a subscription message with it
        service = service_connection.service
        subscription = service_connection.sendSubscribe subscription_id, type, args, cb
        subscription.service = service_name
        subscription.connection = service_connection
        @service_subscriptions[subscription_id] = subscription

        # Attempt to resubscribe if the service is deregistered
        @consul_agent.once 'deregister:services/' + service.ID, =>
            # Only retry if the subsctiption has not already been ended
            if service_connection.pending_responses[subscription_id]?
                delete service_connection.pending_responses[subscription_id]
                _retrySubscribe()

    return subscription_id

# Client::on is an alias for Client::subscribe

Client::on = (service_name, type, args..., cb) ->
    @subscribe service_name, type, args..., cb

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
    _.pairs(@service_subscriptions).map ([sub_id, sub], _cb) ->
        sub.connection.sendUnsubscribe sub_id, sub.type

# Helper for binding specific services

Client::bindRemote = (service_name) ->
    @remote.bind @, service_name

# Connections and connection managment
# ==============================================================================

# Query for and connect to a service

Client::getServiceConnection = (service_name, cb) ->
    service_name = PREFIX + service_name

    # Find all healthy services of this name
    @consul_agent.getServiceHealth service_name, (err, healthy_instances) =>

        if !healthy_instances.length
            err = "Could not find service `#{ service_name }`"
            log.e err
            cb err, null

        # Choose one of the available instances and connect
        instance = helpers.randomChoice healthy_instances
        service_connection = @connectToService instance
        service_connection.connected = true

        # Save for later use
        @saveServiceConnection instance.Service, service_connection #if @save_connections
        cb null, service_connection

        # Let other connections know this is connected
        @connection_manager.emit 'connected:' + service_name, service_connection

# Connect to a service at a found node's address & port

Client::connectToService = (instance) ->
    if connection = @service_connections[instance.Service.Service]?[instance.Service.ID]
        if connection.connected
            return connection
    log.i "[connectToService] Connecting to #{ instance.Service.ID } @ #{ instance.Node.Node } <#{ instance.Node.Address }:#{ instance.Service.Port }>" if VERBOSE
    connection = Connection.fromConsulService instance, @connection_options

    if KEEPALIVE
        @consul_agent.once 'deregister:services/' + instance.Service.ID, =>
            log.w "Deregistered: #{ instance.Service.ID }"
            @killConnection instance

    else
        setTimeout (=> @killConnection instance), CONNECTION_TIMEOUT_MS

    return connection

# Save a connection to a service by name

Client::saveServiceConnection = (service, service_connection) ->
    service_connection.service = service
    @service_connections[service.Service] ||= {}
    @service_connections[service.Service][service.ID] = service_connection

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
            log.w "Closing connection to #{ service_name }..."
            connection.close()
        setTimeout doClose, CONNECTION_LINGER_MS

module.exports = Client

