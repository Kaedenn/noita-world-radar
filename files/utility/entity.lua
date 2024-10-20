--[[
-- Entity-related helper functions
--]]

dofile_once("data/scripts/lib/utilities.lua")

--[[ True if entity is a child of root ]]
function is_child_of(entity, root)
    if root == nil then root = get_players()[1] end
    local seen = {} -- To protect against cycles
    local curr = EntityGetParent(entity)
    if curr == root then return true end
    while curr ~= 0 and not seen[curr] do
        if curr == root then return true end
        seen[curr] = EntityGetParent(curr)
        if curr == seen[curr] then return false end
        curr = seen[curr]
    end
end

--[[ True if the entity is an item ]]
function entity_is_item(entity)
    return EntityHasTag(entity, "item_pickup")
end

--[[ True if the entity is an enemy ]]
function entity_is_enemy(entity)
    return EntityHasTag(entity, "enemy")
end

--[[ Get the display string for an item entity ]]
function item_get_name(entity, simplify)
    local name = EntityGetName(entity) or ""
    local comps = EntityGetComponentIncludingDisabled(entity, "ItemComponent") or {}
    for _, comp in ipairs(comps) do
        local uiname = ComponentGetValue2(comp, "item_name")
        if uiname ~= "" then
            name = uiname
            break
        end
    end

    local path = EntityGetFilename(entity)
    if path:match("chest_random_super.xml") then
        local ename = GameTextGet("$item_chest_treasure_super")
        if simplify then
            return ename
        end
        return ("%s [%s]"):format(ename, "chest_random_super.xml")
    end
    if path:match("physics_greed_die.xml") then
        local ename = GameTextGet("$item_greed_die")
        if simplify then
            return ename
        end
        return ("%s [%s]"):format(ename, "physics_greed_die.xml")
    end

    if name ~= "" and name:match("^[$][%a]+_[%a%d_]+$") then
        locname = GameTextGet(name)
        name = name:gsub("^[$][%a]+_", "") -- strip "$item_" prefix
        if simplify then
            return locname
        end
        if locname:lower() ~= name:lower() then
            return ("%s [%s]"):format(locname, name)
        end
        return locname
    end

    if name == "" then
        name = path:gsub("^[%a_/]+/([%a%d_]+).xml", "%1")
    end
    return nil
end

--[[ Get the display string for an enemy entity ]]
function enemy_get_name(entity, simplify)
    local name = EntityGetName(entity) or ""
    local path = EntityGetFilename(entity)
    return animal_build_name(name, path, simplify)
end

--[[ Format the display name for the given animal ]]
function animal_build_name(name, path, simplify)
    local function path_to_string(dirname, basename)
        if dirname == basename then
            return dirname
        end
        return ("%s (%s)"):format(basename, dirname)
    end

    local locname = name
    if name ~= "" and name:match("^[$][%a]+_[%a%d_]+$") then
        locname = GameTextGet(name)
        if locname == "" then locname = name end
        name = name:gsub("^[$][%a]+_", "") -- strip "$animal_" prefix
    end
    local label = path:gsub("^[%a_/]+/([%a%d_]+).xml", "%1") -- basename
    if path:match("data/entities/animals/([%a_]+)/([%a%d_]+).xml") then
        label = path:gsub("data/entities/animals/([%a_]+)/([%a%d_]+).xml", path_to_string)
    elseif path:match("data/entities/animals/([%a%d_]+).xml") then
        label = path:gsub("data/entities/animals/([%a%d_]+).xml", "%1")
    end
    if name == "" then
        locname = label
        name = label
    end

    if simplify then
        return locname
    end

    local result = name
    local locname_u = locname:lower()
    local label_u = label:lower()
    local name_u = name:lower()
    if locname_u ~= name_u and label_u ~= name_u then
        result = ("%s [%s] [%s]"):format(locname, name, label)
    elseif locname_u ~= name_u then
        result = ("%s [%s]"):format(locname, name)
    elseif label_u ~= name_u then
        result = ("%s [%s]"):format(name, label)
    end
    return result
end

--[[ Get the display string for the entity ]]
function get_display_name(entity, simplify)
    if entity_is_item(entity) then
        return item_get_name(entity, simplify)
    end

    if entity_is_enemy(entity) then
        return enemy_get_name(entity, simplify)
    end

    -- Default behavior for "other" entity types
    local name = EntityGetName(entity) or ""
    local path = EntityGetFilename(entity)
    if path:match("data/entities/items/pickup/([%a_]+).xml") then
        path = path:gsub("data/entities/items/pickup/([%a_]+).xml", "%1")
    elseif path:match("data/entities/animals/([%a_]+)/([%a_]+).xml") then
        path = path:gsub("data/entities/animals/([%a_]+)/([%a_]+).xml", "%2 (%1)")
    elseif path:match("data/entities/animals/([%a_]+).xml") then
        path = path:gsub("data/entities/animals/([%a_]+).xml", "%1")
    end
    if name ~= "" then
        if not simplify then
            if name:lower() ~= path:lower() then
                return ("%s [%s]"):format(name, path)
            end
        end
        return name
    end
    return path
end

--[[ Get a unique identifier that can be used to look up this entity ]]
function entity_get_lookup_key(entity)
    local fname = EntityGetFilename(entity)
    if fname and fname ~= "" and fname ~= "??SAV/player.xml" then
        return fname
    end

    -- Items
    local comps = EntityGetComponentIncludingDisabled(entity, "ItemComponent") or {}
    for _, comp in ipairs(comps) do
        local name = ComponentGetValue2(comp, "item_name")
        if name and name ~= "" then
            return name
        end
    end

    -- Animals
    comps = EntityGetComponentIncludingDisabled(entity, "GameStatsComponent") or {}
    for _, comp in ipairs(comps) do
        local name = ComponentGetValue2(comp, "name")
        if name and name ~= "" then
            return name
        end
    end

    -- Cards
    comps = EntityGetComponentIncludingDisabled(entity, "ItemActionComponent") or {}
    for _, comp in ipairs(comps) do
        local name = ComponentGetValue2(comp, "action_id")
        if name and name ~= "" then
            return name
        end
    end

    print_error(("Failed to obtain lookup key for entity %d"):format(entity))
    return nil
end

--[[ Get both the current and max health of the entity ]]
function get_health(entity)
    local comps = EntityGetComponentIncludingDisabled(entity, "DamageModelComponent") or {}
    if #comps == 0 then return nil end
    local mult = MagicNumbersGetValue("GUI_HP_MULTIPLIER")
    local health = ComponentGetValue2(comps[1], "hp") * mult
    local maxhealth = ComponentGetValue2(comps[1], "max_hp") * mult
    return {health, maxhealth}
end

--[[ True if the entity entry matches the given search term ]]
function entity_match(entry, term)
    if entry.id and term == entry.id then return true end
    if entry.name then
        if term == entry.name then return true end
        if term:gsub("^%$") == entry.name:gsub("^%$") then return true end
        if term == GameTextGet(entry.name) then return true end
    end
    if entry.path and entry.path:match(term) then return true end
    return false
end

--[[ Get all entities having one of the given tags
--
-- Returns a table of {entity_id, entity_name} pairs.
--
-- Filters:
--  no_player       omit entities descending from (held by) the player
--  player          omit entities not descending from (held by) the player
--]]
function get_with_tags(tags, filters, simplify)
    if not filters then filters = {} end
    local entities = {}
    for _, tag in ipairs(tags) do
        for _, entity in ipairs(EntityGetWithTag(tag)) do
            if not entity or entity == 0 then goto continue end
            if not EntityGetIsAlive(entity) then goto continue end
            local is_held = is_child_of(entity, nil)
            if filters.no_player and is_held then goto continue end
            if filters.player and not is_held then goto continue end
            entities[entity] = get_display_name(entity, simplify)
            ::continue::
        end
    end
    local results = {}
    for entid, name in pairs(entities) do
        table.insert(results, {entid, name})
    end
    return results
end

--[[ Return the distance (in pixels) between two entities
-- Reference defaults to the player if nil ]]
function distance_from(entity, reference)
    if reference == nil then reference = get_players()[1] end
    local rx, ry = EntityGetTransform(reference)
    local ex, ey = EntityGetTransform(entity)
    if rx == nil or ry == nil then return 0 end
    if ex == nil or ey == nil then return 0 end
    return math.sqrt(math.pow(rx-ex, 2) + math.pow(ry-ey, 2))
end

-- vim: set ts=4 sts=4 sw=4:
