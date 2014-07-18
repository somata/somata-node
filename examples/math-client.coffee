somata = require '../src'
# somata = require '../lib'
# somata = require 'somata'
log = somata.helpers.log

# Create a new Somata client with default connection options
math_client = new somata.Client

# Execute some remote math commands
math_client.remote 'math', 'add', 5, 10, (err, added) ->
    log.s 'The answer is ' + added
    process.exit()

