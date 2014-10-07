zmq = require 'zmq'
util = require 'util'
_ = require 'underscore'
{EventEmitter} = require 'events'
{log, randomString} = require './helpers'

VERBOSE = process.env.SOMATA_VERBOSE || false
DEFAULT_PROTO = 'tcp'
DEFAULT_CONNECT = 'localhost'

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
        _.extend @, options

        @id ||= randomString()

        @proto ||= DEFAULT_PROTO
        @host ||= DEFAULT_CONNECT
        @address = @proto + '://' + @host + ':' + @port

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
        log ">: #{ util.inspect message }" if VERBOSE
        if on_response = @pending_responses[message.id]
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

    # Send a message to the connected-to service
    # --------------------------------------------------------------------------
    #
    # A callback may be passed to handle a response from the service. An ID is
    # generated for and attached to the message so that the service may respond
    # with the same ID when it has a response.

    send: (message, on_response) ->
        message.id ||= randomString 16
        @socket.send JSON.stringify message
        if on_response?
            @pending_responses[message.id] = on_response
        return message

    sendMethod: (method, args, cb) ->
        method_msg =
            kind: 'method'
            method: method
            args: args
        @send method_msg, cb

    sendSubscribe: (type, args, cb) ->
        subscribe_msg =
            kind: 'subscribe'
            type: type
            args: args
        @send subscribe_msg, cb

    sendUnsubscribe: (id, type) ->
        unsubscribe_msg =
            kind: 'unsubscribe'
            id: id
            type: type
        @send unsubscribe_msg
        delete @pending_responses[id]

    close: -> @socket.close()

# Class methods

Connection.fromConsulService = (instance) ->
    return new Connection
        host: instance.Node.Address
        port: instance.Service.Port

