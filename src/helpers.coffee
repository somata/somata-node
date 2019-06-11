exports.reverse = (l) ->
    reversed = []
    for i in [l.length-1..0]
        reversed.push l[i]
    return reversed
