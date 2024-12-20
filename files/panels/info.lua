--[[
The "Info" Panel: Display interesting information

FIXME: This file is huge
    Refactor supporting code into separate modules, where possible

FIXME: Use a metatable to improve list/cache iteration below O(n)

FIXME: Chest content matching breaks if a chest is opened

FIXME: Remove held items doesn't work for pouches
    Likely because the filename becomes the player

TODO: Refactor "nearby thing scanning" to iterate over the desired object list
    and match based on path instead of scanning via tags. This precludes custom
    non-enemy entities (like portals, props) and may help improve runtime.
        It could also make it worse if we have to iterate over EVERY entity.

TODO: Dynamically limit popup width to screen width

TODO: On-screen UI improvements:
    Refactor to use Panel draw_line_onscreen instead of custom one
    Finish adding icons to treasure chest prediction
    Allow user to configure how the on-screen text is displayed
        Configure anchoring: currently bottom-left, but add other three
        Configure location

TODO: Non-radar improvements:
    Only display the primary biome of a biome group

IDEA: Add "Hide/Show Unknown Spells" selection list checkbox
--]]

dofile_once("data/scripts/lib/utilities.lua")

dofile_once("mods/world_radar/config.lua")
dofile_once("mods/world_radar/files/utility/biome.lua")
dofile_once("mods/world_radar/files/utility/entity.lua")
dofile_once("mods/world_radar/files/utility/material.lua")
dofile_once("mods/world_radar/files/utility/spell.lua")
dofile_once("mods/world_radar/files/utility/treasure_chest.lua")
dofile_once("mods/world_radar/files/utility/orbs.lua")
dofile_once("mods/world_radar/files/utility/eval.lua")
dofile_once("mods/world_Radar/files/utility/draw.lua")
dofile_once("mods/world_radar/files/radar.lua")
dofile_once("mods/world_radar/files/lib/utility.lua")

smallfolk = dofile_once("mods/world_radar/files/lib/smallfolk.lua")
EZWand = dofile_once("mods/world_radar/files/lib/EZWand.lua")

NOWRAP = {wrap=0}           -- Suppress wrapping on hover popups

FALLBACK = "data/ui_gfx/icon_unkown.png"    -- Fallback image

RARE_BIOME = 0.2            -- Biome modifiers "rare" threshold

AC_NONE = 0                 -- Ignore Always Cast
AC_FORBID = 1               -- Forbid Always Cast
AC_REQUIRE = 2              -- Require Always Cast
ACMAX = AC_REQUIRE + 1

GUI_PAD_LEFT = 10           -- Default distance from left edge
GUI_PAD_BOTTOM = 2          -- Default distance from bottom edge

--[[ Panel class with default values.
--
-- Selection menus (spell, material, entity, item) operate as follows:
--  self.env.find_<menu>=true       Master enable/disable checkbox
--  self.env.<menu>_list            Table of selected items
--      <menu>_list[idx].id         Internal ID or unlocalized name
--      <menu>_list[idx].name       Display (possibly localized) name
--      <menu>_list[idx].icon       Path to icon image, if one exists
--      <menu>_list[idx].path       Path to asset file, if applicable
--      <menu>_list[idx].config     Table of arbitrary key-value pairs
--  self.env.<menu>_add_multi=false Allow multiple additions per input
--  self.env.<menu>_text:string     Current input text
--]]
InfoPanel = {
    id = "info",
    name = "Info",
    config = {
        tooltip_wrap = 400,                 -- Default hover tooltip wrap margin
        import_num_lines = 6,               -- Height of the import textarea
        message_timer = 60*10,              -- Default message time (10 seconds)
        range = math.huge,                  -- Range of the radar (infinite)
        range_rule = "infinite",            -- Range of the radar, override
        near_range = 20,                    -- Extra scan max range
        rare_biome_mod = 0.2,               -- Chances below this are rare
        rare_spells = {                     -- Default rare spell list
            {"MANA_REDUCE", keep=1},        -- Add Mana
            {"REGENERATION_FIELD", keep=0}, -- Circle of Vigour
            {"LONG_DISTANCE_CAST", keep=0},
        },
        rare_materials = {                  -- Default rare material list
            "creepy_liquid",                -- Incredibly rare liquid
            "magic_liquid_hp_regeneration", -- Healthium
            "magic_liquid_weakness",        -- Diminution
            "urine",                        -- Spawns rarely in jars
        },
        rare_entities = {                   -- Default rare entity list
            "$animal_worm_big",             -- Giant worm that can drop hearts
            "$animal_chest_leggy",          -- Leggy chest mimic
            "$animal_dark_alchemist",       -- Pahan muisto; heart mimic
            "$animal_mimic_potion",         -- Mimicium potion
            "$animal_playerghost",          -- Kummitus; wand ghost
            "$animal_shaman_wind",          -- Valhe; spell refresh mimic
        },
        rare_items = {                      -- Default rare item list
            "$item_chest_treasure_super",   -- Greater Treasure Chest
            "$item_greed_die",              -- Greed Die
            "$item_waterstone",             -- Vuoksikivi
        },
        gui = {                             -- On-screen UI adjustments
            pad_left = GUI_PAD_LEFT,        -- Distance from left edge
            pad_bottom = GUI_PAD_BOTTOM,    -- Distance from bottom edge
        },
        icons = {
            height = nil,               -- nil -> calculate height
        },
        show_color = true,
        show_images = true,
        pos_relative = false,
        simple_names = true,
        chest_prediction = true,
        chest_scanning = true,
    },
    env = {
        -- list_biomes = true
        -- find_items = true
        -- find_wands = true
        -- find_enemies = true
        -- find_spells = true
        -- onscreen = true
        -- radar = true

        -- show_checkboxes = true
        -- import_dialog = false
        -- import_text = ""
        -- import_data = {plural="", singular="", table_var="", env_var=""}
        -- manage_spells = false
        -- manage_materials = false
        -- manage_entities = false
        -- manage_items = false

        -- material_cache:table = {liquids={name}, gases={name}, ...}
        -- material_liquid = true
        -- material_sand = true
        -- material_gas = false
        -- material_fire = false
        -- material_solid = false
        -- entity_cache:table = nil

        -- spell_list = {{id=string, name=string, icon=string}}
        -- material_list = {{[kind] [id] [name] [uiname] [locname] [icon] [tags]}}
        -- entity_list = {{id=string, name=string, path=string, icon=string}}
        -- item_list = {{id=string, name=string, icon=string}}
        -- wand_matches = {{entid={spell_name}}}
        -- card_matches = {{entid=true}}
        -- spell_add_multi = false
        -- material_add_multi = false
        -- entity_add_multi = false
        -- item_add_multi = false
    },
    host = nil,
    funcs = {},

    -- Types of information to show: name, varname, default, hover
    modes = {
        {"Biomes", "list_biomes", true, "List biome modifiers"},
        {"Items", "find_items", true, "List nearby items"},
        --{"Wands", "find_wands", true, "List nearby wands"},
        {"Enemies", "find_enemies", true, "List nearby enemies"},
        {"Spells", "find_spells", true, "List nearby spells"},
        {"On-screen", "onscreen", true, "Draw on-screen text when closed"},
        {"Radar", "radar", true, "Draw radar icons pointing at found things"},
    },
}

--[[ True if the AC status matches the AC flag ]]
function _want_ac_spell(ac_status, ac_flag)
    if ac_status == AC_NONE then
        return true
    end
    if ac_status == AC_FORBID and not ac_flag then
        return true
    end
    if ac_status == AC_REQUIRE and ac_flag then
        return true
    end
    return false
end

--[[ True if the entry's "keep" flag is 1 ]]
function _want_keep(entry)
    if entry and entry.config and entry.config.keep then
        return entry.config.keep == 1
    end
    return false
end

--[[ True if the table has the given object ]]
function _table_has_object(tbl, entry)
    for _, item in ipairs(tbl) do
        if item.path and entry.path and item.path == entry.path then
            return true
        end
        if item.id == entry.id and item.name == entry.name then
            return true
        end
    end
    return false
end

--[[ Get all of the known materials ]]
function InfoPanel:_get_material_tables()
    -- See files/utility/material.lua generate_material_tables
    if not self.env.material_cache or #self.env.material_cache == 0 then
        self.env.material_cache = generate_material_tables()
        setmetatable(self.env.material_cache, {
            __index = function(self, key)
                return rawget(self, key) -- TODO
            end
        })
    end
    return self.env.material_cache
end

--[[ Get all of the known entities ]]
function InfoPanel:_get_entity_list()
    if not self.env.entity_cache or #self.env.entity_cache == 0 then
        self.env.entity_cache = dofile("mods/world_radar/files/generated/entity_list.lua")
        local cache_obj = self.env.entity_cache
        local function process_appends()
            dofile("mods/world_radar/data/world_radar/append/entity_list.lua")
            -- luacheck: globals ENTITY_EXTRA
            for _, entry in ipairs(ENTITY_EXTRA) do
                table.insert(cache_obj, entry)
            end
        end
        process_appends()
    end
    return self.env.entity_cache
end

--[[ Get all of the known items ]]
function InfoPanel:_get_item_list()
    if not self.env.item_cache or #self.env.item_cache == 0 then
        self.env.item_cache = dofile("mods/world_radar/files/generated/item_list.lua")
        local cache_obj = self.env.item_cache
        local function process_appends()
            dofile("mods/world_radar/data/world_radar/append/item_list.lua")
            -- luacheck: globals ITEM_EXTRA
            for _, entry in ipairs(ITEM_EXTRA) do
                table.insert(cache_obj, entry)
            end
        end
        process_appends()
    end
    return self.env.item_cache
end

--[[ Obtain the spell ID, name, and icon path for a given spell ]]
function InfoPanel:_get_spell_by_name(sname)
    --[[{
    --  id = 'MANA_REDUCE',
    --  name = '$action_mana_reduce',
    --  icon = 'data/ui_gfx/gun_actions/mana.png',
    --  config = {keep=1, ignore_ac=1}
    --}]]
    if not sname or sname == "" then return {} end
    if sname:match("^%$") then sname = sname:gsub("^%$", "") end
    for _, entry in ipairs(get_spell_list()) do
        if table_has_entry({entry.id, entry.name, entry.path}, sname) then
            return {
                id = entry.id,
                name = entry.name,
                icon = entry.sprite,
                config = {},
            }
        end
    end
    return {}
end

--[[ Obtain the material ID, name, etc. for the given name/ID ]]
function InfoPanel:_get_material_by_name(mname)
    --[[{
    --  kind = "sand",
    --  id = 135,
    --  name = "gold",
    --  uiname = "$mat_gold",
    --  locname = "gold",
    --  icon = "data/generated/material_icons/gold.png",
    --  tags = {"[alchemy]", "[corrodible]", "[earth]", "[gold]", ...}
    --}]]
    if type(mname) == "number" then
        mname = CellFactory_GetName(mname)
    end
    if not mname or mname == "" then return {} end
    if self.env.material_cache and #self.env.material_cache > 0 then
        for _, entry in ipairs(self.env.material_cache) do
            if table_has_entry({entry.name, entry.uiname}, mname) then
                return entry
            end
        end
    else
        self.host:print_error("Material cache not ready before _get_material_by_name")
    end
    return {}
end

--[[ Obtain the entity ID, name, etc. for the given name/filename ]]
function InfoPanel:_get_entity_by_name(ename)
    --[[{
    --  id = "blob",
    --  name = "$animal_blob",
    --  path = "data/entities/animals/blob.xml",
    --  icon = "data/ui_gfx/animal_icons/blob.png",
    --  data = {effects={}, health="1.5", herd="slimes"},
    --  tags = "teleportable_NOT,enemy,..."
    --
    --  data.effects[idx] = {frames=number, name=string}
    --}]]
    if not ename or ename == "" then return {} end
    for _, entry in ipairs(self:_get_entity_list()) do
        if table_has_entry({entry.id, entry.name, entry.path}, ename) then
            return entry
        end
    end
    return {}
end

--[[ Obtain the item ID, name, etc. for the given name/filename ]]
function InfoPanel:_get_item_by_name(iname)
    --[[{
    --  id = "chest_random",
    --  name = "$item_chest_treasure",
    --  path = "data/entities/items/pickup/chest_random.xml",
    --  icon = "data/buildings_gfx/chest_random.png",
    --  tags = "teleportable_NOT,item_physics,chest,item_pickup,..."
    --}]]
    if not iname or iname == "" then return {} end
    for _, entry in ipairs(self:_get_item_list()) do
        if table_has_entry({entry.id, entry.name, entry.path}, iname) then
            -- Handle very specific overrides and false classifications
            if entry.id ~= "mimic_potion" or iname ~= "$item_potion" then
                return entry
            end
        end
    end
    return {}
end

--[[ Range check: true if the entity is inside self.range ]]
function InfoPanel:_range_check(entid_or_xy)
    local px, py = EntityGetTransform(get_players()[1])
    if not px or not py then return false end -- Player not loaded

    local ex, ey = nil, nil
    if type(entid_or_xy) == "table" then
        ex = entid_or_xy.x or entid_or_xy[1]
        ey = entid_or_xy.y or entid_or_xy[2]
    elseif type(entid_or_xy) == "number" then
        ex, ey = EntityGetTransform(entid_or_xy)
    end
    if not ex or not ey then
        self.host:print_error(("Failed to get location from %s"):format(entid_or_xy))
        return false
    end

    local range_rule = self.config.range_rule
    if range_rule == "infinite" then
        return true
    elseif range_rule == "onscreen" then
        local sw, sh = GuiGetScreenDimensions(self.gui)
        if ex >= px - sw and ex <= px + sw then
            if ey >= py - sh and ey <= py + sh then
                return true
            end
        end
        return false
    end

    local range = self.config.range
    if range_rule == "world" then
        range = BiomeMapGetSize() * 512 / 2
    elseif range_rule == "perk_range" then
        range = 400
    end

    local dist = math.sqrt(math.pow(px-ex, 2) + math.pow(py-ey, 2))
    return dist <= range
end

--[[ Filter out entities that are children of the player or too far away ]]
function InfoPanel:_filter_entries(entries)
    local results = {}
    for _, entry in ipairs(entries) do
        local entity, name = unpack(entry)
        if not is_child_of(entity, nil) then
            local distance = distance_from(entity, nil)
            if distance <= self.config.range then
                table.insert(results, entry)
            end
        end
    end
    return results
end

--[[ Get all entities having one of the given tags ]]
function InfoPanel:_get_nearby(taglist, filters)
    local simplify = self.config.simple_names
    return self:_filter_entries(get_with_tags(taglist, filters or {}, simplify))
end

--[[ Get all nearby non-held items ]]
function InfoPanel:_get_nearby_items()
    return self:_get_nearby({"item_pickup"})
end

--[[ Get all nearby enemies ]]
function InfoPanel:_get_nearby_enemies()
    return self:_get_nearby({"enemy"})--, "mortal", "hittable"})
end

--[[ Clear treasure chests that have been opened ]]
function InfoPanel:_clear_opened_chests()
    local to_remove = {}
    for lookup_key, entry in pairs(self.env.chest_cache) do
        if not entity_is_chest(entry.entity) then
            table.insert(to_remove, lookup_key)
        end
    end
    for _, lookup_key in ipairs(to_remove) do
        self.env.chest_cache[lookup_key] = nil
    end
end

--[[ Populate the treasure chest cache with nearby chests ]]
function InfoPanel:_cache_treasure_chests()
    local chest_tags = {"chest", "utility_box"}
    for _, itempair in ipairs(self:_get_nearby(chest_tags)) do
        local entity, name = unpack(itempair)
        local lookup_key, seed_x, seed_y = chest_get_lookup_data(entity)
        if lookup_key ~= nil then
            if not self.env.chest_cache[lookup_key] then
                self.env.chest_cache[lookup_key] = {
                    entity=entity,
                    spawn={seed_x, seed_y},
                    contents=chest_get_rewards(entity, self.env.debug.on),
                }
            end
        end
    end
end

--[[ Search for nearby desirable spells; store in self.env ]]
function InfoPanel:_find_spells()
    local spell_table = {}
    for _, entry in ipairs(self.env.spell_list) do
        spell_table[entry.id] = entry
    end
    self.env.wand_matches = {}
    for _, entry in ipairs(self:_get_nearby({"wand"})) do
        local entid = entry[1]
        for _, spell_info in ipairs(wand_get_spells(entid)) do
            local spell_id, spell = unpack(spell_info)
            if not EntityGetIsAlive(entid) then goto continue end
            local spinfo = spell_table[spell]
            if not spinfo then goto continue end
            local spconfig = spinfo.config or {}
            if _want_ac_spell(spconfig.ignore_ac, spell_is_always_cast(spell_id)) then
                if not self.env.wand_matches[entid] then
                    self.env.wand_matches[entid] = {}
                end
                self.env.wand_matches[entid][spell] = spell_id
            end
            ::continue::
        end
    end

    self.env.card_matches = {}
    for _, entry in ipairs(self:_get_nearby({"card_action"})) do
        local entid = entry[1]
        if not EntityGetIsAlive(entid) then goto continue end
        local spell = card_get_spell(entid)
        local parent = EntityGetParent(entid)
        if self.env.wand_matches[parent] then goto continue end
        if spell and spell_table[spell] then
            local spconfig = spell_table[spell].config or {}
            if _want_ac_spell(spconfig.ignore_ac, spell_is_always_cast(entid)) then
                self.env.card_matches[entid] = true
            end
        end
        ::continue::
    end

    self.env.spell_chest_matches = {}
    if self.config.chest_scanning then
        for lookup_key, entry in pairs(self.env.chest_cache) do
            local entid = entry.entity
            if not entity_is_chest(entid) then goto next_chest end
            local entx, enty = EntityGetTransform(entid)
            for _, reward in ipairs(entry.contents) do
                if reward.type ~= "card" then goto next_content end
                for _, card_id in ipairs(reward.entities) do
                    local card = card_id:upper()
                    if not spell_table[card] then goto next_spell end
                    local spconfig = spell_table[card].config or {}
                    if not _want_ac_spell(spconfig.ignore_ac, false) then goto next_spell end
                    table.insert(self.env.spell_chest_matches, {
                        entity=entid,
                        pos={entx, enty},
                        spell=card,
                    })
                    ::next_spell::
                end
                ::next_content::
            end
            ::next_chest::
        end
    end
end

--[[ Locate any flasks/pouches containing desirable materials ]]
function InfoPanel:_find_containers()
    local containers = {}
    for _, item in ipairs(self:_get_nearby({"item_pickup"})) do
        local entity, name = unpack(item)
        local contents = container_get_contents(entity)
        local rare_mats = {}
        for _, material in ipairs(self.env.material_list) do
            if contents[material.name] and contents[material.name] > 0 then
                table.insert(rare_mats, material)
            end
        end
        if #rare_mats > 0 then
            local iinfo = self:_get_item_by_name(entity_get_lookup_key(entity))
            if not iinfo.id then
                iinfo = self:_get_item_by_name("$item_powder_stash_3")
            end
            table.insert(containers, {
                entity = entity,
                name = name,
                contents = contents,
                rare_contents = rare_mats,
                entry = iinfo,
            })
        end
    end

    local chest_containers = {}
    if self.config.chest_scanning then
        for lookup_key, chest_info in pairs(self.env.chest_cache) do
            local entity = chest_info.entity
            if not entity_is_chest(entity) then goto next_chest end
            local entx, enty = EntityGetTransform(entity)
            local entname = item_get_name(entity, true)
            local matlist = {}
            for _, reward in ipairs(chest_info.contents) do
                if reward.type == REWARD.POTION or reward.type == REWARD.POUCH then
                    table.insert(matlist, {
                        reward.entity,
                        reward.content
                    })
                elseif reward.type == REWARD.POTIONS then
                    for idx=1, #reward.entities do
                        table.insert(matlist, {
                            reward.entities[idx],
                            reward.contents[idx]
                        })
                    end
                end
            end
            for _, matinfo in ipairs(matlist) do
                local cpath, mat = unpack(matinfo)
                for _, refdata in ipairs(self.env.material_list) do
                    if mat == refdata.name then
                        table.insert(chest_containers, {
                            entity = entity,
                            pos = {entx, enty},
                            name = entname,
                            path = EntityGetFilename(entity),
                            container = cpath,
                            material = mat,
                        })
                    end
                end
            end
            ::next_chest::
        end
    end

    return containers, chest_containers
end

--[[ Locate any rare enemies nearby
--
-- {{entity=number, name=string, path=string, ...}}
--]]
function InfoPanel:_find_enemies()
    local enemies = {}
    local rare_ents = {}
    for _, entry in ipairs(self.env.entity_list) do
        rare_ents[entry.path] = entry
    end
    for _, enemy in ipairs(self:_get_nearby_enemies()) do
        local entity, name = unpack(enemy)
        local entfname = EntityGetFilename(entity)
        if rare_ents[entfname] then
            local entry = {}
            entry.entity = entity
            entry.name = name
            entry.path = entfname
            for key, val in ipairs(rare_ents[entfname]) do
                entry[key] = val
            end
            table.insert(enemies, entry)
        end
    end

    local chest_enemies = {}
    if self.config.chest_scanning then
        for lookup_key, chest_info in pairs(self.env.chest_cache) do
            local entity = chest_info.entity
            if not entity_is_chest(entity) then goto next_chest end
            local entname = item_get_name(entity, true)
            local entx, enty = EntityGetTransform(entity)
            for _, reward in ipairs(chest_info.contents) do
                local rents = {}
                if reward.entity then table.insert(rents, reward.entity) end
                if reward.entities then
                    for _, ent in ipairs(reward.entities) do
                        table.insert(rents, ent)
                    end
                end
                for _, ent in ipairs(rents) do
                    if rare_ents[ent] then
                        table.insert(chest_enemies, {
                            entity = entity,
                            pos = {entx, enty},
                            name = entname,
                            path = EntityGetFilename(entity),
                            entname = rare_ents[ent].name,
                            entpath = ent,
                        })
                    end
                end
            end
            ::next_chest::
        end
    end

    return enemies, chest_enemies
end

--[[ Search for nearby desirable items
--
-- {{entity=number, name=string, path=string, item=item_def}}
--]]
function InfoPanel:_find_items()
    local items = {}
    for _, itempair in ipairs(self:_get_nearby({"item_pickup"})) do
        local entity, name = unpack(itempair)
        local entry = {entity=entity, name=name, path=EntityGetFilename(entity)}
        for _, item in ipairs(self.env.item_list) do
            if entry.path == item.path then
                entry.entry = item
                table.insert(items, entry)
            end
        end
    end

    local chest_items = {}
    if self.config.chest_scanning then
        for lookup_key, chest_info in pairs(self.env.chest_cache) do
            local entity = chest_info.entity
            if not entity_is_chest(entity) then goto next_chest end
            local entx, enty = EntityGetTransform(entity)
            local entname = item_get_name(entity, true)
            for _, reward in ipairs(chest_info.contents) do
                local ctype = reward.type
                local cpaths = reward.entities or {reward.entity}
                for _, item in ipairs(self.env.item_list) do
                    if table_has_entry(cpaths, item.path) then
                        table.insert(items, {
                            entity = entity,
                            pos = {entx, enty},
                            name = entname,
                            path = EntityGetFilename(entity),
                            item = item.path,
                        })
                    end
                end
            end
            ::next_chest::
        end
    end
    return items, chest_items
end

--[[ Draw the orb radar ]]
function InfoPanel:_draw_orb_radar()
    local enable = conf_get(CONF.ORB_ENABLE)
    if not enable then
        return
    end

    local limit = conf_get(CONF.ORB_LIMIT)
    local display = conf_get(CONF.ORB_DISPLAY)

    local player = get_players()[1]
    local px, py = EntityGetTransform(player)
    if px == nil or py == nil then
        return
    end

    local orb_list = Orbs.list
    if limit == "world" then
        local world = world_get_name(check_parallel_pos(px))
        orb_list = Orbs:get_within(world, true)
    elseif limit == "main" then
        orb_list = Orbs:get_main(true)
    elseif limit == "parallel" then
        orb_list = Orbs:get_parallel(true)
    elseif limit == "both" then
        orb_list = Orbs:get_all(true)
    end

    table.sort(orb_list, make_distance_sorter(px, py))

    for idx = 1, math.min(display, #orb_list) do
        local orb_x, orb_y = unpack(orb_list[idx]:pos())
        Radar:draw_for_pos(orb_x, orb_y, RADAR_ORB, {
            range = BiomeMapGetSize() * BIOME_SIZE / 8
        })
    end
end

--[[ Draw the on-screen UI and the radar indicators, if enabled ]]
function InfoPanel:_draw_onscreen_gui()
    local gui = self.gui
    local id = 0
    local screen_width, screen_height = GuiGetScreenDimensions(gui)
    local char_width, char_height = GuiGetTextDimensions(gui, "M")
    local function next_id()
        id = id + 1
        return id
    end
    GuiStartFrame(gui)
    GuiIdPushString(gui, "world_radar_panel_info")

    local ui_show = self.env.onscreen
    local radar_show = self.env.radar
    if radar_show then
        Radar:configure{indicator_distance=conf_get(CONF.RADAR_DISTANCE)}
    end

    local padx, pady = self.config.gui.pad_left, self.config.gui.pad_bottom
    local linenr = 0

    -- Get the Y adjustment required to center the image on the line
    local function center_vertical(image_height)
        return (image_height - char_height) / 2
    end

    local this = self

    -- Draw text; returns right X coordinate
    local function draw_text(text_arg, xpos)
        local linex = xpos or padx
        local liney = screen_height - char_height * linenr - pady
        local text = text_arg
        if type(text_arg) == "table" then
            text = text_arg[1]
            if text_arg.color and this.config.show_color then
                GuiColorSetForNextWidget(gui, unpack(text_arg.color))
            end
        end
        GuiText(gui, linex, liney, text)
        local textw, texth = GuiGetTextDimensions(gui, text)
        return xpos + textw
    end

    local function draw_line(line)
        if not ui_show then return end
        linenr = linenr + 1
        local linex = padx
        local liney = screen_height - char_height * linenr - pady
        local text = line
        if type(line) == "table" then
            text = line[1]
            local images = {}
            if this.config.show_images then
                if line.image then
                    images = {line.image}
                elseif line.images then
                    images = line.images
                end
            end
            for _, image in ipairs(images) do
                local imgw, imgh = GuiGetImageDimensions(gui, image)
                if imgw and imgh then
                    local scale = 1
                    if imgw > char_height or imgh > char_height then
                        scale = char_height / math.max(imgw, imgh)
                    end
                    local imgy = liney - center_vertical(imgh*scale)
                    GuiImage(gui, next_id(), linex, imgy, image, 1, scale, 0)
                    linex = linex + imgw * scale + 2
                end
            end
            for _, text_part in ipairs(line) do
                linex = draw_text(text_part, linex)
            end
        else
            GuiText(gui, linex, liney, text)
        end
    end

    local function draw_lines(lines)
        for idx=#lines, 1, -1 do
            draw_line(lines[idx])
        end
    end

    local function draw_radar(entid, kind)
        if radar_show then
            Radar:draw_for(entid, kind)
        end
    end

    local cyellow = {1, 1, 0.5, 1}
    local ccyan = {0.5, 1, 1, 1}
    local cgreen = {0.5, 1, 0.5, 1}

    local found_ents, found_chest_ents = self:_find_enemies()
    for _, entry in ipairs(aggregate(found_ents)) do
        local entname, entities = unpack(entry)
        local entinfo = self:_get_entity_by_name(entity_get_lookup_key(entities[1]))
        draw_line({
            {("%dx "):format(#entities), color=cyellow},
            {entname, color=ccyan},
            " detected nearby!!",
            image=entinfo.icon or FALLBACK,
        })
        for _, entid in ipairs(entities) do
            draw_radar(entid, RADAR_KIND_ENTITY)
        end
    end
    for _, entry in ipairs(found_chest_ents) do
        local entinfo = self:_get_entity_by_name(entry.entpath)
        local entname = GameTextGetTranslatedOrNot(entry.entname)
        draw_line({
            {entry.name, color=ccyan},
            " with ",
            {entname, color=cgreen},
            " detected nearby!!",
            image=entinfo.icon or FALLBACK,
        })
        draw_radar(entry.entity, RADAR_KIND_ENTITY)
    end

    local found_item_ids = {}

    local found_mats, found_chest_mats = self:_find_containers()
    for _, entry in ipairs(found_mats) do
        found_item_ids[entry.entity] = entry
        local contents = {}
        local images = {entry.entry.icon}
        for _, material in ipairs(entry.rare_contents) do
            table.insert(contents, GameTextGetTranslatedOrNot(material.uiname))
            table.insert(images, material_get_icon(material.name))
        end
        draw_line({
            {entry.name, color=ccyan},
            " with ",
            {table.concat(contents, ", "), color=ccyan},
            " detected nearby!!",
            images=images,
        })
        draw_radar(entry.entity, RADAR_KIND_MATERIAL)
    end
    for _, entry in ipairs(found_chest_mats) do
        local item_info = self:_get_item_by_name(entry.container)
        local item_name = GameTextGetTranslatedOrNot(item_info.name)
        draw_line({
            {entry.name, color=ccyan},
            " containing ",
            {item_name, color=cgreen},
            " with ",
            {entry.material, color=ccyan},
            " detected nearby!!",
            images={item_info.icon, material_get_icon(entry.material)},
        })
        draw_radar(entry.entity, RADAR_KIND_MATERIAL)
    end

    local found_item_list, found_chest_items = self:_find_items()
    for _, entry in ipairs(found_item_list) do
        if not found_item_ids[entry.entity] then
            draw_line({
                {entry.name, color=ccyan},
                " detected nearby!!",
            })
            draw_radar(entry.entity, RADAR_KIND_ITEM)
        end
    end
    for _, entry in ipairs(found_chest_items) do
        local item_info = self:_get_item_by_name(entry.item)
        local item_name = GameTextGetTranslatedOrNot(item_info.name)
        draw_line({
            {entry.name, color=ccyan},
            " containing ",
            {item_name, color=ccyan},
            " detected nearby!!",
            image=item_info.icon or FALLBACK,
        })
        draw_radar(entry.entity, RADAR_KIND_ITEM)
    end

    for entid, ent_spells in pairs(self.env.wand_matches) do
        local spell_list = {}
        local image_list = {}
        for spell_id, _ in pairs(ent_spells) do
            local spell_name = spell_get_name(spell_id)
            local loc_name = GameTextGetTranslatedOrNot(spell_name)
            if spell_is_always_cast(spell_id) then
                loc_name = "Always Cast " .. loc_name
            end
            table.insert(spell_list, loc_name)
            local spell_icon = spell_get_icon(spell_id, FALLBACK)
            table.insert(image_list, spell_icon)
        end
        local spells = table.concat(spell_list, ", ")
        draw_line({
            "Wand with ",
            {spells, color=ccyan},
            " detected nearby!!",
            images=image_list,
        })
        draw_radar(entid, RADAR_KIND_SPELL)
    end

    for entid, _ in pairs(self.env.card_matches) do
        local spell = card_get_spell(entid)
        local spell_name = spell_get_name(spell) or spell
        spell_name = GameTextGetTranslatedOrNot(spell_name)
        draw_line({
            "Spell ",
            {spell_name, color=ccyan},
            " detected nearby!!",
            image=spell_get_icon(spell, FALLBACK),
        })
        draw_radar(entid, RADAR_KIND_SPELL)
    end

    for _, entry in ipairs(self.env.spell_chest_matches) do
        local entid = entry.entity
        local entpos = entry.pos
        local spell_id = entry.spell
        local spell_name = spell_get_name(spell_id)
        local loc_name = GameTextGetTranslatedOrNot(spell_name)
        draw_line({
            {item_get_name(entid, true), color=cgreen},
            " containing spell ",
            {loc_name, color=ccyan},
            " detected nearby!!",
            image=spell_get_icon(spell_id, FALLBACK),
        })
        draw_radar(entid, RADAR_KIND_SPELL)
    end

    if self.config.chest_prediction then
        local px, py = EntityGetTransform(get_players()[1])
        if px ~= nil and py ~= nil then
            for _, tag in ipairs({"chest", "utility_box"}) do
                local r = self.config.near_range
                for _, chest_id in ipairs(EntityGetInRadiusWithTag(px, py, r, tag)) do
                    local lines = {"Treasure chest should drop..."}
                    local reward_list = chest_get_rewards(chest_id, self.env.debug.on)
                    table_extend(lines, format_rewards(reward_list))
                    draw_lines(lines)
                end
            end
        end
    end

    GuiIdPop(gui)
end

--[[ Perform any needed updates on a specific table ]]
function InfoPanel:_update_table(data, name)
    local modified = false
    for _, tbl_entry in ipairs(data) do
        if not tbl_entry.config then
            tbl_entry.config = {}
            modified = true
        end
        if name == "spells" then
            if not tbl_entry.config.keep then
                tbl_entry.config.keep = 0
                modified = true
            end
            if not tbl_entry.config.ignore_ac then
                tbl_entry.config.ignore_ac = AC_NONE
                modified = true
            end
        elseif name == "materials" then
            if not tbl_entry.tags then
                tbl_entry.tags = CellFactory_GetTags(tbl_entry.id)
                modified = true
            end
            if not tbl_entry.config.keep then
                tbl_entry.config.keep = 0
                modified = true
            end
        elseif name == "entities" then
            local entinfo = self:_get_entity_by_name(tbl_entry.path)
            if not tbl_entry.tags then
                tbl_entry.tags = entinfo.tags
                modified = true
            end
            if not tbl_entry.data then
                tbl_entry.data = entinfo.data or {}
                modified = true
            end
        elseif name == "items" then
            if not tbl_entry.config.keep then
                tbl_entry.config.keep = 0
                modified = true
            end
        end
    end
    return modified
end

--[[ Initialize the various tables from their various places ]]
function InfoPanel:_init_tables()
    local tables = {
        {"spell_list", "spells", self.config.rare_spells},
        {"material_list", "materials", self.config.rare_materials},
        {"entity_list", "entities", self.config.rare_entities},
        {"item_list", "items", self.config.rare_items},
    }

    for _, entry in ipairs(tables) do
        local var, name, default = unpack(entry)
        -- Load from <lua_globals>
        local sdata = self.host:get_var(self.id, var, "{}")
        local data = smallfolk.loads(sdata)
        local from_table = "local"
        -- If that fails, load from ModSettings
        if #data == 0 then
            sdata = self.host:load_value(self.id, var, "{}")
            data = smallfolk.loads(sdata)
            from_table = "global"
        end
        -- If that fails, load from self.config
        if #data == 0 then
            data = {}
            for _, item in ipairs(default) do
                local iid = item
                if type(item) == "table" then iid = item[1] end
                local new_entry = nil
                if var == "spell_list" then
                    new_entry = self:_get_spell_by_name(iid)
                elseif var == "material_list" then
                    new_entry = self:_get_material_by_name(iid)
                elseif var == "entity_list" then
                    new_entry = self:_get_entity_by_name(iid)
                elseif var == "item_list" then
                    new_entry = self:_get_item_by_name(iid)
                end
                if not new_entry or table_empty(new_entry) then
                    self.host:print_error(("Failed to map %s %q"):format(var, iid))
                    new_entry = {
                        id = iid,
                        name = iid,
                        path = nil,
                        icon = nil,
                        config = {},
                    }
                end
                if not new_entry.config then
                    new_entry.config = {}
                end
                if type(item) == "table" then
                    for cname, cval in pairs(item) do
                        new_entry.config[cname] = cval
                    end
                end
                table.insert(data, new_entry)
            end
            from_table = "default"
        end
        if #data > 0 then
            if self:_update_table(data, name) then
                print(("Updated missing data for %s table"):format(name))
                self.host:set_var(self.id, var, smallfolk.dumps(data))
            end
            self.env[var] = data
            print(("Loaded %d %s from %s %s table"):format(
                #self.env[var], name, from_table, var))
        end
    end
end

--[[ Simply draw the mode checkboxes ]]
function InfoPanel:_draw_checkboxes(imgui)
    if not self.env.show_checkboxes then return end

    for idx, bpair in ipairs(self.modes) do
        if idx > 1 then imgui.SameLine() end
        imgui.SetNextItemWidth(100)
        local name, varname, default, hover = unpack(bpair)
        local ret, value = imgui.Checkbox(name, self.env[varname])
        self:_draw_hover_tooltip(imgui, hover, nil)
        if ret then
            self.env[varname] = value
            self.host:set_var(self.id, varname, value and "1" or "0")
        end
    end
end

--[[ Draw a hover tooltip
--
-- content: string
-- content: function(imgui, self, config|nil)
-- config.wrap: text wrap pos, default 400, use 0 to disable
--]]
function InfoPanel:_draw_hover_tooltip(imgui, content, config)
    if imgui.IsItemHovered() then
        if imgui.BeginTooltip() then
            local wrap = config and config.wrap or self.config.tooltip_wrap
            if wrap > 0 then
                imgui.PushTextWrapPos(wrap)
            end
            if type(content) == "string" then
                imgui.Text(content)
            elseif type(content) == "function" then
                content(imgui, self, config)
            elseif type(content) == "table" then
                self.host:draw_line(imgui, content, nil, nil)
            end
            if wrap > 0 then
                imgui.PopTextWrapPos()
            end
            imgui.EndTooltip()
        end
    end
end

--[[ Create a function that draws the hover tooltip for a wand entity ]]
function InfoPanel:_make_wand_hover_func(entid, name)
    local function format_frame_count(label, num_frames)
        local time_fmt = "%0.2f"
        if num_frames % 60 == 0 then
            time_fmt = "%d.0 s"
        end
        local time_str = time_fmt:format(num_frames / 60)
        return ("%s %s (%d frames)"):format(label, time_str, num_frames)
    end
    local this = self
    return function(imgui, self_)
        local entkey = entity_get_lookup_key(entid)
        local wand_info = this:_get_item_by_name(entkey)
        local wand_icon = wand_get_icon(entid) or wand_info.icon or FALLBACK
        local wand = EZWand(entid)
        if wand_info.id then
            imgui.Text(("%s [%s]"):format(wand_info.name, wand_info.id))
        else
            imgui.Text(("%s (unknown wand)"):format(name))
        end
        imgui.Text(("Path: %s"):format(EntityGetFilename(entid)))
        imgui.Text(("Shuffle: %s"):format(wand.shuffle and "Yes" or "No"))
        imgui.Text(("Capacity: %d"):format(wand.capacity))
        imgui.Text(("Spells per Cast: %d"):format(wand.spellsPerCast))
        imgui.Text(format_frame_count("Cast Delay:", wand.castDelay))
        imgui.Text(format_frame_count("Recharge Time:", wand.rechargeTime))
        imgui.Text(("Mana: %d"):format(wand.mana))
        imgui.Text(("Spread: %s degrees"):format(wand.spread))
        imgui.Text(("Speed: %0.3fx"):format(wand.speedMultiplier))

        --[[ This draws below the GUI
        local screen_w, screen_h = imgui.GetMainViewportWorkSize()
        local cursor_x, cursor_y = imgui.GetCursorPos()
        local ui_x = cursor_x / screen_w * 100
        local ui_y = cursor_y / screen_h * 100
        wand:RenderTooltip(ui_x, ui_y, this.host.gui, 200)]]
    end
end

--[[ Create a function that draws the hover tooltip for a spell ]]
function InfoPanel:_make_spell_tooltip_func(entry)
    return function(imgui, self_)
        if not entry then return end
        local data = spell_get_data(entry.id)
        imgui.Text(entry.id)
        if not stats_check_spell(entry.id) then
            draw_spell_new(imgui)
        end
        imgui.Text(("Type: %s [%d]"):format(action_lookup(data.type), data.type))
        local price_text = data.price and tostring(data.price) or "<unknown>"
        imgui.Text(("Price: %s"):format(price_text))
        local mana_text = data.mana and tostring(data.mana) or "<unknown>"
        imgui.Text(("Mana: %s"):format(mana_text))
        if data.max_uses then
            imgui.Text(("Charges: %d"):format(data.max_uses))
        end

        local lv_pairs = {}
        if data.spawn_level and data.spawn_probability then
            local levels = split_string(data.spawn_level, ",")
            local probs = split_string(data.spawn_probability, ",")
            for idx = 1, math.min(#levels, #probs) do
                table.insert(lv_pairs, {levels[idx], probs[idx]})
            end
        end
        if #lv_pairs > 0 then
            imgui.Text("Spawn levels:")
            for idx, lv_pair in ipairs(lv_pairs) do
                local lvnum, lvprob = unpack(lv_pair)
                imgui.Text(("  %d (%.2f)"):format(lvnum, lvprob))
                if idx % 3 ~= 0 then
                    imgui.SameLine()
                end
            end
        end
    end
end

--[[ Create a function that draws the hover tooltip for a material ]]
function InfoPanel:_make_material_tooltip_func(entry)
    return function(imgui, self_)
        local function text_maybe(label, value)
            if value then
                imgui.Text(("%s: %s"):format(label, value))
            end
        end

        if not entry then return end
        local kind = entry.kind
        local matid = entry.id
        local matname = entry.name
        local matuiname = entry.uiname
        imgui.Text(("%s (ID: %s, type %s)"):format(matname, matid, kind))
        imgui.Text(("UI Name: %s"):format(matuiname))

        local mdata = get_material_data_for(matname)
        if mdata.name then
            text_maybe("HP", mdata.hp)
            text_maybe("Density", mdata.density)
            text_maybe("Durability", mdata.durability)
            if tostring(mdata.burnable) == "1" then
                imgui.Text(("Burnable; burn health: %s"):format(mdata.fire_hp))
            end
        end

        imgui.Text(("Tags: %s"):format(table.concat(entry.tags, " ")))
    end
end

--[[ Create a function that draws the hover tooltip for an enemy ]]
function InfoPanel:_make_enemy_tooltip_func(entry)
    return function(imgui, self_)
        if not entry then return end
        imgui.Text(("%s (ID: %s)"):format(entry.name, entry.id))
        imgui.Text(("Tags: %s"):format(entry.tags))
        imgui.Text(("Path: %s"):format(entry.path))
        if entry.data then
            if entry.data.herd then
                imgui.Text(("Herd: %s"):format(entry.data.herd))
            end
            if entry.data.health then
                local health = tonumber(entry.data.health)
                local mult = MagicNumbersGetValue("GUI_HP_MULTIPLIER")
                imgui.Text(("Health: %d"):format(math.floor(health * mult)))
            end
            if entry.data.effects then
                for _, effect in ipairs(entry.data.effects) do
                    local line = ("Has effect %s"):format(effect.name)
                    if effect.frames ~= -1 then
                        line = line .. (" for %d frames"):format(effect.frames)
                    end
                    imgui.Text(line)
                end
            end
        end
    end
end

--[[ Create a function that draws the hover tooltip for an item ]]
function InfoPanel:_make_item_tooltip_func(entry)
    return function(imgui, self_)
        if not entry then return end
        imgui.Text(("%s (ID: %s)"):format(entry.name, entry.id))
        imgui.Text(("Tags: %s"):format(entry.tags))
        imgui.Text(("Path: %s"):format(entry.path))
    end
end

--[[ Draw the various inputs common to the dropdown functions
--
-- config.label         one of "Spell", "Material", etc
-- config.var_prefix    one of "spell", "material", etc
-- config.var_manage    one of "manage_spells", "manage_materials", etc
-- config.hover_text    optional text to display on text input hover
--]]
function InfoPanel:_draw_dropdown_inputs(imgui, config)
    local var_prefix = config.var_prefix or error("Missing var_prefix")
    local var_manage = config.var_manage or error("Missing var_manage")

    local var_add_multi = var_prefix .. "_add_multi"
    local var_list = var_prefix .. "_list"
    local var_text = var_prefix .. "_text"
    if not self.env[var_text] then self.env[var_text] = "" end
    imgui.SetNextItemWidth(400)
    _, self.env[var_text] = imgui.InputText(
        ("%s###%s_input"):format(config.label, var_prefix),
        self.env[var_text])
    if config.hover_text then
        self:_draw_hover_tooltip(imgui, config.hover_text, config.hover_config)
    end
    imgui.SameLine()
    if imgui.SmallButton(("Done###%s_done"):format(var_prefix)) then
        self.env[var_manage] = false
        self.env[var_text] = ""
    end
    imgui.SameLine()
    if imgui.SmallButton(("Save###%s_save"):format(var_prefix)) then
        local data = smallfolk.dumps(self.env[var_list])
        self.host:set_var(self.id, var_list, data)
        self.env[var_manage] = false
        self.env[var_text] = ""
    end
    self:_draw_hover_tooltip(imgui, "Save entries to the 'This Run' list")
    imgui.SameLine()
    _, self.env[var_add_multi] = imgui.Checkbox(
        ("Multi###%s"):format(var_add_multi),
        self.env[var_add_multi])
    self:_draw_hover_tooltip(imgui, "Add multiple entries at a time")
end

function InfoPanel:_draw_spell_dropdown(imgui)
    self:_draw_dropdown_inputs(imgui, {
        label = "Spell",
        var_prefix = "spell",
        var_manage = "manage_spells",
        hover_text = "Spell name or internal ID",
    })

    -- TODO: Add "show only discovered spells" input

    if self.env.spell_text ~= "" then
        local match_text = self.env.spell_text:gsub("[^a-zA-Z0-9_]", "")
        local match_upper, match_lower = match_text:upper(), match_text:lower()
        for _, spell_entry in ipairs(get_spell_list()) do
            local entry = {
                id = spell_entry.id,
                name = spell_entry.name,
                icon = spell_entry.sprite,
                config = {keep=0, ignore_ac=AC_NONE},
            }
            local add_me = false
            if entry.id:match(match_upper) then
                add_me = true
            elseif entry.name:lower():match(match_lower) then
                add_me = true
            end
            local locname = GameTextGetTranslatedOrNot(entry.name)
            if locname and locname ~= "" then
                if locname:lower():match(match_lower) then
                    add_me = true
                end
            end
            -- Hide duplicate spells from being added more than once
            for _, spell in ipairs(self.env.spell_list) do
                if spell.id == entry.id then
                    add_me = false
                end
            end
            if add_me then
                local hover_func = self:_make_spell_tooltip_func(entry)
                if imgui.SmallButton("Add###add_" .. entry.id) then
                    if not self.env.spell_add_multi then self.env.spell_text = "" end
                    if self:_player_has_spell(entry.id) then
                        entry.config.keep = 1
                    end
                    table.insert(self.env.spell_list, entry)
                end
                imgui.SameLine()
                if entry.icon and self.config.show_images then
                    self.host:draw_image(imgui, entry.icon, true)
                    self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
                    imgui.SameLine()
                end
                if not locname or locname == "" then locname = entry.name end
                imgui.Text(("%s (%s)"):format(locname, entry.id))
                if not stats_check_spell(entry.id) then
                    imgui.SameLine()
                    draw_spell_new(imgui)
                end
                self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
            end
        end
    end
end

function InfoPanel:_draw_spell_list(imgui)
    local ret
    local to_remove = nil
    imgui.SeparatorText("Spell List")
    for idx, entry in ipairs(self.env.spell_list) do
        if not entry.config then entry.config = {} end
        if imgui.SmallButton("Remove###remove_" .. entry.id) then
            to_remove = idx
        end
        imgui.SameLine()
        local keep = entry.config.keep == 1
        ret, keep = imgui.Checkbox("###keep_" .. entry.id, keep)
        if ret then
            entry.config.keep = keep and 1 or 0
        end
        self:_draw_hover_tooltip(imgui, "If checked, do not remove this spell upon pickup")
        imgui.SameLine()

        local iac_label = ({
            [AC_NONE] = "-",
            [AC_FORBID] = "I",
            [AC_REQUIRE] = "R",
        })[entry.config.ignore_ac or AC_NONE]

        if imgui.SmallButton(iac_label .. "###ignore_ac_" .. entry.id) then
            entry.config.ignore_ac = (entry.config.ignore_ac + 1) % ACMAX
        end
        self:_draw_hover_tooltip(imgui, {
            {"Determines the behavior if the found spell happens to be an Always Cast"},
            {"[-] will match spells regardless of Always Cast", clear_line=true},
            {"[I] will ignore spells if they're Always Cast", clear_line=true},
            {"[R] will ignore spells if they're not Always Cast", clear_line=true},
        }, NOWRAP)
        imgui.SameLine()
        local hover_func = self:_make_spell_tooltip_func(entry)
        if entry.icon and self.config.show_images then
            self.host:draw_image(imgui, entry.icon, true)
            self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
            imgui.SameLine()
        end
        local label = GameTextGetTranslatedOrNot(entry.name)
        local text = ("%s [%s]"):format(label, entry.id)
        imgui.Text(self.config.simple_names and label or text)
        if not stats_check_spell(entry.id) then
            imgui.SameLine()
            draw_spell_new(imgui)
        end
        self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
    end
    if to_remove ~= nil then
        table.remove(self.env.spell_list, to_remove)
    end
end

function InfoPanel:_draw_material_dropdown(imgui)
    self:_draw_dropdown_inputs(imgui, {
        label = "Material",
        var_prefix = "material",
        var_manage = "manage_materials",
        hover_text = function(imgui_, self_)
            imgui_.Text("Material name, internal ID, or tag")
            imgui_.Text("To match against tags, enter the tag in brackets like so:")
            imgui_.Text("\t[water]")
            imgui_.Text("This will match all materials with the 'water' tag")
        end,
        hover_config = {width=500},
    })

    -- {name, checkbox_varname, table_name}
    local kinds = {
        {"Liquids", "material_liquid", "liquids"},
        {"Sands", "material_sand", "sands"},
        {"Gases", "material_gas", "gases"},
        {"Fires", "material_fire", "fires"},
        {"Solids", "material_solid", "solids"},
    }
    for idx, kind in ipairs(kinds) do
        local label, var, tbl = unpack(kind)
        if idx ~= 1 then imgui.SameLine() end
        imgui.SetNextItemWidth(80)
        _, self.env[var] = imgui.Checkbox(label .. "###show_" .. var, self.env[var])
    end

    if self.env.material_text ~= "" then
        local tag = nil
        if self.env.material_text:match("^%[") then
            tag = self.env.material_text:gsub("[%[%]]", "")
        end
        local match_text = self.env.material_text:gsub("[^a-z0-9_]", "")
        local mattabs = self:_get_material_tables()
        for _, entry in ipairs(mattabs) do
            local kind = entry.kind
            local matid = entry.id
            local matname = entry.name
            local matuiname = entry.uiname
            local matlocname = entry.locname
            local maticon = entry.icon
            local mattags = entry.tags
            local varname = "material_" .. kind
            if not self.env[varname] then
                goto continue
            end
            local add_me = false
            if tag ~= nil then
                for _, mtag in ipairs(mattags) do
                    if mtag:match(tag) then
                        add_me = true
                    end
                end
            elseif matname:match(match_text) then
                add_me = true
            elseif matuiname:match(match_text) then
                add_me = true
            elseif matlocname:match(match_text) then
                add_me = true
            end

            -- Hide duplicate materials from being added more than once
            for _, list_entry in ipairs(self.env.material_list) do
                if matid == list_entry.id then
                    add_me = false
                end
            end

            if not add_me then
                goto continue
            end

            if imgui.SmallButton("Add###add_mat_" .. matname) then
                if not self.env.material_add_multi then self.env.material_text = "" end
                local mat_entry = {
                    kind = kind,
                    id = matid,
                    name = matname,
                    uiname = matuiname,
                    locname = matlocname,
                    icon = maticon,
                    tags = mattags,
                    config = {keep=0},
                }
                if self:_player_has_material(matname) then
                    mat_entry.config.keep = 1
                end
                table.insert(self.env.material_list, mat_entry)
            end
            imgui.SameLine()
            local hover_tooltip_func = self:_make_material_tooltip_func(entry)
            if maticon and self.config.show_images then
                self.host:draw_image(imgui, maticon, true)
                self:_draw_hover_tooltip(imgui, hover_tooltip_func, NOWRAP)
                imgui.SameLine()
            end
            imgui.Text(("%s (%s)"):format(matlocname, matname))
            self:_draw_hover_tooltip(imgui, hover_tooltip_func, NOWRAP)

            ::continue::
        end
    end
end

function InfoPanel:_draw_material_list(imgui)
    local ret
    local to_remove = nil
    imgui.SeparatorText("Material List")
    for idx, entry in ipairs(self.env.material_list) do
        if not entry.config then entry.config = {} end
        if imgui.SmallButton("Remove###remove_" .. entry.name) then
            to_remove = idx
        end
        imgui.SameLine()
        local keep = entry.config.keep == 1
        ret, keep = imgui.Checkbox("###keep_" .. entry.id, keep)
        if ret then
            entry.config.keep = keep and 1 or 0
        end
        self:_draw_hover_tooltip(imgui, "If checked, do not remove this material upon pickup")
        imgui.SameLine()
        local hover_tooltip_func = self:_make_material_tooltip_func(entry)
        if entry.icon and self.config.show_images then
            self.host:draw_image(imgui, entry.icon, true)
            self:_draw_hover_tooltip(imgui, hover_tooltip_func, NOWRAP)
            imgui.SameLine()
        end
        local text = ("%s [%s]"):format(entry.locname, entry.name)
        imgui.Text(self.config.simple_names and entry.locname or text)
        self:_draw_hover_tooltip(imgui, hover_tooltip_func, NOWRAP)
    end
    if to_remove ~= nil then
        table.remove(self.env.material_list, to_remove)
    end
end

function InfoPanel:_draw_entity_dropdown(imgui)
    self:_draw_dropdown_inputs(imgui, {
        label = "Entity",
        var_prefix = "entity",
        var_manage = "manage_entities",
        hover_text = "Entity name or internal ID",
    })

    if self.env.entity_text ~= "" then
        local tag = nil
        if self.env.entity_text:match("^%[") then
            tag = self.env.entity_text:gsub("[%[%]]", "")
        end
        local match_text = self.env.entity_text:gsub("[^a-zA-Z0-9_ ]", "")
        local enttab = self:_get_entity_list()
        for _, entry in ipairs(enttab) do
            local add_me = false
            if tag ~= nil then
                for _, mtag in ipairs(split_string(entry.tags, ",")) do
                    if mtag:match(tag) then
                        add_me = true
                    end
                end
            end
            local locname = GameTextGetTranslatedOrNot(entry.name)
            if not locname or locname == "" then locname = entry.name end
            if entry.name:match(match_text) then
                add_me = true
            elseif entry.path:match(match_text) then
                add_me = true
            elseif locname and locname ~= "" then
                if locname:lower():match(match_text:lower()) then
                    add_me = true
                end
            end
            -- Hide duplicate entities from being added more than once
            for _, entity in ipairs(self.env.entity_list) do
                if entity.path == entry.path then
                    add_me = false
                end
            end
            if add_me then
                local bid = "Add###add_" .. entry.path:gsub("[^a-z_]", "")
                if imgui.SmallButton(bid) then
                    if not self.env.entity_add_multi then self.env.entity_text = "" end
                    table.insert(self.env.entity_list, {
                        id = entry.id,
                        name = entry.name,
                        path = entry.path,
                        icon = entry.icon,
                        tags = entry.tags,
                        data = entry.data or {},
                        config = {},
                    })
                end
                imgui.SameLine()
                local hover_fn = self:_make_enemy_tooltip_func(entry)
                if self.config.show_images then
                    self.host:draw_image(imgui, entry.icon, true, {})
                    self:_draw_hover_tooltip(imgui, hover_fn, {wrap=800})
                    imgui.SameLine()
                end
                imgui.Text(animal_build_name(entry.name, entry.path))
                self:_draw_hover_tooltip(imgui, hover_fn, {wrap=800})
            end
        end
    end
end

function InfoPanel:_draw_entity_list(imgui)
    local to_remove = nil
    imgui.SeparatorText("Entity List")
    for idx, entry in ipairs(self.env.entity_list) do
        if not entry.config then entry.config = {} end
        local bid = ("Remove###remove_%s_%d"):format(entry.id, idx)
        if imgui.SmallButton(bid) then
            to_remove = idx
        end
        imgui.SameLine()
        local hover_fn = self:_make_enemy_tooltip_func(entry)
        if entry.icon and self.config.show_images then
            self.host:draw_image(imgui, entry.icon, true, {})
            self:_draw_hover_tooltip(imgui, hover_fn, {wrap=800})
            imgui.SameLine()
        end
        imgui.Text(animal_build_name(entry.name, entry.path))
        self:_draw_hover_tooltip(imgui, hover_fn, {wrap=800})
    end
    if to_remove ~= nil then
        table.remove(self.env.entity_list, to_remove)
    end
end

function InfoPanel:_draw_item_dropdown(imgui)
    self:_draw_dropdown_inputs(imgui, {
        label = "Item",
        var_prefix = "item",
        var_manage = "manage_items",
        hover_text = function(imgui_, self_)
            imgui_.Text("Item name, internal ID, or tag")
            imgui_.Text("To match against tags, enter the tag in brackets like so:")
            imgui_.Text("\t[wand]")
            imgui_.Text("This will match all wands.")
        end,
        hover_config = {width=500},
    })

    if self.env.item_text ~= "" then
        local tag = nil
        if self.env.item_text:match("^%[") then
            tag = self.env.item_text:gsub("[%[%]]", "")
        end
        local match_text = self.env.item_text:gsub("[^a-zA-Z0-9_ ]", "")
        local itemtab = self:_get_item_list()
        for _, entry in ipairs(itemtab) do
            local add_me = false
            local locname = GameTextGetTranslatedOrNot(entry.name)
            if not locname or locname == "" then locname = entry.name end
            if tag ~= nil then
                for _, itag in ipairs(split_string(entry.tags, ",")) do
                    if itag:match(tag) then
                        add_me = true
                    end
                end
            elseif entry.name:match(match_text) then
                add_me = true
            elseif entry.path:match(match_text) then
                add_me = true
            elseif locname and locname ~= "" then
                if locname:lower():match(match_text:lower()) then
                    add_me = true
                end
            end
            -- Hide duplicate items from being added more than once
            for _, entity in ipairs(self.env.item_list) do
                if entity.path == entry.path then
                    add_me = false
                end
            end
            if add_me then
                local hover_func = self:_make_item_tooltip_func(entry)
                local bid = entry.path:gsub("[^a-z0-9_]", "")
                if imgui.SmallButton("Add###add_" .. bid) then
                    if not self.env.item_add_multi then self.env.item_text = "" end
                    table.insert(self.env.item_list, {
                        id = entry.id,
                        name = entry.name,
                        path = entry.path,
                        icon = entry.icon,
                        tags = entry.tags,
                        config = {},
                    })
                end
                imgui.SameLine()
                if entry.icon and self.config.show_images then
                    self.host:draw_image(imgui, entry.icon, true, {})
                    self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
                    imgui.SameLine()
                end
                local text = ("%s [%s]"):format(locname, entry.id)
                imgui.Text(self.config.simple_names and locname or text)
                self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
            end
        end
    end
end

function InfoPanel:_draw_item_list(imgui)
    local ret
    local to_remove = nil
    imgui.SeparatorText("Item List")
    for idx, entry in ipairs(self.env.item_list) do
        if not entry.config then entry.config = {} end
        if imgui.SmallButton("Remove###remove_" .. entry.id) then
            to_remove = idx
        end
        imgui.SameLine()
        local keep = entry.config.keep == 1
        ret, keep = imgui.Checkbox("###keep_" .. entry.id, keep)
        if ret then
            entry.config.keep = keep and 1 or 0
        end
        self:_draw_hover_tooltip(imgui, "If checked, do not remove this item upon pickup")
        imgui.SameLine()
        local hover_func = self:_make_item_tooltip_func(entry)
        if entry.icon and self.config.show_images then
            self.host:draw_image(imgui, entry.icon, true, {})
            self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
            imgui.SameLine()
        end
        local label = GameTextGetTranslatedOrNot(entry.name)
        local text = ("%s [%s]"):format(label, entry.id)
        imgui.Text(self.config.simple_names and label or text)
        self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
    end
    if to_remove ~= nil then
        table.remove(self.env.item_list, to_remove)
    end
end

--[[ True if the player has the given spell in their inventory ]]
function InfoPanel:_player_has_spell(spell_or_spell_id)
    local spell_id = spell_or_spell_id
    if type(spell_id) == "table" then
        spell_id = spell_or_spell_id.id
    end
    local inv_cards = get_with_tags({"card_action"}, {player=true})
    for _, entpair in ipairs(inv_cards) do
        local entid, entname = unpack(entpair)
        local spell = card_get_spell(entid)
        if spell == spell_id then
            local ac_flag = spell_is_always_cast(entid)
            if type(spell_or_spell_id) == "table" then
                local info = spell_or_spell_id
                if info.config and info.config.ignore_ac then
                    local matches = _want_ac_spell(info.config.ignore_ac, ac_flag)
                    return matches
                end
            end
            return true
        end
    end
    return false
end

--[[ True if the player has the given material in their inventory ]]
function InfoPanel:_player_has_material(material)
    for _, entpair in ipairs(get_with_tags({"potion", "powder_stash"}, {player=true})) do
        local entid, entname = unpack(entpair)
        local cmap, clist = container_get_contents(entid)
        if cmap[material] then
            return true
        end
    end
    return false
end

--[[ True if the player has the given item in their inventory ]]
function InfoPanel:_player_has_item(item_or_item_def)
    local item = item_or_item_def
    if type(item_or_item_def) == "string" then
        item = self:_get_item_by_name(item_or_item_def)
    end
    local inv_items = get_with_tags({"item_pickup"}, {player=true})
    for _, pair in ipairs(inv_items) do
        local entid, entname = unpack(pair)
        local filename = EntityGetFilename(entid)
        if item.path == filename then
            return true
        end
    end
    return false
end

--[[ Determine if we need to remove any list entries and do so ]]
function InfoPanel:_process_remove_entries()
    local remove_spell = conf_get(CONF.REMOVE_SPELL)
    if remove_spell then
        local to_remove = {}
        for idx, entry in ipairs(self.env.spell_list) do
            if self:_player_has_spell(entry) then
                if not _want_keep(entry) then
                    table.insert(to_remove, 1, idx)
                end
            end
        end

        if #to_remove > 0 then
            for _, idx in ipairs(to_remove) do
                table.remove(self.env.spell_list, idx)
            end
            self.host:print(("Removed %d spell%s from the spell list"):format(
                #to_remove,
                #to_remove ~= 1 and "s" or ""))
        end
    end

    local remove_item = conf_get(CONF.REMOVE_ITEM)
    if remove_item then
        local to_remove = {}
        for idx, entry in ipairs(self.env.item_list) do
            if self:_player_has_item(entry) then
                if not _want_keep(entry) then
                    table.insert(to_remove, 1, idx)
                end
            end
        end

        if #to_remove > 0 then
            for _, idx in ipairs(to_remove) do
                table.remove(self.env.item_list, idx)
            end
            self.host:print(("Removed %d item%s from the item list"):format(
                #to_remove,
                #to_remove ~= 1 and "s" or ""))
        end
    end

    local remove_material = conf_get(CONF.REMOVE_MATERIAL)
    if remove_material then
        local to_remove = {}
        for idx, entry in ipairs(self.env.material_list) do
            if self:_player_has_material(entry.name) then
                if not _want_keep(entry) then
                    table.insert(to_remove, 1, idx)
                end
            end
        end

        if #to_remove > 0 then
            for _, idx in ipairs(to_remove) do
                table.remove(self.env.material_list, idx)
            end
            self.host:print(("Removed %d material%s from the material list"):format(
                #to_remove,
                #to_remove ~= 1 and "s" or ""))
        end
    end
end

--[[ Process the entire "import" dialog actions ]]
function InfoPanel:_handle_import_dialog(imgui)
    if not self.env.import_dialog then return end
    local plname = self.env.import_data.plural
    local sname = self.env.import_data.singular
    local tvar = self.env.import_data.table_var
    local evar = self.env.import_data.env_var

    imgui.Text(("Paste %s data here:"):format(sname))
    local line_height = imgui.GetTextLineHeight()
    local flags = 0 -- Nothing needed at this time
    _, self.env.import_text = imgui.InputTextMultiline(
        "###import_box",
        self.env.import_text,
        -line_height * 4,
        line_height * self.config.import_num_lines,
        flags)
    self:_draw_hover_tooltip(imgui, "Paste the exported data here using Ctrl+V")

    local imp_action = nil
    if imgui.Button("Merge") then imp_action = "merge" end
    self:_draw_hover_tooltip(imgui, ("Append new entries to the existing %s list"):format(sname))
    imgui.SameLine()
    if imgui.Button("Replace") then imp_action = "load" end
    self:_draw_hover_tooltip(imgui, ("Replace the %s list with the new entries"):format(sname))
    imgui.SameLine()
    if imgui.Button("Cancel") then imp_action = "close" end
    self:_draw_hover_tooltip(imgui, "Close out of this dialog without modifying anything")

    if imp_action == "load" or imp_action == "merge" then
        self.env.import_text = self.env.import_text:gsub("[\n]", "")
        local result, value = pcall(smallfolk.loads, self.env.import_text)
        if not result then
            self:message({"Load failed", color="red_light"})
            self:message({tostring(value), color="red_light"})
        elseif imp_action == "load" then
            self.env.import_dialog = false

            table_clear(self.env[tvar])
            for _, entry in ipairs(value) do
                table.insert(self.env[tvar], entry)
            end

            local vname = #value == 1 and sname or plname
            self:message({
                {"Imported"},
                {("%d"):format(#value), color="cyan"},
                {vname:lower(), color="cyan"},
                color="yellow_light",
            })
        elseif imp_action == "merge" then
            self.env.import_dialog = false

            local merged = 0
            for _, entry in ipairs(value) do
                if not _table_has_object(self.env[tvar], entry) then
                    table.insert(self.env[tvar], entry)
                    merged = merged + 1
                end
            end

            local vname = #value == 1 and sname or plname
            local mname = merged == 1 and sname or plname
            if merged == #value then
                self:message({
                    {"Imported all"},
                    {("%d"):format(#value), color="cyan"},
                    {vname:lower(), color="cyan"},
                    color="yellow_light",
                })
            else
                self:message({
                    {"Imported"},
                    {("%d"):format(merged), color="cyan"},
                    {vname:lower(), color="cyan"},
                    {"of"},
                    {("%d"):format(#value), color="cyan"},
                    {"total"},
                    {mname:lower(), color="cyan"},
                    {("(Skipped %d)"):format(#value - merged)},
                    color="yellow_light",
                })
            end
        end
    elseif imp_action == "clear" then
        self.env.import_dialog = false
    end
end

--[[ Format predicted treasure chest rewards ]]
function InfoPanel:_format_chest_reward(reward)
    local rtype = reward.type
    local rname = reward.name or ""
    local rentity = reward.entity or ""
    local rentities = reward.entities or {}
    local ramount = reward.amount or 0
    rname = rname:gsub("%$[a-z0-9_]+", GameTextGet)

    local line = {}
    if rtype == REWARD.WAND then
        local wand_data = self:_get_item_by_name(rentity)
        local name = ("%s [%s]"):format(rname, rentity)
        table.insert(line, {
            {"Wand"}, {
                image = wand_data.icon,
                fallback = "data/items_gfx/machinegun.png",
                color = "lightcyan",
                self.config.simple_names and rname or name,
            },
        })
    elseif rtype == REWARD.CARD then
        for _, spell in ipairs(rentities) do
            local spell_data = spell_get_data(spell:upper())
            local name = ("%s (unknown spell)"):format(spell)
            local icon = nil
            if spell_data.name then
                local spell_name = GameTextGetTranslatedOrNot(spell_data.name)
                name = ("%s [%s]"):format(spell_name, spell)
                if self.config.simple_names then
                    name = spell_name
                end
                icon = spell_data.sprite
            end
            table.insert(line, {
                {"Spell"}, {
                    image = icon,
                    color = "lightcyan",
                    name,
                },
                clear_line = true,
            })
        end
    elseif rtype == REWARD.GOLD then
        local iinfo = self:_get_item_by_name("goldnugget")
        table.insert(line, {
            {("%d"):format(ramount)}, {
                image = iinfo.icon,
                fallback = "data/ui_gfx/items/goldnugget.png",
                color = "lightcyan",
                hover = self:_make_item_tooltip_func(iinfo),
                GameTextGet("$mat_gold"),
            },
        })
    elseif rtype == REWARD.CONVERT then
        local minfo = self:_get_material_by_name(rname)
        local mname = GameTextGetTranslatedOrNot(rname)
        if minfo.locname and minfo.name then
            mname = ("%s (%s)"):format(minfo.locname, minfo.name)
        end
        table.insert(line, {
            {"Convert to"}, {
                image = minfo.icon,
                color = "lightcyan",
                hover = self:_make_material_tooltip_func(minfo),
                mname,
            },
        })
    elseif rtype == REWARD.ITEM then
        local iinfo = self:_get_item_by_name(rentity)
        table.insert(line, {
            {"Item"}, {
                image = iinfo.icon,
                color = "lightcyan",
                hover = self:_make_item_tooltip_func(iinfo),
                rname,
            },
        })
    elseif rtype == REWARD.ENTITY then
        local einfo = self:_get_entity_by_name(rentity)
        table.insert(line, {
            {"Entity"}, {
                image = einfo.icon,
                color = "lightcyan",
                hover = self:_make_enemy_tooltip_func(einfo),
                rname,
            },
        })
    elseif rtype == REWARD.POTION or rtype == REWARD.POUCH then
        local iinfo = self:_get_item_by_name(rentity)
        local minfo = self:_get_material_by_name(reward.content)
        local mname = reward.content
        if minfo.locname and minfo.name then
            mname = ("%s (%s)"):format(minfo.locname, minfo.name)
        end
        table.insert(line, {{
            image = iinfo.icon,
            GameTextGetTranslatedOrNot(iinfo.name or "$item_potion"),
        }, {
            image = minfo.icon,
            color = "lightcyan",
            mname,
        }})
    elseif rtype == REWARD.REROLL then
        table.insert(line, {
            image = "data/ui_gfx/perk_icons/no_more_shuffle.png",
            ("Reroll x%d"):format(ramount)
        })
    elseif rtype == REWARD.POTIONS then
        local iinfo = self:_get_item_by_name("potion")
        table.insert(line, {
            image = iinfo.icon,
            ("%dx"):format(ramount),
            GameTextGet("$item_potion"),
        })
        for _, content in ipairs(reward.contents) do
            local minfo = self:_get_material_by_name(content)
            local mname = content
            if minfo.locname and minfo.name then
                mname = ("%s (%s)"):format(minfo.locname, minfo.name)
            end
            table.insert(line, {
                image = minfo.icon,
                color = "lightcyan",
                mname,
            })
        end
    elseif rtype == REWARD.GOLDRAIN then
        local iinfo = self:_get_item_by_name("goldnugget")
        table.insert(line, {
            image = iinfo.icon,
            GameTextGet("$item_goldnugget") .. " rain",
        })
    elseif rtype == REWARD.SAMPO then
        local iinfo = self:_get_item_by_name("sampo")
        table.insert(line, {
            image = iinfo.icon,
            GameTextGet("$item_mcguffin_12"),
        })
    else
        table.insert(line, ("Invalid reward %s"):format(rtype))
    end
    return line
end

--[[ Format a location ]]
function InfoPanel:format_pos(x, y)
    if x == nil or y == nil then
        return ("{%d, %d}"):format(x or "nil", y or "nil")
    end
    if self.config.pos_relative then
        local px, py = EntityGetTransform(get_players()[1])
        if px ~= nil and py ~= nil then
            x = x - px
            y = y - py
        end
        return ("[%d, %d]"):format(x, y)
    end
    return ("{%d, %d}"):format(x, y)
end

--[[ Add a timed message ]]
function InfoPanel:message(contents, timer)
    local duration = timer or self.config.message_timer
    table.insert(self.env.messages, {
        contents,
        duration = duration,
        max_duration = duration,
    })
    local text = self.host:line_to_string(contents)
    text = text:gsub("^[ ]+", "")
    text = text:gsub("[ ]+$", "")
    GamePrint(text)

    if self.env.debug.on then
        local debug_msg = smallfolk.dumps(contents)
        print(("InfoPanel:message(%s, %d)"):format(debug_msg, duration))
    end
    print(("InfoPanel:message(%q)"):format(text)) -- Writes to logger.txt (if enabled)
end

--[[ Process timed messages ]]
function InfoPanel:_process_messages(imgui)
    local msg_to_remove = {}
    if #self.env.messages > 0 then
        for idx, message in ipairs(self.env.messages) do
            message.duration = message.duration - 1
            if message.duration <= 0 then
                table.insert(msg_to_remove, 1, idx)
            else
                self.host:draw_line(imgui, message, nil, nil)
            end
        end
    end
    if #msg_to_remove > 0 then
        for _, idx in ipairs(msg_to_remove) do
            table.remove(self.env.messages, idx)
        end
    end
end

--[[ Public: called before draw or draw_closed regardless of visibility
--
-- This draws the debug screen.
--
-- Note: called *outside* the PushID/PopID guard!
--]]
function InfoPanel:on_draw_pre(imgui)
    if not self.env.debug.on then return end
    local tables = {
        {"Spell", "spell_list"},
        {"Material", "material_list"},
        {"Entity", "entity_list"},
        {"Item", "item_list"},
    }
    local flags = bit.bor(
        imgui.WindowFlags.HorizontalScrollbar)
    local show, is_open = imgui.Begin("World Radar Debug", true, flags)
    if not is_open then
        self.env.debug.on = false
    elseif show then

        --[[ Eval box ]]
        if imgui.CollapsingHeader("Eval") then
            local this = self
            Eval:set_print_function(function(message)
                this.host:print(message)
                this:message(message)
                table.insert(self.env.debug.output, message)
            end)
            local result = Eval:draw(imgui, self)
            if result == Eval.FAIL then
                self.host:print_error(Eval.result.error)
            end
            if imgui.Button("Clear") then
                self.env.debug.output = {}
            end
            imgui.SeparatorText("Output")
            for _, line in ipairs(self.env.debug.output) do
                imgui.Text(line)
            end
        end

        --[[ self.config dump ]]
        if imgui.CollapsingHeader("Configuration") then
            for key, val in pairs(self.config) do
                imgui.Text(("self.config.%s = [%s]\"%s\""):format(
                    key, type(val), val))
            end
        end

        --[[ Testing treasure chest reward formatting ]]
        if imgui.CollapsingHeader("Test Reward Formats") then
            local reward = {}
            if imgui.Button("Entity") then
                reward.type = "entity"
                reward.name = "$animal_dark_alchemist (heart mimic)"
                reward.entity = "data/entities/animals/illusions/dark_alchemist.xml"
            end
            imgui.SameLine()
            if imgui.Button("Gold") then
                reward.type = "gold"
                reward.name = "$item_goldnugget"
                reward.amount = 1200
            end
            imgui.SameLine()
            if imgui.Button("Wand") then
                reward.type = "wand"
                reward.name = "$item_wand (level 4)"
                reward.entity = "data/entities/items/wand_level_04.xml"
            end
            imgui.SameLine()
            if imgui.Button("Card") then
                reward.type = "card"
                reward.name = "random spell"
                reward.amount = 3
                reward.entities = {
                    "MANA_REDUCE",
                    "ADD_TRIGGER",
                    "BLACK_HOLE"
                }
            end

            if imgui.Button("Item") then
                reward.type = "item"
                reward.name = "$item_waterstone"
                reward.entity = "data/entities/items/pickup/waterstone.xml"
            end
            imgui.SameLine()
            if imgui.Button("Potion") then
                reward.type = "potion"
                reward.name = "$item_potion"
                reward.entity = "data/entities/items/pickup/potion.xml"
                reward.content = "water"
            end
            imgui.SameLine()
            if imgui.Button("Pouch") then
                reward.type = "pouch"
                reward.name = "$item_powder_stash_3"
                reward.entity = "data/entities/items/pickup/powder_stash.xml"
            end
            imgui.SameLine()
            if imgui.Button("Reroll") then
                reward.type = "reroll"
                reward.amount = 2
            end

            if imgui.Button("Convert") then
                reward.type = "convert"
                reward.name = "$mat_gold"
            end
            imgui.SameLine()
            if imgui.Button("Potions") then
                reward.type = "potions"
                reward.name = "$item_potion"
                reward.entities = {
                    "data/entities/items/pickup/potion_secret.xml",
                    "data/entities/items/pickup/potion_secret.xml",
                    "data/entities/items/pickup/potion_random_material.xml",
                }
                reward.contents = {
                    "magic_liquid_hp_regeneration_unstable",
                    "glowshroom",
                    "grass_holy",
                }
                reward.amount = #reward.contents
            end
            imgui.SameLine()
            if imgui.Button("Goldrain") then
                reward.type = "goldrain"
                reward.name = "gold rain"
                reward.entity = "data/entities/projectiles/rain_gold.xml"
            end
            imgui.SameLine()
            if imgui.Button("Sampo") then
                reward.type = "sampo"
            end
            if reward.type then
                for _, piece in ipairs(self:_format_chest_reward(reward)) do
                    self:message(piece)
                end
            end
        end

        --[[ Exporting self.env or entry tables ]]
        if imgui.CollapsingHeader("Table Management") then
            if imgui.Button("Copy Entire Environment") then
                local text = smallfolk.dumps(self.env)
                imgui.SetClipboardText(text)
                self.host:p(("Exported entire environment (%d bytes)"):format(#text))
            end

            for _, table_info in ipairs(tables) do
                local tbl_name, tbl_var = unpack(table_info)
                if imgui.Button(("Copy %s List"):format(tbl_name)) then
                    imgui.SetClipboardText(smallfolk.dumps(self.env[tbl_name]))
                    self.host:print(("Copied %s (%d entries) to the clipboard"):format(
                        tbl_var, #self.env[tbl_var]))
                end
                local entries = self.env[tbl_var]
                imgui.Text(("%s[%d] = {"):format(tbl_var, #entries))
                for _, entry in ipairs(entries) do
                    imgui.Text(("    %s,"):format(smallfolk.dumps(entry)))
                end
                imgui.Text("}")
            end
        end

        imgui.End()
    end
end

--[[ Public: initialize the panel ]]
function InfoPanel:init(environ, host, config)
    self.env = environ or self.env or {}
    self.host = host or error("InfoPanel:init() no host given")
    self.biomes = get_biome_data()
    self.gui = GuiCreate()

    Orbs:init()

    self.env.debug = {
        on = false,
        code = "",
        lines = 10,
        output = {},
    }

    self.env.list_biomes = false
    self.env.find_items = true
    self.env.find_wands = false
    self.env.find_enemies = true
    self.env.onscreen = true
    self.env.radar = true

    for _, bpair in ipairs(self.modes) do
        local mname, varname, default = unpack(bpair)
        if self.env[varname] == nil then
            local save_value = self.host:get_var(self.id, varname, "")
            if save_value == "1" or save_value == "0" then
                self.env[varname] = (save_value == "1")
            else
                self.env[varname] = default and true or false
            end
        end
    end

    self.env.show_checkboxes = true
    self.env.import_dialog = false
    self.env.import_text = ""
    self.env.import_data = {plural="", singular="", table_var="", env_var=""}
    self.env.manage_spells = false
    self.env.manage_materials = false
    self.env.manage_entities = false
    self.env.manage_items = false

    self.env.chest_cache = {}

    self.env.material_cache = nil
    self.env.material_liquid = true     -- Show liquids
    self.env.material_sand = true       -- Show sands
    self.env.material_gas = false       -- Hide gasses
    self.env.material_fire = false      -- Hide fires
    self.env.material_solid = false     -- Hide solids
    self.env.item_cache = nil
    self.env.entity_cache = nil

    self.env.spell_list = {}
    self.env.material_list = {}
    self.env.entity_list = {}
    self.env.item_list = {}

    self.env.wand_matches = {}
    self.env.card_matches = {}
    self.env.spell_chest_matches = {}
    self.env.spell_add_multi = false
    self.env.material_add_multi = false
    self.env.entity_add_multi = false
    self.env.item_add_multi = false

    self.env.item_text = ""
    self.env.material_text = ""
    self.env.entity_text = ""
    self.env.spell_text = ""

    self.env.messages = {}

    if config then
        self:configure(config)
    end

    local this = self
    local wrapper = function()
        return this:_init_tables()
    end
    local on_error = function(errmsg)
        this.host:print_error(errmsg)
        if debug and debug.traceback then
            this.host:print_error(debug.traceback())
        end
    end
    local res, ret = xpcall(wrapper, on_error)
    if not res then
        self.host:print_error(tostring(ret))
    end

    return self
end

--[[ Public: called when the player has spawned ]]
function InfoPanel:on_player_spawned(player_entity)
    Orbs:init()
    self.env.chest_cache = {}
    if self.config.chest_scanning then
        self:_cache_treasure_chests()
    end
end

--[[ Public: forcibly reload the caches ]]
function InfoPanel:reload_all()
    self:on_player_spawned(get_players()[1])

    self.env.material_cache = nil
    self:_get_material_tables()

    self.env.entity_cache = nil
    self:_get_entity_list()

    self.env.item_cache = nil
    self:_get_item_list()

    self.env.wand_matches = {}
    self.env.card_matches = {}
    self.env.spell_chest_matches = {}
end

--[[ Public: draw the menu bar ]]
function InfoPanel:draw_menu(imgui)
    local menus = {
        -- Plural, singular, env table name, env manage name
        {"Spells", "Spell", "spell_list", "manage_spells"},
        {"Materials", "Material", "material_list", "manage_materials"},
        {"Entities", "Entity", "entity_list", "manage_entities"},
        {"Items", "Item", "item_list", "manage_items"},
    }

    local prefix
    if imgui.BeginMenu(self.name) then
        if imgui.MenuItem("Save All Lists (This Run)") then
            for _, entry in ipairs(menus) do
                local plname, sname, tvar, evar = unpack(entry)
                local data = smallfolk.dumps(self.env[tvar])
                self.host:set_var(self.id, tvar, data)
                GamePrint(("Saved %d %s"):format(#self.env[tvar], plname:lower()))
            end
        end
        imgui.SeparatorText("Configuration")
        prefix = self.env.show_checkboxes and "Hide" or "Show"
        if imgui.MenuItem(prefix .. " Checkboxes") then
            self.env.show_checkboxes = not self.env.show_checkboxes
        end
        prefix = conf_get(CONF.SIMPLE_NAMES) and "Full" or "Simple"
        if imgui.MenuItem("Show " .. prefix .. " Names") then
            conf_toggle(CONF.SIMPLE_NAMES)
            self.config.simple_names = conf_get(CONF.SIMPLE_NAMES)
        end
        prefix = conf_get(CONF.SHOW_IMAGES) and "Hide" or "Show"
        if imgui.MenuItem(prefix .. " Images") then
            conf_toggle(CONF.SHOW_IMAGES)
            self.config.show_images = conf_get(CONF.SHOW_IMAGES)
        end
        prefix = conf_get(CONF.CHEST_PREDICTION) and "Disable" or "Enable"
        if imgui.MenuItem(prefix .. " Chest Prediction") then
            conf_toggle(CONF.CHEST_PREDICTION)
            self.config.chest_prediction = conf_get(CONF.CHEST_PREDICTION)
        end
        prefix = conf_get(CONF.CHEST_SCANNING) and "Disable" or "Enable"
        if imgui.MenuItem(prefix .. " Treasure Chest Scanning") then
            conf_toggle(CONF.CHEST_SCANNING)
            self.config.chest_scanning = conf_get(CONF.CHEST_SCANNING)
        end
        self:_draw_hover_tooltip(imgui, function(imgui_, self_, config)
            imgui_.Text("Scan the contents of nearby treasure chests for desired items.")
            imgui_.Text("Note that this may affect performance.")
        end, {})
        prefix = conf_get(CONF.POS_RELATIVE) and "Disable" or "Enable"
        if imgui.MenuItem(prefix .. " Relative Positions") then
            conf_toggle(CONF.POS_RELATIVE)
            self.config.pos_relative = conf_get(CONF.POS_RELATIVE)
        end
        imgui.SeparatorText("Pickup Actions")
        local items = {
            {"Spells", CONF.REMOVE_SPELL},
            {"Items", CONF.REMOVE_ITEM},
            {"Materials", CONF.REMOVE_MATERIAL},
        }
        for _, entry in ipairs(items) do
            local label, conf = unpack(entry)
            local curr = conf_get(conf)
            prefix = curr and "Disable" or "Enable"
            local text = ("%s Remove %s on Pickup"):format(prefix, label)
            if imgui.MenuItem(text) then
                conf_toggle(conf)
            end
        end
        imgui.SeparatorText("Orb Radar")
        prefix = conf_get(CONF.ORB_ENABLE) and "Disable" or "Enable"
        if imgui.MenuItem(prefix .. " Orb Radar") then
            conf_toggle(CONF.ORB_ENABLE)
        end
        if imgui.BeginMenu("Orb Selection") then
            local curr = conf_get(CONF.ORB_LIMIT)
            local choices = {
                {"world", "Current World Only"},
                {"main", "Main World Only"},
                {"parallel", "Parallel Worlds Only"},
                {"both", "Both Main and Parallel"},
            }
            for _, choice in ipairs(choices) do
                local conf, label = unpack(choice)
                prefix = (curr == conf) and "[*] " or ""
                if imgui.MenuItem(prefix .. label) then
                    conf_set(CONF.ORB_LIMIT, conf)
                end
            end
            imgui.EndMenu()
        end
        if imgui.BeginMenu("Orb Display") then
            if imgui.MenuItem("Nearest") then
                conf_set(CONF.ORB_DISPLAY, 1)
            end
            if imgui.MenuItem("Nearest 3") then
                conf_set(CONF.ORB_DISPLAY, 3)
            end
            if imgui.MenuItem("All") then
                conf_set(CONF.ORB_DISPLAY, 33)
            end
            imgui.TextDisabled("NOTE: Precise control in mod settings")
            imgui.EndMenu()
        end
        imgui.Separator()
        if imgui.MenuItem("Toggle Internal Debugging") then
            self.env.debug.on = not self.env.debug.on
        end
        if imgui.MenuItem("Reload All") then
            self:reload_all()
            GamePrint("Cleared and reloaded all caches")
        end
        imgui.EndMenu()
    end

    for _, entry in ipairs(menus) do
        local plname, sname, tvar, evar = unpack(entry)
        local data
        if imgui.BeginMenu(plname) then
            if imgui.MenuItem("Select " .. plname) then
                self.env.manage_spells = false
                self.env.manage_materials = false
                self.env.manage_entities = false
                self.env.manage_items = false
                self.env[evar] = true
            end
            imgui.Separator()
            if imgui.MenuItem("Save " .. sname .. " List (This Run)") then
                data = smallfolk.dumps(self.env[tvar])
                self.host:set_var(self.id, tvar, data)
                GamePrint(("Saved %d %s"):format(#self.env[tvar], plname:lower()))
            end
            data = self.host:get_var(self.id, tvar, "")
            if data ~= "" and data ~= "{}" then
                if imgui.MenuItem("Load " .. sname .. " List (This Run)") then
                    self.env[tvar] = smallfolk.loads(data)
                    GamePrint(("Loaded %d %s"):format(#self.env[tvar], plname:lower()))
                end
                if imgui.MenuItem("Clear " .. sname .. " List (This Run)") then
                    self.host:set_var(self.id, tvar, "{}")
                    GamePrint(("Cleared %s list"):format(sname:lower()))
                end
            end
            imgui.Separator()
            if imgui.MenuItem("Save " .. sname .. " List (Forever)") then
                data = smallfolk.dumps(self.env[tvar])
                self.host:save_value(self.id, tvar, data)
                GamePrint(("Saved %d %s"):format(#self.env[tvar], plname:lower()))
            end
            data = self.host:load_value(self.id, tvar, "")
            if data ~= "" and data ~= "{}" then
                if imgui.MenuItem("Load " .. sname .. " List (Forever)") then
                    self.env[tvar] = smallfolk.loads(data)
                    GamePrint(("Loaded %d %s"):format(#self.env[tvar], plname:lower()))
                end
                if imgui.MenuItem("Clear " .. sname .. " List (Forever)") then
                    if self.host:remove_value(self.id, tvar) then
                        GamePrint(("Cleared %s list"):format(sname:lower()))
                    end
                end
            end
            imgui.Separator()
            if imgui.MenuItem("Export " .. sname .. " List") then
                local nentries = #self.env[tvar]
                local text = smallfolk.dumps(self.env[tvar])
                imgui.SetClipboardText(text)
                self.host:print(("Copied %s list (%d entries) to the clipboard"):format(
                    sname, nentries))
            end
            if imgui.MenuItem("Import " .. sname .. " List") then
                self.env.import_dialog = true
                self.env.import_data = {
                    plural = plname,
                    singular = sname,
                    table_var = tvar,
                    env_var = evar,
                }
            end
            imgui.EndMenu()
        end
    end
end

--[[ Public: draw the panel content ]]
function InfoPanel:draw(imgui)
    if not self.config.icons.height then
        self.config.icons.height = imgui.GetTextLineHeight()
    end

    self.config.range_rule = conf_get(CONF.RADAR_RANGE)
    self.config.range = tonumber(conf_get(CONF.RADAR_RANGE_MANUAL))
    self.config.show_images = conf_get(CONF.SHOW_IMAGES)
    self.config.show_color = conf_get(CONF.SHOW_COLOR)
    self.config.pos_relative = conf_get(CONF.POS_RELATIVE)
    self.config.simple_names = conf_get(CONF.SIMPLE_NAMES)
    self.config.chest_prediction = conf_get(CONF.CHEST_PREDICTION)
    self.config.chest_scanning = conf_get(CONF.CHEST_SCANNING)

    self.host:text_clear()

    if self.config.chest_scanning then
        self:_clear_opened_chests()
    end

    if GameGetFrameNum() % 10 == 0 then
        self:_process_remove_entries()
        if self.config.chest_scanning then
            self:_cache_treasure_chests()
        end
    end

    self:_draw_checkboxes(imgui)

    self:_process_messages(imgui)

    self:_handle_import_dialog(imgui)

    if self.env.manage_spells then
        self:_draw_spell_dropdown(imgui)
        self:_draw_spell_list(imgui)
    end

    if self.env.manage_materials then
        self:_draw_material_dropdown(imgui)
        self:_draw_material_list(imgui)
    end

    if self.env.manage_entities then
        self:_draw_entity_dropdown(imgui)
        self:_draw_entity_list(imgui)
    end

    if self.env.manage_items then
        self:_draw_item_dropdown(imgui)
        self:_draw_item_list(imgui)
    end

    local found_something = false
    function print_found_something()
        if not found_something then
            self.host:p({separator_text="Found something!!", color="yellow"})
            found_something = true
        end
    end

    if self.env.find_items then
        local found_item_ids = {}
        local containers, chest_containers = self:_find_containers()
        for _, entry in ipairs(containers) do
            print_found_something()
            found_item_ids[entry.entity] = entry
            local contents = {}
            for _, mat in ipairs(entry.rare_contents) do
                local matname = mat.locname
                if not matname or matname == "" then
                    if mat.uiname then
                        matname = GameTextGetTranslatedOrNot(mat.uiname)
                    end
                end
                if not matname or matname == "" then
                    matname = mat.name
                end
                table.insert(contents, {
                    image = mat.icon,
                    hover = self:_make_material_tooltip_func(mat),
                    matname,
                })
            end
            local iinfo = entry.entry or {}
            self.host:p({
                image = iinfo.icon,
                hover = self:_make_item_tooltip_func(iinfo),
                ("%s with"):format(entry.name),
                contents,
                "detected nearby!!",
            })
            local ex, ey = EntityGetTransform(entry.entity)
            if ex ~= nil and ey ~= nil then
                local pos_str = self:format_pos(ex, ey)
                self.host:d(("%s %d at %s"):format(entry.name, entry.entity, pos_str))
            end
        end

        for _, entry in ipairs(chest_containers) do
            print_found_something()
            local iteminfo = self:_get_item_by_name(entry.container)
            local item_name = GameTextGetTranslatedOrNot(iteminfo.name)
            local matinfo = self:_get_material_by_name(entry.material)
            local matname = matinfo.locname or matinfo.name
            self.host:p({
                image = matinfo.icon,
                hover = self:_make_material_tooltip_func(matinfo),
                {entry.name, color="lightcyan"},
                "containing",
                {item_name, color="lightgreen"},
                "with",
                {matname, color="lightcyan"},
                "detected nearby!!",
            })
            local pos_str = self:format_pos(unpack(entry.pos))
            self.host:d(("%s %d with %s at %s"):format(entry.name, entry.entity, matname, pos_str))
        end

        local found_item_list, found_chest_list = self:_find_items()
        for _, entry in ipairs(found_item_list) do
            if not found_item_ids[entry.entity] then
                print_found_something()
                local entinfo = entry.entry
                self.host:p({
                    image = entinfo.icon,
                    hover = self:_make_item_tooltip_func(entinfo),
                    entry.name,
                    "detected nearby!!",
                })
                local ex, ey = EntityGetTransform(entry.entity)
                if ex ~= nil and ey ~= nil then
                    local pos_str = self:format_pos(ex, ey)
                    self.host:d(("%s %d at %s"):format(entry.name, entry.entity, pos_str))
                end
            end
        end
        for _, entry in ipairs(found_chest_list) do
            print_found_something()
            local item_info = self:_get_item_by_name(entry.item)
            local item_name = GameTextGetTranslatedOrNot(item_info.name)
            self.host:p({
                image = item_info.icon,
                hover = self:_make_item_tooltip_func(item_info),
                {entry.name, color="lightcyan"},
                "containing",
                {item_name, color="lightcyan"},
                "detected nearby!!",
            })
            local pos_str = self:format_pos(unpack(entry.pos))
            self.host:d(("%s %d with %s at %s"):format(entry.name, entry.entity, item_name, pos_str))
        end
    end

    if self.env.find_enemies then
        local found_ent_list, found_chest_list = self:_find_enemies()
        for _, entity in ipairs(found_ent_list) do
            print_found_something()
            local entinfo = self:_get_entity_by_name(entity.path)
            local line = {
                "Entity", {
                    image = entinfo.icon,
                    hover = self:_make_enemy_tooltip_func(entinfo),
                    color = "lightcyan",
                    entity.name,
                },
                "detected nearby!!"}
            self.host:p(line)
            local ex, ey = EntityGetTransform(entity.entity)
            if ex ~= nil and ey ~= nil then
                local pos_str = self:format_pos(ex, ey)
                self.host:d(("%s %d at %s"):format(entity.name, entity.entity, pos_str))
            end
        end
        for _, entry in ipairs(found_chest_list) do
            print_found_something()
            local entinfo = self:_get_entity_by_name(entry.entpath)
            local entname = GameTextGetTranslatedOrNot(entry.entname)
            self.host:p({
                image = entinfo.icon,
                hover = self:_make_enemy_tooltip_func(entinfo),
                {entry.name, color="lightcyan"},
                "spawning",
                {entname, color="lightcyan"},
                "detected nearby!!",
            })
            local pos_str = self:format_pos(unpack(entry.pos))
            self.host:d(("%s %d with %s at %s"):format(entry.name, entry.entity, entry.entname, pos_str))
        end
    end

    if self.env.find_spells then
        self:_find_spells()
        for entid, _ in pairs(self.env.card_matches) do
            if not entid then goto continue end
            if not EntityGetIsAlive(entid) then goto continue end
            local spell = card_get_spell(entid)
            if not spell then
                self.host:print_error(("Card %d lacks spell"):format(entid))
                goto continue
            end
            print_found_something()
            local spell_name = GameTextGetTranslatedOrNot(spell_get_name(spell))
            local spell_data = spell_get_data(spell)
            local name = ("%s [%s]"):format(spell_name, spell)
            local entry = self:_get_spell_by_name(spell)
            self.host:p({
                "Spell", {
                    image = spell_data.sprite,
                    hover = self:_make_spell_tooltip_func(entry),
                    color = "lightcyan",
                    self.config.simple_names and spell_name or name,
                },
                "detected nearby!!",
            })
            local wx, wy = EntityGetTransform(entid)
            if wx ~= nil and wy ~= nil then
                local pos_str = self:format_pos(wx, wy)
                self.host:d(("Spell %d at %s %s"):format(entid, pos_str, name))
            end
            ::continue::
        end

        for entid, ent_spells in pairs(self.env.wand_matches) do
            if not entid then goto continue end
            if not EntityGetIsAlive(entid) then goto continue end
            print_found_something()
            local wand_info = self:_get_item_by_name(entity_get_lookup_key(entid))
            local wand_icon = wand_get_icon(entid) or wand_info.icon
            local line = {{
                image = wand_icon,
                fallback = "data/items_gfx/machinegun.png",
                hover = self:_make_item_tooltip_func(wand_info),
                "Wand with",
            }}
            local spell_list = {}
            for spell, spell_id in pairs(ent_spells) do
                local spell_data = spell_get_data(spell)
                local spell_name = GameTextGetTranslatedOrNot(spell_get_name(spell))
                local entry = self:_get_spell_by_name(spell)
                local name = ("%s [%s]"):format(spell_name, spell)
                local list_entry = {
                    image = spell_data.sprite,
                    hover = self:_make_spell_tooltip_func(entry),
                    color = "lightcyan",
                }
                if spell_is_always_cast(spell_id) then
                    table.insert(list_entry, {
                        color = "lightgreen",
                        "Always Cast",
                    })
                end
                table.insert(list_entry, self.config.simple_names and spell_name or name)
                table.insert(spell_list, list_entry)
            end
            table.insert(line, spell_list)
            table.insert(line, "detected nearby!!")
            self.host:p(line)
            local wx, wy = EntityGetTransform(entid)
            if wx ~= nil and wy ~= nil then
                local pos_str = self:format_pos(wx, wy)
                self.host:d({
                    ("Wand %d at %s with"):format(entid, pos_str),
                    spell_list,
                })
            end
            ::continue::
        end
        for _, entry in ipairs(self.env.spell_chest_matches) do
            local entid = entry.entity
            local iname = item_get_name(entid, true)
            local iinfo = self:_get_item_by_name(entity_get_lookup_key(entid))
            local spell = entry.spell
            local spell_name = GameTextGetTranslatedOrNot(spell_get_name(spell))
            local spell_info = self:_get_spell_by_name(spell)
            local sname = ("%s [%s]"):format(spell_name, spell)
            self.host:p({
                {
                    image = iinfo.icon,
                    hover = self:_make_item_tooltip_func(iinfo),
                    color = "lightgreen",
                    iname,
                },
                "containing",
                {
                    image = spell_info.icon,
                    hover = self:_make_spell_tooltip_func(spell_info),
                    color = "lightcyan",
                    self.config.simple_names and spell_name or sname,
                },
                "detected nearby!!",
            })
            local pos_str = self:format_pos(unpack(entry.pos))
            self.host:d(("%s %d with %s at %s"):format(iname, entid, sname, pos_str))
        end
    end

    -- Display everything else: biomes, items, enemies

    if self.env.list_biomes then
        self.host:p({separator_text="Biome Modifiers"})
        for bname, bdata in pairs(self.biomes) do
            local biome_name = bdata.uiname or bdata.name or bname
            biome_name = GameTextGetTranslatedOrNot(biome_name)
            if not self.config.simple_names then
                if not biome_name:lower():match(bname) then
                    biome_name = ("%s [%s]"):format(biome_name, bname)
                end
            end
            line = ("%s: %s (%0.1f)"):format(biome_name, bdata.text, bdata.probability)
            if bdata.probability < self.config.rare_biome_mod then
                self.host:p({line, color="yellow"})
            else
                self.host:p(line)
            end
        end
    end

    if self.env.find_items then
        self.host:p({separator_text="Items"})
        for _, entry in ipairs(aggregate(self:_get_nearby_items())) do
            local name, entities = unpack(entry)
            local iinfo = self:_get_item_by_name(entity_get_lookup_key(entities[1]))
            local hover_fn = self:_make_item_tooltip_func(iinfo)
            if not iinfo.id then
                local entid = entities[1]
                hover_fn = function(imgui_, self_)
                    imgui_.TextDisabled("Not a known item")
                    imgui_.Text(name)
                    imgui_.Text(("Path: %s"):format(EntityGetFilename(entid)))
                    imgui_.Text(("Name: %s"):format(EntityGetName(entid) or "<unnamed>"))
                end
            end

            -- Print for things other than chests, as chests get special treatment
            if not entity_is_chest(entities[1]) then
                self.host:p({
                    ("%dx"):format(#entities), {
                        name,
                        image = iinfo.icon,
                        color = "lightcyan",
                        hover = hover_fn,
                    },
                })
            end

            for _, entity in ipairs(entities) do
                local ex, ey = EntityGetTransform(entity)
                local contents = {}
                local line = {{
                    image = iinfo.icon,
                    color = "white",
                    hover = hover_fn,
                }, {
                    color="lightcyan",
                    name,
                }}
                if self.host.debugging then
                    table.insert(line, {
                        ("%d at %s"):format(entity, self:format_pos(ex, ey)),
                        color = self.host.colors.debug
                    })
                end
                if entity_is_chest(entity) then
                    line[1].button = {
                        text = "View",
                        id = ("chest_%d_inspect"):format(entity),
                        func = function(this, ent, phost, pimgui)
                            local rewards = chest_get_rewards(ent, self.env.debug.on)
                            for _, reward in ipairs(rewards) do
                                local rline = this:_format_chest_reward(reward)
                                this:message({image=iinfo.icon, rline})
                            end
                        end,
                        small = true,
                        hover = "Peek inside the Treasure Chest without opening it",
                        self,
                        entity,
                    }
                    self.host:p(line)
                else
                    if EntityHasTag(entity, "potion") or EntityHasTag(entity, "powder_stash") then
                        local capacity = container_get_capacity(entity)
                        for matname, amount in pairs(container_get_contents(entity)) do
                            local percent = amount / capacity * 100
                            local matinfo = self:_get_material_by_name(matname)
                            table.insert(contents, {
                                image = matinfo.icon,
                                hover = self:_make_material_tooltip_func(matinfo),
                                matname,
                                ("%d%%"):format(percent),
                            })
                        end
                        if #contents > 0 then
                            table.insert(line, "with")
                            table.insert(line, contents)
                        else
                            table.insert(line, "empty")
                        end
                    end
                    self.host:d(line)
                end
            end
        end
    end

    if self.env.find_wands then
        self.host:p({separator_text="Wands"})
        for _, entry in ipairs(self:_get_nearby({"wand"})) do
            local entid, name = unpack(entry)
            local entkey = entity_get_lookup_key(entid)
            local wand_info = self:_get_item_by_name(entkey)
            local wand_icon = wand_get_icon(entid) or wand_info.icon
            local hover_fn = self:_make_wand_hover_func(entid, name)
            self.host:p({
                image = wand_icon,
                hover = hover_fn,
                color = "white",
                wand_info.name,
            })
        end
    end

    if self.env.find_enemies then
        self.host:p({separator_text="Enemies"})
        for _, entry in ipairs(aggregate(self:_get_nearby_enemies())) do
            local name, entities = unpack(entry)
            local entkey = entity_get_lookup_key(entities[1])
            local entinfo = self:_get_entity_by_name(entkey)
            local hover_fn = self:_make_enemy_tooltip_func(entinfo)
            if not entinfo.id then
                local entid = entities[1]
                hover_fn = function(imgui_, self_)
                    imgui_.TextDisabled("Not a known entity")
                    imgui_.Text(name)
                    imgui_.Text(("Key: %s"):format(entkey or "<unknown>"))
                    imgui_.Text(("Path: %s"):format(EntityGetFilename(entid)))
                    local entname = EntityGetName(entid)
                    if not entname or entname == "" then
                        entname = "<unnamed>"
                    end
                    imgui_.Text(("Name: %s"):format(entname))
                end
            end
            self.host:p({
                ("%dx"):format(#entities), {
                    image = entinfo.icon,
                    hover = hover_fn,
                    color = "white",
                    name,
                }
            })
        end
    end

    self:_draw_onscreen_gui()
    self:_draw_orb_radar()
end

--[[ Public: called when the panel window is closed ]]
function InfoPanel:draw_closed(imgui)
    if self.config.chest_scanning then
        self:_clear_opened_chests()
    end

    if self.env.find_spells then
        self:_find_spells()
    end

    self:_draw_onscreen_gui()
    self:_draw_orb_radar()

    if GameGetFrameNum() % 10 == 0 then
        self:_process_remove_entries()
        if self.config.chest_scanning then
            self:_cache_treasure_chests()
        end
    end
end

--[[ Public: update configuration ]]
function InfoPanel:configure(config)
    for key, value in pairs(config) do
        if key == "materials" then
            self.env.material_cache = value
            self.host:print(("Applied %d materials to material cache"):format(#self.env.material_cache))
        else
            self.config[key] = value
        end
    end
end

--[[ Public: called before the main menu is drawn ]]
function InfoPanel:on_menu_pre(imgui)
    self.env.save_show_clear = self.host.config.menu_show_clear
    self.host.config.menu_show_clear = false
end

--[[ Public: called after the main menu is drawn ]]
function InfoPanel:on_menu_post(imgui)
    self.host.config.menu_show_clear = self.env.save_show_clear
end

return InfoPanel

-- vim: set ts=4 sts=4 sw=4:
