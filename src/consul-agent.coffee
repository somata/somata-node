async = require 'async'
request = require 'request'
util = require 'util'
{log} = require './helpers'
_ = require 'underscore'

VERBOSE = false
DEFAULT_BASE_URL = 'http://localhost:8500/v1'

ConsulAgent = (@options={}) ->
    @setDefaults()
    return @

ConsulAgent::setDefaults = ->
    @options.base_url = DEFAULT_BASE_URL if !@options.base_url?

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

ConsulAgent::deregisterExternalService = (service, cb) ->
    @apiRequest 'PUT', '/catalog/deregister/' + service_id, service, cb

# Health

ConsulAgent::getServiceHealth = (service_id, cb) ->
    @apiRequest 'GET', '/health/service/' + service_id, cb

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
    all_service_nodes = {}
    self = @

    self.getServices (err, services) ->
        async.map _.keys(services), (service_id, _cb) ->
            self.getServiceHealth service_id, (err, service_nodes) ->
                all_service_nodes[service_id] = service_nodes
                _cb()
        , -> cb null, all_service_nodes

module.exports = ConsulAgent

