--[[
-- Biome-related helper functions
--]]

--[[ True if the given biome normally has the given modifier ]]
function biome_is_default(biome_name, modifier)
    if modifier == nil or modifier == "" then return true end
    local default_map = {
        ["alchemist_secret"] = "$biomemodifierdesc_fog_of_war_clear_at_player",
        ["desert"] = "$biomemodifierdesc_hot",
        ["fungicave"] = "$biomemodifierdesc_moist",
        ["lavalake"] = "$biomemodifierdesc_hot",
        ["mountain_floating_island"] = "$biomemodifierdesc_freezing",
        ["mountain_top"] = "$biomemodifierdesc_freezing",
        ["pyramid_entrance"] = "$biomemodifierdesc_hot",
        ["pyramid_left"] = "$biomemodifierdesc_hot",
        ["pyramid_right"] = "$biomemodifierdesc_hot",
        ["pyramid_top"] = "$biomemodifierdesc_hot",
        ["rainforest"] = "$biomemodifierdesc_fungal",
        ["rainforest_open"] = "$biomemodifierdesc_fungal",
        ["wandcave"] = "$biomemodifierdesc_fog_of_war_clear_at_player",
        ["watercave"] = "$biomemodifierdesc_moist",
        ["winter"] = "$biomemodifierdesc_freezing",
        ["winter_caves"] = "$biomemodifierdesc_freezing",
        ["wizardcave"] = "$biomemodifierdesc_fog_of_war_clear_at_player",
    }
    if default_map[biome_name] == modifier then
        return true
    end
    return false
end

--[[ Get a biome modifier by name ]]
function biome_modifier_get(mod_name)
    -- luacheck: globals biome_modifiers
    dofile("data/scripts/biome_modifiers.lua")
    for _, entry in ipairs(biome_modifiers) do
        if entry.ui_description == mod_name then
            return entry
        end
    end
    return nil
end

-- vim: set ts=4 sts=4 sw=4:
