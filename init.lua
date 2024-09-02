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
    if KPanel and KPanel:current() ~= nil then
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
            KPanel:draw_closed(imgui)
        end
    elseif show_closed then
        KPanel:draw_closed(imgui)
    end

end

-- vim: set ts=4 sts=4 sw=4 tw=79:
