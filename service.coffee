os = require 'os'
util = require 'util'
zmq = require 'zmq'
{log, randomString} = require './helpers'
_ = require 'underscore'
Barge = require './'

VERBOSE = false

randomPort = ->
    10000 + Math.floor(Math.random()*50000)

class Service

    methods: {}

    # Instatiate a Barge service
    # --------------------------------------------------------------------------

    constructor: (@name, @options={}) ->
        # Copy methods over from options
        _.extend @methods, @options.methods if @options.methods?

        # Determine service host and port
        @options.binding ||= {}
        @options.binding.host ||= os.hostname()
        @options.binding.port ||= randomPort()

        @options.registry ||= Barge.Registry.DEFAULTS

        # Bind and register
        @service_binding = new Barge.Binding @options.binding
        @bind()
        @registry_connection = new Barge.RegistryConnection @options.registry
        @register()

    # Bind the service socket
    # --------------------------------------------------------------------------

    bind: ->
        @service_binding.handleMessage = @handleClientMessage.bind(@)

    # Create a connection to the Barge registry
    # --------------------------------------------------------------------------

    register: ->
        @registry_connection.register
            name: @name
            binding: @options.binding
        @registry_connection.handleMessage = @handleRegistryMessage.bind(@)

    # Handle a message from the registry
    # --------------------------------------------------------------------------
    #
    # If the message is the `register?` command, re-register

    handleRegistryMessage: (message) =>
        log "<registry>: #{ util.inspect message, depth: null }" if VERBOSE

        if message.command == 'register?'
            @register()

    # Handle a message from a client
    # --------------------------------------------------------------------------
    # 
    # Looks for the requested method in `@methods` and executes it with the
    # arguments contained in the message

    handleClientMessage: (client_id, message) =>
        log "<#{ client_id }>: #{ util.inspect message, depth: null }" if VERBOSE

        # Find the method
        if _method = @methods[message.method]

            # Execute the method with the arguments
            log 'Executing ' + message.method if VERBOSE
            _method message.args..., (err, response) =>

                # Respond to the client
                @service_binding.send client_id,
                    id: message.id
                    type: 'response'
                    response: response

        # Method not found for this service
        else
            # TODO: Send a failure message to client
            log.i 'No method ' + message.method

module.exports = Service

