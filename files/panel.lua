--[[
-- Panel GUI System (v2)
--
-- This script implements the "panels" API, with each "panel" being a separate
-- user-defined GUI layout selected by menu. 
--
-- Usage:
--  local PanelLib = dofile("files/panel.lua")
--  local Panel = PanelLib:init()
--
-- Panels are classes with the following entries:
-- panel.id = "string"     (required)
-- panel.name = "string"   (optional; defaults to panel.id)
-- panel:init()            (optional)
-- panel:draw(imgui)       (required)
-- panel:draw_menu(imgui)  (optional)
-- panel:configure(table)  (optional)
--
-- These entries have the following purpose:
-- panel.id       string    the internal name of the panel
-- panel.name     string    the external, public name of the panel
-- panel:init()             one-time initialization before the first draw()
-- panel:draw(imgui)        draw the panel
-- panel:draw_menu(imgui)   draw a custom menu at the end of the menubar
-- panel:configure(config)  set or update any configuration
--
-- panel:configure *should* return the current config object, but this is not
-- strictly required.
--
-- Panels are allowed to have whatever else they desire in their panel table.
--]]

-- TODO: Allow for {image="<path>"} in Panel.lines

-- luacheck: globals MOD_ID CONF conf_get conf_set

dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/world_radar/config.lua")

--[[ Template object with default values for the Panel class ]]
Panel = {
    initialized = false,
    id_current = nil,   -- ID of the "current" panel
    PANELS = { },       -- Table of panel IDs to panel instances

    debugging = false,  -- true if debugging is active/enabled
    lines = {},         -- lines displayed below the panel

    colors = {          -- text color configuration
        enable = true,
        debug = {0.9, 0.9, 0.0},

        names = {
            -- Pure colors
            red = {1, 0, 0},
            green = {0, 1, 0},
            blue = {0, 0, 1},
            cyan = {0, 1, 1},
            magenta = {1, 0, 1},
            yellow = {1, 1, 0},
            white = {1, 1, 1},
            black = {0, 0, 0},

            -- Blended colors
            red_light = {1, 0.5, 0.5},
            green_light = {0.5, 1, 0.5},
            blue_light = {0.5, 0.5, 1},
            cyan_light = {0.5, 1, 1},
            magenta_light = {1, 0.5, 1},
            yellow_light = {1, 1, 0.5},
            gray = {0.5, 0.5, 0.5},
            lightgray = {0.75, 0.75, 0.75},
        },
    },

    -- host:p(host.separator) to print a horizontal line
    separator = "========"
}

--[[ String used to denote a "default value" ]]
Panel.DEFAULT_VALUE = ("<%s>"):format(string.char(0x7f))

--[[ GlobalsGetValue/GlobalsSetValue current panel ]]
Panel.SAVE_KEY = MOD_ID .. "_current_panel"

--[[ Built-in panels ]]
PANELS_NATIVE = {
    --dofile_once("mods/world_radar/files/panels/eval.lua"),
    dofile_once("mods/world_radar/files/panels/info.lua"),
    --dofile_once("mods/world_radar/files/panels/summon.lua"),
    --dofile_once("mods/world_radar/files/panels/radar.lua"),
    --dofile_once("mods/world_radar/files/panels_old/progress.lua"),
}

--[[ Create the panel subsystem.
--
-- Must be called first, before any other functions are called.
--]]
function Panel:new()
    local this = {}
    setmetatable(this, {
        __index = function(tbl, key)
            return rawget(tbl, key) or rawget(Panel, key)
        end,
    })

    for _, pobj in ipairs(PANELS_NATIVE) do
        this:add(pobj)
    end

    this.debugging = conf_get(CONF.DEBUG)

    return this
end

--[[ Add a new panel ]]
function Panel:add(panel)
    local pobj = {
        host = self,
        config = {}
    }
    -- Persist default configuration
    if type(panel.config) == "table" then
        for key, val in pairs(panel.config) do
            pobj.config[key] = val
        end
    end
    if not panel.id then error("panel missing id") end
    if not panel.draw then error("panel " .. panel.id .. " missing draw") end
    for attr, attr_value in pairs(panel) do
        if attr ~= "host" and attr ~= "config" then
            pobj[attr] = attr_value
        end
    end
    if not pobj.name then pobj.name = panel.id end
    if not pobj.init then pobj.init = function() end end
    if not pobj.configure then pobj.configure = function(config) end end
    if not pobj.draw_menu then pobj.draw_menu = function(imgui) end end

    setmetatable(pobj, { -- pobj inherits from panel
        __index = function(tbl, key)
            local value = rawget(tbl, key)
            if value == nil then value = rawget(panel, key) end
            return value
        end,
        __newindex = function(tbl, key, val)
            rawset(tbl, key, val)
        end,
    })

    self.PANELS[panel.id] = pobj
