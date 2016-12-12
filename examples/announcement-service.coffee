somata = require 'somata'

# Make a method called announce
announce = (message, cb) ->
    announcement_service.publish 'announce', message
    if cb? then cb null, 'announced: ' + message

# Create a new Somata service named 'announcement'
announcement_service = new somata.Service 'announcement', {announce}

# Announce a message every 2500s
setInterval announce.bind(null, 'hi there'), 2500
