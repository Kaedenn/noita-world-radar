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

ENTITY_EXTRA = {
  { -- Meditation Cube
    id = "teleport_meditation_cube",
    name = "Meditation Cube",
    path = "data/entities/buildings/teleport_meditation_cube.xml",
    icon = "data/ui_gfx/gun_actions/summon_portal.png",
    tags = "",
    data = {
      effects = {},
      health = 0,
      herd = "",
    },
  },
  { -- Propane Tank
    id = "physics_propane_tank",
    name = "Propane Tank",
    path = "data/entities/props/physics_propane_tank.xml",
    icon = "data/props_gfx/propane_tank.png",
    tags = "mortal,hittable,teleportable_NOT,prop,prop_physics",
  },
}

