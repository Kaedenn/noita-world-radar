--[[

The "Info" Panel: Display interesting information

TODO: Only display the primary biome of a biome group
TODO: Make rare_materials table configurable
TODO: Make rare_entities table configurable
--]]

nxml = dofile_once("mods/spell_finder/files/lib/nxml.lua")
smallfolk = dofile_once("mods/spell_finder/files/lib/smallfolk.lua")

dofile_once("mods/spell_finder/files/utility/biome.lua")
-- luacheck: globals biome_is_default biome_modifier_get
dofile_once("mods/spell_finder/files/utility/entity.lua")
-- luacheck: globals is_child_of entity_is_item entity_is_enemy item_get_name enemy_get_name get_name get_health get_with_tags distance_from
dofile_once("mods/spell_finder/files/utility/material.lua")
-- luacheck: globals container_get_contents
dofile_once("mods/spell_finder/files/utility/spell.lua")
-- luacheck: globals card_get_spell wand_get_spells

InfoPanel = {
    id = "info",
    name = "Info",
    config = {
        range = math.huge,
        rare_biome_mod = 0.2,
        rare_materials = {
            "creepy_liquid",
            "magic_liquid_hp_regeneration", -- Healthium
            "magic_liquid_weakness", -- Diminution
            "purifying_powder",
            "urine",
        },
        rare_entities = {
            "$animal_worm_big",
            "$animal_wizard_hearty",
            "$animal_chest_leggy",
            "$animal_dark_alchemist", -- Pahan muisto; heart mimic
            "$animal_mimic_potion",
            "$animal_playerghost",
        },
        gui = {
            pad_left = 10,
            pad_bottom = 2,
        },
    },
    env = {},
    host = nil,
    funcs = {
        ModTextFileGetContent = ModTextFileGetContent,
    },

    -- Types of information to show: name, varname, default
    modes = {
        {"Biomes", "biome_list", true},
        {"Items", "item_list", true},
        {"Enemies", "enemy_list", true},
        {"Spells", "find_spells", true},
        {"On-screen", "onscreen", true},
    },

    -- For debugging, provide access to the local functions
    _private_funcs = {},
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

--[[ Get biome information (name, path, modifier) for each biome ]]
function InfoPanel:_get_biome_data()
    local biome_xml = nxml.parse(self.funcs.ModTextFileGetContent("data/biome/_biomes_all.xml"))
    local biomes = {}
    for _, bdef in ipairs(biome_xml.children) do
        local biome_path = bdef.attr.biome_filename
        local biome_name = biome_path:match("^data/biome/(.*).xml$")
        local modifier = BiomeGetValue(biome_path, "mModifierUIDescription")
        local mod_data = biome_modifier_get(modifier) or {}
        if not biome_is_default(biome_name, modifier) then
            biomes[biome_name] = {
                name = biome_name, -- TODO: reliably determine localized name
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
    dofile("data/scripts/gun/gun_actions.lua")
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
function InfoPanel:_get_materials()
    if not self.env.material_cache or #self.env.material_cache == 0 then
        self.env.material_cache = {}
        self.env.material_cache.liquids = CellFactory_GetAllLiquids()
        self.env.material_cache.sands = CellFactory_GetAllSands()
        self.env.material_cache.gases = CellFactory_GetAllGases()
        self.env.material_cache.fires = CellFactory_GetAllFires()
        self.env.material_cache.solids = CellFactory_GetAllSolids()
    end
    return self.env.material_cache
end

--[[ Get all of the known entities (TODO) ]]
function InfoPanel:_get_entities()
    -- TODO
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

--[[ Get all non-held items within conf.range ]]
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
        for _, material in ipairs(self.config.rare_materials) do
            if contents[material] and contents[material] > 0 then
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
        if name:match(GameTextGet("$item_chest_treasure_super")) then
            table.insert(items, {entity=entity, name=name})
        elseif name:match(GameTextGet("$item_greed_die")) then
            table.insert(items, {entity=entity, name=name})
        end
    end
    return items
end

--[[ Count the nearby enemies ]]
function InfoPanel:_get_enemies()
    return self:_filter_entries(get_with_tags({"enemy"}))
end

--[[ Locate any rare enemies nearby ]]
function InfoPanel:_find_enemies()
    local enemies = {}
    local rare_ents = {}
    for _, entname in ipairs(self.config.rare_entities) do
        rare_ents[entname] = 1
    end
    for _, enemy in ipairs(self:_get_enemies()) do
        local entity, name = unpack(enemy)
        local entname = EntityGetName(entity)
        if not entname or entname == "" then entname = name end
        if rare_ents[entname] then
            table.insert(enemies, {entity=entity, name=name})
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
    GuiIdPushString(gui, "spell_finder_panel_info")

    local padx, pady = self.config.gui.pad_left, self.config.gui.pad_bottom
    local linenr = 0
    local function draw_text(line)
        linenr = linenr + 1
        local liney = screen_height - char_height * linenr - pady
        GuiText(gui, padx, liney, line)
    end

    for _, entry in ipairs(aggregate(self:_find_enemies())) do
        local entname, entities = unpack(entry)
        draw_text(("%dx %s"):format(#entities, entname))
    end

    for _, entry in ipairs(self:_find_items()) do
        draw_text(entry.name)
    end

    for _, entity in ipairs(self:_find_containers()) do
        local contents = table.concat(entity.rare_contents, ", ")
        draw_text(("%s with %s"):format(entity.name, contents))
    end

    for entid, ent_spells in pairs(self.env.wand_matches) do
        local spell_list = {}
        for spell_name, _ in pairs(ent_spells) do
            table.insert(spell_list, spell_name)
        end
        local spells = table.concat(spell_list, ", ")
        draw_text(("Wand with %s detected nearby!!"):format(spells))
    end

    for entid, _ in pairs(self.env.card_matches) do
        local spell = card_get_spell(entid)
        draw_text(("Spell %s detected nearby!!"):format(spell))
    end

    GuiIdPop(gui)
end

--[[ Initialize the various tables from their various places ]]
function InfoPanel:_init_tables()
    local tables = {
        {"spell_list", "spells", {}},
        {"material_list", "materials", self.config.rare_materials},
        {"entity_list", "entities", self.config.rare_entities}
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
                table.insert(data, {id=item, name=item})
            end
            from_table = "default"
        end
        if #data > 0 then
            self.env[var] = data
            self.host:print(("Loaded %d %s from %s table"):format(
                #self.env[var], name, from_table))
        end
    end
end

--[[ Public: initialize the panel ]]
function InfoPanel:init(environ, host)
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

    self.env.material_cache = nil

    self.env.material_liquid = true
    self.env.material_sand = true
    self.env.material_gas = false
    self.env.material_fire = false
    self.env.material_solid = false
    self.env.material_list = {}
    self.env.entity_list = {}
    self.env.spell_list = {}
    self.env.wand_matches = {}
    self.env.card_matches = {}
    self.env.spell_add_multi = false

    local this = self
    local wrapper = function() return this._init_tables(this) end
    local on_error = function(errmsg)
        self.host:print(errmsg)
        if debug and debug.traceback then
            self.host:print(debug.traceback())
        end
    end
    local res, ret = xpcall(wrapper, on_error)
    if not res then self.host:print(ret) end

    return self
end

--[[ Public: draw the menu bar ]]
function InfoPanel:draw_menu(imgui)
    if imgui.BeginMenu(self.name) then
        if imgui.MenuItem("Toggle Checkboxes") then
            self.env.show_checkboxes = not self.env.show_checkboxes
        end
        imgui.EndMenu()
    end

    if imgui.BeginMenu("Spells") then
        if imgui.MenuItem("Select Spells") then
            self.env.manage_spells = true
            self.env.manage_materials = false
            self.env.manage_entities = false
        end
        imgui.Separator()
        if imgui.MenuItem("Save Spell List (This Run)") then
            local data = smallfolk.dumps(self.env.spell_list)
            self.host:set_var(self.id, "spell_list", data)
            GamePrint(("Saved %d spells"):format(#self.env.spell_list))
        end
        if imgui.MenuItem("Load Spell List (This Run)") then
            local data = self.host:get_var(self.id, "spell_list", "")
            if data ~= "" then
                self.env.spell_list = smallfolk.loads(data)
                GamePrint(("Loaded %d spells"):format(#self.env.spell_list))
            else
                GamePrint("No spell list saved")
            end
        end
        if imgui.MenuItem("Clear Spell List (This Run)") then
            self.host:set_var(self.id, "spell_list", "{}")
            GamePrint("Cleared spell list")
        end

        imgui.Separator()
        if imgui.MenuItem("Save Spell List (Forever)") then
            local data = smallfolk.dumps(self.env.spell_list)
            self.host:save_value(self.id, "spell_list", data)
            GamePrint(("Saved %d spells"):format(#self.env.spell_list))
        end
        if imgui.MenuItem("Load Spell List (Forever)") then
            local data = self.host:load_value(self.id, "spell_list", "")
            if data ~= "" then
                self.env.spell_list = smallfolk.loads(data)
                GamePrint(("Loaded %d spells"):format(#self.env.spell_list))
            else
                GamePrint("No spell list saved")
            end
        end
        if imgui.MenuItem("Clear Spell List (Forever)") then
            if self.host:remove_value(self.id, "spell_list") then
                GamePrint("Cleared spell list")
            else
                GamePrint("No spell list saved")
            end
        end
        imgui.EndMenu()
    end

    if imgui.BeginMenu("Materials") then
        if imgui.MenuItem("Select Rare Materials") then
            self.env.manage_spells = false
            self.env.manage_materials = true
            self.env.manage_entities = false
        end
        imgui.Separator()
        if imgui.MenuItem("Save Material List (This Run)") then
            local data = smallfolk.dumps(self.env.material_list)
            self.host:set_var(self.id, "material_list", data)
            GamePrint(("Saved %d materials"):format(#self.env.material_list))
        end
        if imgui.MenuItem("Load Material List (This Run)") then
            local data = self.host:get_var(self.id, "material_list", "")
            if data ~= "" then
                self.env.material_list = smallfolk.loads(data)
                GamePrint(("Loaded %d materials"):format(#self.env.material_list))
            else
                GamePrint("No material list saved")
            end
        end
        if imgui.MenuItem("Clear Material List (This Run)") then
            self.host:set_var(self.id, "material_list", "{}")
            GamePrint("Cleared material list")
        end
        imgui.Separator()
        if imgui.MenuItem("Save Material List (Forever)") then
            local data = smallfolk.dumps(self.env.material_list)
            self.host:save_value(self.id, "material_list", data)
            GamePrint(("Saved %d materials"):format(#self.env.material_list))
        end
        if imgui.MenuItem("Load Material List (Forever)") then
            local data = self.host:load_value(self.id, "material_list", "")
            if data ~= "" then
                self.env.material_list = smallfolk.loads(data)
                GamePrint(("Loaded %d materials"):format(#self.env.material_list))
            else
                GamePrint("No material list saved")
            end
        end
        if imgui.MenuItem("Clear Material List (Forever)") then
            if self.host:remove_value(self.id, "material_list") then
                GamePrint("Cleared material list")
            else
                GamePrint("No material list saved")
            end
        end
        imgui.EndMenu()
    end

    if imgui.BeginMenu("Entities") then
        if imgui.MenuItem("Select Rare Entities") then
            self.env.manage_spells = false
            self.env.manage_materials = false
            self.env.manage_entities = true
        end
        imgui.Separator()
        if imgui.MenuItem("Save Entity List (This Run)") then
            local data = smallfolk.dumps(self.env.entity_list)
            self.host:set_var(self.id, "entity_list", data)
            GamePrint(("Saved %d entities"):format(#self.env.entity_list))
        end
        if imgui.MenuItem("Load Entity List (This Run)") then
            local data = self.host:get_var(self.id, "entity_list", "")
            if data ~= "" then
                self.env.entity_list = smallfolk.loads(data)
                GamePrint(("Loaded %d entities"):format(#self.env.entity_list))
            else
                GamePrint("No entity list saved")
            end
        end
        if imgui.MenuItem("Clear Entity List (This Run)") then
            self.host:set_var(self.id, "entity_list", "{}")
            GamePrint("Cleared entity list")
        end
        imgui.Separator()
        if imgui.MenuItem("Save Entity List (Forever)") then
            local data = smallfolk.dumps(self.env.entity_list)
            self.host:save_value(self.id, "entity_list", data)
            GamePrint(("Saved %d entities"):format(#self.env.entity_list))
        end
        if imgui.MenuItem("Load Entity List (Forever)") then
            local data = self.host:load_value(self.id, "entity_list", "")
            if data ~= "" then
                self.env.entity_list = smallfolk.loads(data)
                GamePrint(("Loaded %d entities"):format(#self.env.entity_list))
            else
                GamePrint("No entity list saved")
            end
        end
        if imgui.MenuItem("Clear Entity List (Forever)") then
            if self.host:remove_value(self.id, "entity_list") then
                GamePrint("Cleared entity list")
            else
                GamePrint("No entity list saved")
            end
        end
        imgui.EndMenu()
    end
end

function InfoPanel:_draw_checkboxes(imgui)
    if not self.env.show_checkboxes then
        return
    end

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

function InfoPanel:_draw_spell_dropdown(imgui)
    if not self.env.spell_text then self.env.spell_text = "" end
    local ret, text = false, self.env.spell_text
    imgui.SetNextItemWidth(400)
    ret, text = imgui.InputText("Spell###spell_input", text)
    if ret then self.env.spell_text = text end
    imgui.SameLine()
    if imgui.SmallButton("Done###spell_done") then
        self.env.manage_spells = false
    end
    imgui.SameLine()
    if imgui.SmallButton("Save###spell_save") then
        local data = smallfolk.dumps(self.env.spell_list)
        self.host:set_var(self.id, "spell_list", data)
        self.env.manage_spells = false
    end
    imgui.SameLine()
    _, self.env.spell_add_multi = imgui.Checkbox("Multi###spell_multi", self.env.spell_add_multi)

    if self.env.spell_text ~= "" then
        local spell_list = self:_get_spell_list()
        for _, entry in ipairs(spell_list) do
            local add_me = false
            if entry.id:match(self.env.spell_text:upper()) then
                add_me = true
            elseif entry.name:lower():match(self.env.spell_text:lower()) then
                add_me = true
            end
            local locname = GameTextGet(entry.name)
            if locname and locname ~= "" then
                if locname:lower():match(self.env.spell_text:lower()) then
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
                    table.insert(self.env.spell_list, {name=entry.name, id=entry.id})
                end
                imgui.SameLine()
                imgui.Text(("%s (%s)"):format(GameTextGet(entry.name), entry.id))
            end
        end
    end
end

function InfoPanel:_draw_spell_list(imgui)
    local to_remove = nil
    local flags = bit.bor(
        imgui.WindowFlags.HorizontalScrollbar)
    if imgui.BeginChild("Spell List###spell_list", 0, 0, true, flags) then
        for idx, entry in ipairs(self.env.spell_list) do
            if imgui.SmallButton("Remove###remove_" .. entry.id) then
                to_remove = idx
            end
            imgui.SameLine()
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
    if not self.env.material_text then self.env.material_text = "" end
    local ret, text = false, self.env.material_text
    imgui.SetNextItemWidth(400)
    ret, text = imgui.InputText("Material###material_input", text)
    if ret then self.env.material_text = text end
    imgui.SameLine()
    if imgui.SmallButton("Done###material_done") then
        self.env.manage_materials = false
    end
    imgui.SameLine()
    if imgui.SmallButton("Save###material_save") then
        local data = smallfolk.dumps(self.env.material_list)
        self.host:set_var(self.id, "material_list", data)
        self.env.manage_materials = false
    end
    imgui.SameLine()
    _, self.env.material_add_multi = imgui.Checkbox("Multi###material_multi", self.env.material_add_multi)

    local kinds = {
        {"Liquids", "material_liquid"},
        {"Sands", "material_sand"},
        {"Gases", "material_gas"},
        {"Fires", "material_fire"},
        {"Solids", "material_solid"},
    }
    for idx, kind in ipairs(kinds) do
        local label, var = unpack(kind)
        if idx ~= 1 then imgui.SameLine() end
        imgui.SetNextItemWidth(80)
        _, self.env[var] = imgui.Checkbox(label .. "###" .. var, self.env[var])
    end

    if self.env.material_text ~= "" then
        local mattabs = self:_get_materials()
        -- TODO
    end
end

function InfoPanel:_draw_material_list(imgui)
    local to_remove = nil
    local flags = bit.bor(
        imgui.WindowFlags.HorizontalScrollbar)
    if imgui.BeginChild("Material List###material_list", 0, 0, true, flags) then
        for idx, entry in ipairs(self.env.material_list) do
            if imgui.SmallButton("Remove###remove_" .. entry.id) then
                to_remove = idx
            end
            imgui.SameLine()
            local label = entry.name
            if label:match("^[$]") then
                label = GameTextGet(entry.name)
                if not label or label == "" then label = entry.name end
            end
            imgui.Text(("%s [%s]"):format(label, entry.id))
        end
        if to_remove ~= nil then
            table.remove(self.env.material_list, to_remove)
        end
        imgui.EndChild()
    end
end

function InfoPanel:_draw_entity_dropdown(imgui)
    if not self.env.entity_text then self.env.entity_text = "" end
    local ret, text = false, self.env.entity_text
    imgui.SetNextItemWidth(400)
    ret, text = imgui.InputText("Entity###entity_input", text)
    if ret then self.env.entity_text = text end
    imgui.SameLine()
    if imgui.SmallButton("Done###entity_done") then
        self.env.manage_entities = false
    end
    imgui.SameLine()
    if imgui.SmallButton("Save###entity_save") then
        local data = smallfolk.dumps(self.env.entity_list)
        self.host:set_var(self.id, "entity_list", data)
        self.env.manage_entities = false
    end
    imgui.SameLine()
    _, self.env.entity_add_multi = imgui.Checkbox("Multi###entity_multi", self.env.entity_add_multi)

    if self.env.entity_text ~= "" then
        local enttab = self:_get_entities()
        -- TODO
    end
end

function InfoPanel:_draw_entity_list(imgui)
    local to_remove = nil
    local flags = bit.bor(
        imgui.WindowFlags.HorizontalScrollbar)
    if imgui.BeginChild("Entity List###entity_list", 0, 0, true, flags) then
        for idx, entry in ipairs(self.env.entity_list) do
            if imgui.SmallButton("Remove###remove_" .. entry.id) then
                to_remove = idx
            end
            imgui.SameLine()
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

--[[ Public: draw the panel content ]]
function InfoPanel:draw(imgui)
    self.host:text_clear()

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

    if self.env.biome_list then
        --[[ Print all non-default biome modifiers ]]
        for bname, bdata in pairs(self.biomes) do
            line = ("%s: %s (%0.1f)"):format(bdata.name, bdata.text, bdata.probability)
            if bdata.probability < self.config.rare_biome_mod then
                self.host:p({line, color="yellow"})
            else
                self.host:p(line)
            end
        end
        --[[ Debugging: print the unlocalized strings from above
        for bname, bdata in pairs(self.biomes) do
            self.host:d(("%s: %s"):format(bname, bdata.modifier))
        end]]
    end

    if self.env.item_list then
        self.host:p(self.host.separator)
        for _, entry in ipairs(aggregate(self:_get_items())) do
            local name, entities = unpack(entry)
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

        for _, entity in ipairs(self:_find_containers()) do
            self.host:p(("%s with %s detected nearby!!"):format(
                entity.name, table.concat(entity.rare_contents, ", ")))
            local ex, ey = EntityGetTransform(entity.entity)
            self.host:d(("%s %d at {%d,%d}"):format(entity.name, entity.entity, ex, ey))
        end
    end

    if self.env.enemy_list then
        self.host:p(self.host.separator)
        for _, entry in ipairs(aggregate(self:_get_enemies())) do
            local name, entities = unpack(entry)
            self.host:p(("%dx %s"):format(#entities, name))
        end

        for _, entity in ipairs(self:_find_enemies()) do
            self.host:p(("%s detected nearby!!"):format(entity.name))
            local ex, ey = EntityGetTransform(entity.entity)
            self.host:d(("%s %d at {%d,%d}"):format(entity.name, entity.entity, ex, ey))
        end
    end

    if self.env.find_spells then
        self:_find_spells()
        for entid, ent_spells in pairs(self.env.wand_matches) do
            local spell_list = {}
            for spell_name, _ in pairs(ent_spells) do
                table.insert(spell_list, spell_name)
            end
            local spells = table.concat(spell_list, ", ")
            self.host:p(("Wand with %s detected nearby!!"):format(spells))
            local wx, wy = EntityGetTransform(entid)
            if wx ~= nil and wy ~= nil and wx ~= 0 and wy ~= 0 then
                local pos_str = ("%d, %d"):format(wx, wy)
                self.host:d(("Wand %d at %s with %s"):format(entid, pos_str, spells))
            end
        end

        for entid, _ in pairs(self.env.card_matches) do
            local spell = card_get_spell(entid)
            self.host:p(("Spell %s detected nearby!!"):format(spell))
            local wx, wy = EntityGetTransform(entid)
            if wx ~= nil and wy ~= nil and wx ~= 0 and wy ~= 0 then
                local pos_str = ("%d, %d"):format(wx, wy)
                self.host:d(("Spell %d at %s with %s"):format(entid, pos_str, spell))
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
end

--[[ Public: update configuration ]]
function InfoPanel:configure(config)
    for key, value in pairs(config) do
        self.config[key] = value
    end
end

return InfoPanel

-- vim: set ts=4 sts=4 sw=4:
