zmq = require 'zmq'
util = require 'util'
{EventEmitter} = require 'events'
{randomPort, randomString, log} = require './helpers'

VERBOSE = false
DEFAULT_PROTO = 'tcp'
DEFAULT_BIND = process.env.SOMATA_BIND || '0.0.0.0'

module.exports = class Binding extends EventEmitter

    constructor: (options={}) ->
        @id = @id || randomString()

        @proto = options.proto || DEFAULT_PROTO
        @host = DEFAULT_BIND
        @port = options.port
        @address = @proto + '://' + @host + ':' + @port

        throw new Error("No port specified") if !@port

        @socket = zmq.socket 'router'
        @tryBinding()
        @socket.on 'message', (client_id, message_json) =>
            @handleMessage client_id.toString(), JSON.parse message_json

        log "Socket #{ @id } bound to #{ @address }..."

    tryBinding: (onBound) ->
        try
            @socket.bindSync @address
        catch err
            log.e err
            process.exit()

    send: (client_id, message) ->
        @socket.send [ client_id, JSON.stringify message ]

    handleMessage: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message }" if VERBOSE
        @emit message.kind, client_id, message

