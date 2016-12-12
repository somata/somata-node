somata = require 'somata'

# Create a new Somata client
announcement_client = new somata.Client

# Watch the 'announcement' service for 'announce' events...
announcement_client.subscribe 'announcement', 'announce', (err, message) ->
    console.log 'announcement service did announce:', message

