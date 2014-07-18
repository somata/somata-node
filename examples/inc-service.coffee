somata = require '../src'
# somata = require '../lib'
# somata = require 'somata'

i = 0

new somata.Service 'inc',

    inc: (cb) ->
        cb null, ++i

    dec: (cb) ->
        cb null, --i

