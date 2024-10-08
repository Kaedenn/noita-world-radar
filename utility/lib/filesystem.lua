
minifs = require 'minifs'

--[[ Recursively find files in root having extension ext ]]
function find_with_extension(root, ext)
    ext = ext:gsub("^[.]", "") -- Remove leading dot, if present
    local result = {}
    for name in minifs.listdir(root) do
        local path = table.concat({root, name}, minifs.PATH_SEPARATOR)
        if minifs.isdir(path) then
            for _, entry in ipairs(find_with_extension(path, ext)) do
                table.insert(result, entry)
            end
        elseif name:gsub("[^.]+[.]", "") == ext then
            table.insert(result, path)
        end
    end
    return result
end

--[[ Open and read a file ]]
function read_file(path)
    local fobj = io.open(path, "r") or error("Failed to open " .. path)
    local data = fobj:read("*all")
    fobj:close()
    return data
end

--[[ Open and read a file into a table of lines ]]
function read_lines(path)
    local fobj = io.open(path, "r") or error("Failed to open " .. path)
    local lines = {}
    for line in fobj:lines() do
        table.insert(lines, line)
    end
    fobj:close()
    return lines
end

--[[ Rebase a path relative to a different directory ]]
function path_change_prefix(filepath, old_prefix, new_prefix)
    local parts = minifs.splitpath(filepath)
    local old_parts = minifs.splitpath(old_prefix)

    while #old_parts > 0 and old_parts[1] == parts[1] do
        table.remove(old_parts, 1)
        table.remove(parts, 1)
    end
    if new_prefix:match("/$") then
        new_prefix = new_prefix:gsub("[/]+$", "")
    end
    table.insert(parts, 1, new_prefix)
    return table.concat(parts, minifs.PATH_SEPARATOR)
end

--[[ Obtain the leading components of a path ]]
function dirname(path)
    local parts = minifs.splitpath(path)
    parts[#parts] = nil
    return table.concat(parts, minifs.PATH_SEPARATOR)
end

--[[ Obtain the trailing component of a path ]]
function basename(path, ext)
    local parts = minifs.splitpath(path)
    local base = parts[#parts]
    if ext ~= nil and base:match("%.([^./]+)") == ext then
        base = base:gsub("%.([^./]+)", "")
    end
    return base
end

--[[ Join two or more path components together ]]
function join_path(stem, ...)
    local result = table.concat({stem, ...}, minifs.PATH_SEPARATOR)
    local escaped_pat = ("[%%%s]+"):format(minifs.PATH_SEPARATOR)
    print(escaped_pat)
    return result:gsub(escaped_pat, minifs.PATH_SEPARATOR)
end

-- vim: set ts=4 sts=4 sw=4:
