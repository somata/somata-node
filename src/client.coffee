axios = require 'axios'
WS = require 'ws'
uuid = require 'uuid'
Activator = require './activator'
Subscription = require './subscription'
debug = require('debug')('somata:client')
{reverse, errorToObj, fromPromise} = require './helpers'

# TODO: Check environment variables are valid

REQUEST = process.env.SOMATA_REQUEST or 'ws'
SUBSCRIBE = process.env.SOMATA_SUBSCRIBE or 'ws'
THROW_ORIGINAL = process.env.SOMATA_THROW_ORIGINAL or false
TIMEOUT = process.env.SOMATA_TIMEOUT or 3000
DNS_SUFFIX = process.env.SOMATA_DNS_SUFFIX or ''

interpretConnectionError = (service, base_domain, err, prefix='') ->
    # Don't attempt to interpret error if using THROW_ORIGINAL passthrough
    if THROW_ORIGINAL
        throw err

    # Error response from service
    if error = err.response?.data?.error
        if typeof error == 'string'
            message = "#{prefix} #{error}"
            throw message.trim()
        else
            throw error

    # Service not found (DNS error)
    else if err.code == 'ENOTFOUND'
        message = "#{prefix} Could not resolve #{base_domain} (is the DNS suffix '#{DNS_SUFFIX}' correct?)"
        throw message.trim()

    # Connection refused (found but not mounted)
    else if err.code == 'ECONNREFUSED'
        message = "#{prefix} Could not connect to service #{service}, is it running?"
        throw message.trim()

    # Connection aborted (timeout)
    else if err.code == 'ECONNABORTED'
        message = "#{prefix} Request to service #{service} timed out"
        throw message.trim()

    # Generic HTTP error
    else if err.request? and err.response?
        throw "#{prefix} Request to #{err.config.url} failed with status #{err.response.status}: #{err.response.statusText}"
        throw message.trim()

    # Unknown error (TODO: handle more specific errors)
    else
        console.error '[err.message]', err.message
        err = errorToObj err
        if err.message?
            err.message = "#{prefix} #{err.message}".trim()
        throw err

module.exports = class Client
    constructor: (@service) ->
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

    requestCb: (method, args..., cb) ->
        fromPromise @request.bind(@, method, args...), cb

    # Currently only Websocket subscriptions are supported

    subscribe: (event, args...) ->
        if SUBSCRIBE == 'ws'
            @wsSubscribe event, args...
        else
            console.error "Can't subscribe with #{SUBSCRIBE}"

    # HTTP requests
    # ------------------------------------------------------------------------------

    postRequest: (method, args...) ->
        url = @requestUrl(method)
        id = uuid()
        message = {id, method, args}
        config = {timeout: TIMEOUT}
        debug '[postRequest]', @service, message

        try
            response = await axios.post url, message, config
            return response.data.data
        catch err
            console.error '[wsRequest]', @service, @method, err
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
                console.error '[wsRequest]', @service, method, err
                reject err
            @ws_requests[id] = {resolve, reject}

            setTimeout =>
                delete @ws_requests[id]
                console.error '[wsRequest] Timed out', @service, method
                reject "Timed out"
            , TIMEOUT

    sendWsMessage: (message) ->
        debug '[sendWsMessage]', @service, message

        try
            await @ws_activator.isActive()
        catch err
            interpretConnectionError @service, @baseUrl(), err, "Error connecting to ws://#{@baseUrl()}:"

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
        {id, type, data} = message
        switch type
            when 'response'
                if pending_request = @ws_requests[id]
                    pending_request.resolve(data)
                else
                    debug "Warning: No pending request handler for message #{id}"
            when 'event'
                if pending_subscription = @ws_subscriptions[id]
                    pending_subscription.emit('event', data)
                else
                    debug "Warning: No subscription handler for message #{id}"
            when 'error'
                if pending_request = @ws_requests[id]
                    pending_request.reject(data)
                else
                    debug "Warning: No pending error handler for message #{id}"
            else
                console.error "Unknown message type #{type}", message

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
        debug '[onWsClose]', @service
        @ws_activator.deactivate()
