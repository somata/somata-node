BargeClient = require '../barge-client'
{log} = require '../helpers'

# Create a new Barge client with default connection options
math_client = new BargeClient
    registry:
        port: 8885

# Execute some remote math commands
math_client.remote 'math', 'add', 5, 10, (err, added) ->
    math_client.remote 'math', 'multiply', added, 10, (err, multiplied) ->
        log 'The answer is ' + multiplied, color: 'blue'
        process.exit()

