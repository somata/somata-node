Somata
=====

Somata is a framework for building microservices. This is the Node.js library, see also [somata-python](https://github.com/somata/somata-python) and [somata-go](https://github.com/somata/somata-go)

# Usage

Define a service with `new somata.Service(name, methods, [options])`:

```js
somata = require('somata');

// Create a new Somata service named 'hello'
hello_service = new somata.Service('hello', {

    // Exposing a single method `sayHello`
    sayHello: function (name, cb) {
        cb(null, 'Hello, ' + name + '!');
    }

});
```

Define a client with `new somata.Client([options])`:

```js
somata = require('somata');

// Create a new Somata client
hello_client = new somata.Client();

// Call the 'hello' service's `sayHello` method
hello_client.remote('hello', 'sayHello', 'world', function (err, response) {
    console.log('Response: ' + response);
});
```

Start the service, then run the client:

```sh
$ node hello-service.js &
Somata service listening on localhost:15555...

$ node hello-client.js
Found service hello@localhost:15555
[hello.sayHello] response: Hello, world!
```

# Installation

## Dependencies

Install ZeroMQ, Node.js and NPM.

```sh
$ sudo apt-get install libzmq-dev nodejs npm
$ sudo ln -s /usr/bin/nodejs /usr/bin/node # To fix node-gyp on Ubuntu
```

## Somata NPM module

Install the Somata library locally, and the [Somata registry](https://github.com/somata/somata-registry) globally:

```sh
$ npm install somata
$ npm install -g somata-registry
```

# Running

Start up the registry

```sh
$ somata-registry
```

Then try the hello example:

```
$ coffee examples/hello-service.coffee &
$ coffee examples/hello-client.coffee
```
