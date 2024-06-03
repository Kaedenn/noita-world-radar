--[[
-- Spell-and-wand-related helper functions
--]]

local spell_cache = nil

--[[ Get the spell for the given card ]]
function card_get_spell(card)
    local action = EntityGetComponentIncludingDisabled(card, "ItemActionComponent")
    if #action == 1 then
        return ComponentGetValue2(action[1], "action_id")
    end
    return nil
end

--[[ Get all of the spells on the given wand ]]
function wand_get_spells(entity)
    local cards = EntityGetAllChildren(entity) or {}
    local spells = {}
    for _, card in ipairs(cards) do
        local spell = card_get_spell(card)
        if spell ~= nil then
            table.insert(spells, spell)
        end
    end
    return spells
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
    return spell_cache[spell] or {}
end

--[[ Obtain the (unlocalized) name of the given spell ID ]]
function spell_get_name(spell)
    local action = spell_get_data(spell)
    return action.name
end

-- vim: set ts=4 sts=4 sw=4:
