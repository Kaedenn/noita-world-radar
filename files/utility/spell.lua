--[[
-- Spell-and-wand-related helper functions
--]]

dofile_once("data/scripts/gun/gun_enums.lua")
-- luacheck: globals ACTION_TYPE_PROJECTILE ACTION_TYPE_STATIC_PROJECTILE ACTION_TYPE_MODIFIER ACTION_TYPE_DRAW_MANY ACTION_TYPE_MATERIAL ACTION_TYPE_OTHER ACTION_TYPE_UTILITY ACTION_TYPE_PASSIVE

local spell_cache = nil

--[[ Get the spell for the given card ]]
function card_get_spell(card)
    local action = EntityGetComponentIncludingDisabled(card, "ItemActionComponent")
    if not action or #action ~= 1 then
        print_error(("Entity %s lacks ItemActionComponent"):format(tostring(card)))
        return nil
    end
    return ComponentGetValue2(action[1], "action_id")
end

--[[ Get all of the spells on the given wand ]]
function wand_get_spells(entity)
    local cards = EntityGetAllChildren(entity) or {}
    local spells = {}
    for _, card in ipairs(cards) do
        local spell = card_get_spell(card)
        if spell ~= nil then
            table.insert(spells, {card, spell})
        end
    end
    return spells
end

--[[ True if the spell is an Always Cast ]]
function spell_is_always_cast(spell)
    local icomps = EntityGetComponentIncludingDisabled(spell, "ItemComponent")
    if not icomps or #icomps < 1 then
        print_error(("Entity %s lacks ItemComponent"):format(tostring(spell)))
        return nil
    end
    for _, icomp in ipairs(icomps) do
        local is_ac = ComponentGetValue2(icomp, "permanently_attached")
        -- local ix, iy = ComponentGetValue2(icomp, "inventory_slot")
        if is_ac then return true end
    end
    return false
end

--[[ Obtain the spell table for the given spell ID ]]
function spell_get_data(spell)
    if not spell_cache then
        spell_cache = {}
        dofile_once("data/scripts/gun/gun_actions.lua")
        -- luacheck: globals actions
        for _, entry in ipairs(actions) do
            spell_cache[entry.id] = entry
        end
    end
    if spell and spell_cache[spell] then
        return spell_cache[spell]
    end
    return {}
end

--[[ Obtain the (unlocalized) name of the given spell ID ]]
function spell_get_name(spell)
    local action = spell_get_data(spell)
    return action.name
end

--[[ Obtain the display name for the given action ]]
function action_lookup(action)
    local action_types = {}
    action_types[ACTION_TYPE_PROJECTILE]  = "PROJECTILE"
    action_types[ACTION_TYPE_STATIC_PROJECTILE] = "STATIC_PROJECTILE"
    action_types[ACTION_TYPE_MODIFIER]    = "MODIFIER"
    action_types[ACTION_TYPE_DRAW_MANY]   = "DRAW_MANY"
    action_types[ACTION_TYPE_MATERIAL]    = "MATERIAL"
    action_types[ACTION_TYPE_OTHER]       = "OTHER"
    action_types[ACTION_TYPE_UTILITY]     = "UTILITY"
    action_types[ACTION_TYPE_PASSIVE]     = "PASSIVE"
    return action_types[action] or "invalid"
end

-- vim: set ts=4 sts=4 sw=4:
