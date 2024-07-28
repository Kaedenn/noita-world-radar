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

--[[ True if the given table is truly empty ]]
function table_empty(tbl)
    if tbl == nil then return true end
    if #tbl > 0 then return false end
    local empty = true
    for key, val in pairs(tbl) do
        empty = false
    end
    return empty
end

--[[ Determine if the given table includes the given entry ]]
function table_has_entry(tbl, entry)
    for _, item in ipairs(tbl) do
        if item.path and entry.path and item.path == entry.path then
            return true
        end
        if item.id == entry.id and item.name == entry.name then
            return true
        end
    end
    return false
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
