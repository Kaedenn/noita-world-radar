--[[
-- Material-related helper functions
--]]

nxml = dofile_once("mods/world_radar/files/lib/nxml.lua")
_material_cache = nil

local function _parse_cell_data(entry)
    local result = {}
    for key, val in pairs(entry.attr) do
        result[key] = val
    end
    for _, child in ipairs(entry.children) do
        -- TODO: children
    end
    return result
end

local function _parse_cell_data_child(entry)
    local result = {}
    for key, val in pairs(entry.attr) do
        if key == "_parent" then
            result.parent = val
        elseif key == "_inherit_reactions" then
            result.inherit_reactions = val
        else
            result[key] = val
        end
    end

    for _, child in ipairs(entry.children) do
        result[child.name] = child -- TODO: parse
    end

    return result
end

local function _parse_reaction(entry)
    local inputs = {}
    local outputs = {}
    local probability = tonumber(entry.attr.probability) or entry.attr.probability
    for tag, value in pairs(entry.attr) do
        local side, idx = tag:match("([%w]+put)_cell([%d]+)")
        if side == "input" then
            table.insert(inputs, {idx=idx, value=value})
        elseif side == "output" then
            table.insert(outputs, {idx=idx, value=value})
        end
    end
    table.sort(inputs, function(left, right) return left.idx < right.idx end)
    table.sort(outputs, function(left, right) return left.idx < right.idx end)

    local mat_from = {}
    for _, ientry in ipairs(inputs) do
        table.insert(mat_from, ientry.value)
    end

    local mat_to = {}
    for _, oentry in ipairs(outputs) do
        table.insert(mat_to, oentry.value)
    end

    return mat_from, mat_to, probability
end

--[[ Requirement reaction: input1 becomes output1+ unless input2+ are present ]]
local function _parse_req_reaction(entry)
    local input = entry.attr.input_cell1
    local input_req = entry.attr.input_cell2
    local outputs = {entry.attr.output_cell1, entry.attr.output_cell2}
    local probability = tonumber(entry.attr.probability)
    return {
        input = input,
        input_req = input_req,
        outputs = outputs,
        probability = probability,
    }
end

--[[ Merge a CellDataChild's parent into the CellDataChild entry ]]
local function merge_celldata(entry, parent)
    local merged = {}
    for key, val in pairs(parent) do
        merged[key] = val
    end
    for key, val in pairs(entry) do
        if key == "tags" then
            local tags = parent.tags .. "," .. val
            local seen = {}
            local final = {}
            for tag in tags:gmatch("%[[^%]]+%]") do
                if not seen[tag] then
                    table.insert(final, tag)
                    seen[tag] = tag
                end
            end
            merged.tags = table.concat(final, ",")
        else
            merged[key] = val
        end
    end

    for key, val in pairs(merged) do
        entry[key] = val
    end
end

--[[ Parse materials.xml ]]
function load_materials_xml()
    local text = ModTextFileGetContent("data/materials.xml")
    local mats = nxml.parse(text)

    local cells = {}
    local cell_children = {}
    local reactions = {}
    local req_reactions = {}

    for idx, entry in ipairs(mats.children) do
        local tag = entry.name
        if tag == "CellData" then
            table.insert(cells, _parse_cell_data(entry))
        elseif tag == "CellDataChild" then
            table.insert(cell_children, _parse_cell_data_child(entry))
        elseif tag == "Reaction" then
            local m_from, m_to, prob = _parse_reaction(entry)
            table.insert(reactions, {
                inputs = m_from,
                outputs = m_to,
                probability = prob,
            })
        elseif tag == "ReqReaction" then
            table.insert(req_reactions, _parse_req_reaction(entry))
        else
            print_error(("Invalid materials.xml tag %d: %s"):format(idx, entry))
        end
    end

    local cells_byname = {}
    for _, entry in ipairs(cells) do
        cells_byname[entry.name] = entry
    end

    -- CellDataChild entries we couldn't parse, likely due to depending on
    -- entries defined below it.
    local defer_cells = {}
    local last_children_count = 0

    -- Merge parent/child material definitions
    while #cell_children > 0 and #cell_children ~= last_children_count do
        for _, entry in ipairs(cell_children) do
            local parent = cells_byname[entry.parent]
            if not parent then
                table.insert(defer_cells, entry)
            else
                merge_celldata(entry, parent)
                cells_byname[entry.name] = entry
                table.insert(cells, entry)
            end
        end
        cell_children = defer_cells
        last_children_count = #cell_children
        defer_cells = {}
    end

    if #defer_cells > 0 then
        for _, entry in ipairs(defer_cells) do
            print_error(("Cell %s has invalid parent %s"):format(
                entry.name, entry.parent))
        end
    end

    return {
        materials = cells,
        materials_byname = cells_byname,
        reactions = reactions,
        req_reactions = req_reactions,
    }
end

--[[ Load and cache the materials.xml file ]]
function get_material_data()
    if not _material_cache then
        _material_cache = load_materials_xml()
    end
    return _material_cache
end

--[[ Get data about a material ]]
function get_material_data_for(matid)
    local mcache = get_material_data()
    if mcache.materials_byname[matid] then
        return mcache.materials_byname[matid]
    end
    for _, material in ipairs(mcache.materials) do
        if material.name == matid then return material end
        if material.ui_name == matid then return material end
    end
    return {}
end

--[[ True if the material matches the given condition ]]
function match_material(material_name, condition)
    if material_name == condition then return true end
    if condition:match("^%[.*%]$") then
        local mtype = CellFactory_GetType(material_name)
        if not mtype then return false end
        local mtags = CellFactory_GetTags(mtype)
        if not mtags then return false end
        for _, mtag in ipairs(mtags) do
            if mtag == condition then
                return true
            end
        end
    end
    return false
end

--[[ Determine if the two materials react and, if so, return their outputs
-- Returns nil or {output, probability} where
-- output is a table of strings
-- probability is a number; higher means more probable/efficient conversion
--]]
function check_material_reaction(material1, material2)
    local data = get_material_data()
    for _, reaction in ipairs(data.reactions) do
        local prob = reaction.probability
        if #reaction.inputs ~= 2 then
            goto continue
        end
        local input1, input2 = unpack(reaction.inputs)
        local matches = (
            (match_material(material1, input1) and match_material(material2, input2))
            or
            (match_material(material2, input1) and match_material(material1, input2))
        )
        if matches then
            return {reaction.outputs, reaction.probability}
        end
        ::continue::
    end
    return nil
end

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
