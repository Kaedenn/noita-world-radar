dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/lib/mod_settings.lua")
-- luacheck: globals MOD_SETTING_SCOPE_RUNTIME

-- Available if desired
-- mod_setting_change_fn(mod_id, gui, in_main_menu, setting, old_value, new_value)
-- mod_setting_image(mod_id, gui, in_main_menu, im_id, setting)
-- mod_setting_ui_fn(mod_id, gui, in_main_menu, im_id, setting)

MOD_ID = "world_radar"

function wr_range_manual(mod_id, gui, in_main_menu, im_id, setting)
    -- luacheck: globals mod_setting_text
    if ModSettingGetNextValue(MOD_ID .. ".radar_range") == "manual" then
        mod_setting_text(mod_id, gui, in_main_menu, im_id, setting)
    end
end

mod_settings_version = 1
mod_settings = {
    {
        category_id = "general_settings",
        ui_name = "General Settings",
        foldable = true,
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
                id = "remove_found_item",
                ui_name = "Remove Item on Pickup",
                ui_description = "Remove an item from the scanner list when you pick up the item.",
                value_default = false,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "remove_found_material",
                ui_name = "Remove Material on Pickup",
                ui_description = "Remove a material from the scanner list when you pick up the material.",
                value_default = false,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "radar_range",
                ui_name = "Scanner Range",
                ui_description = "How far away should the radar scan?",
                value_default = "infinite",
                values = {
                    {"manual", "Manual"},
                    {"onscreen", "On Screen"},
                    {"perk_range", "Same as Radar Perks"},
                    {"world", "Current World"},
                    {"infinite", "All Loaded Chunks (Default)"},
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "radar_range_manual",
                ui_name = "Scanner Range",
                ui_description = "How far away should the radar scan?",
                value_default = "51200",
                allowed_characters = "0123456789",
                ui_fn = wr_range_manual,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
        },
    },

    {
        category_id = "display_settings",
        ui_name = "Display Settings",
        foldable = true,
        settings = {
            {
                id = "show_images",
                ui_name = "Show Images",
                ui_description = "Show images with the text.",
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
            {
                id = "show_closed",
                ui_name = "Show When Closed",
                ui_description = "Show on-screen text even if the UI is closed or disabled.",
                value_default = false,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "radar_distance",
                ui_name = "Radar Sprite Distance",
                ui_description = "How far away from the player are the radar icons drawn? (perks use 20, default is 40).",
                value_default = 40,
                value_min = 5,
                value_max = 50,
                value_display_multiplier = 1,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "pos_relative",
                ui_name = "Relative Positions",
                ui_description = "Should coordinates be relative instead of absolute?",
                value_default = false,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            --[[
            {
                id = "gui_anchor",
                ui_name = "Text Location",
                ui_description = "Where should the on-screen text be drawn?",
                value_default = "bottom_left",
                values = {
                    {"top_left", "Top Left (Below Wands)"},
                    {"bottom_left", "Bottom Left (Default)"},
                    {"top_right", "Top Right (Below Health)"},
                    {"bottom_right", "Bottom Right"},
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            --]]
        },
    },

    {
        category_id = "orb_settings",
        ui_name = "Orb Radar Settings",
        foldable = true,
        settings = {
            {
                id = "orb_enable",
                ui_name = "Orb Radar",
                ui_description = [[Add icons around the player indicating where the orbs are.
This will tell you where the nearest (uncollected) orbs are.

Note: Orb locations are only approximate! Due to how the game handles
orb spawns, orb locations can be off by at most 256 pixels (or about
half a screen).]],
                value_default = false,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "orb_limit",
                ui_name = "Orb Selection",
                ui_description = "Which orbs should be considered for display?",
                value_default = "world",
                values = {
                    {"world", "Current World Only"},
                    {"main", "Main World Only"},
                    {"parallel", "Parallel Worlds Only"},
                    {"both", "Both Main and Parallel"},
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "orb_display",
                ui_name = "Orb Display",
                ui_description = "How many orbs should be displayed?",
                value_default = 1,
                value_min = 1,
                value_max = 33,
                value_display_multiplier = 1,
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
        },
    },
}

function wr_get_setting(name, setting_list)
    local settings = setting_list or mod_settings or {}
    for idx, setting in ipairs(settings) do
        if setting.id == name then
            return setting
        end
        if setting.settings then
            result = wr_get_setting(name, setting.settings)
            if result then return result end
        end
    end
    return nil
end

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
