zmq = require 'zmq'
util = require 'util'
_ = require 'underscore'
{EventEmitter} = require 'events'
{log, randomString} = require './helpers'

VERBOSE =         process.env.SOMATA_VERBOSE || false
DEFAULT_PROTO =   process.env.SOMATA_PROTO   || 'tcp'
DEFAULT_CONNECT = process.env.SOMATA_CONNECT || '127.0.0.1'

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
        log.d '[Connection.constructor]', options if VERBOSE
        _.extend @, options

        @id ||= randomString()

        @proto ||= DEFAULT_PROTO
        @host ||= DEFAULT_CONNECT
        #@address = @proto + '://' + @host + ':' + @port
        @address = @proto + '://' + @host
        @address += ':' + @port if @proto != 'ipc'

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

        log "Socket #{ @id } connected to #{ @address }..." if VERBOSE

    # Handle a message from the connected-to service
    # --------------------------------------------------------------------------
    #
    # If the message ID exists in the pending responses hash, pass the stored
    # callback the message.

    handleMessage: (message) ->
        log "[connection.handleMessage] #{ util.inspect(message).slice(0,100).replace(/\s+/g, ' ') }" if VERBOSE
        if on_response = @pending_responses[message.id]
            if on_response.timeout?
                clearTimeout on_response.timeout
            if message.kind == 'response'
                on_response(null, message.response)
                delete @pending_responses[message.id]
            else if message.kind == 'error'
                on_response(message.error, null)
                delete @pending_responses[message.id]
            else if message.kind == 'event'
                on_response(null, message.event)
            else if message.kind == 'end'
                on_response(null, null, true)
                delete @pending_responses[message.id]
        else
            log.w '[handleMessage] No pending response for ' + message.id, @pending_responses

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

    send: (message, on_response) ->
        message.id ||= randomString 16
        if on_response?
            @setPending message.id, on_response
        @socket.send JSON.stringify message
        return message

    sendMethod: (id, method, args, cb) ->
        method_msg =
            id: id
            kind: 'method'
            method: method
            args: args
        @send method_msg, cb

    sendSubscribe: (id, type, args, cb) ->
        subscribe_msg =
            id: id
            kind: 'subscribe'
            type: type
            args: args
        @send subscribe_msg, cb

    sendUnsubscribe: (id, type) ->
        unsubscribe_msg =
            id: id
            kind: 'unsubscribe'
            type: type
        @send unsubscribe_msg
        delete @pending_responses[id]

    close: -> @socket.close()

# Class methods

Connection.fromConsulService = (instance, options={}) ->
    instance_tags = _.object instance.Service.Tags?.map (t) -> t.split(':')
    proto = instance_tags.proto || DEFAULT_PROTO
    host = instance_tags.host || instance.Node.Address
    port = instance.Service.Port
    return new Connection _.extend options, {proto, host, port}

