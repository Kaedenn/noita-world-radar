--[[
-- Biome-related helper functions
--]]

nxml = dofile_once("mods/world_radar/files/lib/nxml.lua")

BIOME_EMPTY = "_EMPTY_"

local _ModTextFileGetContent = ModTextFileGetContent

--[[ Get biome information (name, path, modifier) for each biome ]]
function get_biome_data()
    local biomes_xml = nxml.parse(_ModTextFileGetContent("data/biome/_biomes_all.xml"))
    local biomes = {}
    for _, bdef in ipairs(biomes_xml.children) do
        local biome_path = bdef.attr.biome_filename
        local biome_name = biome_path:match("^data/biome/(.*).xml$")
        local biome_uiname = BiomeGetValue(biome_path, "name")
        if biome_uiname == "_EMPTY_" then
            biome_uiname = biome_name
        end
        local modifier = BiomeGetValue(biome_path, "mModifierUIDescription")
        local mod_data = biome_modifier_get(modifier) or {}
        local show = true
        if biome_is_default(biome_name, modifier) then show = false end
        if biome_is_common(biome_name, modifier) then show = false end
        if biome_name == "rainforest_open" then show = false end
        if show then
            biomes[biome_name] = {
                name = biome_name,
                uiname = biome_uiname,
                path = biome_path,
                modifier = modifier,
                probability = mod_data.probability or 0,
                text = GameTextGet(modifier),
            }
        end
    end
    return biomes
end

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

--[[ True if the biome commonly has the given modifier ]]
function biome_is_common(biome_name, modifier)
    if modifier == nil or modifier == "" then return false end
    local common_map = {
        ["lake_statue"] = {"$biomemodifierdesc_moist"},
    }
    if common_map[biome_name] then
        for _, mod in ipairs(common_map[biome_name]) do
            if mod == modifier then
                return true
            end
        end
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
