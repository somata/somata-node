somata = require '../src'
# somata = require '../lib'
# somata = require 'somata'
log = somata.helpers.log
util = require 'util'

# Create a new Somata client
announcement_client = new somata.Client

# Execute the 'announcement' service's `sayannouncement` method with the argument 'world' ...
announcement_client.on 'announcement', 'announcement', (err, message) ->
    log.s message

