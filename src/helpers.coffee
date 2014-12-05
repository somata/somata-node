util = require 'util'
crypto = require 'crypto'
_ = require 'underscore'
moment = require 'moment'
ansi = require('ansi')(process.stdout, {enabled: true})

# Format the current date for logging
date_format = 'YYYY-MM-DD hh:mm:ss'
logDate = ->
    ansi.grey()
    ansi.write '[' + moment().format(date_format) + '] '
    ansi.reset()

# Colored, timestamped log output
exports.log = log = (s, d, options={}) ->
    logDate() if !options.date? or options.date
    ansi.hex(options.hex) if options.hex?
    ansi.fg[options.color]() if options.color?
    ansi.write s
    ansi.reset()
    ansi.write ' ' + util.inspect(d, colors: true) if d?
    ansi.write '\n'
log.w = (s, d) -> log s, d, color: 'yellow'
log.i = (s, d) -> log s, d, color: 'cyan'
log.e = (s, d) -> log s, d, color: 'red'
log.d = (s, d) -> log s, d, color: 'grey'
log.s = (s, d) -> log s, d, color: 'green'

# Avoid wasting time on static resources
static_exts = ['css','js','jpg','png','gif','woff', 'svg']
exports.is_static_url = (url) -> url.split('.').slice(-1)[0] in static_exts

# Capitalize the first letter of a string
exports.capitalize = (type) -> type[0].toUpperCase() + type.slice(1)

# Generate a random alphanumeric string
exports.randomString = (len=8) ->
    s = ''
    while s.length < len
        s += Math.random().toString(36).slice(2, len-s.length+2)
    return s

# Choose a random item from an array
exports.randomChoice = (l) ->
    l[Math.floor(Math.random() * l.length)]

# Summarize a service
exports.serviceSummary = (service) ->
    return service.name + '@' + service.binding.host + ':' + service.binding.port

# Create a tcp://host:port address from a Consul Node description
exports.makeAddress = (host, port) ->
    return 'tcp://' + host + ':' + port

exports.randomPort = ->
    10000 + Math.floor(Math.random()*50000)

exports.makeBindingAddress = (protocol, port) ->
    return protocol + '://0.0.0.0:' + port

exports.md5 = (s) -> crypto.createHash('md5').update(s).digest('hex')
exports.hashobj = (o) -> exports.md5 JSON.stringify o

