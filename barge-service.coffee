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
    methods: {}

    constructor: (@service_options) ->
        @service_binding = new BargeBinding @service_options
        @service_binding.handleMessage = @handleMessage.bind(@)

    handleMessage: (client_id, message) =>
        log "<#{ client_id }>: #{ util.inspect message }" if VERBOSE

        # Find the method
        if _method = @methods[message.method]

            # Execute the method with the arguments
            log 'Executing ' + message.method if VERBOSE
            _method message.args..., (err, response) =>

                # Respond to the client
                @service_binding.send client_id,
                    id: message.id
                    type: 'response'
                    response: response

        # Method not found for this service
        else
            # TODO: Send a failure message to client
            log 'No method ' + message.method, color: 'yellow'

    register: (@registry_options) ->
        @registry_connection = new BargeRegistryConnection @registry_options
        @registry_connection.register @service_options

module.exports = BargeService

