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
-- Reward types:
--  entity      Spawn a simple entity given by the path
--  gold        Spawn gold nuggets; amount has the total value
--  wand        Spawn a wand; entity is the path to the wand XML
--  card        Spawn one or more spell(s); amount=number of spells,
--              entities={spell IDs (eg. BOMB, X_RAY, etc.)}
--  item        Spawn a single item
--  potion      Spawn a single potion
--  pouch       Spawn a material pouch
--  reroll      Re-roll the drop table; amount=number of times
--  convert     Convert the treasure chest sprite to gold dust
--  potions     (Greater Treasure Chest only) Spawn multiple potions;
--              amount=number of potions, entities={potion XMLs}
--  goldrain    (Greater Treasure Chest only) Start a gold rain event
--  sampo       (Greater Treasure Chest only) The Sampo
--
-- The amount of gold dropped by gold rain cannot be predicted because the
-- random seed uses the newly-created entity ID. Because chest prediction
-- does not spawn entities, this can't be done.
--
--]]

--[[
dofile("mods/world_radar/files/utility/treasure_chest.lua")
cx, cy = 0, 0 -- Replace with your location
SetRandomSeed(cx, cy)
print_rewards(do_chest_get_rewards_super(cx, cy, 0, cx, cy, false))
--]]

-- TODO: Add potion contents (they use the same chest spawn coords)
-- FIXME: Fix gold amounts being inaccurate for normal treasure chests
-- TODO: Add utility boxes

dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/gun/gun_actions.lua")
dofile_once("data/scripts/game_helpers.lua")
-- luacheck: globals actions

REWARD_TYPE_ENTITY = "entity"
REWARD_TYPE_GOLD = "gold"
REWARD_TYPE_WAND = "wand"
REWARD_TYPE_CARD = "card"
REWARD_TYPE_ITEM = "item"
REWARD_TYPE_POTION = "potion"
REWARD_TYPE_POUCH = "pouch"
REWARD_TYPE_REROLL = "reroll"
REWARD_TYPE_CONVERT = "convert"
REWARD_TYPE_POTIONS = "potions"
REWARD_TYPE_GOLDRAIN = "goldrain"
REWARD_TYPE_SAMPO = "sampo"

--[[ Obtain the rewards that would be dropped by the treasure chest ]]
function chest_get_rewards(entity_id)
    local x, y = EntityGetTransform(entity_id)
    local rand_x, rand_y = x, y
    if rand_x == nil or rand_y == nil then
        error(("Failed to get location of entity %s"):format(tostring(entity_id)))
    end

    local position_comp = EntityGetFirstComponent(entity_id, "PositionSeedComponent")
    if position_comp then
        rand_x = tonumber(ComponentGetValue(position_comp, "pos_x"))
        rand_y = tonumber(ComponentGetValue(position_comp, "pos_y"))
    end

    local fname = EntityGetFilename(entity_id)
    local rewards = {}
    if fname:match("chest_random_super") then
        SetRandomSeed(rand_x, rand_y)
        rewards = do_chest_get_rewards_super(x, y, entity_id, rand_x, rand_y, false)
    elseif fname:match("chest_random") then
        -- Offsets taken from data/scripts/items/chest_random.lua
        rand_x = rand_x + 509.7
        rand_y = rand_y + 683.1

        SetRandomSeed(rand_x, rand_y)
        rewards = do_chest_get_rewards(x, y, entity_id, rand_x, rand_y, false)
    else
        local pos_str = ("(%f,%f)"):format(x, y)
        local spawn_str = ("(%d,%d)"):format(rand_x, rand_y)
        print_error(("Entity %d at %s (from %s) isn't a treasure chest"):format(
            entity_id, pos_str, spawn_str))
    end

    return rewards
end

--[[ Obtain the chest rewards for the given entity ]]
function do_chest_get_rewards(x, y, entity_id, rand_x, rand_y, set_rand_)
    local set_rand = false
    if set_rand_ ~= nil then set_rand = set_rand_ end
    if set_rand then
        SetRandomSeed(GameGetFrameNum(), x + y + entity_id)
    end

    local rewards = {}
    local count = 1
    while count > 0 do
        count = count - 1
        local rnd = Random(1, 100)

        local reward = {type=nil, name=nil, entity=nil, amount=nil}
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
            reward.amount = reward.amount + amount * 10

            rnd = Random(0, 100)
            if rnd > 30 and rnd <= 80 then
                reward.amount = 50
            elseif rnd <= 95 then
                reward.amount = 200
            elseif rnd <= 99 then
                reward.amount = 1000
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
function do_chest_get_rewards_super(x, y, entity_id, rand_x, rand_y, set_rand_)
    local set_rand = false
    if set_rand_ ~= nil then set_rand = set_rand_ end
    if set_rand then
        SetRandomSeed(GameGetFrameNum(), x + y + entity_id)
    end

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
            reward.type = "entity"
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

--[[ Obtain a random spell card.
--
-- TODO: Allow for multiple returns in case flag_name is unset.
--]]
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

    if string.len(item) > 0 then
        return item
    end

    return nil
end

--[[ Generate text for use in Panel:p ]]
function format_rewards(rewards)
    local text = {}
    for idx, reward in ipairs(rewards) do
        if reward.type == "wand" then
            table.insert(text, ("Wand: %s [%s]"):format(reward.name, reward.entity))
        elseif reward.type == "card" then
            for sidx, spell in ipairs(reward.entities) do
                table.insert(text, ("Spell: %s"):format(spell))
            end
        elseif reward.type == "gold" then
            table.insert(text, ("%d %s"):format(reward.amount, reward.name))
        elseif reward.type == "convert" then
            table.insert(text, ("Convert entity to %s"):format(reward.name))
        elseif reward.type == "item" then
            table.insert(text, ("Item: %s [%s]"):format(reward.name, reward.entity))
        elseif reward.type == "entity" then
            table.insert(text, ("Entity: %s [%s]"):format(reward.name, reward.entity))
        elseif reward.type == "potion" then
            table.insert(text, ("Potion: %s [%s]"):format(reward.name, reward.entity))
        elseif reward.type == "pouch" then
            table.insert(text, ("Pouch: %s [%s]"):format(reward.name, reward.entity))
        elseif reward.type == "reroll" then
            table.insert(text, ("Reroll %dx"):format(reward.amount))
        elseif reward.type == "potions" then
            for _, potion in ipairs(reward.entities) do
                table.insert(text, ("Potion: %s"):format(potion))
            end
        elseif reward.type == "goldrain" then
            table.insert(text, "Gold rain")
        elseif reward.type == "sampo" then
            table.insert(text, "The Sampo")
        else
            table.insert(text, ("Invalid reward %s"):format(reward.type))
        end
    end
    return text
end

--[[ Print the rewards via the given imgui object (TODO) ]]
function print_rewards(rewards, imgui)
    local text = format_rewards(rewards)
    for _, reward in ipairs(text) do
        GamePrint(reward)
    end
end

-- vim: set ts=4 sts=4 sw=4:
