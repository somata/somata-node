axios = require 'axios'
WS = require 'ws'
uuid = require 'uuid'
Activator = require './activator'
debug = require('debug')('somata:client')
{reverse} = require './helpers'

# TODO: Check environment variables are valid

DEFAULT_REQUEST = 'ws' # 'post'
REQUEST = process.env.SOMATA_REQUEST or DEFAULT_REQUEST

DEFAULT_CONFIG =
    timeout: 100

DNS_SUFFIX = process.env.SOMATA_DNS_SUFFIX or ''

module.exports = class Client
    constructor: (@service, @config=DEFAULT_CONFIG) ->
        if @service.match ':'
            deprecated_service = @service
            @service = reverse(@service.split(':')).join('.')
            debug "Warning: Deprecated service identifier #{deprecated_service} updated to #{@service}"
        @ws_activator = new Activator @activateWs.bind(@)

    baseUrl: ->
        if DNS_SUFFIX?.length
            [@service, DNS_SUFFIX].join '.'
        else
            @service

    requestUrl: (method) ->
        "http://#{@baseUrl()}/#{method}.json"

    websocketUrl: ->
        "ws://#{@baseUrl()}/ws"

    # Requests
    # --------------------------------------------------------------------------

    # Depending on the SOMATA_REQUEST environment variable, a request will use
    # either a HTTP POST or Websocket

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
    # TODO: Purge completed and expired requests
    # TODO: Purge and error-out (and re-send?) requests after a disconnect
    # TODO: Subscriptions

    # To implement request/reply logic with websocket messages, we keep track of
    # @ws_requests which maps each request message ID to a Promise. A response
    # with a matching message ID will resolve that promise.

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
        @ws.on 'message', @onWsMessage
        @ws.on 'close', @onWsClose
        new Promise (resolve, reject) =>
            @ws.on 'open', ->
                resolve true
            @ws.on 'error', (err) ->
                reject err

    handleWsMessage: (message_json) =>
        message = JSON.parse message_json
        {id} = message
        @ws_requests[id](message.response)
    onWsClose: =>
        debug '[onWsClose]'
        @ws_activator.deactivate()
