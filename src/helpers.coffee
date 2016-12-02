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

# Capitalize the first letter of a string
exports.capitalize = (type) -> type[0].toUpperCase() + type.slice(1)

exports.randomChoice = (list) ->
    list[Math.floor(Math.random() * list.length)]

# Generate a random alphanumeric string
exports.randomString = (len=8) ->
    s = ''
    while s.length < len
        s += Math.random().toString(36).slice(2, len - s.length+2)
    return s

# Summarize a message
exports.summarizeMessage = (message) ->
    util.inspect(message).slice(0,100).replace(/\s+/g, ' ')

# Summarize a client
exports.summarizeClient = (client) ->
    "<#{client.id}> #{client.address}"

# Summarize a connection
exports.summarizeConnection = (connection) ->
    "<#{connection.id}> #{connection.address}"

# Summarize a service
exports.summarizeService = (service) ->
    return service.name + '@' + service.binding.host + ':' + service.binding.port

# Create a proto://host:port address
exports.makeAddress = (proto, host, port) ->
    address = proto + '://' + host
    address += ':' + port if proto != 'ipc'
    return address

exports.randomPort = ->
    10000 + Math.floor(Math.random() * 50000)

# Descend down an object tree {one: {two: 3}} with a path 'one.two'
descend = (o, c) ->
    if c.length == 1
        return o[c[0]].bind(o)
    else
        return descend o[c.shift()], c
exports.descend = descend

exports.parseAddress = (s, default_host, default_port) ->
    if !s?
        if default_host?
            return {host: default_host, port: default_port}
        else
            return null
    else
        [host, port] = s.split(':')
        host ||= default_host
        port ||= default_port
        return {host, port}

