--[[ Treasure chest content prediction ]]

dofile_once("data/scripts/lib/utilities.lua")
dofile_once("data/scripts/gun/gun_actions.lua")
dofile_once("data/scripts/game_helpers.lua")
-- luacheck: globals actions

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

    -- Offsets taken from data/scripts/items/chest_random.lua
    rand_x = rand_x + 509.7
    rand_y = rand_y + 683.1

    SetRandomSeed(rand_x, rand_y)
    local rewards = do_chest_get_rewards(x, y, entity_id, rand_x, rand_y, false)

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
            reward.name = "bomb"
            reward.entity = "data/entities/projectiles/bomb_small.xml"
        elseif rnd <= 40 then -- Gold
            reward.type = "item"
            reward.name = "gold"
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
                reward.amount = reward.amount + tamount * 50
                if Random(0, 100) > 50 then
                    tamount = Random(1, 3)
                    reward.amount = reward.amount + tamount * 200
                end
                if Random(0, 100) > 80 then
                    tamount = Random(1, 3)
                    reward.amount = reward.amount + tamount * 200
                end
            end
        elseif rnd <= 50 then -- Potion
            reward.type = "potion"
            reward.name = "potion"
            rnd = Random(0, 100)
            if rnd <= 94 then
                reward.type = "potion"
                reward.name = "potion"
                reward.entity = "data/entities/items/pickup/potion.xml"
            elseif rnd <= 98 then
                reward.type = "pouch"
                reward.name = "powder stash"
                reward.entity = "data/entities/items/pickup/powder_stash.xml"
            elseif rnd <= 100 then
                rnd = Random(0, 100)
                if rnd <= 98 then
                    reward.type = "potion"
                    reward.name = "secret potion"
                    reward.entity = "data/entities/items/pickup/potion_secret.xml"
                elseif rnd <= 100 then
                    reward.type = "potion"
                    reward.name = "random material potion"
                    reward.entity = "data/entities/items/pickup/potion_random_material.xml"
                end
            end
        elseif rnd <= 54 then -- Spell refresh (or mimic)
            rnd = Random(0, 100)
            if rnd <= 98 then
                reward.type = "item"
                reward.name = "spell refresh"
                reward.entity = "data/entities/items/pickup/spell_refresh.xml"
            else
                reward.type = "entity"
                reward.name = "spell refresh mimic"
                reward.entity = "data/entities/animals/illusions/shaman_wind.xml"
            end
        elseif rnd <= 60 then -- Misc items
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
                    if GameHasFlagRun("greed_curse") and not GameHasFlagRun("greed_curse_gone") then
                        reward.name = "greed die"
                        reward.entity = "data/entities/items/pickup/physics_greed_die.xml"
                    else
                        reward.name = "die"
                        reward.entity = "data/entities/items/pickup/physics_die.xml"
                    end
                else
                    reward.type = "potion"
                    reward.name = "potion"
                    reward.entity = "data/entities/items/pickup/potion.xml"
                end
            elseif opt == "runestone" then
                local r_opts = {"laser", "fireball", "lava", "slow", "null", "disc", "metal"}
                rnd = Random(1, #r_opts)
                local r_opt = r_opts[rnd]
                reward.type = "item"
                reward.name = r_opt .. " runestone"
                reward.entity = "data/entities/items/pickup/runestones/runestone_" .. r_opt .. ".xml"
            elseif opt == "orb" then
                reward.type = "item"
                reward.name = "shiny orb"
                reward.entity = "data/entities/items/pickup/physics_gold_orb.xml"
                if GameHasFlagRun("greed_curse") and not GameHasFlagRun("greed_curse_gone") then
                    reward.name = "greedy shiny orb"
                    reward.entity = "data/entities/items/pickup/physics_gold_orb_greed.xml"
                end
            else
                reward.type = "item"
                reward.name = string.match(opt, "([^/]*)%.xml$")
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
            rnd = Random(0,100)

            reward.type = "wand"
            if rnd <= 25 then
                reward.name = "level 1 wand"
                reward.entity = "data/entities/items/wand_level_01.xml"
            elseif rnd <= 50 then
                reward.name = "level 1 wand (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_01.xml"
            elseif rnd <= 75 then
                reward.name = "level 2 wand"
                reward.entity = "data/entities/items/wand_level_02.xml"
            elseif rnd <= 90 then
                reward.name = "level 2 wand (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_02.xml"
            elseif rnd <= 96 then
                reward.name = "level 3 wand"
                reward.entity = "data/entities/items/wand_level_03.xml"
            elseif rnd <= 98 then
                reward.name = "level 3 wand (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_03.xml"
            elseif rnd <= 99 then
                reward.name = "level 4 wand"
                reward.entity = "data/entities/items/wand_level_04.xml"
            elseif rnd <= 100 then
                reward.name = "level 4 wand (unshuffle)"
                reward.entity = "data/entities/items/wand_unshuffle_04.xml"
            end
        elseif rnd <= 95 then -- Heart
            rnd = Random(0, 100)
            reward.type = "item"
            if rnd <= 88 then
                reward.name = "heart"
                reward.entity = "data/entities/items/pickup/heart.xml"
            elseif rnd <= 89 then
                reward.type = "entity"
                reward.name = "heart mimic"
                reward.entity = "data/entities/animals/illusions/dark_alchemist.xml"
            elseif rnd <= 99 then
                reward.name = "better heart"
                reward.entity = "data/entities/items/pickup/heart_better.xml"
            else
                reward.name = "full heal"
                reward.entity = "data/entities/items/pickup/heart_fullhp.xml"
            end
        elseif rnd <= 98 then -- Converts the chest to gold
            reward.type = "gold"
            reward.name = "convert to gold"
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

-- vim: set ts=4 sts=4 sw=4:

