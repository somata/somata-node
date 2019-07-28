fs = require 'fs'
express = require 'express'
express_ws = require 'express-ws'
uuid = require 'uuid'
debug = require('debug')('somata:service')
{reverse, errorToObj} = require './helpers'

try
    config = require.main.require './somata.json'
catch
    config = {}

PORT = process.env.SOMATA_PORT or config.port or 8000

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

    onSubscribe: (id, event, args, sendEvent) ->
        @subscriptions[event] ||= []
        @subscriptions[event].push {id, sendEvent}

    onUnsubscribe: (event, args, sendEvent) ->
        @subscriptions[event] = @subscriptions[event].filter (subscribed) ->
            subscribed.sendEvent != sendEvent

    publish: (event, args...) ->
        if @subscriptions[event]?.length
            for {id, sendEvent} in @subscriptions[event]
                event_message = {id, event, args}
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
            res.json {response}

        catch err
            res.status 500
            res.json {error: err}

    onWsRequest: (ws, message) ->
        {method, args} = message
        try
            response = await @onMethod method, args
            response_json = JSON.stringify {response, id: message.id}
            ws.send response_json
        catch err
            if err instanceof Error
                error_json = {error: errorToObj(err), id: message.id}
            else
                error_json = {error: err, id: message.id}
            ws.send JSON.stringify error_json

    onMethod: (method, args) ->
        debug '[onMethod]', method, args
        @methods[method](args...)

