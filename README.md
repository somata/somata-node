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
$ sudo apt-get install nodejs npm libzmq-dev unzip
$ sudo ln -s /usr/bin/nodejs /usr/bin/node # To fix node-gyp on Ubuntu
```

## Consul

Get the latest download link for your platform from [the Consul download page](http://www.consul.io/downloads.html). Unzip and move the binary somewhere in your `$PATH`.

```sh
$ curl -LO https://releases.hashicorp.com/consul/0.6.0/consul_0.6.0_linux_amd64.zip
$ unzip consul_0.6.0_linux_amd64.zip
$ sudo mv consul /usr/local/bin
```

### Running consul

Start the consul agent. For a basic self-sufficient agent:

```sh
$ consul agent -server -bootstrap -data-dir /tmp/consul
```

To keep it running in the background indefinitely:

```sh
$ nohup consul agent -server -bootstrap -data-dir /tmp/consul > consul.log &
```

Test that Consul is running:

```sh
$ consul members
Node             Address            Status  Type    Build  Protocol  DC
ip-172-30-0-108  172.30.0.108:8301  alive   server  0.6.0  2         dc1
```

For more information on installing Consul read [their installation instructions](http://www.consul.io/intro/getting-started/install.html).

## Somata NPM module

Install Somata itself with [npm](http://npmjs.org):

```sh
$ npm install somata
```
