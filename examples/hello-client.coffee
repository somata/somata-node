barge = require '../lib'

# Create a new Barge client
hello_client = new barge.Client

# Execute the 'hello' service's `sayHello` method with the argument 'world' ...
hello_client.remote 'hello', 'sayHello', 'world', (err, hello_response) ->

    # ... then execute hello.sayGoodbye('world')
    hello_client.remote 'hello', 'sayGoodbye', 'world', (err, goodbye_response) ->

        # ... then print the responses and leave
        console.log '[hello.sayHello] response: ' + hello_response
        console.log '[hello.sayGoodbye] response: ' + goodbye_response
        process.exit()

