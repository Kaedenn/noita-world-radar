dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/mod_settings.lua")

MOD_ID = "spell_finder"

CONF = {
    ENABLE = "enable",      -- should the UI be drawn?
    DEBUG = "debug",        -- is debugging enabled?
}

function f_enable(curr_value)
    if curr_value then return "Disable" end
    return "Enable"
end

function conf_get(key)
    return ModSettingGet(MOD_ID .. "." .. key)
end

function conf_set(key, value)
    return ModSettingSetNextValue(MOD_ID .. "." .. key, value, false)
end

-- vim: set ts=4 sts=4 sw=4:
