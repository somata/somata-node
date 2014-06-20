util = require 'util'
zmq = require 'zmq'
{log, randomString, randomChoice} = require './helpers'
_ = require 'underscore'

VERBOSE = true
HEARTBEAT_INTERVAL = 5000
HEARTBEAT_TIMEOUT = HEARTBEAT_INTERVAL * 5
REGISTRATION_TIMEOUT = HEARTBEAT_INTERVAL * 5

exports.DEFAULTS = REGISTRY_DEFAULTS =
    proto: 'tcp'
    bind: '0.0.0.0'
    host: process.env.BARGE_REGISTRY_HOST || 'localhost'
    port: process.env.BARGE_REGISTRY_PORT || 9910

class BargeRegistry

    pending_registrations: {}
    registered_services: {}
    registered_clients: {}

    constructor: (options={}) ->
        options = _.defaults options, REGISTRY_DEFAULTS
        @address = options.proto + '://' + options.bind + ':' + options.port

        @socket = zmq.socket 'router'
        @socket.bindSync @address
        @socket.on 'message', (client_id, message_json) =>
            @handleMessage client_id.toString(), JSON.parse message_json

        log "Barge registry listening on #{ @address }..."

    send: (client_id, message) ->
        @socket.send [ client_id, JSON.stringify message ]

    handleMessage: (client_id, message) ->
        log "<#{ client_id }>: #{ util.inspect message }" if VERBOSE

        switch message.type

            when 'register'
                @handleRegister client_id, message

            when 'unregister'
                @handleUnregister client_id

            when 'heartbeat'
                @handleHeartbeat client_id, message

            when 'query'
                @handleQuery client_id, message

            else
                log 'Unrecognized message: ' + util.inspect message

    handleRegister: (client_id, message) ->
        service = message.args
        service.client_id = client_id
        if !@registered_clients[client_id]?
            log.i "New service registered: #{ service.name } (#{ client_id })"
        else
            log.i "Re-registering service: #{ service.name } (#{ client_id })"

        if !@registered_services[service.name]
            @registered_services[service.name] = []
        @registered_services[service.name].push service
        @registered_clients[client_id] = service
        @registered_clients[client_id].last_seen = new Date().getTime()
        if @pending_registrations[client_id]?
            delete @pending_registrations[client_id]

    handleUnregister: (client_id) ->
        if service = @registered_clients[client_id]
            @registered_services = _.without @registered_services, service
            delete @registered_clients[client_id]
            log.e "Unregistered service: #{ service.name } <#{ client_id }>"

    handleHeartbeat: (client_id, message) ->
        now = new Date().getTime()

        # Request re-registration if we haven't seen this client
        if !@registered_clients[client_id]?

            # Set a pending registration time out (so that buffered
            # heartbeats don't create a flood of registration requests)
            if !@pending_registrations[client_id]? or
                (now - @pending_registrations[client_id]) > REGISTRATION_TIMEOUT
                    @send client_id, command: 'register?'
                    @pending_registrations[client_id] = now

        # Service is already known, update its last heartbaet
        else
            @registered_clients[client_id].last_seen = now

    handleQuery: (client_id, message) ->
        service_name = message.args.service_name
        services = @registered_services[service_name]
        if services?.length
            service = randomChoice services
            log "Found service: #{ util.inspect service }", color: 'green'
            @send client_id,
                id: message.id
                service: service
        else
            log "Could not find service: #{ service_name }", color: 'yellow'
            @send client_id,
                id: message.id
                service: null

# Stand-alone mode
if require.main == module

    # Parse options from command line with minimist
    minimist = require 'minimist'
    argv = minimist process.argv.slice 2

    new BargeRegistry argv

