Barge
=====

Node.js micro-service &amp; service-registry framework; inspired by Seaport and ZeroRPC

Barge lets you quickly compose networked distributed systems from a collection of services. Services register their network location with the Barge registry, clients query for available services and connect to use their methods from afar.

# Usage

Define a service with `new barge.Service(name, options)`:

```coffee
barge = require 'barge'

# Create a new Barge service named 'hello'
hello_service = new barge.Service 'hello', methods:

    # With a few methods

    sayHello: (name, cb) ->
        cb null, 'Hello, ' + name + '!'

    sayGoodbye: (name, cb) ->
        cb null, 'Goodbye, cruel ' + name + '!'
```

Define a client with `new barge.Client(options)`:

```coffee
barge = require 'barge'

# Create a new Barge client
hello_client = new barge.Client

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
$ barge-registry --port 8885 &
Barge registry listening on localhost:8885...

$ coffee hello-service.coffee &
Barge service listening on localhost:5555...

$ coffee hello-client.coffee
[hello.sayHello] response: Hello, world!
```

# Installation

To get the barge library, with [npm](http://npmjs.org) do:

```sh
$ npm install barge
```

To get the barge-registry command, do:

```sh
$ npm install -g barge
```

