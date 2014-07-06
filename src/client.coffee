util = require 'util'
helpers = require './helpers'
_ = require 'underscore'
ConsulAgent = require './consul-agent'
Connection = require './connection'
log = helpers.log

VERBOSE = false

Client = (@options={}) ->
    @consul_agent = new ConsulAgent
    return @

# Keep track of existing connections by service name

Client::service_connections = {}

# Execute a service's remote method

Client::remote = (service_name, method, args..., cb) ->
    @getServiceConnection service_name, (err, service_connection) ->
        service_connection.invoke method, args..., cb

# Queries for and connects to a service

Client::getServiceConnection = (service_name, cb) ->

    if service_connection = @service_connections[service_name]
        # Use an existing connection
        cb null, service_connection

    else
        # Otherwise ask the consul agent
        @getServiceNodes service_name, (err, nodes) =>
            if !nodes? or !nodes.length
                log "Could not find service", color: 'yellow'

            else
                node = helpers.randomChoice nodes
                service_connection = @connectToServiceNode node

                # Save for further use
                @saveServiceConnection service_name, service_connection
                cb null, service_connection

# Ask the Consul agent for a service's available nodes

Client::getServiceNodes = (service_name, cb) ->
    @consul_agent.getServiceNodes service_name, cb

# Connect to a service at a found node's address & port

Client::connectToServiceNode = (node) ->
    log.s "[connectToServiceNode] Connecting to #{ util.inspect node }" if VERBOSE
    connection = Connection.fromConsulNode node
    return connection

# Save a connection to a service by name

Client::saveServiceConnection = (service_name, service_connection) ->
    @service_connections[service_name] = service_connection
    setTimeout @killConnection.bind(@, service_name, service_connection), 3500

# Kill an existing connection

Client::killConnection = (service_name, service_connection) ->
    setTimeout (-> service_connection.close()), 1000
    delete @service_connections[service_name]

module.exports = Client

