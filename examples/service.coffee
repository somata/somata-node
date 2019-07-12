somata = require '../src'

sayHello = (name) ->
    throw "No good"
    # return "Hello #{name}"

service = new somata.Service 'examples:hello', {
    sayHello
}

shout_n = 0

shout = ->
    shout_n += 1
    service.publish 'shout', shout_n

setInterval shout, 500

