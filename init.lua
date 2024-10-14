--[[ World Radar
--
-- This mod displays the following information:
--  Biome modifier list
--  Nearby (actually, all loaded) enememies
--  Nearby items/flasks/pouches/chests
--
--  Nearby configured enemies
--  Nearby configured spells or wands containing configured spells
--  Nearby configured items
--  Nearby configured material containers
--]]

dofile_once("mods/world_radar/config.lua")
dofile_once("mods/world_radar/files/utility/material.lua")
dofile_once("mods/world_radar/files/lib/profiler.lua")

MaterialTables = {}
KPanelLib = dofile("mods/world_radar/files/panel.lua")
KPanel = nil
imgui = nil

function do_print_error(...)
    local args = {...}
    local strings = {}
    for _, arg in ipairs(args) do
        table.insert(strings, tostring(arg))
    end
    local message = table.concat(strings, " ")
    GamePrint(message)
    print_error(message)
end

function do_call(func, ...)
    local res, ret = pcall(func, ...)
    if not res then do_print_error(ret) end
    return res, ret
end

function _build_menu_bar_gui()
    if imgui.BeginMenuBar() then
        if KPanel and KPanel.build_menu then
            do_call(KPanel.build_menu, KPanel, imgui)
        end
        imgui.EndMenuBar()
    end
end

function _build_gui()
    if KPanel then
        KPanel:draw(imgui)
    end
end

--[[ Load the material table.
-- Because fungal shifts change the value returned by CellFactory_GetUIName(),
-- we need to cache these values after the cell factory is initialized but
-- before the world state (and thus the shift log) is loaded ]]
function OnBiomeConfigLoaded()
    MaterialTables = generate_material_tables()
end

function OnModPostInit()
end

function OnPlayerSpawned(player_entity)
    if KPanel and KPanel.initialized then
        KPanel:on_player_spawned(player_entity)
    end
end

function OnWorldPostUpdate()
    if not imgui then
        imgui = load_imgui({version="1.17.0", mod=MOD_ID})
    end

    if not KPanel then
        KPanel = KPanelLib:new()
    end
    if not KPanel then
        GamePrint("Failed KPanel:new()")
    elseif not KPanel.init then
        GamePrint("Failed KPanel:new(); init not defined")
    elseif not KPanel.initialized then
        KPanel:init(nil, {["materials"]=MaterialTables})
        KPanel:set("info")
    end

    local profile = GlobalsGetValue("kae_profile")
    Profiler:start("main")
    local show_closed = conf_get(CONF.SHOW_CLOSED)
    if conf_get(CONF.ENABLE) then
        if imgui.Begin("World Information Scanner###world_radar", nil, bit.bor(
            imgui.WindowFlags.HorizontalScrollbar,
            imgui.WindowFlags.MenuBar))
        then
            do_call(_build_menu_bar_gui)
            do_call(_build_gui)
            imgui.End()
        elseif KPanel then
            do_call(KPanel.draw_closed, KPanel, imgui)
        end
    elseif show_closed then
        do_call(KPanel.draw_closed, KPanel, imgui)
    end
    local end_time = GameGetRealWorldTimeSinceStarted()
    if profile ~= "" then
        local measure = Profiler:tick("main")
        local time_str = ("%3dus"):format(1000000 * measure)
        KPanel:draw_line_onscreen(time_str, {"1", "1"}, true, true, {}, {
            monospace = true,
        })
    end
end

-- vim: set ts=4 sts=4 sw=4 tw=79:
