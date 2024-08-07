--[[
The "Info" Panel: Display interesting information

IDEA: Add "include all unknown spells" button
IDEA: Add "include all unkilled enemies" button
    These could be quite noisy for early-game

IDEA: Limit menu choices to discovered things

TODO: Add treasure chest drop scanning (wands, spells, containers)

TODO: Better feedback display for timed messages to show remaining time
    Show a line or a bar getting shorter? Like Twitch announcements

TODO: Non-radar improvements:
    Only display the primary biome of a biome group
    Add "show triggers" (eg. temple collapse) via barrier spell effect

TODO: Allow user to configure how the on-screen text is displayed
    Configure anchoring: currently bottom-left, but add other three
    Configure location
--]]

dofile_once("data/scripts/lib/utilities.lua")
-- luacheck: globals get_players check_parallel_pos

nxml = dofile_once("mods/world_radar/files/lib/nxml.lua")
smallfolk = dofile_once("mods/world_radar/files/lib/smallfolk.lua")

dofile_once("mods/world_radar/config.lua")
-- luacheck: globals MOD_ID CONF conf_get conf_set
dofile_once("mods/world_radar/files/utility/biome.lua")
-- luacheck: globals biome_is_default biome_is_common biome_modifier_get
dofile_once("mods/world_radar/files/utility/entity.lua")
-- luacheck: globals is_child_of entity_is_item entity_is_enemy item_get_name enemy_get_name get_name get_health entity_match get_with_tags distance_from animal_build_name
dofile_once("mods/world_radar/files/utility/material.lua")
-- luacheck: globals container_get_contents container_get_capacity material_get_icon generate_material_tables
dofile_once("mods/world_radar/files/utility/spell.lua")
-- luacheck: globals card_get_spell wand_get_spells spell_is_always_cast spell_get_name spell_get_data action_lookup
dofile_once("mods/world_radar/files/utility/treasure_chest.lua")
-- luacheck: globals entity_is_chest chest_get_rewards REWARD
dofile_once("mods/world_radar/files/utility/orbs.lua")
-- luacheck: globals Orbs world_get_name make_distance_sorter
dofile_once("mods/world_radar/files/radar.lua")
-- luacheck: globals Radar RADAR_KIND_SPELL RADAR_KIND_ENTITY RADAR_KIND_MATERIAL RADAR_KIND_ITEM RADAR_ORB
dofile_once("mods/world_radar/files/lib/utility.lua")
-- luacheck: globals table_clear table_empty table_has_entry split_string

NOWRAP = {wrap=0}

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
    conf = {
        show_images = MOD_ID .. ".show_images",
        remove_spell = MOD_ID .. ".remove_found_spell",
        remove_item = MOD_ID .. ".remove_found_item",
        remove_material = MOD_ID .. ".remove_found_material",
        show_radar = MOD_ID .. ".show_radar",
        range = MOD_ID .. ".radar_range",
    },
    config = {
        tooltip_wrap = 400,             -- Default hover tooltip wrap margin
        import_num_lines = 6,           -- Height of the import textarea
        message_timer = 60*10,          -- Default message time
        range = math.huge,              -- Range of the radar
        range_rule = "infinite",        -- Range of the radar, overrides range
        rare_biome_mod = 0.2,           -- Modifiers below this are rare
        show_images = true,             -- Enable images
        rare_spells = {                 -- Default rare spell list
            {"MANA_REDUCE", keep=1},          -- Add Mana
            {"REGENERATION_FIELD", keep=0},   -- Circle of Vigour
            {"LONG_DISTANCE_CAST", keep=0},
        },
        rare_materials = {              -- Default rare material list
            "creepy_liquid",                -- Incredibly rare liquid
            "magic_liquid_hp_regeneration", -- Healthium
            "magic_liquid_weakness",        -- Diminution
            "urine",                        -- Spawns rarely in jars
        },
        rare_entities = {               -- Default rare entity list
            "$animal_worm_big",         -- Giant worm that can drop hearts
            "$animal_chest_leggy",      -- Leggy chest mimic
            "$animal_dark_alchemist",   -- Pahan muisto; heart mimic
            "$animal_mimic_potion",     -- Mimicium potion
            "$animal_playerghost",      -- Kummitus; wand ghost
            "$animal_shaman_wind",      -- Valhe; spell refresh mimic
        },
        rare_items = {                  -- Default rare item list
            "$item_chest_treasure_super",   -- Greater Treasure Chest
            "$item_greed_die",          -- Greed Die
            "$item_waterstone",         -- Vuoksikivi
        },
        gui = {                         -- On-screen UI adjustments
            pad_left = 10,              -- Distance from left edge
            pad_bottom = 2,             -- Distance from bottom edge
        },
        icons = {
            height = nil,               -- nil -> calculate height
        },
    },
    env = {
        -- list_biomes = true
        -- find_items = true
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

    -- Types of information to show: name, varname, default
    modes = {
        {"Biomes", "list_biomes", true},
        {"Items", "find_items", true},
        {"Enemies", "find_enemies", true},
        {"Spells", "find_spells", true},
        {"On-screen", "onscreen", true},
        {"Radar", "radar", true},
    },
}

--[[ Collect {id, name} pairs into {name, {id...}} sets ]]
local function aggregate(entries)
    local byname = {}
    for _, entry in ipairs(entries) do
        local entity = entry[1] or entry.entity
        local name = entry[2] or entry.name
        if name ~= nil then
            if not byname[name] then
                byname[name] = {}
            end
            table.insert(byname[name], entity)
        end
    end
    local results = {}
    for name, entities in pairs(byname) do
        table.insert(results, {name, entities})
    end
    table.sort(results, function(left, right)
        local lname, rname = left[1], right[1]
        return lname < rname
    end)
    return results
end

--[[ Determine if the player has the spell in their inventory ]]
local function player_has_spell(spell_id)
    local inv_cards = get_with_tags({"card_action"}, {player=true})
    for _, entpair in ipairs(inv_cards) do
        local entid, entname = unpack(entpair)
        local spell = card_get_spell(entid)
        if spell == spell_id then
            return true
        end
    end
    return false
end

--[[ Get biome information (name, path, modifier) for each biome (TODO: move) ]]
function _get_biome_data()
    local biomes_xml = nxml.parse(ModTextFileGetContent("data/biome/_biomes_all.xml"))
    local biomes = {}
    for _, bdef in ipairs(biomes_xml.children) do
        local biome_path = bdef.attr.biome_filename
        local biome_name = biome_path:match("^data/biome/(.*).xml$")
        local biome_uiname = BiomeGetValue(biome_path, "name")
        if biome_uiname == "_EMPTY_" then
            biome_uiname = biome_name
        end
        local modifier = BiomeGetValue(biome_path, "mModifierUIDescription")
        local mod_data = biome_modifier_get(modifier) or {}
        local show = true
        if biome_is_default(biome_name, modifier) then show = false end
        if biome_is_common(biome_name, modifier) then show = false end
        if show then
            biomes[biome_name] = {
                name = biome_name,
                uiname = biome_uiname,
                path = biome_path,
                modifier = modifier,
                probability = mod_data.probability or 0,
                text = GameTextGet(modifier),
            }
        end
    end
    return biomes
end

--[[ Get all of the known spells ]]
function InfoPanel:_get_spell_list()
    -- luacheck: globals actions
    dofile_once("data/scripts/gun/gun_actions.lua")
    if actions and #actions > 0 then
        return actions
    end
    self.host:p("Failed to determine spell list")
    return {}
end

--[[ Get all of the known materials ]]
function InfoPanel:_get_material_tables()
    -- See files/utility/material.lua generate_material_tables
    if not self.env.material_cache or #self.env.material_cache == 0 then
        self.env.material_cache = generate_material_tables()
    end
    return self.env.material_cache
end

--[[ Get all of the known entities ]]
function InfoPanel:_get_entity_list()
    --[[{
    --  id = "blob",
    --  name = "$animal_blob",
    --  path = "data/entities/animals/blob.xml",
    --  icon = "data/ui_gfx/animal_icons/blob.png",
    --}]]
    if not self.env.entity_cache or #self.env.entity_cache == 0 then
        self.env.entity_cache = dofile("mods/world_radar/files/generated/entity_list.lua")
    end
    return self.env.entity_cache
end

--[[ Get all of the known items ]]
function InfoPanel:_get_item_list()
    --[[{
    --  id = "treasure_chest",
    --  name = "$item_treasure_chest",
    --  filename = "data/entities/items/pickup/chest_random.lua",
    --  icon = "data/buildings_gfx/chest_random.png",
    --}]]
    if not self.env.item_cache or #self.env.item_cache == 0 then
        self.env.item_cache = dofile("mods/world_radar/files/generated/item_list.lua")
    end
    return self.env.item_cache
end

--[[ Obtain the spell ID, name, and icon path for a given spell name/ID/filename ]]
function InfoPanel:_get_spell_by_name(sname)
    if sname:match("^%$") then sname = sname:gsub("^%$", "") end
    for _, entry in ipairs(self:_get_spell_list()) do
        local spinfo = {
            id = entry.id,
            name = entry.name,
            icon = entry.sprite,
            config = {},
        }
        for _, test_name in ipairs({entry.id, entry.name, entry.path}) do
            if test_name == sname then
                return spinfo
            end
        end
    end
    self.host:print(("Could not locate spell %q"):format(sname))
    return {}
end

--[[ Obtain the material ID, name, etc. for the given name/filename ]]
function InfoPanel:_get_material_by_name(mname)
    if self.env.material_cache and #self.env.material_cache > 0 then
        for _, entry in ipairs(self.env.material_cache) do
            if entry.name == mname then
                return entry
            end
            if mname == entry.path then
                return entry
            end
        end
    else
        self.host:print("Material cache not ready before _get_material_by_name")
    end
    return {}
end

--[[ Obtain the entity ID, name, etc. for the given name/filename ]]
function InfoPanel:_get_entity_by_name(ename)
    for _, entry in ipairs(self:_get_entity_list()) do
        if ename == entry.id or ename == entry.name then
            return entry
        end
        if ename == entry.path then
            return entry
        end
    end
    return {}
end

--[[ Obtain the item ID, name, etc. for the given name/filename ]]
function InfoPanel:_get_item_by_name(iname)
    for _, entry in ipairs(self:_get_item_list()) do
        if iname == entry.id or iname == entry.name then
            return entry
        end
        if iname == entry.path then
            return entry
        end
    end
    return {}
end

--[[ Range check: true if the entity is inside self.range ]]
function InfoPanel:_range_check(entid_or_xy)
    local ex, ey = nil, nil
    if type(entid_or_xy) == "table" then
        ex = entid_or_xy.x or entid_or_xy[1]
        ey = entid_or_xy.y or entid_or_xy[2]
    elseif type(entid_or_xy) == "number" then
        ex, ey = EntityGetTransform(entid_or_xy)
    end
    if not ex or not ey then
        print_error(("Failed to get location from %s"):format(entid_or_xy))
        return false
    end

    local range_rule = self.config.range_rule
    if range_rule == "infinite" then
        return true
    end

    local range = self.config.range
    if range_rule == "world" then
        range = BiomeMapGetSize() * 512 / 2
    elseif range_rule == "perk_range" then
        range = 400
    elseif range_rule == "onscreen" then
        range = 200 -- TODO: Get screen size
    elseif range_rule == "manual" then
        -- Use self.config.range as-is
    end

    local px, py = EntityGetTransform(get_players()[1])
    if not px or not py then return false end -- Player not loaded
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

--[[ Get all nearby non-held items ]]
function InfoPanel:_get_nearby_items()
    return self:_filter_entries(get_with_tags({"item_pickup"}))
end

--[[ Get all nearby enemies ]]
function InfoPanel:_get_nearby_enemies()
    return self:_filter_entries(get_with_tags({"enemy"}))
end

--[[ Search for nearby desirable spells ]]
function InfoPanel:_find_spells()
    local spell_table = {}
    for _, entry in ipairs(self.env.spell_list) do
        spell_table[entry.id] = entry
    end
    self.env.wand_matches = {}
    for _, entry in ipairs(get_with_tags({"wand"}, {no_player=true})) do
        local entid = entry[1]
        for _, spell_info in ipairs(wand_get_spells(entid)) do
            local spell_id, spell = unpack(spell_info)
            local spinfo = spell_table[spell]
            if not spinfo then goto continue end
            local spconfig = spinfo.config or {}
            if spconfig.ignore_ac == 1 and spell_is_always_cast(spell_id) then
                goto continue
            end
            if not self.env.wand_matches[entid] then
                self.env.wand_matches[entid] = {}
            end
            self.env.wand_matches[entid][spell] = true
            ::continue::
        end
    end

    self.env.card_matches = {}
    for _, entry in ipairs(get_with_tags({"card_action"}, {no_player=true})) do
        local entid = entry[1]
        local spell = card_get_spell(entid)
        local parent = EntityGetParent(entid)
        -- XXX: Should we just ignore all spells inside wands?
        if not self.env.wand_matches[parent] then
            if spell and spell_table[spell] then
                local spconfig = spell_table[spell].config or {}
                if spconfig.ignore_ac ~= 1 or not spell_is_always_cast(entid) then
                    self.env.card_matches[entid] = true
                end
            end
        end
    end
end

--[[ Locate any flasks/pouches containing rare materials ]]
function InfoPanel:_find_containers()
    local containers = {}
    for _, item in ipairs(self:_filter_entries(get_with_tags({"item_pickup"}))) do
        local entity, name = unpack(item)
        local contents = container_get_contents(entity)
        local rare_mats = {}
        for _, material in ipairs(self.env.material_list) do
            if contents[material.name] and contents[material.name] > 0 then
                table.insert(rare_mats, material)
            end
        end
        if #rare_mats > 0 then
            table.insert(containers, {
                entity = entity,
                name = name,
                contents = contents,
                rare_contents = rare_mats,
            })
        end
    end
    return containers
end

--[[ Locate any rare enemies nearby ]]
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
    return enemies
end

--[[ Search for nearby desirable items ]]
function InfoPanel:_find_items()
    local items = {}
    for _, itempair in ipairs(self:_filter_entries(get_with_tags({"item_pickup"}))) do
        local entity, name = unpack(itempair)
        local entry = {entity=entity, name=name, path=EntityGetFilename(entity)}
        for _, item in ipairs(self.env.item_list) do
            if entry.path == item.path then
                entry.entry = item
                table.insert(items, entry)
            end
        end
    end
    return items
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
        orb_list = Orbs:get_within(world)
    elseif limit == "main" then
        orb_list = Orbs:get_main()
    elseif limit == "parallel" then
        orb_list = Orbs:get_parallel()
    elseif limit == "both" then
        orb_list = Orbs.list
    end

    table.sort(orb_list, make_distance_sorter(px, py))

    for idx = 1, math.min(display, #orb_list) do
        local orb_x, orb_y = unpack(orb_list[idx]:pos())
        Radar:configure{
            range=1024,
            range_medium=1024*0.25,
            range_faint=1024*0.5,
            next_only=true
        }
        Radar:draw_for_pos(orb_x, orb_y, RADAR_ORB)
    end
end

--[[ Draw the on-screen UI and the radar indicators, if enabled ]]
function InfoPanel:_draw_onscreen_gui()
    if not self.gui then self.gui = GuiCreate() end
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
    local function draw_text(line)
        linenr = linenr + 1
        local liney = screen_height - char_height * linenr - pady
        if ui_show then
            GuiText(gui, padx, liney, line)
        end
    end

    local function draw_radar(entid, kind)
        if radar_show then
            Radar:draw_for(entid, kind)
        end
    end

    for _, entry in ipairs(aggregate(self:_find_enemies())) do
        local entname, entities = unpack(entry)
        draw_text(("%dx %s detected nearby!!"):format(#entities, entname))
        for _, entid in ipairs(entities) do
            draw_radar(entid, RADAR_KIND_ENTITY)
        end
    end

    for _, entry in ipairs(self:_find_items()) do
        draw_text(("%s detected nearby!!"):format(entry.name))
        draw_radar(entry.entity, RADAR_KIND_ITEM)
    end

    for _, entry in ipairs(self:_find_containers()) do
        local contents = {}
        for _, material in ipairs(entry.rare_contents) do
            table.insert(contents, GameTextGet(material.uiname))
        end
        draw_text(("%s with %s detected nearby!!"):format(
            entry.name, table.concat(contents, ", ")))
        draw_radar(entry.entity, RADAR_KIND_MATERIAL)
    end

    for entid, ent_spells in pairs(self.env.wand_matches) do
        local spell_list = {}
        for spell_id, _ in pairs(ent_spells) do
            local spell_name = spell_get_name(spell_id)
            if spell_name then
                table.insert(spell_list, GameTextGet(spell_name))
            else
                table.insert(spell_list, spell_name)
            end
        end
        local spells = table.concat(spell_list, ", ")
        draw_text(("Wand with %s detected nearby!!"):format(spells))
        draw_radar(entid, RADAR_KIND_SPELL)
    end

    for entid, _ in pairs(self.env.card_matches) do
        local spell = card_get_spell(entid)
        local spell_name = spell_get_name(spell)
        if spell_name then
            spell_name = GameTextGet(spell_name)
        else
            spell_name = spell
        end
        draw_text(("Spell %s detected nearby!!"):format(spell_name))
        draw_radar(entid, RADAR_KIND_SPELL)
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
                tbl_entry.config.ignore_ac = 0
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
            -- Nothing to do yet
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
                    print_error(("Failed to map %s %q"):format(var, iid))
                    new_entry = {
                        id=iid,
                        name=iid,
                        path=nil,
                        icon=nil,
                        config={},
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
            self.host:print(("Loaded %d %s from %s %s table"):format(
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
        local name, varname, default = unpack(bpair)
        local ret, value = imgui.Checkbox(name, self.env[varname])
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

--[[ Create a function that draws the hover tooltip for a spell ]]
function InfoPanel:_make_spell_tooltip_func(entry)
    return function(imgui, self_)
        local data = spell_get_data(entry.id)
        imgui.Text(entry.id)
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
        local kind = entry.kind
        local matid = entry.id
        local matname = entry.name
        local matuiname = entry.uiname
        imgui.Text(("%s (ID: %s, type %s)"):format(matname, matid, kind))
        imgui.Text(("UI Name: %s"):format(matuiname))
        imgui.Text(("Tags: %s"):format(table.concat(entry.tags, " ")))
    end
end

--[[ Create a function that draws the hover tooltip for an item ]]
function InfoPanel:_make_item_tooltip_func(entry)
    return function(imgui, self_)
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

    if self.env.spell_text ~= "" then
        local match_upper = self.env.spell_text:gsub("[^a-zA-Z0-9_]", ""):upper()
        local match_lower = self.env.spell_text:gsub("[^a-zA-Z0-9_]", ""):lower()
        local spell_list = self:_get_spell_list()
        for _, spell_entry in ipairs(spell_list) do
            local entry = {
                id = spell_entry.id,
                name = spell_entry.name,
                icon = spell_entry.sprite,
                config = {
                    keep = 0,
                    ignore_ac = 0,
                },
            }
            local add_me = false
            if entry.id:match(match_upper) then
                add_me = true
            elseif entry.name:lower():match(match_lower) then
                add_me = true
            end
            local locname = GameTextGet(entry.name)
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
                    if player_has_spell(entry.id) then
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
        local ignore_ac = entry.config.ignore_ac == 1
        ret, ignore_ac = imgui.Checkbox("###ignore_ac_" .. entry.id, ignore_ac)
        if ret then
            entry.config.ignore_ac = ignore_ac and 1 or 0
        end
        self:_draw_hover_tooltip(imgui, "If checked, do not match if the spell is an Always Cast spell")
        imgui.SameLine()
        local hover_func = self:_make_spell_tooltip_func(entry)
        if entry.icon and self.config.show_images then
            self.host:draw_image(imgui, entry.icon, true)
            self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
            imgui.SameLine()
        end
        local label = entry.name
        if label:match("^%$") then
            label = GameTextGet(entry.name)
            if not label or label == "" then label = entry.name end
        end
        imgui.Text(("%s [%s]"):format(label, entry.id))
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
            local varname = "material_" .. kind
            local matid = entry.id
            local matname = entry.name
            local matuiname = entry.uiname
            local matlocname = entry.locname
            local maticon = entry.icon
            local mattags = entry.tags
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
                table.insert(self.env.material_list, {
                    kind = kind,
                    id = matid,
                    name = matname,
                    uiname = matuiname,
                    locname = matlocname,
                    icon = maticon,
                    tags = mattags,
                    config = {},
                })
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
        imgui.Text(("%s [%s]"):format(entry.locname, entry.name))
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
        local match_text = self.env.entity_text:gsub("[^a-zA-Z0-9_ ]", "")
        local enttab = self:_get_entity_list()
        for _, entry in ipairs(enttab) do
            local add_me = false
            local locname = GameTextGet(entry.name)
            if entry.name:match(self.env.entity_text) then
                add_me = true
            elseif entry.path:match(self.env.entity_text) then
                add_me = true
            elseif locname and locname ~= "" then
                if locname:lower():match(self.env.entity_text:lower()) then
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
                        config = {},
                    })
                end
                imgui.SameLine()
                if self.config.show_images then
                    self.host:draw_image(imgui, entry.icon, true, {
                        fallback="data/ui_gfx/icon_unkown.png"
                    })
                    self:_draw_hover_tooltip(imgui, ("Path: %s"):format(entry.path), NOWRAP)
                    imgui.SameLine()
                end
                imgui.Text(animal_build_name(entry.name, entry.path))
                self:_draw_hover_tooltip(imgui, ("Path: %s"):format(entry.path), NOWRAP)
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
        if entry.icon and self.config.show_images then
            self.host:draw_image(imgui, entry.icon, true, {
                fallback="data/ui_gfx/icon_unkown.png"
            })
            self:_draw_hover_tooltip(imgui, ("Path: %s"):format(entry.path), NOWRAP)
            imgui.SameLine()
        end
        imgui.Text(animal_build_name(entry.name, entry.path))
        self:_draw_hover_tooltip(imgui, ("Path: %s"):format(entry.path), NOWRAP)
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
            local locname = GameTextGet(entry.name)
            if not locname or locname == "" then locname = entry.name end
            if tag ~= nil then
                for itag in entry.tags:gmatch("[^,]+") do
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
                    self.host:draw_image(imgui, entry.icon, true, {
                        fallback="data/ui_gfx/icon_unkown.png"
                    })
                    self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
                    imgui.SameLine()
                end
                imgui.Text(("%s [%s]"):format(locname, entry.id))
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
            self.host:draw_image(imgui, entry.icon, true, {
                fallback="data/ui_gfx/icon_unkown.png"
            })
            self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
            imgui.SameLine()
        end
        local label = entry.name
        if label:match("^%$") then
            label = GameTextGet(entry.name)
            if not label or label == "" then label = entry.name end
        end
        imgui.Text(("%s [%s]"):format(label, entry.id))
        self:_draw_hover_tooltip(imgui, hover_func, NOWRAP)
    end
    if to_remove ~= nil then
        table.remove(self.env.item_list, to_remove)
    end
end

--[[ Determine if we need to remove any list entries and do so ]]
function InfoPanel:_process_remove_entries()
    local remove_spell = conf_get(CONF.REMOVE_SPELL)
    if remove_spell then
        local inv_cards = get_with_tags({"card_action"}, {player=true})
        local inv_spell_map = {}
        for _, entpair in ipairs(inv_cards) do
            local entid, entname = unpack(entpair)
            local spell = card_get_spell(entid)
            if not inv_spell_map[spell] then
                inv_spell_map[spell] = 0
            end
            inv_spell_map[spell] = inv_spell_map[spell] + 1
        end

        local to_remove = {}
        for idx, entry in ipairs(self.env.spell_list) do
            if inv_spell_map[entry.id] then
                local want_remove = true
                if entry.config and entry.config.keep then
                    if entry.config.keep ~= 0 then
                        want_remove = false
                    end
                end
                if want_remove then
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
        local inv_items = get_with_tags({"item_pickup"}, {player=true})
        local inv_item_map = {}
        for _, entpair in ipairs(inv_items) do
            local entid, entname = unpack(entpair)
            local filename = EntityGetFilename(entid)
            inv_item_map[filename] = entpair
        end

        local to_remove = {}
        for idx, entry in ipairs(self.env.item_list) do
            if inv_item_map[entry.path] then
                local want_remove = true
                if entry.config and entry.config.keep then
                    if entry.config.keep ~= 0 then
                        want_remove = false
                    end
                end
                if want_remove then
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
        local inv_mat_map = {}
        for _, entpair in ipairs(get_with_tags({"potion", "powder_stash"}, {player=true})) do
            local entid, entname = unpack(entpair)
            local cmap, clist = container_get_contents(entid)
            for matname, count in pairs(cmap) do
                if not inv_mat_map[matname] then
                    inv_mat_map[matname] = {count=count, containers={entid}}
                else
                    inv_mat_map[matname].count = inv_mat_map[matname].count + count
                    table.insert(inv_mat_map[matname].containers, entid)
                end
            end
        end
        local inv_materials = {}
        for matname, matinfo in pairs(inv_mat_map) do
            table.insert(inv_materials, matname)
        end

        local to_remove = {}
        for idx, entry in ipairs(self.env.material_list) do
            if inv_mat_map[entry.name] then
                table.insert(to_remove, 1, idx)
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
                if not table_has_entry(self.env[tvar], entry) then
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

--[[ Handle treasure chest prediction ]]
function InfoPanel:_format_chest_reward(reward)
    local rtype = reward.type
    local rname = reward.name or ""
    local rentity = reward.entity or ""
    local rentities = reward.entities or {}
    local ramount = reward.amount or 0
    rname = rname:gsub("%$[a-z0-9_]+", GameTextGet)

    local line = {}
    if rtype == REWARD.WAND then -- TODO
        table.insert(line, {
            {"Wand"},
            {
                --image=wand_data.icon,
                --fallback="data/ui_gfx/icon_unkown.png",
                color="lightcyan",
                ("%s [%s]"):format(rname, rentity)
            },
        })
    elseif rtype == REWARD.CARD then
        for _, spell in ipairs(rentities) do
            local spell_data = spell_get_data(spell:upper())
            local name = ("%s (unknown spell)"):format(spell)
            local icon = nil
            if spell_data.name then
                local spell_name = spell_data.name
                if spell_name:match("^%$") then
                    spell_name = GameTextGet(spell_name)
                end
                name = ("%s [%s]"):format(spell_name, spell)
                icon = spell_data.sprite
            else
                name = ("%s (unknown spell)")
            end
            table.insert(line, {
                {"Spell"},
                {
                    image=icon,
                    fallback="data/ui_gfx/icon_unkown.png",
                    color="lightcyan",
                    name,
                },
                clear_line=true,
            })
        end
    elseif rtype == REWARD.GOLD then
        local iinfo = self:_get_item_by_name("goldnugget")
        table.insert(line, {
            {("%d"):format(ramount/10)},
            {
                image=iinfo.icon,
                fallback="data/ui_gfx/items/goldnugget.png",
                color="lightcyan",
                GameTextGet("$item_goldnugget"),
            },
            {("(%d total gold)"):format(ramount)},
        })
    elseif rtype == REWARD.CONVERT then -- TODO
        table.insert(line, ("Convert entity to %s"):format(rname))
    elseif rtype == REWARD.ITEM then
        local iinfo = self:_get_item_by_name(rentity)
        table.insert(line, {
            {"Item"},
            {
                image=iinfo.icon,
                fallback="data/ui_gfx/icon_unkown.png",
                color="lightcyan",
                rname,
            },
        })
    elseif rtype == REWARD.ENTITY then
        local einfo = self:_get_entity_by_name(rentity)
        table.insert(line, {
            {"Entity"},
            {
                image=einfo.icon,
                fallback="data/ui_gfx/icon_unkown.png",
                color="lightcyan",
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
        table.insert(line, {
            {
                image=iinfo.icon,
                fallback="data/ui_gfx/icon_unkown.png",
                GameTextGet(iinfo.name or "$item_potion"),
            },
            {
                image=minfo.icon,
                fallback="data/ui_gfx/icon_unkown.png",
                color="lightcyan",
                mname,
            },
        })
    elseif rtype == REWARD.REROLL then
        table.insert(line, {
            image="data/ui_gfx/perk_icons/no_more_shuffle.png",
            ("Reroll x%d"):format(ramount)
        })
    elseif rtype == REWARD.POTIONS then -- TODO: Display each potion type with material
        local iinfo = self:_get_item_by_name("potion")
        table.insert(line, {
            image=iinfo.icon,
            fallback="data/ui_gfx/icon_unkown.png",
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
                image=minfo.icon,
                fallback="data/ui_gfx/icon_unkown.png",
                color="lightcyan",
                mname,
            })
        end
    elseif rtype == REWARD.GOLDRAIN then
        local iinfo = self:_get_item_by_name("goldnugget")
        table.insert(line, {
            image=iinfo.icon,
            fallback="data/ui_gfx/icon_unkown.png",
            GameTextGet("$item_goldnugget") .. " rain",
        })
    elseif rtype == REWARD.SAMPO then
        local iinfo = self:_get_item_by_name("sampo")
        table.insert(line, {
            image=iinfo.icon,
            fallback="data/ui_gfx/icon_unkown.png",
            GameTextGet("$item_mcguffin_12"),
        })
    else
        table.insert(line, ("Invalid reward %s"):format(rtype))
    end
    return line
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

    if self.do_debug then
        local debug_msg = smallfolk.dumps(contents)
        print(("InfoPanel:message(%s, %d)"):format(debug_msg, duration))
    end
    print(("InfoPanel:message(%q)"):format(text)) -- Writes to logger.txt (if enabled)
end

--[[ Public: called before draw or draw_closed regardless of visibility
--
-- Note: called *outside* the PushID/PopID guard!
--]]
function InfoPanel:on_draw_pre(imgui)
    if not self.do_debug then return end
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
        self.do_debug = false
    elseif show then
        if imgui.CollapsingHeader("Configuration") then
            for key, val in pairs(self.config) do
                imgui.Text(("self.config.%s = [%s]\"%s\""):format(
                    key, type(val), val))
            end
        end

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
    self.host = host or {}
    self.biomes = _get_biome_data()
    self.gui = GuiCreate()

    Orbs:init()

    self.debug = {}
    self.do_debug = false

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
    local wrapper = function() return this:_init_tables() end
    local on_error = function(errmsg)
        self.host:print(errmsg)
        if debug and debug.traceback then
            self.host:print(debug.traceback())
        end
        print_error(errmsg)
    end
    local res, ret = xpcall(wrapper, on_error)
    if not res then self.host:print(tostring(ret)) end

    -- Upgrade material list: add tags entry
    for matidx, matentry in ipairs(self.env.material_list) do
        if not matentry.tags then
            matentry.tags = CellFactory_GetTags(matentry.id)
        end
    end

    return self
end

--[[ Public: draw the menu bar ]]
function InfoPanel:draw_menu(imgui)
    if imgui.BeginMenu(self.name) then
        if imgui.MenuItem("Toggle Checkboxes") then
            self.env.show_checkboxes = not self.env.show_checkboxes
        end
        if imgui.MenuItem("Toggle Images") then
            self.config.show_images = not self.config.show_images
            ModSettingSetNextValue(self.conf.show_images, self.config.show_images, false)
        end
        imgui.SeparatorText("Pickup Actions")
        local items = {
            {"Spells", self.conf.remove_spell},
            {"Items", self.conf.remove_item},
            {"Materials", self.conf.remove_material},
        }
        for _, entry in ipairs(items) do
            local label, conf = unpack(entry)
            local curr = ModSettingGet(conf)
            local prefix = curr and "Disable" or "Enable"
            local text = ("%s Remove %s on Pickup"):format(prefix, label)
            if imgui.MenuItem(text) then
                ModSettingSetNextValue(conf, not curr, false)
            end
        end
        imgui.SeparatorText("Orb Radar")
        local prefix = conf_get(CONF.ORB_ENABLE) and "Disable" or "Enable"
        if imgui.MenuItem(prefix .. " Orb Radar") then
            conf_set(CONF.ORB_ENABLE, not conf_get(CONF.ORB_ENABLE))
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
            imgui.TextDisabled("Precise control in mod settings")
            imgui.EndMenu()
        end
        imgui.Separator()
        if imgui.MenuItem("Toggle Internal Debugging") then
            self.do_debug = not self.do_debug
        end
        imgui.EndMenu()
    end

    local menus = {
        -- Plural, singular, env table name, env manage name
        {"Spells", "Spell", "spell_list", "manage_spells"},
        {"Materials", "Material", "material_list", "manage_materials"},
        {"Entities", "Entity", "entity_list", "manage_entities"},
        {"Items", "Item", "item_list", "manage_items"},
    }
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

    self.host:text_clear()
    self.config.show_images = conf_get(CONF.SHOW_IMAGES)
    if self.config.show_images == nil then self.config.show_images = true end

    self:_process_remove_entries()

    self:_draw_checkboxes(imgui)

    -- Display (and handle) timed messages
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

    -- Display and manage the import dialog
    self:_handle_import_dialog(imgui)

    -- Display the various dropdown menus

    if self.env.manage_spells then
        self:_draw_spell_dropdown(imgui)
        imgui.Separator()
        self:_draw_spell_list(imgui)
    end

    if self.env.manage_materials then
        self:_draw_material_dropdown(imgui)
        imgui.Separator()
        self:_draw_material_list(imgui)
    end

    if self.env.manage_entities then
        self:_draw_entity_dropdown(imgui)
        imgui.Separator()
        self:_draw_entity_list(imgui)
    end

    if self.env.manage_items then
        self:_draw_item_dropdown(imgui)
        imgui.Separator()
        self:_draw_item_list(imgui)
    end

    -- Process and display the "found something!!" results

    local found_something = false
    if self.env.find_items then
        for _, entry in ipairs(self:_find_containers()) do
            if not found_something then
                self.host:p({separator_text="Found something!!", color="yellow"})
                found_something = true
            end
            local contents = {}
            for _, mat in ipairs(entry.rare_contents) do
                local matinfo = self:_get_material_by_name(mat.name)
                table.insert(contents, matinfo.locname or GameTextGet(mat.uiname))
            end
            -- TODO: Add icons to contents table
            self.host:p(("%s with %s detected nearby!!"):format(
                entry.name, table.concat(contents, ", ")))
            local ex, ey = EntityGetTransform(entry.entity)
            if ex ~= nil and ey ~= nil then
                local pos_str = ("%d, %d"):format(ex, ey)
                self.host:d(("%s %d at %s"):format(entry.name, entry.entity, pos_str))
            end
            found_something = true
        end

        for _, entry in ipairs(self:_find_items()) do
            if not found_something then
                self.host:p({separator_text="Found something!!", color="yellow"})
                found_something = true
            end
            local entinfo = entry.entry
            self.host:p({
                {
                    image=entinfo.icon,
                    fallback="data/ui_gfx/icon_unkown.png",
                    entry.name,
                },
                "detected nearby!!",
            })
        end
    end

    if self.env.find_enemies then
        for _, entity in ipairs(self:_find_enemies()) do
            if not found_something then
                self.host:p({separator_text="Found something!!", color="yellow"})
                found_something = true
            end
            local entinfo = self:_get_entity_by_name(entity.path)
            local line = {
                {
                    image=entinfo.icon,
                    fallback="data/ui_gfx/icon_unkown.png",
                    entity.name,
                },
                "detected nearby!!",
            }
            self.host:p(line)
            local ex, ey = EntityGetTransform(entity.entity)
            if ex ~= nil and ey ~= nil then
                local pos_str = ("%d, %d"):format(ex, ey)
                self.host:d(("%s %d at %s"):format(entity.name, entity.entity, pos_str))
            end
        end
    end

    if self.env.find_spells then
        for entid, _ in pairs(self.env.card_matches) do
            if not found_something then
                self.host:p({separator_text="Found something!!", color="yellow"})
                found_something = true
            end
            local spell = card_get_spell(entid)
            local spell_name = spell_get_name(spell)
            local spell_data = spell_get_data(spell)
            if spell_name:match("^%$") then
                spell_name = GameTextGet(spell_name)
            end
            local name = ("%s [%s]"):format(spell_name, spell)
            self.host:p({
                "Spell",
                {name, image=spell_data.sprite, color="lightcyan"},
                "detected nearby!!",
            })
            local wx, wy = EntityGetTransform(entid)
            if wx ~= nil and wy ~= nil then
                local pos_str = ("%d, %d"):format(wx, wy)
                self.host:d(("Spell %d at %s with %s"):format(entid, pos_str, name))
            end
        end

        self:_find_spells()
        for entid, ent_spells in pairs(self.env.wand_matches) do
            local spell_list = {}
            for spell, _ in pairs(ent_spells) do
                local spell_data = spell_get_data(spell)
                local spell_name = spell_get_name(spell)
                if spell_name:match("^%$") then
                    spell_name = GameTextGet(spell_name)
                end
                local name = ("%s [%s]"):format(spell_name, spell)
                table.insert(spell_list, {
                    image=spell_data.sprite,
                    color="lightcyan",
                    name,
                })
            end
            -- TODO: Add wand image?
            self.host:p({
                "Wand with",
                spell_list,
                "detected nearby!!",
            })
            local wx, wy = EntityGetTransform(entid)
            if wx ~= nil and wy ~= nil then
                local pos_str = ("%d, %d"):format(wx, wy)
                self.host:d({
                    ("Wand %d at %s with"):format(entid, pos_str),
                    spell_list,
                })
            end
        end
    end

    -- Display everything else: biomes, items, enemies

    if self.env.list_biomes then
        self.host:p({separator_text="Biome Modifiers"})
        for bname, bdata in pairs(self.biomes) do
            local biome_name = bdata.uiname or bdata.name or bname
            if biome_name:match("^%$") then
                biome_name = GameTextGet(biome_name)
            end
            if not biome_name:lower():match(bname) then
                biome_name = ("%s [%s]"):format(biome_name, bname)
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
            local entname = EntityGetName(entities[1])
            if not entname or entname == "" then
                entname = EntityGetFilename(entities[1])
            end
            local iinfo = self:_get_item_by_name(entname)

            -- Print for things other than chests, as chests get special treatment
            if not entity_is_chest(entities[1]) then
                self.host:p({
                    ("%dx"):format(#entities),
                    {
                        name,
                        image=iinfo.icon,
                        fallback="data/ui_gfx/icon_unkown.png",
                        color="lightcyan",
                    },
                })
            end

            for _, entity in ipairs(entities) do
                local ex, ey = EntityGetTransform(entity)
                local contents = {}
                local line = {}
                table.insert(line, {
                    image=iinfo.icon,
                    fallback="data/ui_gfx/icon_unkown.png",
                    color="white",
                })
                table.insert(line, {name, color="lightcyan"})
                if self.host.debugging then
                    table.insert(line, {
                        ("%d at {%d,%d}"):format(entity, ex, ey),
                        color=self.host.colors.debug
                    })
                end
                -- TODO: Make this available to the search functions
                if entity_is_chest(entity) then
                    line[1].button = {
                        text = "View",
                        id = ("chest_%d_%d_inspect"):format(ex, ey),
                        func = function(this, ent, phost, pimgui)
                            local rewards = chest_get_rewards(ent)
                            for _, reward in ipairs(rewards) do
                                local rline = this:_format_chest_reward(reward)
                                this:message({image=iinfo.icon, rline})
                            end
                        end,
                        small = true,
                        self,
                        entity,
                    }
                    self.host:p(line)
                else
                    local capacity = container_get_capacity(entity)
                    for matname, amount in pairs(container_get_contents(entity)) do
                        local percent = amount / capacity * 100
                        table.insert(contents, ("%s %d%%"):format(matname, percent))
                    end
                    if #contents > 0 then
                        table.insert(line, "with")
                        table.insert(line, table.concat(contents, ", "))
                    elseif EntityHasTag(entity, "potion") then
                        table.insert(line, "empty")
                    end
                    self.host:d(line)
                end
            end
        end
    end

    if self.env.find_enemies then
        self.host:p({separator_text="Enemies"})
        for _, entry in ipairs(aggregate(self:_get_nearby_enemies())) do
            local name, entities = unpack(entry)
            local first_entity = entities[1]
            local entname = EntityGetName(first_entity)
            local entinfo = {}
            if entname and entname ~= "" then
                entinfo = self:_get_entity_by_name(entname)
            end
            if not entinfo.id then
                entinfo = self:_get_entity_by_name(name)
            end
            self.host:p({
                ("%dx"):format(#entities),
                {
                    image = entinfo.icon,
                    fallback = "data/ui_gfx/icon_unkown.png",
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
    if self.env.find_spells then
        self:_find_spells()
    end
    self:_draw_orb_radar()
    self:_draw_onscreen_gui()

    self:_process_remove_entries()
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
