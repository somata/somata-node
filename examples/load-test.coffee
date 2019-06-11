somata = require '../src'

client = new somata.Client 'hello'

warmup = 100
n_tests = process.argv[2] or 1000

main = ->
    start = new Date().getTime()

    for n in [0..n_tests]
        await client.request 'sayHello', n

    end = new Date().getTime()
    diff = (end - start) / 1000
    console.log "Finished #{n_tests} requests in #{diff}s"
    process.exit()

setTimeout main, warmup

