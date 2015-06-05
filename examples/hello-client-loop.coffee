somata = require 'somata'
log = somata.helpers.log

# Create a new Somata client
hello_client = new somata.Client save_connections: false

n_sent = 0
n_recd = 0

# Execute the 'hello' service's `sayHello` method with the argument 'world' ...
_sayHello = ->
    n_sent++
    hello_client.remote 'hello', 'sayHello', 'world', (err, hello_response) ->
        n_recd++
    setTimeout _sayHello, 500

_sayHello()

_showNs = ->
    somata.log.d "[SUMMARY] sent=#{ n_sent } recd=#{ n_recd } (#{ n_recd*100.0/n_sent }%)"
    setTimeout _showNs, 500

_showNs()
