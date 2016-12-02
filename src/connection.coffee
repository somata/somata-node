zmq = require 'zmq'
util = require 'util'
_ = require 'underscore'
{EventEmitter} = require 'events'
Subscription = require './subscription'
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
        @sendPing()

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

    # Handle a message from the connected-to service
    # --------------------------------------------------------------------------
    #
    # If the message ID exists in the pending responses hash, pass the stored
    # callback the message.

    handleMessage: (message) ->
        log.d "[Connection.handleMessage] #{helpers.summarizeConnection(@)} #{helpers.summarizeMessage(message)}" if VERBOSE > 1
        if on_response = @pending_responses[message.id]
            # Clear timeout if it exists
            if on_response.timeout?
                clearTimeout on_response.timeout

            # Response events: 'response' and 'error'
            if message.kind == 'response'
                on_response(null, message.response)
                delete @pending_responses[message.id]
            else if message.kind == 'error'
                on_response(message.error, null)
                delete @pending_responses[message.id]

            # Subscription events: 'event' and 'end'
            else if message.kind == 'event'
                on_response(message.event)
            else if message.kind == 'end'
                on_response(null, true)
                delete @pending_responses[message.id]

        else
            log.w '[handleMessage] No pending response for ' + message.id if VERBOSE

    # Send a message to the connected-to service
    # --------------------------------------------------------------------------
    #
    # A callback may be passed to handle a response from the service. An ID is
    # generated for and attached to the message so that the service may respond
    # with the same ID when it has a response.

    setPending: (message_id, on_response) ->

        # Optionally create timeout handler
        if @timeout_ms
            dotimeout = =>
                log.e "[TIMEOUT] Timing out request #{ message_id }"
                on_response(timeout: @timeout_ms, message: "Timed out")
                delete @pending_responses[message_id]
            on_response.timeout = setTimeout dotimeout, @timeout_ms

        # Save the response in the pending hash
        @pending_responses[message_id] = on_response

    # Constructing and sending messages
    # --------------------------------------------------------------------------

    send: (message, on_response) ->
        message.id ||= helpers.randomString 16
        message.service ||= @service_instance?.name
        if on_response?
            @setPending message.id, on_response
        @socket.send JSON.stringify message
        return message

    sendMethod: (id, method_name, args, cb) ->
        method_msg =
            id: id
            kind: 'method'
            method: method_name
            args: args
        @send method_msg, cb

    sendSubscribe: (id, service, type, args, cb) ->
        subscribe_msg =
            id: id
            kind: 'subscribe'
            service: service
            type: type
            args: args
        @send subscribe_msg, cb

    resendSubscribe: (subscription) ->
        existing_cb = @pending_responses[subscription.id]
        delete @pending_responses[subscription.id]
        subscribe_msg =
            id: subscription.id
            kind: 'subscribe'
            service: subscription.service
            type: subscription.type
            args: subscription.args
        @send subscribe_msg, existing_cb

    sendUnsubscribe: (id, type) ->
        unsubscribe_msg =
            id: id
            kind: 'unsubscribe'
            type: type
        @send unsubscribe_msg
        delete @pending_responses[id]

    # Ping logic, to keep track of the connected-to binding
    # --------------------------------------------------------------------------

    last_ping: null
    last_pong: null

    sendPing: ->
        clearTimeout @pingTimeoutTimeout
        @pingTimeoutTimeout = setTimeout @pingDidTimeout.bind(@), PING_INTERVAL

        ping = {id: @last_ping?.id, kind: 'ping'}
        @last_ping = @send ping, @handlePing

    handlePing: (err, pong) =>
        return if @closed

        if pong == 'hello'
            log.i "[Connection.handlePing] #{helpers.summarizeConnection(@)} New ping response" if VERBOSE
            if @last_pong?
                @emit 'reconnect'
            else
                @emit 'connect'
            @last_pong = new Date()

        else
            log.d "[Connection.handlePing] #{helpers.summarizeConnection(@)} Continuing ping" if VERBOSE > 1

        clearTimeout @pingTimeoutTimeout
        @nextPingTimeout = setTimeout @sendPing.bind(@), PING_INTERVAL

    pingDidTimeout: ->
        log.e "[Connection.pingDidTimeout] #{helpers.summarizeConnection(@)}"
        @nextPingTimeout = setTimeout @sendPing.bind(@), PING_INTERVAL * 2
        @emit 'timeout'

    close: ->
        clearTimeout @nextPingTimeout
        clearTimeout @pingTimeoutTimeout
        @closed = true
        @socket.close()