end

--[[ Initialize the panel subsystem.
--
-- Must be called after Panel:new()
--]]
function Panel:init(env)
    for pid, pobj in pairs(self.PANELS) do
        local res, val = pcall(function() pobj:init(env, self) end)
        if not res then GamePrint(val) end
    end
    local curr_panel = GlobalsGetValue(Panel.SAVE_KEY)
    if curr_panel ~= "" and self:is(curr_panel) then
        self:d(("curr := %s (from %s)"):format(curr_panel, Panel.SAVE_KEY))
        self.id_current = curr_panel
    end

    self.initialized = true
end

--[[ Enable or disable debugging (toggle if nil) ]]
function Panel:set_debugging(enable)
    if enable == nil then
        self.debugging = not self.debugging
    elseif type(enable) == "boolean" then
        self.debugging = enable
    elseif enable then
        self.debugging = true
    else
        self.debugging = false
    end
    conf_set(CONF.DEBUG, self.debugging)
end

--[[ Add a debug line (if debugging is enabled) ]]
function Panel:d(msg)
    if self.debugging then
        table.insert(self.lines, {level="debug", msg})
    end
end

--[[ Add a debug line unless it already exists; returns true on success ]]
function Panel:d_unique(msg)
    for _, line in ipairs(self.lines) do
        if self:line_to_string(line) ~= self:line_to_string(msg) then
            return false
        end
    end
    self:d(msg)
    return true
end

--[[ Add a line ]]
function Panel:p(msg)
    table.insert(self.lines, msg)
end

--[[ Add a line unless it already exists; returns true on success ]]
function Panel:p_unique(msg)
    for _, line in ipairs(self.lines) do
        if self:line_to_string(line) ~= self:line_to_string(msg) then
            return false
        end
    end
    self:p(msg)
    return true
end

--[[ Prepend a line ]]
function Panel:prepend(msg)
    table.insert(self.lines, 1, msg)
end

--[[ Prepend a line unless it already exists; returns true on success ]]
function Panel:prepend_unique(msg)
    for _, line in ipairs(self.lines) do
        if self:line_to_string(line) ~= self:line_to_string(msg) then
            return false
        end
    end
    self:prepend(msg)
    return true
end

--[[ Clear the text ]]
function Panel:text_clear()
    while #self.lines > 0 do
        table.remove(self.lines, 1)
    end
end

--[[ Print text to both the panel and to the game ]]
function Panel:print(msg)
    self:p(msg)
    GamePrint(msg)
    print(msg) -- Writes to logger.txt if logging is enabled
end

--[[ True if the given panel ID refers to a known Panel object ]]
function Panel:is(pid)
    return self.PANELS[pid] ~= nil
end

--[[ Get the Panel object for the given panel ID ]]
function Panel:get(pid)
    if self:is(pid) then
        return self.PANELS[pid]
    end
    return nil
end

--[[ Change the current panel ]]
function Panel:set(pid)
    if self:is(pid) and pid ~= self.id_current then
        self:text_clear()
        self.id_current = pid
        GlobalsSetValue(Panel.SAVE_KEY, pid)
    end
end

--[[ Set the current panel to nil ]]
function Panel:reset()
    self.id_current = nil
end

--[[ Returns the current Panel object or nil ]]
function Panel:current()
    if self.id_current ~= nil then
        return self:get(self.id_current)
    end
    return nil
end

--[[ Set a value in lua_globals.
--
-- Note that Noita does not escape quotes, and GlobalsSetValue with a
-- value containing quotes will corrupt world_state.lua, causing
-- everything below the <lua_globals> entry to be discarded. Therefore,
-- replace double-quotes with their XML escape sequence.
--]]
function Panel:set_var(pid, varname, value)
    local key = ("%s_panel_%s_%s"):format(MOD_ID, pid, varname)
    local encoded = value:gsub("\"", "&quot;")
    GlobalsSetValue(key, encoded)
end

--[[ Get a value in lua_globals.
--
-- Returns default if the key isn't present. See set_var above.
--]]
function Panel:get_var(pid, varname, default)
    local key = ("%s_panel_%s_%s"):format(MOD_ID, pid, varname)
    local value = GlobalsGetValue(key, Panel.DEFAULT_VALUE)
    if value == Panel.DEFAULT_VALUE then return default end
    return value:gsub("&quot;", "\"")
end

--[[ Save a value in mod settings ]]
function Panel:save_value(pid, varname, value)
    local key = ("%s.panel_%s_%s"):format(MOD_ID, pid, varname)
    ModSettingSet(key, value)
end

--[[ Load a value from mod settings ]]
function Panel:load_value(pid, varname, default)
    local key = ("%s.panel_%s_%s"):format(MOD_ID, pid, varname)
    local value = ModSettingGet(key)
    if value == nil then return default end
    return value
end

--[[ Remove a value from mod settings ]]
function Panel:remove_value(pid, varname)
    local key = ("%s.panel_%s_%s"):format(MOD_ID, pid, varname)
    return ModSettingRemove(key)
end

--[[ Build the window menu ]]
function Panel:build_menu(imgui)
    local current = self:current()

    if imgui.BeginMenu("Panel") then
        local label = self.debugging and "Disable" or "Enable"
        if imgui.MenuItem(label .. " Debugging") then
            self:set_debugging(not self.debugging)
        end

        if imgui.MenuItem("Copy Text") then
            local all_lines = ""
            for _, line_obj in ipairs(self.lines) do
                local line = self:line_to_string(line_obj)
                all_lines = all_lines .. line .. "\r\n"
            end
            imgui.SetClipboardText(all_lines)
        end

        if imgui.MenuItem("Clear") then
            self.lines = {}
        end

        if imgui.MenuItem("Close") then
            conf_set(CONF.ENABLE, false)
        end

        if #self.PANELS > 1 then
            imgui.Separator()

            for pid, pobj in pairs(self.PANELS) do
                local mstr = pobj.name
                if pid == self.id_current then
                    mstr = mstr .. " [*]"
                end
                if imgui.MenuItem(mstr) then
                    self:set(pid)
                end
            end

            imgui.Separator()

            if current ~= nil then
                if imgui.MenuItem("Return") then
                    self:reset()
                end
            end
        end

        imgui.EndMenu()
    end

    if current ~= nil then
        if current.draw_menu ~= nil then
            current:draw_menu(imgui)
        end
    end

end

--[[ Private: draw a line to the feedback box ]]
function Panel:_draw_line(imgui, line, show_images, show_color)
    if show_images == nil then show_images = true end
    if show_color == nil then show_color = true end
    if type(line) == "table" then
        local level = line.level or nil
        local color = line.color or nil
        if color == nil and level ~= nil then
            color = self.colors[level] or nil
        end

        if color ~= nil and show_color then
            if type(color) == "string" then
                color = self.colors.names[color] or {1, 1, 1}
            end
            imgui.PushStyleColor(imgui.Col.Text, unpack(color))
        end

        if line.image and show_images then
            local img = imgui.LoadImage(line.image)
            if img then
                imgui.Image(img, line.width or img.width, line.height or img.height)
                imgui.SameLine()
            end
        end

        for idx, token in ipairs(line) do
            if idx ~= 1 then imgui.SameLine() end
            if level ~= nil then
                imgui.Text(("%s:"):format(level))
                imgui.SameLine()
            end
            self:_draw_line(imgui, token, show_images, show_color)
        end
        if color ~= nil and show_color then
            imgui.PopStyleColor()
        end
    elseif line == self.separator then
        imgui.Separator()
    elseif type(line) == "string" then
        imgui.Text(line)
    else
        imgui.Text(tostring(line))
    end
end

--[[ Join together a line of text into a single string ]]
function Panel:line_to_string(line)
    if type(line) == "table" then
        local result = ""
        if line.level ~= nil then
            result = ("%s:"):format(line.level)
        end
        for _, entry in ipairs(line) do
            result = result .. " " .. self:line_to_string(entry)
        end
        return result
    end

    if type(line) == "string" then
        return line
    end
    return tostring(line)
end

--[[ Called when the main window is open ]]
function Panel:draw(imgui)
    local current = self:current()
    if current ~= nil then
        imgui.PushID(MOD_ID .. "_panel_" .. self.id_current)
        current:draw(imgui)
        imgui.PopID()
    end

    local show_images = ModSettingGet(MOD_ID .. ".show_images")
    local show_color = ModSettingGet(MOD_ID .. ".color")
    for _, line in ipairs(self.lines) do
        self:_draw_line(imgui, line, show_images, show_color)
    end
end

--[[ Called instead of draw() if the main window is closed ]]
function Panel:draw_closed(imgui)
    local current = self:current()
    if current ~= nil then
        if current.draw_closed then
            current:draw_closed(imgui)
        end
    end
end

return Panel

-- vim: set ts=4 sts=4 sw=4 tw=79:
