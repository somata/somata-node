util = require 'util'
zmq = require 'zmq'
{log, randomString} = require './helpers'
_ = require 'underscore'
BargeConnection = require './barge-connection'
BargeRegistryConnection = require './barge-registry-connection'

VERBOSE = true
DEFAULT_PROTO = 'tcp'
DEFAULT_BIND = '0.0.0.0'
DEFAULT_PORT = 9910

module.exports = barge = {}

class BargeBinding

    constructor: (options={}) ->
        @id = @id || randomString()
        log "Created id: " + @id

        @proto = options.proto || DEFAULT_PROTO
        @host = DEFAULT_BIND
        @port = options.port || DEFAULT_PORT
        @address = @proto + '://' + @host + ':' + @port

        @socket = zmq.socket 'router'
        @socket.bindSync @address
        @socket.on 'message', (client_id, message_json) =>
            @handleMessage client_id.toString(), JSON.parse message_json

        log "Bound to #{ @address }..."

    send: (client_id, message) ->
        @socket.send [ client_id, JSON.stringify message ]

    handleMessage: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message }" if VERBOSE

class BargeService

    constructor: (options) ->
        registry_options = options.registry
        service_options = options.service

        @registry_connection = new BargeRegistryConnection registry_options
        @registry_connection.register service_options

        @service_binding = new BargeBinding service_options
        @service_binding.handleMessage = (client_id, message) =>
            log "<#{ client_id }>: #{ util.inspect message }" if VERBOSE
            if _method = @[message.method]
                log 'Executing ' + message.method
                _method message.args..., (response) =>
                    console.log "Got: " + response
                    @service_binding.send client_id,
                        id: message.id
                        type: 'response'
                        response: response
            else
                log 'No method ' + message.method, color: 'yellow'

module.exports = BargeService

