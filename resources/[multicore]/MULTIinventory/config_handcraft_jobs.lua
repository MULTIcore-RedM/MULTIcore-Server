-- ============================================================
-- MULTIinventory :: job field recipes (Crafting Journal, one chapter per trade)
--
-- Small, everyday things a trade can make anywhere with its own tools carried
-- (the tools are kept). Bigger work stays at the job's own workshop; these never
-- give more than the workshop does. Three job stations add a few more:
--   anvil      (blacksmith, gunsmith, jeweller, stable, wagon maker)
--   workbench  (carpenter, cooper, wagon maker, undertaker)
--   hide_frame (tanner, hunter)
-- (stations: config_workshop.lua Config.Stations)
--
-- A player only sees the chapters of the jobs they have. Job names: edit JOBS below
-- (each list = global job names + one per town prefix, e.g. valblacksmith).
-- Same recipe format as config_handcraft.lua.
-- ============================================================

Config = Config or {}
Config.HandCraft = Config.HandCraft or {}
Config.HandCraft.recipes = Config.HandCraft.recipes or {}

local TOWNS = { 'val', 'black', 'straw', 'rhodes', 'stden', 'tumble', 'armad', 'van', 'anne' }
local function J(globals, suffix)
    local t, seen = {}, {}
    for _, n in ipairs(globals) do if not seen[n] then seen[n] = true; t[#t + 1] = n end end
    if suffix then
        for _, p in ipairs(TOWNS) do local n = p .. suffix; if not seen[n] then seen[n] = true; t[#t + 1] = n end end
    end
    return t
end
local function merge(...)
    local t, seen = {}, {}
    for _, list in ipairs({ ... }) do for _, n in ipairs(list) do if not seen[n] then seen[n] = true; t[#t + 1] = n end end end
    return t
end
local function I(item, n) return { item = item, count = n or 1 } end
local function A(list, n, label) return { items = list, count = n or 1, label = label } end

local BARBERS = J({ 'barber', 'deadwoodbarber' }, 'barber')
local JOBS = {
    animaltamer  = J({ 'animaltamer' }, 'animaltamer'),
    barber       = BARBERS,
    blacksmith   = J({ 'blacksmith' }, 'blacksmith'),
    bountyhunter = J({ 'bountyhunter' }, 'bountyhunter'),
    carpenter    = J({ 'carpenter', 'woodworker' }, 'carpenter'),
    cooper       = J({ 'cooper' }, 'cooper'),
    doctor       = merge(J({ 'medic', 'doctor' }, 'medic'), BARBERS),   -- barbers are medical too
    farmer       = J({ 'farmer' }, 'farmer'),
    fisherman    = J({ 'fisherman' }, 'fisherman'),
    generalstore = J({ 'storeowner' }, 'store'),
    gunsmith     = J({ 'gunsmith' }, 'gunsmith'),
    herbalist    = J({ 'herbalist' }, 'herbalist'),
    hunter       = J({ 'hunter' }, 'hunter'),
    jeweller     = J({ 'jeweler' }, 'jeweler'),
    journalist   = J({ 'news', 'bwphotographer', 'sdphotographer' }, 'news'),
    pharmacist   = J({ 'pharmacist' }, 'pharmacist'),
    printer      = J({ 'printer' }, 'printer'),
    priest       = J({ 'priest' }, 'priest'),
    saloon       = J({ 'saloonowner', 'barman' }, 'saloon'),
    stable       = J({ 'horsetrainer' }, 'horsetrainer'),
    tailor       = J({ 'tailor' }, 'tailor'),
    tanner       = J({ 'tanner' }, 'tanner'),
    traindriver  = J({ 'traindriver' }, 'traindriver'),
    undertaker   = J({ 'undertaker' }, 'undertaker'),
    wagon        = { 'wagon_maker', 'wagon_saint', 'wagon_rhodes', 'wagon_blackwater', 'wagon_strawberry',
                     'wagon_valentine', 'wagon_tumbleweed', 'wagon_armadillo', 'wagon_vanhorn', 'wagon_annesburg' },
}
JOBS.healers = merge(JOBS.herbalist, JOBS.doctor, JOBS.pharmacist)

-- tool kits (carried, never used up)
local HAMMER = A({ 'toolhammer', 'ironhammer', 'stonehammer' }, 1, 'Hammer')
local SAW    = A({ 'handsaw', 'woodsaw' }, 1, 'Saw')
local NEEDLE = A({ 'sewing_kit', 'needle', 'native_bone_needle' }, 1, 'Needle or sewing kit')
local MORTAR = A({ 'mortarpestle', 'tool_mortar_pestle', 'herbalist_mortar' }, 1, 'Mortar & pestle')
local WRENCH = A({ 'wrench' }, 1, 'Wrench')
local KIT = {
    animaltamer = { A({ 'pet_whistle', 'kit_lunging_rope' }, 1, 'Whistle or lunging rope') },
    barber      = { A({ 'barber_kit' }, 1, 'Barber kit') },
    doctor      = { A({ 'doctors_bag', 'dochitkit', 'sig_surgeon_kit' }, 1, "Doctor's bag") },
    farmer      = { A({ 'shovel', 'hoe', 'wateringcan' }, 1, 'Farm tool') },
    fisherman   = { A({ 'fishing_repair_kit', 'fishing_net', 'small_fishing_net', 'large_fishing_net' }, 1, 'Tackle') },
    hunter      = { A({ 'trap_kit', 'tracking_kit' }, 1, 'Trapping kit') },
    jeweller    = { A({ 'magnifying_glass' }, 1, 'Magnifying glass') },
    journalist  = { A({ 'reporter_notebook', 'evidence_notebook', 'notebook' }, 1, 'Notebook') },
    camera      = { A({ 'field_camera', 'press_camera', 'camera' }, 1, 'Camera') },
    priest      = { A({ 'prayer_book' }, 1, 'Prayer book') },
    saloon      = { A({ 'coffee_grinder' }, 1, 'Coffee grinder') },
    stable      = { A({ 'kit_horse_brush', 'horse_brush', 'horsebrush' }, 1, 'Horse brush'), A({ 'kit_hoof_knife' }, 1, 'Hoof knife') },
    tanner      = { A({ 'knife_blade', 'kit_hoof_knife' }, 1, 'Blade') },
    traindriver = { A({ 'railroad_spike_puller' }, 1, 'Spike puller') },
    undertaker  = { A({ 'shovel' }, 1, 'Shovel') },
}

local R = {
    -- ---------------- Animal Tamer ----------------
    tamer_small_bait = { label = 'Small Animal Bait', category = 'Animal Tamer', jobs = JOBS.animaltamer, tools = KIT.animaltamer, ingredients = { I('raw_meat'), I('herb') }, outputs = { I('animal_bait_small', 2) }, time = 5000 },
    tamer_feed       = { label = 'Animal Feed', category = 'Animal Tamer', jobs = JOBS.animaltamer, tools = KIT.animaltamer, ingredients = { I('corn', 2), I('carrot') }, outputs = { I('animal_feed', 2) }, time = 5000 },
    tamer_water      = { label = 'Animal Water', category = 'Animal Tamer', jobs = JOBS.animaltamer, tools = KIT.animaltamer, ingredients = { I('water') }, outputs = { I('animal_water') }, time = 4000 },
    tamer_tonic      = { label = 'Animal Tonic', category = 'Animal Tamer', jobs = JOBS.animaltamer, tools = KIT.animaltamer, ingredients = { I('herb', 2), I('water') }, outputs = { I('animal_tonic') }, time = 8000 },
    tamer_whistle    = { label = 'Carve a Pet Whistle', category = 'Animal Tamer', jobs = JOBS.animaltamer, tools = KIT.animaltamer, ingredients = { I('iron_ingot'), I('wood') }, outputs = { I('pet_whistle') }, time = 9000 },

    -- ---------------- Barber ----------------
    barber_shaving_cream = { label = 'Shaving Cream', category = 'Barber', jobs = JOBS.barber, tools = KIT.barber, ingredients = { I('herb'), I('water') }, outputs = { I('shaving_cream') }, time = 5000 },
    barber_towel      = { label = 'Clean Towel', category = 'Barber', jobs = JOBS.barber, tools = KIT.barber, ingredients = { I('cloth'), I('water') }, outputs = { I('clean_towel') }, time = 4000 },
    barber_pomade     = { label = 'Pomade', category = 'Barber', jobs = JOBS.barber, tools = KIT.barber, ingredients = { I('beeswax', 2) }, outputs = { I('pomade') }, time = 5000 },
    barber_aftershave = { label = 'Aftershave', category = 'Barber', jobs = JOBS.barber, tools = KIT.barber, ingredients = { I('herb', 2), I('whiskey_bottle'), I('water') }, outputs = { I('aftershave') }, time = 6000 },
    barber_shaving_kit = { label = 'Roll a Shaving Kit', category = 'Barber', jobs = JOBS.barber, tools = KIT.barber, ingredients = { I('razor_blade'), I('shaving_cream'), I('cloth') }, outputs = { I('shaving_kit') }, time = 7000 },

    -- ---------------- Blacksmith (cold work; forge work at the smithy or the anvil) ----------------
    smith_straighten  = { label = 'Straighten a Bent Horseshoe', category = 'Blacksmith', jobs = JOBS.blacksmith, tools = { HAMMER }, ingredients = { I('bent_horseshoe') }, outputs = { I('horseshoe') }, time = 6000 },
    smith_repair_kit  = { label = 'Weapon Repair Kit', category = 'Blacksmith', jobs = JOBS.blacksmith, tools = { HAMMER }, ingredients = { I('nails', 5), I('wood_plank', 2), I('rope') }, outputs = { I('weapon_repair_kit') }, time = 10000 },
    smith_shoe_set    = { label = 'Horseshoe Set', category = 'Blacksmith', jobs = JOBS.blacksmith, tools = { HAMMER }, ingredients = { I('horseshoe', 4), I('nails', 16) }, outputs = { I('horseshoe_set') }, time = 8000 },
    smith_rehaft_pick = { label = 'Haft a Pickaxe', category = 'Blacksmith', jobs = JOBS.blacksmith, tools = { HAMMER }, ingredients = { I('iron_ingot'), I('tool_handle') }, outputs = { I('pickaxe') }, time = 7000 },
    smith_hammer      = { label = 'Haft a Smithing Hammer', category = 'Blacksmith', jobs = JOBS.blacksmith, tools = { HAMMER }, ingredients = { I('iron_ingot', 2), I('wood'), I('tool_handle') }, outputs = { I('toolhammer') }, time = 10000 },
    smith_anvil       = { label = 'Forge a Field Anvil', description = 'A small anvil to set down anywhere (lasts about 48 hours once set up).', category = 'Blacksmith', jobs = JOBS.blacksmith, tools = { HAMMER }, ingredients = { I('iron_ingot', 4), I('steel_ingot') }, outputs = { I('anvil') }, time = 15000, maxQuantity = 2 },

    -- ---------------- Bounty Hunter ----------------
    bounty_cuffs  = { label = 'Handcuffs', category = 'Bounty Hunter', jobs = JOBS.bountyhunter, tools = { HAMMER }, ingredients = { I('iron_ingot'), I('bolts', 2) }, outputs = { I('handcuffs') }, time = 7000 },
    bounty_poster = { label = 'Bounty Poster', category = 'Bounty Hunter', jobs = JOBS.bountyhunter, ingredients = { I('paper', 3), I('ink') }, outputs = { I('bounty_poster') }, time = 5000 },

    -- ---------------- Carpenter ----------------
    carp_planks       = { label = 'Saw Planks', category = 'Carpenter', jobs = JOBS.carpenter, tools = { SAW }, ingredients = { I('wood_log', 2) }, outputs = { I('wood_plank') }, time = 8000 },
    carp_handle       = { label = 'Tool Handle', category = 'Carpenter', jobs = JOBS.carpenter, tools = { SAW }, ingredients = { I('wood_plank') }, outputs = { I('tool_handle') }, time = 5000 },
    carp_campfire_kit = { label = 'Campfire Kit', category = 'Carpenter', jobs = JOBS.carpenter, tools = { HAMMER }, ingredients = { I('wood', 3), I('rock', 2) }, outputs = { I('campfire_kit') }, time = 7000 },
    carp_cross        = { label = 'Wooden Cross', category = 'Carpenter', jobs = JOBS.carpenter, tools = { HAMMER, SAW }, ingredients = { I('wood_plank', 2), I('nails', 4) }, outputs = { I('grave_cross_wood') }, time = 8000 },
    carp_handsaw      = { label = 'Make a Handsaw', category = 'Carpenter', jobs = JOBS.carpenter, tools = { HAMMER }, ingredients = { I('steel_ingot'), I('tool_handle'), I('nails', 2) }, outputs = { I('handsaw') }, time = 10000 },
    carp_plane        = { label = 'Make a Wood Plane', category = 'Carpenter', jobs = JOBS.carpenter, tools = { HAMMER, SAW }, ingredients = { I('iron_ingot'), I('wood_plank') }, outputs = { I('wood_plane') }, time = 9000 },
    carp_workbench    = { label = 'Build a Field Workbench', description = 'A folding workbench to set down anywhere (lasts about 48 hours once set up).', category = 'Carpenter', jobs = JOBS.carpenter, tools = { HAMMER, SAW }, ingredients = { I('wood_plank', 6), I('nails', 12) }, outputs = { I('camp_workbench') }, time = 15000, maxQuantity = 2 },

    -- ---------------- Cooper ----------------
    coop_staves   = { label = 'Barrel Staves', category = 'Cooper', jobs = JOBS.cooper, tools = { SAW }, ingredients = { I('wood_plank', 2) }, outputs = { I('barrel_stave', 2) }, time = 6000 },
    coop_bucket   = { label = 'Wooden Bucket', category = 'Cooper', jobs = JOBS.cooper, tools = { HAMMER }, ingredients = { I('barrel_stave', 2), I('barrel_hoop') }, outputs = { I('empty_bucket') }, time = 7000 },
    coop_mash_lid = { label = 'Mash Lid', category = 'Cooper', jobs = JOBS.cooper, tools = { HAMMER }, ingredients = { I('barrel_stave', 2), I('tree_resin') }, outputs = { I('mash_lid') }, time = 6000 },
    coop_handsaw  = { label = 'Make a Handsaw', category = 'Cooper', jobs = JOBS.cooper, tools = { HAMMER }, ingredients = { I('steel_ingot'), I('tool_handle'), I('nails', 2) }, outputs = { I('handsaw') }, time = 10000 },

    -- ---------------- Doctor (doctors, medics, barbers) ----------------
    doc_bandage    = { label = 'Bandage', category = 'Doctor', jobs = JOBS.doctor, tools = KIT.doctor, ingredients = { I('cotton', 2), I('purealcohol') }, outputs = { I('bandage') }, time = 5000 },
    doc_gauze      = { label = 'Gauze Rolls', category = 'Doctor', jobs = JOBS.doctor, tools = KIT.doctor, ingredients = { I('cotton', 2), I('purealcohol') }, outputs = { I('gauze', 3) }, time = 6000 },
    doc_tourniquet = { label = 'Tourniquet', category = 'Doctor', jobs = JOBS.doctor, tools = KIT.doctor, ingredients = { I('cloth'), I('wood'), I('twine') }, outputs = { I('tourniquet') }, time = 5000 },
    doc_splint     = { label = 'Splint', category = 'Doctor', jobs = JOBS.doctor, tools = KIT.doctor, ingredients = { I('wood_plank'), I('cloth', 2) }, outputs = { I('splint') }, time = 8000 },
    doc_yarrow     = { label = 'Yarrow Poultice', category = 'Doctor', jobs = JOBS.doctor, tools = KIT.doctor, ingredients = { I('herb_yarrow', 2), I('cloth') }, outputs = { I('native_yarrow_poultice') }, time = 6000 },
    doc_bag        = { label = "Stitch a Doctor's Bag", category = 'Doctor', jobs = JOBS.doctor, tools = { NEEDLE }, ingredients = { I('leather', 4), I('cloth', 2), I('iron', 2), I('twine', 2) }, outputs = { I('doctors_bag') }, time = 14000 },

    -- ---------------- Farmer ----------------
    farm_feed       = { label = 'Animal Feed', category = 'Farmer', jobs = JOBS.farmer, tools = KIT.farmer, ingredients = { I('corn', 3), I('carrot', 2) }, outputs = { I('animal_feed') }, time = 5000 },
    farm_hay        = { label = 'Hay Snack', category = 'Farmer', jobs = JOBS.farmer, tools = KIT.farmer, ingredients = { I('wheat', 3) }, outputs = { I('haysnack') }, time = 4000 },
    farm_horsemeal  = { label = 'Horse Meal', category = 'Farmer', jobs = JOBS.farmer, tools = KIT.farmer, ingredients = { I('wheat', 2), I('corn', 2), I('carrot') }, outputs = { I('horsemeal') }, time = 5000 },
    farm_fertilizer = { label = 'Fertilizer', category = 'Farmer', jobs = JOBS.farmer, tools = KIT.farmer, ingredients = { I('animal_feed'), I('potato'), I('salt') }, outputs = { I('fertilizer') }, time = 7000 },
    farm_seed_pack  = { label = 'Seed Pack', category = 'Farmer', jobs = JOBS.farmer, tools = KIT.farmer, ingredients = { I('cornseed', 2), I('wheat') }, outputs = { I('seed_pack') }, time = 5000 },
    farm_can        = { label = 'Watering Can', category = 'Farmer', jobs = JOBS.farmer, tools = { A({ 'shovel', 'hoe' }, 1, 'Shovel or hoe') }, ingredients = { I('tin_can'), I('iron'), I('wood') }, outputs = { I('wateringcan') }, time = 8000 },

    -- ---------------- Fisherman ----------------
    fish_clean      = { label = 'Clean Fish', category = 'Fisherman', jobs = JOBS.fisherman, tools = KIT.fisherman, ingredients = { I('fish', 2) }, outputs = { I('cleaned_fish') }, time = 5000 },
    fish_bread_bait = { label = 'Bread Bait', category = 'Fisherman', jobs = JOBS.fisherman, tools = KIT.fisherman, ingredients = { I('bread') }, outputs = { I('p_baitBread01x', 3) }, time = 4000 },
    fish_corn_bait  = { label = 'Corn Bait', category = 'Fisherman', jobs = JOBS.fisherman, tools = KIT.fisherman, ingredients = { I('corn') }, outputs = { I('p_baitCorn01x', 3) }, time = 4000 },
    fish_worm_bait  = { label = 'Worm Bait', category = 'Fisherman', jobs = JOBS.fisherman, tools = KIT.fisherman, ingredients = { I('fiber', 2), I('fertilizer') }, outputs = { I('p_baitWorm01x', 4) }, time = 5000 },
    fish_lure       = { label = 'Fish Lure', category = 'Fisherman', jobs = JOBS.fisherman, tools = KIT.fisherman, ingredients = { I('feathers'), I('fiber', 2), I('iron') }, outputs = { I('p_FinisdFishlure01x') }, time = 7000 },
    fish_repair_kit = { label = 'Rod Repair Kit', category = 'Fisherman', jobs = JOBS.fisherman, ingredients = { I('wood'), I('rope'), I('fiber', 2) }, outputs = { I('fishing_repair_kit') }, time = 6000 },

    -- ---------------- General Store ----------------
    store_note = { label = 'Notes', category = 'General Store', jobs = JOBS.generalstore, ingredients = { I('paper') }, outputs = { I('note') }, time = 4000 },

    -- ---------------- Gunsmith ----------------
    gun_oilcan     = { label = 'Oil Can', category = 'Gunsmith', jobs = JOBS.gunsmith, tools = { WRENCH, HAMMER }, ingredients = { I('iron'), I('oil') }, outputs = { I('oilcan', 2) }, time = 5000 },
    gun_casings    = { label = 'Shell Casings', category = 'Gunsmith', jobs = JOBS.gunsmith, tools = { WRENCH, HAMMER }, ingredients = { I('copperore', 2) }, outputs = { I('shellcasing') }, time = 6000 },
    gun_repair_kit = { label = 'Weapon Repair Kit', category = 'Gunsmith', jobs = JOBS.gunsmith, tools = { WRENCH, HAMMER }, ingredients = { I('nails', 5), I('wood_plank', 2), I('rope') }, outputs = { I('weapon_repair_kit') }, time = 10000 },
    gun_wrench     = { label = 'Make a Wrench', category = 'Gunsmith', jobs = JOBS.gunsmith, tools = { HAMMER }, ingredients = { I('iron_ingot'), I('bolts') }, outputs = { I('wrench') }, time = 9000 },

    -- ---------------- Herbalist ----------------
    herb_dried       = { label = 'Dried Herb Bundle', category = 'Herbalist', jobs = JOBS.herbalist, tools = { MORTAR }, ingredients = { I('herb', 4) }, outputs = { I('dried_herb') }, time = 5000 },
    herb_tea         = { label = 'Herbal Tea', category = 'Herbalist', jobs = JOBS.herbalist, ingredients = { I('herb_wild_mint'), I('herb_creeping_thyme'), I('water') }, outputs = { I('native_herbal_tea') }, time = 5000 },
    herb_willow_tea  = { label = 'Willow Bark Tea', category = 'Herbalist', jobs = JOBS.herbalist, ingredients = { I('native_willow'), I('water') }, outputs = { I('native_willow_tea') }, time = 5000 },
    herb_sage_bundle = { label = 'Sage Bundle', category = 'Herbalist', jobs = JOBS.herbalist, ingredients = { I('native_sage', 2), I('native_sweetgrass'), I('twine') }, outputs = { I('native_sage_bundle') }, time = 6000 },
    herb_poultice    = { label = 'Poultice', category = 'Herbalist', jobs = JOBS.herbalist, tools = { MORTAR }, ingredients = { I('herb_burdock_root', 2), I('cotton') }, outputs = { I('poultice') }, time = 6000 },
    herb_mortar      = { label = 'Mortar & Pestle', category = 'Herbalist', jobs = JOBS.herbalist, ingredients = { I('stone', 2), I('wood') }, outputs = { I('mortarpestle') }, time = 9000 },

    -- ---------------- Hunter ----------------
    hunt_bait     = { label = 'Bait', category = 'Hunter', jobs = JOBS.hunter, tools = KIT.hunter, ingredients = { I('raw_meat'), I('herb') }, outputs = { I('bait', 2) }, time = 4000 },
    hunt_leather  = { label = 'Rough Leather', category = 'Hunter', jobs = JOBS.hunter, tools = KIT.hunter, ingredients = { I('rawhide', 2) }, outputs = { I('leather') }, time = 8000 },
    hunt_trap_kit = { label = 'Trap Kit', category = 'Hunter', jobs = JOBS.hunter, ingredients = { I('wood', 2), I('rope'), I('iron') }, outputs = { I('trap_kit') }, time = 9000 },

    -- ---------------- Jeweller ----------------
    jewel_sap      = { label = 'Refine Sap', category = 'Jeweller', jobs = JOBS.jeweller, tools = KIT.jeweller, ingredients = { I('tree_resin', 2) }, outputs = { I('sap') }, time = 4000 },
    jewel_ruby     = { label = 'Cut a Ruby', category = 'Jeweller', jobs = JOBS.jeweller, tools = KIT.jeweller, ingredients = { I('ruby_uncut') }, outputs = { I('ruby') }, time = 8000 },
    jewel_sapphire = { label = 'Cut a Sapphire', category = 'Jeweller', jobs = JOBS.jeweller, tools = KIT.jeweller, ingredients = { I('sapphire_uncut') }, outputs = { I('sapphire') }, time = 8000 },

    -- ---------------- Journalist ----------------
    news_ink         = { label = 'Press Ink', category = 'Journalist', jobs = JOBS.journalist, ingredients = { I('charcoal', 2), I('oil') }, outputs = { I('ink') }, time = 5000 },
    news_letter      = { label = 'Sealed Letter', category = 'Journalist', jobs = JOBS.journalist, tools = KIT.journalist, ingredients = { I('paper'), I('ink'), I('wax') }, outputs = { I('document_sealed') }, time = 5000 },
    news_photo_paper = { label = 'Photo Paper', category = 'Journalist', jobs = JOBS.journalist, ingredients = { I('paper', 3), I('chemicals') }, outputs = { I('photo_paper', 2) }, time = 5000 },
    news_photograph  = { label = 'Develop a Photograph', category = 'Journalist', jobs = JOBS.journalist, tools = KIT.camera, ingredients = { I('photo_paper'), I('camera_film'), I('chemicals') }, outputs = { I('photograph') }, time = 10000 },
    news_notebook    = { label = 'Reporter Notebook', category = 'Journalist', jobs = JOBS.journalist, tools = { NEEDLE }, ingredients = { I('paper', 3), I('leather'), I('ink') }, outputs = { I('reporter_notebook') }, time = 6000 },

    -- ---------------- Pharmacist ----------------
    pharm_lozenges = { label = 'Throat Lozenges', category = 'Pharmacist', jobs = JOBS.pharmacist, tools = { MORTAR }, ingredients = { I('honey'), I('sugar', 2), I('herb_wild_mint') }, outputs = { I('throat_lozenges', 6) }, time = 6000 },
    pharm_eye_wash = { label = 'Eye Wash', category = 'Pharmacist', jobs = JOBS.pharmacist, ingredients = { I('water'), I('salt'), I('herb_creeping_thyme'), I('medicine_vial') }, outputs = { I('eye_wash') }, time = 5000 },
    pharm_iodine   = { label = 'Tincture of Iodine', category = 'Pharmacist', jobs = JOBS.pharmacist, ingredients = { I('salt'), I('purealcohol'), I('medicine_vial') }, outputs = { I('iodine_tincture') }, time = 6000 },
    pharm_splint   = { label = 'Wooden Splint', category = 'Pharmacist', jobs = JOBS.pharmacist, ingredients = { I('wood_plank'), I('cloth') }, outputs = { I('wooden_splint') }, time = 6000 },
    pharm_suture   = { label = 'Suture Kit', category = 'Pharmacist', jobs = JOBS.pharmacist, tools = { NEEDLE }, ingredients = { I('cotton'), I('cloth'), I('nails') }, outputs = { I('suture_kit') }, time = 6000 },
    pharm_mustard  = { label = 'Mustard Plaster', category = 'Pharmacist', jobs = JOBS.pharmacist, ingredients = { I('mustard_powder'), I('flour'), I('cloth'), I('water') }, outputs = { I('mustard_poultice') }, time = 6000 },

    -- ---------------- Printer ----------------
    print_ink = { label = "Printer's Ink", category = 'Printer', jobs = JOBS.printer, ingredients = { I('charcoal', 2), I('oil') }, outputs = { I('ink') }, time = 5000 },

    -- ---------------- Priest ----------------
    priest_holy_water = { label = 'Holy Water', category = 'Priest', jobs = JOBS.priest, tools = KIT.priest, ingredients = { I('water', 2), I('herb_yarrow') }, outputs = { I('holy_water') }, time = 6000 },
    priest_candle     = { label = 'Candles', category = 'Priest', jobs = JOBS.priest, ingredients = { I('wax', 2), I('fiber') }, outputs = { I('candle', 2) }, time = 5000 },
    priest_incense    = { label = 'Incense Bundle', category = 'Priest', jobs = JOBS.priest, tools = KIT.priest, ingredients = { I('herb', 3), I('charcoal') }, outputs = { I('incense') }, time = 5000 },
    priest_book       = { label = 'Bind a Prayer Book', category = 'Priest', jobs = JOBS.priest, tools = { NEEDLE }, ingredients = { I('paper', 5), I('leather', 2), I('ink') }, outputs = { I('prayer_book') }, time = 12000 },

    -- ---------------- Saloon ----------------
    saloon_coffee      = { label = 'Grind Coffee', category = 'Saloon', jobs = JOBS.saloon, tools = KIT.saloon, ingredients = { I('coffee_beans', 2) }, outputs = { I('coffee_powder') }, time = 4000 },
    saloon_lemon_water = { label = 'Lemon Water', category = 'Saloon', jobs = JOBS.saloon, ingredients = { I('lemon'), I('water', 2) }, outputs = { I('lemon_water') }, time = 4000 },
    saloon_old_fash    = { label = 'Old Fashioned', category = 'Saloon', jobs = JOBS.saloon, ingredients = { I('water'), I('whisky'), I('orange'), I('sugar') }, outputs = { I('oldfashioned') }, time = 5000 },

    -- ---------------- Stable (horse trainers) ----------------
    stable_treat      = { label = 'Horse Treats', category = 'Stable', jobs = JOBS.stable, tools = KIT.stable, ingredients = { I('apple', 2), I('carrot') }, outputs = { I('horse_treat', 2) }, time = 4000 },
    stable_haycube    = { label = 'Hay Cube', category = 'Stable', jobs = JOBS.stable, ingredients = { I('wheat', 3) }, outputs = { I('consumable_haycube') }, time = 4000 },
    stable_sugarcube  = { label = 'Sugar Cube', category = 'Stable', jobs = JOBS.stable, ingredients = { I('sugar') }, outputs = { I('consumable_sugarcube') }, time = 4000 },
    stable_ointment   = { label = 'Horse Ointment', category = 'Stable', jobs = JOBS.stable, tools = KIT.stable, ingredients = { I('beeswax'), I('herb'), I('oil') }, outputs = { I('consumable_horse_ointment') }, time = 6000 },
    stable_brush      = { label = 'Make a Horse Brush', category = 'Stable', jobs = JOBS.stable, tools = { A({ 'kit_hoof_knife' }, 1, 'Hoof knife') }, ingredients = { I('wood_plank'), I('fiber', 3) }, outputs = { I('kit_horse_brush') }, time = 6000 },
    stable_hoof_knife = { label = 'Make a Hoof Knife', category = 'Stable', jobs = JOBS.stable, tools = { HAMMER }, ingredients = { I('iron', 3), I('wood', 2) }, outputs = { I('kit_hoof_knife') }, time = 6000 },

    -- ---------------- Tailor ----------------
    tailor_fabric     = { label = 'Bolt of Fabric', category = 'Tailor', jobs = JOBS.tailor, tools = { NEEDLE }, ingredients = { I('cotton', 3), I('twine') }, outputs = { I('fabric') }, time = 6000 },
    tailor_cloth      = { label = 'Woollen Cloth', category = 'Tailor', jobs = JOBS.tailor, tools = { NEEDLE }, ingredients = { I('wool', 3), I('twine') }, outputs = { I('cloth', 3) }, time = 6000 },
    tailor_buttons    = { label = 'Brass Buttons', category = 'Tailor', jobs = JOBS.tailor, tools = { NEEDLE }, ingredients = { I('copper') }, outputs = { I('brass_button', 4) }, time = 5000 },
    tailor_sewing_kit = { label = 'Make a Sewing Kit', category = 'Tailor', jobs = JOBS.tailor, ingredients = { I('needle', 2), I('thread', 4), I('leather') }, outputs = { I('sewing_kit') }, time = 9000 },

    -- ---------------- Tanner ----------------
    tan_liquor    = { label = 'Tanning Liquor', category = 'Tanner', jobs = JOBS.tanner, ingredients = { I('wood', 2), I('water', 2), I('salt') }, outputs = { I('tanning_liquor', 2) }, time = 6000 },
    tan_salt_deer = { label = 'Salt a Deer Hide', category = 'Tanner', jobs = JOBS.tanner, tools = KIT.tanner, ingredients = { I('deerpelt'), I('salt') }, outputs = { I('rawhide', 2) }, time = 7000 },
    tan_salt_goat = { label = 'Salt a Goat Hide', category = 'Tanner', jobs = JOBS.tanner, tools = KIT.tanner, ingredients = { I('goats'), I('salt') }, outputs = { I('rawhide') }, time = 6000 },
    tan_salt_boar = { label = 'Salt a Boar Hide', category = 'Tanner', jobs = JOBS.tanner, tools = KIT.tanner, ingredients = { I('boars'), I('salt') }, outputs = { I('rawhide', 2) }, time = 7000 },
    tan_belt      = { label = 'Leather Belt', category = 'Tanner', jobs = JOBS.tanner, tools = KIT.tanner, ingredients = { I('leather'), I('iron') }, outputs = { I('leather_belt') }, time = 7000 },
    tan_hide_frame = { label = 'Lash a Hide Frame', description = 'A stretching frame to set down anywhere (lasts about 48 hours once set up).', category = 'Tanner', jobs = merge(JOBS.tanner, JOBS.hunter), tools = KIT.tanner, ingredients = { I('wood', 6), I('rope', 2) }, outputs = { I('hide_frame') }, time = 12000, maxQuantity = 2 },

    -- ---------------- Train Driver ----------------
    train_grease  = { label = 'Machine Grease', category = 'Train Driver', jobs = JOBS.traindriver, ingredients = { I('oil'), I('charcoal') }, outputs = { I('machine_grease') }, time = 4000 },
    train_oil_can = { label = 'Train Oil Can', category = 'Train Driver', jobs = JOBS.traindriver, tools = KIT.traindriver, ingredients = { I('machine_grease'), I('scrapmetal') }, outputs = { I('train_oil_can') }, time = 5000 },
    train_coal    = { label = 'Coal Bundle', category = 'Train Driver', jobs = JOBS.traindriver, ingredients = { I('coal', 6) }, outputs = { I('train_coal_bundle') }, time = 4000 },
    train_ticket  = { label = 'Railroad Tickets', category = 'Train Driver', jobs = JOBS.traindriver, ingredients = { I('paper'), I('ink') }, outputs = { I('railroad_ticket', 2) }, time = 4000 },

    -- ---------------- Undertaker ----------------
    under_flowers = { label = 'Funeral Flowers', category = 'Undertaker', jobs = JOBS.undertaker, ingredients = { I('herb', 3), I('fiber') }, outputs = { I('funeral_flowers') }, time = 4000 },
    under_bouquet = { label = 'Funeral Bouquet', category = 'Undertaker', jobs = JOBS.undertaker, ingredients = { I('herb', 2), I('fiber') }, outputs = { I('grave_bouquet') }, time = 4000 },
    under_wraps   = { label = 'Burial Wraps', category = 'Undertaker', jobs = JOBS.undertaker, tools = { NEEDLE }, ingredients = { I('cloth', 2), I('cotton', 2) }, outputs = { I('burial_wraps') }, time = 6000 },
    under_candle  = { label = 'Grave Candle', category = 'Undertaker', jobs = JOBS.undertaker, ingredients = { I('wax', 2), I('fiber') }, outputs = { I('grave_candle') }, time = 4000 },
    under_cross   = { label = 'Wooden Cross', category = 'Undertaker', jobs = JOBS.undertaker, tools = { HAMMER }, ingredients = { I('wood_plank', 2), I('nails', 4) }, outputs = { I('grave_cross_wood') }, time = 8000 },
    under_rosary  = { label = 'Funeral Rosary', category = 'Undertaker', jobs = JOBS.undertaker, ingredients = { I('fiber', 3), I('twine') }, outputs = { I('funeral_rosary') }, time = 5000 },

    -- ---------------- Wagon Maker ----------------
    wagon_gasket     = { label = 'Sealing Gasket', category = 'Wagon Maker', jobs = JOBS.wagon, tools = { WRENCH, HAMMER }, ingredients = { I('leather'), I('oil'), I('twine') }, outputs = { I('sealing_gasket') }, time = 5000 },
    wagon_brake_pad  = { label = 'Brake Pad', category = 'Wagon Maker', jobs = JOBS.wagon, tools = { WRENCH, HAMMER }, ingredients = { I('leather', 2), I('scrapmetal', 2) }, outputs = { I('brake_pad') }, time = 6000 },
    wagon_wrench     = { label = 'Make a Wrench', category = 'Wagon Maker', jobs = JOBS.wagon, tools = { HAMMER }, ingredients = { I('iron_ingot'), I('bolts') }, outputs = { I('wrench') }, time = 9000 },

    -- ================ job stations ================
    -- anvil
    anvil_nails      = { label = 'Nails', category = 'Blacksmith', station = 'anvil', jobs = JOBS.blacksmith, tools = { HAMMER }, ingredients = { I('iron_ingot') }, outputs = { I('nails', 8) }, time = 8000 },
    anvil_horseshoe  = { label = 'Horseshoe', category = 'Blacksmith', station = 'anvil', jobs = merge(JOBS.blacksmith, JOBS.stable), tools = { HAMMER }, ingredients = { I('iron_ingot'), I('coal') }, outputs = { I('horseshoe') }, time = 8000 },
    anvil_iron_bolts = { label = 'Iron Bolts', category = 'Blacksmith', station = 'anvil', jobs = merge(JOBS.blacksmith, JOBS.gunsmith, JOBS.wagon), tools = { HAMMER }, ingredients = { I('iron_ingot'), I('coal') }, outputs = { I('iron_bolts', 3) }, time = 6000 },
    anvil_nuggets    = { label = 'Combine Small Nuggets', category = 'Jeweller', station = 'anvil', jobs = JOBS.jeweller, tools = { HAMMER }, ingredients = { I('smallnugget', 3), I('coal') }, outputs = { I('mediumnugget') }, time = 6000 },
    -- workbench
    wb_crate       = { label = 'Wooden Crate', category = 'Carpenter', station = 'workbench', jobs = JOBS.carpenter, tools = { HAMMER, SAW }, ingredients = { I('wood_plank', 6), I('nails', 10) }, outputs = { I('wooden_crate') }, time = 12000 },
    wb_barrel      = { label = 'Wooden Barrel', category = 'Cooper', station = 'workbench', jobs = JOBS.cooper, tools = { HAMMER, SAW }, ingredients = { I('barrel_stave', 6), I('barrel_hoop', 2) }, outputs = { I('wooden_barrel') }, time = 12000 },
    wb_wagon_wheel = { label = 'Wagon Wheel', category = 'Wagon Maker', station = 'workbench', jobs = JOBS.wagon, tools = { WRENCH, HAMMER }, ingredients = { I('wood_plank', 4), I('iron_ingot'), I('nails', 8) }, outputs = { I('wagon_wheel') }, time = 15000 },
    wb_coffin      = { label = 'Wooden Coffin', category = 'Undertaker', station = 'workbench', jobs = JOBS.undertaker, tools = { HAMMER }, ingredients = { I('wood_plank', 8), I('nails', 6), I('fabric', 2) }, outputs = { I('coffin') }, time = 14000 },
    -- hide frame
    frame_leather   = { label = 'Tan Leather', category = 'Tanner', station = 'hide_frame', jobs = JOBS.tanner, ingredients = { I('rawhide', 3), I('tanning_liquor') }, outputs = { I('leather', 2) }, time = 12000 },
    frame_wolf_fur  = { label = 'Tan a Wolf Fur', category = 'Tanner', station = 'hide_frame', jobs = JOBS.tanner, ingredients = { I('wolfpelt'), I('salt'), I('tanning_liquor') }, outputs = { I('tanned_fur') }, time = 10000 },
    frame_deer_hide = { label = 'Salt & Stretch a Deer Hide', category = 'Hunter', station = 'hide_frame', jobs = merge(JOBS.hunter, JOBS.tanner), ingredients = { I('deerpelt'), I('salt') }, outputs = { I('rawhide', 3) }, time = 8000 },
}

for id, r in pairs(R) do Config.HandCraft.recipes[id] = r end

-- Herbal remedies a herbalist / doctor / pharmacist also makes at the workshop: those trades only.
for _, id in ipairs({ 'grind_herb_mix', 'mash_herbal_poultice', 'brew_fever_tonic', 'mix_burn_salve',
                      'mix_camphor_salve', 'brew_cough_syrup' }) do
    local r = Config.HandCraft.recipes[id]
    if r and r.jobs == nil then r.jobs = JOBS.healers end
end

-- one chapter per trade (a player only sees the chapters of their own jobs)
Config.CraftBook = Config.CraftBook or {}
Config.CraftBook.chapters = Config.CraftBook.chapters or {}
for _, ch in ipairs({
    { 'animaltamer', 'Animal Tamer' }, { 'barber', 'Barber' }, { 'blacksmith', 'Blacksmith' },
    { 'bountyhunter', 'Bounty Hunter' }, { 'carpenter', 'Carpenter' }, { 'cooper', 'Cooper' },
    { 'doctor', 'Doctor' }, { 'farmer', 'Farmer' }, { 'fisherman', 'Fisherman' }, { 'generalstore', 'General Store' },
    { 'gunsmith', 'Gunsmith' }, { 'herbalist', 'Herbalist' }, { 'hunter', 'Hunter' }, { 'jeweller', 'Jeweller' },
    { 'journalist', 'Journalist' }, { 'pharmacist', 'Pharmacist' }, { 'printer', 'Printer' }, { 'priest', 'Priest' },
    { 'saloon', 'Saloon' }, { 'stable', 'Stable' }, { 'tailor', 'Tailor' }, { 'tanner', 'Tanner' },
    { 'traindriver', 'Train Driver' }, { 'undertaker', 'Undertaker' }, { 'wagon', 'Wagon Maker' },
}) do
    local chs = Config.CraftBook.chapters
    chs[#chs + 1] = { key = 'job_' .. ch[1], label = ch[2], categories = { ch[2] }, blurb = 'Field work for the ' .. ch[2]:lower() .. ' trade.' }
end
