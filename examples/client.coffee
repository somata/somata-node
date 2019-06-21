somata = require '../src'

client = new somata.Client 'examples:hello'

delay = (n) ->
    new Promise (resolve, reject) ->
        setTimeout resolve, n

main = ->
    client.subscribe('shout').on 'event', (n) ->
        console.log '[shout]', n
    try
        [hello_jones, hello_sam] = await Promise.all [
            client.request 'sayHello', 'jones'
            client.request 'sayHello', 'sam'
        ]
        console.log '[hello_jones]', hello_jones
        console.log '[hello_sam]', hello_sam
        await delay 2500
        hello_later = await client.request 'sayHello', 'later'
        console.log '[hello_later]', hello_later
    catch err
        console.log '[err]', err
    process.exit()

main()


