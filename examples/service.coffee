somata = require '../src'

sayHello = (name) ->
    # throw "No good"
    return "Hello #{name}"

new somata.Service 'examples:hello', {
    sayHello
}
