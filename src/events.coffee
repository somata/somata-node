{EventEmitter} = require 'events'
events = require './events'
async = require 'async'

exit = new EventEmitter
exiters = []
exit.onExit = (cb) ->
    exiters.push cb

exitWrapped = ->
    async.map exiters, (_cb, cb) ->
        _cb cb
    , process.exit

exit.on 'exit', exitWrapped

process.on 'SIGINT', ->
    exit.emit 'exit'

process.on 'SIGTERM', ->
    exit.emit 'exit'

module.exports = {
    exit
}
