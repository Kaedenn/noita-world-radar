--[[ Determine the locations of every Orb
--
-- Example invocation:
Orbs:init()
local px, py = EntityGetTransform(get_players()[1])

-- Nearest uncollected orbs
local nearest = Orbs:nearest(px, py)[1]

-- Main world uncollected orbs, ordered by distance
local nearest_main = Orbs:get_main()
table.sort(nearest_main, make_distance_sorter(px, py))

--]]

-- TODO: Determine the biome for NG+ orbs based on location
-- NOTE: This can be done through careful examination of newgame_plus.lua

dofile_once("data/scripts/lib/utilities.lua")

BIOME_EMPTY = "_EMPTY_"
BIOME_SIZE = 512
BIOME_SHIFT = 256

ORB_MAX = 128
WORLD_MAIN = "main"
WORLD_EAST = "east"
WORLD_WEST = "west"

--[[ Convert a world name to a number ]]
function world_get_number(world_name)
    if world_name == WORLD_MAIN then
        return 0
    end
    if world_name == WORLD_EAST then
        return 1
    end
    if world_name == WORLD_WEST then
        return -1
    end
    return nil
end

--[[ Convert a world number to a name ]]
function world_get_name(world_number)
    if world_number < 0 then
        return WORLD_WEST
    end
    if world_number == 0 then
        return WORLD_MAIN
    end
    if world_number > 0 then
        return WORLD_EAST
    end
    return nil
end

--[[ Split an orb ID into a (orb index, world number) pair ]]
function orb_id_split(orbid)
    local orb_num = orbid % ORB_MAX
    local world_index = math.floor(orbid / ORB_MAX)
    local world_number = world_index
    if world_index ~= 0 then
        if world_index % 2 == 1 then
            world_number = (world_index + 1)/2
        else
            world_number = -world_index/2
        end
    end
    return orb_num, world_number
end

--[[ Get a parallel orb ID for the given orb ID ]]
function orb_get_parallel(orbid, world)
    local onum, oworld = orb_id_split(orbid)
    local oadjust = 0
    if world == WORLD_MAIN then
        oadjust = 0
    elseif world == WORLD_WEST then
        oadjust = ORB_MAX
    elseif world == WORLD_EAST then
        oadjust = ORB_MAX*2
    else
        error(("orb_get_parallel(): invalid world %s"):format(world))
    end

    return onum + oadjust
end

--[[ Create a function usable in table.sort(Orbs:get_*()) ]]
function make_distance_sorter(px, py)
    return function(orb1, orb2)
        local x1, y1 = unpack(orb1:pos())
        local x2, y2 = unpack(orb2:pos())
        local dist1 = math.sqrt(math.pow(px-x1, 2) + math.pow(py-y1, 2))
        local dist2 = math.sqrt(math.pow(px-x2, 2) + math.pow(py-y2, 2))
        return dist1 < dist2
    end
end

--[[ Offset an {x,y} pair by the given world ]]
local function pos_offset(orb_pos, world)
    local ox, oy = unpack(orb_pos)
    local world_width = BiomeMapGetSize()*BIOME_SIZE
    if world == WORLD_WEST then
        ox = ox - world_width
    elseif world == WORLD_EAST then
        ox = ox + world_width
    end
    return {ox, oy}
end

Orb = {
    -- Initialize self
    new = function(self, odef) -- {id, name, biome, opos, wpos}
        local this = {}
        setmetatable(this, {
            __index = self,
            __tostring = self.__tostring
        })
        this._id = odef[1]
        this._name = odef[2]
        this._biome = odef[3] or BIOME_EMPTY
        this._orb_pos = odef[4]
        return this
    end,

    id = function(self) return self._id end,
    name = function(self) return self._name end,
    biome = function(self) return self._biome end,
    pos = function(self) return self._orb_pos end,
    index = function(self)
        local orb_index, _ = orb_id_split(self._id)
        return orb_index
    end,
    world = function(self)
        local _, world_num = orb_id_split(self._id)
        return world_num
    end,

    --[[ Return {label, {wx, wy}} for this orb ]]
    as_poi = function(self)
        local name = self._name
        if self._biome ~= "" and self._biome ~= BIOME_EMPTY then
            name = ("%s (%s)"):format(name, self._biome)
        end
        if self:is_collected() then
            name = ("%s (collected)"):format(name)
        end
        return {name, self._real_pos}
    end,

    --[[ True if this orb is collected ]]
    is_collected = function(self)
        return GameGetOrbCollectedThisRun(self._id) or false
    end,

    --[[ Represent this orb as a string ]]
    __tostring = function(self)
        local biome = self:biome()
        if type(biome) == "table" then
            biome = table.concat(biome, " ")
        end
        return ("Orb(%d, %q, %q, {%d, %d})"):format(
            self:id(), self:name(), biome, self:pos()[1], self:pos()[2])
    end,
}

Orbs = {
    --[[
    -- The orb map is complicated, because GameGetOrbCollectedThisRun(idx) and
    -- orb_map_get()[idx+1] do not agree. Moreover, this is different between
    -- NG and NG+.
    --
    -- Columns are:
    --  NG orb index (for orb_map_get location)
    --  NG+ orb index (for orb_map_get location)
    --  orb ID (for GameGetOrbCollectedThisRun)
    --  orb name (really, the book's name)
    --  NG orb biome
    --  NG+ orb biome, if static (optional)
    --]]
    MAP = { -- [ngindex, ng+index, orbid, name, ngbiome[, ng+biome]]
        {1, 1, 0, "Volume I", "Mountain Altar", "Mountain Altar"},
        {10, 0, 1, "Thoth", "$biome_pyramid", "$biome_pyramid"},
        {5, 2, 2, "Volume II", "$biome_vault_frozen"},
        {9, 7, 3, "Volume III", "$biome_lavacave"},
        {8, 3, 4, "Volume IV", "$biome_sandcave"},
        {2, 8, 5, "Volume V", "$biome_wandcave"},
        {3, 9, 6, "Volume VI", "$biome_rainforest_dark"},
        {0, 10, 7, "Volume VII", "$biome_lava", "$biome_lake"},
        {6, 4, 8, "Volume VIII", "$biome_boss_victoryroom", "$biome_boss_victoryroom"},
        {4, 5, 9, "Volume IX", "$biome_winter_caves"},
        {7, 6, 10, "Volume X", "$biome_wizardcave"}, 
    },

    -- Orb objects
    list = {},

    -- Obtain all of the orbs belonging to the given world
    get_within = function(self, world_name, limit_uncollected)
        local wnum = world_get_number(world_name)
        local results = {}
        for _, orb in ipairs(self.list) do
            if orb:world() == wnum then
                if not limit_uncollected or not orb:is_collected() then
                    table.insert(results, orb)
                end
            end
        end
        return results
    end,

    -- Obtain all uncollected orbs
    get_all = function(self, limit_uncollected)
        local results = {}
        for _, orb in ipairs(self.list) do
            if not limit_uncollected or not orb:is_collected() then
                table.insert(results, orb)
            end
        end
        return results
    end,

    -- Obtain all main world orbs
    get_main = function(self, limit_uncollected)
        return self:get_within(WORLD_MAIN, limit_uncollected)
    end,

    -- Obtain all parallel world orbs
    get_parallel = function(self, limit_uncollected)
        local result = {}
        for _, orb in ipairs(self:get_within(WORLD_WEST, limit_uncollected)) do
            table.insert(result, orb)
        end
        for _, orb in ipairs(self:get_within(WORLD_EAST, limit_uncollected)) do
            table.insert(result, orb)
        end
        return result
    end,

    -- Determine the nearest uncollected orb
    nearest = function(self, px, py)
        local results = {}
        for _, orb in ipairs(self.list) do
            if not orb:is_collected() then
                table.insert(results, orb)
            end
        end
        table.sort(results, make_distance_sorter(px, py))
        return results
    end,

    -- Initialize the orb list
    init = function(self)
        local newgame_n = tonumber(SessionNumbersGetValue("NEW_GAME_PLUS_COUNT"))
        local orb_map = orb_map_get()
        for _, orb_def in ipairs(Orbs.MAP) do
            local orb_num = orb_def[1]
            if orb_num+1 > #orb_map then break end
            if newgame_n > 0 then orb_num = orb_def[2] end
            local orb_id = orb_def[3]
            local orb_pos = orb_map[orb_num+1]
            local orb_name = orb_def[4]
            local orb_biome = BiomeMapGetName(orb_pos[1], orb_pos[2])
            if orb_biome == BIOME_EMPTY then
                if newgame_n == 0 then
                    orb_biome = orb_def[5]
                elseif orb_def[6] then
                    orb_biome = orb_def[6]
                end
            end

            local omx, omy = unpack(orb_pos)
            local ox = omx * BIOME_SIZE + BIOME_SHIFT
            local oy = omy * BIOME_SIZE + BIOME_SHIFT

            table.insert(self.list, Orb:new({
                orb_id,
                orb_name,
                orb_biome,
                {ox, oy}
            }))

            if orb_def[3] ~= 10 then
                table.insert(self.list, Orb:new({
                    orb_id+ORB_MAX,
                    orb_name,
                    {"$biome_west", orb_biome},
                    pos_offset({ox, oy}, WORLD_WEST)
                }))
                table.insert(self.list, Orb:new({
                    orb_id+2*ORB_MAX,
                    orb_name,
                    {"$biome_east", orb_biome},
                    pos_offset({ox, oy}, WORLD_EAST)
                }))
            end
        end
    end,
}

return Orbs

-- vim: set ts=4 sts=4 sw=4 tw=79:
