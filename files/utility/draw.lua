--[[ Assorted helper functions for drawing things using Noita-Dear-ImGui ]]

TRIBOOL_TRUE = "1"
TRIBOOL_FALSE = "0"
TRIBOOL_OTHER = ""

--[[ Cycle between the three inputs ]]
function tribool_next(tb_value)
    if tb_value == TRIBOOL_TRUE then return TRIBOOL_FALSE end
    if tb_value == TRIBOOL_FALSE then return TRIBOOL_OTHER end
    return TRIBOOL_TRUE
end

--[[ Default button function for tribool ]]
function tb_default_button_func(imgui, name, value, config)
    return imgui.Button(name)
end

--[[ Default text function for tribool ]]
function tb_default_text_func(imgui, label, value, config)
    return imgui.Text(label)
end

--[[ Draw a three-value input
--
-- names: table of 3 button labels
-- label: extra text to draw after the input
-- last_value: one of the TRIBOOL_* values
-- config: optional table of the following values
--      button_func = function(imgui, name: string, curr_value, config) -> bool
--      text_func = function(imgui, label: string, curr_value, config) -> nil
--
-- Returns two values: boolean, TRIBOOL_*
--]]
function draw_tribool_input(imgui, names, label, last_value, config)
    local conf = config or {}
    if not conf.button_func then conf.button_func = tb_default_button_func end
    if not conf.text_func then conf.text_func = tb_default_text_func end
    local text_map = {
        [TRIBOOL_TRUE] = names[1],
        [TRIBOOL_FALSE] = names[2],
        [TRIBOOL_OTHER] = names[3],
    }
    local res, ret = false, last_value
    if conf.button_func(imgui, text_map[last_value], last_value, config) then
        res, ret = true, tribool_next(last_value)
    end
    imgui.SameLine()
    conf.label_func(imgui, label, last_value, config)

    return res, ret
end

--[[ Draw "New!" indicating the object is undiscovered ]]
function draw_spell_new(imgui)
    imgui.PushStyleColor(imgui.Col.Text, 1, 0, 0.84)
    imgui.Text("New!")
    imgui.PopStyleColor()
end

-- vim: set ts=4 sts=4 sw=4:

