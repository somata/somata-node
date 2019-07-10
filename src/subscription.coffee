EventEmitter = require 'events'
debug = require('debug')('somata:subscription')

module.exports = class Subscription
    constructor: ->
        @emitter = new EventEmitter

    on: ->
        @emitter.on(arguments...)

    emit: ->
        @emitter.emit(arguments...)
