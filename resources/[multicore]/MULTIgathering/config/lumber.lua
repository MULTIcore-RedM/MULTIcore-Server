-- ============================================================
-- MULTIgathering :: lumber zones, trees and what a chop gives
-- A zone is a stretch of forest where chopping pays (the server checks the player is inside).
-- Each finished chop uses one charge of the zone; an empty zone is "cut out" until it refills.
--   id             unique id (letters, digits, _)
--   zone           locale key zone_<zone> for the blip and notes
--   coords         centre of the zone
--   radius         size of the zone (metres, flat distance)
--   charges        chops before the zone is cut out
--   respawnMinutes minutes until a cut-out zone is full again
--   rewards        a key of Config.LumberRewards
-- Zone centres: the log sale points of rsg-lumberjack (RSG v2, GPL v3, see CREDITS.md),
-- which sit at the lumber camps; the radius makes them forest zones.
-- ============================================================

Config.LumberZones = {
    { id = 'strawberry',  zone = 'strawberry', coords = vector3(-1808.22, -596.15, 154.95), radius = 300.0, charges = 60, respawnMinutes = 30, rewards = 'forest' },
    { id = 'bigvalley',   zone = 'bigvalley',  coords = vector3(-1395.34, -223.84, 100.86), radius = 300.0, charges = 60, respawnMinutes = 30, rewards = 'forest' },
    { id = 'scarlett',    zone = 'scarlett',   coords = vector3(1053.37, -1125.14, 67.89),  radius = 300.0, charges = 60, respawnMinutes = 30, rewards = 'forest' },
    { id = 'roanoke',     zone = 'roanoke',    coords = vector3(2870.63, 1468.58, 68.03),   radius = 300.0, charges = 60, respawnMinutes = 30, rewards = 'forest' },
}

-- Reward tables, rolled like Config.MiningRewards (each line on its own, `fallback` if none hits).
Config.LumberRewards = {
    forest = {
        { item = 'wood',       chance = 100, min = 2, max = 4 },
        { item = 'tree_seeds', chance = 5,   min = 1, max = 1 },
        fallback = { item = 'wood', amount = 1 },
    },
}

-- Tree models MULTItarget offers "Chop" on (Config.Lumber.Interaction 'target').
-- From rsg-lumberjack's Config.Trees (RSG v2, GPL v3): the common forest trees.
Config.TreeModels = {
    'p_tree_poplar_01', 'p_tree_poplar_02', 'p_tree_riv_poplar_01', 'p_tree_riv_poplar_02',
    'p_tree_willow_01', 'p_tree_willow_02',
    'p_tree_cedar_03b_snow', 'p_tree_cedar_decor_01', 'p_tree_cedar_decor_02',
    'p_tree_douglasfir_01', 'p_tree_douglasfir_02', 'p_tree_douglasfir_05',
    'p_tree_douglasfir_snow_01', 'p_tree_douglasfir_snow_02', 'p_tree_douglasfir_snow_03', 'p_tree_douglasfir_snow_04', 'p_tree_douglasfir_snow_05',
    'p_tree_lodgepole_01', 'p_tree_lodgepole_02', 'p_tree_lodgepole_03', 'p_tree_lodgepole_04', 'p_tree_lodgepole_05',
    'p_tree_lodgepole_06', 'p_tree_lodgepole_07', 'p_tree_lodgepole_snow_01', 'p_tree_lodgepole_snow_02',
    'p_tree_longleafpine_01', 'p_tree_longleafpine_02', 'p_tree_longleafpine_03', 'p_tree_longleafpine_04',
    'p_tree_pine_ponderosa_01', 'p_tree_pine_ponderosa_02', 'p_tree_pine_ponderosa_03', 'p_tree_pine_ponderosa_04',
    'p_tree_pine_ponderosa_05', 'p_tree_pine_ponderosa_06', 'p_tree_pine_ponderosa_07',
    'p_tree_whitepine_01', 'p_tree_whitepine_02', 'p_tree_whitepine_03', 'p_tree_whitepine_04', 'p_tree_whitepine_05',
    'p_tree_whitepine_06', 'p_tree_whitepine_07', 'p_tree_whitepine_08', 'p_tree_whitepine_09', 'p_tree_whitepine_10',
    'p_tree_pine_dead_01', 'p_tree_pine_dead_02', 'p_tree_fallen_pine_01', 'p_tree_fallen_pine_02',
    'p_tree_maple_02', 'p_tree_maple_03', 'p_tree_maple_03_lg', 'p_tree_maple_03_md', 'p_tree_maple_04_md', 'p_tree_maple_05_lg',
    'p_tree_maple_s_01', 'p_tree_maple_s_02', 'p_tree_maple_s_03', 'p_tree_maple_s_04', 'p_tree_riv_maple_01', 'p_tree_riv_maple_04',
    'p_tree_blue_oak_01', 'p_tree_cottonwood_01', 'p_tree_cottonwood_02', 'p_tree_cottonwood_03', 'p_tree_cottonwood_04',
    'p_tree_engoak_01', 'p_tree_engoak_01_lg', 'p_tree_engoak_02', 'p_tree_liveoak_01', 'p_tree_oak_01',
    'p_tree_white_oak_01', 'p_tree_white_oak_02',
    'p_tree_redwood_05', 'p_tree_redwood_05_lg', 'p_tree_redwood_05_md', 'p_tree_redwood_05_sm',
    'p_tree_baldcypress_01a', 'p_tree_baldcypress_02', 'p_tree_baldcypress_03', 'p_tree_baldcypress_05', 'p_tree_baldcypress_07',
    'p_tree_hickory_01', 'p_tree_hickory_02', 'p_tree_mesquite_01',
    'rdr2_tree_beech', 'rdr2_tree_riverbirch', 'rdr2_tree_sycamore', 'rdr2_tree_utahjuniper',
}
