barge = require '../lib'

i = 0

new barge.Service 'inc', methods:

    inc: (cb) ->
        cb null, ++i
    dec: (cb) ->
        cb null, --i

