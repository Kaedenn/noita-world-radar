--[[
-- A very, very simple logger.
--
-- logger = dofile("mods/world_radar/utility/lib/logging.lua")
-- logger.warning("this is a %s message", "warning")
-- logger.level = logger.DEBUG
-- logger.debug("this is a %s message", "debug")
--]]

logger = {
    WARNING = 10,
    INFO = 20,
    DEBUG = 30,
    TRACE = 40,

    LEVELS = {}, -- Set below

    level = nil, -- Set below

    write = function(level_name, message, ...)
        if level_name and level_name ~= "" then
            io.stderr:write(("%s: "):format(level_name))
        end
        io.stderr:write(message:format(...))
        io.stderr:write("\n")
    end,

    debug = nil, -- Set below
    info = nil, -- Set below
    warning = nil, -- Set below
}

logger.LEVELS = {
    [logger.WARNING] = {number=logger.WARNING, name="warning"},
    [logger.INFO] = {number=logger.INFO, name="info"},
    [logger.DEBUG] = {number=logger.DEBUG, name="debug"},
    [logger.TRACE] = {number=logger.TRACE, name="trace"},
}

local function _init_logger(inst)
    inst.level = inst.INFO
    for lvnum, lvdef in pairs(inst.LEVELS) do
        inst[lvdef.name] = function(message, ...)
            if inst.level >= lvnum then
                inst.write(lvdef.name, message, ...)
            end
        end
    end
    return inst
end
return _init_logger(logger)

-- vim: set ts=4 sts=4 sw=4:
