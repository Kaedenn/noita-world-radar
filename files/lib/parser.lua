--[[ Trivial "safe" wrapper around smallfolk ]]

smallfolk = dofile_once("mods/world_radar/files/lib/smallfolk.lua")

--[[ Attempt to parse text using smallfolk.
-- Returns data, nil on success.
-- Returns nil, error_message on failure. ]]
function try_parse(text)
    local result, value = pcall(smallfolk.loads, text)
    if result then
        return value, nil
    end
    return nil, value
end

-- vim: set ts=4 sts=4 sw=4:
