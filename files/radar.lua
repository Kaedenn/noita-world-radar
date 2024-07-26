--[[ World Radar nearby radar ]]

dofile_once("data/scripts/lib/utilities.lua")
-- luacheck: globals get_magnitude vec_normalize

RADAR_KIND_SPELL = 1
RADAR_KIND_ENTITY = 2
RADAR_KIND_MATERIAL = 3
RADAR_KIND_ITEM = 4

RADAR_SPRITE_MAP = {
    [RADAR_KIND_SPELL] = {
        "mods/world_radar/files/images/particles/radar_spell_faint.png",
        "mods/world_radar/files/images/particles/radar_spell_medium.png",
        "mods/world_radar/files/images/particles/radar_spell_strong.png",
    },
    [RADAR_KIND_ENTITY] = {
        "mods/world_radar/files/images/particles/radar_entity_faint.png",
        "mods/world_radar/files/images/particles/radar_entity_medium.png",
        "mods/world_radar/files/images/particles/radar_entity_strong.png",
    },
    [RADAR_KIND_MATERIAL] = {
        "mods/world_radar/files/images/particles/radar_material_faint.png",
        "mods/world_radar/files/images/particles/radar_material_medium.png",
        "mods/world_radar/files/images/particles/radar_material_strong.png",
    },
    [RADAR_KIND_ITEM] = {
        "mods/world_radar/files/images/particles/radar_item_faint.png",
        "mods/world_radar/files/images/particles/radar_item_medium.png",
        "mods/world_radar/files/images/particles/radar_item_strong.png",
    },
}

Radar = {
    config = {
        range = 400,
        range_faint = 400 * 0.8,
        range_medium = 400 * 0.5,
        indicator_distance = 40,
    },
}

function Radar:configure(values)
    for conf_key, conf_value in pairs(values) do
        if self.config[conf_key] ~= nil then
            self.config[conf_key] = conf_value
        end
    end
end

function Radar:draw_for(entid, kind)
    if not RADAR_SPRITE_MAP[kind] then
        print_error(("draw_for(%d, %d): invalid kind"):format(entid, kind))
        return
    end
    local player = get_players()[1]
    local pos_x, pos_y = EntityGetTransform(player)
    if pos_x == nil or pos_y == nil then
        return -- Player isn't in the world
    end
    local ex, ey = EntityGetFirstHitboxCenter(entid)
    local dx, dy = ex - pos_x, ey - pos_y
    local distance = get_magnitude(dx, dy)

    local nx, ny = vec_normalize(dx, dy)
    local ind_x = pos_x + nx * self.config.indicator_distance
    local ind_y = pos_y + ny * self.config.indicator_distance

    local sprite_base
    if distance > self.config.range_faint then
        sprite_base = 1
    elseif distance > self.config.range_medium then
        sprite_base = 2
    else
        sprite_base = 3
    end

    local sprite = RADAR_SPRITE_MAP[kind][sprite_base]
    if sprite then
        GameCreateSpriteForXFrames(sprite, ind_x, ind_y, true, 0, 0, 1, true)
    end
end

return Radar

-- vim: set ts=4 sts=4 sw=4:

