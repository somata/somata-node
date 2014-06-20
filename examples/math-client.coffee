barge = require 'barge'
{log} = require '../helpers'

# Create a new Barge client with default connection options
math_client = new barge.Client

# Execute some remote math commands
math_client.remote 'math', 'add', 5, 10, (err, added) ->
    math_client.remote 'math', 'multiply', added, 10, (err, multiplied) ->
        log 'The answer is ' + multiplied, color: 'blue'
        process.exit()

