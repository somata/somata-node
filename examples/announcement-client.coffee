barge = require '../src'
# barge = require '../lib'
# barge = require 'barge'
log = barge.helpers.log
util = require 'util'

# Create a new Barge client
announcement_client = new barge.Client

# Execute the 'announcement' service's `sayannouncement` method with the argument 'world' ...
announcement_client.on 'announcement', 'announcement', (err, message) ->
    log.s message

