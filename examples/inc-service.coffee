Service = require('../service')

i = 0

new Service 'inc', methods:

    inc: (cb) ->
        cb null, ++i
    dec: (cb) ->
        cb null, --i

