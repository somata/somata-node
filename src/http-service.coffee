fs = require 'fs'
_ = require 'underscore'
util = require 'util'
querystring = require 'querystring'

calendar_desc = JSON.parse fs.readFileSync('/home/sean/calendar_desc.json').toString()

base_url = calendar_desc.baseUrl

console.log 'Base URL: ' + base_url

#resource_kinds = _.keys calendar_desc.resources
resource_kinds = ['calendars', 'events']

for resource_kind in resource_kinds
    resource = calendar_desc.resources[resource_kind]
    _.map resource.methods, (method, method_name) ->
        console.log resource_kind + ': ' + method_name
        named_params = _.map method.parameters, (parameter, parameter_name) ->
            parameter.name = parameter_name
            return parameter
        console.log method.path
        console.log '--------------'
        named_params.filter((p) -> p.required).forEach (parameter) ->
            console.log '* ' + parameter.name
        named_params.filter((p) -> !p.required).forEach (parameter) ->
            console.log parameter.name
        console.log ''

quickAdd = calendar_desc.resources.events.methods.quickAdd

unzip = (o, name_attr='name') ->
    _.map o, (a, n) ->
        a[name_attr] = n
        return a

printl = (l, name_attr='name') ->
    l.forEach (e, i) ->
        console.log "#{ i }) #{ e[name_attr] }"

renderTemplate = (template, parameter_values) ->
    s = template
    for parameter, value of parameter_values
        console.log parameter
        s = s.replace '{'+parameter+'}', value
    return s

urlForMethod = (method, args...) ->
    parameters = unzip method.parameters
    console.log util.inspect method

    # Filter out required parameters
    req_params = parameters.filter (p) ->
        return p.required

    # Get required path parameters
    req_path_params = req_params.filter (p) ->
        return p.location == 'path'
    req_path_values = args.slice(0, req_path_params.length)

    # Build and render URL template
    url = calendar_desc.baseUrl + method.path
    url = renderTemplate url,
        # {p0: v0, p1: v1, ...}
        _.object _.pluck(req_path_params, 'name'), req_path_values

    # Get required query parameters
    req_query_params = req_params.filter (p) ->
        return p.location == 'query'
    req_query_values = args.slice(req_path_params.length)

    # Append querystring
    if req_query_values
        qs = querystring.stringify _.object _.pluck(req_query_params, 'name'), req_query_values
        url += '?' + qs

    return url

execMethod = (method, args...) ->
    url = urlForMethod method, args...
    console.log url
    # method = method.httpMethod
    # request d

execMethod(quickAdd, 'sprobertson@gmail.com', 'important thing happening at 3pm')

