zmq = require 'zmq'
util = require 'util'
{EventEmitter} = require 'events'
helpers = require './helpers'
{log} = helpers

VERBOSE =       process.env.SOMATA_VERBOSE || false
DEFAULT_PROTO = process.env.SOMATA_PROTO   || 'tcp'
DEFAULT_HOST =  process.env.SOMATA_HOST    || '127.0.0.1'

module.exports = class Binding extends EventEmitter

    constructor: (options={}) ->
        log.d '[Binding.constructor]', options if VERBOSE

        @id = helpers.randomString()
        @proto = options.proto || DEFAULT_PROTO
        @host = options.host || DEFAULT_HOST
        @port = options.port || helpers.randomPort() if @proto != 'ipc'
        @should_retry = !options.port? # Retry with random ports if not specified

        @tryBinding()

    didBind: ->
        # Announce binding
        log.i "[didBind] Socket #{@id} bound to #{@address}..." if VERBOSE
        process.nextTick => @emit 'bind'

        # Start handling messages
        @socket.on 'message', (client_id, message_json) =>
            @handleMessage client_id.toString(), JSON.parse message_json

        # Handling pings
        @on 'ping', @handlePing.bind(@)
        @on 'subscribe', @handleSubscribe.bind(@)
        @on 'unsubscribe', @handleUnsubscribe.bind(@)

    handlePing: (client_id, ping) ->
        if @known_pings[ping.id]
            response = 'pong'
        else
            @known_pings[ping.id] = true
            response = 'hello'

        @send client_id, {
            id: ping.id
            kind: 'response'
            response
        }

    handleSubscribe: (client_id, subscription) ->
        log.d '[Binding.on subscribe]', client_id, subscription
        subscription.client_id = client_id
        @subscriptions[subscription.type] ||= {}
        @subscriptions[subscription.type][subscription.id] = subscription

    handleUnsubscribe: (client_id, unsubscription) ->
        log.d '[Binding.on unsubscribe]', client_id, unsubscription
        delete @subscriptions[unsubscription.type]?[unsubscription.id]

    tryBinding: (n_retried=0) ->
        try
            @address = helpers.makeAddress @proto, @host, @port
            log.d "[tryBinding] Attempting to bind on #{@address}..." if VERBOSE
            @socket = zmq.socket 'router'
            @socket.bindSync @address
            @didBind()

        catch err
            log.e "[tryBinding] Failed to bind on #{@address}", err

            if !@should_retry
                process.exit()

            else if n_retried < 5
                log.w "[tryBinding] Retrying..."
                @port = helpers.randomPort()
                setTimeout =>
                    @tryBinding(n_retried+1)
                , 1000

            else
                log.e "[tryBinding] Retried too many times."
                process.exit()

    send: (client_id, message) ->
        @socket.send [client_id, JSON.stringify message]

    handleMessage: (client_id, message) ->
        log.d "[binding.handleMessage] <#{client_id}> #{helpers.summarizeMessage message}" if VERBOSE > 1
        @emit message.kind, client_id, message

    subscriptions: {}

    known_pings: {}

# setInterval ->
#     for subscription_type in Object.keys(subscriptions)
#         for subscription_id in Object.keys(subscriptions[subscription_type])
#             subscription = subscriptions[subscription_type][subscription_id]
#             b.send subscription.client_id, {
#                 id: subscription_id
#                 kind: 'event'
#                 event: {test: true}
#             }
# , 2000
