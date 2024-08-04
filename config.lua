dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/mod_settings.lua")

MOD_ID = "world_radar"

CONF = {
    ENABLE = "enable",
    DEBUG = "debug",
    REMOVE_SPELL = "remove_found_spell",
    REMOVE_ITEM = "remove_found_item",
    REMOVE_MATERIAL = "remove_found_material",
    SHOW_IMAGES = "show_images",
    SHOW_COLOR = "color",
    SHOW_CLOSED = "show_closed",
    RADAR_DISTANCE = "radar_distance",

    RADAR_RANGE = "radar_range",
    RADAR_RANGE_MANUAL = "radar_range_manual",
    GUI_ANCHOR = "gui_anchor",
}

function conf_get(key)
    return ModSettingGet(MOD_ID .. "." .. key)
end

function conf_set(key, value)
    return ModSettingSetNextValue(MOD_ID .. "." .. key, value, false)
end

-- vim: set ts=4 sts=4 sw=4:
