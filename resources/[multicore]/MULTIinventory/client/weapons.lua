-- ============================================================
-- MULTIinventory :: client/weapons.lua
--
-- Puts weapons on the ped / takes them off when the server says so, keeps the ped's ammo pool in
-- step with the gunbelt (server deltas), applies components and condition, and reports ammo +
-- condition back (every Config.Weapons.reportSeconds while armed, and a "final" report when a
-- weapon comes off). The server is the authority; reports can only lower ammo / raise wear.
--
-- Server -> client: MULTIinventory:weapons:cl:equip (payload), :holster (id), :remove (id), :draw (id),
--   :loadout ({ belt, weapons }), :ammo (deltas), :belt (absolute belt), :ammoclear, :condition (id, cond, anim),
--   :components (id, comps, components)
-- Client -> server: MULTIinventory:weapons:sv:report (see server/weapons/weapons.lua handleReport)
-- Emits (client-local): vorp_inventory:onWeaponEquipped (comps, weaponId, name, isDual, defaults)
--   when Config.Compat.emitVorpEvents, and MULTIinventory:weaponEquipped (weaponId, name, slot) /
--   MULTIinventory:weaponRemoved (weaponId, name). State bag GetEquippedWeaponData_<hash> =
--   { serialNumber, weaponId } (replicated).
-- Exports: GetEquippedWeapons() -> { { id, name, slot, serial } }, IsWeaponEquipped(id) -> bool
-- ============================================================

-- RDR3 natives used here (public native DB). One place to fix a hash after testing.
--
-- Dual wield (two sidearms) - native inventory path (client/native_inventory.lua, NativeInv):
--   Native sequence per the verified native notes.
--   GiveWeaponToPed + _SET_ALLOW_DUAL_WIELD alone does NOT let the ped draw the off-hand gun. The game
--   needs (1) the off-hand holster in the native wardrobe (NativeInv.EnsureOffhandHolster) and (2) each
--   sidearm as an item in the native CARRIED_WEAPONS container: right hip -> SLOTID_WEAPON_0 bound to
--   hand attach slot 0, left hip -> SLOTID_WEAPON_1 bound to attach slot 1 (_SET_CURRENT_PED_WEAPON_BY_GUID).
--   Each sidearm's native GUID is kept on its Eq entry (w.guid, w.nidx) and removed by GUID, so two
--   copies of the same model stay separate. Unequipping one of a pair re-sets the remaining gun to the
--   normal holster (attach 2) and holsters it.
--   Decision: only sidearms (right/left hip) use the native path; long arms, knife, lasso, bow, kits
--   keep the plain GiveWeaponToPed path (it works for single weapons and is unchanged).
--   Config.Weapons.nativeSidearms = false turns the native path off. Any native failure falls back to
--   the old path for that weapon (GiveWeaponToPed into PISTOL_R/PISTOL_L, logged once with Config.Debug).
--   * GIVE_WEAPON_TO_PED(ped, hash, ammo, forceInHand, forceInHolster, attachPoint, allowMultipleCopies,
--     p7, p8, addReason, ignoreUnlocks, permanentDegradation, p12) (fallback / non-sidearms).
--   * _SET_ALLOW_DUAL_WIELD(ped, toggle) 0x83B8D50EB9446BF7: still set while both hips are filled.
--   * SET_CURRENT_PED_WEAPON(ped, hash, forceInstant, attachPoint, p4, p5): attach 0 = HAND_PRIMARY,
--     1 = HAND_SECONDARY, 2 = PISTOL_R (normal holster).
--   * GET_CURRENT_PED_WEAPON(ped, &hash, p2, attachPoint, p4) reads one hand (0 primary / 1 secondary).
WeaponNatives = {
    GiveWeaponToPed            = 0x5E3BDDBCB83F3D84,
    RemoveWeaponFromPed        = 0x4899CB088EDF59B8,
    SetCurrentPedWeapon        = 0xADF692B254977C0C,
    GetCurrentPedWeapon        = 0x3A87E44BB9A01D54,
    SetAllowDualWield          = 0x83B8D50EB9446BF7,  -- _SET_ALLOW_DUAL_WIELD (ped, toggle)
    GetPedAmmoByType           = 0x39D22031557946C1,
    SetPedAmmoByType           = 0x5FD1E1F011E76D7E,
    GetAmmoInClip              = 0x2E1202248937775C,
    SetAmmoInClip              = 0xDCD2A934D65CB497,
    GetPedAmmoTypeFromWeapon   = 0x7FEAD38B326B9F74,
    SetAmmoTypeForPedWeapon    = 0xCC9C4393523833E2,  -- _SET_AMMO_TYPE_FOR_PED_WEAPON (ped, weaponHash, ammoHash)
    GetPedWeaponObject         = 0x3B390A939AF0B5FC,  -- GET_CURRENT_PED_WEAPON_ENTITY_INDEX (ped, attachPoint)
    GiveWeaponComponent        = 0x74C9090FDD1BB48E,  -- GIVE_WEAPON_COMPONENT_TO_ENTITY (ped, comp, weapon, true)
    GetComponentModel          = 0x59DE03442B6C9598,  -- _GET_WEAPON_COMPONENT_TYPE_MODEL (comp) -> Hash
    GetWeaponDirt              = 0x810E8AE9AFEA7E54,
    SetWeaponDirt              = 0x812CE61DEBCAB948,
    GetWeaponSoot              = 0x4BF66F8878F67663,
    SetWeaponSoot              = 0xA9EF4AD10BDDDB57,
    GetWeaponDegradation       = 0x0D78E1097F89E637,
    SetWeaponDegradation       = 0xA7A57E89E965D839,
    GetWeaponDamage            = 0x904103D5D2333977,
    SetWeaponDamage            = 0xE22060121602493B,
}
local N = WeaponNatives

local Eq = {}            -- [weaponId] = { id, name, hash, slot, attach, isDual, ammoTypes, serial, group,
                         --               guid, nidx }  (guid/nidx: native inventory item + SLOTID_WEAPON_<nidx>)
local known = {}         -- ammo types this client has been told about
local typeByHash = nil
local lastSent = nil
local UNARMED = GetHashKey('WEAPON_UNARMED')

local function cfg() return Config.Weapons end
local function ped() return PlayerPedId() end
local function H(name) return GetHashKey(name) end

local function ammoTypeOfHash(h)
    if not typeByHash then
        typeByHash = {}
        for t in pairs(AmmoDefs.all()) do typeByHash[H(t)] = t end
    end
    return typeByHash[h]
end

local function getPool(p, t) return Citizen.InvokeNative(N.GetPedAmmoByType, p, H(t), Citizen.ResultAsInteger()) or 0 end
local function setPool(p, t, n) Citizen.InvokeNative(N.SetPedAmmoByType, p, H(t), math.max(0, math.floor(n))) end

local function getClip(p, hash)
    local ok, n = Citizen.InvokeNative(N.GetAmmoInClip, p, Citizen.PointerValueInt(), hash, Citizen.ReturnResultAnyway())
    return (ok and tonumber(n)) or 0
end

local function currentIn(p, hand)
    local _, cur = Citizen.InvokeNative(N.GetCurrentPedWeapon, p, Citizen.PointerValueInt(), true, hand or 0, true)
    return cur
end

-- [thrown] Throwables (dynamite, fire bottles, tomahawks, knives, bolas, poison bottles) have no magazine:
-- the ped's pool of the stack's ammo type (GET/SET_PED_AMMO_BY_TYPE) IS the stack. Equip puts the whole
-- count there and sets the weapon to that ammo type (_SET_AMMO_TYPE_FOR_PED_WEAPON, so volatile dynamite /
-- fire bottles work); the "clip" reported for a throwable is that pool. Every throw lowers it; the watcher
-- below reports the change right away and the server lowers the stack (and deletes it after the last one).
local function isThrown(w) return w and w.group == 'thrown' end

---This gun's magazine. Sidearms on the native path are read per gun (by their GUID, then by the GUID
---at their hand attach point 0 / 1 while drawn) so a pair - even two of the same model - keeps two
---separate magazines; everything else (and any native failure) uses the per-model read.
local function clipOf(p, w)
    if isThrown(w) then
        local t = w.thrownType or (w.ammoTypes and w.ammoTypes[1])
        return t and getPool(p, t) or 0
    end
    if w.guid and NativeInv then
        local n = NativeInv.ClipByGuid(p, w.guid)
        if n then return n end
        local hand = (w.nidx == 1) and 1 or 0
        if currentIn(p, hand) == w.hash then
            local g = NativeInv.GuidAtAttach(p, hand)
            n = g and NativeInv.ClipByGuid(p, g)
            if n then return n end
        end
    end
    return getClip(p, w.hash)
end

local function weaponAmmoType(p, w)
    if isThrown(w) and w.thrownType then return w.thrownType end
    local h =Citizen.InvokeNative(N.GetPedAmmoTypeFromWeapon, p, w.hash, Citizen.ResultAsInteger())
    local t = h and ammoTypeOfHash(h)
    if t then return t end
    return w.ammoTypes and w.ammoTypes[1] or nil
end

local function weaponObject(p, w)
    local function at(a)
        local o = Citizen.InvokeNative(N.GetPedWeaponObject, p, a, Citizen.ResultAsInteger())
        return (o and o ~= 0) and o or nil
    end
    local obj = at(w.attach or 0)
    -- drawn: the off-hand gun sits in HAND_SECONDARY (1), anything else in HAND_PRIMARY (0)
    if not obj and w.slot == 'left' and currentIn(p, 1) == w.hash then obj = at(1) end
    if not obj and (w.attach or 0) ~= 0 and currentIn(p, 0) == w.hash then obj = at(0) end
    return obj or 0
end

-- ------------------------------------------------------------
-- sidearms / dual wield
-- ------------------------------------------------------------
local function sidearms()
    local r, l
    for _, w in pairs(Eq) do
        if w.slot == 'right' then r = w elseif w.slot == 'left' then l = w end
    end
    return r, l
end

---The ped may dual wield while both hips hold a sidearm (the server only fills the left hip when
---Config.Weapons.dualWield allows it for this character).
local function syncDual(p)
    local r, l = sidearms()
    Citizen.InvokeNative(N.SetAllowDualWield, p or ped(), (r ~= nil and l ~= nil))
end

---GiveWeaponToPed into the weapon's holster attach point. Multiple copies are allowed for the
---off-hand gun and whenever another equipped weapon has the same model.
local function giveToPed(p, w)
    local multi = w.isDual == true
    for id, o in pairs(Eq) do if id ~= w.id and o.hash == w.hash then multi = true end end
    Citizen.InvokeNative(N.GiveWeaponToPed, p, w.hash, 0, false, true, w.attach or 0, multi, 0.5, 1.0, H('ADD_REASON_DEFAULT'), true, 0.0, false)
end

local function isSidearm(w) return w.slot == 'right' or w.slot == 'left' end

local function nativeOn()
    return NativeInv ~= nil and cfg().nativeSidearms ~= false
end

local function leftEquipped()
    for _, o in pairs(Eq) do if o.slot == 'left' then return true end end
    return false
end

---Should the off-hand holster be worn? A gun on the left hip, or the character's "always wear both
---holsters" choice (SetOffhandHolsterStyle export).
-- false once the server says this character may not wear the off-hand holster (no Off-hand Holster
-- item when Config.Weapons.dualWield.requireItem is set). Then "always" is ignored too.
local offhandAllowed = true
-- Leather: drawn only while the player owns the Off-hand Holster item (server: offhandHolster.leatherItem).
-- A gun on the left hip works either way. Another resource can also hide it (SetOffhandLeatherHidden).
local noLeatherItem = false
local exportHidden = false
local function syncLeather()
    if NativeInv and NativeInv.SetLeatherHidden then NativeInv.SetLeatherHidden(exportHidden or noLeatherItem) end
end
local function alwaysHolster()
    if not offhandAllowed then return false end
    if not NativeInv or not NativeInv.AlwaysHolster then return false end
    local ok, v = pcall(NativeInv.AlwaysHolster)
    return ok and v == true
end
local function wantHolster() return leftEquipped() or alwaysHolster() end

---Put weapons away (switching to unarmed holsters whatever is in hand).
local function holsterAll(p)
    Citizen.InvokeNative(N.SetCurrentPedWeapon, p, UNARMED, true, 0, false, false)
end

---Native inventory path for a sidearm (see the header). -> true when w is on the ped this way;
---false = caller falls back to GiveWeaponToPed. w is not in Eq yet.
---Native sequence per the verified native notes.
local function nativeEquip(p, w)
    local other
    for _, o in pairs(Eq) do
        if o.id ~= w.id and isSidearm(o) and o.slot ~= w.slot then other = o end
    end
    -- a pair is either fully native or fully on the old path (no mixing)
    if other and not other.guid then return false end
    local ok, res = pcall(function()
        local carried = NativeInv.CarriedWeaponsGuid()
        if not carried then return false end
        if w.slot == 'left' and not NativeInv.EnsureOffhandHolster(false) then
            NativeInv.warnOnce('offhand', 'off-hand holster could not be added')
            return false
        end
        -- lone sidearm = main weapon slot 0; a pair = right 0 / left 1
        local idx = 0
        if other then
            idx = (w.slot == 'left') and 1 or 0
            local want = 1 - idx
            if other.nidx ~= want then
                local moved = NativeInv.MoveSidearm(other.guid, want, carried)
                if not moved then return false end
                other.guid, other.nidx = moved, want
            end
        end
        local guid = NativeInv.AddSidearm(w.hash, idx, carried)
        if not guid then return false end
        w.guid, w.nidx = guid, idx
        NativeInv.BindToHand(p, guid, idx)
        if other then NativeInv.BindToHand(p, other.guid, other.nidx) end
        return true
    end)
    if not ok then NativeInv.warnOnce('nativeEquip', res) end
    return ok and res == true
end

---Native removal of one sidearm. If the other one of a pair stays, it goes back to the normal
---holster (attach 2) and is holstered first. -> true when removed by GUID.
local function nativeRemove(p, w)
    local rem
    for _, o in pairs(Eq) do if o.id ~= w.id and isSidearm(o) then rem = o end end
    if rem then
        pcall(function()
            Citizen.InvokeNative(N.SetCurrentPedWeapon, p, rem.hash, true, 2, false, false)
            holsterAll(p)
        end)
    end
    local removed = NativeInv.Remove(w.guid)
    w.guid, w.nidx = nil, nil
    return removed
end

---Draw w. A sidearm while both hips are filled draws both: main gun to HAND_PRIMARY (0),
---off-hand gun to HAND_SECONDARY (1) - by native GUID when both are on the native path.
local function drawWeapon(p, w)
    local r, l = sidearms()
    if r and l and (w == r or w == l) then
        syncDual(p)
        if r.guid and l.guid and NativeInv.BindToHand(p, r.guid, 0) and NativeInv.BindToHand(p, l.guid, 1) then return end
        Citizen.InvokeNative(N.SetCurrentPedWeapon, p, r.hash, true, 0, false, false)
        Citizen.InvokeNative(N.SetCurrentPedWeapon, p, l.hash, true, 1, false, false)
    else
        if w.guid and NativeInv.BindToHand(p, w.guid, 0) then return end
        Citizen.InvokeNative(N.SetCurrentPedWeapon, p, w.hash, true, 0, false, false)
    end
end

local function readCond(p, w)
    local obj = weaponObject(p, w)
    if obj == 0 then return {} end
    return {
        dirt = Citizen.InvokeNative(N.GetWeaponDirt, obj, Citizen.ResultAsFloat()),
        soot = Citizen.InvokeNative(N.GetWeaponSoot, obj, Citizen.ResultAsFloat()),
        degradation = Citizen.InvokeNative(N.GetWeaponDegradation, obj, Citizen.ResultAsFloat()),
        damage = Citizen.InvokeNative(N.GetWeaponDamage, obj, Citizen.ResultAsFloat()),
    }
end

local function applyCond(p, w, c)
    if not c then return end
    local obj = weaponObject(p, w)
    if obj == 0 then return end
    if c.dirt then Citizen.InvokeNative(N.SetWeaponDirt, obj, c.dirt + 0.0, false) end
    if c.soot then Citizen.InvokeNative(N.SetWeaponSoot, obj, c.soot + 0.0, false) end
    if c.degradation then Citizen.InvokeNative(N.SetWeaponDegradation, obj, c.degradation + 0.0, false) end
    if c.damage then Citizen.InvokeNative(N.SetWeaponDamage, obj, c.damage + 0.0, false) end
end

-- Fitting order: structural parts first, then materials, engravings, tints and wraps, so a
-- later part never wipes an earlier one (same order as RINGOgunsmith / RINGOweaponpositions).
local function partPriority(cat)
    local c = tostring(cat):upper()
    local fixed = { BARREL = 1, GRIP = 2, GRIPSTOCK = 3, STOCK = 4, SIGHT = 5, SCOPE = 6, CLIP = 7,
                    MAG = 8, TUBE = 9, CYLINDER = 10, FRAME = 11, HAMMER = 12, TRIGGER = 13,
                    WRAP = 60, WRAP_MATERIAL = 65, WRAP_TINT = 70 }
    if fixed[c] then return fixed[c] end
    if c:find('RIFLING') then return 20 end
    if c:find('ENGRAVING_MATERIAL') then return 45 end
    if c:find('_ENGRAVING') then return 40 end
    if c:find('_MATERIAL') then return 30 end
    if c:find('_TINT') then return 50 end
    return 35
end

---Component hashes of a weapon in fitting order.
local function partList(comps, components)
    local out, seen = {}, {}
    local function add(v)
        local h = type(v) == 'number' and v or (type(v) == 'string' and v ~= '' and H(v)) or nil
        if h and h ~= 0 and not seen[h] then seen[h] = true; out[#out + 1] = h end
    end
    if type(comps) == 'table' then
        local keys = {}
        for k in pairs(comps) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            local pa, pb = partPriority(a), partPriority(b)
            if pa ~= pb then return pa < pb end
            return tostring(a) < tostring(b)
        end)
        for _, k in ipairs(keys) do add(comps[k]) end
    end
    if type(components) == 'table' then for _, v in ipairs(components) do add(v) end end
    return out
end

-- Parts with their own model (grips, barrels, sights, scopes) only attach once that model is
-- streamed in; finishes and engravings have none.
local function fitParts(target, w, parts)
    for _, h in ipairs(parts) do
        local m = Citizen.InvokeNative(N.GetComponentModel, h, Citizen.ResultAsInteger()) or 0
        if m ~= 0 and IsModelValid(m) and not HasModelLoaded(m) then
            RequestModel(m)
            local deadline = GetGameTimer() + 1500
            while not HasModelLoaded(m) and GetGameTimer() < deadline do Wait(0) end
        end
        Citizen.InvokeNative(N.GiveWeaponComponent, target, h, w.hash, true)
        if m ~= 0 then SetModelAsNoLongerNeeded(m) end
    end
end

local function applyComponents(p, w, comps, components)
    local parts = partList(comps, components)
    w.parts, w.fitObj = parts, nil
    if #parts == 0 then return end
    fitParts(p, w, parts)
    -- the gun object that already exists (in hand / holstered) is not rebuilt by the ped call
    local obj = weaponObject(p, w)
    if obj ~= 0 then fitParts(obj, w, parts); w.fitObj = obj end
end

local function stateKey(w) return 'GetEquippedWeaponData_' .. tostring(w.hash) end

local function waitPed()
    local t = 0
    while (not DoesEntityExist(ped()) or IsEntityDead(ped())) and t < 30000 do Wait(250); t = t + 250 end
end

-- ------------------------------------------------------------
-- reports
-- ------------------------------------------------------------
local function buildReport(extraWeapons, final, extraPools)
    local p = ped()
    local pools, weapons = {}, extraWeapons or {}
    for t in pairs(known) do pools[t] = getPool(p, t) end
    for id, w in pairs(Eq) do
        for _, t in ipairs(w.ammoTypes or {}) do pools[t] = getPool(p, t) end
        local at = weaponAmmoType(p, w)
        local c = readCond(p, w)
        weapons[tostring(id)] = { clip = at and clipOf(p, w) or 0, ammoType = at,
                                  dirt = c.dirt, soot = c.soot, degradation = c.degradation, damage = c.damage }
    end
    for t, n in pairs(extraPools or {}) do pools[t] = n end
    local held
    local cur = currentIn(p, 0)
    for id, w in pairs(Eq) do if w.hash == cur and w.slot ~= 'left' then held = id break end end
    if not held then for id, w in pairs(Eq) do if w.hash == cur then held = id break end end end
    return { pools = pools, weapons = weapons, final = final, held = held }
end

local lastSendAt = -1e9
local function send(report)
    local s = json.encode(report)
    if s == lastSent and not report.final then return end
    lastSent = s
    lastSendAt = GetGameTimer()
    TriggerServerEvent('MULTIinventory:weapons:sv:report', report)
end

---Take a weapon off the ped; its magazine leaves the pool with it. final = report it as final.
local function takeOff(id, final)
    local w = Eq[id]
    if not w then
        if final then send(buildReport(nil, { [tostring(id)] = true })) end
        return
    end
    local p = ped()
    local at = weaponAmmoType(p, w)
    local clip = at and clipOf(p, w) or 0
    local c = readCond(p, w)
    local pool = at and getPool(p, at) or 0
    local sameModel = false
    for oid, o in pairs(Eq) do if oid ~= id and o.hash == w.hash then sameModel = true end end
    local byGuid = w.guid ~= nil and nativeRemove(p, w)
    Eq[id] = nil
    LocalPlayer.state:set(stateKey(w), nil, true)
    if byGuid then
        -- removed by GUID: a second copy of the same model stays untouched; otherwise make sure
        -- nothing of this model is left on the ped
        if not sameModel then Citizen.InvokeNative(N.RemoveWeaponFromPed, p, w.hash, true, H('REMOVE_REASON_DEFAULT')) end
    else
        Citizen.InvokeNative(N.RemoveWeaponFromPed, p, w.hash, true, H('REMOVE_REASON_DEFAULT'))
        -- a second copy (dual wield) of the same model stays: RemoveWeaponFromPed took every copy, so
        -- give it back with its magazine (clip natives are per model: both copies read the same value)
        for _, o in pairs(Eq) do
            if o.hash == w.hash then
                if o.guid then NativeInv.Remove(o.guid); o.guid, o.nidx = nil, nil end
                giveToPed(p, o)
                if at then Citizen.InvokeNative(N.SetAmmoInClip, p, o.hash, clip) end
                LocalPlayer.state:set(stateKey(o), { serialNumber = o.serial, weaponId = o.id }, true)
            end
        end
    end
    -- left hip emptied: take the off-hand holster off again (it comes back with the next left gun)
    -- (kept on when the character chose "always wear both holsters")
    if w.slot == 'left' and NativeInv and not wantHolster() then pcall(NativeInv.RemoveOffhandHolster) end
    syncDual(p)
    if at then setPool(p, at, pool - clip) end
    TriggerEvent('MULTIinventory:weaponRemoved', id, w.name)
    local wr = { [tostring(id)] = { clip = clip, ammoType = at, dirt = c.dirt, soot = c.soot, degradation = c.degradation, damage = c.damage } }
    send(buildReport(wr, final and { [tostring(id)] = true } or nil, at and { [at] = math.max(0, pool - clip) } or nil))
end

-- ------------------------------------------------------------
-- put on
-- ------------------------------------------------------------
local function putOn(pl, absolute)
    local p = ped()
    local w = { id = pl.id, name = pl.name, hash = H(pl.name), slot = pl.slot, attach = pl.attach or 0,
                isDual = pl.isDual == true, ammoTypes = pl.ammoTypes or {}, serial = pl.serial, group = pl.group }
    local thrown = isThrown(w)
    if thrown then w.thrownType = pl.ammoType or w.ammoTypes[1] end
    local before = {}
    for t in pairs(pl.deltas or {}) do before[t] = getPool(p, t) end
    -- [thrown] the stack's ammo goes onto the ped BEFORE the weapon (a throwable given with an empty pool
    -- may not stay selectable); a loadout has already set the absolute pool
    if thrown and not absolute then
        for t, d in pairs(pl.deltas or {}) do setPool(p, t, before[t] + d); known[t] = true end
    end
    local keepThrown = thrown and w.thrownType and getPool(p, w.thrownType) or nil
    local native = isSidearm(w) and nativeOn() and nativeEquip(p, w)
    if not native then
        if isSidearm(w) and nativeOn() then NativeInv.warnOnce('fallback', 'sidearm ' .. tostring(w.name) .. ' given with GiveWeaponToPed') end
        giveToPed(p, w)
    end
    if not absolute and not thrown then
        for t, d in pairs(pl.deltas or {}) do setPool(p, t, before[t] + d); known[t] = true end
    end
    if thrown then
        if w.thrownType then
            known[w.thrownType] = true
            Citizen.InvokeNative(N.SetAmmoTypeForPedWeapon, p, w.hash, H(w.thrownType))
            setPool(p, w.thrownType, keepThrown or 0)   -- exactly the stack (+ any of it still on the belt)
        end
    elseif pl.ammoType then Citizen.InvokeNative(N.SetAmmoInClip, p, w.hash, pl.clip or 0) end
    for _, t in ipairs(w.ammoTypes) do known[t] = true end
    Eq[w.id] = w
    syncDual(p)
    Wait(100)
    applyComponents(p, w, pl.comps, pl.components)
    applyCond(p, w, pl.condition)
    if pl.draw then drawWeapon(p, w)
    elseif native then holsterAll(p) end   -- binding by GUID puts the gun in hand; equip = holstered
    LocalPlayer.state:set(stateKey(w), { serialNumber = pl.serial, weaponId = pl.id }, true)
    TriggerEvent('MULTIinventory:weaponEquipped', pl.id, pl.name, pl.slot)
    if Config.Compat and Config.Compat.emitVorpEvents then
        TriggerEvent('vorp_inventory:onWeaponEquipped', pl.comps or {}, pl.id, pl.name, w.isDual, pl.defaults or {})
    end
    return w
end

RegisterNetEvent('MULTIinventory:weapons:cl:equip', function(pl)
    CreateThread(function() waitPed(); putOn(pl, false) end)
end)

RegisterNetEvent('MULTIinventory:weapons:cl:holster', function(id)
    CreateThread(function() takeOff(id, true) end)
end)

RegisterNetEvent('MULTIinventory:weapons:cl:remove', function(id)
    CreateThread(function() takeOff(id, true) end)
end)

RegisterNetEvent('MULTIinventory:weapons:cl:draw', function(id)
    local w = Eq[id]
    if not w then return end
    local p = ped()
    local cur = currentIn(p, 0)
    local r, l = sidearms()
    local inHand = cur == w.hash
    -- either gun of a drawn pair counts as "in hand" (toggle holsters both)
    if not inHand and r and l and (w == r or w == l) then inHand = (cur == r.hash) or (currentIn(p, 1) == l.hash) end
    if inHand then
        Citizen.InvokeNative(N.SetCurrentPedWeapon, p, UNARMED, true, 0, false, false)
    else
        drawWeapon(p, w)
    end
end)

