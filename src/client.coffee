axios = require 'axios'
WS = require 'ws'
uuid = require 'uuid'
Activator = require './activator'
Subscription = require './subscription'
debug = require('debug')('somata:client')
{reverse} = require './helpers'

# TODO: Check environment variables are valid

DEFAULT_REQUEST = 'ws' # 'post'
DEFAULT_SUBSCRIBE = 'ws'
REQUEST = process.env.SOMATA_REQUEST or DEFAULT_REQUEST
SUBSCRIBE = process.env.SOMATA_SUBSCRIBE or DEFAULT_SUBSCRIBE

THROW_ORIGINAL = process.env.SOMATA_THROW_ORIGINAL or false

DEFAULT_CONFIG =
    timeout: 100

DNS_SUFFIX = process.env.SOMATA_DNS_SUFFIX or ''

interpretConnectionError = (service, base_domain, err) ->
    # Don't attempt to interpret error if using THROW_ORIGINAL passthrough
    if THROW_ORIGINAL
        throw err

    # Error response from service
    if error = err.response?.data?.error
        throw error

    # Service not found (DNS error)
    else if err.code == 'ENOTFOUND'
        throw "Could not resolve #{base_domain} (is the DNS suffix '#{DNS_SUFFIX}' correct?)"

    # Connection refused (found but not mounted)
    else if err.code == 'ECONNREFUSED'
        throw "Could not connect to service #{service}, is it running?"

    # Connection aborted (timeout)
    else if err.code == 'ECONNABORTED'
        throw "Request to service #{service} timed out"

    # Generic HTTP error
    else if err.request? and err.response?
        throw "Request to #{err.config.url} failed with status #{err.response.status}: #{err.response.statusText}"

    # Unknown error (TODO: handle more specific errors)
    else
        console.log '[err.message]', err.message
        throw err

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

    # Generic requests and subscriptions
    # --------------------------------------------------------------------------

    # Depending on the SOMATA_REQUEST environment variable, a request will use
    # either a HTTP POST or Websocket

    request: (method, args...) ->
        if REQUEST == 'post'
            @postRequest method, args...
        else if REQUEST == 'ws'
            @wsRequest method, args...

    # Currently only Websocket subscriptions are supported

    subscribe: (event, args...) ->
        if SUBSCRIBE == 'ws'
            @wsSubscribe event, args...

    # HTTP requests
    # ------------------------------------------------------------------------------

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
            interpretConnectionError @service, @baseUrl(), err

    # Websocket requests and subscriptions
    # --------------------------------------------------------------------------
    # TODO: Purge completed and expired requests
    # TODO: Purge and error-out (and re-send?) requests after a disconnect
    # TODO: Subscriptions

    # To implement request/reply logic with websocket messages, we keep track of
    # @ws_requests which maps each request message ID to a Promise. A response
    # with a matching message ID will resolve that promise.

    wsRequest: (method, args...) ->
        id = uuid()

        return new Promise (resolve, reject) =>
            try
                await @sendWsMessage {id, method, args}
            catch err
                reject err
            @ws_requests[id] = [resolve, reject]

    sendWsMessage: (message) ->
        debug '[sendWsMessage]', message

        try
            await @ws_activator.isActive()
        catch err
            interpretConnectionError @service, @baseUrl(), err

        message_json = JSON.stringify message
        @ws.send message_json

    # For subscriptions, similar to requests, we keep track of @ws_subscriptions
    # mapping each subscription ID to a Promise.

    wsSubscribe: (event, args...) ->
        id = uuid()
        await @sendWsMessage {id, event, args}

        subscription = new Subscription
        @ws_subscriptions[id] = subscription
        return subscription

    # Depending if the incoming message is a response or an event it will
    # either call the response promise or the emit on the subscription.

    onWsMessage: (message_json) =>
        message = JSON.parse message_json
        {id, response, event} = message
        if response
            if pending_request = @ws_requests[id]
                pending_request(message.response)
            else
                debug "Warning: No pending request for message #{id}"
        else if event
            if pending_subscription = @ws_subscriptions[id]
                pending_subscription.emit('event', message.args...)
            else
                debug "Warning: No pending subscription for message #{id}"
        else
            console.log '[Unknown message]', message

    # Websocket helper methods
    # --------------------------------------------------------------------------

    activateWs: ->
        @ws_requests = {}
        @ws_subscriptions = {}
        @ws = new WS @websocketUrl()
        @ws.on 'message', @onWsMessage
        @ws.on 'close', @onWsClose
        new Promise (resolve, reject) =>
            @ws.on 'open', ->
                resolve true
            @ws.on 'error', (err) ->
                reject err

    onWsClose: =>
        debug '[onWsClose]'
        @ws_activator.deactivate()
