somata = require 'somata'

client = new somata.Client
client.remote 'hello', 'sayHello', 'test1', -> console.log 'got test1'
client.remote 'hello', 'sayHello', 'test2', -> console.log 'got test2'

