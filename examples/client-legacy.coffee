somata = require '../src'

client = new somata.Client 'examples:hello'

tryRequestCb = ->
    client.requestCb 'sayHello', 'jones', (err, hello_jones) ->
        if err
            console.log '[err]', err
        else
            console.log '[hello_jones]', hello_jones

main = ->
    await tryRequestCb()
    process.exit()

main()
