-- ============================================================
-- MULTIconsumables :: animations and hand props
-- Every name here was looked up (see README "Where the game names come from"):
--   [rsg-consume]  used by RSG v2's rsg-consume (GPL v3), a working script
--   [redm-info]    listed in redm-info (animations.lua, Scenarios.lua, objects.lua)
--   [server]       used by a working script on the owner's test server (read only)
-- Anything not in redm-info is marked UNVERIFIED and must be checked in game.
--
-- kinds:
--   anim      TaskPlayAnim(dict, clip) with an optional prop attached to a bone; `enter` plays first
--   scenario  TaskStartScenarioInPlace(name) for `ms` (the game brings its own prop), then ClearPedTasks
--   stew      bowl + spoon item interaction (rsg-consume's Stew)
--   coffee    mug item interaction (rsg-consume's Hotdrinks)
-- An item's own `prop` (config/consumables.lua) replaces the anim's default prop.
-- mounted = what to do in the saddle: 'anim' (same animation, upper body), 'interaction' (the
--   item interaction below), false = no animation, the item is used straight away.
-- ============================================================

Config.Anims = {
    -- eating with one hand (bread, meat, fish) [rsg-consume: Eat]
    eat = {
        kind = 'anim', ms = 5000,
        dict = 'mech_inventory@eating@multi_bite@sphere_d8-2_sandwich', clip = 'quick_left_hand', flag = 31, -- [rsg-consume] (dict not in redm-info: UNVERIFIED there, works in rsg-consume)
        prop = 'p_bread_14_ab_s_a',                                              -- [rsg-consume][redm-info objects.lua]
        bone = 'SKEL_L_Finger01', pos = { 0.04, -0.03, -0.01 }, rot = { 0.0, 19.0, 46.0 }, -- [rsg-consume]
        mounted = 'anim',
    },
    -- eating from a can [rsg-consume: Eatcanned]
    eat_canned = {
        kind = 'anim', ms = 2750,
        dict = 'mech_inventory@eating@canned_food@cylinder@d8-2_h10-5', clip = 'left_hand', flag = 31, -- [rsg-consume] (not in redm-info: UNVERIFIED there)
        prop = 's_canrigapricots01x',                                            -- [rsg-consume][redm-info objects.lua]
        bone = 'SKEL_L_Finger00', pos = { 0.10, -0.03, 0.02 }, rot = { 20.0, -70.0, -20.0 }, -- [rsg-consume]
        mounted = 'interaction',
        interaction = { anim = 'EAT_CANNED_FOOD_CYLINDER@D8-2_H10-5_QUICK_LEFT' }, -- [rsg-consume] START_TASK_ITEM_INTERACTION
    },
    -- drinking from a bottle (beer, spirits, wine, water, milk, medicine) [rsg-consume: Drink]
    drink = {
        kind = 'anim', ms = 4500,
        dict = 'mech_inventory@drinking@bottle_cylinder_d1-3_h30-5_neck_a13_b2-5', -- [rsg-consume] (not in redm-info: UNVERIFIED there)
        enter = 'uncork', enterMs = 500, clip = 'chug_a', flag = 31,            -- [rsg-consume]
        prop = 'p_bottlebeer01a',                                                -- [rsg-consume][redm-info objects.lua]
        bone = 'PH_R_HAND', pos = { 0.0, 0.0, 0.04 }, rot = { 0.0, 0.0, 0.0 },   -- [rsg-consume]
        mounted = 'interaction',
        interaction = {                                                          -- [rsg-consume] _TASK_ITEM_INTERACTION_2
            gxt = 1737033966, propId = 'p_bottleJD01x_ph_r_hand',
            state = 'DRINK_Bottle_Cylinder_d1-55_H18_Neck_A8_B1-8_QUICK_RIGHT_HAND', ms = 4000,
        },
    },
    -- stew from a bowl with a spoon [rsg-consume: Stew]
    stew = {
        kind = 'stew', ms = 15000,                                               -- ms = longest wait for the interaction to end
        bowl = 'p_bowl04x_stew', spoon = 'p_spoon01x',                           -- [rsg-consume][redm-info objects.lua]
        mounted = false,
    },
    -- hot coffee from a mug [rsg-consume: Hotdrinks]
    coffee = {
        kind = 'coffee', ms = 5000,
        mug = 'P_MUGCOFFEE01X',                                                  -- [rsg-consume][redm-info objects.lua: p_mugcoffee01x]
        mounted = false,
    },
    -- cigarette: the game's smoking scenario brings its own cigarette [redm-info Scenarios.lua]
    smoke_cigarette = {
        kind = 'scenario', ms = 20000, scenario = 'WORLD_HUMAN_SMOKE',
        mounted = false,
    },
    -- cigar [redm-info Scenarios.lua]
    smoke_cigar = {
        kind = 'scenario', ms = 25000, scenario = 'WORLD_HUMAN_SMOKE_CIGAR',
        mounted = false,
    },
    -- pipe: standing smoking animation with a pipe in the right hand
    smoke_pipe = {
        kind = 'anim', ms = 15000,
        dict = 'amb_rest@world_human_smoking@male_b@idle_a', clip = 'idle_a', flag = 31, -- dict [redm-info]; clip [server] UNVERIFIED in redm-info (no clip lists)
        prop = 'p_pipe01x',                                                      -- [redm-info objects.lua]
        bone = 'SKEL_R_Finger13', pos = { 0.005, -0.045, 0.0 }, rot = { -170.0, 10.0, -15.0 }, -- [server] offsets, check in game
        mounted = false,
    },
    -- chewing tobacco: take a pinch from the tin
    chew = {
        kind = 'anim', ms = 6000,
        dict = 'amb_misc@world_human_chew_tobacco@male_a@stand_enter', clip = 'enter_back', flag = 31, -- UNVERIFIED (not in redm-info; [server])
        prop = 's_tobaccotin01x',                                                -- [redm-info objects.lua]
        bone = 'SKEL_R_Finger13', pos = { 0.0, -0.05, 0.02 }, rot = { 30.0, 180.0, 0.0 }, -- [server] offsets, check in game
        mounted = false,
    },
    -- drinking from a canteen [rsg-canteen]
    canteen = {
        kind = 'anim', ms = 5000,
        dict = 'amb_rest_drunk@world_human_drinking@female_a@idle_a', clip = 'idle_a', flag = 31, -- [rsg-canteen] (not in redm-info: UNVERIFIED there)
        prop = 'p_cs_canteen_hercule',                                       -- [rsg-canteen][redm-info objects.lua]
        bone = 'SKEL_R_HAND', pos = { 0.10, 0.09, -0.05 }, rot = { 306.0, 18.0, 0.0 }, -- [rsg-canteen]
        mounted = 'anim',
    },
    -- filling a canteen at a river or lake (redm-info Scenarios.lua)
    refill = {
        kind = 'scenario', ms = 6000, scenario = 'WORLD_HUMAN_CROUCH_INSPECT',
        mounted = false,
    },
}
