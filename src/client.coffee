util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
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

Client = (@options={}) ->
    @consul_agent = new ConsulAgent
    @subscriptions = {}

    # Deregister when quit
    process.on 'SIGINT', =>
        @unsubscribeAll ->
            process.exit()

    return @

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
    @getServiceConnection service_name, (err, service_connection) ->
        if err
            log.e err
        else
            service_connection.sendMethod method, args, cb

# Subscriptions
# --------------------------------------

# Keep track of subscriptions

Client::service_subscriptions = {}

# Subscribe to a service's events
#
# TODO: Decide on `on` vs `subscribe`

Client::subscribe = (service_name, type, args..., cb) ->

    # Make sure the last argument is a function
    if typeof cb != 'function'
        log.w "[Client.subscribe] #{ service_name }:#{ type } not a function: " + cb
        args.push cb
        cb = -> log.w "#{ service_name }:#{ type } event received with no callback."

    # In case the subsctiption fails or drops
    _retrySubscribe = (=> @subscribe service_name, type, args..., cb)

    # Look for the service
    @getServiceConnection service_name, (err, service_connection) =>

        if err
            # Attempt to retry subscription if the service was not found
            log.e err + "... retrying in #{ CONNECTION_RETRY_MS/1000 }s"
            setTimeout _retrySubscribe, CONNECTION_RETRY_MS

        else
            # If we've got a connection, send a subscription message with it
            service = service_connection.service
            subscription = service_connection.sendSubscribe type, args, cb
            subscription.connection = service_connection
            @service_subscriptions[subscription.id] = subscription

            # Attempt to resubscribe if the service is deregistered
            @consul_agent.once 'deregister:services/' + service.ID, =>
                delete service_connection.pending_responses[subscription.id]
                _retrySubscribe()

# Client::on is an alias for Client::subscribe

Client::on = (service_name, type, args..., cb) ->
    @subscribe service_name, type, args..., cb

# Unsubscribe from every connected subscription

Client::unsubscribeAll = (cb) ->
    for subscription_id, subscription of @service_subscriptions
        subscription.connection.sendUnsubscribe subscription.id, subscription.type
    cb()

# Helper for binding specific services

Client::bindRemote = (service_name) ->
    @remote.bind @, service_name

# Connections and connection managment
# ==============================================================================

# Keep track of existing connections by service name

Client::service_connections = {}

# Query for and connect to a service

Client::getServiceConnection = (service_name, cb) ->
    service_name = PREFIX + service_name

    if service_connection = @service_connections[service_name]
        # Use an existing connection
        cb null, service_connection

    else

        # Find all healthy services of this name
        @consul_agent.getHealthyServiceInstances service_name, (err, healthy_instances) =>

            if !healthy_instances.length
                return cb "Could not find service `#{ service_name }`", null

            # Choose one of the available instances and connect
            instance = helpers.randomChoice healthy_instances
            service_connection = @connectToService instance

            # Save for later use
            @saveServiceConnection instance.Service, service_connection
            cb null, service_connection

# Connect to a service at a found node's address & port

Client::connectToService = (instance) ->
    log.i "[connectToService] Connecting to #{ instance.Service.Service } @ #{ instance.Node.Node } <#{ instance.Node.Address }:#{ instance.Service.Port }>" if VERBOSE
    connection = Connection.fromConsulService instance
    return connection

# Save a connection to a service by name

Client::saveServiceConnection = (service, service_connection) ->
    service_connection.service = service
    @service_connections[service.Service] = service_connection

    if KEEPALIVE
        @consul_agent.once 'deregister:services/' + service.ID, =>
            log.w "Deregistered: #{ service.ID }"
            @killConnection service.Service

    else
        setTimeout (=> @killConnection service.Service), CONNECTION_TIMEOUT_MS

# Disconnecting
# ------------------------------------------------------------------------------

# Check for unhealthy services on an interval and kill connections

Client::purgeDeadServiceConnections = ->
    @getUnhealthyServiceInstances (err, unhealthy_instances) =>
        unhealthy_instances.each (instance) =>
            if @service_connections[instance.Service.Service]?
                @killConnection instance.Service.Service

# Kill an existing connection

Client::killConnection = (service_name) ->
    log.w '[killConnection] ' + service_name if VERBOSE
    if connection = @service_connections[service_name]
        delete @service_connections[service_name]
        doClose = ->
            log.w "Closing connection to #{ service_name }..."
            connection.close()
        setTimeout doClose, CONNECTION_LINGER_MS

module.exports = Client

