-- ============================================================
-- MULTIinventory :: weapons and ammo on the ped
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
--
-- Parts reused from RSG v2 (GPL v3, Copyright (C) RSG Framework contributors):
--   * rsg-weapons  client/client.lua  : give + select flow, weapon degradation
--                                       from info.quality (1 - quality / 100)
--   * rsg-weapons  config.lua          : thrown weapon -> AMMO_* type table
--   * rsg-ammo     config.lua          : ammo box item -> AMMO_* type table
--   * rsg-ammo     client/client.lua   : thrown ammo needs its weapon on the ped first
--   * rsg-weaponcomp client/inhands.lua: component apply order (model, give, apply shop item)
-- Every native below is checked in femga natives.json (hash + name in the table N).
--
-- Model:
--   * A weapon item (type 'weapon', unique) is put on the ped when used and taken
--     off when used again or when it leaves the satchel. info.ammo = rounds loaded
--     in the gun, remembered on the gun item. Loading takes the rounds from the
--     satchel (one round item per round loaded); firing a loaded round takes nothing more.
--   * Ammo items fill the ped's ammo pool by their exact AMMO_* type. Rounds per
--     item: def.ammoPer, Config.Ammo.PerItem[name], 'ammo_box_*' = Config.Ammo.BoxRounds, else 1.
--   * Thrown weapons (dynamite, molotov, knives, tomahawks, bolas, ...): the item
--     count is the throw count; every throw removes one item on the server.
--   * Used rounds / throws go to the server in batches (throttled).
--
-- Client -> server (handled by server/core):
--   net MULTIinventory:server:ammoUsed ({ [ammoItemName] = itemsUsed })
--   net MULTIinventory:server:thrown ({ [weaponItemName] = throws })
--   net MULTIinventory:server:weaponAmmo ({ { id = info.id|info.serie, slot = n, ammo = rounds, ammoType = 'AMMO_*' }, ... })
-- Server -> client:
--   MULTIinventory:client:useWeapon (item)   toggle a weapon item (e.g. from a VORP useWeapon call)
--   MULTIinventory:client:unequipAll ()
-- ============================================================

local N = {
    GIVE_WEAPON_TO_PED              = 0x5E3BDDBCB83F3D84,
    REMOVE_WEAPON_FROM_PED          = 0x4899CB088EDF59B8,
    SET_CURRENT_PED_WEAPON          = 0xADF692B254977C0C,
    HAS_PED_GOT_WEAPON              = 0x8DECB02F88F428BC,
    IS_WEAPON_VALID                 = 0x937C71165CF334B3,
    IS_WEAPON_THROWABLE             = 0x30E7C16B12DA8211, -- _IS_WEAPON_THROWABLE
    IS_WEAPON_A_GUN                 = 0x705BE297EEBDB95D,
    GET_DEFAULT_WEAPON_ATTACH_POINT = 0x65DC4AC5B96614CB, -- _GET_DEFAULT_WEAPON_ATTACH_POINT
    SET_AMMO_IN_CLIP                = 0xDCD2A934D65CB497,
    GET_AMMO_IN_CLIP                = 0x2E1202248937775C,
    GET_MAX_AMMO_IN_CLIP            = 0xA38DCFFCEA8962FA,
    SET_PED_AMMO_BY_TYPE            = 0x5FD1E1F011E76D7E,
    GET_PED_AMMO_BY_TYPE            = 0x39D22031557946C1,
    GET_AMMO_TYPE_FOR_WEAPON        = 0x5C2EA6C44F515F34, -- _GET_AMMO_TYPE_FOR_WEAPON
    IS_AMMO_TYPE_VALID_FOR_WEAPON   = 0xC570B881754DF609, -- _IS_AMMO_TYPE_VALID_FOR_WEAPON
    SET_AMMO_TYPE_FOR_PED_WEAPON    = 0xCC9C4393523833E2, -- _SET_AMMO_TYPE_FOR_PED_WEAPON
    GIVE_WEAPON_COMPONENT_TO_ENTITY = 0x74C9090FDD1BB48E, -- _GIVE_WEAPON_COMPONENT_TO_ENTITY
    GET_WEAPON_COMPONENT_TYPE_MODEL = 0x59DE03442B6C9598, -- _GET_WEAPON_COMPONENT_TYPE_MODEL
    APPLY_SHOP_ITEM_TO_PED          = 0xD3A7B003ED343FD9, -- _APPLY_SHOP_ITEM_TO_PED
    GET_CURRENT_PED_WEAPON_ENTITY_INDEX = 0x3B390A939AF0B5FC,
    GET_OBJECT_INDEX_FROM_ENTITY_INDEX  = 0x280BBE5601EAA983,
    SET_WEAPON_DEGRADATION          = 0xA7A57E89E965D839, -- _SET_WEAPON_DEGRADATION
    REMOVE_ALL_PED_AMMO             = 0x1B83C0DEEBCBB214, -- _REMOVE_ALL_PED_AMMO
}

-- weapon attach points (eWeaponAttachPoint, natives.json comment on SET_CURRENT_PED_WEAPON)
local AP = { PISTOL_R = 2, PISTOL_L = 3, RIFLE = 9, RIFLE_ALT = 10 }

-- thrown weapon -> ammo type (rsg-weapons config.lua, GPL v3); poison/drain knives share the knife weapon
local THROWN_AMMO = {
    weapon_thrown_throwing_knives   = 'AMMO_THROWING_KNIVES',
    weapon_thrown_tomahawk          = 'AMMO_TOMAHAWK',
    weapon_thrown_tomahawk_ancient  = 'AMMO_TOMAHAWK_ANCIENT',
    weapon_thrown_bolas             = 'AMMO_BOLAS',
    weapon_thrown_bolas_hawkmoth    = 'AMMO_BOLAS_HAWKMOTH',
    weapon_thrown_bolas_ironspiked  = 'AMMO_BOLAS_IRONSPIKED',
    weapon_thrown_bolas_intertwined = 'AMMO_BOLAS_INTERTWINED',
    weapon_thrown_dynamite          = 'AMMO_DYNAMITE',
    weapon_thrown_molotov           = 'AMMO_MOLOTOV',
    weapon_thrown_poisonbottle      = 'AMMO_POISONBOTTLE',
    weapon_melee_hatchet            = 'AMMO_HATCHET',
    weapon_melee_hatchet_hunter     = 'AMMO_HATCHET_HUNTER',
    weapon_melee_cleaver            = 'AMMO_HATCHET_CLEAVER',
}

-- ammo item -> ammo type when the item definition carries none
-- (ammo_box_* from rsg-ammo config.lua, GPL v3; arrows from rsg-ammo's AMMO_ARROW* type list)
local ITEM_AMMO = {
    ammo_arrow = 'AMMO_ARROW', ammo_arrow_small = 'AMMO_ARROW_SMALL_GAME', ammo_arrow_fire = 'AMMO_ARROW_FIRE',
    ammo_arrow_poison = 'AMMO_ARROW_POISON', ammo_arrow_dynamite = 'AMMO_ARROW_DYNAMITE',
    ammo_box_revolver = 'AMMO_REVOLVER', ammo_box_revolver_express = 'AMMO_REVOLVER_EXPRESS',
    ammo_box_revolver_explosive = 'AMMO_REVOLVER_EXPRESS_EXPLOSIVE', ammo_box_revolver_velocity = 'AMMO_REVOLVER_HIGH_VELOCITY',
    ammo_box_revolver_splitpoint = 'AMMO_REVOLVER_SPLIT_POINT',
    ammo_box_pistol = 'AMMO_PISTOL', ammo_box_pistol_express = 'AMMO_PISTOL_EXPRESS',
    ammo_box_pistol_explosive = 'AMMO_PISTOL_EXPRESS_EXPLOSIVE', ammo_box_pistol_velocity = 'AMMO_PISTOL_HIGH_VELOCITY',
    ammo_box_pistol_splitpoint = 'AMMO_PISTOL_SPLIT_POINT',
    ammo_box_repeater = 'AMMO_REPEATER', ammo_box_repeater_express = 'AMMO_REPEATER_EXPRESS',
    ammo_box_repeater_explosive = 'AMMO_REPEATER_EXPRESS_EXPLOSIVE', ammo_box_repeater_velocity = 'AMMO_REPEATER_HIGH_VELOCITY',
    ammo_box_repeater_splitpoint = 'AMMO_REPEATER_SPLIT_POINT',
    ammo_box_rifle = 'AMMO_RIFLE', ammo_box_rifle_express = 'AMMO_RIFLE_EXPRESS',
    ammo_box_rifle_explosive = 'AMMO_RIFLE_EXPRESS_EXPLOSIVE', ammo_box_rifle_velocity = 'AMMO_RIFLE_HIGH_VELOCITY',
    ammo_box_rifle_splitpoint = 'AMMO_RIFLE_SPLIT_POINT', ammo_box_rifle_elephant = 'AMMO_RIFLE_ELEPHANT',
    ammo_box_shotgun = 'AMMO_SHOTGUN', ammo_box_shotgun_buckshot_incendiary = 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY',
    ammo_box_shotgun_slug = 'AMMO_SHOTGUN_SLUG', ammo_box_shotgun_slug_explosive = 'AMMO_SHOTGUN_SLUG_EXPLOSIVE',
    ammo_box_varmint = 'AMMO_22', ammo_box_varmint_tranquilizer = 'AMMO_22_TRANQUILIZER',
}

local ADD_REASON_DEFAULT = joaat('ADD_REASON_DEFAULT')       -- as rsg-weapons uses it
local REMOVE_REASON_DEFAULT = joaat('REMOVE_REASON_DEFAULT') -- as rsg-weapons uses it

local function u32(h) return (tonumber(h) or 0) & 0xFFFFFFFF end
-- natives returning BOOL / int / Hash (args packed: a vararg in the middle of a call keeps only its first value)
local function call(hash, ...)
    local a = table.pack(...)
    a[a.n + 1] = Citizen.ResultAsInteger()
    return Citizen.InvokeNative(hash, table.unpack(a, 1, a.n + 1))
end
local function bool(hash, ...) return call(hash, ...) == 1 end
local function int(hash, ...) return tonumber(call(hash, ...)) or 0 end

local function cfg(k, d) return MIC.Cfg('Weapons.' .. k, d) end

-- shared weapon facts from the engine (MULTIInv.WeaponData[name] = { hash, type, ammoTypes, thrown }), read defensively
local function weaponData(name)
    local g = rawget(_G, 'MULTIInv')
    local wd = type(g) == 'table' and type(g.WeaponData) == 'table' and g.WeaponData[name]
    return type(wd) == 'table' and wd or {}
end

local function weaponHash(name)
    local wd = weaponData(name)
    if wd.hash then return u32(type(wd.hash) == 'string' and joaat(wd.hash) or wd.hash) end
    return u32(joaat(name:upper()))
end

-- ---------------------------------------------------------------
-- state
-- ---------------------------------------------------------------

local equipped = {}   -- [key] = { key, name, hash, slot, attach, ammoType, extra, lastClip, thrown, ammoTypeName }
local lastSet = {}    -- [AMMO_TYPE] = pool we last set on the ped
local spent = {}      -- [AMMO_TYPE] = rounds used that do not yet make up a whole item
local owed = {}       -- [itemName] = items reported used, not yet gone from the satchel push
local lastCount = {}  -- [itemName] = count at the last satchel push
local queueAmmo, queueThrown, queueWeapon = {}, {}, {}
local busy = false
-- Does the ped's ammo pool count the rounds loaded in the gun? Learned from the first shot or
-- reload (nil until then, treated as no). Satchel rounds = the pool without the loaded rounds:
-- a reload takes one satchel round per round loaded, a shot takes none.
local poolHasClip = nil
local quietUntil = 0  -- ammo type switch running: the watcher only takes new baselines

local function clipOf(ped, hash)
    local _, ammo = Citizen.InvokeNative(N.GET_AMMO_IN_CLIP, ped, Citizen.PointerValueInt(), hash, Citizen.ResultAsInteger())
    return tonumber(ammo) or 0
end

--- Rounds loaded in the carried guns of ammo type t (each weapon model once).
local function clipsOf(ped, t)
    local n, seen = 0, {}
    for _, w in pairs(equipped) do
        if not w.thrown and w.ammoTypeName == t and not seen[w.hash] then
            seen[w.hash] = true
            n = n + clipOf(ped, w.hash)
        end
    end
    return n
end

--- Loaded rounds the pool counts as well (0 when it does not).
local function loadedInPool(ped, t)
    if poolHasClip == true then return clipsOf(ped, t) end
    return 0
end

local function rebaseClips(ped)
    for _, w in pairs(equipped) do
        if not w.thrown then w.lastClip = clipOf(ped, w.hash) end
    end
end

local function keyOf(it)
    local info = it.info or {}
    if info.id then return 'id:' .. tostring(info.id) end
    if info.serie or info.serial then return 'sn:' .. tostring(info.serie or info.serial) end
    return 'slot:' .. tostring(it.slot) .. ':' .. it.name
end

local function thrownAmmoOf(name)
    local wd = weaponData(name)
    if wd.thrown and type(wd.ammoTypes) == 'table' and wd.ammoTypes[1] then return wd.ammoTypes[1] end
    return THROWN_AMMO[name]
end

--- AMMO_* type of an ammo item (nil when the item is not ammo).
local function ammoTypeOfItem(name)
    local over = MIC.Cfg('Ammo.Items', {})[name]
    if over then return over end
    local d = MIC.Def(name) or {}
    if d.type == 'ammo' and type(d.ammotype) == 'string' then return d.ammotype:upper() end
    if ITEM_AMMO[name] then return ITEM_AMMO[name] end
    if d.type == 'ammo' or (d.category == 'ammo') then
        return type(d.ammotype) == 'string' and d.ammotype:upper() or nil
    end
    return nil
end
MIC.AmmoTypeOfItem = ammoTypeOfItem

local function perItem(name)
    local d = MIC.Def(name) or {}
    local p = tonumber(d.ammoPer) or tonumber(MIC.Cfg('Ammo.PerItem', {})[name])
    if not p and name:find('^ammo_box_') then p = tonumber(MIC.Cfg('Ammo.BoxRounds', 12)) end
    return math.max(1, math.floor(p or 1))
end

-- which satchel items feed a pool type: { [AMMO_TYPE] = { [itemName] = { count, per, thrown } } }
local function poolSources()
    local out = {}
    for _, it in pairs(MIC.PlayerItems()) do
        local t = ammoTypeOfItem(it.name)
        local thrown = false
        if not t then
            local tt = thrownAmmoOf(it.name)
            if tt and equipped['thrown:' .. it.name] then t, thrown = tt, true end
        end
        if t then
            out[t] = out[t] or {}
            local s = out[t][it.name] or { count = 0, per = thrown and 1 or perItem(it.name), thrown = thrown }
            s.count = s.count + (tonumber(it.amount) or 0)
            out[t][it.name] = s
        end
    end
    return out
end

local function extraFor(t)
    local n = 0
    for _, w in pairs(equipped) do
        if not w.thrown and w.ammoTypeName == t then n = n + (w.extra or 0) end
    end
    return n
end

--- Set the ped's ammo pools to what the satchel holds (minus what was used and not yet synced).
local function applyPools()
    local ped = PlayerPedId()
    local src = poolSources()
    local seen = {}
    for t, items in pairs(src) do
        local rounds = 0
        for name, s in pairs(items) do
            rounds = rounds + math.max(0, s.count - (owed[name] or 0)) * s.per
        end
        local target = math.max(0, rounds - (spent[t] or 0) + extraFor(t) + loadedInPool(ped, t))
        seen[t] = true
        if lastSet[t] ~= target then
            Citizen.InvokeNative(N.SET_PED_AMMO_BY_TYPE, ped, joaat(t), target)
            lastSet[t] = target
        end
    end
    for t in pairs(lastSet) do
        if not seen[t] then
            local target = extraFor(t)
            Citizen.InvokeNative(N.SET_PED_AMMO_BY_TYPE, ped, joaat(t), target)
            if target == 0 then lastSet[t] = nil; spent[t] = nil else lastSet[t] = target end
        end
    end
    -- setting a pool can empty a clip too: new clip baselines, so that is not taken as shots
    rebaseClips(ped)
end
MIC.ApplyAmmoPools = applyPools

--- Rounds of type t were fired / thrown: take them from the extra first, then from items.
local function consume(t, used)
    for _, w in pairs(equipped) do
        if used <= 0 then break end
        if not w.thrown and w.ammoTypeName == t and (w.extra or 0) > 0 then
            local take = math.min(w.extra, used)
            w.extra = w.extra - take
            used = used - take
            w.dirty = true
        end
    end
    if used <= 0 then return end
    spent[t] = (spent[t] or 0) + used
    local items = poolSources()[t] or {}
    while true do
        local pick
        for name, s in pairs(items) do
            if s.count - (owed[name] or 0) > 0 then pick = name; break end
        end
        if not pick then spent[t] = 0; return end
        local s = items[pick]
        if spent[t] < s.per then return end
        spent[t] = spent[t] - s.per
        owed[pick] = (owed[pick] or 0) + 1
        if s.thrown then
            queueThrown[pick] = (queueThrown[pick] or 0) + 1
        else
            queueAmmo[pick] = (queueAmmo[pick] or 0) + 1
        end
    end
end

-- ---------------------------------------------------------------
-- equip / unequip
-- ---------------------------------------------------------------

local function attachInUse(ap)
    for _, w in pairs(equipped) do if w.attach == ap then return true end end
    return false
end

local function hashInUse(h)
    for _, w in pairs(equipped) do if w.hash == h then return true end end
    return false
end

local function loadModel(model)
    if model == 0 or not IsModelValid(model) then return false end
    RequestModel(model, false)
    local t = GetGameTimer() + 1000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(model)
end

-- component names: RSG keeps { CATEGORY = 'COMPONENT_NAME' } in info.componentshash,
-- VORP-style items keep a list of names in info.components; labels are skipped
local function componentNames(info)
    local out = {}
    local function take(t)
        if type(t) ~= 'table' then return end
        for _, v in pairs(t) do
            if type(v) == 'string' and v:match('^[%u%d_]+$') and v:find('_') then out[#out + 1] = v end
        end
    end
    take(info.componentshash)
    if #out == 0 then take(info.components) end
    return out
end

local function applyComponents(ped, hash, info)
    if not cfg('Components', true) then return end
    for _, name in ipairs(componentNames(info)) do
        local comp = joaat(name)
        local model = int(N.GET_WEAPON_COMPONENT_TYPE_MODEL, comp)
        local loaded = model ~= 0 and loadModel(model)
        Citizen.InvokeNative(N.GIVE_WEAPON_COMPONENT_TO_ENTITY, ped, comp, hash, true)
        Citizen.InvokeNative(N.APPLY_SHOP_ITEM_TO_PED, ped, comp, true, true, true)
        if loaded then SetModelAsNoLongerNeeded(model) end
    end
end

local function applyQuality(ped, info)
    local q = tonumber(info.quality)
    if not q then return end
    local ent = int(N.GET_CURRENT_PED_WEAPON_ENTITY_INDEX, ped, 0)
    local obj = ent ~= 0 and int(N.GET_OBJECT_INDEX_FROM_ENTITY_INDEX, ent) or 0
    if obj ~= 0 and DoesEntityExist(obj) then
        Citizen.InvokeNative(N.SET_WEAPON_DEGRADATION, obj, math.max(0.0, math.min(1.0, 1.0 - q / 100.0)))
    end
end

local function queueWeaponAmmo(w)
    if w.thrown then return end
    local ped = PlayerPedId()
    local clip = clipOf(ped, w.hash)
    local total = clip + (w.extra or 0)
    if total ~= w.lastTotal or w.dirty then
        w.lastTotal, w.dirty = total, false
        queueWeapon[w.key] = { id = w.id, slot = w.slot, ammo = total, ammoType = w.ammoTypeName }
    end
end

local function equipThrown(it, hash)
    local key = 'thrown:' .. it.name
    local ped = PlayerPedId()
    local t = thrownAmmoOf(it.name)
    if not bool(N.HAS_PED_GOT_WEAPON, ped, hash, 0, false) then
        Citizen.InvokeNative(N.GIVE_WEAPON_TO_PED, ped, hash, 0, false, true, int(N.GET_DEFAULT_WEAPON_ATTACH_POINT, hash),
            false, 0.5, 1.0, ADD_REASON_DEFAULT, false, 0.0, false)
    end
    equipped[key] = { key = key, name = it.name, hash = hash, thrown = true, ammoTypeName = t }
    lastCount[it.name] = MIC.CountItem(it.name)
    applyPools()
    Citizen.InvokeNative(N.SET_CURRENT_PED_WEAPON, ped, hash, true, 0, false, false)
end

local function equipGun(it, hash)
    local ped = PlayerPedId()
    local info = it.info or {}
    local key = keyOf(it)
    local attach = int(N.GET_DEFAULT_WEAPON_ATTACH_POINT, hash)
    if cfg('TwoSlots', true) then
        -- second sidearm on the left hip, second long arm on the shoulder (UNVERIFIED in game:
        -- the left holster may need the off-hand holster wardrobe item rsg-weapons adds)
        if attach == AP.PISTOL_R and attachInUse(AP.PISTOL_R) then attach = AP.PISTOL_L
        elseif attach == AP.RIFLE and attachInUse(AP.RIFLE) then attach = AP.RIFLE_ALT end
    end
    local multiple = hashInUse(hash)
    Citizen.InvokeNative(N.GIVE_WEAPON_TO_PED, ped, hash, 0, false, true, attach, multiple,
        0.5, 1.0, ADD_REASON_DEFAULT, false, 0.0, false)
    Citizen.InvokeNative(N.SET_CURRENT_PED_WEAPON, ped, hash, true, attach, false, false)

    -- ammo type: the one saved on the item, else the weapon's own default
    local typeName = type(info.ammoType) == 'string' and info.ammoType or nil
    if not typeName then
        local wd = weaponData(it.name)
        if type(wd.ammoTypes) == 'table' then typeName = wd.ammoTypes[1] end
    end
    if not typeName then
        local d = MIC.Def(it.name) or {}
        typeName = type(d.ammotype) == 'string' and d.ammotype:upper() or nil
    end
    if not typeName then
        -- MULTIcore shared/weapons.lua (RSG shape, keyed by weapon hash)
        local c = MIC.Core()
        local sw = c and c.Shared and c.Shared.Weapons
        local e = sw and (sw[hash] or sw[hash - 0x100000000] or sw[joaat(it.name)])
        typeName = type(e) == 'table' and type(e.ammotype) == 'string' and e.ammotype or nil
    end
    if typeName and bool(N.IS_AMMO_TYPE_VALID_FOR_WEAPON, hash, joaat(typeName)) then
        Citizen.InvokeNative(N.SET_AMMO_TYPE_FOR_PED_WEAPON, ped, hash, joaat(typeName))
    end

    -- rounds in the gun (already taken from the satchel when they were loaded): one clip
    -- loaded, the rest rides on the pool as "extra"
    local ammo = math.max(0, math.floor(tonumber(info.ammo) or 0))
    local maxClip = int(N.GET_MAX_AMMO_IN_CLIP, ped, hash, true)
    local clip = maxClip > 0 and math.min(ammo, maxClip) or ammo
    local w = {
        serie = info.serie or info.serial,
        key = key, id = info.id or info.serie or info.serial, name = it.name, slot = it.slot, hash = hash,
        attach = attach, ammoTypeName = typeName, extra = ammo - clip, lastTotal = ammo,
    }
    equipped[key] = w
    Citizen.InvokeNative(N.SET_AMMO_IN_CLIP, ped, hash, clip)
    applyPools()
    applyComponents(ped, hash, info)
    applyQuality(ped, info)
    -- the VORP face turns this into vorp_inventory:onWeaponEquipped and the equipped-weapon state bag
    TriggerEvent('MULTIinventory:client:weaponEquipped', {
        id = info.id, name = it.name, components = info.components, comps = info.componentshash or info.components,
        serie = info.serie or info.serial, isDual = attach == AP.PISTOL_L, defaults = {},
    })
end

local function removeFromPed(w)
    local ped = PlayerPedId()
    if not w.thrown then queueWeaponAmmo(w) end
    -- another equipped copy of the same weapon keeps it on the ped
    local still = false
    for k, o in pairs(equipped) do if k ~= w.key and o.hash == w.hash then still = true end end
    if not still then
        Citizen.InvokeNative(N.REMOVE_WEAPON_FROM_PED, ped, w.hash, true, REMOVE_REASON_DEFAULT)
    end
    equipped[w.key] = nil
    applyPools()
end

function MIC.Unequip(it)
    local w = equipped[keyOf(it)] or equipped['thrown:' .. it.name]
    if w then removeFromPed(w) end
    MIC.PushPage()
end

function MIC.UnequipAll()
    for _, w in pairs(equipped) do removeFromPed(w) end
    equipped = {}
    MIC.PushPage()
end

-- ---------------------------------------------------------------
-- server pushes from the VORP face (server/vorp/20_weapons.lua)
-- ---------------------------------------------------------------

-- an ammo type changed on the server: set that pool now (the satchel push follows)
RegisterNetEvent('MULTIinventory:client:ammoChanged', function(ammoType, count)
    if type(ammoType) ~= 'string' then return end
    local t = ammoType:upper()
    local target = math.max(0, math.floor(tonumber(count) or 0)) + extraFor(t)
    spent[t] = 0
    Citizen.InvokeNative(N.SET_PED_AMMO_BY_TYPE, PlayerPedId(), joaat(t), target)
    lastSet[t] = target
end)

-- all ammo taken: empty every pool on the ped
RegisterNetEvent('MULTIinventory:client:removeAllAmmo', function()
    local ped = PlayerPedId()
    for t in pairs(lastSet) do Citizen.InvokeNative(N.SET_PED_AMMO_BY_TYPE, ped, joaat(t), 0) end
    Citizen.InvokeNative(N.REMOVE_ALL_PED_AMMO, ped)
    for _, w in pairs(equipped) do if not w.thrown then w.extra = 0; w.dirty = true end end
    lastSet, spent = {}, {}
end)

-- a weapon was taken from the player on the server: off the ped
RegisterNetEvent('MULTIinventory:client:weaponRemoved', function(name, serie)
    if type(name) ~= 'string' then return end
    name = name:lower()
    for _, w in pairs(equipped) do
        if w.name == name and (serie == nil or w.thrown or tostring(w.serie) == tostring(serie)) then
            removeFromPed(w)
            if serie ~= nil then break end
        end
    end
    MIC.PushPage()
end)

-- components changed on a weapon: put them on again from the satchel's copy (after its push)
AddEventHandler('MULTIinventory:client:componentsChanged', function(weaponId)
    CreateThread(function()
        Wait(cfg('ComponentsDelay', 500))
        for _, w in pairs(equipped) do
            if not w.thrown and (weaponId == nil or tostring(w.id) == tostring(weaponId)) then
                for _, it in pairs(MIC.PlayerItems()) do
                    if it.name == w.name and keyOf(it) == w.key then
                        applyComponents(PlayerPedId(), w.hash, it.info or {})
                        break
                    end
                end
            end
        end
    end)
end)

function MIC.IsEquipped(it)
    if type(it) ~= 'table' or not it.name then return false end
    return equipped[keyOf(it)] ~= nil or equipped['thrown:' .. it.name] ~= nil
end

--- Equip / unequip a weapon item from the satchel.
function MIC.ToggleWeapon(it)
    if busy or type(it) ~= 'table' or not it.name then return end
    local hash = weaponHash(it.name)
    if not bool(N.IS_WEAPON_VALID, hash) then return MIC.Notify(_L('err_bad_weapon'), 'error') end
    local wd = weaponData(it.name)
    local d = MIC.Def(it.name) or {}
    local thrown = wd.thrown == true or d.type == 'weapon_thrown'
        or (wd.thrown == nil and d.unique ~= true and THROWN_AMMO[it.name] ~= nil)
    busy = true
    if thrown then
        local key = 'thrown:' .. it.name
        if equipped[key] then removeFromPed(equipped[key]) else equipThrown(it, hash) end
    else
        local q = tonumber((it.info or {}).quality)
        if q and q <= cfg('BrokenQuality', 0) then
            busy = false
            return MIC.Notify(_L('weapon_broken'), 'error')
        end
        local key = keyOf(it)
        if equipped[key] then removeFromPed(equipped[key]) else equipGun(it, hash) end
    end
    busy = false
    MIC.PushPage()
end

--- Load this ammo item's type into a carried gun that takes it.
function MIC.SelectAmmo(it)
    local t = ammoTypeOfItem(it.name)
    if not t then return end
    local ped = PlayerPedId()
    local h = u32(Citizen.InvokeNative(0x8425C5F057012DAB, ped, Citizen.ResultAsInteger())) -- _GET_PED_CURRENT_HELD_WEAPON
    local target
    for _, w in pairs(equipped) do
        if not w.thrown and bool(N.IS_AMMO_TYPE_VALID_FOR_WEAPON, w.hash, joaat(t)) then
            if not target or w.hash == h then target = w end
        end
    end
    if not target then return MIC.Notify(_L('ammo_no_weapon'), 'error') end
    quietUntil = GetGameTimer() + 750
    applyPools()
    Citizen.InvokeNative(N.SET_AMMO_TYPE_FOR_PED_WEAPON, ped, target.hash, joaat(t))
    target.ammoTypeName = t
    target.dirty = true
    -- the switch reloads the gun: new baselines once it settled (not counted as shots)
    CreateThread(function()
        Wait(600)
        applyPools()
        for at in pairs(lastSet) do lastSet[at] = int(N.GET_PED_AMMO_BY_TYPE, PlayerPedId(), joaat(at)) end
    end)
    local d = MIC.Def(it.name) or {}
    MIC.Notify(_L('ammo_loaded', d.label or it.name), 'success')
end

--- Called by MIC.UseSlot: true when this file handled the item.
function MIC.HandleWeaponUse(it, d)
    if not cfg('Enabled', true) then return false end
    if ammoTypeOfItem(it.name) and not (d.type == 'weapon' or d.type == 'weapon_thrown') then
        if MIC.Cfg('Ammo.UseLoads', true) then MIC.SelectAmmo(it); return true end
        return false
    end
    local isWeapon = d.type == 'weapon' or d.type == 'weapon_thrown' or weaponData(it.name).hash ~= nil
    if not isWeapon then return false end
    MIC.ToggleWeapon(it)
    return true
end

RegisterNetEvent('MULTIinventory:client:useWeapon', function(item)
    if type(item) ~= 'table' or not item.name then return end
    local it = item.slot and MIC.PlayerItems()[tonumber(item.slot)] or nil
    if not it or it.name ~= item.name then it = item end
    MIC.ToggleWeapon(it)
end)

RegisterNetEvent('MULTIinventory:client:unequipAll', function() MIC.UnequipAll() end)

-- ---------------------------------------------------------------
-- satchel changed: drop weapons that left it, refresh pools
-- ---------------------------------------------------------------

MIC.OnInvChange[#MIC.OnInvChange + 1] = function(inv)
    if not inv then
        -- logged out: nothing to keep on the ped
        for _, w in pairs(equipped) do
            Citizen.InvokeNative(N.REMOVE_WEAPON_FROM_PED, PlayerPedId(), w.hash, true, REMOVE_REASON_DEFAULT)
        end
        equipped, lastSet, spent, owed, lastCount = {}, {}, {}, {}, {}
        return
    end
    local items = MIC.PlayerItems()
    -- counts per item name, to settle what we reported as used
    local counts = {}
    for _, it in pairs(items) do counts[it.name] = (counts[it.name] or 0) + (tonumber(it.amount) or 0) end
    for name, c in pairs(counts) do
        local before = lastCount[name]
        if before and c < before and owed[name] then owed[name] = math.max(0, owed[name] - (before - c)) end
    end
    for name in pairs(lastCount) do
        if not counts[name] then owed[name] = nil end
    end
    lastCount = counts
    -- weapons that are no longer in the satchel come off the ped
    for key, w in pairs(equipped) do
        local keep = false
        if w.thrown then
            keep = (counts[w.name] or 0) > 0
        else
            for _, it in pairs(items) do
                if it.name == w.name and keyOf(it) == key then keep = true; w.slot = it.slot; break end
            end
        end
        if not keep then
            if not w.thrown then queueWeapon[key] = nil end
            local still = false
            for k, o in pairs(equipped) do if k ~= key and o.hash == w.hash then still = true end end
            if not still then Citizen.InvokeNative(N.REMOVE_WEAPON_FROM_PED, PlayerPedId(), w.hash, true, REMOVE_REASON_DEFAULT) end
            equipped[key] = nil
        end
    end
    applyPools()
end

-- ---------------------------------------------------------------
-- watch the ped: rounds fired, throws, clip changes; send in batches
-- ---------------------------------------------------------------

CreateThread(function()
    local nextSend = 0
    while true do
        Wait(cfg('AmmoCheckInterval', 250))
        if MIC.LoggedIn() and cfg('Enabled', true) and next(lastSet) then
            local ped = PlayerPedId()
            if not IsEntityDead(ped) then
                -- clips of the carried guns now, and how each changed since the last look
                local clipNow, clipBefore, typeOfHash = {}, {}, {}
                for _, w in pairs(equipped) do
                    if not w.thrown and not clipNow[w.hash] then
                        clipNow[w.hash] = clipOf(ped, w.hash)
                        clipBefore[w.hash] = w.lastClip or clipNow[w.hash]
                        typeOfHash[w.hash] = w.ammoTypeName
                    end
                end
                local quiet = GetGameTimer() < quietUntil
                for t, set in pairs(lastSet) do
                    local now = int(N.GET_PED_AMMO_BY_TYPE, ped, joaat(t))
                    local cNow, cBefore = 0, 0
                    for h, c in pairs(clipNow) do
                        if typeOfHash[h] == t then cNow, cBefore = cNow + c, cBefore + clipBefore[h] end
                    end
                    -- learn once whether the pool counts loaded rounds:
                    -- shot   (clip down): pool down as well = yes, pool unchanged = no
                    -- reload (clip up)  : pool unchanged = yes, pool down by the same = no
                    local dc, dp = cNow - cBefore, now - set
                    if poolHasClip == nil and not quiet and dc ~= 0 then
                        if dc < 0 then
                            if dp == dc then poolHasClip = true elseif dp == 0 then poolHasClip = false end
                        else
                            if dp == 0 then poolHasClip = true elseif dp == -dc then poolHasClip = false end
                        end
                        if poolHasClip ~= nil and MIC.Cfg('Debug', false) then
                            print(('[MULTIinventory] ammo pool counts loaded rounds: %s'):format(tostring(poolHasClip)))
                        end
                    end
                    -- satchel rounds = the pool without what is loaded in the guns
                    local totalNow = now - (poolHasClip == true and cNow or 0)
                    local totalBefore = set - (poolHasClip == true and cBefore or 0)
                    if quiet then
                        lastSet[t] = now
                    elseif totalNow < totalBefore then
                        -- rounds loaded into a gun (or thrown): one satchel round each
                        lastSet[t] = now
                        consume(t, totalBefore - totalNow)
                    elseif totalNow > totalBefore and MIC.Cfg('Ammo.BlockWorldAmmo', true) then
                        -- ammo picked up in the world is not in the satchel: put the pool back
                        local back = math.max(0, now - (totalNow - totalBefore))
                        Citizen.InvokeNative(N.SET_PED_AMMO_BY_TYPE, ped, joaat(t), back)
                        lastSet[t] = back
                    else
                        lastSet[t] = now
                    end
                end
                for _, w in pairs(equipped) do
                    if not w.thrown and clipNow[w.hash] then w.lastClip = clipNow[w.hash] end
                end
            end
        end
        if GetGameTimer() >= nextSend then
            nextSend = GetGameTimer() + cfg('SyncInterval', 2000)
            for _, w in pairs(equipped) do queueWeaponAmmo(w) end
            if next(queueAmmo) then TriggerServerEvent('MULTIinventory:server:ammoUsed', queueAmmo); queueAmmo = {} end
            if next(queueThrown) then TriggerServerEvent('MULTIinventory:server:thrown', queueThrown); queueThrown = {} end
            if next(queueWeapon) then
                local list = {}
                for _, v in pairs(queueWeapon) do if v.id or v.slot then list[#list + 1] = v end end
                if #list > 0 then TriggerServerEvent('MULTIinventory:server:weaponAmmo', list) end
                queueWeapon = {}
            end
        end
    end
end)

-- ---------------------------------------------------------------
-- death and respawn: put weapons back (or not) the way MULTImedic is set up
-- ---------------------------------------------------------------

local medicLosesWeapons
local function medicLoseWeapons()
    if medicLosesWeapons ~= nil then return medicLosesWeapons end
    medicLosesWeapons = false
    if GetResourceState('MULTImedic') == 'started' then
        local src = LoadResourceFile('MULTImedic', 'config.lua') or ''
        medicLosesWeapons = src:match('LoseWeapons%s*=%s*true') ~= nil
    end
    return medicLosesWeapons
end

local function reequip()
    local mode = cfg('AfterRespawn', 'medic') -- 'medic' | 'keep' | 'remove'
    if mode == 'medic' then mode = medicLoseWeapons() and 'remove' or 'keep' end
    local ped = PlayerPedId()
    local list = {}
    for _, w in pairs(equipped) do list[#list + 1] = w end
    for _, w in ipairs(list) do
        if not bool(N.HAS_PED_GOT_WEAPON, ped, w.hash, 0, false) then
            equipped[w.key] = nil
            if mode == 'keep' then
                -- give it back once, from the satchel (never a second copy)
                for _, it in pairs(MIC.PlayerItems()) do
                    if it.name == w.name and (w.thrown or keyOf(it) == w.key) then
                        if w.thrown then equipThrown(it, w.hash) else equipGun(it, w.hash) end
                        break
                    end
                end
            end
        end
    end
    lastSet = {}
    applyPools()
end

local function afterRespawn()
    CreateThread(function()
        Wait(cfg('RespawnDelay', 1500))
        reequip()
    end)
end

AddEventHandler('MULTImedic:client:onRevive', afterRespawn)
AddEventHandler('vorp_core:Client:OnPlayerRespawn', afterRespawn)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    for _, w in pairs(equipped) do
        Citizen.InvokeNative(N.REMOVE_WEAPON_FROM_PED, ped, w.hash, true, REMOVE_REASON_DEFAULT)
    end
end)
