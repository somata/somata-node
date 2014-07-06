# barge = require '../src'
# barge = require '../lib'
barge = require 'barge'

i = 0

new barge.Service 'inc',

    inc: (cb) ->
        cb null, ++i

    dec: (cb) ->
        cb null, --i

