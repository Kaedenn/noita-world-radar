--[[ Tools for evaluating code ]]

MIN_LINES = 5

EVAL_NOOP = 0
EVAL_SUCCESS = 1
EVAL_FAIL = 2

Eval = {
    code = "",
    lines = MIN_LINES,
    print_func = nil,
    result = {          -- Output/result of the evaluation
        code = "",      -- Code that was evaluated
        func = nil,     -- Function created by load()
        error = nil,    -- Error object, if load() failed
        result = nil,   -- boolean
        value = nil,    -- return value, if any
    },

    NOOP = EVAL_NOOP,
    SUCCESS = EVAL_SUCCESS,
    FAIL = EVAL_FAIL,
}

local set_content = ModTextFileSetContent
local function do_load(code)
    local filename = "mods/world_radar/files/eval_command" .. ".lua"
    set_content(filename, code)
    return loadfile(filename)
end

function Eval:set_print_function(func)
    self.print_func = func
end

function Eval:_make_print_wrapper(host)
    local real_print = _G.print
    return function(...)
        pcall(real_print, ...)
        local line = ""
        local items = {...}
        for i, item in ipairs(items) do
            if i ~= 1 then
                line = line .. "\t"
            end
            line = line .. tostring(item)
        end
        if #line == 0 then
            line = "<empty>"
        end
        host.host:print(line)
    end
end

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
        local function code_on_error(errmsg)
            host.host:print_error(errmsg)
        end
        local cfunc, cerror = do_load(self.code)
        if type(cfunc) ~= "function" then
            self.result = {
                code = self.code,
                func = cfunc,
                error = cerror,
                result = nil,
                value = nil
            }
            return EVAL_FAIL
        end

        local eval_env = {
            ["self"] = self,
            ["panel"] = host,
            ["print"] = self:_make_print_wrapper(host),
            ["code"] = self.code,
            ["imgui"] = imgui,
            ["kae"] = dofile_once("mods/world_radar/files/lib/libkae.lua"),
            ["nxml"] = dofile_once("mods/world_radar/files/lib/nxml.lua"),
            ["smallfolk"] = dofile_once("mods/world_radar/files/lib/smallfolk.lua"),
        }
        local env_meta = {
            __index = function(tbl, key)
                if rawget(tbl, key) ~= nil then
                    return rawget(tbl, key)
                end
                return rawget(_G, key)
            end,
            __newindex = function(tbl, key, val)
                rawset(tbl, key, val)
            end,
        }

        if eval_env.kae and eval_env.kae.config then
            eval_env.kae.config.printfunc = eval_env["print"]
        end
        local env = setmetatable(eval_env, env_meta)
        local func = setfenv(cfunc, env)
        local presult, pvalue = xpcall(func, code_on_error)
        self.result = {
            code = self.code,
            func = cfunc,
            error = cerror,
            result = presult,
            value = pvalue
        }
        return EVAL_SUCCESS
    end

    return EVAL_NOOP
end

-- vim: set ts=4 sts=4 sw=4: