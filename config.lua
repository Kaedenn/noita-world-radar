
MOD_ID = "world_radar"

CONF = {
    ENABLE = "enable",
    DEBUG = "debug",

    -- Remove spell, item, or material on pickup
    REMOVE_SPELL = "remove_found_spell",
    REMOVE_ITEM = "remove_found_item",
    REMOVE_MATERIAL = "remove_found_material",

    SHOW_IMAGES = "show_images",
    SHOW_COLOR = "color",
    SHOW_CLOSED = "show_closed",
    SIMPLE_NAMES = "simple_names",
    CHEST_PREDICTION = "chest_prediction",
    CHEST_SCANNING = "chest_scanning",
    POS_RELATIVE = "pos_relative",

    RADAR_DISTANCE = "radar_distance",
    RADAR_RANGE = "radar_range",
    RADAR_RANGE_MANUAL = "radar_range_manual",
    GUI_ANCHOR = "gui_anchor",

    ORB_ENABLE = "orb_enable",
    ORB_LIMIT = "orb_limit",
    ORB_DISPLAY = "orb_display",
}

function conf_get(key)
    return ModSettingGet(MOD_ID .. "." .. key)
end

function conf_set(key, value)
    return ModSettingSetNextValue(MOD_ID .. "." .. key, value, false)
end

function conf_toggle(key)
    conf_set(key, not conf_get(key))
end

-- vim: set ts=4 sts=4 sw=4:
