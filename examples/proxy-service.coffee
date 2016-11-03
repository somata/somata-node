# Acts as a proxy to a remote service by forwarding calls through a
# client connected to a remote registry

somata = require 'somata'

[service_name, registry_host] = process.argv.slice(2)
if !service_name? or !registry_host?
    console.log "Usage: coffee proxy.coffee [service name] [remote registry host]"
    process.exit()

client = new somata.Client {registry_host}

new somata.Service service_name, (method) -> (args..., cb) ->
    client.remote service_name, method, args..., cb
