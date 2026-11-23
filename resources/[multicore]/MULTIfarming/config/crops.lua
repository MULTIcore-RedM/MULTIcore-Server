-- ============================================================
-- MULTIfarming :: crops
-- One entry per crop. The key is the crop id stored in the database (do not rename a crop
-- that is already planted on a live server).
--   seed       usable seed item (using it from the satchel starts planting)
--   item       what a ripe crop gives (MULTIcore item names)
--   min / max  how many of `item` one harvest gives
--   stages     the crop's looks in order: seedling, growing, ripe. `prop` is a game model,
--              `minutes` the real minutes of WATERED growth the crop spends in that stage
--              (the last stage is ripe and has no minutes). Without water a crop stops growing.
--   waterUse   water % used per minute of growth (a crop starts with Config.Planting.StartWater %)
--   seedBack   chance (%) of getting seeds back on harvest, and how many (min-max)
--
-- Every prop name below is in redm-info objects.lua (folder rdr_inst_crops.rpf for crp_*,
-- p_food.rpf for p_pumpkin / p_onion). Which size a crop model shows (small or tall) could not
-- be checked outside the game: those are marked UNVERIFIED.
-- ============================================================

Config.Crops = {
    corn = {
        seed = 'seed_corn', item = 'corn', min = 2, max = 4,
        stages = {
            { prop = 'crp_seedling_aa_sim',   minutes = 20 },
            { prop = 'crp_cornstalks_cb_sim', minutes = 30 },  -- UNVERIFIED: a shorter stalk than the ripe one?
            { prop = 'crp_cornstalks_ab_sim' },                -- UNVERIFIED: a full stalk with cobs?
        },
        waterUse = 1.5,
        seedBack = { chance = 40, min = 1, max = 2 },
    },
    potato = {
        seed = 'seed_potato', item = 'potato', min = 2, max = 4,
        stages = {
            { prop = 'crp_seedling_aa_sim',    minutes = 20 },
            { prop = 'crp_potato_sap_aa_sim',  minutes = 25 },  -- the game's potato sapling
            { prop = 'crp_potato_aa_sim' },
        },
        waterUse = 1.5,
        seedBack = { chance = 40, min = 1, max = 2 },
    },
    tomato = {
        seed = 'seed_tomato', item = 'tomato', min = 2, max = 4,
        stages = {
            { prop = 'crp_seedling_aa_sim',     minutes = 15 },
            { prop = 'crp_tomatoes_sap_aa_sim', minutes = 25 },  -- the game's tomato sapling
            { prop = 'crp_tomatoes_aa_sim' },
        },
        waterUse = 2.0,
        seedBack = { chance = 40, min = 1, max = 2 },
    },
    carrot = {
        seed = 'seed_carrot', item = 'horsecarrot', min = 2, max = 4,   -- horsecarrot is MULTIcore's 'Carrot'
        stages = {
            { prop = 'crp_seedling_aa_sim',    minutes = 15 },
            { prop = 'crp_carrots_sap_ba_sim', minutes = 20 },  -- the game's carrot sapling
            { prop = 'crp_carrots_ba_sim' },
        },
        waterUse = 1.5,
        seedBack = { chance = 40, min = 1, max = 2 },
    },
    onion = {
        seed = 'seed_onion', item = 'onion_vidalia', min = 2, max = 3,
        stages = {
            { prop = 'crp_seedling_aa_sim', minutes = 15 },
            { prop = 'crp_seedling_aa_sim', minutes = 20 },  -- no onion crop model in the game: the seedling stays
            { prop = 'p_oniongreen02x' },                    -- UNVERIFIED: a green onion food prop; may look small on the ground
        },
        waterUse = 1.0,
        seedBack = { chance = 40, min = 1, max = 2 },
    },
    wheat = {
        seed = 'seed_wheat', item = 'grain_wheat', min = 2, max = 4,
        stages = {
            { prop = 'crp_wheat_sap_ac',          minutes = 20 },  -- UNVERIFIED: a short green wheat sapling?
            { prop = 'crp_wheat_sap_long_aa_sim', minutes = 30 },  -- green wheat
            { prop = 'crp_wheat_dry_long_aa_sim' },                -- dry (ripe) wheat
        },
        waterUse = 1.0,
        seedBack = { chance = 50, min = 1, max = 2 },
    },
    pumpkin = {
        seed = 'seed_pumpkin', item = 'pumpkin', min = 1, max = 2,
        stages = {
            { prop = 'crp_seedling_aa_sim', minutes = 25 },
            { prop = 'crp_lettuce_aa_sim',  minutes = 35 },  -- UNVERIFIED: leafy plant standing in for the pumpkin vine
            { prop = 'p_pumpkin_01x' },
        },
        waterUse = 2.0,
        seedBack = { chance = 35, min = 1, max = 2 },
    },
    tobacco = {
        seed = 'seed_tobacco', item = 'tobacco_leaf', min = 2, max = 3,
        stages = {
            { prop = 'crp_tobaccoplant_aa_sim', minutes = 25 },  -- UNVERIFIED: smallest of the three tobacco plants?
            { prop = 'crp_tobaccoplant_ab_sim', minutes = 35 },
            { prop = 'crp_tobaccoplant_ac_sim' },
        },
        waterUse = 1.5,
        seedBack = { chance = 35, min = 1, max = 2 },
    },
}
