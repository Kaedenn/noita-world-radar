--[[
-- Material-related helper functions
--]]

--[[ Get the contents of a given container (flask/pouch) ]]
function container_get_contents(entity)
    local comps = EntityGetComponentIncludingDisabled(entity, "MaterialInventoryComponent")
    if not comps or #comps == 0 then return {} end
    local comp = comps[1]
    if not comp or comp == 0 then return {} end

    local entries = {}
    for idx, count in ipairs(ComponentGetValue2(comp, "count_per_material_type")) do
        if count ~= 0 then
            table.insert(entries, {idx-1, count})
        end
    end
    -- Sort descending
    table.sort(entries, function(left, right) return left[2] > right[2] end)

    local results = {}
    for _, entry in ipairs(entries) do
        local matid, count = unpack(entry)
        results[CellFactory_GetName(matid)] = count
    end
    return results
end

--[[ Get the (probable) path to the material icon ]]
function material_get_icon(matname)
    return ("data/generated/material_icons/%s.png"):format(matname)
end

-- vim: set ts=4 sts=4 sw=4:
