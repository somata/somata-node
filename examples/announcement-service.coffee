somata = require '../src'
# somata = require '../lib'
# somata = require 'somata'

# Create a new Somata service named 'announcement'
announcement_service = new somata.Service 'announcement'

sendAnnouncement = ->
    announcement_service.publish 'announcement', 'hello there'
setInterval sendAnnouncement, 2500
