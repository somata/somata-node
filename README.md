Barge
=====

Node.js micro-service &amp; service-registry framework; inspired by Seaport and ZeroRPC

Barge lets you quickly compose networked distributed systems from a collection of services. Services register their network location with the Barge registry, clients query for available services and connect to use their methods from afar.

### Simple example

Define a service:

```coffee
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
```

Define a client:

```coffee
BargeClient = require '../barge-client'

# Create a new Barge client ...
hello_client = new BargeClient

    # ... connected to the registry at localhost:8555
    registry:

        host: 'localhost'
        port: 8885

# Execute the 'hello' service's `sayHello` method with the argument 'world' ...
hello_client.remote 'hello', 'sayHello', 'world', (err, hello_response) ->

    # ... then execute hello.sayGoodbye('world')
    hello_client.remote 'hello', 'sayGoodbye', 'world', (err, goodbye_response) ->

        # ... then print the responses and leave
        console.log '[hello.sayHello] response: ' + hello_response
        console.log '[hello.sayGoodbye] response: ' + goodbye_response
        process.exit()
```

Start the registry and service, then run the client:

```sh
$ coffee barge-registry.coffee --port 8885 &
Barge registry listening on localhost:8885...

$ coffee hello-service.coffee &
Barge service listening on localhost:5555...

$ coffee hello-client.coffee
[hello.sayHello] response: Hello, world!
```

