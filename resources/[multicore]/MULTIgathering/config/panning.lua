-- ============================================================
-- MULTIgathering :: gold panning
-- Using the gold pan while standing in a river, creek, lake, pond or swamp (the game's own
-- water map: _GET_WATER_MAP_ZONE_AT_COORDS) washes the gravel. Gold is rare.
-- ============================================================

-- Reward table, rolled like Config.MiningRewards (each line on its own). No fallback:
-- most pans find nothing, as in life.
Config.PanningRewards = {
    { item = 'smallnugget',  chance = 10,  min = 1, max = 2 }, -- gold flakes and grains
    { item = 'mediumnugget', chance = 2,   min = 1, max = 1 },
    { item = 'largenugget',  chance = 0.3, min = 1, max = 1 },
}

-- Optional: places where panning pays, checked on the server (the server cannot see water).
-- Empty = any water the client finds. Example:
--   { id = 'flatneck', coords = vector3(x, y, z), radius = 150.0 },
Config.PanningZones = {}
