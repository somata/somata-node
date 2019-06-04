somata = require '../src'

sayHello = (name) ->
    # throw "No good"
    return "Hello #{name}"

new somata.Service 'hello', {
    sayHello
}
