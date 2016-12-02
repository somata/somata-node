{EventEmitter} = require 'events'
helpers = require './helpers'
{log} = helpers

VERBOSE = parseInt process.env.SOMATA_VERBOSE || 0

class Subscription extends EventEmitter
    constructor: (options={}) ->
        Object.assign @, options
        @id ||= @type + '~' + helpers.randomString()

    subscribe: (connection, options={}) ->
        @connection = connection
        log.i "[Subscription.subscribe] #{@id} <#{@connection.id}>"
        @connection.sendSubscribe @id, @type, @args, @cb

        @resubscribe = @_resubscribe.bind(@)

        if options.keepalive
            @connection.on 'reconnect', @resubscribe

    _resubscribe: ->
        log.i "[Subscription.resubscribe] #{@id} <#{@connection.id}>"
        @connection.sendSubscribe @id, @type, @args, @cb

    unsubscribe: ->
        log.w "[Subscription.unsubscribe] <#{@connection.id}> #{@id}"
        delete @connection.pending_responses[@id]
        @connection.removeListener 'reconnect', @resubscribe
        @connection.sendUnsubscribe @id, @type

module.exports = Subscription