RegisterNetEvent('MULTIinventory:weapons:cl:loadout', function(data)
    CreateThread(function()
        waitPed()
        Wait(1000)
        local p = ped()
        for id, w in pairs(Eq) do
            if w.guid then NativeInv.Remove(w.guid); w.guid, w.nidx = nil, nil end
            Citizen.InvokeNative(N.RemoveWeaponFromPed, p, w.hash, true, H('REMOVE_REASON_DEFAULT'))
            LocalPlayer.state:set(stateKey(w), nil, true)
            Eq[id] = nil
        end
        local belt = data.belt or {}
        local totals = {}
        for t, n in pairs(belt) do totals[t] = n; known[t] = true end
        for _, pl in ipairs(data.weapons or {}) do
            if pl.ammoType then totals[pl.ammoType] = (totals[pl.ammoType] or 0) + (pl.clip or 0) end
            for _, t in ipairs(pl.ammoTypes or {}) do totals[t] = totals[t] or 0 end
        end
        for t in pairs(known) do setPool(p, t, totals[t] or 0) end
        for t, n in pairs(totals) do setPool(p, t, n) end
        -- new ped / character: the off-hand holster is re-added fresh with the left gun (or dropped)
        if data.offhand ~= nil then offhandAllowed = data.offhand == true end
        if data.leather ~= nil then noLeatherItem = data.leather ~= true end
        syncLeather()
        local hasLeft = false
        for _, pl in ipairs(data.weapons or {}) do if pl.slot == 'left' then hasLeft = true end end
        if NativeInv and nativeOn() then
            if hasLeft or alwaysHolster() then pcall(NativeInv.EnsureOffhandHolster, true) else pcall(NativeInv.RemoveOffhandHolster) end
        end
        for _, pl in ipairs(data.weapons or {}) do putOn(pl, true) end
        lastSent = nil
    end)
end)

RegisterNetEvent('MULTIinventory:weapons:cl:ammo', function(deltas)
    local p = ped()
    for t, d in pairs(deltas or {}) do
        known[t] = true
        setPool(p, t, getPool(p, t) + d)
    end
end)

RegisterNetEvent('MULTIinventory:weapons:cl:belt', function(belt)
    local p = ped()
    local clips, thrownT = {}, {}
    for _, w in pairs(Eq) do
        local at = weaponAmmoType(p, w)
        if at and isThrown(w) then thrownT[at] = true
        elseif at then clips[at] = (clips[at] or 0) + clipOf(p, w) end
    end
    for t in pairs(belt or {}) do known[t] = true end
    -- [thrown] a throwable on the ped keeps its pool (it is the stack; the server corrects it with :thrownCount)
    for t in pairs(known) do if not thrownT[t] then setPool(p, t, ((belt or {})[t] or 0) + (clips[t] or 0)) end end
    lastSent = nil
end)

-- [thrown] the server's count for a throwable on the ped (after a report claimed more than the stack holds)
RegisterNetEvent('MULTIinventory:weapons:cl:thrownCount', function(id, ammoType, n)
    local w = Eq[id]
    if not w or type(ammoType) ~= 'string' then return end
    known[ammoType] = true
    setPool(ped(), ammoType, tonumber(n) or 0)
    lastSent = nil
end)

RegisterNetEvent('MULTIinventory:weapons:cl:ammoclear', function()
    local p = ped()
    for _, w in pairs(Eq) do
        for _, t in ipairs(w.ammoTypes or {}) do known[t] = true end
        Citizen.InvokeNative(N.SetAmmoInClip, p, w.hash, 0)
    end
    for t in pairs(known) do setPool(p, t, 0) end
    lastSent = nil
end)

RegisterNetEvent('MULTIinventory:weapons:cl:condition', function(id, cond, anim)
    CreateThread(function()
        local cl = cfg().cleaning or {}
        if anim and (cl.animMs or 0) > 0 then
            local p = ped()
            local w0 = Eq[id]
            if cl.animDict and cl.animName then
                RequestAnimDict(cl.animDict)
                local t = 0
                while not HasAnimDictLoaded(cl.animDict) and t < 2000 do Wait(50); t = t + 50 end
                TaskPlayAnim(p, cl.animDict, cl.animName, 8.0, -8.0, cl.animMs, 1, 0, false, false, false)
                Wait(cl.animMs)
            elseif cl.nativeAnim ~= false and w0 and w0.hash and not IsPedInAnyVehicle(p, false) and not IsPedOnMount(p) then
                -- RDR2 cleaning interaction: draw the gun, wipe it with a rag, then holster it again
                local cloth
                local okAnim = pcall(function()
                    local model = joaat(cl.clothModel or 's_balledragcloth01x')
                    RequestModel(model)
                    local t = 0
                    while not HasModelLoaded(model) and t < 2000 do Wait(50); t = t + 50 end
                    local c = GetEntityCoords(p)
                    cloth = CreateObject(model, c.x, c.y, c.z, true, true, false, false, true)
                    SetModelAsNoLongerNeeded(model)
                    SetCurrentPedWeapon(p, w0.hash, true, 0, false, false)
                    Wait(600)
                    local group = GetWeapontypeGroup(w0.hash)
                    local short = group == joaat('GROUP_PISTOL') or group == joaat('GROUP_REVOLVER')
                    local state = joaat(short and (cl.shortArmState or 'SHORTARM_CLEAN_ENTER') or (cl.longArmState or 'LONGARM_CLEAN_ENTER'))
                    Citizen.InvokeNative(0x72F52AA2D2B172CC, p, w0.hash, cloth, joaat('CLOTH'), state, 1, 0, -1.0) -- _TASK_ITEM_INTERACTION_2
                end)
                Wait(cl.animMs)
                ClearPedTasks(p)
                if cloth and DoesEntityExist(cloth) then DeleteObject(cloth) end
                if okAnim then SetCurrentPedWeapon(p, joaat('WEAPON_UNARMED'), true, 0, false, false) end
            else
                Wait(cl.animMs)
            end
        end
        local w = Eq[id]
        if w then applyCond(ped(), w, cond) end
    end)
end)

RegisterNetEvent('MULTIinventory:weapons:cl:components', function(id, comps, components)
    local w = Eq[id]
    if w then CreateThread(function() applyComponents(ped(), w, comps, components) end) end
end)

-- Drawing, holstering or swapping hands gives the gun a new object (the native inventory path
-- binds by GUID, which the ped-level fit does not always reach): fit the parts onto each new one.
CreateThread(function()
    while true do
        Wait(400)
        local p = ped()
        for _, w in pairs(Eq) do
            if w.parts and #w.parts > 0 then
                local obj = weaponObject(p, w)
                if obj ~= 0 and obj ~= w.fitObj and DoesEntityExist(obj) then
                    w.fitObj = obj
                    local ok, err = pcall(fitParts, obj, w, w.parts)
                    if not ok then print(('^3[MULTIinventory] part fitting failed: %s^7'):format(tostring(err))) end
                end
            end
        end
    end
end)

-- ------------------------------------------------------------
-- periodic report + respawn re-equip
-- ------------------------------------------------------------
-- Off-hand holster re-apply: spawn, character load, ped model change and clothing reloads can rebuild
-- the native wardrobe, so the holster is added again (while a gun sits on the left hip, or always when
-- the character chose "always wear both holsters").
local holsterToken = 0
-- Only once a character is loaded (its clothing arrived from the server). Before that the player may
-- be in the framework's character creator, which rebuilds the same ped's outfit; touching it then can
-- hang the game.
local function charReady() return ClothingClient ~= nil and ClothingClient.loaded == true end
local function reapplyHolster(delay)
    if not (NativeInv and nativeOn()) or not charReady() then return end
    holsterToken = holsterToken + 1
    local my = holsterToken
    SetTimeout(delay or 3000, function()
        if my ~= holsterToken or not charReady() or not wantHolster() then return end
        local ok, err = pcall(NativeInv.EnsureOffhandHolster, true)
        if not ok then NativeInv.warnOnce('reapplyHolster', err) end
    end)
end
AddEventHandler('playerSpawned', function() reapplyHolster(4000) end)
RegisterNetEvent('vorp:SelectedCharacter', function() reapplyHolster(6000) end)
AddEventHandler('vorpcharacter:reloadafterdeath', function() reapplyHolster(4000) end)
AddEventHandler('RSGCore:Client:OnPlayerLoaded', function() reapplyHolster(6000) end)
AddEventHandler('MULTIinventory:client:clothingChanged', function() reapplyHolster(3500) end)
AddEventHandler('vorp_character:Client:OnClothingAdded', function() reapplyHolster(2000) end)

-- No EMPTY off-hand holster: with no gun on the left hip (and "always" off), any
-- off-hand leather on the ped is stripped, wherever it came from (character creator, saved outfits,
-- clothing reloads). holsters_left only holds off-hand holsters, so the right-hip holster is never touched.
-- Two checks in a row before stripping, so a left gun being equipped right now is never caught mid-way.
CreateThread(function()
    local IS_META_PED_USING_COMPONENT = 0xFB4891BD7578CDC1
    local seen = 0
    while true do
        Wait(2000)
        local oh = cfg().offhandHolster or {}
        if oh.stripEmpty ~= false and NativeInv and NativeInv.HideHolsterLeather and charReady() then
            local p = PlayerPedId()
            local okc, wearing = pcall(Citizen.InvokeNative, IS_META_PED_USING_COMPONENT, p, NativeInv.HOLSTERS_LEFT_CATEGORY or 0xB6B6122D)
            local hidden = NativeInv.LeatherHidden and NativeInv.LeatherHidden()
            if okc and wearing and (not wantHolster() or hidden) then
                seen = seen + 1
                if seen >= 2 then
                    NativeInv.HideHolsterLeather(p)
                    seen = 0
                end
            else
                seen = 0
            end
        end
    end
end)
AddEventHandler('vorp_character:Client:OnClothingRemoved', function() reapplyHolster(2000) end)

CreateThread(function()
    local lastPed = nil
    while true do
        Wait(math.max(1, cfg().reportSeconds or 5) * 1000)
        -- ped model change replaces the ped: re-apply the off-hand holster on the new one
        -- (checked with no weapons on too, for the "always wear both holsters" rig)
        if DoesEntityExist(ped()) then
            local p = ped()
            if lastPed and p ~= lastPed then reapplyHolster(500) end
            lastPed = p
        end
        if next(Eq) and DoesEntityExist(ped()) and not IsEntityDead(ped()) then
            local p = ped()
            -- keep the dual-wield flag on the current ped (model swaps / skin reloads replace the ped)
            local ok, err = pcall(function() syncDual(p); send(buildReport()) end)
            if not ok and Config.Debug then print('[MULTIinventory] weapon report: ' .. tostring(err)) end
        end
    end
end)

