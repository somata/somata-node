somata = require '.'

VERBOSE = process.env.SOMATA_VERBOSE || false
EXTERNAL = process.env.SOMATA_EXTERNAL || false
CHECK_INTERVAL = parseInt(process.env.SOMATA_CHECK_INTERVAL) || 9000
CHECK_TTL = process.env.SOMATA_CHECK_TTL || ((CHECK_INTERVAL / 1000) + 4 + "s")
SERVICE_HOST = process.env.SOMATA_SERVICE_HOST

services = {}

registerService = (service_name, service_options, cb) ->
    console.log "Registering #{service_name}", service_options
    services[service_name] = service_options
    cb null, service_options

findServices = (cb) ->
    cb null, services

getService = (service_name, cb) ->
    cb null, services[service_name]

registry_methods = {
    registerService
    findServices
    getService
}

registry_options = {
    rpc_options: {port: 8420}
}

class Registry extends somata.Service
    register: (cb) ->
        console.log "Who registers the registry?"

registry = new Registry 'somata:registry', registry_methods, registry_options

