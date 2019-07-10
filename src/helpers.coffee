exports.reverse = (l) ->
    reversed = []
    for i in [l.length-1..0]
        reversed.push l[i]
    return reversed

exports.toPromise = (fn) ->
    return (args...) ->
        console.log '[args]', args
        new Promise (resolve, reject) ->
            console.log '[calling]', args
            fn args..., (err, result) ->
                console.log '[err,result]', err,result
                if err
                    reject err
                else
                    resolve result

exports.toPromises = (fns) ->
    as_promises = {}
    for key, fn of fns
        console.log '[key]', key
        as_promises[key] = exports.toPromise fn
    return as_promises
