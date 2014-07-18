somata = require '../src'
# somata = require '../lib'
# somata = require 'somata'

# Create a new Somata service named 'math'
math_service = new somata.Service 'math',

    # Define the math methods

    add: (n1, n2, cb) ->
        cb null, n1 + n2

    multiply: (n1, n2, cb) ->
        cb null, n1 * n2
