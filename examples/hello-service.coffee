somata = require '../src'
# somata = require '../lib'
# somata = require 'somata'

# Create a new Somata service named 'hello'
hello_service = new somata.Service 'hello',

    sayHello: (name, cb) ->
        process.exit() if name == 'world 2'
        cb null, 'Hello, ' + name + '!'

    sayGoodbye: (name, cb) ->
        cb null, 'Goodbye, cruel ' + name + '!'

