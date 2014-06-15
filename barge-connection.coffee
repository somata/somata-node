zmq = require 'zmq'
util = require 'util'
{log, randomString} = require './helpers'

VERBOSE = true
DEFAULT_PROTO = 'tcp'
DEFAULT_CONNECT = 'localhost'
DEFAULT_PORT = 9910

module.exports = class BargeConnection

    pending_responses: {}

    constructor: (options={}) ->
        @connect options

    connect: (options) ->
        @id = options.id || randomString()
        log "Created id: " + @id

        @proto = options.proto || DEFAULT_PROTO
        @host = options.host || DEFAULT_CONNECT
        @port = options.port || DEFAULT_PORT
        @address = @proto + '://' + @host + ':' + @port

        @socket = zmq.socket 'dealer'
        @socket.identity = @id
        @socket.connect @address
        @socket.on 'message', (message_json) =>
            @handleMessage JSON.parse message_json

        log "Connected to #{ @address }..."

    handleMessage: (message) ->
        log ">: #{ util.inspect message }" if VERBOSE
        if on_response = @pending_responses[message.id]
            on_response(null, message)

    send: (message, on_response) ->
        message.id = randomString 16
        @socket.send JSON.stringify message
        if on_response?
            @pending_responses[message.id] = on_response
        return message

