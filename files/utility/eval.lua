--[[ Tools for evaluating code ]]

MIN_LINES = 5

Eval = {
    code = "",
    lines = MIN_LINES,
}

function Eval:draw(imgui, host)
    local ret, code
    local line_height = imgui.GetTextLineHeight()

    ret, code = imgui.InputTextMultiline(
        "##worldradar_eval",
        self.code,
        -line_height * 4,
        line_height * self.lines,
        imgui.InputTextFlags.EnterReturnsTrue)
    if code and code ~= "" then
        self.code = code
    end

    local exec_code = ret or false
    if imgui.Button("Execute") then
        exec_code = true
    end
    imgui.SameLine()
    ret, self.lines = imgui.InputInt("Lines##worldradar_eval_lines", self.lines)
    if self.lines < MIN_LINES then self.lines = MIN_LINES end

    if exec_code then
        host.host:print(self.code)
    end
end

-- vim: set ts=4 sts=4 sw=4:
