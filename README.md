Somata
=====

Node.js micro-service orchestration framework; inspired by Seaport and ZeroRPC

Somata lets you quickly compose networked distributed systems from a collection of services. Services register their network location with the Somata registry, clients query for available services and connect to use their methods from afar.

# Usage

Define a service with `new somata.Service(name, options)`:

```coffee
somata = require 'somata'

# Create a new Somata service named 'hello'
hello_service = new somata.Service 'hello', methods:

    # With a few methods

    sayHello: (name, cb) ->
        cb null, 'Hello, ' + name + '!'

    sayGoodbye: (name, cb) ->
        cb null, 'Goodbye, cruel ' + name + '!'
```

Define a client with `new somata.Client(options)`:

```coffee
somata = require 'somata'

# Create a new Somata client
hello_client = new somata.Client

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
$ somata-registry &
Somata registry listening on localhost:9010...

$ coffee hello-service.coffee &
Somata service listening on localhost:15555...

$ coffee hello-client.coffee
Found service hello@localhost:15555
[hello.sayHello] response: Hello, world!
```

# Installation

To get the somata library, with [npm](http://npmjs.org) do:

```sh
$ npm install somata
```

To get the `somata-registry` command, do:

```sh
$ npm install -g somata
```

