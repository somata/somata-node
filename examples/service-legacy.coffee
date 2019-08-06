somata = require '../src'

sayHello = (name, cb) ->
    cb null, "Hello #{name}"

service = new somata.Service 'examples:hello', somata.helpers.toPromises {
    sayHello
}

