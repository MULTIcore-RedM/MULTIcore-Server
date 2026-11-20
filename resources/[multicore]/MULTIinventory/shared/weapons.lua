-- ============================================================
-- MULTIinventory :: weapon and ammo data (shared, client + server)
--
-- MULTIInvData.Weapons[name]  = { name, hash, group, ammoTypes = { 'AMMO_..', ... },
--                                 ammoType (default), thrown, melee, noAmmo, weight }
-- MULTIInvData.Ammo[AMMO_X]   = { name, hash, item, max, refill, verified }
-- MULTIInvData.AmmoItems[item]= 'AMMO_X'      (an item that IS rounds of that ammo)
-- MULTIInvData.AmmoBoxes[item]= { ammo = 'AMMO_X', rounds = n }   (filled from Config at start)
--
-- Weapon names and groups follow MULTIcore's shared/weapons.lua (RSGShared.Weapons).
-- Ammo type names, max / refill values and the ammo box -> ammo table come from
-- RSG v2's rsg-ammo (config.lua) and rsg-weapons (Config.ThrowableWeaponAmmoTypes),
-- GPL v3, by the RSG / Rexshack-RedM team (see CREDITS.md).
--
-- verified = 'game'  : joaat(name) is a value of redm-info Weapons.cs `AmmoType`
--                      (or the name is quoted in femga natives.json)
-- verified = 'rsg'   : name taken from rsg-ammo's data (used there with joaat), not
--                      found in the local game-data files
-- ============================================================

MULTIInvData = MULTIInvData or {}

local VAR = { '', '_EXPRESS', '_EXPRESS_EXPLOSIVE', '_HIGH_VELOCITY', '_SPLIT_POINT' }
local function family(base)
    local t = {}
    for i = 1, #VAR do t[i] = base .. VAR[i] end
    return t
end

-- ammo type -> { max (most a ped carries), refill (rounds per box / per use), verified, item }
-- item = the satchel item that holds rounds of this type (nil -> generated 'ammo_<lower name>')
local AMMO = {
    AMMO_REVOLVER                    = { 200, 12, 'game' },
    AMMO_REVOLVER_EXPRESS            = { 200, 12, 'rsg' },
    AMMO_REVOLVER_EXPRESS_EXPLOSIVE  = { 10, 10, 'rsg' },
    AMMO_REVOLVER_HIGH_VELOCITY      = { 200, 12, 'rsg' },
    AMMO_REVOLVER_SPLIT_POINT        = { 200, 12, 'rsg' },
    AMMO_PISTOL                      = { 100, 12, 'game' },
    AMMO_PISTOL_EXPRESS              = { 100, 12, 'rsg' },
    AMMO_PISTOL_EXPRESS_EXPLOSIVE    = { 10, 10, 'rsg' },
    AMMO_PISTOL_HIGH_VELOCITY        = { 100, 12, 'rsg' },
    AMMO_PISTOL_SPLIT_POINT          = { 50, 12, 'rsg' },
    AMMO_REPEATER                    = { 200, 12, 'game' },
    AMMO_REPEATER_EXPRESS            = { 200, 12, 'rsg' },
    AMMO_REPEATER_EXPRESS_EXPLOSIVE  = { 10, 10, 'rsg' },
    AMMO_REPEATER_HIGH_VELOCITY      = { 200, 12, 'rsg' },
    AMMO_REPEATER_SPLIT_POINT        = { 100, 12, 'rsg' },
    AMMO_RIFLE                       = { 100, 12, 'game' },
    AMMO_RIFLE_EXPRESS               = { 100, 12, 'rsg' },
    AMMO_RIFLE_EXPRESS_EXPLOSIVE     = { 10, 10, 'rsg' },
    AMMO_RIFLE_HIGH_VELOCITY         = { 100, 12, 'rsg' },
    AMMO_RIFLE_SPLIT_POINT           = { 50, 12, 'rsg' },
    AMMO_RIFLE_ELEPHANT              = { 20, 10, 'rsg' },
    AMMO_22                          = { 100, 12, 'game' },
    AMMO_22_TRANQUILIZER             = { 200, 12, 'rsg' },
    AMMO_SHOTGUN                     = { 60, 12, 'game' },
    AMMO_SHOTGUN_BUCKSHOT_INCENDIARY = { 14, 7, 'rsg' },
    AMMO_SHOTGUN_SLUG                = { 60, 12, 'rsg' },
    AMMO_SHOTGUN_SLUG_EXPLOSIVE      = { 10, 10, 'rsg' },
    AMMO_ARROW                       = { 40, 10, 'game', 'ammo_arrow_single' },
    AMMO_ARROW_SMALL_GAME            = { 40, 10, 'rsg', 'ammo_arrow_small_single' },
    AMMO_ARROW_FIRE                  = { 8, 3, 'rsg', 'ammo_arrow_fire_single' },
    AMMO_ARROW_POISON                = { 8, 2, 'rsg', 'ammo_arrow_poison_single' },
    AMMO_ARROW_DYNAMITE              = { 8, 1, 'rsg', 'ammo_arrow_dynamite_single' },
    -- thrown: the weapon item itself is the ammo (its stack count)
    AMMO_THROWING_KNIVES             = { 8, 1, 'game', 'weapon_thrown_throwing_knives' },
    AMMO_THROWING_KNIVES_DRAIN       = { 8, 1, 'rsg', 'ammo_throwing_knives_drain' },
    AMMO_THROWING_KNIVES_POISON      = { 8, 1, 'rsg', 'ammo_throwing_knives_poison' },
    AMMO_TOMAHAWK                    = { 3, 1, 'game', 'weapon_thrown_tomahawk' },
    AMMO_TOMAHAWK_ANCIENT            = { 1, 1, 'game', 'weapon_thrown_tomahawk_ancient' },
    AMMO_DYNAMITE                    = { 8, 1, 'game', 'weapon_thrown_dynamite' },
    AMMO_MOLOTOV                     = { 8, 1, 'game', 'weapon_thrown_molotov' },
    AMMO_POISONBOTTLE                = { 8, 1, 'game', 'weapon_thrown_poisonbottle' },
    AMMO_BOLAS                       = { 3, 1, 'rsg', 'weapon_thrown_bolas' },
    AMMO_BOLAS_HAWKMOTH              = { 3, 1, 'rsg', 'weapon_thrown_bolas_hawkmoth' },
    AMMO_BOLAS_INTERTWINED           = { 3, 1, 'rsg', 'weapon_thrown_bolas_intertwined' },
    AMMO_BOLAS_IRONSPIKED            = { 3, 1, 'rsg', 'weapon_thrown_bolas_ironspiked' },
    AMMO_HATCHET                     = { 1, 1, 'game', 'weapon_melee_hatchet' },
    AMMO_HATCHET_HUNTER              = { 1, 1, 'game', 'weapon_melee_hatchet_hunter' },
    AMMO_HATCHET_DOUBLE_BIT          = { 1, 1, 'game', 'weapon_melee_hatchet_double_bit' },
    AMMO_HATCHET_CLEAVER             = { 1, 1, 'game', 'weapon_melee_cleaver' },
}

-- weapon name -> { group, ammo (list or nil), thrown?, weight (grams, used only when the item is generated) }
local W = {}
local function add(names, group, ammo, opts)
    for _, n in ipairs(names) do
        W[n] = { group = group, ammo = ammo, thrown = opts and opts.thrown or false, weight = opts and opts.weight or 1000 }
    end
end
add({ 'weapon_revolver_cattleman', 'weapon_revolver_cattleman_mexican', 'weapon_revolver_doubleaction',
      'weapon_revolver_doubleaction_gambler', 'weapon_revolver_schofield', 'weapon_revolver_lemat',
      'weapon_revolver_navy', 'weapon_revolver_navy_crossover' }, 'revolver', family('AMMO_REVOLVER'))
add({ 'weapon_pistol_volcanic', 'weapon_pistol_m1899', 'weapon_pistol_mauser', 'weapon_pistol_semiauto' },
    'pistol', family('AMMO_PISTOL'))
add({ 'weapon_repeater_carbine', 'weapon_repeater_winchester', 'weapon_repeater_henry', 'weapon_repeater_evans' },
    'repeater', family('AMMO_REPEATER'), { weight = 2500 })
add({ 'weapon_rifle_springfield', 'weapon_rifle_boltaction' }, 'rifle', family('AMMO_RIFLE'), { weight = 3500 })
add({ 'weapon_sniperrifle_rollingblock', 'weapon_sniperrifle_rollingblock_exotic', 'weapon_sniperrifle_carcano' },
    'sniper', family('AMMO_RIFLE'), { weight = 4000 })
add({ 'weapon_rifle_elephant' }, 'rifle', { 'AMMO_RIFLE_ELEPHANT' }, { weight = 5000 })
add({ 'weapon_rifle_varmint' }, 'varmint', { 'AMMO_22', 'AMMO_22_TRANQUILIZER' }, { weight = 2500 })
add({ 'weapon_shotgun_doublebarrel', 'weapon_shotgun_doublebarrel_exotic', 'weapon_shotgun_sawedoff',
      'weapon_shotgun_semiauto', 'weapon_shotgun_pump', 'weapon_shotgun_repeating' }, 'shotgun',
    { 'AMMO_SHOTGUN', 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY', 'AMMO_SHOTGUN_SLUG', 'AMMO_SHOTGUN_SLUG_EXPLOSIVE' }, { weight = 3500 })
add({ 'weapon_bow', 'weapon_bow_improved' }, 'bow',
    { 'AMMO_ARROW', 'AMMO_ARROW_SMALL_GAME', 'AMMO_ARROW_FIRE', 'AMMO_ARROW_POISON', 'AMMO_ARROW_DYNAMITE' }, { weight = 1500 })
-- no ammo
add({ 'weapon_lasso', 'weapon_lasso_reinforced' }, 'lasso', nil, { weight = 800 })
add({ 'weapon_melee_knife', 'weapon_melee_knife_jawbone', 'weapon_melee_knife_trader', 'weapon_melee_knife_horror',
      'weapon_melee_knife_rustic', 'weapon_melee_machete', 'weapon_melee_machete_horror',
      'weapon_melee_machete_collector', 'weapon_melee_torch' }, 'melee', nil, { weight = 700 })
add({ 'weapon_melee_davy_lantern', 'weapon_melee_lantern', 'weapon_melee_lantern_halloween', 'weapon_kit_binoculars',
      'weapon_kit_binoculars_improved', 'weapon_kit_camera', 'weapon_kit_camera_advanced', 'weapon_kit_metal_detector' },
    'held', nil, { weight = 1000 })
add({ 'weapon_fishingrod' }, 'fishing', nil, { weight = 1000 })
-- thrown: stackable, the count is the ammo
add({ 'weapon_thrown_throwing_knives' }, 'thrown', { 'AMMO_THROWING_KNIVES', 'AMMO_THROWING_KNIVES_DRAIN', 'AMMO_THROWING_KNIVES_POISON' }, { thrown = true, weight = 150 })
add({ 'weapon_thrown_tomahawk' }, 'thrown', { 'AMMO_TOMAHAWK' }, { thrown = true, weight = 700 })
add({ 'weapon_thrown_tomahawk_ancient' }, 'thrown', { 'AMMO_TOMAHAWK_ANCIENT' }, { thrown = true, weight = 700 })
add({ 'weapon_thrown_dynamite' }, 'thrown', { 'AMMO_DYNAMITE' }, { thrown = true, weight = 300 })
add({ 'weapon_thrown_molotov' }, 'thrown', { 'AMMO_MOLOTOV' }, { thrown = true, weight = 500 })
add({ 'weapon_thrown_poisonbottle' }, 'thrown', { 'AMMO_POISONBOTTLE' }, { thrown = true, weight = 300 })
add({ 'weapon_thrown_bolas' }, 'thrown', { 'AMMO_BOLAS' }, { thrown = true, weight = 400 })
add({ 'weapon_thrown_bolas_hawkmoth' }, 'thrown', { 'AMMO_BOLAS_HAWKMOTH' }, { thrown = true, weight = 400 })
add({ 'weapon_thrown_bolas_intertwined' }, 'thrown', { 'AMMO_BOLAS_INTERTWINED' }, { thrown = true, weight = 400 })
add({ 'weapon_thrown_bolas_ironspiked' }, 'thrown', { 'AMMO_BOLAS_IRONSPIKED' }, { thrown = true, weight = 400 })
add({ 'weapon_melee_hatchet' }, 'thrown', { 'AMMO_HATCHET' }, { thrown = true, weight = 800 })
add({ 'weapon_melee_hatchet_hunter' }, 'thrown', { 'AMMO_HATCHET_HUNTER' }, { thrown = true, weight = 800 })
add({ 'weapon_melee_hatchet_double_bit' }, 'thrown', { 'AMMO_HATCHET_DOUBLE_BIT' }, { thrown = true, weight = 900 })
add({ 'weapon_melee_cleaver' }, 'thrown', { 'AMMO_HATCHET_CLEAVER' }, { thrown = true, weight = 700 })

local hashOf = GetHashKey

MULTIInvData.Ammo = {}
MULTIInvData.AmmoItems = {}
for name, d in pairs(AMMO) do
    local item = d[4] or ('ammo_' .. name:lower():gsub('^ammo_', ''))
    MULTIInvData.Ammo[name] = { name = name, hash = hashOf(name), max = d[1], refill = d[2], verified = d[3], item = item }
    MULTIInvData.AmmoItems[item] = name
end

MULTIInvData.Weapons = {}
for name, d in pairs(W) do
    MULTIInvData.Weapons[name] = {
        name = name,
        hash = hashOf(name),
        group = d.group,
        type = d.group,      -- same as group (revolver, pistol, repeater, rifle, sniper, varmint, shotgun, bow, thrown, melee, lasso, held, fishing)
        ammoTypes = d.ammo or {},
        ammoType = d.ammo and d.ammo[1] or nil,
        thrown = d.thrown,
        melee = (d.group == 'melee' or d.group == 'thrown') and not name:find('^weapon_thrown_') and true or false,
        noAmmo = d.ammo == nil,
        weight = d.weight,
    }
end

-- filled on start from Config.Ammo.Boxes (box item -> ammo type) and Config.Ammo.BoxRounds
MULTIInvData.AmmoBoxes = MULTIInvData.AmmoBoxes or {}

--- Weapon data by name or by hash (nil when the name is not a known weapon).
function MULTIInvData.GetWeapon(nameOrHash)
    if type(nameOrHash) == 'string' then return MULTIInvData.Weapons[nameOrHash:lower()] end
    for _, w in pairs(MULTIInvData.Weapons) do
        if w.hash == nameOrHash then return w end
    end
end
