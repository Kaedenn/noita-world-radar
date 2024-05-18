--[[
-- Spell-and-wand-related helper functions
--]]

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

-- vim: set ts=4 sts=4 sw=4:
