async = require 'async'
request = require 'request'
util = require 'util'
{log} = require './helpers'
{EventEmitter} = require 'events'
_ = require 'underscore'

VERBOSE = process.env.SOMATA_VERBOSE || false
CONSUL_URL = process.env.SOMATA_CONSUL_URL || 'http://localhost:8500/v1'
HEALTH_POLL_MS = parseInt(process.env.SOMATA_HEALTH_POLL) || 2000

module.exports = class ConsulAgent extends EventEmitter
    constructor: (@options={}) ->
        @setDefaults()
        @startWatchingKnownServices()
        return @

ConsulAgent::setDefaults = ->
    @options.base_url ||= CONSUL_URL
    @known_services = []
    @known_instances = {}

# Helpers for blocking queries

last_index = 0
WATCH_S  = 60
makeWatchQuery = (index) -> "?wait=#{ WATCH_S }s&index=#{ index }"

# Generalized request to the Consul HTTP API

ConsulAgent::apiRequest = (method, path, data, cb) ->
    if !cb?
        cb = data
        data = null

    request_options =
        url: @options.base_url + path
        method: method
        json: true
        body: data

    request request_options, (err, res, data) ->
        log.d '[apiRequest] Response status: ' + res.statusCode if VERBOSE
        last_index = res.headers['x-consul-index']
        cb(err, data) if cb?

# Core API requests
# ------------------------------------------------------------------------------

# Catalog

ConsulAgent::getNodes = (cb) ->
    @apiRequest 'GET', '/catalog/nodes', cb

ConsulAgent::getServices = (cb) ->
    @apiRequest 'GET', '/catalog/services', cb

ConsulAgent::getServiceNodes = (service_id, cb) ->
    @apiRequest 'GET', '/catalog/service/' + service_id, cb

ConsulAgent::registerExternalService = (service, cb) ->
    @apiRequest 'POST', '/catalog/register', service, cb

ConsulAgent::deregisterExternalService = (service, cb) ->
    @apiRequest 'PUT', '/catalog/deregister', service, cb

# Health

ConsulAgent::getServiceHealth = (service_id, cb) ->
    @apiRequest 'GET', '/health/service/' + service_id, cb

ConsulAgent::watchServiceHealth = (service_id, index=last_index, cb) ->
    @apiRequest 'GET', '/health/service/' + service_id + makeWatchQuery(index), cb

# Agent

ConsulAgent::registerService = (service, cb) ->
    @apiRequest 'PUT', '/agent/service/register', service, cb

ConsulAgent::deregisterService = (service_id, cb) ->
    @apiRequest 'DELETE', '/agent/service/deregister/' + service_id, cb

ConsulAgent::registerCheck = (check, cb) ->
    @apiRequest 'PUT', '/agent/check/register', check, cb

ConsulAgent::deregisterCheck = (check_id, cb) ->
    @apiRequest 'DELETE', '/agent/check/deregister/' + check_id, cb

ConsulAgent::checkPass = (check_id, cb) ->
    @apiRequest 'GET', '/agent/check/pass/' + check_id, cb

# Higher level requests

ConsulAgent::getAllServicesHealth = (cb) ->
    all_service_instances = {}
    self = @

    self.getServices (err, services) ->
        async.map _.keys(services), (service_id, _cb) ->
            self.getServiceHealth service_id, (err, service_instances) ->
                all_service_instances[service_id] = service_instances
                _cb()
        , -> cb null, all_service_instances

# Find healthy service instances (those without a check in 'critical' state)

healthyInstances = (instances) ->
    instances.filter (i) ->
        i.Checks.filter((c) ->
            c.Status == 'critical'
        ).length == 0

ConsulAgent::getHealthyServiceInstances = (service_name, cb) ->

    # Otherwise ask the consul agent
    @getServiceHealth service_name, (err, instances) ->

        # Filter by those with passing checks
        cb err, healthyInstances instances

# Find unhealthy service instances (those with a check in 'critical' state)

unhealthyInstances = (instances) ->
    instances.filter (i) ->
        i.Checks.filter((c) ->
            c.Status == 'critical'
        ).length != 0

ConsulAgent::getUnhealthyServiceInstances = (service_name, cb) ->

    # Otherwise ask the consul agent
    @getServiceHealth service_name, (err, instances) ->

        # Filter by those with passing checks
        cb err, unhealthyInstances instances

# Emulate upcoming agent events by polling for changes to registered instances

ConsulAgent::startWatchingKnownServices = ->
    again = @startWatchingKnownServices.bind(@)
    if @known_services.length
        async.map @known_services, (service_name, _cb) =>
            @checkServiceHealth(service_name, null, _cb)
        , again
    else
        setTimeout again, 250

ConsulAgent::checkServiceHealth = (service_name, index=null, cb) ->
    index = last_index if index == null
    @watchServiceHealth service_name, index, (err, service_instances) =>
        getServiceID = (ins) -> ins.Service.ID
        healthy_instances = healthyInstances service_instances
        healthy_ids = healthy_instances.map getServiceID
        known_ids = (@known_instances[service_name]?.map getServiceID) || []

        # Check if we are adding or removing each ID
        new_ids = healthy_ids.filter (i) -> i not in known_ids
        dead_ids = known_ids.filter (i) -> i not in healthy_ids

        # Emit register and deregister events when a service ID becomes known or disappears
        new_ids.map (service_id) =>
            service_instance = healthy_instances[service_id]
            @emit 'register:services/' + service_name, service_instance
        dead_ids.map (service_id) =>
            @emit 'deregister:services/' + service_id

        @known_instances[service_name] = healthy_instances
        cb(null, healthy_instances) if cb?

