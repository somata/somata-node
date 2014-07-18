barge = require '../src'
# barge = require '../lib'
# barge = require 'barge'

# Create a new Barge service named 'announcement'
announcement_service = new barge.Service 'announcement'

sendAnnouncement = ->
    announcement_service.publish 'announcement', 'hello there'
setInterval sendAnnouncement, 2500
