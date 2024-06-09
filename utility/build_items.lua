#!/usr/bin/env luajit

--[[ Build the items list
--
-- This script builds the item list for the World Radar mod. It does
-- this by finding all .xml files in data/entities, filtering out the
-- files for things other than items, and parsing the resulting files
-- for the relevant information.
--
-- Usage:
--  luajit utility/build_items.lua -h
--  luajit utility/build_items.lua [-v] [-o FILE] DATA_PATH
-- 
-- FILE defaults to items.lua. Pass "-o -" to write to stdout.
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

local self_name = arg[0]:gsub(".*\\/", "")
local base_path = arg[0]:gsub("[\\/][^\\/]+.lua$", "")
package.path = package.path .. ";" .. table.concat({
    base_path .. "/?.lua",
    base_path .. "/lib/?.lua",
    base_path .. "/../files/lib/?.lua",
}, ";")

io = require 'io'

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
        data_path = nil,
        output = "items.lua",
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

--[[ Get all of the item icons ]]
local function get_item_icons(data_path)
    local icons = {}
    for name in minifs.listdir(data_path .. "/ui_gfx/items") do
        if name:match("[.]png$") then
            icons[name:gsub("[.]png$", "")] = "data/ui_gfx/items/" .. name
        end
    end
    return icons
end

--[[ Is this xml file one we should parse? ]]
local function include_xml_byname(file_path)
    local patterns = {
        "verlet", "placeholder", "hitfx", "aabb", "/custom_cards/",
        "/_debug/", "/_[^/]*$",
    }
    for _, pattern in ipairs(patterns) do
        if file_path:find(pattern) then
            return false
        end
    end
    return true
end

--[[ Does the xml file content look like something we should use? ]]
local function include_xml_bycontent(file_text)
    local patterns = {
        "<ItemComponent", "<BookComponent", "<AbilityComponent",
    }
    for _, pattern in ipairs(patterns) do
        if file_text:find(pattern) then
            return true
        end
    end
    return false
end

--[[ Obtain the nth child having the given name (default first) ]]
local function xml_lookup(root, name, nth)
    local curr_nth = 1
    for index, elem in ipairs(root.children) do
        if elem.name == name then
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
local function merge_xml(parent, referenced)
    local index = 1
    local nth_table = {}
    for _, elem in ipairs(referenced.children) do
        if not nth_table[elem.name] then nth_table[elem.name] = 0 end
        nth_table[elem.name] = nth_table[elem.name] + 1
        local base = xml_lookup(parent, elem.name, nth_table[elem.name])
        if base then
            merge_element(base, elem)
            if #elem.children > 0 then
                merge_xml(base, elem)
            end
        else
            table.insert(parent.children, index, elem)
            index = index + 1
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
local function expand_base_tags(xml, data_path)
    local base_tag, base_index = xml_lookup(xml, "Base")
    if not base_tag then return end

    local parent_path = base_tag.attr.file:gsub("^data%/", data_path .. "/")
    parent_path = parent_path:gsub("[%/]+", "/")
    logger.trace("Expanding %s to %s", base_tag.attr.file, parent_path)
    local root_xml = nxml.parse(read_file(parent_path))
    logger.trace("Merging %s", root_xml)
    logger.trace("Into %s", xml)
    merge_xml(base_tag, root_xml)
    xml_delete(xml, "Base", true, true)

    for _, elem in ipairs(xml.children) do
        expand_base_tags(elem, data_path)
    end
    logger.trace("Result: %s", xml)
end

function main()
    local argv = parse_argv(arg)

    local data = table.concat({
        argv.data_path, "entities"
    }, minifs.PATH_SEPARATOR)
    logger.debug("Searching for xml files in " .. data)

    local icons = get_item_icons(argv.data_path)

    local itemlist = {}
    for _, name in ipairs(find_with_extension(data, "xml")) do
        if not include_xml_byname(name) then goto continue end
        local content = read_file(name)
        if not include_xml_bycontent(content) then goto continue end
        logger.debug("Reading XML file " .. name)
        local root = nxml.parse(content)
        if root.name ~= "Entity" then goto continue end

        expand_base_tags(root, argv.data_path)
        logger.debug("File: %s", name)
        logger.debug(tostring(root))

        ::continue::
    end

    logger.debug("Found %d items in %s", #itemlist, argv.data_path)

    local ofile = io.stdout
    if argv.output ~= "-" then
        ofile = io.open(argv.output, "w")
    end
    ofile:write(([[
-- This file was generated by %s. Do not modify!
return {
]]):format(self_name))
    for _, entry in ipairs(itemlist) do
        local ipath, iname = unpack(entry)
        local iid = string.match(ipath, "([^/]*)%.xml$")
        local icon = icons[iid] or ""
        if icon == "" then
            icon = icons[iname:gsub("^[$][^_]+", "")] or ""
        end
        ofile:write(([[  {id=%q, name=%q, path=%q, icon=%q},
]]):format(iid, iname, ipath, icon))
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
