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

-- vim: set ts=4 sts=4 sw=4:
