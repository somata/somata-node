util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
ConsulAgent = require './consul-agent'
Connection = require './connection'
log = helpers.log

VERBOSE = false
KEEPALIVE = false
CONNECTION_TIMEOUT = 6500
CONNECTION_LINGER = 1500

Client = (@options={}) ->
    @consul_agent = new ConsulAgent
    return @

# Keep track of existing connections by service name

Client::service_connections = {}

# Execute a service's remote method

Client::remote = (service_name, method, args..., cb) ->
    @getServiceConnection service_name, (err, service_connection) ->
        if err
            log.e err
        else
            service_connection.sendMethod method, args..., cb

Client::on = (service_name, type, cb) ->
    @getServiceConnection service_name, (err, service_connection) ->
        if err
            log.e err
        else
            service_connection.sendSubscribe type, cb

# Queries for and connects to a service

Client::getServiceConnection = (service_name, cb) ->

    if service_connection = @service_connections[service_name]
        # Use an existing connection
        cb null, service_connection

    else
        # Otherwise ask the consul agent
        @getServiceHealth service_name, (err, instances) =>

            # Filter by those with passing checks
            healthy_instances = instances.filter((i) ->
                i.Checks.filter((c) ->
                    c.Status == 'critical'
                ).length == 0
            )

            if !healthy_instances.length
                return cb "Could not find service", null

            # Choose one of the available instances and connect
            instance = helpers.randomChoice healthy_instances
            service_connection = @connectToService instance

            # Save for later use
            @saveServiceConnection service_name, service_connection
            cb null, service_connection

# Ask the Consul agent for a service's available nodes

Client::getServiceHealth = (service_name, cb) ->
    @consul_agent.getServiceHealth service_name, cb

# Connect to a service at a found node's address & port

Client::connectToService = (instance) ->
    log.s "[connectToService] Connecting to #{ util.inspect instance }" if VERBOSE
    connection = Connection.fromConsulService instance
    return connection

# Save a connection to a service by name

Client::saveServiceConnection = (service_name, service_connection) ->
    @service_connections[service_name] = service_connection
    if !KEEPALIVE
        setTimeout @killConnection.bind(@, service_name, service_connection), CONNECTION_TIMEOUT

# Kill an existing connection

Client::killConnection = (service_name, service_connection) ->
    setTimeout (-> service_connection.close()), CONNECTION_LINGER
    delete @service_connections[service_name]

module.exports = Client

