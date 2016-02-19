# Somata Crash Course

## Setup

### Installation

Install Node.js and CoffeeScript (`-g` is for installing global binaries):

```bash
$ sudo apt-get install nodejs npm
$ sudo ln -s /usr/bin/nodejs /usr/bin/node # An Ubuntu annoyance
$ sudo npm install -g coffee-script
```

Test that CoffeeScript is working. You can learn more about CoffeeScript syntax from the many examples at http://coffeescript.org/

```bash
$ coffee
coffee> test = 21
21
coffee> double = (n) -> n * 2
[Function]
coffee> double test
42
```

Install ZeroMQ, the Somata Registry, Somata REPL, and Somata library:

```bash
$ sudo apt-get install libzmq-dev
$ sudo npm install -g somata-registry
$ sudo npm install -g somata-repl
$ npm install somata
```

### Running the Registry

Test the Somata Registry:

```bash
$ somata-registry
[didBind] Socket mbed2kjj bound to tcp://0.0.0.0:8420...
```

You could keep this running in one terminal window and open another. Or better yet, kill it, install PM2 (a process manager for Node.js), and start it with pm2 to run in the background.

```bash
$ sudo npm install -g pm2
$ pm2 start somata-registry
$ pm2 logs
...
[didBind] Socket mbed2kjj bound to tcp://0.0.0.0:8420...
...
```

## Creating a Service

Create a new file `hello-Service.coffee` to define a basic Service. The two important arguments for a new Service are the name "hello" and method hash `{sayHello: [Function]}` that the Service will expose.

```coffee
somata = require 'somata'

new somata.Service 'hello',
    sayHello: (name, cb) ->
        cb null, "Hello #{name}!"
```

The CoffeeScript syntax takes some getting used to -- the Javascript equivalent is:

```javascript
somata = require('somata');

new somata.Service('hello', {
    sayHello: function (name, cb) {
        cb(null, "Hello " + name + "!");
    }
});
```

A new Service will start listening for connections, connect itself to the registry, and register it's name, port, and set of methods. Killing the process will deregister the Service.

### Running the Service

See if it works: 

```bash
$ coffee hello-Service.coffee
[didBind] Socket sj4x536c bound to tcp://0.0.0.0:20052...
Registered Service `hello~6cz3je2x` on tcp://0.0.0.0:20052
```

Looks good. The Service assigns itself a random ID ("6cz3je2x") to identify that particular instance, as there may be many instances of a Service with the same name.

Keep that running – in another window, in the background (`coffee hello-Service.coffee &`) or using pm2 (`pm2 start hello-Service.coffee`). Now test your Service with the Somata REPL:

```bash
$ somata-repl
#| hello.sayHello "Jack"
'Hello Jack!'
#| hello.sayGoodbye "Jack"
[ERROR] No method sayGoodbye
#| 
```

The REPL allows you to call Service methods using a simple Bash-like syntax. It will return responses as well as errors from the Service (such as attempting an undefined method). More info on Hashpipe, the language behind the REPL, is available at https://github.com/spro/hashpipe

## Creating a Client

Now create `hello-client.coffee` to use a Client to call your Service from code.

```coffee
somata = require 'somata'

client = new somata.Client
client.remote 'hello', 'sayHello', 'world', (err, response) ->
    console.log "Response: #{response}"
```

A Client has two important methods: `remote` and `subscribe`. We'll get into subscriptions later, but both have the same general syntax:

`[Service name] [method name] [method arguments...] [callback]`

When this `client.remote 'hello', ...` is called, it first asks the Registry for a list of all Services named "hello", creates a connection to one of the Service instances, and sends a message to the Service specifying the method `sayHello` and the arguments. When the Service responds, the callback will be called. Try it:

```bash
$ coffee hello-client.coffee
Response: Hello world!
```

## Layering Services

The base case has been covered: A single Client calling a single Service. For real world applications, things are rarely so simple. Often one Service will call another within one of its methods.

Create another Service in `hello-yeller-Service.coffee`

```coffee
somata = require 'somata'

client = new somata.Client

new somata.Service 'hello:yeller',
    yellHello: (name, cb) ->
        client.remote 'hello', 'sayHello', name, (err, response) ->
            cb null, response.toUpperCase() + '!!'
```

Now we have a Service that uses a Client to call another Service. The `hello:yeller.yellHello` method will call `hello.sayHello`, and return the response of that after uppercasing it. Try it:

```bash
$ somata-repl
#| hello.sayHello everyone
'Hello everyone!'
#| hello:yeller.yellHello everyone
'HELLO EVERYONE!!!'
#| 
```

Using only two atomic Somata units, Clients and Services, many architectures may be acheived.

## Subscriptions

So far we've only looked at the Client &rarr; Service RPC half of Somata, where every message from a Client expects a single response message from the Service. The other half is Service &rarr; Client event publishing & subscription, where Services send many messages to all Clients that subscribe.

