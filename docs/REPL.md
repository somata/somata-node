# Somata REPL

The Somata REPL is a command-line interface based on [hashpipe](https://github.com/qnectar/hashpipe) that allows you to make service calls directly.

## Basic usage

The syntax of a service call is `[service]:[method] [args...]` (the equivalent of `client.remote([service], [method], [args...])`):

```
# hello:sayHello "world"
"Hello, world!"
# soundberry:volume
35
# soundberry:volume 50
50
# soundberry:volume "+5"
55
# wemo:set 123 0
[set] 123 ==> false
# wemo:update 123 {name: "tea switch"}
[update] 123 ==> name = "tea switch"
```

Read the [hashpipe documentation](https://github.com/qnectar/hashpipe) for more details on the syntax.

