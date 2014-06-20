barge = require 'barge'

# Create a new Barge service named 'hello'
hello_service = new barge.Service 'hello', methods:

    sayHello: (name, cb) ->
        cb null, 'Hello, ' + name + '!'

    sayGoodbye: (name, cb) ->
        cb null, 'Goodbye, cruel ' + name + '!'

