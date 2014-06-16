BargeService = require '../barge-service'

# Create a new Barge service named 'hello' listening on localhost:5555
hello_service = new BargeService
    name: 'hello'
    host: 'localhost'
    port: 5555

# Define a method which takes a callback to send data to the client
hello_service.methods.sayHello = (name, cb) ->
    cb null, 'Hello, ' + name + '!'

# Register with the registry
hello_service.register()

