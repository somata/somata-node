{EventEmitter} = require 'events'
helpers = require './helpers'
{log} = helpers

VERBOSE = parseInt process.env.SOMATA_VERBOSE || 0

class Subscription extends EventEmitter
    constructor: (options={}) ->
        super()
        Object.assign @, options
        @id ||= @type + '~' + helpers.randomString()

        @handleEvent = @_handleEvent.bind(@)

    _handleEvent: (message) ->
        log.d '[Subscription.handleEvent]', arguments if VERBOSE > 2
        @emit @type, message

    subscribe: (connection) ->
        @connection = connection
        log.i "[Subscription.subscribe] #{@id} <#{@connection.id}>"
        @connection.sendSubscribe @id, @service, @type, @args, @handleEvent

        @resubscribe = @_resubscribe.bind(@)
        @connection.on 'reconnect', @resubscribe

    _resubscribe: ->
        log.i "[Subscription.resubscribe] #{@id} <#{@connection.id}>" if VERBOSE
        @connection.sendSubscribe @id, @service, @type, @args, @handleEvent

    unsubscribe: ->
        log.w "[Subscription.unsubscribe] <#{@connection.id}> #{@id}" if VERBOSE
        delete @connection.pending_responses[@id]
        @connection.removeListener 'reconnect', @resubscribe
        @connection.sendUnsubscribe @id, @type

module.exports = Subscription
