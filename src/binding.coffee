zmq = require 'zeromq'
util = require 'util'
{EventEmitter} = require 'events'
helpers = require './helpers'
{log} = helpers

VERBOSE =       parseInt process.env.SOMATA_VERBOSE || 0
DEFAULT_PROTO = process.env.SOMATA_PROTO   || 'tcp'
DEFAULT_HOST =  process.env.SOMATA_HOST    || '127.0.0.1'
MAX_BIND_RETRIES = 5

module.exports = class Binding extends EventEmitter

    pending_responses: {}
    subscriptions: {}
    known_pings: {}

    constructor: (options={}) ->
        super()
        Object.assign @, options

        @id ||= helpers.randomString()
        @proto ||= DEFAULT_PROTO
        @host ||= DEFAULT_HOST
        @port ||= helpers.randomPort() if @proto != 'ipc'
        @should_retry = !options.port? # Retry with random ports if not specified

        @tryBind()

    emitNext: (args...) ->
        process.nextTick => @emit args...

    # Binding
    # --------------------------------------------------------------------------

    tryBind: (n_retried=0) ->
        try
            @address = helpers.makeAddress @proto, @host, @port
            log.d "[Binding.tryBind] Attempting to bind on #{@address}..." if VERBOSE
            @socket = zmq.socket 'router'
            @socket.bindSync @address
            @didBind()

        catch err
            log.e "[Binding.tryBind] Failed to bind on #{@address}", err

            if !@should_retry
                process.exit()

            else if n_retried < MAX_BIND_RETRIES
                log.w "[Binding.tryBind] Retrying..."
                @port = helpers.randomPort()
                setTimeout =>
                    @tryBind(n_retried+1)
                , 1000

            else
                log.e "[Binding.tryBind] Retried too many times."
                process.exit()

    didBind: ->
        # Announce that it did bind
        log.i "[Binding.didBind] Socket #{@id} bound to #{@address}" if VERBOSE
        @emitNext 'bind'

        # Start handling messages
        @socket.on 'message', (client_id, message_json) =>
            @handleMessage client_id.toString(), JSON.parse message_json

        # Subscribe to default message kinds
        @on 'ping', @handlePing.bind(@)
        @on 'method', @handleMethod.bind(@)
        @on 'subscribe', @handleSubscribe.bind(@)
        @on 'unsubscribe', @handleUnsubscribe.bind(@)

    # Incoming messages (from a Connection)
    # --------------------------------------------------------------------------

    handleMessage: (client_id, message) ->
        log.d "[Binding.handleMessage] <#{client_id}> #{helpers.summarizeMessage message}" if VERBOSE > 1
        if cb = @pending_responses[client_id]?[message.id]
            cb message

        else
            @emit message.kind, client_id, message

    handlePing: (client_id, message) ->
        if message.ping == 'hello' or !@known_pings[message.id]?
            @known_pings[message.id] = true
            @emitNext 'connected', client_id
            pong = 'welcome'
        else
            pong = 'pong'

        @setPingTimeout(client_id)

        @send client_id, {
            id: message.id
            kind: 'pong'
            pong
        }

    ping_timeouts: {}

    setPingTimeout: (client_id) ->
        clearTimeout @ping_timeouts[client_id]
        pingDidTimeout = @pingDidTimeout.bind(@, client_id)
        @ping_timeouts[client_id] = setTimeout pingDidTimeout, 2500

    clearSubscriptions: (client_id) ->
        for subscription_type, subscriptions of @subscriptions
            for subscription_id, subscription of subscriptions
                if subscription.client_id == client_id
                    delete @subscriptions[subscription_type][subscription_id]
                    delete @pending_responses[client_id]?[subscription_id]

    pingDidTimeout: (client_id) ->
        @clearSubscriptions(client_id)
        delete @known_pings[client_id]
        log.w '[Binding.pingDidTimeout]', client_id if VERBOSE
        @emit 'timeout', client_id

    handleMethod: (client_id, message) ->
        log.d "[Binding.handleMethod]", message if VERBOSE
        if message.service?
            # Ignore as it was meant for a service
        else if method = @methods?[message.method]
            response = method message.args..., (err, response) =>
                @send client_id, {id: message.id, kind: 'response', response}
        else
            @send client_id, {id: message.id, kind: 'error', error: "Unknown method '#{message.method}'"}

    handleSubscribe: (client_id, subscription) ->
        log.d '[Binding.handleSubscribe]', client_id, subscription if VERBOSE
        subscription.client_id = client_id
        @subscriptions[subscription.type] ||= {}
        @subscriptions[subscription.type][subscription.id] = subscription

    handleUnsubscribe: (client_id, unsubscription) ->
        log.d '[Binding.handleUnsubscribe]', client_id, unsubscription if VERBOSE
        delete @subscriptions[unsubscription.type]?[unsubscription.id]

    # Outgoing messages
    # --------------------------------------------------------------------------

    send: (client_id, message, cb) ->
        if cb?
            message.id ||= helpers.randomString()
            @pending_responses[client_id] ||= {}
            @pending_responses[client_id][message.id] = cb
        @socket.send [client_id, JSON.stringify message]

    method: (client_id, method, args..., cb) ->
        @send client_id, {
            kind: 'method'
            method, args
        }, (message) ->
            cb message.error, message.response, message

    subscribe: (client_id, type, args..., cb) ->
        @send client_id, {
            kind: 'subscribe'
            type, args
        }, (message) ->
            cb message.error or message.event, message

    unsubscribe: (client_id, type, id, cb) ->
        @send client_id, {
            kind: 'unsubscribe'
            type, id
        }

    publish: (type, event) ->
        subscriptions = @subscriptions[type]
        for subscription in helpers.values subscriptions
            {id, client_id} = subscription
            @send client_id, {id, type, event}

