somata = require '.'
{log} = somata

VERBOSE = process.env.SOMATA_VERBOSE || false
SERVICE_HOST = process.env.SOMATA_SERVICE_HOST
BUMP_FACTOR = 1.5 # Wiggle room for heartbeats
DEAD_FACTOR = 10 # Heartbeats to miss before pronounced dead

# Map of ID -> Instance
registered = {}

# Map of ID -> Expected heartbeat
heartbeats = {}

registerService = (service_instance, cb) ->
    service_name = service_instance.name
    service_id = service_instance.id
    log.s "Registering #{service_id}", service_instance
    registered[service_name] ||= {}
    registered[service_name][service_id] = service_instance
    heartbeats[service_id] = new Date().getTime() + service_instance.heartbeat * 1.5
    cb null, service_instance

deregisterService = (service_name, service_id, cb) ->
    log.w "Deregistering #{service_id}"
    if service_instance = registered[service_name]?[service_id]
        delete registered[service_name]?[service_id]
        registry.publish 'deregister', service_instance
    cb null, service_id

findServices = (cb) ->
    cb null, instances

isHealthy = (service_instance) ->
    next_heartbeat = heartbeats[service_instance.id]
    is_healthy = next_heartbeat > new Date().getTime()
    if !is_healthy
        log.w "Heartbeat overdue by #{new Date().getTime() - next_heartbeat}"
        deregisterService service_instance.name, service_instance.id
    return is_healthy

getHealthyServiceByName = (service_name) ->
    service_instances = registered[service_name]
    # TODO: Go through to find healthy ones
    for service_id, instance of service_instances
        if isHealthy instance
            return instance
    return null

getServiceById = (service_id) ->
    service_name = service_id.split('~')[0]
    return registered[service_name]?[service_id]

getService = (service_name, cb) ->
    if service_instance = getHealthyServiceByName(service_name)
        cb null, service_instance
    else
        log.i "No healthy instances for #{service_name}"
        cb "No healthy instances for #{service_name}"

heartbeat = (service_id, cb) ->
    if service_instance = getServiceById(service_id)
        bump_time = service_instance.heartbeat * BUMP_FACTOR
        heartbeats[service_id] = new Date().getTime() + bump_time
        cb null, true
    else
        # TODO: Tell service to re-register
        log.w "No known service #{service_id}"
        cb "No known service #{service_id}", false

registry_methods = {
    registerService
    deregisterService
    findServices
    getService
    heartbeat
}

registry_options = {
    rpc_options: {port: 8420}
}

class Registry extends somata.Service
    register: (cb) ->
        console.log "Who registers the registry?"
    deregister: (cb) ->
        console.log "Who deregisters the registry?"
        cb()

registry = new Registry 'somata:registry', registry_methods, registry_options

