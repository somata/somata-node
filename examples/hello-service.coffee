Service = require '../service'

# Create a new Barge service named 'hello'
hello_service = new Service 'hello', methods:

    sayHello: (name, cb) ->
        cb null, 'Hello, ' + name + '!'

    sayGoodbye: (name, cb) ->
        cb null, 'Goodbye, cruel ' + name + '!'

