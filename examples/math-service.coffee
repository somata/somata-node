BargeService = require '../barge-service'

# Create a new Barge service named 'math'
math_service = new BargeService
    registry:
        host: 'localhost'
    service:
        name: 'math'
        host: 'localhost'
        port: 5555

# Define the math methods
math_service.add = (n1, n2, cb) ->
    cb n1 + n2
math_service.multiply = (n1, n2, cb) ->
    cb n1 * n2

