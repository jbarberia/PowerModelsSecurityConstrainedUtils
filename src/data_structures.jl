
"""
Get an easy mapping for posterior analysis of data in a DataFrame.

function to_dataframe(d::Dict{String, Any})

usages:
    df = to_dataframe(data["bus"])
"""
function to_dataframe(d::Dict{String, Any})
    df = DataFrame(values(d))
    return df
end