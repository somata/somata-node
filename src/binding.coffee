zmq = require 'zmq'
util = require 'util'
{EventEmitter} = require 'events'
{randomPort, randomString, log} = require './helpers'

VERBOSE = process.env.SOMATA_VERBOSE || false
DEFAULT_PROTO = 'tcp'
DEFAULT_BIND = process.env.SOMATA_BIND || '0.0.0.0'

module.exports = class Binding extends EventEmitter

    constructor: (options={}) ->
        @id = @id || randomString()

        @proto = options.proto || DEFAULT_PROTO
        @bind = DEFAULT_BIND
        @host = options.host
        @port = options.port || randomPort()

        @tryBinding()

    didBind: ->
        # Announce binding
        log.i "[didBind] Socket #{ @id } bound to #{ @address }..."
        process.nextTick => @emit 'bind'

        # Start handling messages
        @socket.on 'message', (client_id, message_json) =>
            @handleMessage client_id.toString(), JSON.parse message_json

    makeAddress: ->
        @address = @proto + '://' + @bind + ':' + @port

    tryBinding: (n_retried=0) ->
        try
            @makeAddress()
            log.d "[tryBinding] Attempting to bind on #{ @address }..." if VERBOSE
            @socket = zmq.socket 'router'
            @socket.bindSync @address
            @didBind()
        catch err
            log.e "[tryBinding] Failed to bind on #{ @address }", err
            if n_retried < 5
                log.w "[tryBinding] Retrying..."
                @port = randomPort()
                setTimeout =>
                    @tryBinding(n_retried+1)
                , 1000
            else
                log.e "[tryBinding] Retried too many times."
                process.exit()

    send: (client_id, message) ->
        @socket.send [ client_id, JSON.stringify message ]

    handleMessage: (client_id, message) ->
        log "[binding.handleMessage] <#{ client_id }> #{ util.inspect(message).slice(0,100).replace(/\s+/g, ' ') }" if VERBOSE
        @emit message.kind, client_id, message

