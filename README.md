# Somata (the HTTP- & WebSocket-based rewrite)

## Quickstart

### Install

Clone this branch and install dependencies:

```sh
> git clone --single-branch --branch somata-http git://github.com/somata/somata-node somata-http
> cd somata-http
> npm install
```

### Set up DNS to resolve services

Instead of using a registry to locate services, clients now find services with DNS - a service that would have been called `examples:hello` will now be located at `http://hello.examples/`. In order to resolve services on a local machine (instead of e.g. Kubernetes which will automatically configure DNS based on the Kubernetes Service name) you will have to manually define the location of each service.

With nginx + simon this is easy enough. Assuming a service located at port :8000 (the default) and a DNS suffix of ".pronto" (as set up with dnsmasq), add a record for the example hello service with `simon-says`:

```sh
> simon-says hello.examples.pronto :8000
Pointing hello.examples.pronto to 127.0.0.1:8000
1) "127.0.0.1:8000"
```

### Run the examples

Run the example hello service:

```sh
> DEBUG=somata.* coffee examples/service.coffee
  somata.service Warning: Deprecated service identifier: 'examples:hello' +0ms
  somata.service Service identifier updated to 'hello.examples' +2ms
  somata.service Listening on :8000 +7ms
```

Run the example hello client using HTTP POST requests:

```sh
> SOMATA_REQUEST=post SOMATA_DNS_SUFFIX=pronto coffee examples/client.coffee
[hello_jones] Hello jones
[hello_sam] Hello sam
```

## Options

Change the port a service is bound to with `SOMATA_PORT`. The default is 8000.

Change the default request method with `SOMATA_REQUEST`. Options are "post" and "ws" (for WebSockets - experimental).

Change the DNS suffix with `SOMATA_DNS_SUFFIX`. The default is no suffix – the `hello.examples` service will be available at `http://hello.examples/`.


## Testing services with Curl

Call a service method by POSTing an object `{args: [...]}` to `http://service_name.suffix/method_name.json`. The response will be an object `{type: "response", data: ...}`:

```sh
> curl -X POST -d '{"args": ["Jones"]}' -H 'Content-type: application/json' hello.examples.pronto/sayHello.json
{"type":"response","data":"Hello Jones"}
```

