BargeService = require '../barge-service'

# Create a new Barge service ...
hello_service = new BargeService

    # ... named 'hello'...
    name: 'hello'

    # ... listening at localhost:5555 ...
    binding:

        host: 'localhost'
        port: 5555

    # ... connected to the registry at localhost:8555 ...
    registry:

        host: 'localhost'
        port: 8885

    # ... with these methods.
    methods:

        sayHello: (name, cb) ->
            cb null, 'Hello, ' + name + '!'

        sayGoodbye: (name, cb) ->
            cb null, 'Goodbye, cruel ' + name + '!'

