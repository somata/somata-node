zmq = require 'zmq'
util = require 'util'
{EventEmitter} = require 'events'
{randomString, log} = require './helpers'

VERBOSE = false
DEFAULT_PROTO = 'tcp'
DEFAULT_BIND = '0.0.0.0'
DEFAULT_PORT = 5555

module.exports = class SomataBinding extends EventEmitter

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

        log "Socket #{ @id } bound to #{ @address }..."

    send: (client_id, message) ->
        @socket.send [ client_id, JSON.stringify message ]

    handleMessage: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message }" if VERBOSE
        @emit message.kind, client_id, message

