Somata
=====

Micro-service orchestration framework built on [ZeroMQ](http://zeromq.org) and [Consul](http://www.consul.io).

# Usage

Define a service with `new somata.Service(name, methods, [options])`:

```coffee
somata = require 'somata'

# Create a new Somata service named 'hello'
hello_service = new somata.Service 'hello',

    # With a few methods

    sayHello: (name, cb) ->
        cb null, 'Hello, ' + name + '!'

    sayGoodbye: (name, cb) ->
        cb null, 'Goodbye, cruel ' + name + '!'
```

Define a client with `new somata.Client([options])`:

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

Start the service, then run the client:

```sh
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

To install Consul, read [their installation instructions](http://www.consul.io/intro/getting-started/install.html).
