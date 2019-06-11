EventEmitter = require 'events'
debug = require('debug')('somata.activator')

# Activator
# An object that can be used to wait for some function to complete
# ------------------------------------------------------------------------------
# 
# Params:
# * activate: () -> Promise
#   The function that will be called to begin the activation process, which
#   should return a Promise that will resolve when activation is done.
#
# Methods:
# * isActive: () -> Promise
#   Begins activation and blocks until activated, or if already activated
#   passes straight through.

module.exports = class Activator
    constructor: (@activate) ->
        @emitter = new EventEmitter

        @is_activating = false
        @is_activated = false

    startActivation: ->
        debug '[startActivation]'
        @is_activating = true
        try
            await @activate()
            @onActivated()
        catch err
            @emitter.emit 'error', err

    onActivated: ->
        debug '[onActivated]'
        @emitter.emit 'active'
        @is_activated = true

    activePromise: ->
        new Promise (resolve, reject) =>
            @emitter.on 'active', resolve
            @emitter.on 'error', reject

    # Returns a promise that "blocks" until activated, starting activation if 
    # not already in progress, or continue right through if already activated
    isActive: ->
        if not @is_activated
            if not @is_activating
                @startActivation()
            await @activePromise()

