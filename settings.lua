dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/mod_settings.lua")
-- luacheck: globals MOD_SETTING_SCOPE_RUNTIME

-- Available if desired
-- mod_setting_changed_callback(mod_id, gui, in_main_menu, setting, old_value, new_value)
-- mod_setting_image(mod_id, gui, in_main_menu, im_id, setting)

MOD_ID = "world_radar"

mod_settings_version = 1
mod_settings = {
    {
        category_id = "general_settings",
        ui_name = "General Settings",
        settings = {
            {
                id = "enable",
                ui_name = "Enable UI",
                ui_description = "Is the UI drawn to the screen? Closing the UI unchecks this setting.",
                value_default = true,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "debug",
                ui_name = "Enable Debugging",
                ui_description = "Enable additional diagnostic output, including entity locations and more.",
                value_default = false,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "remove_found_spell",
                ui_name = "Remove Spell on Pickup",
                ui_description = "Remove a spell from the scanner list when you pick up the spell.",
                value_default = true,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "remove_found_material",
                ui_name = "Remove Material on Pickup",
                ui_description = "Remove a material from the scanner list when you pick up the material.",
                value_default = false,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
        },
    },

    {
        category_id = "display_settings",
        ui_name = "Display Settings",
        settings = {
            {
                id = "show_images",
                ui_name = "Show Images",
                ui_description = "Show image next to spell, item, and enemy entries.",
                value_default = true,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "color",
                ui_name = "Color Display",
                ui_description = "Adds color to the text displayed.",
                value_default = true,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
        },
    },
}

-- This function is called to ensure the correct setting values are visible to
-- the game via ModSettingGet(). your mod's settings don't work if you don't
-- have a function like this defined in settings.lua.
-- This function is called:
--    - when entering the mod settings menu (MOD_SETTINGS_SCOPE_ONLY_SET_DEFAULT)
--    - before mod initialization when starting a new game (MOD_SETTING_SCOPE_NEW_GAME)
--    - when entering the game after a restart (MOD_SETTING_SCOPE_RESTART)
--    - at the end of an update when mod settings have been changed via
--      ModSettingsSetNextValue() and the game is unpaused (MOD_SETTINGS_SCOPE_RUNTIME)
function ModSettingsUpdate(init_scope)
    -- luacheck: globals mod_settings_get_version mod_settings_update
    local old_version = mod_settings_get_version(MOD_ID)
    mod_settings_update(MOD_ID, mod_settings, init_scope)
end

-- This function should return the number of visible setting UI elements.
-- Your mod's settings wont be visible in the mod settings menu if this function
-- isn't defined correctly.
-- If your mod changes the displayed settings dynamically, you might need to
-- implement custom logic.
-- The value will be used to determine whether or not to display various UI
-- elements that link to mod settings.
-- At the moment it is fine to simply return 0 or 1 in a custom implementation,
-- but we don't guarantee that will be the case in the future.
-- This function is called every frame when in the settings menu.
function ModSettingsGuiCount()
    -- luacheck: globals mod_settings_gui_count
    return mod_settings_gui_count(MOD_ID, mod_settings)
end

-- This function is called to display the settings UI for this mod. Your mod's
-- settings wont be visible in the mod settings menu if this function isn't
-- defined correctly.
function ModSettingsGui(gui, in_main_menu)
    -- luacheck: globals mod_settings_gui
    mod_settings_gui(MOD_ID, mod_settings, gui, in_main_menu)
end

-- vim: set ts=4 sts=4 sw=4:
