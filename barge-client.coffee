util = require 'util'
{log, randomString} = require './helpers'
_ = require 'underscore'
BargeConnection = require './barge-connection'

class BargeClient

    constructor: (@options={}) ->
        @registrar_connection = new BargeConnection @options.registry

    sendQuery: (service_name, on_response) ->
        @registrar_connection.send
            type: 'query'
            args:
                service_name: service_name
        , (err, response) ->
            on_response response.service

    remote: (service_name, method, args..., cb) ->

        # Send query
        @sendQuery service_name, (service) ->
            if !service?
                log "Could not find service", color: 'yellow'
            else
                log "Found service:", color: 'green'
                log util.inspect service
                connectToService service

        # Connect to service
        connectToService = (service) ->
            service_connection = new BargeConnection service.binding
            sendMethod service_connection

        # Send method to service
        sendMethod = (service_connection) ->
            service_connection.send
                type: 'method'
                method: method
                args: args
            , (err, response) ->
                log "Got response: " + util.inspect(response), color: 'green'
                cb null, response.response

module.exports = BargeClient

