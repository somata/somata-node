barge = require '../src'
# barge = require '../lib'
# barge = require 'barge'
log = barge.helpers.log

client = new barge.Client

until1000 = (cb) ->
    client.remote 'inc', 'inc', (err, n) ->
        if n >= 1000
            cb()
        else
            until1000 cb

until0 = (cb) ->
    client.remote 'inc', 'dec', (err, n) ->
        if n <= 0
            cb()
        else
            until0 cb

until1000 ->
    log.s "Got to 1000"
    until0 ->
        log.s "Got to 0"
        process.exit()

