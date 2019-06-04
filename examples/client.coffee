somata = require '../src'

client = new somata.Client 'hello'

main = ->
    try
        [hello_jones, hello_sam] = await Promise.all [
            client.request 'sayHello', 'jones'
            client.request 'sayHello', 'sam'
        ]
        console.log '[hello_jones]', hello_jones
        console.log '[hello_sam]', hello_sam
    catch err
        console.log '[err]', err
    process.exit()

main()


