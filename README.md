Somata
=====

Micro-service orchestration framework built on [ZeroMQ](http://zeromq.org) and [Consul](http://www.consul.io).

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

Install ZeroMQ, Node.js and NPM, plus unzip (if you don't have it).

```sh
$ sudo apt-get install libzmq-dev nodejs npm
$ sudo ln -s /usr/bin/nodejs /usr/bin/node # To fix node-gyp on Ubuntu
```

## Somata NPM module

Install Somata itself with [npm](http://npmjs.org):

```sh
$ npm install somata
```
