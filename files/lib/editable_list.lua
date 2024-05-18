--[[ Create an "Editable List" class using ImGui ]]

EditList = {}

--[[ Default entry draw function ]]
function EditList.draw_entry(entry, imgui)
    local name = entry[1]
    local data = entry.data
    if type(data.color) == "table" then
        imgui.PushStyleColor(imgui.Col.Text, unpack(data.color))
    end

    imgui.Text(name)

    if type(data.color) == "table" then
        imgui.PopStyleColor()
    end
end

--[[ Create a new EditList instance ]]
function EditList.new(config)
    local this = {
        entries = {},
        name = "List",
        id = nil,
        draw_func = EditList.draw_entry,
        sort_func = nil,
    }

    if config then
        if config.name then this.name = config.name end
        if config.id then this.id = config.id end
        if config.draw_func then this.draw_func = config.draw_func end
        if config.sort_func then this.sort_func  = config.sort_func end
    end

    setmetatable(this, {
        __index = function(tbl, key)
            if rawget(tbl, key) ~= nil then
                return rawget(tbl, key)
            end
            return rawget(EditList, key)
        end
    })
    return this
end

--[[ Add a single entry with optional data ]]
function EditList:add(name, data)
    table.insert(self.entries, {
        {name, data=data or {}}
    })
    if self.sort_func ~= nil then
        table.sort(self.entries, self.sort_func)
    end
end

--[[ Remove all entries with a given name; returns number of entries removed ]]
function EditList:remove(name)
    local to_remove = {}
    for idx, entry in ipairs(self.entries) do
        if entry[1] == name then
            table.insert(to_remove, 1, idx)
        end
    end
    for _, idx in ipairs(to_remove) do
        table.remove(self.entries, idx)
    end
    return #to_remove
end

--[[ Clear all entries ]]
function EditList:clear()
    self.entries = {}
end

--[[ Draw the list ]]
function EditList:draw(imgui)
    local to_remove = nil
    local flags = bit.bor(
        imgui.WindowFlags.HorizontalScrollbar)
    if imgui.BeginChild(self.name, 0, 0, false, flags) then
        for idx, entry in ipairs(self.entries) do
            local name = entry[1]
            local data = entry.data
            local bid = ("Remove###%s"):format(data.id or name)
            if imgui.SmallButton(bid) then
                to_remove = idx
            end
            imgui.SameLine()
            self.draw_func(entry, imgui)
        end
        imgui.EndChild()
    end
    if to_remove ~= nil then
        table.remove(self.entries, to_remove)
    end
end

-- vim: set ts=4 sts=4 sw=4:
