-- ============================================================
-- MULTIinventory :: hand crafting - turning raw finds into materials
--
-- Things a person does with their hands to make a raw find useful to other
-- recipes: gutting a caught fish into fillets, pounding beaks into bone meal
-- for the fields, melting candle ends back into wax, and hafting old stone
-- arrowheads on new shafts. Same recipe format as config_handcraft.lua.
-- Delete a recipe (or set enabled = false) if your server does not use it.
-- ============================================================

Config = Config or {}
Config.HandCraft = Config.HandCraft or {}
Config.HandCraft.recipes = Config.HandCraft.recipes or {}

-- One ingredient line may list at most 8 alternative items (server/handcraft/core.lua),
-- so the longer lists below are split over several recipes.
local function A(list, n, label) return { items = list, count = n or 1, label = label } end

-- Caught fish, sorted by the meat they give.
local FISH_SMALL = {        -- panfish: flaky white meat
    'a_c_fishbluegil_01_sm', 'a_c_fishbluegil_01_ms', 'a_c_fishperch_01_sm', 'a_c_fishperch_01_ms',
    'a_c_fishrockbass_01_sm', 'a_c_fishrockbass_01_ms',
}
local FISH_PICKEREL = {     -- pickerel: flaky white meat
    'a_c_fishchainpickerel_01_sm', 'a_c_fishchainpickerel_01_ms', 'a_c_fishredfinpickerel_01_sm', 'a_c_fishredfinpickerel_01_ms',
}
local FISH_GAME_MEDIUM = {  -- bass, trout and salmon: succulent meat
    'a_c_fishlargemouthbass_01_ms', 'a_c_fishsmallmouthbass_01_ms', 'a_c_fishrainbowtrout_01_ms', 'a_c_fishsalmonsockeye_01_ms',
}
local FISH_GAME_LARGE = {
    'a_c_fishlargemouthbass_01_lg', 'a_c_fishsmallmouthbass_01_lg', 'a_c_fishrainbowtrout_01_lg',
    'a_c_fishsalmonsockeye_01_ml', 'a_c_fishsalmonsockeye_01_lg',
}
local FISH_BOTTOM_SMALL = { -- bullheads: gritty meat
    'a_c_fishbullheadcat_01_sm', 'a_c_fishbullheadcat_01_ms',
}
local FISH_BOTTOM_LARGE = { -- catfish, gar, pike, muskie, sturgeon
    'a_c_fishchannelcatfish_01_lg', 'a_c_fishchannelcatfish_01_xl', 'a_c_fishlongnosegar_01_lg',
    'a_c_fishnorthernpike_01_lg', 'a_c_fishmuskie_01_lg', 'a_c_fishlakesturgeon_01_lg',
}

local BEAKS_LAND = {        -- fowl, gulls, condor, parrot, turtle
    'provision_beak_turkey', 'provision_beak_goose', 'gooseb', 'provision_beak_prairie_chicken',
    'provision_beak_seagull', 'provision_beak_condor', 'provision_beak_parrot', 'provision_beak_turtle',
}
local BEAKS_WATER = {       -- wading and diving birds
    'provision_beak_common_loon', 'provision_beak_cormorant', 'provision_beak_pelican', 'provision_beak_heron',
    'provision_beak_crane', 'provision_beak_egret', 'provision_beak_roseate_spoonbill', 'provision_beak_red_footed_booby',
}

local ARROWHEAD_SETS = {
    { id = 'haft_rough_arrowheads', label = 'Haft Rough Stone Arrowheads', items = {
        'arch_arrowhead_raw', 'arch_arrowhead_crude', 'arch_arrowhead_rough', 'arch_arrowhead_chipped',
        'arch_arrowhead_splinter', 'arch_arrowhead_bone', 'arch_arrowhead_slate', 'arch_arrowhead_granite' } },
    { id = 'haft_fine_arrowheads', label = 'Haft Fine Stone Arrowheads', items = {
        'arch_arrowhead_feldspar', 'arch_arrowhead_quartz', 'arch_arrowhead_agate', 'arch_arrowhead_obsidian',
        'arch_arrowhead_obsidian_fine', 'arch_arrowhead_ancient', 'arch_broadhead_ancient', 'arch_spearpoint_ancient' } },
    { id = 'haft_collected_rough_arrowheads', label = 'Haft Collected Rough Arrowheads', items = {
        'provision_arrowhead_raw', 'provision_arrowhead_crude', 'provision_arrowhead_rough', 'provision_arrowhead_chipped',
        'provision_arrowhead_splintered', 'provision_arrowhead_bone', 'provision_arrowhead_slate', 'provision_arrowhead_granite' } },
    { id = 'haft_collected_fine_arrowheads', label = 'Haft Collected Fine Arrowheads', items = {
        'provision_arrowhead_feldspar', 'provision_arrowhead_quartz', 'provision_arrowhead_agate', 'provision_arrowhead_obsidian' } },
}
local FLETCHING = {
    'feathers', 'Feather', 'provision_feather_turkey', 'provision_feather_goose',
    'provision_feather_hawk', 'provision_feather_eagle', 'goosef', 'hawkf',
}

local R = Config.HandCraft.recipes

R.gut_panfish = {
    label = 'Gut & Fillet Panfish',
    description = 'Scale and gut a small fish and take the two fillets off the bone.',
    category = 'Provisions',
    ingredients = { A(FISH_SMALL, 1, 'Bluegill, perch or rock bass') },
    outputs = { { item = 'provision_flakey_fish_meat', count = 1 } },
    time = 4000,
}
R.gut_pickerel = {
    label = 'Gut & Fillet Pickerel',
    description = 'Scale and gut a pickerel and take the two fillets off the bone.',
    category = 'Provisions',
    ingredients = { A(FISH_PICKEREL, 1, 'Chain or redfin pickerel') },
    outputs = { { item = 'provision_flakey_fish_meat', count = 1 } },
    time = 4000,
}
R.gut_gamefish = {
    label = 'Gut & Fillet Game Fish',
    description = 'Clean a bass, trout or salmon and fillet it.',
    category = 'Provisions',
    ingredients = { A(FISH_GAME_MEDIUM, 1, 'Bass, trout or salmon') },
    outputs = { { item = 'provision_succulent_fish_meat', count = 1 } },
    time = 5000,
}
R.gut_gamefish_large = {
    label = 'Gut & Fillet a Big Game Fish',
    description = 'A big bass, trout or salmon gives two good fillets.',
    category = 'Provisions',
    ingredients = { A(FISH_GAME_LARGE, 1, 'Large bass, trout or salmon') },
    outputs = { { item = 'provision_succulent_fish_meat', count = 2 } },
    time = 6000,
}
R.gut_bullhead = {
    label = 'Skin & Fillet Bullhead',
    description = 'Skin a bullhead the way you would a catfish and cut the meat away.',
    category = 'Provisions',
    ingredients = { A(FISH_BOTTOM_SMALL, 1, 'Bullhead') },
    outputs = { { item = 'provision_gritty_fish_meat', count = 1 } },
    time = 5000,
}
R.gut_bottomfish_large = {
    label = 'Butcher a Big River Fish',
    description = 'Skin and portion a catfish, gar, pike, muskie or sturgeon.',
    category = 'Provisions',
    ingredients = { A(FISH_BOTTOM_LARGE, 1, 'Catfish, gar, pike, muskie or sturgeon') },
    outputs = { { item = 'provision_gritty_fish_meat', count = 3 } },
    time = 8000,
}

R.curd_goat_cheese = {
    label = 'Curd Goat Milk into Cheese',
    description = 'Warm goat milk, turn it with a splash of vinegar, then salt and press the curds.',
    category = 'Provisions',
    ingredients = {
        A({ 'goatmilk', 'goat_milk' }, 3, 'Goat milk'),
        A({ 'vinegar', 'wine_vinegar' }, 1, 'Vinegar'),
        { item = 'salt', count = 1 },
    },
    outputs = { { item = 'goat_cheese', count = 1 } },
    time = 9000,
}

R.pound_bone_meal = {
    label = 'Pound Beaks into Bone Meal',
    description = 'Dry bird beaks and pound them to a coarse meal. Farmers dig it into their soil.',
    category = 'Materials',
    ingredients = { A(BEAKS_LAND, 3, 'Fowl, gull, condor, parrot or turtle beaks') },
    outputs = { { item = 'bone_meal', count = 1 } },
    time = 6000,
}
R.pound_bone_meal_waterbirds = {
    label = 'Pound Water-Bird Beaks into Bone Meal',
    description = 'Dry the long beaks of wading and diving birds and pound them to a coarse meal.',
    category = 'Materials',
    ingredients = { A(BEAKS_WATER, 3, 'Loon, heron, pelican or other water-bird beaks') },
    outputs = { { item = 'bone_meal', count = 1 } },
    time = 6000,
}

R.render_candle_wax = {
    label = 'Melt Down Candle Ends',
    description = 'Melt old candles down and pour off the wax into a cake.',
    category = 'Materials',
    ingredients = { { item = 'candle', count = 3 } },
    outputs = { { item = 'wax', count = 1 } },
    time = 6000,
}

for _, set in ipairs(ARROWHEAD_SETS) do
    R[set.id] = {
        label = set.label,
        description = 'Bind old stone heads onto straight shafts and fletch them. Ten heads make a bundle.',
        category = 'Materials',
        ingredients = {
            A(set.items, 10, 'Arrowheads'),
            A({ 'wood', 'wood_log' }, 2, 'Wood'),
            A(FLETCHING, 1, 'Feathers'),
            A({ 'native_sinew_thread', 'twine', 'string' }, 1, 'Sinew or twine'),
        },
        outputs = { { item = 'ammo_arrow', count = 1 } },
        time = 12000,
        maxQuantity = 5,
    }
end
