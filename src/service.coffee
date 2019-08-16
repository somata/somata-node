express = require 'express'
express_ws = require 'express-ws'
uuid = require 'uuid'
debug = require('debug')('somata:service')
{reverse, errorToObj} = require './helpers'

PORT = process.env.SOMATA_PORT or 8000

module.exports = class Service
    constructor: (@service, @methods) ->
        if @service.match ':'
            deprecated_service = @service
            @service = reverse(@service.split(':')).join('.')
            debug "Warning: Deprecated service identifier #{deprecated_service} updated to #{@service}"

        @subscriptions = {}

        app = express()
        express_ws(app)

        app.use express.json {
            limit: '7MB'#, verify: rawBodySaver
        }

        app.post '/:method.json', @onPostRequest.bind(@)

        app.ws '/ws', (ws, req) =>
            ws.on 'message', (message_json) =>
                message = JSON.parse message_json
                if message.method?
                    @onWsRequest ws, message
                else if message.event?
                    @onWsSubscribe ws, message

        app.listen PORT, ->
            debug "Listening on :#{PORT}"

    # Handing subscriptions
    # --------------------------------------------------------------------------

    # Subscriptions (currently ond only by websockets) are stored in
    # @subscriptions as event -> [{id, sendEvent}]. When an event is published
    # all clients who were subscribed are sent the event.

    onWsSubscribe: (ws, message) ->
        debug '[onWsSubscribe]', message
        {id, event, args} = message
        # TODO: try/catch
        sendEvent = (event_message) ->
            debug '[sendEvent]', event_message
            event_message_json = JSON.stringify event_message
            ws.send event_message_json
        @onSubscribe id, event, args, sendEvent
        ws.on 'close', @onUnsubscribe.bind @, event, args, sendEvent

    # TODO: Take args into consideration
    onSubscribe: (id, event, args, sendEvent) ->
        @subscriptions[event] ||= []
        @subscriptions[event].push {id, sendEvent}

    onUnsubscribe: (event, args, sendEvent) ->
        @subscriptions[event] = @subscriptions[event].filter (subscribed) ->
            subscribed.sendEvent != sendEvent

    publish: (event, data) ->
        if @subscriptions[event]?.length
            for {id, sendEvent} in @subscriptions[event]
                event_message = {id, type: 'event', event, data}
                sendEvent event_message

    # Handling requests
    # --------------------------------------------------------------------------

    onPostRequest: (req, res) ->
        {method} = req.params
        {args} = req.body
        debug '[request]', method, args

        try
            response = await @onMethod method, args
            debug '[response]', response
            res.status 200
            res.json {type: 'response', data: response}

        catch err
            console.error '[onPostRequest Error]', method, err
            res.status 500
            if err instanceof Error
                err = errorToObj err
            res.json {type: 'error', data: err}

    onWsRequest: (ws, message) ->
        {method, args} = message

        try
            response = await @onMethod method, args
            debug '[response]', response
            response_json = JSON.stringify {id: message.id, type: 'response', data: response}
            ws.send response_json

        catch err
            console.error '[onWsRequest Error]', method, err
            if err instanceof Error
                err = errorToObj err
            error_json = {id: message.id, type: 'error', data: err}
            ws.send JSON.stringify error_json

    onMethod: (method, args=[]) ->
        debug '[onMethod]', method, args
        @methods[method](args...)

