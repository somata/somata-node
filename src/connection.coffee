zmq = require 'zmq'
util = require 'util'
_ = require 'underscore'
{EventEmitter} = require 'events'
helpers = require './helpers'
{log} = helpers

VERBOSE = parseInt process.env.SOMATA_VERBOSE || 0
DEFAULT_PROTO = process.env.SOMATA_PROTO || 'tcp'
DEFAULT_CONNECT = process.env.SOMATA_CONNECT || process.env.SOMATA_REGISTRY_HOST || '127.0.0.1'
PING_INTERVAL = parseInt(process.env.SOMATA_PING_INTERVAL) || 2000

module.exports = class Connection extends EventEmitter

    # Store pending response callbacks
    # --------------------------------------------------------------------------
    #
    # If a message from the connected-to service corresponds to a response
    # callback in this object, the stored callback will be called with that
    # message as its argument.

    pending_responses: {}
    subscriptions: {}

    # Create a new Somata connection
    # --------------------------------------------------------------------------
    #
    # Accepts an optional `id`, or generates one if none is supplied.
    #
    # Creates a socket address by combining the optional supplied `proto`,
    # `host`, and `port`, and connects to that address.

    constructor: (options={}) ->
        Object.assign @, options

        @id ||= helpers.randomString()

        @proto ||= DEFAULT_PROTO
        @host ||= DEFAULT_CONNECT

        # TODO: Host overwrite no longer necessary with bridges(?)
        if @host == '0.0.0.0'
            @host = DEFAULT_CONNECT

        @address = helpers.makeAddress @proto, @host, @port

        @connect()

    # Create and connect the connection socket
    # --------------------------------------------------------------------------
    #
    # Messages sent to the connected socket are handled with `handleMessage`.

    connect: ->
        @socket = zmq.socket 'dealer'
        @socket.identity = @id
        @socket.connect @address
        @socket.on 'message', (message_json) =>
            @handleMessage JSON.parse message_json

        log.i "[Connection.connect] #{helpers.summarizeConnection(@)} connected to #{@address}..." if VERBOSE

        @connected()

    connected: ->
        @on 'method', @handleMethod.bind(@)
        @on 'subscribe', @handleSubscribe.bind(@)
        @sendPing()

    # Incoming messages (from a connected-to Binding)
    # --------------------------------------------------------------------------

    handleMessage: (message) ->
        log.d "[Connection.handleMessage] #{helpers.summarizeConnection(@)} #{helpers.summarizeMessage(message)}" if VERBOSE > 1

        if on_response = @pending_responses[message.id]

            # Clear timeout if it exists
            if on_response.timeout?
                clearTimeout on_response.timeout

            if on_response.once
                delete @pending_responses[message.id]

            on_response(message)

        else if message.kind?
            @emit message.kind, message

        else
            log.w '[handleMessage] No pending response for ' + message.id if VERBOSE
            log.w '[handleMessage] No pending response for', message

    handleMethod: (message) ->
        log.d "[Connection.on method]", message if VERBOSE
        if method = @methods?[message.method]
            response = method message.args..., (err, response) =>
                @send {id: message.id, kind: 'response', response}
        else
            @send {id: message.id, kind: 'error', error: "Unknown method"}

    handleSubscribe: (subscription) ->
        log.d '[Connection.on subscribe]', subscription if VERBOSE
        log.d '[Connection.on subscribe]', subscription
        @subscriptions[subscription.type] ||= {}
        @subscriptions[subscription.type][subscription.id] = subscription

    handleUnsubscribe: (unsubscription) ->
        # TODO

    # Outgoing messages
    # --------------------------------------------------------------------------

    send: (message, cb) ->
        message.id ||= helpers.randomString 16
        if cb?
            @pending_responses[message.id] = cb
        @socket.send JSON.stringify message
        return message

    method: (service, method, args..., cb) ->
        cb.once = true
        @send {
            kind: 'method'
            service, method, args
        }, (message) ->
            cb message.error, message.response, message

    subscribe: (service, type, args..., cb) ->
        @send {
            kind: 'subscribe'
            service, type, args
        }, (message) ->
            cb message.error, message.event, message

    unsubscribe: (service, id) ->
        @send {
            kind: 'unsubscribe'
            service, id
        }

    publish: (type, event) ->
        subscriptions = @subscriptions[type]
        for subscription in helpers.values subscriptions
            {id} = subscription
            @send {id, type, event}

    # Ping logic, to keep track of the connected-to binding
    # --------------------------------------------------------------------------

    last_ping: null
    last_pong: null

    sendPing: ->
        @pongTimeoutTimeout = setTimeout @pongDidTimeout.bind(@), PING_INTERVAL

        ping = if @last_ping? then 'ping' else 'hello'
        message = {id: @last_ping?.id, kind: 'ping', ping}
        @last_ping = @send message, @handlePong.bind(@)

    handlePong: (message) ->
        if @closed
            log.e '[handlePong] Closed connection'
            return

        if message.pong == 'welcome'
            log.i "[Connection.handlePong] #{helpers.summarizeConnection(@)} New ping response" if VERBOSE or true
            is_new = !@last_pong?
            @clearSubscriptions()
            @emit 'connect', is_new
            @last_pong = new Date()

        else
            log.d "[Connection.handlePong] #{helpers.summarizeConnection(@)} Continuing ping" if VERBOSE > 2

        clearTimeout @pongTimeoutTimeout
        @nextPingTimeout = setTimeout @sendPing.bind(@), PING_INTERVAL

    pongDidTimeout: ->
        log.e "[Connection.pongDidTimeout] #{helpers.summarizeConnection(@)}"
        # @nextPingTimeout = setTimeout @sendPing.bind(@), PING_INTERVAL * 2
        delete @last_ping
        @clearSubscriptions()
        @emit 'timeout'

    clearSubscriptions: ->
        for subscription_type, subscriptions of @subscriptions
            for subscription_id, subscription of subscriptions
                delete @subscriptions[subscription_type][subscription_id]
                delete @pending_responses[subscription_id]

    close: ->
        log.e "[Connection.close] #{helpers.summarizeConnection(@)}"
        clearTimeout @nextPingTimeout
        clearTimeout @pongTimeoutTimeout
        @closed = true
        @socket.close()

