--[[ Build the entity list ]]

io = require 'io'

local base_path = arg[0]:gsub("[\\/][^\\/]+.lua$", "")
package.path = package.path .. ";" .. table.concat({
    base_path .. "/?.lua",
    base_path .. "/../files/lib/?.lua"
}, ";")

function parse_argv(argv)
    local args = {
        verbose = false,
        data_path = nil,
        output = "entities.lua",
    }
    for opti, optv in ipairs(argv) do
        local lead = optv:sub(1, 1)
        if lead ~= "-" then
            if not args.data_path then
                args.data_path = optv
            else
                error(("Unknown argument %d %q"):format(opti, optv))
            end
        elseif optv == "-v" or optv == "--verbose" then
            args.verbose = true
        elseif optv == "-o" or optv == "--output" then
            args.output = optv
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
    end

    if not args.data_path then
        error("Missing required argument data_path")
    end

    if os.getenv("DEBUG") then args.verbose = true end

    return args
end

nxml = require 'nxml'
kae = require 'libkae'
local args = parse_argv(arg)
kae.table.print(args)

-- vim: set ts=4 sts=4 sw=4:
