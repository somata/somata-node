barge = require 'barge'

client = new barge.Client

until1000 = (cb) ->
    client.remote 'inc', 'inc', (err, n) ->
        if n >= 1000
            console.log "Done."
            cb()
        else
            until1000 cb

until0 = (cb) ->
    client.remote 'inc', 'dec', (err, n) ->
        if n <= 0
            console.log "Done."
            cb()
        else
            until0 cb

until1000 ->
    console.log "Got to 1000"
    until0 ->
        console.log "Got to 0"
        process.exit()
