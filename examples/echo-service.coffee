somata = require 'somata'

# Create a new Somata service named 'echo'
echo_service = new somata.Service 'echo',

    echo: (input, cb) ->
        cb null, input

