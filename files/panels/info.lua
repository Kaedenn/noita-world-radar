--[[
The "Info" Panel: Display interesting information

TODO: Only display the primary biome of a biome group

TODO: Add "include all unknown spells" button
TODO: Add "auto-remove found spells" button

TODO: Add "show triggers" (eg. temple collapse) via barrier spell effect

TODO: Allow user to configure where the on-screen text is displayed
--]]

nxml = dofile_once("mods/world_radar/files/lib/nxml.lua")
smallfolk = dofile_once("mods/world_radar/files/lib/smallfolk.lua")

dofile_once("mods/world_radar/config.lua")
-- luacheck: globals MOD_ID
dofile_once("mods/world_radar/files/utility/biome.lua")
-- luacheck: globals biome_is_default biome_is_common biome_modifier_get
dofile_once("mods/world_radar/files/utility/entity.lua")
-- luacheck: globals is_child_of entity_is_item entity_is_enemy item_get_name enemy_get_name get_name get_health entity_match get_with_tags distance_from
dofile_once("mods/world_radar/files/utility/material.lua")
-- luacheck: globals container_get_contents material_get_icon generate_material_tables
dofile_once("mods/world_radar/files/utility/spell.lua")
-- luacheck: globals card_get_spell wand_get_spells spell_get_name

--[[ Panel class with default values.
--
-- Selection menus (spell, material, entity, item) operate as follows:
--  self.env.find_<menu>=true       Master enable/disable checkbox
--  self.env.<menu>_list            Table of selected items
--      <menu>_list[idx].id         Internal ID or unlocalized name
--      <menu>_list[idx].name       Display (possibly localized) name
--      <menu>_list[idx].icon       Path to icon image, if one exists
--      <menu>_list[idx].path       Path to asset file, if applicable
--  self.env.<menu>_add_multi=false Allow multiple additions per input
--  self.env.<menu>_text:string     Current input text
--]]
InfoPanel = {
    id = "info",
    name = "Info",
    conf = {
        show_images = MOD_ID .. ".show_images",
        remove_spell = MOD_ID .. ".remove_found_spell",
        remove_material = MOD_ID .. ".remove_found_material",
    },
    config = {
        range = math.huge,
        rare_biome_mod = 0.2,
        show_images = true,
        rare_materials = { -- Default rare material list
            "creepy_liquid",
            "magic_liquid_hp_regeneration", -- Healthium
            "magic_liquid_weakness",        -- Diminution
            --"purifying_powder",
            "urine",
        },
        rare_entities = { -- Default rare entity list
            "$animal_worm_big",
            --"$animal_wizard_hearty",  -- Heart mage; available if desired
            "$animal_chest_leggy",
            "$animal_dark_alchemist",   -- Pahan muisto; heart mimic
            "$animal_mimic_potion",
            "$animal_playerghost",
            "$animal_shaman_wind",      -- Valhe; spell refresh mimic
        },
        rare_items = { -- Default rare item list
            "$item_chest_treasure_super",
            "$item_greed_die",
        },
        gui = {
            pad_left = 10,
            pad_bottom = 2,
        },
        icons = {
            width = 20,
            height = 20,
        },
    },
    env = {
        -- list_biomes = true
        -- find_items = true
        -- find_enemies = true
        -- find_spells = true
        -- onscreen = true

        -- show_checkboxes = true
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
    funcs = {
        ModTextFileGetContent = ModTextFileGetContent,
    },

    -- Types of information to show: name, varname, default
    modes = {
        {"Biomes", "list_biomes", true},
        {"Items", "find_items", true},
        {"Enemies", "find_enemies", true},
        {"Spells", "find_spells", true},
        {"On-screen", "onscreen", true},
    },
}

--[[ True if the given table is truly empty ]]
local function table_empty(tbl)
    if tbl == nil then return true end
    if #tbl > 0 then return false end
    local empty = true
    for key, val in pairs(tbl) do
        empty = false
    end
    return empty
end

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

--[[ Draw an image using imgui ]]
function InfoPanel:_draw_image(imgui, image, rescale, end_line)
    local path = image
    local width, height = 0, 0
    local uvx, uvy = 0, 0
    local frame_width, frame_height = nil, nil
    if type(image) == "table" then
        path = image.path
        width = image.width or 0
        height = image.height or 0
        frame_width = image.frame_width
        frame_height = image.frame_height
    end
    if path == "" or type(path) ~= "string" then
        return false
    end
    local img = imgui.LoadImage(path)
    if img then
        if frame_width then uvx = frame_width / img.width end
        if frame_height then uvy = frame_height / img.height end
        if width == 0 then width = img.width end
        if height == 0 then height = img.height end
        if rescale then
            width = self.config.icons.width or img.width
            height = self.config.icons.height or img.height
        end
        if uvx ~= 0 or uvy ~= 0 then
            imgui.Image(img, width, height, 0, 0, uvx, uvy)
        else
            imgui.Image(img, width, height)
        end
        if not end_line then
            imgui.SameLine()
        end
        return true
    end
    return false
end

--[[ Get biome information (name, path, modifier) for each biome ]]
function InfoPanel:_get_biome_data()
    local biomes_xml = nxml.parse(self.funcs.ModTextFileGetContent("data/biome/_biomes_all.xml"))
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

--[[ True if the spell is desired ]]
function InfoPanel:_want_spell(spell)
    for _, entry in ipairs(self.env.spell_list) do
        if entry.id:match(spell) then
            return true
        end
        if entry.name:match(spell) then
            return true
        end
        if GameTextGet(entry.name):match(spell) then
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

--[[ Obtain the spell ID, name, and icon path for a given spell name or ID ]]
function InfoPanel:_get_spell_by_name(sid, sname)
    local spell_name = sname:gsub("^%$", "")
    local spell_id = sid:upper()
    for _, entry in ipairs(self:_get_spell_list()) do
        if entry.id == spell_id or entry.name == spell_name then
            return {
                id = entry.id,
                name = entry.name,
                icon = entry.sprite
            }
        end
    end
    self.host:print(("Could not locate spell %q %q"):format(sid, sname))
    return {}
end

--[[ Obtain the material ID, name, etc. for the given name ]]
function InfoPanel:_get_material_by_name(mname)
    if self.env.material_cache and #self.env.material_cache > 0 then
        for _, entry in ipairs(self.env.material_cache) do
            if entry.name == mname then
                return entry
            end
        end
    else
        self.host:print("Material cache not ready before _get_material_by_name")
    end
    --[[
    -- Could not find it in the material cache; fall back to manual deduction
    local mid = CellFactory_GetType(mname)
    if mid < 0 then
        self.host:print(("Unknown material %q"):format(mname))
        return {}
    end
    self.host:print(("Material %q has ID %d"):format(mname, mid))
    local uiname = CellFactory_GetUIName(mid)
    local locname = GameTextGet(uiname)
    return {
        id = mid,
        name = mname,
        uiname = uiname,
        locname = locname,
        icon = material_get_icon(mname),
    }]]
    return {}
end

--[[ Obtain the entity ID, name, etc. for the given name ]]
function InfoPanel:_get_entity_by_name(ename)
    for _, entry in ipairs(self:_get_entity_list()) do
        if ename == entry.id or ename == entry.name then
            return entry
        end
    end
    return {}
end

--[[ Obtain the item ID, name, etc. for the given name ]]
function InfoPanel:_get_item_by_name(iname)
    for _, entry in ipairs(self:_get_item_list()) do
        if iname == entry.id or iname == entry.name then
            return entry
        end
    end
    return {}
end

--[[ Filter out entities that are children of the player or too far away ]]
function InfoPanel:_filter_entries(entries)
    local results = {}
    for _, entry in ipairs(entries) do
        local entity, name = unpack(entry)
        if name:match("^mods/") == nil then
            if not is_child_of(entity, nil) then
                local distance = distance_from(entity, nil)
                if distance <= self.config.range then
                    table.insert(results, entry)
                end
            end
        end
    end
    return results
end

--[[ Get all nearby non-held items ]]
function InfoPanel:_get_items()
    return self:_filter_entries(get_with_tags({"item_pickup"}))
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

--[[ Locate any rare items ]]
function InfoPanel:_find_items()
    local items = {}
    for _, item in ipairs(self:_filter_entries(get_with_tags({"item_pickup"}))) do
        local entity, name = unpack(item)
        for _, entry in ipairs(self.env.item_list) do
            local iname = entry.name
            if name:match(iname) or name:match(GameTextGet(iname)) then
                table.insert(items, {entity=entity, name=name})
            end
        end
    end
    return items
end

--[[ Get all nearby enemies ]]
function InfoPanel:_get_enemies()
    return self:_filter_entries(get_with_tags({"enemy"}))
end

--[[ Locate any rare enemies nearby ]]
function InfoPanel:_find_enemies()
    local enemies = {}
    local rare_ents = {}
    for _, entry in ipairs(self.env.entity_list) do
        rare_ents[entry.id] = entry
    end
    for _, enemy in ipairs(self:_get_enemies()) do
        local entity, name = unpack(enemy)
        local entname = EntityGetName(entity)
        if not entname or entname == "" then entname = name end
        if rare_ents[entname] then
            local entry = {}
            for key, val in ipairs(rare_ents[entname]) do
                entry[key] = val
            end
            entry.entity = entity
            entry.name = name
            table.insert(enemies, entry)
        end
    end
    return enemies
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
        for _, spell in ipairs(wand_get_spells(entid)) do
            if spell_table[spell] ~= nil then
                if not self.env.wand_matches[entid] then
                    self.env.wand_matches[entid] = {}
                end
                self.env.wand_matches[entid][spell] = true
            end
        end
    end

    self.env.card_matches = {}
    for _, entry in ipairs(get_with_tags({"card_action"}, {no_player=true})) do
        local entid = entry[1]
        local spell = card_get_spell(entid)
        local parent = EntityGetParent(entid)
        if not self.env.wand_matches[parent] then
            if spell and spell_table[spell] then
                self.env.card_matches[entid] = true
            end
        end
    end
end

--[[ Draw the on-screen UI ]]
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

    local padx, pady = self.config.gui.pad_left, self.config.gui.pad_bottom
    local linenr = 0
    local function draw_text(line)
        linenr = linenr + 1
        local liney = screen_height - char_height * linenr - pady
        GuiText(gui, padx, liney, line)
    end

    for _, entry in ipairs(aggregate(self:_find_enemies())) do
        local entname, entities = unpack(entry)
        draw_text(("%dx %s detected nearby!!"):format(#entities, entname))
    end

    for _, entry in ipairs(self:_find_items()) do
        draw_text(("%s detected nearby!!"):format(entry.name))
    end

    for _, entry in ipairs(self:_find_containers()) do
        local contents = {}
        for _, material in ipairs(entry.rare_contents) do
            table.insert(contents, GameTextGet(material.uiname))
        end
        draw_text(("%s with %s detected nearby!!"):format(
            entry.name, table.concat(contents, ", ")))
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
    end

    GuiIdPop(gui)
end

--[[ Initialize the various tables from their various places ]]
function InfoPanel:_init_tables()
    local tables = {
        {"spell_list", "spells", {}},
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
                local new_entry = nil
                if var == "spell_list" then
                    new_entry = self:_get_spell_by_name(item, item)
                elseif var == "material_list" then
                    new_entry = self:_get_material_by_name(item)
                elseif var == "entity_list" then
                    new_entry = self:_get_entity_by_name(item)
                elseif var == "item_list" then
                    new_entry = self:_get_item_by_name(item)
                end
                if not new_entry or table_empty(new_entry) then
                    new_entry = {id=item, name=item, path=nil, icon=nil}
                    print(("Failed to map %s %q"):format(var, item))
                end
                table.insert(data, new_entry)
            end
            from_table = "default"
        end
        if #data > 0 then
            self.env[var] = data
            self.host:print(("Loaded %d %s from %s %s table"):format(
                #self.env[var], name, from_table, var))
        end
    end
end

--[[ Public: initialize the panel ]]
function InfoPanel:init(environ, host, config)
    self.env = environ or self.env or {}
    self.host = host or {}

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

    self.biomes = self:_get_biome_data()
    self.gui = GuiCreate()

    self.env.show_checkboxes = true
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
        imgui.Separator()
        local items = {
            {"Spells", self.conf.remove_spell},
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
        imgui.Separator()
        if imgui.MenuItem("Toggle Internal Debugging") then
            self.env.do_debug = not self.env.do_debug
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
            imgui.EndMenu()
        end
    end
end

function InfoPanel:_draw_checkboxes(imgui)
    if not self.env.show_checkboxes then return end

    for idx, bpair in ipairs(self.modes) do
        if idx > 1 then imgui.SameLine() end
        imgui.SetNextItemWidth(100)
        local name, varname = unpack(bpair)
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
            local wrap = config and config.wrap or 400
            if wrap > 0 then
                imgui.PushTextWrapPos(wrap)
            end
            if type(content) == "string" then
                imgui.Text(content)
            elseif type(content) == "function" then
                content(imgui, self, config)
            end
            if wrap > 0 then
                imgui.PopTextWrapPos()
            end
            imgui.EndTooltip()
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
        local mattags = entry.tags or {""}
        imgui.Text(("%s (ID: %s, type %s)"):format(matname, matid, kind))
        imgui.Text(("UI Name: %s"):format(matuiname))
        imgui.Text(("Tags: %s"):format(table.concat(mattags, " ")))
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
        if self.env.do_debug then
            imgui.Text(("match_upper: %q"):format(match_upper))
            imgui.Text(("match_lower: %q"):format(match_lower))
        end
        for _, spell_entry in ipairs(spell_list) do
            local entry = {
                id = spell_entry.id,
                name = spell_entry.name,
                icon = spell_entry.sprite
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
                if imgui.SmallButton("Add###add_" .. entry.id) then
                    if not self.env.spell_add_multi then self.env.spell_text = "" end
                    table.insert(self.env.spell_list, entry)
                end
                imgui.SameLine()
                if entry.icon and self.config.show_images then
                    self:_draw_image(imgui, entry.icon, true, false)
                end
                if not locname or locname == "" then locname = entry.name end
                imgui.Text(("%s (%s)"):format(locname, entry.id))
            end
        end
    end
end

function InfoPanel:_draw_spell_list(imgui)
    local to_remove = nil
    local flags = imgui.WindowFlags.HorizontalScrollbar
    if imgui.BeginChild("Spell List###spell_list", 0, 0, true, flags) then
        for idx, entry in ipairs(self.env.spell_list) do
            if imgui.SmallButton("Remove###remove_" .. entry.id) then
                to_remove = idx
            end
            imgui.SameLine()
            if entry.icon and self.config.show_images then
                self:_draw_image(imgui, entry.icon, true, false)
            end
            local label = entry.name
            if label:match("^[$]") then
                label = GameTextGet(entry.name)
                if not label or label == "" then label = entry.name end
            end
            imgui.Text(("%s [%s]"):format(label, entry.id))
        end
        if to_remove ~= nil then
            table.remove(self.env.spell_list, to_remove)
        end
        imgui.EndChild()
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
                })
            end
            imgui.SameLine()
            local hover_tooltip_func = self:_make_material_tooltip_func(entry)
            if maticon and self.config.show_images then
                self:_draw_image(imgui, maticon, true, false)
                self:_draw_hover_tooltip(imgui, hover_tooltip_func, {wrap=500})
            end
            imgui.Text(("%s (%s)"):format(matlocname, matname))
            self:_draw_hover_tooltip(imgui, hover_tooltip_func, {wrap=500})

            ::continue::
        end
    end
end

function InfoPanel:_draw_material_list(imgui)
    local to_remove = nil
    local flags = imgui.WindowFlags.HorizontalScrollbar
    if imgui.BeginChild("Material List###material_list", 0, 0, true, flags) then
        for idx, entry in ipairs(self.env.material_list) do
            if imgui.SmallButton("Remove###remove_" .. entry.name) then
                to_remove = idx
            end
            imgui.SameLine()
            local hover_tooltip_func = self:_make_material_tooltip_func(entry)
            if entry.icon and self.config.show_images then
                self:_draw_image(imgui, entry.icon, true, false)
                self:_draw_hover_tooltip(imgui, hover_tooltip_func)
            end
            imgui.Text(("%s [%s]"):format(entry.locname, entry.name))
            self:_draw_hover_tooltip(imgui, hover_tooltip_func)
        end
        if to_remove ~= nil then
            table.remove(self.env.material_list, to_remove)
        end
        imgui.EndChild()
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
                if entity.id == entry.id then
                    add_me = false
                end
            end
            if add_me then
                if imgui.SmallButton("Add###add_" .. entry.id) then
                    if not self.env.entity_add_multi then self.env.entity_text = "" end
                    table.insert(self.env.entity_list, {
                        id = entry.id,
                        name = entry.name,
                        path = entry.path,
                        icon = entry.icon,
                    })
                end
                imgui.SameLine()
                if self.config.show_images then
                    local paths = {entry.icon, "data/ui_gfx/icon_unknown.png"}
                    for _, path in ipairs(paths) do
                        local result = self:_draw_image(imgui, path, true, false)
                        if result then break end
                    end
                end
                imgui.Text(("%s (%s)"):format(locname, entry.name))
            end
        end
    end
end

function InfoPanel:_draw_entity_list(imgui)
    local to_remove = nil
    local flags = imgui.WindowFlags.HorizontalScrollbar
    if imgui.BeginChild("Entity List###entity_list", 0, 0, true, flags) then
        for idx, entry in ipairs(self.env.entity_list) do
            local bid = ("Remove###remove_%s_%d"):format(entry.id, idx)
            if imgui.SmallButton(bid) then
                to_remove = idx
            end
            imgui.SameLine()
            if entry.icon and self.config.show_images then
                self:_draw_image(imgui, entry.icon, true, false)
            end
            local label = entry.name
            if label:match("^[$]") then
                label = GameTextGet(entry.name)
                if not label or label == "" then label = entry.name end
            end
            imgui.Text(("%s [%s]"):format(label, entry.id))
        end
        if to_remove ~= nil then
            table.remove(self.env.entity_list, to_remove)
        end
        imgui.EndChild()
    end
end

function InfoPanel:_draw_item_dropdown(imgui)
    self:_draw_dropdown_inputs(imgui, {
        label = "Item",
        var_prefix = "item",
        var_manage = "manage_items",
        hover_text = "Item name or internal ID",
    })

    if self.env.item_text ~= "" then
        local itemtab = self:_get_item_list()
        for _, entry in ipairs(itemtab) do
            local add_me = false
            local locname = GameTextGet(entry.name)
            if not locname or locname == "" then locname = entry.name end
            if entry.name:match(self.env.item_text) then
                add_me = true
            elseif entry.path:match(self.env.item_text) then
                add_me = true
            elseif locname and locname ~= "" then
                if locname:lower():match(self.env.item_text:lower()) then
                    add_me = true
                end
            end
            -- Hide duplicate items from being added more than once
            for _, entity in ipairs(self.env.item_list) do
                if entity.name == entry.name then
                    add_me = false
                end
            end
            if add_me then
                if imgui.SmallButton("Add###add_" .. entry.name) then
                    if not self.env.item_add_multi then self.env.item_text = "" end
                    table.insert(self.env.item_list, {
                        id = entry.id,
                        name = entry.name,
                        path = entry.path,
                        icon = entry.icon,
                        tags = entry.tags,
                    })
                end
                imgui.SameLine()
                if entry.icon and self.config.show_images then
                    self:_draw_image(imgui, entry.icon, true, false)
                end
                imgui.Text(("%s [%s]"):format(locname, entry.id))
            end
        end
    end
end

function InfoPanel:_draw_item_list(imgui)
    local to_remove = nil
    local flags = imgui.WindowFlags.HorizontalScrollbar
    if imgui.BeginChild("Item List###item_list", 0, 0, true, flags) then
        for idx, entry in ipairs(self.env.item_list) do
            if imgui.SmallButton("Remove###remove_" .. entry.id) then
                to_remove = idx
            end
            imgui.SameLine()
            if entry.icon and self.config.show_images then
                self:_draw_image(imgui, entry.icon, true, false)
            end
            local label = entry.name
            if label:match("^[$]") then
                label = GameTextGet(entry.name)
                if not label or label == "" then label = entry.name end
            end
            imgui.Text(("%s [%s]"):format(label, entry.id))
        end
        if to_remove ~= nil then
            table.remove(self.env.item_list, to_remove)
        end
        imgui.EndChild()
    end
end

--[[ Determine if we need to remove any list entries and do so ]]
function InfoPanel:_process_remove_entries()
    local remove_spell = ModSettingGet(self.conf.remove_spell)
    if remove_spell then
        local inv_cards = get_with_tags({"card_action"}, {player=true})
        local inv_spell_map = {}
        for _, entpair in ipairs(inv_cards) do
            local entid, entname = unpack(entpair)
            local spell = card_get_spell(entid)
            inv_spell_map[spell] = (inv_spell_map[spell] or 0) + 1
        end
        local inv_spells = {}
        for spell, count in pairs(inv_spell_map) do
            table.insert(inv_spells, spell)
        end

        local to_remove = {}
        for idx, entry in ipairs(self.env.spell_list) do
            if inv_spell_map[entry.id] then
                table.insert(to_remove, 1, idx)
            end
        end

        if #to_remove > 0 then
            for _, idx in ipairs(to_remove) do
                table.remove(self.env.spell_list, idx)
            end
            self.host:print(("Removed %d spell(s) from the spell list"):format(#to_remove))
        end
    end

    local remove_material = ModSettingGet(self.conf.remove_material)
    if remove_material then
        local inv_mat_map = {}
        for _, entpair in ipairs(get_with_tags({"potion", "powder_stash"}, {player=true})) do
            local entid, entname = unpack(entpair)
            local cmap, clist = container_get_contents(entid)
            for matname, count in pairs(cmap) do
                if not inv_mat_map[matname] then
                    inv_mat_map[matname] = {
                        count = count,
                        containers = {entid},
                    }
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
            self.host:print(("Removed %d material(s) from the material list"):format(#to_remove))
        end
    end
end

--[[ Public: called before draw or draw_closed regardless of visibility
--
-- Note: called *outside* the PushID/PopID guard!
--]]
function InfoPanel:on_draw_pre(imgui)
    if self.env.do_debug then
        local flags = bit.bor(
            imgui.WindowFlags.HorizontalScrollbar)
        if imgui.Begin("Info Panel Debugging Window", nil, flags) then
            local dconfig = {obj_pre="\n", entry_pre="  ", entry_post="\n"}
            imgui.Text(("spell_list[%d] = {%s...}"):format(
                #self.env.spell_list,
                smallfolk.dumps(self.env.spell_list[1] or {}, dconfig)))
            if imgui.Button("Copy Spell List") then
                imgui.SetClipboardText(smallfolk.dumps(self.env.spell_list, dconfig))
            end

            imgui.Text(("material_list[%d] = {%s...}"):format(
                #self.env.material_list,
                smallfolk.dumps(self.env.material_list[1] or {}, dconfig)))
            if imgui.Button("Copy Material List") then
                imgui.SetClipboardText(smallfolk.dumps(self.env.material_list, dconfig))
            end

            imgui.Text(("entity_list[%d] = {%s...}"):format(
                #self.env.entity_list,
                smallfolk.dumps(self.env.entity_list[1] or {}, dconfig)))
            if imgui.Button("Copy Entity List") then
                imgui.SetClipboardText(smallfolk.dumps(self.env.entity_list, dconfig))
            end

            imgui.Text(("item_list[%d] = {%s...}"):format(
                #self.env.item_list,
                smallfolk.dumps(self.env.item_list[1] or {}, dconfig)))
            if imgui.Button("Copy Item List") then
                imgui.SetClipboardText(smallfolk.dumps(self.env.item_list, dconfig))
            end
            imgui.End()
        end
    end
end

--[[ Public: draw the panel content ]]
function InfoPanel:draw(imgui)
    self.host:text_clear()
    self.config.show_images = ModSettingGet(self.conf.show_images)
    if self.config.show_images == nil then self.config.show_images = true end

    self:_process_remove_entries()

    self:_draw_checkboxes(imgui)
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

    if self.env.list_biomes then
        --[[ Print all non-default biome modifiers ]]
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
        self.host:p(self.host.separator)
        for _, entry in ipairs(aggregate(self:_get_items())) do
            local name, entities = unpack(entry)
            -- TODO: Determine and display item icon
            local line = ("%dx %s"):format(#entities, name)
            self.host:p(line)

            for _, entity in ipairs(entities) do
                local ex, ey = EntityGetTransform(entity)
                local contents = {}
                line = ("%s %d at {%d,%d}"):format(name, entity, ex, ey)
                local div = 10
                if EntityHasTag(entity, "powder_stash") then
                    div = 15
                end
                -- TODO: Handle Alchemist flasks that contain 200%
                for matname, amount in pairs(container_get_contents(entity)) do
                    table.insert(contents, ("%s %d%%"):format(matname, amount/div))
                end
                if #contents > 0 then
                    line = line .. " with " .. table.concat(contents, ", ")
                elseif EntityHasTag(entity, "potion") then
                    line = line .. " empty"
                end
                self.host:d(line)
            end
        end

        for _, entry in ipairs(self:_find_containers()) do
            local contents = {}
            for _, mat in ipairs(entry.rare_contents) do
                local matinfo = self:_get_material_by_name(mat.name)
                table.insert(contents, matinfo.locname or GameTextGet(mat.uiname))
            end
            self.host:p(("%s with %s detected nearby!!"):format(
                entry.name, table.concat(contents, ", ")))
            local ex, ey = EntityGetTransform(entry.entity)
            if ex ~= nil and ey ~= nil then
                local pos_str = ("%d, %d"):format(ex, ey)
                self.host:d(("%s %d at %s"):format(entry.name, entry.entity, pos_str))
            end
        end
    end

    if self.env.find_enemies then
        self.host:p(self.host.separator)
        for _, entry in ipairs(aggregate(self:_get_enemies())) do
            local name, entities = unpack(entry)
            local first_entity = entities[1]
            local entname = EntityGetName(first_entity)
            local entinfo = nil
            if entname and entname ~= "" then
                entinfo = self:_get_entity_by_name(entname)
            end
            if not entinfo then
                entinfo = self:_get_entity_by_name(name)
            end
            local line = {("%dx"):format(#entities), {name}}
            if entinfo and entinfo.icon then
                line[2].image = entinfo.icon
            end
            self.host:p(line)
        end

        for _, entity in ipairs(self:_find_enemies()) do
            if entity.icon and self.config.show_images then
                self:_draw_image(imgui, entity.icon, true, false)
            end
            self.host:p(("%s detected nearby!!"):format(entity.name))
            local ex, ey = EntityGetTransform(entity.entity)
            if ex ~= nil and ey ~= nil then
                local pos_str = ("%d, %d"):format(ex, ey)
                self.host:d(("%s %d at %s"):format(entity.name, entity.entity, pos_str))
            end
        end
    end

    if self.env.find_spells then
        self:_find_spells()
        for entid, ent_spells in pairs(self.env.wand_matches) do
            local spell_list = {}
            for spell, _ in pairs(ent_spells) do
                local spell_name = spell_get_name(spell)
                if spell_name:match("^%$") then
                    spell_name = GameTextGet(spell_name)
                end
                local name = ("%s [%s]"):format(spell_name, spell)
                table.insert(spell_list, name)
            end
            local spells = table.concat(spell_list, ", ")
            self.host:p(("Wand with %s detected nearby!!"):format(spells))
            local wx, wy = EntityGetTransform(entid)
            if wx ~= nil and wy ~= nil then
                local pos_str = ("%d, %d"):format(wx, wy)
                self.host:d(("Wand %d at %s with %s"):format(entid, pos_str, spells))
            end
        end

        for entid, _ in pairs(self.env.card_matches) do
            local spell = card_get_spell(entid)
            local spell_name = spell_get_name(spell)
            if spell_name:match("^%$") then
                spell_name = GameTextGet(spell_name)
            end
            local name = ("%s [%s]"):format(spell_name, spell)
            self.host:p(("Spell %s detected nearby!!"):format(name))
            local wx, wy = EntityGetTransform(entid)
            if wx ~= nil and wy ~= nil then
                local pos_str = ("%d, %d"):format(wx, wy)
                self.host:d(("Spell %d at %s with %s"):format(entid, pos_str, name))
            end
        end
    end

    if self.env.onscreen then
        self:_draw_onscreen_gui()
    end

end

--[[ Public: called when the panel window is closed ]]
function InfoPanel:draw_closed(imgui)
    if self.env.find_spells then
        self:_find_spells()
    end
    if self.env.onscreen then
        self:_draw_onscreen_gui()
    end

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
