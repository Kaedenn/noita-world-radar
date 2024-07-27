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

    local content_map = {}
    local content_list = {}
    for _, entry in ipairs(entries) do
        local matid, count = unpack(entry)
        local matname = CellFactory_GetName(matid)
        content_map[matname] = count
        table.insert(content_list, {matname, count})
    end
    return content_map, content_list
end

--[[ Determine the overall capacity for the given container ]]
function container_get_capacity(entid)
    local total_capacity = tonumber(GlobalsGetValue("EXTRA_POTION_CAPACITY_LEVEL", "1000")) or 1000
    if EntityHasTag(entid, "extra_potion_capacity") then
        local comp = EntityGetFirstComponentIncludingDisabled(entid, "MaterialSuckerComponent")
        if comp ~= nil then
            total_capacity = ComponentGetValue(comp, "barrel_size")
        end
    end
    return total_capacity
end

--[[ Easily obtain all of the materials ]]
function generate_material_tables()
    local tables = {
        {"liquid", CellFactory_GetAllLiquids()},
        {"sand", CellFactory_GetAllSands()},
        {"gas", CellFactory_GetAllGases()},
        {"fire", CellFactory_GetAllFires()},
        {"solid", CellFactory_GetAllSolids()},
    }
    local result = {}
    for _, table_pair in ipairs(tables) do
        local tname, tentries = unpack(table_pair)
        for _, mat in ipairs(tentries) do
            local id = CellFactory_GetType(mat)
            local uiname = CellFactory_GetUIName(id)
            table.insert(result, {
                kind = tname,
                id = id,
                name = mat,
                uiname = uiname,
                locname = GameTextGet(uiname),
                icon = material_get_icon(mat),
                tags = CellFactory_GetTags(id),
            })
        end
    end
    return result
end

--[[ Get the (probable) path to the material icon ]]
function material_get_icon(matname)
    return ("data/generated/material_icons/%s.png"):format(matname)
end

-- vim: set ts=4 sts=4 sw=4:
