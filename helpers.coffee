moment = require 'moment'
_ = require 'underscore'
util = require 'util'
ansi = require('ansi')(process.stdout)

# Format the current date for logging
date_format = 'YYYY-MM-DD hh:mm:ss'
logDate = ->
    ansi.grey()
    ansi.write '[' + moment().format(date_format) + '] '
    ansi.reset()

# Colored, timestamped log output
exports.log = (s, options={}) ->
    logDate() if !options.date? or options.date
    ansi.hex(options.hex) if options.hex?
    ansi.fg[options.color]() if options.color?
    ansi.write s + '\n'
    ansi.reset()

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
