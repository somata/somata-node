axios = require 'axios'
WS = require 'ws'
uuid = require 'uuid'
Activator = require './activator'
debug = require('debug')('somata.client')
{reverse} = require './helpers'

DEFAULT_REQUEST = 'ws' # 'post'
REQUEST = process.env.SOMATA_REQUEST or DEFAULT_REQUEST

DEFAULT_CONFIG =
    timeout: 100

URL_SUFFIX = process.env.SOMATA_URL_SUFFIX or ''

module.exports = class Client
    constructor: (@service, @config=DEFAULT_CONFIG) ->
        if @service.match ':'
            debug "Warning: Deprecated service identifier: #{@service}"
            @service = reverse(@service.split(':')).join('.')
            debug "Service identifier updated to #{@service}"
        @ws_activator = new Activator @activateWs.bind(@)

    baseUrl: ->
        if URL_SUFFIX?.length
            [@service, URL_SUFFIX].join '.'
        else
            @service

    requestUrl: (method) ->
        "http://#{@baseUrl()}/#{method}.json"

    websocketUrl: ->
        "ws://#{@baseUrl()}/ws"

    # Requests
    # --------------------------------------------------------------------------

    request: (method, args...) ->
        if REQUEST == 'post'
            @postRequest method, args...
        else if REQUEST == 'ws'
            @wsRequest method, args...

    postRequest: (method, args...) ->
        url = @requestUrl(method)
        id = uuid()
        message = {id, method, args}
        config = {timeout: @config.timeout}
        debug '[postRequest]', message

        try
            response = await axios.post url, message, config
            return response.data.response

        # Error handling
        catch err
            # Error response from service
            if error = err.response?.data?.error
                throw error
            # Connection refused
            else if err.code == 'ECONNREFUSED'
                throw "Could not connect to #{@service}"
            # Connection aborted (timeout)
            else if err.code == 'ECONNABORTED'
                throw "Request to #{@service} timed out"
            # Unknown error (TODO: handle more specific errors)
            else
                console.error '[Unknown error]', err

    # Websocket requests and subscriptions
    # --------------------------------------------------------------------------
    # To implement request/reply logic with websocket messages, we keep track of
    # @ws_requests which maps each request message ID to a Promise. A response
    # with a matching message ID will resolve that promise.
    # 
    # TODO: Purge completed and expired requests
    # TODO: Handle disconnects
    # TODO: Subscriptions

    wsRequest: (method, args...) ->
        await @ws_activator.isActive()

        id = uuid()
        message = {id, method, args}
        debug '[wsRequest]', message
        message_json = JSON.stringify message
        @ws.send message_json

        promise = new Promise (resolve, reject) =>
            @ws_requests[id] = resolve

    activateWs: ->
        @ws_requests = {}
        @ws = new WS @websocketUrl()
        @ws.on 'message', @handleWsMessage
        new Promise (resolve, reject) =>
            @ws.on 'open', ->
                resolve true

    handleWsMessage: (message_json) =>
        message = JSON.parse message_json
        {id} = message
        @ws_requests[id](message.response)

