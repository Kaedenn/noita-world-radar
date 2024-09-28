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
-- panel:on_draw_pre(imgui)     (optional; called before draw/draw_closed)
-- panel:on_draw_post(imgui)    (optional; called after draw/draw_closed)
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

-- TODO: onscreen text: add instance list like Panel.lines

--[[ Line Format
The Panel class supports fairly complex layout for printing lines using the
Panel:p() and Panel:d() functions. A line is either a string or a table of
line fragments. Each line fragment can be either a string or another table.
The following values are understood for line fragments; all attributes are
optional:
  level: string       used to determine color and displayed as a prefix
  color: string       one of Panel.colors; or:
  color: {r, g, b}    values between [0, 1], alpha = 1; or:
  color: {r, g, b, a} values between [0, 1]
  image: string       path to a PNG image file
  image: table        image specification
  width: number       override width of the image in pixels
  height: number      override height of the image in pixels
  wrapped_text: string    display text wrapped to the container
  separator_text: string  display text with a separator
  label_text: string      display text as a label
  bullet_text: string     display text with a bullet
  button: table       add a button to the left of the entry
    .text: string     button text (default: "Button")
    .id: string       optional button ID, if button.text lacks one
    .func: function   function called if the button is clicked
    .small: boolean   if true, creates a small button
    [i]: any          applied to the function as arguments
  hover: table        print a hover box if the item is hovered (requires image)
  hover: function     call a function if the item is hovered (requires image)

The indexed values (fragment[1], fragment[2], etc) can be zero or more of the
following:
  string              displayed as is
  Line                processed as above with results on one line
  LineFragment        processed as above with results on one line

The following labels are understood:
  "debug"             color={0.9, 0.9, 0}, near-yellow
  "warning"           color={1.0, 0.5, 0.5}, light-red

When displaying images via Line.image, the width and height keys can be used
to override the image width and height. For instance:
  {"mods/mymod/files/myimage.png", height=20}
will display the image using its actual width but with a height of 20 pixels
Proportional scaling and min/max sizes are not (yet?) supported.

Button functions are called as follows:
  button_func(unpack(button_args), panel, imgui)
where panel is the host Panel instance and imgui is the current ImGui object.

Panel.separator is a special Line that prints a horizontal separator, used
as follows:
  host:p(host.separator)
--]]

dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/world_radar/config.lua")
dofile_once("mods/world_radar/files/lib/utility.lua")

--[[ Template object with default values for the Panel class ]]
Panel = {
    initialized = false,
    id_current = nil,   -- ID of the "current" panel
    PANELS = {},        -- Table of panel IDs to panel instances
    gui = nil,          -- Noita Gui instance

    debugging = false,  -- true if debugging is active/enabled
    lines = {},         -- lines displayed below the panel
    config = {          -- non-persistent configuration
        menu_show = true,       -- draw the Panels menu
        menu_show_clear = true, -- include the Clear menu item
    },

    colors = {          -- text color configuration
        enable = true,
        debug = {0.9, 0.9, 0.0}, -- near-yellow
        warning = {1.0, 0.5, 0.5}, -- light red

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
            red_light = {1, 0.5, 0.5}, lightred = {1, 0.5, 0.5},
            green_light = {0.5, 1, 0.5}, lightgreen = {0.5, 1, 0.5},
            blue_light = {0.5, 0.5, 1}, lightblue = {0.5, 0.5, 1},
            cyan_light = {0.5, 1, 1}, lightcyan = {0.5, 1, 1},
            magenta_light = {1, 0.5, 1}, lightmagenta = {1, 0.5, 1},
            yellow_light = {1, 1, 0.5}, lightyellow = {1, 1, 0.5},
            gray_light = {0.75, 0.75, 0.75}, lightgray = {0.75, 0.75, 0.75},
            gray = {0.5, 0.5, 0.5},
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
    dofile_once("mods/world_radar/files/panels/info.lua"),
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
function Panel:init(env, config)
    for pid, pobj in pairs(self.PANELS) do
        local res, val = pcall(function() pobj:init(env, self, config) end)
        if not res then
            GamePrint(val)
            print_error(val)
        end
    end
    local curr_panel = GlobalsGetValue(Panel.SAVE_KEY)
    if curr_panel ~= "" and self:is(curr_panel) then
        self:d(("curr := %s (from %s)"):format(curr_panel, Panel.SAVE_KEY))
        self.id_current = curr_panel
    end

    if not self.gui then self.gui = GuiCreate() end
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

--[[ Has this exact message been logged before? ]]
function Panel:message_unique(msg)
    for _, line in ipairs(self.lines) do
        if self:line_to_string(line) ~= self:line_to_string(msg) then
            return true
        end
    end
    return false
end

--[[ Add a debug line (if debugging is enabled) ]]
function Panel:d(msg)
    if self.debugging then
        table.insert(self.lines, {level="debug", msg})
    end
end

--[[ Add a debug line unless it already exists; returns true on success ]]
function Panel:d_unique(msg)
    if self:message_unique(msg) then
        self:d(msg)
        return true
    end
    return false
end

--[[ Add a line ]]
function Panel:p(msg)
    table.insert(self.lines, msg)
end

--[[ Add a line unless it already exists; returns true on success ]]
function Panel:p_unique(msg)
    if self:message_unique(msg) then
        self:p(msg)
        return true
    end
    return false
end

--[[ Prepend a line ]]
function Panel:prepend(msg)
    table.insert(self.lines, 1, msg)
end

--[[ Prepend a line unless it already exists; returns true on success ]]
function Panel:prepend_unique(msg)
    if self:message_unique(msg) then
        self:prepend(msg)
        return true
    end
    return false
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

--[[ Print text to the panel, the game, and to the logger (if enabled) ]]
function Panel:print_error(msg)
    if self:message_unique(msg) then
        self:p({{"ERROR:", color="lightred"}, msg})
        GamePrint(("ERROR: %s"):format(msg))
        print_error(msg) -- Writes to logger.txt if logging is enabled
        generate_traceback()
    end
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
    if type(value) == "boolean" then
        value = value and "1" or "0"
    elseif type(value) ~= "string" then
        value = tostring(value)
    end
    local encoded = value:gsub("\"", "&quot;")
    GlobalsSetValue(key, encoded)
end

--[[ Get a value in lua_globals or the default value if not present ]]
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

    if current ~= nil then
        if current.on_menu_pre ~= nil then
            current:on_menu_pre(imgui)
        end
    end

    if self.config.menu_show and imgui.BeginMenu("Panel") then
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

        if self.config.menu_show_clear and imgui.MenuItem("Clear") then
            self.lines = {}
        end

        if imgui.MenuItem("Close") then
            conf_set(CONF.ENABLE, false)
        end

        -- Show panel selection code for multi-panel use
        if #self.PANELS > 1 then
            imgui.Separator()
            for pid, pobj in pairs(self.PANELS) do
                local mstr = pobj.name
                if pid == self.id_current then mstr = mstr .. " [*]" end
                if imgui.MenuItem(mstr) then self:set(pid) end
            end

            imgui.Separator()
            if current and imgui.MenuItem("Return") then
                self:reset()
            end
        end

        imgui.EndMenu()
    end

    if current ~= nil then
        if current.draw_menu ~= nil then
            current:draw_menu(imgui)
        end
        if current.on_menu_post ~= nil then
            current:on_menu_post(imgui)
        end
    end

end

--[[ Draw an image to the feedback box ]]
function Panel:draw_image(imgui, image, rescale, extra)
    local path = image
    local width, height, uvx, uvy = 0, 0, 0, 0
    local frame_width, frame_height = nil, nil
    local odata = extra or {}
    local hover_obj = odata.hover
    if type(image) == "table" then
        path = image.path
        width = image.width or 0
        height = image.height or 0
        frame_width = image.frame_width
        frame_height = image.frame_height
    end
    if path == "" or type(path) ~= "string" then
        return false
    end
    local img = imgui.LoadImage(path)
    if not img and odata.fallback then
        path = odata.fallback
        img = imgui.LoadImage(path)
    end
    if not img then
        print_error(("Failed to load image %q"):format(path))
        return false
    end

    if rescale == nil and odata.rescale then
        rescale = true
    end

    if frame_width then uvx = frame_width / img.width end
    if frame_height then uvy = frame_height / img.height end
    if rescale then
        local want_height = height
        if not height or height == 0 then
            want_height = imgui.GetTextLineHeight()
        end
        local orig_height = frame_height or img.height
        local orig_width = frame_width or img.width
        local want_width = want_height / orig_height * orig_width
        width = math.floor(want_width)
        height = math.floor(want_height)
    else
        if width == 0 then width = img.width end
        if height == 0 then height = img.height end
    end
    if uvx ~= 0 or uvy ~= 0 then
        imgui.Image(img, width, height, 0, 0, uvx, uvy)
    else
        imgui.Image(img, width, height)
    end
    if hover_obj then
        if imgui.IsItemHovered() then
            if imgui.BeginTooltip() then
                if type(hover_obj) == "function" then
                    hover_obj(imgui, self, image)
                else
                    self:draw_line(imgui, hover_obj, nil, nil)
                end
                imgui.EndTooltip()
            end
        end
    end
    return true
end

--[[ Draw a line to the feedback box
-- @param imgui userdata Reference to the Noita-Dear-ImGui object
-- @param line table|string Line to print
-- @param show_images boolean|nil Don't draw images if this is false
-- @param show_color boolean|nil Don't draw using color if this is false
-- @param data table|nil For recursive calls: the table containing this piece
--
-- If show_images is nil, then the "show_images" setting is used
-- If show_color is nil, then the "show_color" setting is used
--
-- The line parameter has quite a complex structure. See documentation in the
-- build directory for its structure.
--]]
function Panel:draw_line(imgui, line, show_images, show_color, data)
    if not data then data = {} end
    if show_images == nil then show_images = conf_get(CONF.SHOW_IMAGES) end
    if show_color == nil then show_color = conf_get(CONF.SHOW_COLOR) end
    if type(line) == "table" then
        local level = line.level or nil
        local color = line.color or nil
        if color == nil and level ~= nil then
            color = self.colors[level] or nil
        end

        -- Display "time remaining" as a simple percentage
        if line.duration and line.max_duration then
            local ratio = line.duration / line.max_duration
            if imgui.ProgressBar then
                imgui.ProgressBar(ratio, 16, imgui.GetTextLineHeight())
            else
                local percent = math.floor(ratio * 100)
                local prefix = ("%02d"):format(math.min(percent, 99))
                imgui.SetNextItemWidth(16) -- FIXME: Calculate actual width
                imgui.TextDisabled(prefix)
            end
            if imgui.IsItemHovered() then
                if imgui.BeginTooltip() then
                    imgui.Text("Click to clear")
                    imgui.EndTooltip()
                end
            end
            if imgui.IsItemClicked() then
                line.duration = 0
            end
            imgui.SameLine()
        end

        local pushed_color = false
        if color ~= nil and show_color then
            if type(color) == "string" then
                color = self.colors.names[color] or {1, 1, 1}
            end
            imgui.PushStyleColor(imgui.Col.Text, unpack(color))
            pushed_color = true
        end

        if (line.image or line.fallback) and show_images then
            -- FIXME: Draw fallback if drawing line.image fails
            self:draw_image(imgui, line.image or line.fallback, true, line)
            imgui.SameLine()
        end

        if line.button then
            local btext = line.button.text or "Button"
            local bid = line.button.id or ""
            local bfunc = line.button.func or function() end
            local blabel = btext
            if bid ~= "" then
                blabel = ("%s###%s"):format(btext, bid)
            end

            local ret
            if line.button.small then
                ret = imgui.SmallButton(blabel)
            else
                ret = imgui.Button(blabel)
            end
            if line.button.hover then
                if imgui.IsItemHovered() then
                    if imgui.BeginTooltip() then
                        self:draw_line(imgui, line.button.hover, show_images, show_color, line.button)
                        imgui.EndTooltip()
                    end
                end
            end
            imgui.SameLine()

            if ret then
                local bargs = {unpack(line.button)} -- Copy to modify
                table.insert(bargs, self)   -- Append self
                table.insert(bargs, imgui)  -- Append imgui
                local result, value = pcall(bfunc, unpack(bargs))
                if not result then
                    self:print_error(("ERROR: %s"):format(value))
                end
            end
        end

        if type(line.wrapped_text) == "string" then
            imgui.TextWrapped(line.wrapped_text)
        end

        if type(line.separator_text) == "string" then
            imgui.SeparatorText(line.separator_text)
        end

        if type(line.label_text) == "string" then
            imgui.LabelText(line.label_text)
        end

        if type(line.bullet_text) == "string" then
            imgui.BulletText(line.bullet_text)
        end

        for idx, token in ipairs(line) do
            if idx ~= 1 then
                if type(token) ~= "table" or not token.clear_line then
                    imgui.SameLine()
                end
            end
            if level ~= nil then
                imgui.Text(("%s:"):format(level))
                imgui.SameLine()
            end
            self:draw_line(imgui, token, show_images, show_color, line)
        end
        if pushed_color then
            imgui.PopStyleColor()
        end
    elseif line == self.separator then
        imgui.Separator()
    elseif type(line) == "string" then
        if data.wrapped then
            imgui.TextWrapped(line)
        elseif data.as_separator then
            imgui.SeparatorText(line)
        elseif data.as_label then
            imgui.LabelText(line)
        elseif data.as_bullet then
            imgui.BulletText(line)
        elseif data.disabled then
            imgui.TextDisabled(line)
        else
            imgui.Text(line)
        end
    else
        -- It's neither a table nor a string?
        imgui.Text(tostring(line))
    end
end

--[[ Draw a line to the screen. Supports most Panel:draw_line features.
--
-- curr_x and curr_y support a few different behaviors:
--  if curr_x is nil, curr_x = 2 * char_width
--  if curr_y is nil, curr_y = screen_height - 2 * char_height
--  if curr_y < 0, curr_y = screen_height - math.abs(curr_y) * char_height
--
-- This function returns two values:
--  curr_x + width of line in pixels
--  curr_y + height of line in pixels
--
-- Features not supported:
--  self.separator
--  line.level (support is planned; color works)
--  line.label (support is planned)
--  line.clear_line (support is tentatively planned)
--  line.wrapped, line.wrapped_text (support is planned)
--  line.as_separator, line.separator_text
--  line.as_label, line.label_text
--  line.as_bullet, line.bullet_text
--  line.disabled
--]]
function Panel:draw_line_onscreen(line, pos, show_images, show_color, data, extra)
    local id = extra and extra.id or 0
    local function next_id() id = id + 1; return id end
    if show_images == nil then show_images = conf_get(CONF.SHOW_IMAGES) end
    if show_color == nil then show_color = conf_get(CONF.SHOW_COLOR) end
    GuiStartFrame(self.gui)
    local screen_width, screen_height = GuiGetScreenDimensions(self.gui)
    local char_width, char_height = GuiGetTextDimensions(self.gui, "M")
    if not data then GuiIdPushString(self.gui, MOD_ID .. "_panel_onscreen") end

    local curr_x, curr_y = unpack(pos or {nil, nil})
    if not curr_x then curr_x = char_width * 2 end
    if not curr_y then
        curr_y = screen_height - char_height * 2
    elseif curr_y < 0 then
        curr_y = screen_height - char_height * math.abs(curr_y)
    end

    local base_pos = extra and extra.base_pos or {curr_x, curr_y}
    if type(line) == "table" then
        local level = line.level or nil
        local color = line.color or nil
        if color == nil and level ~= nil then
            color = self.colors[level] or nil
        end
        if type(color) == "string" then
            color = self.colors.names[color] or {1, 1, 1, 1}
        end

        if line.duration and line.max_duration then
            local ratio = line.duration / line.max_duration
            local percent = math.floor(ratio * 100)
            local prefix = ("%02d:"):format(math.min(percent, 99))
            local clicked = GuiButton(self.gui, next_id(), curr_x, curr_y, prefix)
            if clicked then
                line.duration = 0
            end
            local textw, texth = GuiGetTextDimensions(self.gui, prefix)
            curr_x = curr_x + textw + char_width
        end

        if (line.image or line.fallback) and show_images then
            local image_path = line.image
            local img_width, img_height = GuiGetImageDimensions(self.gui, image_path)
            if img_width == 0 and img_height == 0 then
                image_path = line.fallback
                img_width, img_height = GuiGetImageDimensions(self.gui, image_path)
            end
            if img_width ~= 0 and img_height ~= 0 then
                GuiImage(self.gui, next_id(), curr_x, curr_y, image_path, 1, 1)
                curr_x = curr_x + img_width + char_width
            end
        end

        if line.button then
            local btext = line.button.text or "Button"
            local bid = line.button.id or ""
            local bfunc = line.button.func or function() end
            local bfunc_right = line.button.func_right or function() end
            local blabel = btext
            if bid ~= "" then
                GuiIdPushString(self.gui, ("%s_%s"):format(btext, bid))
            end
            local clicked, right_clicked = GuiButton(self.gui, next_id(), curr_x, curr_y, btext)
            if clicked then
                local bargs = {unpack(line.button)}
                table.insert(bargs, self)
                local result, value = pcall(bfunc, unpack(bargs))
                if not result then
                    self:print_error(("ERROR: %s"):format(value))
                end
            end
            if right_clicked then
                local bargs = {unpack(line.button)}
                table.insert(bargs, self)
                local result, value = pcall(bfunc_right, unpack(bargs))
                if not result then
                    self:print_error(("ERROR: %s"):format(value))
                end
            end
            local textw, texth = GuiGetTextDimensions(self.gui, line)
            curr_x = curr_x + textw + char_width
            if bid ~= "" then
                GuiIdPop(self.gui)
            end
        end

        local temp_y = curr_y
        for _, token in ipairs(line) do
            curr_x, temp_y = self:draw_line_onscreen(
                token,
                {curr_x, curr_y},
                show_images,
                show_color,
                line,
                {id=id, color=color, base_pos=base_pos})
            temp_y = math.max(curr_y, temp_y)
        end
        curr_y = temp_y

    elseif type(line) == "string" then
        if show_color then
            local color = nil
            if extra and extra.color then
                color = extra.color
            elseif data and data.color then
                color = data.color
            end
            if type(color) == "string" then
                color = self.colors.names[color]
            end
            if color then
                local tr, tg, tb, ta = unpack(color)
                if not ta then ta = 1 end
                GuiColorSetForNextWidget(self.gui, tr, tg, tb, ta)
            end
        end
        GuiText(self.gui, curr_x, curr_y, line)
        local textw, texth = GuiGetTextDimensions(self.gui, line)
        curr_x = curr_x + textw
        curr_y = curr_y + texth
    end
    if not data then GuiIdPop(self.gui) end

    return curr_x, curr_y
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
        if current.on_draw_pre then current:on_draw_pre(imgui) end
        imgui.PushID(MOD_ID .. "_panel_" .. self.id_current)
        current:draw(imgui)
        imgui.PopID()
        if current.on_draw_post then current:on_draw_post(imgui) end
    end

    local show_images = conf_get(CONF.SHOW_IMAGES)
    local show_color = conf_get(CONF.SHOW_COLOR)
    for _, line in ipairs(self.lines) do
        self:draw_line(imgui, line, show_images, show_color)
    end
end

--[[ Called instead of draw() if the main window is closed ]]
function Panel:draw_closed(imgui)
    local current = self:current()
    if current ~= nil then
        if current.on_draw_pre then current:on_draw_pre(imgui) end
        imgui.PushID(MOD_ID .. "_panel_" .. self.id_current .. "_closed")
        if current.draw_closed then
            current:draw_closed(imgui)
        end
        imgui.PopID()
        if current.on_draw_post then current:on_draw_post(imgui) end
    end
end

return Panel

-- vim: set ts=4 sts=4 sw=4 tw=79:
