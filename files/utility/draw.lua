--[[ Assorted helper functions for drawing things using Noita-Dear-ImGui ]]

--[[ Draw a hover tooltip if the prior object is hovered 
--
-- content: string
-- content: function(imgui, self, config|nil)
-- config.wrap: text wrap pos, default 400, use 0 to disable
--]]
function draw_hover(imgui, content, config)
    if imgui.IsItemHovered() then
        if imgui.BeginTooltip() then
            local wrap = config and config.wrap or 0
            if wrap > 0 then
                imgui.PushTextWrapPos(wrap)
            end
            if type(content) == "string" then
                imgui.Text(content)
            elseif type(content) == "function" then
                content(imgui, self, config)
            elseif type(content) == "table" then
                self.host:draw_line(imgui, content, nil, nil)
            end
            if wrap > 0 then
                imgui.PopTextWrapPos()
            end
            imgui.EndTooltip()
        end
    end
end

--[[ Draw "New!" indicating the object is undiscovered ]]
function draw_spell_new(imgui)
    imgui.PushStyleColor(imgui.Col.Text, 1, 0, 0.84)
    imgui.Text("New!")
    imgui.PopStyleColor()
end

-- vim: set ts=4 sts=4 sw=4:

