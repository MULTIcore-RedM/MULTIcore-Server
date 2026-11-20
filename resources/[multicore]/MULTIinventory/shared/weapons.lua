-- ============================================================
-- MULTIinventory :: shared/weapons.lua
--
-- Weapon and ammo definitions built from public RedM game names (weapon and
-- ammo type hash names, in-game labels, magazine sizes). Game facts only - no
-- third-party inventory data is copied. Unknown WEAPON_* names still work
-- (WeaponDefs.get returns a generic definition), so add-on weapons need no
-- code change; tune them with Config.Weapons.extraDefs.
--
--   WeaponDefs.get(name)          -> def (never nil for a WEAPON_* name)
--   WeaponDefs.isKnown(name)      -> bool
--   WeaponDefs.equipSlotsFor(def) -> { 'right', 'left' } | { 'back', 'shoulder' } | { '<key>' }
--   WeaponDefs.isHandgun(def) / WeaponDefs.isLongArm(def)
--   WeaponDefs.counts(def)        -> counts toward the carried-weapons limit?
--   WeaponDefs.dualWield()        -> enabled, requireItem   (Config.Weapons.dualWield)
--   WeaponDefs.usesAmmo(def, ammoType) -> bool
--   WeaponDefs.isThrown(def) / thrownDefault(def) / thrownStackMax(def, ammoType)   (throwables)
--   AmmoDefs.get(type) -> { type, label, max } | nil      AmmoDefs.isType(type)
--
-- def = { name, label, group, weight, clip, ammoTypes = {...}, desc, kind, sidearm }
--   sidearm: true = hip holster even outside revolver/pistol (sawed-off shotgun)
--   group: revolver | pistol | repeater | rifle | sniper | shotgun | bow | melee | thrown | lasso | kit | other
--   clip : rounds held in the weapon itself (0 = fed straight from the gunbelt: bows, throwables)
-- ============================================================

WeaponDefs = WeaponDefs or {}
AmmoDefs = AmmoDefs or {}

local defs = {}

local SUFFIX = { '', '_EXPRESS', '_EXPRESS_EXPLOSIVE', '_HIGH_VELOCITY', '_SPLIT_POINT' }
local function family(base)
    local out = {}
    for i, s in ipairs(SUFFIX) do out[i] = base .. s end
    return out
end

local GROUP = {
    revolver = { weight = 1.2, ammo = family('AMMO_REVOLVER') },
    pistol   = { weight = 1.0, ammo = family('AMMO_PISTOL') },
    repeater = { weight = 3.2, ammo = family('AMMO_REPEATER') },
    rifle    = { weight = 3.8, ammo = family('AMMO_RIFLE') },
    sniper   = { weight = 4.2, ammo = family('AMMO_RIFLE') },
    shotgun  = { weight = 3.6, ammo = { 'AMMO_SHOTGUN', 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY', 'AMMO_SHOTGUN_SLUG', 'AMMO_SHOTGUN_EXPRESS_EXPLOSIVE' } },
    bow      = { weight = 1.5, ammo = { 'AMMO_ARROW', 'AMMO_ARROW_IMPROVED', 'AMMO_ARROW_FIRE', 'AMMO_ARROW_POISON', 'AMMO_ARROW_DYNAMITE', 'AMMO_ARROW_SMALL_GAME' } },
    melee    = { weight = 0.8, ammo = {} },
    thrown   = { weight = 0.3, ammo = {} },
    lasso    = { weight = 0.5, ammo = {} },
    kit      = { weight = 0.5, ammo = {} },
    other    = { weight = 1.0, ammo = {} },
}

local function add(name, label, group, clip, o)
    o = o or {}
    local g = GROUP[group]
    defs[name] = {
        name = name, label = label, group = group, clip = clip or 0,
        weight = o.weight or g.weight,
        ammoTypes = o.ammo or g.ammo,
        desc = o.desc or '',
        kind = o.kind,
        sidearm = o.sidearm,
    }
end

-- revolvers
add('WEAPON_REVOLVER_CATTLEMAN', 'Cattleman Revolver', 'revolver', 6)
add('WEAPON_REVOLVER_CATTLEMAN_MEXICAN', 'Flaco\'s Revolver', 'revolver', 6)
add('WEAPON_REVOLVER_DOUBLEACTION', 'Double-Action Revolver', 'revolver', 6)
add('WEAPON_REVOLVER_DOUBLEACTION_GAMBLER', 'Gambler\'s Double-Action', 'revolver', 6)
add('WEAPON_REVOLVER_SCHOFIELD', 'Schofield Revolver', 'revolver', 6)
add('WEAPON_REVOLVER_LEMAT', 'LeMat Revolver', 'revolver', 9)
add('WEAPON_REVOLVER_NAVY', 'Navy Revolver', 'revolver', 6)
add('WEAPON_REVOLVER_NAVY_CROSSOVER', 'Navy Revolver (Crossover)', 'revolver', 6)
-- pistols
add('WEAPON_PISTOL_VOLCANIC', 'Volcanic Pistol', 'pistol', 8)
add('WEAPON_PISTOL_M1899', 'M1899 Pistol', 'pistol', 8)
add('WEAPON_PISTOL_MAUSER', 'Mauser Pistol', 'pistol', 10)
add('WEAPON_PISTOL_SEMIAUTO', 'Semi-Automatic Pistol', 'pistol', 8)
-- repeaters
add('WEAPON_REPEATER_CARBINE', 'Carbine Repeater', 'repeater', 10)
add('WEAPON_REPEATER_WINCHESTER', 'Lancaster Repeater', 'repeater', 14)
add('WEAPON_REPEATER_HENRY', 'Litchfield Repeater', 'repeater', 16)
add('WEAPON_REPEATER_EVANS', 'Evans Repeater', 'repeater', 26)
-- rifles
add('WEAPON_RIFLE_VARMINT', 'Varmint Rifle', 'rifle', 16, { ammo = { 'AMMO_22', 'AMMO_22_TRANQUILIZER' }, weight = 3.0 })
add('WEAPON_RIFLE_SPRINGFIELD', 'Springfield Rifle', 'rifle', 1)
add('WEAPON_RIFLE_BOLTACTION', 'Bolt-Action Rifle', 'rifle', 5)
add('WEAPON_RIFLE_ELEPHANT', 'Elephant Rifle', 'rifle', 2, { ammo = { 'AMMO_RIFLE_ELEPHANT' }, weight = 5.0 })
add('WEAPON_SNIPERRIFLE_ROLLINGBLOCK', 'Rolling Block Rifle', 'sniper', 1)
add('WEAPON_SNIPERRIFLE_ROLLINGBLOCK_EXOTIC', 'Rolling Block Rifle (Exotic)', 'sniper', 1)
add('WEAPON_SNIPERRIFLE_CARCANO', 'Carcano Rifle', 'sniper', 5)
-- shotguns
add('WEAPON_SHOTGUN_DOUBLEBARREL', 'Double-Barreled Shotgun', 'shotgun', 2)
add('WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC', 'Double-Barreled Shotgun (Exotic)', 'shotgun', 2)
-- [inv_sawnoff 2026-10-10] The sawed-off is a SIDEARM in RDR2 (game fact, public RedM/RDR2 knowledge:
-- it is carried in the hip holster, SLOTID_WEAPON_0/1, attach PISTOL_R/PISTOL_L, and can be dual
-- wielded with the off-hand holster). It keeps group 'shotgun' (shells), sidearm = true picks the hips.
add('WEAPON_SHOTGUN_SAWEDOFF', 'Sawed-Off Shotgun', 'shotgun', 2, { weight = 2.4, sidearm = true })
add('WEAPON_SHOTGUN_SEMIAUTO', 'Semi-Auto Shotgun', 'shotgun', 4)
add('WEAPON_SHOTGUN_PUMP', 'Pump-Action Shotgun', 'shotgun', 5)
add('WEAPON_SHOTGUN_REPEATING', 'Repeating Shotgun', 'shotgun', 4)
-- bows
add('WEAPON_BOW', 'Bow', 'bow', 0)
add('WEAPON_BOW_IMPROVED', 'Improved Bow', 'bow', 0)
-- melee
for _, k in ipairs({ { '', 'Hunting Knife' }, { '_JAWBONE', 'Jawbone Knife' }, { '_TRADER', 'Trader Knife' },
                     { '_HORROR', 'Bone Knife' }, { '_RUSTIC', 'Rustic Knife' }, { '_CIVIL_WAR', 'Civil War Knife' },
                     { '_MINER', 'Miner Knife' }, { '_VAMPIRE', 'Ornate Dagger' } }) do
    add('WEAPON_MELEE_KNIFE' .. k[1], k[2], 'melee', 0, { kind = 'knife', weight = 0.4 })
end
add('WEAPON_MELEE_MACHETE', 'Machete', 'melee', 0)
add('WEAPON_MELEE_MACHETE_COLLECTOR', 'Collector\'s Machete', 'melee', 0)
add('WEAPON_MELEE_MACHETE_HORROR', 'Bone Machete', 'melee', 0)
add('WEAPON_MELEE_CLEAVER', 'Cleaver', 'melee', 0)
add('WEAPON_MELEE_HATCHET', 'Hatchet', 'melee', 0)
add('WEAPON_MELEE_HATCHET_HUNTER', 'Hunter Hatchet', 'melee', 0)
add('WEAPON_MELEE_HATCHET_DOUBLE_BIT', 'Double Bit Hatchet', 'melee', 0)
add('WEAPON_MELEE_HATCHET_VIKING', 'Viking Hatchet', 'melee', 0)
add('WEAPON_MELEE_HATCHET_HEWING', 'Hewing Hatchet', 'melee', 0)
add('WEAPON_MELEE_ANCIENT_HATCHET', 'Ancient Hatchet', 'melee', 0)
add('WEAPON_MELEE_HAMMER', 'Hammer', 'melee', 0)
add('WEAPON_MELEE_TORCH', 'Torch', 'melee', 0, { kind = 'light' })
add('WEAPON_MELEE_LANTERN', 'Lantern', 'kit', 0, { kind = 'light' })
add('WEAPON_MELEE_DAVY_LANTERN', 'Davy Lantern', 'kit', 0, { kind = 'light' })
-- thrown (the "ammo" of a throwable is the number carried; no clip)
add('WEAPON_THROWN_THROWING_KNIVES', 'Throwing Knives', 'thrown', 0, { ammo = { 'AMMO_THROWING_KNIVES', 'AMMO_THROWING_KNIVES_IMPROVED', 'AMMO_THROWING_KNIVES_POISON' } })
add('WEAPON_THROWN_TOMAHAWK', 'Tomahawk', 'thrown', 0, { ammo = { 'AMMO_TOMAHAWK', 'AMMO_TOMAHAWK_IMPROVED', 'AMMO_TOMAHAWK_HOMING' } })
add('WEAPON_THROWN_TOMAHAWK_ANCIENT', 'Ancient Tomahawk', 'thrown', 0, { ammo = { 'AMMO_TOMAHAWK_ANCIENT' } })
add('WEAPON_THROWN_DYNAMITE', 'Dynamite', 'thrown', 0, { ammo = { 'AMMO_DYNAMITE', 'AMMO_DYNAMITE_VOLATILE' } })
add('WEAPON_THROWN_MOLOTOV', 'Fire Bottle', 'thrown', 0, { ammo = { 'AMMO_MOLOTOV', 'AMMO_MOLOTOV_VOLATILE' } })
add('WEAPON_THROWN_BOLAS', 'Bolas', 'thrown', 0, { ammo = { 'AMMO_BOLAS' } })
add('WEAPON_THROWN_BOLAS_HAWKMOTH', 'Hawkmoth Bolas', 'thrown', 0, { ammo = { 'AMMO_BOLAS_HAWKMOTH' } })
add('WEAPON_THROWN_BOLAS_IRONSPIKED', 'Ironspiked Bolas', 'thrown', 0, { ammo = { 'AMMO_BOLAS_IRONSPIKED' } })
add('WEAPON_THROWN_BOLAS_INTERTWINED', 'Intertwined Bolas', 'thrown', 0, { ammo = { 'AMMO_BOLAS_INTERTWINED' } })
add('WEAPON_THROWN_POISONBOTTLE', 'Poison Bottle', 'thrown', 0, { ammo = { 'AMMO_POISONBOTTLE' } })
-- lasso
add('WEAPON_LASSO', 'Lasso', 'lasso', 0)
add('WEAPON_LASSO_REINFORCED', 'Reinforced Lasso', 'lasso', 0)
-- kit
add('WEAPON_KIT_BINOCULARS', 'Binoculars', 'kit', 0)
add('WEAPON_KIT_BINOCULARS_IMPROVED', 'Improved Binoculars', 'kit', 0)
add('WEAPON_KIT_CAMERA', 'Camera', 'kit', 0)
add('WEAPON_KIT_CAMERA_ADVANCED', 'Advanced Camera', 'kit', 0)
add('WEAPON_KIT_METAL_DETECTOR', 'Metal Detector', 'kit', 0)
add('WEAPON_FISHINGROD', 'Fishing Rod', 'kit', 0)

-- ------------------------------------------------------------
-- ammo types (label, default gunbelt maximum; Config.Weapons.ammoMax overrides)
-- ------------------------------------------------------------
local ammoDefs = {}
local function ammo(t, label, max) ammoDefs[t] = { type = t, label = label, max = max } end
local VARIANT = { [''] = '', _EXPRESS = 'Express ', _EXPRESS_EXPLOSIVE = 'Explosive ', _HIGH_VELOCITY = 'High Velocity ', _SPLIT_POINT = 'Split Point ' }
for base, info in pairs({ AMMO_REVOLVER = { 'Revolver Cartridges', 150 }, AMMO_PISTOL = { 'Pistol Cartridges', 150 },
                          AMMO_REPEATER = { 'Repeater Cartridges', 200 }, AMMO_RIFLE = { 'Rifle Cartridges', 100 } }) do
    for s, pre in pairs(VARIANT) do ammo(base .. s, pre .. info[1], info[2]) end
end
ammo('AMMO_22', 'Varmint Cartridges', 200)
ammo('AMMO_22_TRANQUILIZER', 'Tranquilizer Cartridges', 50)
ammo('AMMO_RIFLE_ELEPHANT', 'Elephant Rifle Cartridges', 30)
ammo('AMMO_SHOTGUN', 'Shotgun Shells', 60)
ammo('AMMO_SHOTGUN_BUCKSHOT_INCENDIARY', 'Incendiary Buckshot', 30)
ammo('AMMO_SHOTGUN_SLUG', 'Shotgun Slugs', 60)
ammo('AMMO_SHOTGUN_EXPRESS_EXPLOSIVE', 'Explosive Slugs', 30)
ammo('AMMO_ARROW', 'Arrows', 60)
ammo('AMMO_ARROW_IMPROVED', 'Improved Arrows', 40)
ammo('AMMO_ARROW_FIRE', 'Fire Arrows', 20)
ammo('AMMO_ARROW_POISON', 'Poison Arrows', 20)
ammo('AMMO_ARROW_DYNAMITE', 'Dynamite Arrows', 10)
ammo('AMMO_ARROW_SMALL_GAME', 'Small Game Arrows', 40)
ammo('AMMO_THROWING_KNIVES', 'Throwing Knives', 10)
ammo('AMMO_THROWING_KNIVES_IMPROVED', 'Improved Throwing Knives', 10)
ammo('AMMO_THROWING_KNIVES_POISON', 'Poison Throwing Knives', 10)
ammo('AMMO_TOMAHAWK', 'Tomahawks', 5)
ammo('AMMO_TOMAHAWK_IMPROVED', 'Improved Tomahawks', 5)
ammo('AMMO_TOMAHAWK_HOMING', 'Homing Tomahawks', 5)
ammo('AMMO_TOMAHAWK_ANCIENT', 'Ancient Tomahawks', 5)
ammo('AMMO_DYNAMITE', 'Dynamite', 6)
ammo('AMMO_DYNAMITE_VOLATILE', 'Volatile Dynamite', 6)
ammo('AMMO_MOLOTOV', 'Fire Bottles', 6)
ammo('AMMO_MOLOTOV_VOLATILE', 'Volatile Fire Bottles', 6)
ammo('AMMO_BOLAS', 'Bolas', 5)
ammo('AMMO_BOLAS_HAWKMOTH', 'Hawkmoth Bolas', 5)
ammo('AMMO_BOLAS_IRONSPIKED', 'Ironspiked Bolas', 5)
ammo('AMMO_BOLAS_INTERTWINED', 'Intertwined Bolas', 5)
ammo('AMMO_POISONBOTTLE', 'Poison Bottles', 6)

-- ------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------
local function prettyName(name)
    local s = tostring(name):upper():gsub('^WEAPON_', ''):gsub('_', ' '):lower()
    return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end

local function cfg() return (Config and Config.Weapons) or {} end

function WeaponDefs.isKnown(name)
    if type(name) ~= 'string' then return false end
    local up = name:upper()
    return defs[up] ~= nil or (cfg().extraDefs or {})[up] ~= nil
end

function WeaponDefs.get(name)
    if type(name) ~= 'string' then return nil end
    local up = name:upper()
    if up:sub(1, 7) ~= 'WEAPON_' then return nil end
    local d = defs[up]
    local extra = (cfg().extraDefs or {})[up]
    if extra then
        local base = d or { name = up, label = prettyName(up), group = 'other', clip = 0, weight = GROUP.other.weight, ammoTypes = {}, desc = '' }
        local out = {}
        for k, v in pairs(base) do out[k] = v end
        for k, v in pairs(extra) do out[k] = v end
        out.name = up
        return out
    end
    if d then return d end
    -- unknown add-on weapon: generic definition (group guessed from the name)
    local g = 'other'
    for _, k in ipairs({ 'REVOLVER', 'PISTOL', 'REPEATER', 'SNIPERRIFLE', 'RIFLE', 'SHOTGUN', 'BOW', 'MELEE', 'THROWN', 'LASSO', 'KIT' }) do
        if up:find(k, 1, true) then
            g = (k == 'SNIPERRIFLE') and 'sniper' or k:lower()
            break
        end
    end
    local gg = GROUP[g] or GROUP.other
    -- [inv_sawnoff] sawed-off variants (add-on names) are sidearms like the base game one
    local side = up:find('SAWEDOFF', 1, true) ~= nil or nil
    return { name = up, label = prettyName(up), group = g, clip = 0, weight = gg.weight, ammoTypes = gg.ammo, desc = '', generic = true, sidearm = side }
end

function WeaponDefs.all() return defs end

local HANDGUN = { revolver = true, pistol = true }
local LONGARM = { repeater = true, rifle = true, sniper = true, shotgun = true }

-- [inv_sawnoff] Sidearm = holstered on the hip (right / left off-hand) and drawn from the holster:
-- every revolver and pistol plus any def flagged sidearm = true (the sawed-off shotgun; add-ons
-- via Config.Weapons.extraDefs { sidearm = true }). sidearm = false forces a revolver/pistol off.
function WeaponDefs.isHandgun(def)
    if def == nil then return false end
    if def.sidearm ~= nil then return def.sidearm == true end
    return HANDGUN[def.group] == true
end
WeaponDefs.isSidearm = WeaponDefs.isHandgun
function WeaponDefs.isLongArm(def) return def ~= nil and not WeaponDefs.isHandgun(def) and LONGARM[def.group] == true end

---The third sidearm (Config.Weapons.extraSidearm) is switched on and its virtual slot exists.
function WeaponDefs.extraOn()
    local c = Config.Weapons or {}
    return type(c.extraSidearm) == 'table' and c.extraSidearm.enabled == true and type((c.slots or {}).extra) == 'table'
end

---Is a slot key virtual (not on the ped: the extra sidearm)?
function WeaponDefs.isVirtualSlot(key)
    local s = ((Config.Weapons or {}).slots or {})[key]
    return type(s) == 'table' and s.virtual == true
end

---Equip slot keys a weapon may use, in order of preference.
function WeaponDefs.equipSlotsFor(def)
    if not def then return { 'other' } end
    if WeaponDefs.isHandgun(def) then
        if WeaponDefs.extraOn() then return { 'right', 'left', 'extra' } end
        return { 'right', 'left' }
    end
    if LONGARM[def.group] then
        -- Config.Weapons.longArmSlots = { 'back' } -> one long arm only (default: back + shoulder)
        local la = (Config.Weapons or {}).longArmSlots
        if type(la) == 'table' and #la > 0 then return { table.unpack(la) } end
        return { 'back', 'shoulder' }
    end
    if def.group == 'melee' then return { def.kind == 'knife' and 'knife' or 'melee' } end
    if def.group == 'bow' or def.group == 'lasso' or def.group == 'thrown' then return { def.group } end
    -- kit + unknown: one slot per weapon name (binoculars and a lantern can both be carried)
    return { 'kit:' .. def.name }
end

---Dual wield settings -> enabled (bool), requireItem (string|nil).
---Config.Weapons.dualWield = { enabled, requireItem } (or a plain boolean from older configs).
function WeaponDefs.dualWield()
    local d = cfg().dualWield
    if type(d) == 'table' then
        local item = d.requireItem
        if type(item) ~= 'string' or item == '' then item = nil end
        return d.enabled ~= false, item
    end
    return d ~= false, nil
end

---Counts toward the carried-weapons limit (Config.Weapons.maxCarried)?
function WeaponDefs.counts(def)
    if not def then return true end
    local c = cfg()
    if (c.notCountedNames or {})[def.name] then return false end
    return not (c.notCountedGroups or {})[def.group]
end

---Throwable (dynamite, fire bottle, tomahawk, knives, bolas, poison bottle)? Its row's ammo IS the
---stack: { [AMMO_X] = n } = n of them to throw (never fed from a magazine, never capped by def.clip).
function WeaponDefs.isThrown(def) return def ~= nil and def.group == 'thrown' end

---Count a throwable row gets when it is created without ammo (Config.Weapons.thrown.defaultCount):
---1 for every throwable (one item = one to throw), except a knife sheath (knives come as belt ammo).
function WeaponDefs.thrownDefault(def)
    if not WeaponDefs.isThrown(def) then return 0 end
    local t = cfg().thrown or {}
    local n = (t.defaultCount or {})[def.name]
    if n == nil then n = t.defaultCountAll end
    n = math.tointeger(tonumber(n) or 1) or 1
    return n < 0 and 0 or n
end

---Most of one throwable a single inventory stack holds (Config.Weapons.thrown.stackMax, else the
---ammo type's gunbelt maximum, AmmoDefs / Config.Weapons.ammoMax).
function WeaponDefs.thrownStackMax(def, ammoType)
    local t = cfg().thrown or {}
    local n = tonumber((t.stackMax or {})[def and def.name or ''])
    if not n then
        local a = AmmoDefs.get(ammoType)
        n = a and a.max or 10
    end
    n = math.tointeger(math.floor(n)) or 10
    return n < 1 and 1 or n
end

function WeaponDefs.usesAmmo(def, ammoType)
    if not def then return false end
    for _, t in ipairs(def.ammoTypes or {}) do if t == ammoType then return true end end
    return false
end

function AmmoDefs.get(t)
    if type(t) ~= 'string' then return nil end
    local d = ammoDefs[t:upper()]
    if not d then return nil end
    local mx = (cfg().ammoMax or {})[d.type]
    if mx then return { type = d.type, label = d.label, max = mx } end
    return d
end

function AmmoDefs.isType(t) return AmmoDefs.get(t) ~= nil end
function AmmoDefs.all() return ammoDefs end
