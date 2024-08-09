--[[ World Radar nearby radar ]]

dofile_once("data/scripts/lib/utilities.lua")
-- luacheck: globals get_magnitude vec_normalize get_players

RADAR_KIND_SPELL = 1
RADAR_KIND_ENTITY = 2
RADAR_KIND_MATERIAL = 3
RADAR_KIND_ITEM = 4

RADAR_ORB = 5

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
    [RADAR_ORB] = {
        "mods/world_radar/files/images/particles/radar_orb_faint.png",
        "mods/world_radar/files/images/particles/radar_orb_medium.png",
        "mods/world_radar/files/images/particles/radar_orb_strong.png",
    },
}

Radar = {
    config = {
        range = 400,
        range_faint = 400 * 0.8,
        range_medium = 400 * 0.5,
        indicator_distance = 40,
    },
    _config_next = {
        range = nil,
        range_faint = nil,
        range_medium = nil,
        indicator_distance = nil,
    },

    get = function(self, config_key)
        if self._config_next[config_key] ~= nil then
            return self._config_next[config_key]
        end
        return self.config[config_key]
    end,
}

function Radar:configure(values)
    local conf_table = self.config
    if values.next_only then
        conf_table = self._config_next
    end
    local conf_set = {}
    for conf_key, conf_value in pairs(values) do
        conf_set[conf_key] = conf_value
        if conf_table[conf_key] ~= nil then
            conf_table[conf_key] = conf_value
        end
    end
    -- Update range_faint and range_medium automatically if range is updated
    if conf_set.range then
        if not conf_set.range_faint then
            conf_table.range_faint = conf_table.range * 0.8
        end
        if not conf_set.range_medium then
            conf_table.range_medium = conf_table.range * 0.5
        end
    end
end

function Radar:draw_for_pos(ent_x, ent_y, kind)
    if not RADAR_SPRITE_MAP[kind] then
        print_error(("draw_for({%0.2f, %0.2f}, %d): invalid kind"):format(ent_x, ent_y, kind))
        return
    end

    local player = get_players()[1]
    local pos_x, pos_y = EntityGetTransform(player)
    if pos_x == nil or pos_y == nil then
        return -- Player isn't in the world
    end
    local dx, dy = ent_x - pos_x, ent_y - pos_y
    local distance = get_magnitude(dx, dy)

    local indicator_distance = self:get("indicator_distance")
    local range = self:get("range")
    local range_faint = self:get("range_faint") or range * 0.8
    local range_medium = self:get("range_medium") or range * 0.5
    for key, _ in pairs(self._config_next) do self._config_next[key] = nil end

    local nx, ny = vec_normalize(dx, dy)
    local ind_x = pos_x + nx * indicator_distance
    local ind_y = pos_y + ny * indicator_distance

    local sprite_list = RADAR_SPRITE_MAP[kind]

    local sprite
    if distance > range_faint then
        sprite = sprite_list[1]
    elseif distance > range_medium then
        sprite = sprite_list[2]
    else
        sprite = sprite_list[3]
    end
    if sprite then
        GameCreateSpriteForXFrames(sprite, ind_x, ind_y, true, 0, 0, 1, true)
    end
end

function Radar:draw_for(entid, kind)
    local ex, ey = EntityGetFirstHitboxCenter(entid)
    Radar:draw_for_pos(ex, ey, kind)
end

return Radar

-- vim: set ts=4 sts=4 sw=4:

