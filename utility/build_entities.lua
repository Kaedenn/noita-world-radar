#!/usr/bin/env luajit

--[[ Build the entity list
--
-- This script finds all .xml files in data/entities/animals that contain an
-- <Entity> root node that has a "name" attribute beginning with "$animal_"
-- and outputs a lua file that can be loaded by a mod.
--
-- Usage:
--  luajit utility/build_entities.lua -h
--  luajit utility/build_entities.lua [-v] [-o FILE] DATA_PATH
-- 
-- FILE defaults to output.lua. Pass "-o -" to write to stdout.
--
--]]

io = require 'io'
ffi = require 'ffi'

local base_path = arg[0]:gsub("[\\/][^\\/]+.lua$", "")
package.path = package.path .. ";" .. table.concat({
    base_path .. "/?.lua",
    base_path .. "/../files/lib/?.lua"
}, ";")

--[[ Parse program arguments ]]
function parse_argv(argv)
    if not argv then argv = arg end
    local args = {
        verbose = false,
        data_path = nil,
        output = "entities.lua",
    }
    local skip_next = false
    for opti, optv in ipairs(argv) do
        if skip_next then
            skip_next = false
            goto continue
        end
        local lead = optv:sub(1, 1)
        if lead ~= "-" then
            if args.data_path then
                error(("Unknown argument %d %q"):format(opti, optv))
            end
            args.data_path = optv
        elseif optv == "-o" or optv == "--output" then
            args.output = argv[opti+1]
            skip_next = true
        elseif optv == "-v" or optv == "--verbose" then
            args.verbose = true
        elseif optv == "-h" or optv == "--help" then
            print(([[
usage: %s [-h] [-v] [-o FILE] DATA_PATH

arguments:
    DATA_PATH               path to unpacked data.wak directory

options:
    -h, --help              print this message and exit
    -v, --verbose           enable verbose diagnostics
    -o FILE, --output FILE  write results to FILE (default %q)
]]):format(argv[0], args.output))
            os.exit(0)
        else
            error(("Unknown argument %d %q"):format(opti, optv))
        end
        ::continue::
    end

    if not args.data_path then
        error("Missing required argument data_path")
    end

    return args
end

--[[ Open and read a file ]]
local function read_file(path)
    local fobj = io.open(path, "r")
    local data = fobj:read("*all")
    fobj:close()
    return data
end

--[[ Open and read a file into a table of lines ]]
local function read_lines(path)
    local fobj = io.open(path, "r") or error("Failed to open " .. path)
    local lines = {}
    for line in fobj:lines() do
        table.insert(lines, line)
    end
    fobj:close()
    return lines
end

--[[ Read the icon file into a usable table ]]
local function read_icon_file(data_path)
    local lines = read_lines(data_path .. "/ui_gfx/animal_icons/_list.txt")
    local icons = {}
    for _, ent_name in ipairs(lines) do
        icons[ent_name] = ("data/ui_gfx/animal_icons/%s.png"):format(ent_name)
    end
    return icons
end

nxml = require 'nxml'
kae = require 'libkae'
minifs = require 'minifs'

function main()
    local argv = parse_argv(arg)

    local function pdebug(message)
        if argv.verbose then
            io.stderr:write("DEBUG: ")
            io.stderr:write(message)
            if ffi.os == "Windows" then
                io.stderr:write("\r\n")
            else
                io.stderr:write("\n")
            end
        end
    end

    --[[ Recursively find files in root having extension ext ]]
    local function find_with_extension(root, ext)
        ext = ext:gsub("^[.]", "") -- Remove leading dot, if present
        local result = {}
        pdebug(("Listing directory %q"):format(root))
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

    local data = table.concat({
        argv.data_path, "entities", "animals"
    }, minifs.PATH_SEPARATOR)
    pdebug("Searching for xml files in " .. data)

    local icons = {}
    for name in minifs.listdir(argv.data_path .. "/ui_gfx/animal_icons") do
        if name:match("[.]png$") then
            icons[name:gsub("[.]png$", "")] = "data/ui_gfx/animal_icons/" .. name
        end
    end

    local entlist = {}
    for _, name in ipairs(find_with_extension(data, "xml")) do
        pdebug("Reading XML file " .. name)
        local root = nxml.parse(read_file(name))
        if root.name == "Entity" and root.attr.name then
            local ename = root.attr.name
            local fpath = name:match("[/\\](data[/\\].*)")
            if ename == "$animal_lukki" and fpath:match("chest_leggy%.xml") then
                ename = "$animal_chest_leggy"
            end

            if fpath:match("/illusions/") then
                pdebug(("File %s at %q defines illusory entity %q; skipping"):format(
                    fpath, name, ename))
            elseif ename:match("^[$]animal_") then
                pdebug(("File %s at %q defines entity %q"):format(fpath, name, ename))
                table.insert(entlist, {fpath, ename})
            else
                pdebug(("File %s at %q defines non-entity %q; skipping"):format(
                    fpath, name, ename))
            end
        end
    end

    io.stderr:write(("Found %d entities in %s\n"):format(#entlist, argv.data_path))

    local ofile = io.stdout
    if argv.output ~= "-" then
        ofile = io.open(argv.output, "w")
    end
    ofile:write([[
-- This file was generated by build_entities.lua. Do not modify!
return {
]])
    for _, entry in ipairs(entlist) do
        local entpath, entname = unpack(entry)
        local entid = string.match(entpath, "([^/]*)%.xml$")
        local icon = icons[entid] or ""
        if icon == "" then
            icon = icons[entname:gsub("^[$]animal_", "")] or ""
        end
        ofile:write(([[  {id=%q, name=%q, path=%q, icon=%q},
]]):format(entid, entname, entpath, icon))
    end
    ofile:write([[
}
]])
    if argv.output ~= "-" then
        ofile:close()
    end

    return 0
end

os.exit(main())

-- vim: set ts=4 sts=4 sw=4:
