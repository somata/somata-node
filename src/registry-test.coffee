somata = require '.'

# Test connecting to registry
# connection = new somata.Connection port: 8420
# connection.sendMethod null, 'getService', ['hello'], (err, found) ->
#     console.log 'found', err, found

# Test regular remote call
client = new somata.Client

add = (a, b) -> a + b
sum = (l) -> l.reduce add, 0
avg = (l) -> sum(l) / l.length

dts = []

sendHello = (cb) ->
    client.remote 'hello', 'sayHello', 'world', cb

sendHellos = ->
    n_hellos = 1
    n = n_hellos
    start_t = new Date().getTime()
    saidHello = (err, hello) ->
        if err?
            end_t = new Date().getTime()
            dt = (end_t-start_t)/1000
            console.log "[#{n_hellos-n}] Failed after #{dt}"
        else if n > 0
            n -= 1
            sendHello saidHello
        else
            end_t = new Date().getTime()
            dt = (end_t-start_t)/1000
            dts.push dt
            console.log "[#{n_hellos}] Done after #{dt} avg #{avg dts}"
    sendHello saidHello

setInterval sendHellos, 5000
sendHellos()
