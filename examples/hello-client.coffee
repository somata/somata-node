somata = require '../src'
# somata = require '../lib'
# somata = require 'somata'
log = somata.helpers.log

# Create a new Somata client
hello_client = new somata.Client

# Execute the 'hello' service's `sayHello` method with the argument 'world' ...
hello_client.remote 'hello', 'sayHello', 'world', (err, hello_response) ->
    log.s '[hello.sayHello] response: ' + hello_response

    # ... then execute hello.sayGoodbye('world')
    hello_client.remote 'hello', 'sayGoodbye', 'world', (err, goodbye_response) ->
        log.s '[hello.sayGoodbye] response: ' + goodbye_response

        process.exit()

