ConsulAgent = require '../consul-agent'
util = require 'util'

# Try it out

test_service =
    Name: 'testing'
    Port: 4382

agent = new ConsulAgent

agent.registerService test_service, (err, registered) ->
    console.log 'Registered.'

    agent.getServices (err, services) ->
        console.log 'Services: ' + util.inspect services

        agent.getServiceNodes test_service.Name, (err, nodes) ->
            console.log 'Nodes: ' + util.inspect nodes

            agent.deregisterService test_service.Name, (err, deregistered) ->
                console.log 'Deregistered.'

                agent.getServices (err, services) ->
                    console.log 'Services: ' + util.inspect services

