--[[ Treasure chest content prediction
--
-- This script attempts to determine what a treasure chest would drop
-- when opened.
--
-- Rewards are tables with the following keys:
--  type:string             One of the type codes below
--  name:string             Name of the new entity
--  entity:string           Path to the new entity xml (or nil)
--  amount:number           Amount of this type dropped (or nil)
--  entities:{string...}?   Table of new entity xmls
--
-- Special additional keys for certain reward types:
--  content="material_name"         when type="potion"
--  contents={"material_name", ...} when type="potions"
--
-- Treasure chest reward types:
--  entity      Spawn a simple entity given by the path
--  gold        Spawn gold nuggets; amount has the total value
--  wand        Spawn a wand; entity is the path to the wand XML
--  card        Spawn one or more spell(s); amount=number of spells,
--              entities={spell IDs (eg. BOMB, X_RAY, etc.)}
--  item        Spawn a single item
--  potion      Spawn a single potion, content=material
--  pouch       Spawn a material pouch, content=material
--  reroll      Re-roll the drop table; amount=number of times
--  convert     Convert the treasure chest sprite to gold dust
--
-- Greater Treasure Chest reward types:
--  potions     Spawn multiple potions; amount=number of potions,
--              entities={potion XMLs}, contents={materials}
--  goldrain    Start a gold rain event
--  sampo       The Sampo
--
-- The amount of gold dropped by gold rain cannot be predicted because the
-- random seed uses the newly-created entity ID. Because chest prediction
-- does not spawn entities, this can't be done.

dofile("mods/world_radar/files/utility/treasure_chest.lua")
rewards = chest_get_rewards(entid)
for _, reward in ipairs(rewards) do
  for key, val in pairs(reward) do
    print(key, smallfolk.dumps(val))
  end
end

--]]

-- FIXME: Potion rewards are incorrect

dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/gun/gun_enums.lua")
dofile_once("data/scripts/gun/gun_actions.lua")
dofile_once("data/scripts/game_helpers.lua")

REWARD = {
    ENTITY = "entity",      -- Spawn an entity by path
    GOLD = "gold",          -- Drop some gold nuggets
    WAND = "wand",          -- Spawn a wand
    CARD = "card",          -- Spawn a spell
    ITEM = "item",          -- Spawn an item
    POTION = "potion",      -- Spawn a potion
    POUCH = "pouch",        -- Spawn a pouch
    REROLL = "reroll",      -- Repeat a few more times
    CONVERT = "convert",    -- Convert the entity to something
    POTIONS = "potions",    -- Spawn several potions
    GOLDRAIN = "goldrain",  -- Make it rain gold
    SAMPO = "sampo",        -- Spawn The Sampo
}

CONTAINER = {
    POTION = "data/entities/items/pickup/potion.xml",
    POUCH = "data/entities/items/pickup/powder_stash.xml",
    POTION_SECRET = "data/entities/items/pickup/potion_secret.xml",
    POTION_RANDOM = "data/entities/items/pickup/potion_random_material.xml",
}

--[[ True if the entity is a treasure chest we can predict ]]
function entity_is_chest(entid)
    if EntityHasTag(entid, "chest") then
        local iname = EntityGetFilename(entid)
        if (iname:match("chest_random_super.xml") or
            iname:match("chest_random.xml")) then
            return true
        end
    elseif EntityHasTag(entid, "utility_box") then
        return true
    end
    return false
end

--[[ Obtain the rewards that would be dropped by the treasure chest ]]
function chest_get_rewards(entity_id, do_debug)
    local x, y = EntityGetTransform(entity_id)
    local rand_x, rand_y = x, y
    if rand_x == nil or rand_y == nil then
        error(("Failed to get location of entity %s"):format(tostring(entity_id)))
    end

    local position_comp = EntityGetFirstComponent(entity_id, "PositionSeedComponent")
    local seed_x, seed_y = rand_x, rand_y
    if position_comp then
        seed_x = tonumber(ComponentGetValue(position_comp, "pos_x"))
        seed_y = tonumber(ComponentGetValue(position_comp, "pos_y"))
    end

    local fname = EntityGetFilename(entity_id)
    local rewards = {}
    if fname:match("chest_random_super") then
        SetRandomSeed(rand_x, rand_y)
        if do_debug then
            print(("Entity %d: {%f, %f} rand={%f, %f}"):format(
                entity_id, seed_x, seed_y, rand_x, rand_y))
        end
        rewards = do_chest_get_rewards_super(x, y, entity_id, rand_x, rand_y)
    elseif fname:match("chest_random") then
        rand_x = seed_x + 509.7
        rand_y = seed_y + 683.1
        SetRandomSeed(rand_x, rand_y)
        if do_debug then
            print(("Entity %d: {%f, %f} rand={%f, %f}"):format(
                entity_id, seed_x, seed_y, rand_x, rand_y))
        end
        rewards = do_chest_get_rewards(x, y, entity_id, rand_x, rand_y)
    elseif fname:match("utility_box") then
        rand_x = seed_x + 509.7
        rand_y = seed_y + 683.1
        SetRandomSeed(rand_x, rand_y)
        if do_debug then
            print(("Entity %d: {%f, %f} rand={%f, %f}"):format(
                entity_id, seed_x, seed_y, rand_x, rand_y))
        end
        rewards = do_utility_box_get_rewards(x, y, entity_id, rand_x, rand_y)
    else
        local pos_str = ("(%f,%f)"):format(x, y)
        local spawn_str = ("(%d,%d)"):format(rand_x, rand_y)
        print_error(("Entity %d at %s (from %s) isn't a treasure chest"):format(
            entity_id, pos_str, spawn_str))
    end

    -- Expand potion rewards
    local rx = rand_x - 4.5 -- TODO: Figure out why this happens
    local ry = rand_y - 4
    for _, reward in ipairs(rewards) do
        if reward.type == REWARD.POTION or reward.type == REWARD.POUCH then
            reward.content = do_potion_get_contents(rx, ry, reward.entity, do_debug)
        elseif reward.type == REWARD.POTIONS then
            reward.contents = {}
            for _, fpath in ipairs(reward.entities) do
                table.insert(do_potion_get_contents(rx, ry, fpath, do_debug))
            end
        end
    end

    return rewards
end

--[[ Obtain the chest rewards for the given entity ]]
function do_chest_get_rewards(x, y, entity_id, rand_x, rand_y)
    local rewards = {}
    local count = 1
    while count > 0 do
        count = count - 1
        local rnd = Random(1, 100)

        local reward = {
            type=nil,
            name=nil,
            entity=nil,
            amount=nil,
            entities=nil,
        }
        if rnd <= 7 then -- Bomb
            reward.type = "entity"
            reward.name = "$action_bomb"
            reward.entity = "data/entities/projectiles/bomb_small.xml"
        elseif rnd <= 40 then -- Gold
            reward.type = "gold"
            reward.name = "$item_goldnugget"
            reward.amount = 0

            local amount = 5
            rnd = Random(0, 100)
            if rnd <= 80 then
                amount = 7
            elseif rnd <= 95 then
                amount = 10
            elseif rnd <= 100 then
                amount = 20
            end

            rnd = Random(0, 100)
            if rnd > 30 and rnd <= 80 then
                reward.amount = reward.amount + 50
            elseif rnd <= 95 then
                reward.amount = reward.amount + 200
            elseif rnd <= 99 then
                reward.amount = reward.amount + 1000
            else
                local tamount = Random(1, 3)
                for i=1, tamount do
                    reward.amount = reward.amount + 50
                    dummy = Random(-10, 10) -- Discard for x position
                    dummy = Random(-10, 5) -- Discard for y position
                end
                if Random(0, 100) > 50 then
                    tamount = Random(1, 3)
                    for i=1, tamount do
                        reward.amount = reward.amount + 200
                        dummy = Random(-10, 10) -- Discard for x position
                        dummy = Random(-10, 5) -- Discard for y position
                    end
                end
                if Random(0, 100) > 80 then
                    tamount = Random(1, 3)
                    for i=1, tamount do
                        reward.amount = reward.amount + 1000
                        dummy = Random(-10, 10) -- Discard for x position
                        dummy = Random(-10, 5) -- Discard for y position
                    end
                end
            end
            for i=1, amount do
                reward.amount = reward.amount + 10
                dummy = Random(-10, 10) -- Discard for x position
                dummy = Random(-10, 5) -- Discard for y position
            end
        elseif rnd <= 50 then -- Potion
            reward.type = "potion"
            reward.name = "potion"
            rnd = Random(0, 100)
            if rnd <= 94 then
                reward.type = "potion"
                reward.name = "$item_potion"
                reward.entity = "data/entities/items/pickup/potion.xml"
            elseif rnd <= 98 then
                reward.type = "pouch"
                reward.name = "$item_powder_stash_3"
                reward.entity = "data/entities/items/pickup/powder_stash.xml"
            elseif rnd <= 100 then
                rnd = Random(0, 100)
                if rnd <= 98 then
                    reward.type = "potion"
                    reward.name = "$item_potion (secret material)"
                    reward.entity = "data/entities/items/pickup/potion_secret.xml"
                elseif rnd <= 100 then
                    reward.type = "potion"
                    reward.name = "$item_potion (random material)"
                    reward.entity = "data/entities/items/pickup/potion_random_material.xml"
                end
            end
        elseif rnd <= 54 then -- Spell refresh (or mimic)
            rnd = Random(0, 100)
            if rnd <= 98 then
                reward.type = "item"
                reward.name = "$item_spell_refresh"
                reward.entity = "data/entities/items/pickup/spell_refresh.xml"
            else
                reward.type = "entity"
                reward.name = "$animal_shaman_wind (spell refresh mimic)"
                reward.entity = "data/entities/animals/illusions/shaman_wind.xml"
            end
        elseif rnd <= 60 then -- Misc items
            local greeding = GameHasFlagRun("greed_curse") and not GameHasFlagRun("greed_curse_gone")
            local opts = {
                "data/entities/items/pickup/safe_haven.xml",
                "data/entities/items/pickup/moon.xml",
                "data/entities/items/pickup/thunderstone.xml",
                "data/entities/items/pickup/evil_eye.xml",
                "data/entities/items/pickup/brimstone.xml",
                "runestone",
                "die",
                "orb"
            }
            rnd = Random(1, #opts)
            local opt = opts[rnd]
            if opt == "die" then
                local flag_status = HasFlagPersistent("card_unlocked_duplicate")
                if flag_status then
                    reward.type = "item"
                    if greeding then
                        reward.name = "$item_greed_die"
                        reward.entity = "data/entities/items/pickup/physics_greed_die.xml"
                    else
                        reward.name = "$item_die"
                        reward.entity = "data/entities/items/pickup/physics_die.xml"
                    end
                else
                    reward.type = "potion"
                    reward.name = "$item_potion (via die fallback)"
                    reward.entity = "data/entities/items/pickup/potion.xml"
                end
            elseif opt == "runestone" then
                local r_opts = {"laser", "fireball", "lava", "slow", "null", "disc", "metal"}
                rnd = Random(1, #r_opts)
                local r_opt = r_opts[rnd]
                reward.type = "item"
                reward.name = "$item_runestone_" .. r_opt
                reward.entity = "data/entities/items/pickup/runestones/runestone_" .. r_opt .. ".xml"
            elseif opt == "orb" then
                reward.type = "item"
                reward.name = "$item_gold_orb"
                reward.entity = "data/entities/items/pickup/physics_gold_orb.xml"
                if greeding then
                    reward.name = "$item_gold_orb_greed"
                    reward.entity = "data/entities/items/pickup/physics_gold_orb_greed.xml"
                end
            else
                reward.type = "item"
                reward.name = "$item_" .. string.match(opt, "([^/]*)%.xml$")
                reward.entity = opt
            end
        elseif rnd <= 65 then -- Random spell card
            local amount = 1
            rnd = Random(0, 100)
            if rnd <= 50 then
                amount = 1
            elseif rnd <= 70 then
                amount = amount + 1
            elseif rnd <= 80 then
                amount = amount + 2
            elseif rnd <= 90 then
                amount = amount + 3
            else
                amount = amount + 4
            end
            reward.type = "card"
            reward.name = "random spell"
            reward.amount = amount
            reward.entities = {}
            for i = 1, amount do
                local card_x = x + (i - (amount / 2)) * 8
                local card_y = y - 4 + Random(-5, 5)
                local card = get_random_card(card_x, card_y)
                if card then
                    table.insert(reward.entities, card)
                end
            end
        elseif rnd <= 84 then -- Wand
            rnd = Random(0, 100)
            reward.type = "wand"
            if rnd <= 25 then
                reward.name = "$item_wand (level 1)"
                reward.entity = "data/entities/items/wand_level_01.xml"
            elseif rnd <= 50 then
                reward.name = "$item_wand (level 1) (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_01.xml"
            elseif rnd <= 75 then
                reward.name = "$item_wand (level 2)"
                reward.entity = "data/entities/items/wand_level_02.xml"
            elseif rnd <= 90 then
                reward.name = "$item_wand (level 2) (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_02.xml"
            elseif rnd <= 96 then
                reward.name = "$item_wand (level 3)"
                reward.entity = "data/entities/items/wand_level_03.xml"
            elseif rnd <= 98 then
                reward.name = "$item_wand (level 3) (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_03.xml"
            elseif rnd <= 99 then
                reward.name = "$item_wand (level 4)"
                reward.entity = "data/entities/items/wand_level_04.xml"
            elseif rnd <= 100 then
                reward.name = "$item_wand (level 4) (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_04.xml"
            end
        elseif rnd <= 95 then -- Heart
            rnd = Random(0, 100)
            reward.type = "item"
            if rnd <= 88 then
                reward.name = "$item_heart"
                reward.entity = "data/entities/items/pickup/heart.xml"
            elseif rnd <= 89 then
                reward.type = "entity"
                reward.name = "$animal_dark_alchemist (heart mimic)"
                reward.entity = "data/entities/animals/illusions/dark_alchemist.xml"
            elseif rnd <= 99 then
                reward.name = "$item_heart_better"
                reward.entity = "data/entities/items/pickup/heart_better.xml"
            else
                reward.name = "$item_heart_fullhp"
                reward.entity = "data/entities/items/pickup/heart_fullhp.xml"
            end
        elseif rnd <= 98 then -- Converts the chest to gold
            reward.type = "convert"
            reward.name = "$mat_gold"
        elseif rnd <= 99 then -- Add 2 to the reward count
            count = count + 2
            reward.type = "reroll"
            reward.name = "reroll"
            reward.amount = 2
        elseif rnd <= 100 then -- Add 3 to the reward count
            count = count + 3
            reward.type = "reroll"
            reward.name = "reroll"
            reward.amount = 3
        end

        if reward.type ~= nil then
            table.insert(rewards, reward)
        end
    end

    return rewards
end

--[[ Obtain the greater treasure chest rewards for the given entity ]]
function do_chest_get_rewards_super(x, y, entity_id, rand_x, rand_y)
    if Random(0, 100000) >= 100000 then
        return {{type="sampo"}}
    end

    local rewards = {}
    local count = 1
    while count > 0 do
        count = count - 1
        local rnd = Random(1, 100)

        local reward = {type=nil, name=nil, entity=nil, amount=nil}
        if rnd <= 10 then
            rnd = Random(0, 100)
            reward.type = "potions"
            reward.name = "$item_potion"
            reward.entities = {}
            if rnd <= 30 then
                table.insert(reward.entities, "data/entities/items/pickup/potion.xml")
                table.insert(reward.entities, "data/entities/items/pickup/potion.xml")
                table.insert(reward.entities, "data/entities/items/pickup/potion_secret.xml")
            else
                table.insert(reward.entities, "data/entities/items/pickup/potion_secret.xml")
                table.insert(reward.entities, "data/entities/items/pickup/potion_secret.xml")
                table.insert(reward.entities, "data/entities/items/pickup/potion_random_material.xml")
            end
            reward.amount = #reward.entities
        elseif rnd <= 15 then
            reward.type = "goldrain"
            reward.name = "gold rain"
            reward.entity = "data/entities/projectiles/rain_gold.xml"
        elseif rnd <= 18 then
            rnd = Random(1, 30)
            reward.type = "item"
            if rnd ~= 30 then
                reward.name = "$item_waterstone"
                reward.entity = "data/entities/items/pickup/waterstone.xml"
            else
                reward.name = "$item_poopstone"
                reward.entity = "data/entities/items/pickup/poopstone.xml"
            end
        elseif rnd <= 39 then
            rnd = Random(0, 100)
            reward.type = "wand"
            if rnd <= 25 then
                reward.name = "$item_wand (level 4)"
                reward.entity = "data/entities/items/wand_level_04.xml"
            elseif rnd <= 50 then
                reward.name = "$item_wand (level 4) (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_04.xml"
            elseif rnd <= 75 then
                reward.name = "$item_wand (level 5)"
                reward.entity = "data/entities/items/wand_level_05.xml"
            elseif rnd <= 90 then
                reward.name = "$item_wand (level 5) (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_05.xml"
            elseif rnd <= 96 then
                reward.name = "$item_wand (level 6)"
                reward.entity = "data/entities/items/wand_level_06.xml"
            elseif rnd <= 98 then
                reward.name = "$item_wand (level 6) (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_06.xml"
            elseif rnd <= 99 then
                reward.name = "$item_wand (level 6)" -- Not a typo
                reward.entity = "data/entities/items/wand_level_06.xml"
            elseif rnd <= 100 then
                reward.name = "$item_wand (level 10)"
                reward.entity = "data/entities/items/wand_level_10.xml"
            end
        elseif rnd <= 60 then
            rnd = Random(0, 100)
            reward.type = "item"
            if rnd <= 89 then
                reward.name = "$item_heart"
                reward.entity = "data/entities/items/pickup/heart.xml"
            elseif rnd <= 99 then
                reward.name = "$item_heart_better"
                reward.entity = "data/entities/items/pickup/heart_better.xml"
            else
                reward.name = "$item_heart_fullhp"
                reward.entity = "data/entities/items/pickup/heart_fullhp.xml"
            end
        elseif rnd <= 98 then
            count = count + 2
            reward.type = "reroll"
            reward.amount = 2
        elseif rnd <= 100 then
            count = count + 3
            reward.type = "reroll"
            reward.amount = 3
        end

        if reward.type ~= nil then
            table.insert(rewards, reward)
        end
    end

    return rewards
end

--[[ Obtain the utility box rewards for the given entity ]]
function do_utility_box_get_rewards(x, y, entity_id, rand_x, rand_y)
    local rewards = {}
    local count = 1
    while count > 0 do
        count = count - 1
        local rnd = Random(1, 100)

        local reward = {type=nil, name=nil, entity=nil, amount=nil}
        if rnd <= 2 then -- Bomb
            reward.type = "entity"
            reward.name = "$action_bomb"
            reward.entity = "data/entities/projectiles/bomb_small.xml"
        elseif rnd <= 5 then -- Spell refresh (or mimic)
            rnd = Random(0, 100)
            if rnd <= 98 then
                reward.type = "item"
                reward.name = "$item_spell_refresh"
                reward.entity = "data/entities/items/pickup/spell_refresh.xml"
            else
                reward.type = "entity"
                reward.name = "$animal_shaman_wind (spell refresh mimic)"
                reward.entity = "data/entities/animals/illusions/shaman_wind.xml"
            end
        elseif rnd <= 11 then -- Misc items
            local greeding = GameHasFlagRun("greed_curse") and not GameHasFlagRun("greed_curse_gone")
            local opts = {
                "data/entities/items/pickup/safe_haven.xml",
                "data/entities/items/pickup/moon.xml",
                "data/entities/items/pickup/thunderstone.xml",
                "data/entities/items/pickup/evil_eye.xml",
                "data/entities/items/pickup/brimstone.xml",
                "runestone",
                "die",
                "orb"
            }
            rnd = Random( 1, #opts )
            local opt = opts[rnd]
            if opt == "die" then
                local flag_status = HasFlagPersistent("card_unlocked_duplicate")
                if flag_status then
                    reward.type = "item"
                    if greeding then
                        reward.name = "$item_greed_die"
                        reward.entity = "data/entities/items/pickup/physics_greed_die.xml"
                    else
                        reward.name = "$item_die"
                        reward.entity = "data/entities/items/pickup/physics_die.xml"
                    end
                else
                    reward.type = "potion"
                    reward.name = "$item_potion (via die fallback)"
                    reward.entity = "data/entities/items/pickup/potion.xml"
                end
            elseif opt == "runestone" then
                local r_opts = {"laser", "fireball", "lava", "slow", "null", "disc", "metal"}
                rnd = Random(1, #r_opts)
                local r_opt = r_opts[rnd]
                reward.type = "item"
                reward.name = "$item_runestone_" .. r_opt
                reward.entity = "data/entities/items/pickup/runestones/runestone_" .. r_opt .. ".xml"
            elseif opt == "orb" then
                reward.type = "item"
                reward.name = "$item_gold_orb"
                reward.entity = "data/entities/items/pickup/physics_gold_orb.xml"
                if greeding then
                    reward.name = "$item_gold_orb_greed"
                    reward.entity = "data/entities/items/pickup/physics_gold_orb_greed.xml"
                end
            else
                reward.type = "item"
                reward.name = "$item_" .. string.match(opt, "([^/]*)%.xml$")
                reward.entity = opt
            end
        elseif rnd <= 97 then -- Random card
            local amount = 2
            rnd = Random(0, 100)
            if rnd <= 40 then
                amount = 2
            elseif rnd <= 60 then
                amount = amount + 1
            elseif rnd <= 77 then
                amount = amount + 2
            elseif rnd < 90 then
                amount = amount + 3
            else
                amount = amount + 4
            end

            reward.type = "card"
            reward.name = "random spell"
            reward.amount = amount
            reward.entities = {}
            for i = 1, amount do
                local card_x = x + (i - (amount / 2)) * 8
                local card_y = y - 4 + Random(-5, 5)
                local card = get_random_utility_card(card_x, card_y)
                if card then
                    table.insert(reward.entities, card)
                end
            end
        elseif rnd <= 99 then -- Add 2 to the reward count
            count = count + 2
            reward.type = "reroll"
            reward.name = "reroll"
            reward.amount = 2
        elseif rnd <= 100 then -- Add 3 to the count
            count = count + 3
            reward.type = "reroll"
            reward.name = "reroll"
            reward.amount = 3
        end

        if reward.type ~= nil then
            table.insert(rewards, reward)
        end
    end

    return rewards
end

--[[ Obtain a random spell card ]]
function get_random_card(card_x, card_y)
    local item = ""
    local valid = false
    while not valid do
        local itemno = Random(1, #actions)
        local thisitem = actions[itemno]
        item = string.lower(thisitem.id)
        if thisitem.spawn_requires_flag ~= nil then
            local flag_name = thisitem.spawn_requires_flag
            local flag_status = HasFlagPersistent(flag_name)
            if flag_status then
                valid = true
            end
            if thisitem.spawn_probability == "0" then
                valid = false
            end
        else
            valid = true
        end
    end

    if item ~= "" then
        return item
    end

    return nil
end

--[[ Obtain a random utility spell card ]]
function get_random_utility_card(x, y)
    local item = ""
    local valid = false
    while not valid do
        local itemno = Random(1, #actions)
        local thisitem = actions[itemno]
        local itype = thisitem.type
        item = string.lower(thisitem.id)
        if itype == ACTION_TYPE_UTILITY or itype == ACTION_TYPE_MODIFIER then
            if thisitem.spawn_requires_flag ~= nil then
                local flag_name = thisitem.spawn_requires_flag
                local flag_status = HasFlagPersistent(flag_name)
                if flag_status then
                    valid = true
                end
                if thisitem.spawn_probability == "0" then
                    valid = false
                end
            else
                valid = true
            end
        else
            valid = false
        end
    end

    if item ~= "" then
        return item
    end

    return nil
end

--[[ Predict the contents of a potion or pouch ]]
function do_potion_get_contents(rand_x, rand_y, potion_filename, do_debug)
    if do_debug then
        print(("Potion %s: SetRandomSeed(%f, %f)"):format(potion_filename, rand_x, rand_y))
    end

    SetRandomSeed(rand_x, rand_y)
    local material = nil
    if not potion_filename or potion_filename == CONTAINER.POTION then
        dofile("data/scripts/items/potion.lua")
        -- luacheck: globals materials_standard materials_magic
        material = "water"

        if Random(0, 100) <= 75 then
            if Random(0, 100000) <= 50 then -- 0.05% chance of Healthium
                material = "magic_liquid_hp_regeneration"
            elseif Random(200, 100000) <= 250 then
                material = "purifying_powder"
            elseif Random(250, 100000) <= 500 then
                material = "magic_liquid_weakness"
            else
                local potion_material = random_from_array(materials_magic)
                material = potion_material.material
            end
        else
            local potion_material = random_from_array(materials_standard)
            material = potion_material.material
        end

        local year,month,day,temp1,temp2,temp3,jussi,mammi = GameGetDateAndTimeLocal()

        if (month == 5 and day == 1) or (month == 4 and day == 30) then
            if Random(0, 100) <= 20 then
                if Random(0, 5) <= 4 then
                    material = "sima"
                else
                    material = "beer"
                end
            end
        end

        if jussi and Random(0, 100) <= 9 then
            if Random(0, 3) <= 2 then
                material = "juhannussima"
            else
                material = "beer"
            end
        end

        if mammi and Random(0, 100) <= 8 then
            material = "mammi"
        end

        if month == 2 and day == 14 and Random(0, 100) <= 8 then
            material = "maic_liquid_charm"
        end
    elseif potion_filename == CONTAINER.POUCH then
        dofile("data/scripts/items/powder_stash.lua")
        -- luacheck: globals materials_standard materials_magic
        if Random(0, 100) <= 75 then
            local potion_material = random_from_array(materials_magic)
            material = potion_material.material
        else
            local potion_material = random_from_array(materials_standard)
            material = potion_material.material
        end
    elseif potion_filename == CONTAINER.POTION_SECRET then
        dofile("data/scripts/items/potion_secret.lua")
        -- luacheck: globals potions
        material = random_from_array(potions)
    elseif potion_filename == CONTAINER.POTION_RANDOM then
        local materials = nil
        if Random(0, 100) <= 50 then
            materials = CellFactory_GetAllLiquids(false)
        else
            materials = CellFactory_GetAllSands(false)
        end
        material = random_from_array(materials)
    else
        print_error(("At {%.2f,%.2f}: invalid potion %q"):format(
            rand_x, rand_y, potion_filename))
    end

    return material
end

--[[ Format rewards as a table of lines ]]
function format_rewards(rewards)
    local text = {}
    for idx, reward in ipairs(rewards) do
        local rtype = reward.type
        local rname = reward.name or ""
        local rentity = reward.entity or ""
        local rentities = reward.entities or {}
        local ramount = reward.amount or 0
        local name = rname:gsub("%$[a-z_]+", GameTextGetTranslatedOrNot)
        if name and name ~= "" then
            rname = name
        end

        local line = ""
        if rtype == REWARD.WAND then
            line = ("Wand: %s [%s]"):format(rname, rentity)
        elseif rtype == REWARD.CARD then
            for sidx, spell in ipairs(rentities) do
                line = ("Spell: %s"):format(spell)
            end
        elseif rtype == REWARD.GOLD then
            line = ("%d %s"):format(ramount, rname)
        elseif rtype == REWARD.CONVERT then
            line = ("Convert entity to %s"):format(rname)
        elseif rtype == REWARD.ITEM then
            line = ("Item: %s [%s]"):format(rname, rentity)
        elseif rtype == REWARD.ENTITY then
            line = ("Entity: %s [%s]"):format(rname, rentity)
        elseif rtype == REWARD.POTION then
            line = ("Potion: %s [%s]"):format(reward.content, rentity)
        elseif rtype == REWARD.POUCH then
            line = ("Pouch: %s [%s]"):format(rname, rentity)
        elseif rtype == REWARD.REROLL then
            line = ("Reroll %dx"):format(ramount)
        elseif rtype == REWARD.POTIONS then
            line = ("Potions: %s"):format(table.concat(reward.contents, ", "))
        elseif rtype == REWARD.GOLDRAIN then
            line = "Gold rain"
        elseif rtype == REWARD.SAMPO then
            line = "The Sampo"
        else
            line = ("Invalid reward %s"):format(rtype)
        end
        table.insert(text, line)
    end
    return text
end

-- vim: set ts=4 sts=4 sw=4:
