util = require 'util'
{log, randomString, serviceSummary} = require './helpers'
_ = require 'underscore'
Barge = require './'

class Client

    service_connections: {}

    constructor: (@options={}) ->
        @options.registry ||= {}
        @options.registry = _.defaults @options.registry, Barge.Registry.DEFAULTS
        @registry_connection = new Barge.Connection @options.registry

    sendQuery: (service_name, on_response) ->
        @registry_connection.send
            type: 'query'
            args:
                service_name: service_name
        , (err, response) ->
            on_response response.service

    remote: (service_name, method, args..., cb) ->

        # Send method to service once connected
        @getServiceConnection service_name, (err, service_connection) ->
            service_connection.send
                type: 'method'
                method: method
                args: args
            , (err, response) ->
                #log "Got response: " + util.inspect(response), color: 'green'
                cb null, response.response

    # Queries for and connects to a service
    getServiceConnection: (service_name, cb) ->

        # Check if already connected
        if service_connection = @service_connections[service_name]
            cb null, service_connection

        # Otherwise ask registry
        else
            @sendQuery service_name, (service) =>
                if !service?
                    log "Could not find service", color: 'yellow'

                else
                    log "Found service #{ serviceSummary service }", color: 'green'
                    service_connection = @connectToService service

                    # Save for further use
                    @saveServiceConnection service_name, service_connection
                    cb null, service_connection

    # Connect to service if it isn't already connected
    connectToService: (service) ->
        service_connection = new Barge.Connection service.binding

    # Save a connection to a service by name
    # TODO: Expire
    saveServiceConnection: (service_name, service_connection) ->
        @service_connections[service_name] = service_connection
        setTimeout @killConnection.bind(@, service_name, service_connection), 1500

    killConnection: (service_name, service_connection) ->
        setTimeout (-> service_connection.close()), 1000
        delete @service_connections[service_name]

module.exports = Client

