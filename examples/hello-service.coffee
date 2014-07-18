# barge = require '../src'
# barge = require '../lib'
barge = require 'barge'

# Create a new Barge service named 'hello'
hello_service = new barge.Service 'hello',

    sayHello: (name, cb) ->
        cb null, 'Hello, ' + name + '!'

    sayGoodbye: (name, cb) ->
        cb null, 'Goodbye, cruel ' + name + '!'

