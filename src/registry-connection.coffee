_ = require 'underscore'
util = require 'util'
{log} = require './helpers'
Connection = require './connection'

VERBOSE = true
HEARTBEAT_MS = 5000

module.exports = class RegistryConnection extends Connection

    heartbeat_ms: HEARTBEAT_MS

    # Register with the Barge registry and start sending heartbeats
    # --------------------------------------------------------------------------
    #
    # When the process is quit, send an `unregister` command before exiting

    register: (service) ->
        @sendRegister service
        @startHeartbeats()

        process.on 'SIGINT', =>
            @sendUnregister()
            process.exit()

    # Handle a message from the registry
    # --------------------------------------------------------------------------
    #
    # If the message is the `register?` command, re-register 

    handleMessage: (message) ->
        log ">: #{ util.inspect message }" if VERBOSE

    # Send a `register` message to the registry
    # --------------------------------------------------------------------------
    #
    # Extends the service's address information {host, port} with
    # the connection's socket id

    sendRegister: (service) ->
        @send
            type: 'register'
            args: _.extend service, id: @id

    # Send an `unregister` message to the registry
    # --------------------------------------------------------------------------

    sendUnregister: ->
        @send
            type: 'unregister'

    # Send a `heartbeat` message to the registry
    # --------------------------------------------------------------------------

    sendHeartbeat: ->
        @send
            type: 'heartbeat'
            args:
                id: @id
                name: @name

    # Start sending heartbeats at an interval
    # --------------------------------------------------------------------------

    startHeartbeats: ->
        clearInterval @heartbeat_interval
        @heartbeat_interval = setInterval @sendHeartbeat.bind(@), @heartbeat_ms

