somata = require '../src'

client = new somata.Client 'examples:hello'

delay = (n) ->
    new Promise (resolve, reject) ->
        setTimeout resolve, n

trySubscribe = ->
    try
        console.log 'try to subscribe'
        subscription = await client.subscribe('shout')
        console.log 'subscribed?'
        subscription.on 'event', (n) ->
            console.log '[shout]', n
    catch err
        console.log "can't subscribe", err

tryOneRequest = ->
    try
        hello_jones = await client.request 'sayHello', 'jones'
        console.log '[hello_jones]', hello_jones
    catch err
        console.log '[err]', err

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
    console.log 'Waiting...'
    await delay 500
    # await trySubscribe()
    await tryOneRequest()
    # await tryRequests()

    console.log 'Done'
    process.exit()

main()

