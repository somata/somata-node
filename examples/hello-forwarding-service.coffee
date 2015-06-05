somata = require '../src'

# Create a new Somata client
hello_client = new somata.Client

forward_service = new somata.Service 'hello:forward',
    sayHello: (s, cb) ->
        hello_client.remote 'hello', 'sayHello', s, cb
