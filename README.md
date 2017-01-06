# Somata for Node

Somata is a framework for building networked microservices, supporting both remote procedure call (RPC) and publish-subscribe models of communication. This is the Node version of the library, see also [somata-python](https://github.com/somata/somata-python) and [somata-lua](https://github.com/somata/somata-lua).

* [At a glance](#at-a-glance)
* [Installation](#installation)
* [Getting started](#getting-started)

## At a glance

As an example of a the most basic Somata system, we'll make a single "hello" Service with a `sayHello` method, and call that method from a separate process using a Client.

![](https://i.imgur.com/mryWajd.png)

A **Service** has a name and set of named methods:

```js
var somata = require('somata');

var hello_service = new somata.Service('hello', {
    sayHello: function (name, cb) {
        cb(null, 'Hello, ' + name + '!');
    }
});
```

To make requests to a Service you use a **Client**:

```js
var somata = require('somata');

var hello_client = new somata.Client();

hello_client.remote('hello', 'sayHello', 'world', function (err, response) {
    console.log('Got response: ' + response);
});
```

Read the [Somata Protocol Overview](https://github.com/somata/somata-protocol#overview) to learn more about how these pieces connect.

## Installation

Somata requires the [Node.js ZeroMQ library](https://github.com/JustinTulloss/zeromq.node), which requires [ZeroMQ](http://zeromq.org/) libraries - install those with your system package manager:

```sh
$ sudo apt-get install libzmq-dev
```

Install the Somata library locally, and the [Somata Registry](https://github.com/somata/somata-registry) globally:

```sh
$ npm install somata
$ npm install -g somata-registry
```

## Getting started

First make sure the Registry is [installed](https://github.com/somata/somata-registry#installation) and running:

```sh
$ somata-registry
[Registry] Bound to 127.0.0.1:8420
```

### Creating a Service

Create a Service using `new somata.Service(name, methods)`. The `methods` argument is an object of named functions; every function is asynchronous and takes a callback as its last argument. 

A Service can publish events using `service.publish(type, data)`.

This example (see [examples/hello-service.js](https://github.com/somata/somata-node/blob/master/examples/hello-service.js)) creates a Service named "hello" with a single method `sayHello(name, cb)`, and emits an event called `hi` every 2 seconds:

```js
var somata = require('somata');

var hello_service = new somata.Service('hello', {
    sayHello: function (name, cb) {
        cb(null, 'Hello, ' + name + '!');
    }
});

setInterval(function() {
    hello_service.publish('hi', "Just saying hi.");
}, 2000);
```

### Running a Service

When a Service is started it will bind to a random port and register itself with the Registry:

```sh
$ node examples/hello-service.js
Registered service `hello~9iuma73n` on tcp://127.0.0.1:15544
```

### Creating a Client

Create a Client using `new somata.Client()`.

Call a remote method of a Service using `client.remote(service, method, args..., cb)`. The callback takes two argments, `err` and `response`.

Subscribe to events from a Service using `client.subscribe(service, type, cb)`. This callback takes one argument, the incoming `event`.

This example (see [examples/hello-client.js](https://github.com/somata/somata-node/blob/master/examples/hello-client.js)) connects to the "hello" service, calls the `sayHello` method, and subscribes to its events:

```js
var somata = require('somata');

var hello_client = new somata.Client();

hello_client.remote('hello', 'sayHello', 'world', function (err, response) {
    console.log('Got response: ' + response);
});

hello_client.subscribe('hello', 'hi', function (event) {
    console.log('Got event: ' + event);
});
```

### Running a Client

Assuming the Registry and "hello" service are running, running the client call the "hello" service's remote method `sayHello` and subscribe to its `hi` events:

```sh
$ node examples/hello-client.js
Got response: Hello, world!
Got event: Just saying hi.
Got event: Just saying hi.
Got event: Just saying hi.
^C
```
