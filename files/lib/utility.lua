--[[ Assorted utility functions that don't belong anywhere else ]]

--[[ Collect {id, name} pairs into {name, {id...}} sets ]]
function aggregate(entries)
    local byname = {}
    for _, entry in ipairs(entries) do
        local entity = entry[1] or entry.entity
        local name = entry[2] or entry.name
        if name ~= nil then
            if not byname[name] then
                byname[name] = {}
            end
            table.insert(byname[name], entity)
        end
    end
    local results = {}
    for name, entities in pairs(byname) do
        table.insert(results, {name, entities})
    end
    table.sort(results, function(left, right)
        local lname, rname = left[1], right[1]
        return lname < rname
    end)
    return results
end

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
        if item == entry then
            return true
        end
    end
    return false
end

--[[ Add a bunch of items to the end of a table, in-place ]]
function table_extend(tbl, values)
    for _, value in ipairs(values) do
        table.insert(tbl, value)
    end
end

--[[ Build a new table as a concatenation of two or more tables ]]
function table_concat(...)
    local result = {}
    for _, tbl in ipairs({...}) do
        table_extend(result, tbl)
    end
    return result
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

--[[ Return the first non-nil and non-empty value in the table, or nil ]]
function first_of(tbl)
    for _, entry in ipairs(tbl) do
        if entry and entry ~= "" then
            return entry
        end
    end
    return nil
end

--[[ Generate a traceback (HACK) ]]
function generate_traceback()
    print_error("Generating traceback via SetPlayerSpawnLocation()...")
    SetPlayerSpawnLocation()
end

-- vim: set ts=4 sts=4 sw=4:
