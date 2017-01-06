# Somata for Node

Somata is a framework for building networked microservices, supporting both remote procedure call (RPC) and publish-subscribe models of communication. This is the Node version of the library, see also [somata-python](https://github.com/somata/somata-python) and [somata-lua](https://github.com/somata/somata-lua).

* [Overview](#overview)
* [Installation](#installation)
* [Getting started](#getting-started)

## Overview

### Service vs. Client

The two core classes of Somata are the *Service* and *Client*.

![](https://i.imgur.com/jd7pQQm.png)

A *Service* has a name and exposes a set of methods, and may publish events.

A *Client* manages connections to one or more Services, to call methods and subscribe to events.

### Service discovery

Service discovery is managed by the [Somata Registry](https://github.com/somata/somata-registry), which is itself a specialized Service. A Service will send registration information (i.e. its name and binding port) to the Registry. When a Client calls a remote method, or creates a subscription, it first asks the Registry to look up the Service by name.

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