Create a new Service in `fizzbuzz-service.coffee` that will publish some events at an interval:

```coffee
somata = require 'somata'

fizzbuzz_service = new somata.Service 'fizzbuzz', {}

i = 0
publishFizzOrBuzz = ->
    if i % 3 == 0
        fizzbuzz_service.publish 'fizz', i
    if i % 5 == 0
        fizzbuzz_service.publish 'buzz', i
    i += 1

setInterval publishFizzOrBuzz, 100
```

Note two differences about this Service definition from before: we keep a reference to the `fizzbuzz_service` so that we can use its `publish` method, and the methods hash is "empty" because there are no RPC methods on this Service (not that there couldn't be).

This Service will publish one of two events (named `fizz` and `buzz`) when the conditions are met. The event can have a payload (in this case the number `i`) which will be sent to any subscribed clients.

Create `fizzbuzz-client.coffee` to subscribe to the `fizz` and `buzz` events and print them as they arrive:

```coffee
somata = require 'somata'

client = new somata.Client

showFizz = (i) -> console.log "Fizz: #{i}"
showBuzz = (i) -> console.log "Buzz: #{i}"

client.subscribe 'fizzbuzz', 'fizz', showFizz
client.subscribe 'fizzbuzz', 'buzz', showBuzz
```

The Client's `subscribe` method is in the same general shape as `remote`:

`[Service name] [event name] [onEvent]`

Calling `subscribe` sends a message to the Service specifying the event we want to subscribe to. The Service keeps track of which Clients have subscribed to which events, and sends messages as necessary when events are published.

Once the client is running you should see something like this:

```bash
$ coffee fizzbuzz-client.coffee
Fizz: 57
Fizz: 60
Buzz: 60
Fizz: 63
Buzz: 65
Fizz: 66
Fizz: 69
Buzz: 70
...
```

## Conventions

### Method definition

You don't have to define methods directly inside the methods hash like the simpler examples show. Often it's easier (especially with methods that might call each other) to define the methods in the root of your code, and include them in the method hash afterwards:

```coffee
somata = require 'somata'

plus = (a, b, cb) -> cb null, a + b
times = (a, b, cb) -> cb null, a * b
square = (a, cb) -> times a, a, cb

math_methods = {
    plus: plus
    times: times
    square: square
}

new somata.Service 'math', math_methods
```

A CoffeeScript trick with `{}` makes the most common case (where method names exposed by the Service are the same as the actual function names) even easier:

```coffee
math_methods = {plus, times, squared}
```

For more intuition, try this in the CoffeeScript REPL:

```bash
$ coffee
coffee> a = 5
5
coffee> b = 'test'
'test'
coffee> {a, b}
{ a: 5, b: 'test' }
```

### Service names and namespacing

The Service name "hello:yeller" from the layering example is an example of our namespacing convention for within a project, in this case the "hello" project. The Somata REPL supports this syntax well.

To refer to a specific Service's method, follow the Somata REPL convention: `hello:yeller.yellHello`

There are some common naming conventions used across projects, many obvious:

* "project:engine" is a place for central business logic
* "project:data" is usually a wrapper around generic find, get, update, and delete methods for some database (Postgres, MongoDB, Redis)
* "project:notifications" is for sending push notifications (APN, GCM)
* "project:email" is for sending emails

### Service name binding

Often you'll be making many calls to the same named Service, so the Client offers a convenience method `bindRemote`:

```coffee
somata = require 'somata'

client = new somata.Client
HelloService = client.bindRemote 'hello'

HelloService 'sayHello', 'world', (err, response) ->
    console.log "Response: #{response}"
```

This looks less convenient when used in a trivial example, but is nice when repeatedly referencing a Service.

You can also bind down to a method name:

```coffee
somata = require 'somata'

client = new somata.Client
sayHello = client.bindRemote 'hello', 'sayHello'

sayHello 'world', (err, response) ->
    console.log "Response: #{response}"
```

### Process management with PM2

PM2 makes it easy to keep a bunch of services running in the background. If an error causes one of your services to die, PM2 will attempt to restart it (giving up after a rapid succession of failures).

Important commands to know:

* `pm2 start hello-service.coffee` starts a process, using the script base name ("hello-service" here) as the process name.
* `pm2 start hello-service.coffee --name hello` lets you start a process with a specific name.
* `pm2 list` shows a list of processes along with their ID, uptime, and memory usage.
* `pm2 restart hello-service` or `pm2 restart 1` restarts a process by name or ID.
* `pm2 logs` is like `tail -f` on the output of all processes at once.
* `pm2 logs hello` gives you the logs of a specific process.
* `pm2 stop hello` temporarily stops a process, allowing you to restart it later.
* `pm2 delete hello` permanently stops it and removes it from the list.
