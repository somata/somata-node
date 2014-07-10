barge = require '../src'
# barge = require '../lib'
# barge = require 'barge'
log = barge.helpers.log

# Create a new Barge client with default connection options
math_client = new barge.Client

# Execute some remote math commands
math_client.remote 'math', 'add', 5, 10, (err, added) ->
    log.s 'The answer is ' + added
    process.exit()

