BargeService = require '../barge-service'

# Create a new Barge service named 'math'
math_service = new BargeService
    name: 'math'

    binding:
        host: 'localhost'
        port: 5556

    registry:
        port: 8885

    # Define the math methods
    methods:
        add: (n1, n2, cb) ->
            cb null, n1 + n2
        multiply: (n1, n2, cb) ->
            cb null, n1 * n2

