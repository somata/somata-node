express = require 'express'
express_ws = require 'express-ws'
uuid = require 'uuid'
debug = require('debug')('somata:service')
{reverse} = require './helpers'

PORT = process.env.SOMATA_PORT or 8000

module.exports = class Service
    constructor: (@service, @methods) ->
        if @service.match ':'
            debug "Warning: Deprecated service identifier: '#{@service}'"
            @service = reverse(@service.split(':')).join('.')
            debug "Service identifier updated to '#{@service}'"

        app = express()
        express_ws(app)

        app.use express.json {
            limit: '7MB'#, verify: rawBodySaver
        }

        app.post '/:method.json', @handlePostRequest.bind(@)

        app.ws '/ws', (ws, req) =>
            ws.on 'message', (message_json) =>
                message = JSON.parse message_json
                if message.method?
                    @handleWsRequest ws, message

        app.listen PORT, ->
            debug "Listening on :#{PORT}"

    handlePostRequest: (req, res) ->
        {method} = req.params
        {args} = req.body

        try
            response = await @handleMethod method, args
            debug '[response]', response
            res.status 200
            res.json {response}

        catch err
            res.status 500
            res.json {error: err}

    handleWsRequest: (ws, message) ->
        {method, args} = message
        # TODO: try/catch
        response = await @handleMethod method, args
        response_json = JSON.stringify {response, id: message.id}
        ws.send response_json

    handleMethod: (method, args) ->
        @methods[method](args)

