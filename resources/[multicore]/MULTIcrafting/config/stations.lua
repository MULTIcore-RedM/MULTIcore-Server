-- ============================================================
-- MULTIcrafting :: fixed stations (kitchens, workbenches)
--   id       unique name
--   type     a key of Config.StationTypes (cooking, gunsmith, blacksmith, campfire ...)
--   coords   where the player stands to craft (vector3)
--   label    optional plain text name for the menu title (nil = the type's name)
--   radius   optional: how close the player must be (nil = the type's distance)
--   job      optional: only this MULTIcore job (or a list) may use the station; grade = lowest grade
--   blip     optional: true = a map blip (Config.Blips.Enabled must be on); blipSprite = own sprite
--   enabled  optional: false switches the station off
--
-- The default spots are the bar counters of the saloons and the counters of the gunsmiths
-- (the same points MULTIstores uses, from RSG v2's rsg-shops config). Move them to a kitchen
-- stove or a back-room bench on your map if you like. Smithies need no entry: the anvils and
-- forges already in the world are blacksmith stations (Config.StationTypes.blacksmith.worldProps).
-- ============================================================

Config.Stations = {
    -- saloon kitchens
    { id = 'kitchen_valentine',  type = 'cooking', coords = vector3(-313.44, 806.14, 118.98) },
    { id = 'kitchen_rhodes',     type = 'cooking', coords = vector3(1340.25, -1374.71, 80.48) },
    { id = 'kitchen_bastille',   type = 'cooking', coords = vector3(2639.87, -1226.13, 53.38) },
    { id = 'kitchen_blackwater', type = 'cooking', coords = vector3(-817.69, -1319.29, 43.68) },
    { id = 'kitchen_tumbleweed', type = 'cooking', coords = vector3(-5518.50, -2906.52, -1.75) },
    { id = 'kitchen_annesburg',  type = 'cooking', coords = vector3(2964.36, 1358.28, 44.86) },
    { id = 'kitchen_oldlight',   type = 'cooking', coords = vector3(2948.17, 528.08, 45.34) },

    -- gunsmith benches (the recipes there are for the gunsmith job; set job = 'gunsmith' to lock the bench itself)
    { id = 'bench_gunsmith_valentine',  type = 'gunsmith', coords = vector3(-281.17, 778.94, 119.50) },
    { id = 'bench_gunsmith_rhodes',     type = 'gunsmith', coords = vector3(1322.31, -1323.02, 77.89) },
    { id = 'bench_gunsmith_saintdenis', type = 'gunsmith', coords = vector3(2717.14, -1286.90, 49.64) },
    { id = 'bench_gunsmith_tumbleweed', type = 'gunsmith', coords = vector3(-5506.41, -2963.95, -0.64) },
    { id = 'bench_gunsmith_annesburg',  type = 'gunsmith', coords = vector3(2948.42, 1319.44, 44.82) },

    -- example of a job-locked blacksmith bench at your own spot:
    -- { id = 'bench_smith_valentine', type = 'blacksmith', coords = vector3(0.0, 0.0, 0.0), job = 'blacksmith', grade = 0, blip = true },
}
