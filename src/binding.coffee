zmq = require 'zmq'
util = require 'util'
{EventEmitter} = require 'events'
{randomPort, randomString, log} = require './helpers'

VERBOSE =       process.env.SOMATA_VERBOSE || false
DEFAULT_PROTO = process.env.SOMATA_PROTO   || 'tcp'
DEFAULT_HOST =  process.env.SOMATA_HOST    || '127.0.0.1'

module.exports = class Binding extends EventEmitter

    constructor: (options={}) ->
        log.d '[Binding.constructor]', options if VERBOSE
        @id = @id || randomString()

        @proto = options.proto || DEFAULT_PROTO
        @host = options.host || DEFAULT_HOST
        @port = options.port || randomPort() if @proto != 'ipc'

        @tryBinding()

    didBind: ->
        # Announce binding
        log.i "[didBind] Socket #{ @id } bound to #{ @address }..."
        process.nextTick => @emit 'bind'

        # Start handling messages
        @socket.on 'message', (client_id, message_json) =>
            @handleMessage client_id.toString(), JSON.parse message_json

    makeAddress: ->
        @address = @proto + '://' + @host
        @address += ':' + @port if @proto != 'ipc'

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
        log "[binding.handleMessage] <#{ client_id }> #{ util.inspect(message).slice(0,300).replace(/\s+/g, ' ') }" if VERBOSE
        @emit message.kind, client_id, message

