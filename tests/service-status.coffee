barge = require '../src'
_ = require 'underscore'

test_client = new barge.Client
test_client.consul_agent.getServices (err, all_services) ->
    services = _.omit(all_services, 'consul')
    _.keys(services).map (service) ->
        test_client.remote service, '_status', (err, response) ->
            console.log response

