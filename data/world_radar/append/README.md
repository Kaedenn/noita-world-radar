# Adding Custom Objects

You can add new objects to both the enemy and item lists.

## Overview

Objects are added via appending to one of the files in this directory. For instance, the following would add custom enemies to the enemy list:

```lua
function OnModInit()
  ModLuaFileAppend(
    "data/world_radar/append/entity_list.lua",
    "mods/mymod/files/append/new_enemies.lua")
end
```

Your `new_enemies.lua` or `new_items.lua` files will generally have the following structure:

```lua
table.insert(ENTITY_EXTRA, {
  entity-definition...
})
table.insert(ENTITY_EXTRA, {
  entity-definition...
})
```

See below for the layout of these tables.

## Adding a New Enemy

Enemy objects have the following structure:

```lua
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
```

The fields are as follows:

* `id` - Unique ID identifying this entity. Generally this is just the entity filename without path or extension.
* `name` - Entity name, either localized or raw. Must be exactly `EntityGetName(entid)`.
* `path` - XML file path. Must be exactly `EntityGetFilename(entid)`.
* `icon` - Image used in the enemy list. Presently, this needs to be a string and be a PNG image. Animated images are not supported. Sprite-sheet images are supported, but that layout is not yet documented.
* `tags` - Comma-separated string of tags. Should be exactly `EntityGetTags(entid)`.
* `data` - Place for extra information displayed to the player.
  * `data.effects` - Table of effects this enemy spawns with. See `mods/world_radar/files/generated/entity_list.lua` for examples.
  * `data.health` - Floating-point health of the enemy. Actual enemy health is calculated by multiplying this by `MagicNumbersGetValue("GUI_HP_MULTIPLIER")`.
  * `data.herd` - One of the `herd` names.

## Adding a New Item

Item objects have the following structure:

```lua
  id = "mynewitem",
  name = "$item_mynewitem",
  path = "mods/mymod/items/mynewitem.xml",
  icon = "mods/mymod/images/items/mynewitem.png",
  tags = "item_physics,item_pickup",
```

The fields are as follows:

* `id` - Unique ID identifying this item. Generally this is just the item filename without path or extension.
* `name` - Item name, either localized or raw. Must be exactly `EntityGetName(entid)`.
* `path` - XML file path. Must be exactly `EntityGetFilename(entid)`.
* `icon` - Image used in the item list. Presently, this needs to be a string and be a PNG image. Animated images are not supported. Sprite-sheet images are supported, but that layout is not yet documented.
* `tags` - Comma-separated string of tags. Should be exactly `EntityGetTags(entid)`.

