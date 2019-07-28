exports.reverse = (l) ->
    reversed = []
    for i in [l.length-1..0]
        reversed.push l[i]
    return reversed

exports.toPromise = (cb_fn) ->
    return (args...) ->
        new Promise (resolve, reject) ->
            try
                cb_fn args..., (err, result) ->
                    if err
                        reject err
                    else
                        resolve result
            catch err
                reject err

exports.fromPromise = (promise_fn, cb) ->
    promise_fn()
        .then (result) ->
            cb null, result
        .catch (err) ->
            cb err

exports.toPromises = (cb_fns) ->
    as_promises = {}
    for key, cb_fn of cb_fns
        as_promises[key] = exports.toPromise cb_fn
    return as_promises

exports.errorToObj = (err) ->
    obj = {}
    Object.getOwnPropertyNames(err).forEach (key) ->
        obj[key] = err[key]
    return obj

