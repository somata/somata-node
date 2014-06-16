barge
=====

Node.js micro-service &amp; service-registry framework; inspired by Seaport and ZeroRPC

Barge lets you quickly compose networked distributed systems from a collection of services. Services register their network location with the Barge registry, clients query for available services and connect to use their methods from afar.

### Simple example

Define a service:

```js
BargeService = require '../barge-service'

# Create a new Barge service named 'hello' listening on localhost:5555
hello_service = new BargeService
    name: 'hello'
    host: 'localhost'
    port: 5555

# Define a method which takes a callback to send data to the client
hello_service.sayHello = (name, cb) ->
    cb null, 'Hello, ' + name + '!'

# Register with the registry
hello_service.register()
```

Define a client:

```js
BargeClient = require '../barge-client'

# Create a new Barge client
hello_client = new BargeClient

# Execute the 'hello' service's `sayHello` method with the argument 'world'
hello_client.remote 'hello', 'sayHello', 'world', (err, response) ->
    console.log '[hello.sayHello] response: ' + response
```

Start the registry and service, then run the client:

```sh
> coffee barge-registry.coffee &
Barge registry listening on localhost:9910...

> coffee hello-service.coffee &
Barge service listening on localhost:5555...

> coffee hello-client.coffee
[hello.sayHello] response: Hello, world!
```
