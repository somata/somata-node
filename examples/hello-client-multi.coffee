somata = require 'somata'
log = somata.helpers.log

# Create a new Somata client
hello_client = new somata.Client

step = (n) -> ->
    hello_client.remote 'hello', 'sayHello', 'world ' + n, (err, hello_response) ->
        console.log "Step #{n} response: #{hello_response}"

setTimeout step(1), 2000
setTimeout step(2), 5000
setTimeout step(3), 10000
