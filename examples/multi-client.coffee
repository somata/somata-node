somata = require '../src'
client = new somata.MultiClient

main = ->
    response = await client.request 'examples:hello', 'sayHello', 'Johnny'
    console.log '[response]', response
    process.exit()

main()
