BargeService = require '../barge-service'

# Create a new Barge service named 'math'
math_service = new BargeService
    name: 'math'
    host: 'localhost'
    port: 5556

# Register with the registry
math_service.register()

# Define the math methods
math_service.methods.add = (n1, n2, cb) ->
    cb null, n1 + n2
math_service.methods.multiply = (n1, n2, cb) ->
    cb null, n1 * n2

