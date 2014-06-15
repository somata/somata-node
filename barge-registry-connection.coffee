_ = require 'underscore'
util = require 'util'
{log} = require './helpers'
BargeConnection = require './barge-connection'

VERBOSE = true
HEARTBEAT_INTERVAL = 5000

module.exports = class BargeRegistrarConnection extends BargeConnection
    constructor: (@registry_options={}, @service_options={}) ->
        @connect @registry_options

    handleMessage: (message) ->
        log ">: #{ util.inspect message }" if VERBOSE
        if message.command == 'register?'
            @sendRegister()

    register: (options) ->
        @sendRegister options
        @startHeartbeats()

        process.on 'SIGINT', =>
            @sendUnregister()
            process.exit()

    sendRegister: (options) ->
        @send
            type: 'register'
            args: _.extend options,
                id: @id

    sendUnregister: ->
        @send
            type: 'unregister'

    sendHeartbeat: ->
        @send
            type: 'heartbeat'
            args:
                id: @id
                name: @name

    startHeartbeats: ->
        setInterval (=> @sendHeartbeat.call(@)), HEARTBEAT_INTERVAL

