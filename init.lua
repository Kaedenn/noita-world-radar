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
--
--]]

dofile_once("data/scripts/lib/mod_settings.lua")

dofile_once("mods/world_radar/config.lua")
-- luacheck: globals MOD_ID CONF conf_get
dofile_once("mods/world_radar/files/utility/material.lua")
-- luacheck: globals generate_material_tables

MaterialTables = {}
KPanelLib = dofile("mods/world_radar/files/panel.lua")
KPanel = nil
imgui = nil

function _build_menu_bar_gui()
    if imgui.BeginMenuBar() then
        local function do_build_menu()
            if KPanel and KPanel.build_menu then
                KPanel:build_menu(imgui)
            end
        end
        local pres, pval = pcall(do_build_menu)
        if not pres then GamePrint(("do_build('%s')"):format(pval)) end

        imgui.EndMenuBar()
    end
end

function _build_gui()
    if not KPanel then
        GamePrint("_build_gui: KPanel not defined")
    elseif KPanel:current() ~= nil then
        local function runner()
            return KPanel:draw(imgui)
        end
        local panel_result, panel_value = pcall(runner)
        if not panel_result then
            imgui.Text("ERROR:")
            imgui.SameLine()
            imgui.Text(tostring(panel_value))
            GamePrint(tostring(panel_value))
        end
    end
end

--[[ See the Fungal Shift Query init.lua for why this is necessary ]]
function OnBiomeConfigLoaded()
    MaterialTables = generate_material_tables()
end

function OnModPostInit()
end

function OnPlayerSpawned(player_entity)
end

function OnWorldPostUpdate()
    if not imgui then
        imgui = load_imgui({version="1.14.2", mod=MOD_ID})
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
        if imgui.Begin("World Radar###world_radar", nil, bit.bor(
            --imgui.WindowFlags.NoFocusOnAppearing,
            --imgui.WindowFlags.NoNavInputs,
            imgui.WindowFlags.HorizontalScrollbar,
            imgui.WindowFlags.MenuBar
            ))
        then
            local res, val
            res, val = pcall(_build_menu_bar_gui)
            if not res then GamePrint(tostring(val)) end
            res, val = pcall(_build_gui)
            if not res then GamePrint(tostring(val)) end
            imgui.End()
        elseif KPanel then
            KPanel:draw_closed(imgui)
        end
    elseif show_closed then
        KPanel:draw_closed(imgui)
    end

end

-- vim: set ts=4 sts=4 sw=4 tw=79:
