--[[ Assorted utility functions that don't belong anywhere else ]]

--[[ Empty a table in-place ]]
function table_clear(tbl)
    for key, val in pairs(tbl) do
        tbl[key] = nil
    end
    while #tbl > 0 do
        table.remove(tbl, 1)
    end
end

--[[ Split a string into parts ]]
function split_string(inputstr, sep)
    sep = sep or "%s"
    local tokens = {}
    for str in string.gmatch(inputstr, "[^"..sep.."]+") do
        table.insert(tokens, str)
    end
    return tokens
end

-- vim: set ts=4 sts=4 sw=4:
