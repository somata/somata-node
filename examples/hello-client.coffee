BargeClient = require '../barge-client'

# Create a new Barge client
hello_client = new BargeClient

# Execute the 'hello' service's `sayHello` method with the argument 'world'
hello_client.remote 'hello', 'sayHello', 'world', (err, response) ->
    console.log '[hello.sayHello] response: ' + response
    process.exit()

