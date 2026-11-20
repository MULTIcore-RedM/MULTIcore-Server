-- ============================================================
-- MULTIinventory :: vorp_inventory face - ammunition
-- VORP keeps ammo per character as { AMMO_REVOLVER = 24, ... }.
-- MULTIinventory keeps ammo as items in the satchel, one item = one
-- round, and thrown weapons (knives, tomahawks, bolas, dynamite,
-- molotovs, poison bottles, hatchets) as their own weapon items: the
-- "ammo" of a thrown type is how many of those items the player has.
--
-- Where the engine publishes its own tables they win:
--   MULTIInv.WeaponData[name] = { hash, type, ammoTypes = {...}, thrown }
--   MULTIInv.AmmoItems[item]  = 'AMMO_X'   (also read: AmmoItemTypes, AmmoMap)
-- The tables below are the fallback, and fill any type the engine
-- does not map. AMMO_* names: the game's ammo type names, as listed by
-- RSG v2 rsg-ammo / rsg-weapons (GPL v3).
-- ============================================================

local V = MULTIVorp

-- AMMO type -> satchel item (one item = one round). Fallback only.
V.AmmoItemDefault = {
    -- revolver
    AMMO_REVOLVER                    = 'ammo_revolver',
    AMMO_REVOLVER_EXPRESS            = 'ammo_revolver_express',
    AMMO_REVOLVER_EXPRESS_EXPLOSIVE  = 'ammo_revolver_express_explosive',
    AMMO_REVOLVER_HIGH_VELOCITY      = 'ammo_revolver_high_velocity',
    AMMO_REVOLVER_SPLIT_POINT        = 'ammo_revolver_split_point',
    -- pistol
    AMMO_PISTOL                      = 'ammo_pistol',
    AMMO_PISTOL_EXPRESS              = 'ammo_pistol_express',
    AMMO_PISTOL_EXPRESS_EXPLOSIVE    = 'ammo_pistol_express_explosive',
    AMMO_PISTOL_HIGH_VELOCITY        = 'ammo_pistol_high_velocity',
    AMMO_PISTOL_SPLIT_POINT          = 'ammo_pistol_split_point',
    -- repeater
    AMMO_REPEATER                    = 'ammo_repeater',
    AMMO_REPEATER_EXPRESS            = 'ammo_repeater_express',
    AMMO_REPEATER_EXPRESS_EXPLOSIVE  = 'ammo_repeater_express_explosive',
    AMMO_REPEATER_HIGH_VELOCITY      = 'ammo_repeater_high_velocity',
    AMMO_REPEATER_SPLIT_POINT        = 'ammo_repeater_split_point',
    -- rifle
    AMMO_RIFLE                       = 'ammo_rifle',
    AMMO_RIFLE_EXPRESS               = 'ammo_rifle_express',
    AMMO_RIFLE_EXPRESS_EXPLOSIVE     = 'ammo_rifle_express_explosive',
    AMMO_RIFLE_HIGH_VELOCITY         = 'ammo_rifle_high_velocity',
    AMMO_RIFLE_SPLIT_POINT           = 'ammo_rifle_split_point',
    AMMO_RIFLE_ELEPHANT              = 'ammo_rifle_elephant',
    -- varmint rifle
    AMMO_22                          = 'ammo_22',
    AMMO_22_TRANQUILIZER             = 'ammo_22_tranquilizer',
    -- shotgun
    AMMO_SHOTGUN                     = 'ammo_shotgun',
    AMMO_SHOTGUN_BUCKSHOT_INCENDIARY = 'ammo_shotgun_buckshot_incendiary',
    AMMO_SHOTGUN_SLUG                = 'ammo_shotgun_slug',
    AMMO_SHOTGUN_SLUG_EXPLOSIVE      = 'ammo_shotgun_slug_explosive',
    -- arrows (the item names RSG already uses)
    AMMO_ARROW                       = 'ammo_arrow',
    AMMO_ARROW_SMALL_GAME            = 'ammo_arrow_small',
    AMMO_ARROW_FIRE                  = 'ammo_arrow_fire',
    AMMO_ARROW_POISON                = 'ammo_arrow_poison',
    AMMO_ARROW_DYNAMITE              = 'ammo_arrow_dynamite',
    -- throwing-knife variants have no weapon of their own: rounds items
    AMMO_THROWING_KNIVES_DRAIN       = 'ammo_throwing_knives_drain',
    AMMO_THROWING_KNIVES_POISON      = 'ammo_throwing_knives_poison',
}

-- AMMO type of a thrown weapon -> the weapon item (counted as ammo). Fallback only.
V.ThrownDefault = {
    AMMO_THROWING_KNIVES   = 'weapon_thrown_throwing_knives',
    AMMO_TOMAHAWK          = 'weapon_thrown_tomahawk',
    AMMO_TOMAHAWK_ANCIENT  = 'weapon_thrown_tomahawk_ancient',
    AMMO_BOLAS             = 'weapon_thrown_bolas',
    AMMO_BOLAS_HAWKMOTH    = 'weapon_thrown_bolas_hawkmoth',
    AMMO_BOLAS_INTERTWINED = 'weapon_thrown_bolas_intertwined',
    AMMO_BOLAS_IRONSPIKED  = 'weapon_thrown_bolas_ironspiked',
    AMMO_DYNAMITE          = 'weapon_thrown_dynamite',
    AMMO_MOLOTOV           = 'weapon_thrown_molotov',
    AMMO_POISONBOTTLE      = 'weapon_thrown_poisonbottle',
    AMMO_HATCHET           = 'weapon_melee_hatchet',
    AMMO_HATCHET_HUNTER    = 'weapon_melee_hatchet_hunter',
    AMMO_HATCHET_CLEAVER   = 'weapon_melee_cleaver',
}

-- Weapon family -> the ammo types it takes (first = the plain one).
local FAMILY = {
    revolver = { 'AMMO_REVOLVER', 'AMMO_REVOLVER_EXPRESS', 'AMMO_REVOLVER_EXPRESS_EXPLOSIVE', 'AMMO_REVOLVER_HIGH_VELOCITY', 'AMMO_REVOLVER_SPLIT_POINT' },
    pistol   = { 'AMMO_PISTOL', 'AMMO_PISTOL_EXPRESS', 'AMMO_PISTOL_EXPRESS_EXPLOSIVE', 'AMMO_PISTOL_HIGH_VELOCITY', 'AMMO_PISTOL_SPLIT_POINT' },
    repeater = { 'AMMO_REPEATER', 'AMMO_REPEATER_EXPRESS', 'AMMO_REPEATER_EXPRESS_EXPLOSIVE', 'AMMO_REPEATER_HIGH_VELOCITY', 'AMMO_REPEATER_SPLIT_POINT' },
    rifle    = { 'AMMO_RIFLE', 'AMMO_RIFLE_EXPRESS', 'AMMO_RIFLE_EXPRESS_EXPLOSIVE', 'AMMO_RIFLE_HIGH_VELOCITY', 'AMMO_RIFLE_SPLIT_POINT' },
    elephant = { 'AMMO_RIFLE_ELEPHANT' },
    varmint  = { 'AMMO_22', 'AMMO_22_TRANQUILIZER' },
    shotgun  = { 'AMMO_SHOTGUN', 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY', 'AMMO_SHOTGUN_SLUG', 'AMMO_SHOTGUN_SLUG_EXPLOSIVE' },
    bow      = { 'AMMO_ARROW', 'AMMO_ARROW_SMALL_GAME', 'AMMO_ARROW_FIRE', 'AMMO_ARROW_POISON', 'AMMO_ARROW_DYNAMITE' },
    knives   = { 'AMMO_THROWING_KNIVES', 'AMMO_THROWING_KNIVES_DRAIN', 'AMMO_THROWING_KNIVES_POISON' },
}

local function familyOf(name)
    name = name:lower()
    if name:find('^weapon_rifle_elephant') then return FAMILY.elephant end
    if name:find('^weapon_rifle_varmint') then return FAMILY.varmint end
    if name:find('^weapon_revolver_') then return FAMILY.revolver end
    if name:find('^weapon_pistol_') then return FAMILY.pistol end
    if name:find('^weapon_repeater_') then return FAMILY.repeater end
    if name:find('^weapon_rifle_') or name:find('^weapon_sniperrifle_') then return FAMILY.rifle end
    if name:find('^weapon_shotgun_') then return FAMILY.shotgun end
    if name:find('^weapon_bow') then return FAMILY.bow end
    if name == 'weapon_thrown_throwing_knives' then return FAMILY.knives end
    return nil
end

-- ------------------------------------------------------------
-- The engine's tables (read defensively; any of them may be missing)
-- ------------------------------------------------------------
--- MULTIInv.WeaponData (engine), else MULTIInvData.Weapons (shared/weapons.lua)
function V.WeaponDataTable()
    local wd = MULTIInv and MULTIInv.WeaponData
    if type(wd) == 'table' then return wd end
    if type(MULTIInvData) == 'table' and type(MULTIInvData.Weapons) == 'table' then return MULTIInvData.Weapons end
    return nil
end

local function engineWeaponData(name)
    local wd = V.WeaponDataTable()
    if type(wd) ~= 'table' or type(name) ~= 'string' then return nil end
    return wd[name] or wd[name:lower()] or wd[name:upper()]
end

local function engineAmmoItems()
    local E = MULTIInv
    if E then
        for _, key in ipairs({ 'AmmoItems', 'AmmoItemTypes', 'AmmoMap' }) do
            if type(E[key]) == 'table' then return E[key] end
        end
    end
    -- shared/weapons.lua (engine): MULTIInvData.AmmoItems[item] = 'AMMO_X'
    if type(MULTIInvData) == 'table' and type(MULTIInvData.AmmoItems) == 'table' then return MULTIInvData.AmmoItems end
    return nil
end

-- built maps (rebuilt when the engine's tables change size)
local typeToItem, itemToType, thrownType, built = {}, {}, {}, nil

local function signature()
    local n = 0
    local wd = V.WeaponDataTable()
    if type(wd) == 'table' then for _ in pairs(wd) do n = n + 1 end end
    local ai = engineAmmoItems()
    local m = 0
    if ai then for _ in pairs(ai) do m = m + 1 end end
    return n .. ':' .. m .. ':' .. tostring(V.Cfg('AmmoItems', nil) ~= nil)
end

local function isBoxItem(item)
    return type(item) == 'string' and item:find('^ammo_box_') ~= nil
end

local function build()
    local sig = signature()
    if built == sig then return end
    built = sig
    typeToItem, itemToType, thrownType = {}, {}, {}

    -- 1. fallbacks
    for t, item in pairs(V.AmmoItemDefault) do typeToItem[t] = item end
    for t, item in pairs(V.ThrownDefault) do typeToItem[t] = item; thrownType[t] = true end

    -- 2. the engine: thrown weapons from WeaponData
    local wd = V.WeaponDataTable()
    if type(wd) == 'table' then
        for name, d in pairs(wd) do
            if type(d) == 'table' and d.thrown and type(d.ammoTypes) == 'table' and d.ammoTypes[1] then
                local t = tostring(d.ammoTypes[1]):upper()
                typeToItem[t] = tostring(name):lower()
                thrownType[t] = true
            end
        end
    end

    -- 3. the engine: ammo items -> type (rounds items; ammo boxes are not rounds)
    local ai = engineAmmoItems()
    if ai then
        for item, t in pairs(ai) do
            if type(item) == 'string' and type(t) == 'string' and not isBoxItem(item) then
                t = t:upper()
                if not thrownType[t] then typeToItem[t] = item end
            end
        end
    end

    -- 4. owner overrides: Config.Vorp.AmmoItems = { AMMO_X = 'item' }
    local over = V.Cfg('AmmoItems', nil)
    if type(over) == 'table' then
        for t, item in pairs(over) do
            if type(t) == 'string' and type(item) == 'string' then typeToItem[t:upper()] = item end
        end
    end

    for t, item in pairs(typeToItem) do itemToType[item] = t end
end

--- 'AMMO_REVOLVER', 'ammo_revolver' (the item) or an ammo hash -> 'AMMO_REVOLVER'
function V.AmmoType(given)
    build()
    if type(given) == 'number' then
        local h = math.tointeger(given)
        if not h or not joaat then return nil end
        h = h & 0xFFFFFFFF
        for t in pairs(typeToItem) do
            local th = math.tointeger(joaat(t))
            if th and (th & 0xFFFFFFFF) == h then return t end
        end
        return nil
    end
    if type(given) ~= 'string' or given == '' then return nil end
    local up = given:upper()
    if typeToItem[up] then return up end
    local t = itemToType[given] or itemToType[given:lower()]
    if t then return t end
    -- an ammo box item the engine maps (counts as its type for lookups only)
    local ai = engineAmmoItems()
    if ai and type(ai[given]) == 'string' then return ai[given]:upper() end
    return nil
end

--- AMMO type -> satchel item name, and whether it is a thrown weapon
function V.AmmoItem(ammoType)
    build()
    local t = V.AmmoType(ammoType)
    if not t then return nil end
    return typeToItem[t], thrownType[t] == true, t
end

--- item name -> AMMO type (rounds items and thrown weapons), or nil
function V.AmmoTypeOfItem(item)
    build()
    if type(item) ~= 'string' then return nil end
    local t = itemToType[item] or itemToType[item:lower()]
    if not t then return nil end
    return t, thrownType[t] == true
end

--- every known AMMO type -> { item, thrown }
function V.AmmoTypes()
    build()
    local out = {}
    for t, item in pairs(typeToItem) do out[t] = { item = item, thrown = thrownType[t] == true } end
    return out
end

--- ammo types a weapon takes (first = default)
function V.WeaponAmmoTypes(name)
    if type(name) ~= 'string' then return {} end
    local d = engineWeaponData(name)
    if d and type(d.ammoTypes) == 'table' and d.ammoTypes[1] then
        local out = {}
        for i, t in ipairs(d.ammoTypes) do out[i] = tostring(t):upper() end
        return out
    end
    local fam = familyOf(name)
    if fam then return fam end
    -- thrown weapon whose type is known
    build()
    for t, item in pairs(typeToItem) do
        if thrownType[t] and item == name:lower() then return { t } end
    end
    local def = V.Def(name:lower())
    if def and type(def.ammotype) == 'string' then return { def.ammotype:upper() } end
    return {}
end

function V.IsThrownWeapon(name)
    if type(name) ~= 'string' then return false end
    local d = engineWeaponData(name)
    if d and d.thrown ~= nil then return d.thrown and true or false end
    local _, thrown = V.AmmoTypeOfItem(name:lower())
    return thrown == true
end

--- How many of one AMMO type the player has (rounds items or thrown weapons)
function V.AmmoCount(invId, ammoType)
    local item, _, t = V.AmmoItem(ammoType)
    if not item then return 0, nil end
    return V.CountOf(invId, item), t
end

--- { AMMO_X = n } for every type the player has (n > 0)
function V.UserAmmo(invId)
    local out = {}
    local inv = V.Get(invId)
    if not inv then return out end
    for _, e in ipairs(V.Stacks(inv)) do
        local t = V.AmmoTypeOfItem(e.stack.name)
        if t then out[t] = (out[t] or 0) + V.StackAmount(e.stack) end
    end
    return out
end

--- VORP createWeapon's ammo argument (number, numeric string or { AMMO_X = n }) -> rounds loaded
function V.AmmoNumber(ammo)
    if type(ammo) == 'table' then
        local n = 0
        for _, v in pairs(ammo) do n = n + (tonumber(v) or 0) end
        return math.max(0, math.floor(n))
    end
    local n = tonumber(ammo)
    if not n or n ~= n or n == math.huge then return 0 end
    return math.max(0, math.floor(n))
end
