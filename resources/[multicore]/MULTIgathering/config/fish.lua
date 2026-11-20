-- ============================================================
-- MULTIgathering :: fish
-- Which item each fish gives, by the game's fish model (species and size).
-- The item names are MULTIcore's fish items (one per model, from RSG v2's items list);
-- each caught fish carries info.weight (kg).
--   item     item given (must exist; a missing one is registered at start)
--   min/max  weight range in kg; the client's weight is kept inside it (a forged weight cannot go higher)
-- Models checked against femga peds_list.lua. Weight ranges follow rsg-fishing's
-- weight classes (RSG v2, GPL v3, see CREDITS.md); the large-fish class is MULTIcore's own.
-- ============================================================

Config.Fish = {
    a_c_fishbluegil_01_sm        = { item = 'a_c_fishbluegil_01_sm',        min = 0.12, max = 0.45 },
    a_c_fishbluegil_01_ms        = { item = 'a_c_fishbluegil_01_ms',        min = 0.40, max = 0.75 },
    a_c_fishbullheadcat_01_sm    = { item = 'a_c_fishbullheadcat_01_sm',    min = 0.12, max = 0.45 },
    a_c_fishbullheadcat_01_ms    = { item = 'a_c_fishbullheadcat_01_ms',    min = 0.40, max = 0.75 },
    a_c_fishchainpickerel_01_sm  = { item = 'a_c_fishchainpickerel_01_sm',  min = 0.12, max = 0.45 },
    a_c_fishchainpickerel_01_ms  = { item = 'a_c_fishchainpickerel_01_ms',  min = 0.40, max = 0.75 },
    a_c_fishperch_01_sm          = { item = 'a_c_fishperch_01_sm',          min = 0.12, max = 0.45 },
    a_c_fishperch_01_ms          = { item = 'a_c_fishperch_01_ms',          min = 0.40, max = 0.75 },
    a_c_fishredfinpickerel_01_sm = { item = 'a_c_fishredfinpickerel_01_sm', min = 0.12, max = 0.45 },
    a_c_fishredfinpickerel_01_ms = { item = 'a_c_fishredfinpickerel_01_ms', min = 0.40, max = 0.75 },
    a_c_fishrockbass_01_sm       = { item = 'a_c_fishrockbass_01_sm',       min = 0.12, max = 0.45 },
    a_c_fishrockbass_01_ms       = { item = 'a_c_fishrockbass_01_ms',       min = 0.40, max = 0.75 },
    a_c_fishlargemouthbass_01_ms = { item = 'a_c_fishlargemouthbass_01_ms', min = 1.00, max = 1.25 },
    a_c_fishlargemouthbass_01_lg = { item = 'a_c_fishlargemouthbass_01_lg', min = 1.25, max = 1.50 },
    a_c_fishsmallmouthbass_01_ms = { item = 'a_c_fishsmallmouthbass_01_ms', min = 1.00, max = 1.25 },
    a_c_fishsmallmouthbass_01_lg = { item = 'a_c_fishsmallmouthbass_01_lg', min = 1.25, max = 1.50 },
    a_c_fishrainbowtrout_01_ms   = { item = 'a_c_fishrainbowtrout_01_ms',   min = 1.00, max = 1.25 },
    a_c_fishrainbowtrout_01_lg   = { item = 'a_c_fishrainbowtrout_01_lg',   min = 1.25, max = 1.50 },
    a_c_fishsalmonsockeye_01_ms  = { item = 'a_c_fishsalmonsockeye_01_ms',  min = 1.00, max = 1.20 },
    a_c_fishsalmonsockeye_01_ml  = { item = 'a_c_fishsalmonsockeye_01_ml',  min = 1.20, max = 1.35 },
    a_c_fishsalmonsockeye_01_lg  = { item = 'a_c_fishsalmonsockeye_01_lg',  min = 1.35, max = 1.50 },
    a_c_fishchannelcatfish_01_lg = { item = 'a_c_fishchannelcatfish_01_lg', min = 3.50, max = 4.25 },
    a_c_fishchannelcatfish_01_xl = { item = 'a_c_fishchannelcatfish_01_xl', min = 4.25, max = 5.00 },
    a_c_fishlakesturgeon_01_lg   = { item = 'a_c_fishlakesturgeon_01_lg',   min = 3.50, max = 5.00 },
    a_c_fishlongnosegar_01_lg    = { item = 'a_c_fishlongnosegar_01_lg',    min = 3.50, max = 5.00 },
    a_c_fishmuskie_01_lg         = { item = 'a_c_fishmuskie_01_lg',         min = 3.50, max = 5.00 },
    a_c_fishnorthernpike_01_lg   = { item = 'a_c_fishnorthernpike_01_lg',   min = 3.50, max = 5.00 },
}

-- Which fish each bait draws to the hook (from rsg-fishing's Config.BaitsPerFish, RSG v2, GPL v3).
-- With Config.Fishing.CheckBaitFish the server also refuses a fish the bait cannot catch.
local small = {
    'a_c_fishbluegil_01_ms', 'a_c_fishbluegil_01_sm', 'a_c_fishperch_01_ms', 'a_c_fishperch_01_sm',
    'a_c_fishbullheadcat_01_ms', 'a_c_fishbullheadcat_01_sm', 'a_c_fishrainbowtrout_01_ms',
    'a_c_fishlargemouthbass_01_ms', 'a_c_fishredfinpickerel_01_ms', 'a_c_fishredfinpickerel_01_sm',
}
Config.BaitFish = {
    p_baitbread01x  = small,
    p_baitcorn01x   = small,
    p_baitcheese01x = small,
    p_baitcricket01x = {
        'a_c_fishbluegil_01_ms', 'a_c_fishbluegil_01_sm', 'a_c_fishlakesturgeon_01_lg', 'a_c_fishlargemouthbass_01_lg',
        'a_c_fishlargemouthbass_01_ms', 'a_c_fishmuskie_01_lg', 'a_c_fishperch_01_ms', 'a_c_fishperch_01_sm',
        'a_c_fishrainbowtrout_01_lg', 'a_c_fishrainbowtrout_01_ms', 'a_c_fishredfinpickerel_01_ms',
        'a_c_fishredfinpickerel_01_sm', 'a_c_fishsmallmouthbass_01_lg',
    },
    p_baitworm01x = {
        'a_c_fishbluegil_01_ms', 'a_c_fishbluegil_01_sm', 'a_c_fishchainpickerel_01_ms', 'a_c_fishchainpickerel_01_sm',
        'a_c_fishlakesturgeon_01_lg', 'a_c_fishlargemouthbass_01_lg', 'a_c_fishlargemouthbass_01_ms',
        'a_c_fishperch_01_ms', 'a_c_fishperch_01_sm', 'a_c_fishrainbowtrout_01_ms', 'a_c_fishredfinpickerel_01_ms',
        'a_c_fishredfinpickerel_01_sm', 'a_c_fishrockbass_01_ms', 'a_c_fishsalmonsockeye_01_ml',
        'a_c_fishsalmonsockeye_01_ms', 'a_c_fishsmallmouthbass_01_ms',
    },
    p_finisdfishlure01x = {
        'a_c_fishbluegil_01_ms', 'a_c_fishbluegil_01_sm', 'a_c_fishbullheadcat_01_ms', 'a_c_fishbullheadcat_01_sm',
        'a_c_fishlakesturgeon_01_lg', 'a_c_fishlongnosegar_01_lg', 'a_c_fishnorthernpike_01_lg', 'a_c_fishperch_01_ms',
        'a_c_fishperch_01_sm', 'a_c_fishredfinpickerel_01_ms', 'a_c_fishredfinpickerel_01_sm',
        'a_c_fishsalmonsockeye_01_lg', 'a_c_fishsalmonsockeye_01_ml', 'a_c_fishsalmonsockeye_01_ms',
        'a_c_fishsmallmouthbass_01_ms',
    },
    p_finisdfishlurelegendary01x = {
        'a_c_fishbluegil_01_ms', 'a_c_fishbullheadcat_01_ms', 'a_c_fishchainpickerel_01_ms',
        'a_c_fishchannelcatfish_01_lg', 'a_c_fishchannelcatfish_01_xl', 'a_c_fishlakesturgeon_01_lg',
        'a_c_fishlongnosegar_01_lg', 'a_c_fishnorthernpike_01_lg', 'a_c_fishperch_01_ms',
        'a_c_fishredfinpickerel_01_ms', 'a_c_fishsalmonsockeye_01_lg', 'a_c_fishsalmonsockeye_01_ml',
        'a_c_fishsalmonsockeye_01_ms', 'a_c_fishsmallmouthbass_01_lg', 'a_c_fishsmallmouthbass_01_ms',
    },
}
