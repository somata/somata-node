util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
ConsulAgent = require './consul-agent'
Connection = require './connection'
log = helpers.log

VERBOSE = process.env.SOMATA_VERBOSE || false
KEEPALIVE = process.env.SOMATA_KEEPALIVE || false
CONNECTION_TIMEOUT_MS = 6500
CONNECTION_LINGER_MS = 1500
CONNECTION_RETRY_MS = 2500

Client = (@options={}) ->
    @consul_agent = new ConsulAgent
    @subscriptions = {}
    return @

# Keep track of existing connections by service name

Client::service_connections = {}

# Execute a service's remote method

Client::call = (service_name, method, args..., cb) ->
    @remote service_name, method, args..., cb

Client::remote = (service_name, method, args..., cb) ->
    @getServiceConnection service_name, (err, service_connection) ->
        if err
            log.e err
        else
            service_connection.sendMethod method, args..., cb

Client::on = (service_name, type, cb) ->
    @subscribe service_name, type, cb

Client::subscribe = (service_name, type, cb) ->
    _retry_subscribe = (=> @subscribe service_name, type, cb)
    @getServiceConnection service_name, (err, service_connection) =>

        if err
            # Attempt to retry subscription if the service was not found
            log.e err + "... retrying in #{ CONNECTION_RETRY_MS/1000 }s"
            setTimeout _retry_subscribe, CONNECTION_RETRY_MS

        else
            # If we've got a connection, send a subscription message with it
            service = service_connection.service
            subscription = service_connection.sendSubscribe type, cb

            # Attempt to resubscribe if the service is deregistered
            @consul_agent.once 'deregister:services/' + service.ID, =>
                delete service_connection.pending_responses[subscription.id]
                _retry_subscribe()

# Queries for and connects to a service

Client::getServiceConnection = (service_name, cb) ->

    if service_connection = @service_connections[service_name]
        # Use an existing connection
        cb null, service_connection

    else

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
            @killConnection service.Service

    else
        setTimeout (=> @killConnection service.Service), CONNECTION_TIMEOUT_MS

# Check for unhealthy services on an interval and kill connections

Client::purgeDeadServiceConnections = ->
    @getUnhealthyServiceInstances (err, unhealthy_instances) =>
        unhealthy_instances.each (instance) =>
            if @service_connections[instance.Service.Service]?
                @killConnection instance.Service.Service

# Kill an existing connection

Client::killConnection = (service_name) ->
    log.w '[killConnection] ' + service_name if VERBOSE
    connection = @service_connections[service_name]
    delete @service_connections[service_name]
    setTimeout (-> connection.close()), CONNECTION_LINGER_MS

module.exports = Client

