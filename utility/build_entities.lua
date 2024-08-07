#!/usr/bin/env luajit

--[[ Build the entity list
--
-- This script builds the entity list for the World Radar mod. It does
-- this by finding all .xml files in data/entities/animals that contain
-- an <Entity> root node having a "name" attribute beginning with
-- "$animal_".
--
-- Usage:
--  luajit utility/build_entities.lua -h
--  luajit utility/build_entities.lua [-v] [-o FILE] DATA_PATH
-- 
-- FILE defaults to entities.lua. Pass "-o -" to write to stdout.
--
-- The <Base> tag is complicated.
--
-- This tag causes the content of the referenced xml file to be merged
-- into the original xml file. The nodes are merged and not appended;
-- the following rules apply:
--  Original: <Component attr1="a" attr2="b" />
--  Base: <Component attr2="c" attr3="d" />
--  Result: <Component attr1="a" attr2="c" attr3="d" />
-- Tags and attributes in the original file override the tags and
-- attributes of the referenced base file.
--
-- The nth child node overwrites the nth base node with that tag.
--
-- Child nodes can have _remove_from_base="1" which removes that node
-- from the base entirely.
--]]

-- FIXME: SpriteComponent lookup broken for icons

local self_name = arg[0]:gsub(".*\\/", "")
local base_path = arg[0]:gsub("[\\/][^\\/]+.lua$", "")
package.path = package.path .. ";" .. table.concat({
    base_path .. "/?.lua",
    base_path .. "/lib/?.lua",
    base_path .. "/../files/lib/?.lua",
}, ";")

io = require 'io'

-- luacheck: globals minifs read_file read_lines find_with_extension
require 'lib.filesystem' -- exports minifs
kae = require 'lib.libkae'
logger = require 'lib.logging'
nxml = require 'nxml'

--[[ Parse program arguments ]]
function parse_argv(argv)
    if not argv then argv = arg end
    local args = {
        verbose = false,
        trace = false,
        trace_files = {},
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
        elseif optv == "-t" or optv == "--trace" then
            args.trace = true
        elseif optv == "-T" or optv == "--trace-this" then
            table.insert(args.trace_files, argv[opti+1])
            skip_next = true
        elseif optv == "-h" or optv == "--help" then
            print(([[
usage: %s [-h] [-v] [-o FILE] DATA_PATH

arguments:
    DATA_PATH               path to unpacked data.wak directory

options:
    -h, --help              print this message and exit
    -v, --verbose           enable verbose diagnostics
    -t, --trace             enable very verbose diagnostics
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

    if args.trace then
        logger.level = logger.TRACE
    elseif args.verbose then
        logger.level = logger.DEBUG
    else
        logger.level = logger.INFO
    end

    return args
end

--[[ Trivial function to convert a table to a string ]]
local function table_to_string(tbl)
    local entries = {}
    for key, val in pairs(tbl) do
        if type(val) == "table" then
            table.insert(entries, ("%s=%s"):format(key, table_to_string(val)))
        elseif type(val) == "number" then
            table.insert(entries, ("%s=%s"):format(key, val))
        elseif type(val) == "boolean" then
            table.insert(entries, ("%s=%s"):format(key, val and "true" or "false"))
        else
            table.insert(entries, ("%s=%q"):format(key, val))
        end
    end
    table.sort(entries)
    return "{" .. table.concat(entries, ", ") .. "}"
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

--[[ Obtain the nth child having the given name (default first) ]]
local function xml_lookup(root, name, nth, tag)
    local curr_nth = 1
    for index, elem in ipairs(root.children) do
        local match = false
        if elem.name == name then
            if tag and elem.attr._tags then
                for etag in elem.attr._tags:gmatch("([a-z0-9_-]+)") do
                    if tag == etag then
                        match = true
                        break
                    end
                end
            else
                match = true
            end
        end
        if match then
            if nth == nil or nth == curr_nth then
                return elem, index
            end
            curr_nth = curr_nth + 1
        end
    end
    return nil, 0
end

--[[ Delete an xml element, optionally moving up its contents
-- Returns true, "" on success and false, error otherwise.
--]]
local function xml_delete(parent, name, move_children, recurse)
    local node, index = xml_lookup(parent, name)
    if not node then
        return false, "node " .. name .. "not found"
    end

    if move_children then
        local dst_index = index + 1
        for _, elem in ipairs(node.children) do
            table.insert(parent.children, dst_index, elem)
            dst_index = dst_index + 1
        end
    end
    table.remove(parent.children, index)
    if recurse then
        xml_delete(parent, name, move_children, true)
    end
    return true, ""
end

--[[ Merge a single element into the specified tree at the given location ]]
local function merge_element(new_elem, referenced_elem)
    for attr_name, attr_value in pairs(referenced_elem.attr) do
        if not new_elem.attr[attr_name] then
            new_elem.attr[attr_name] = attr_value
        end
    end
end

--[[ Merge the content of the base file into the child tree ]]
local function merge_xml(root, parent, referenced)
    local index = 1
    local nth_table = {}
    for _, elem in ipairs(referenced.children) do
        if not nth_table[elem.name] then nth_table[elem.name] = 0 end
        nth_table[elem.name] = nth_table[elem.name] + 1
        local base = xml_lookup(parent, elem.name, nth_table[elem.name])
        if base then
            merge_element(base, elem)
            if #elem.children > 0 then
                merge_xml(root, base, elem)
            end
        else
            table.insert(parent.children, index, elem)
            index = index + 1
        end
    end

    for attr_name, attr_value in pairs(referenced.attr) do
        if not root.attr[attr_name] then
            root.attr[attr_name] = attr_value
        elseif attr_name == "tags" then
            local tags = root.attr.tags .. "," .. attr_value
            local tag_list = {}
            local tag_table = {}
            for tag in tags:gmatch("([^,]+)") do
                if tag ~= "" and not tag_table[tag] then
                    table.insert(tag_list, tag)
                    tag_table[tag] = 1
                end
            end
            tags = table.concat(tag_list, ",")
            logger.debug("Merged tags %q with %q to get %q",
                root.attr.tags, referenced.attr.tags, tags)
            root.attr[attr_name] = tags
        end
    end

    --[[ TODO
    local to_remove = {}
    for idx, elem in ipairs(parent.children) do
        if elem.attr._remove_from_base == "1" then
            table.insert(to_remove, 1, idx)
        end
    end
    for _, idx in ipairs(to_remove) do
        table.remove(parent.children, idx)
    end
    ]]
end

--[[ Expand any <Base name="..."> tags in the xml ]]
local function expand_base_tags(xml, data_path, depth)
    local base_tag, base_index = xml_lookup(xml, "Base")
    if not base_tag then return end
    if not depth then depth = 1 end

    local parent_path = base_tag.attr.file:gsub("^data%/", data_path .. "/")
    parent_path = parent_path:gsub("[%/]+", "/")
    logger.trace("%d: Expanding %s to %s", depth, base_tag.attr.file, parent_path)
    local root_xml = nxml.parse(read_file(parent_path))
    logger.trace("%d: Merging %s %s", depth, parent_path, root_xml)
    logger.trace("%d: Into %s", depth, xml)
    merge_xml(xml, base_tag, root_xml)
    xml_delete(xml, "Base", true, false)

    for _, elem in ipairs(xml.children) do
        expand_base_tags(elem, data_path, depth+1)
    end
    if xml_lookup(xml, "Base") then
        logger.debug("%d: Tree still contains Base element(s)", depth)
        expand_base_tags(xml, data_path, depth+1)
    end
    logger.trace("%d: Result: %s", depth, xml)
end

--[[ Build an icon table from the sprite xml file ]]
local function parse_icon_xml(file_path)
    if not minifs.exists(file_path) then return "" end
    local root = nxml.parse(read_file(file_path))
    local path = root.attr.filename
    local xoffset = tonumber(root.attr.offset_x or "0")
    local yoffset = tonumber(root.attr.offset_y or "0")
    local anim = root.attr.default_animation

    local frame_data = {path=path}
    for _, node in ipairs(root.children) do
        if node.name == "RectAnimation" and node.attr.name == anim then
            local frame_count = tonumber(node.attr.frame_count)
            local frames_per_row = tonumber(node.attr.frames_per_row)
            local frame_rows = 1
            if frames_per_row > 1 then
                frame_rows = math.ceil(frame_count / frames_per_row)
            end
            local frame_wait = tonumber(node.attr.frame_wait)

            frame_data.count = frame_count
            frame_data.num_cols = frames_per_row
            frame_data.num_rows = frame_rows
            frame_data.frame_width = tonumber(node.attr.frame_width)
            frame_data.frame_height = tonumber(node.attr.frame_height)
            frame_data.wait = frame_wait

            -- TODO: pos_x, pos_y, offset_x, offset_y
        end
    end

    if path and path ~= "" then
        return frame_data
    end
    return ""
end

--[[ Build an entity table from the given xml ]]
local function build_entity_entry(xml, filename)
    local damage = xml_lookup(xml, "DamageModelComponent")
    local sprite = xml_lookup(xml, "SpriteComponent")
    local genome = xml_lookup(xml, "GenomeDataComponent")
    local function nonempty(value) return value and value ~= "" end

    local id = filename:gsub("^.*%/", ""):gsub("%.xml$", "")
    local name = id

    if nonempty(xml.attr.name) then
        name = xml.attr.name
    end

    local icon = nil
    if sprite and nonempty(sprite.attr.image_file) then
        icon = sprite.attr.image_file
    end

    local health = nil
    if damage and nonempty(damage.attr.hp) then
        health = damage.attr.hp
    end

    local herd = nil
    if genome and nonempty(genome.attr.herd_id) then
        herd = genome.attr.herd_id
    end

    local entry = {
        id = id,
        name = name,
        path = filename,
        icon = icon,
        data = {
            health = health,
            herd = herd,
        },
    }
    logger.debug(table_to_string(entry))
    return entry
end

function main()
    local argv = parse_argv(arg)

    local data = table.concat({
        argv.data_path, "entities", "animals"
    }, minifs.PATH_SEPARATOR)
    logger.debug("Searching for xml files in " .. data)

    local trace_files = {}
    for _, name in ipairs(argv.trace_files) do trace_files[name] = name end

    local icons = {}
    for name in minifs.listdir(argv.data_path .. "/ui_gfx/animal_icons") do
        if name:match("[.]png$") then
            icons[name:gsub("[.]png$", "")] = "data/ui_gfx/animal_icons/" .. name
        end
    end

    local entlist = {}
    for _, name in ipairs(find_with_extension(data, "xml")) do
        local filename = name:match("[/\\](data[/\\].*)")
        local basename = name:match("[^/\\]+$")
        logger.info("Reading XML file " .. name)
        local root = nxml.parse(read_file(name))
        if root.name ~= "Entity" then goto continue end

        local save_level = logger.level
        if trace_files[basename] then
            logger.level = logger.TRACE
        end
        expand_base_tags(root, argv.data_path, 1)
        logger.level = save_level

        local ename = root.attr.name
        if not ename then
            logger.warning(("File %s root attribute lacks name"):format(name))
            goto continue
        end

        local entry = build_entity_entry(root, filename)

        if entry.name == "$animal_lukki" and filename:match("chest_leggy%.xml") then
            entry.name = "$animal_chest_leggy"
        end

        if icons[entry.id] then
            entry.icon = icons[entry.id]
        elseif icons[entry.name:gsub("^%$animal_", "")] then
            entry.icon = icons[entry.name:gsub("^%$animal_", "")]
        else
            entry.icon = ""
        end

        if ename:match("^[$]animal_") then
            logger.debug("File %s at %q defines entity %q", filename, name, ename)
            table.insert(entlist, entry)
        else
            logger.debug("File %s at %q defines non-entity %q; skipping",
                filename, name, ename)
        end
        ::continue::
    end

    logger.info("Found %d entities in %s", #entlist, argv.data_path)

    local ofile = io.stdout
    if argv.output ~= "-" then
        ofile = io.open(argv.output, "w")
    end
    ofile:write(([[
-- This file was generated by %s. Do not modify!
return {
]]):format(self_name))
    for _, entry in ipairs(entlist) do
        ofile:write("  " .. table_to_string(entry) .. ",")
        ofile:write("\n")
    end
    ofile:write([[
}
]])
    if argv.output ~= "-" then
        ofile:close()
    end

    logger.info("Wrote %d entities to %s", #entlist,
        argv.output == "-" and "<stdout>" or argv.output)

    return 0
end

os.exit(main())

-- vim: set ts=4 sts=4 sw=4:
