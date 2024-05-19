dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/mod_settings.lua")

-- luacheck: globals MOD_SETTING_SCOPE_RUNTIME mod_settings_get_version mod_settings_gui_count mod_settings_gui mod_settings_update

-- Available functions:
-- ModSettingSetNextValue(setting_id, next_value, true/false)
-- ModSettingSet(setting_id, new_value)

-- Available if desired
--function mod_setting_changed_callback(mod_id, gui, in_main_menu, setting, old_value, new_value)
--end

MOD_ID = "spell_finder"

mod_settings_version = 1
mod_settings = {
    {
        id = "enable",
        ui_name = "Enable UI",
        ui_description = "Uncheck this to hide the UI",
        value_default = true,
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
        id = "debug",
        ui_name = "Enable Debugging",
        ui_description = "Enable debugging output",
        value_default = false,
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
}

function ModSettingsUpdate(init_scope)
    local old_version = mod_settings_get_version(MOD_ID)
    mod_settings_update(MOD_ID, mod_settings, init_scope)
end

function ModSettingsGuiCount()
    return mod_settings_gui_count(MOD_ID, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
    mod_settings_gui(MOD_ID, mod_settings, gui, in_main_menu)
end

-- vim: set ts=4 sts=4 sw=4:
