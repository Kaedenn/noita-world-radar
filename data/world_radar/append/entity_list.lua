--[[
-- Custom Entity List

To add your own entities, append those to this file
  ModLuaAppend("data/world_radar/append/entity_list.lua", "mods/mymod/entities.lua")

Content of entities.lua:

table.insert(ENTITY_EXTRA, {
  id = "mynewenemy",
  name = "$animal_mynewenemy",
  path = "mods/mymod/animals/mynewenemy.xml",
  icon = "mods/mymod/images/animals/mynewenemy.png",
  tags = "enemy,mortal,hittable,homing_target",
  data = {
    effects = {},
    health = 100,
    herd = "ghost",
  },
})

--]]

ENTITY_EXTRA = {}