-- [thrown] throw watcher: while a throwable is on the ped, a change of its pool (a throw) is reported at
-- once (at most one report per ~1.1 s - the server drops faster non-final reports), so the inventory stack
-- follows every throw and the stack is removed right after the last one. No work without a throwable.
CreateThread(function()
    local lastSeen = {}
    while true do
        local w
        for _, o in pairs(Eq) do if isThrown(o) and o.thrownType then w = o break end end
        if not w then
            lastSeen = {}
            Wait(1000)
        else
            Wait(250)
            local p = ped()
            if DoesEntityExist(p) and not IsEntityDead(p) then
                local n = getPool(p, w.thrownType)
                local key = tostring(w.id)
                if lastSeen[key] == nil then lastSeen[key] = n end
                if n ~= lastSeen[key] and GetGameTimer() - lastSendAt >= 1100 then
                    lastSeen[key] = n
                    local ok, err = pcall(function() send(buildReport()) end)
                    if not ok and Config.Debug then print('[MULTIinventory] thrown report: ' .. tostring(err)) end
                end
            end
        end
    end
end)

CreateThread(function()
    local wasDead = false
    while true do
        Wait(1000)
        local dead = IsEntityDead(ped())
        if wasDead and not dead and InvClient and InvClient.charId then
            Wait(2500)
            CreateThread(function() InvClient.request('weaponLoadout', {}) end)
        end
        wasDead = dead
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, w in pairs(Eq) do LocalPlayer.state:set(stateKey(w), nil, true) end
end)

exports('GetEquippedWeapons', function()
    local out = {}
    for id, w in pairs(Eq) do out[#out + 1] = { id = id, name = w.name, slot = w.slot, serial = w.serial } end
    return out
end)
exports('IsWeaponEquipped', function(id) return Eq[tonumber(id)] ~= nil end)

-- ------------------------------------------------------------
-- off-hand holster style (two-gun rig)
-- ------------------------------------------------------------
---Put the off-hand holster on / take it off to match the current choice; force = re-add with the
---current item (style change). -> true when the holster is on afterwards.
local function applyOffhandHolster(force)
    if not (NativeInv and nativeOn()) then return false end
    if wantHolster() then
        local ok, res = pcall(NativeInv.EnsureOffhandHolster, force == true)
        return ok and res == true
    end
    pcall(NativeInv.RemoveOffhandHolster)
    return false
end

---exports.MULTIinventory:SetOffhandHolsterStyle(style, tint, always) -> true, worn | false, 'style'|'off'
---style 0..10/14/15/302, tint 1..4 (302: 1 only); the M/F item follows the ped sex. nil args keep the
---current value. Re-applies the holster right away (also drives the /weaponpos live preview).
exports('SetOffhandHolsterStyle', function(style, tint, always)
    if not NativeInv or not NativeInv.SetHolsterStyle then return false, 'off' end
    local ok, err = NativeInv.SetHolsterStyle(style, tint, always)
    if not ok then return false, err end
    return true, applyOffhandHolster(true)
end)

---exports.MULTIinventory:ResetOffhandHolsterStyle() -> worn. Back to Config.Weapons.offhandHolster
---(character switch, or a character with no saved choice). Re-applies the holster right away.
exports('ResetOffhandHolsterStyle', function()
    if not NativeInv or not NativeInv.ResetHolsterStyle then return false end
    NativeInv.ResetHolsterStyle()
    return applyOffhandHolster(true)
end)

---exports.MULTIinventory:SetOffhandLeatherHidden(hidden) -> worn. true = the left holster leather is not
---drawn (a script attaches its own holster model); the off-hand holster still works for draw / dual wield.
---Not saved: the caller sets it again after a MULTIinventory restart or a character load.
exports('SetOffhandLeatherHidden', function(hidden)
    if not NativeInv or not NativeInv.SetLeatherHidden then return false end
    exportHidden = hidden == true
    syncLeather()
    return applyOffhandHolster(true)
end)

-- the Off-hand Holster item was bought / dropped / moved: draw or strip the leather right away
RegisterNetEvent('MULTIinventory:weapons:cl:leather', function(has)
    noLeatherItem = has ~= true
    syncLeather()
    applyOffhandHolster(true)
end)

---exports.MULTIinventory:GetOffhandHolsterStyles() -> { sex, styles = { { style, label, tints } },
---current = { style, tint, always }, enabled, worn } for the current ped.
exports('GetOffhandHolsterStyles', function()
    if not NativeInv or not NativeInv.StyleList then return { sex = 'male', styles = {}, current = {}, enabled = false } end
    local l = NativeInv.StyleList()
    l.enabled = nativeOn()
    l.worn = NativeInv.WornOffhandItem and NativeInv.WornOffhandItem() or nil
    return l
end)

-- ------------------------------------------------------------
-- Extra (third) sidearm: it is not on the ped (the game has two sidearm slots). Hold the key / use the
-- command to draw it - the server swaps it with the right-hip gun. The state bag 'rinvx' says whether one is
-- equipped; the loop only watches the key while it is (no per-frame work otherwise).
-- ------------------------------------------------------------
do
    local X = (Config.Weapons or {}).extraSidearm or {}
    if X.enabled == true then
        local function draw() TriggerServerEvent('MULTIinventory:weapons:sv:swapExtra') end
        if type(X.command) == 'string' and X.command ~= '' then
            RegisterCommand(X.command, draw, false)
        end
        local key, holdMs = tonumber(X.holdKey), tonumber(X.holdMs) or 450
        if key then
            CreateThread(function()
                local since, fired = nil, false
                while true do
                    local has = LocalPlayer.state.rinvx
                    if type(has) == 'table' and has.name then
                        Wait(0)
                        local ped = PlayerPedId()
                        if IsControlPressed(0, key) and not IsEntityDead(ped) and not IsPauseMenuActive() then
                            since = since or GetGameTimer()
                            if not fired and GetGameTimer() - since >= holdMs then
                                fired = true
                                draw()
                            end
                        else
                            since, fired = nil, false
                        end
                    else
                        since, fired = nil, false
                        Wait(500)
                    end
                end
            end)
        end
    end
end
