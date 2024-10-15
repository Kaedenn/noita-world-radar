--[[
-- Custom Item List

To add your own items, append those to this file
  ModLuaAppend("data/world_radar/append/item_list.lua", "mods/mymod/items.lua")

Content of items.lua:

table.insert(ITEMS_EXTRA, {
  id = "mynewitem",
  name = "$item_mynewitem",
  path = "mods/mymod/items/mynewitem.xml",
  icon = "mods/mymod/images/items/mynewitem.png",
  tags = "item_physics,item_pickup",
})

--]]

ITEM_EXTRA = {}

