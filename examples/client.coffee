somata = require '../src'

client = new somata.Client 'examples:hello'

delay = (n) ->
    new Promise (resolve, reject) ->
        setTimeout resolve, n

trySubscribe = ->
    try
        subscription = await client.subscribe('shout')
        subscription.on 'event', (n) ->
            console.log '[shout]', n
    catch err
        console.error "Couldn't subscribe:", err

tryRequests = ->
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

main = ->
    await trySubscribe()
    await tryRequests()

    process.exit()

main()

