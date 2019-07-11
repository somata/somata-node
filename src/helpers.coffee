exports.reverse = (l) ->
    reversed = []
    for i in [l.length-1..0]
        reversed.push l[i]
    return reversed

exports.toPromise = (fn) ->
    return (args...) ->
        new Promise (resolve, reject) ->
            try
                fn args..., (err, result) ->
                    if err
                        reject err
                    else
                        resolve result
            catch err
                reject err

exports.toPromises = (fns) ->
    as_promises = {}
    for key, fn of fns
        as_promises[key] = exports.toPromise fn
    return as_promises
