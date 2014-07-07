zmq = require 'zmq'
util = require 'util'
_ = require 'underscore'
{EventEmitter} = require 'events'
{log, randomString} = require './helpers'

VERBOSE = false
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

    # Create a new Barge connection
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
            on_response(null, message.response)

    # Send a message to the connected-to service
    # --------------------------------------------------------------------------
    #
    # A callback may be passed to handle a response from the service. An ID is
    # generated for and attached to the message so that the service may respond
    # with the same ID when it has a response.

    send: (message, on_response) ->
        message.id = randomString 16
        @socket.send JSON.stringify message
        if on_response?
            @pending_responses[message.id] = on_response
        return message

    invoke: (method, args..., cb) ->
        method_msg =
            kind: 'method'
            method: method
            args: args
        @send method_msg, cb

    close: ->
        @socket.close()

# Class methods

Connection.fromConsulNode = (node) ->
    return new Connection
        host: node.Address
        port: node.ServicePort

