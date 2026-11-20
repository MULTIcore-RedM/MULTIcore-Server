-- ============================================================
-- MULTIinventory :: client/native_inventory.lua
--
-- Thin wrapper around the game's OWN (native) inventory, used for dual wield: the game only lets the
-- ped draw a second sidearm when the character has the off-hand holster in its native wardrobe and the
-- two guns sit in the native CARRIED_WEAPONS container (SLOTID_WEAPON_0 / SLOTID_WEAPON_1), bound to
-- hand attach slots 0 / 1 by GUID.
-- Native sequence per the verified native notes.
-- Written fresh for MULTIinventory; no third-party code.
--
-- Every native call is pcall-guarded. Functions return nil/false on failure (the caller then falls
-- back to the plain GiveWeaponToPed path); the first failure of each kind is printed when Config.Debug.
--
-- GUIDs are 8*13-byte buffers (non-interned Lua strings > 40 bytes, so the native writes into them in
-- place, same idea as a DataView ArrayBuffer :Buffer()).
-- ============================================================

NativeInv = NativeInv or {}
local NI = NativeInv

NI.Natives = {
    IsKeyValid                = 0x6D5D51B188333FD1,  -- _ITEMDATABASE_IS_KEY_VALID (itemHash, 0)
    GetGuidFromItemId         = 0x886DFD3E185C8A89,  -- _INVENTORY_GET_GUID_FROM_ITEMID (inv, parentGuid|0, category, slotId, outGuid)
    AddItemWithGuid           = 0xCB5D11F9508A928D,  -- _INVENTORY_ADD_ITEM_WITH_GUID (inv, outGuid, parentGuid, item, slot, 1, reason)
    EquipItemWithGuid         = 0x734311E2852760D0,  -- _INVENTORY_EQUIP_ITEM_WITH_GUID (inv, guid, true)
    MoveItemWithGuid          = 0xDCCAA7C3BFD88862,  -- _INVENTORY_MOVE_INVENTORY_ITEM_WITH_GUID (inv, guid, newParent, slot, 1, outGuid)
    RemoveItemWithGuid        = 0x3E4E811480B3AE79,  -- _INVENTORY_REMOVE_INVENTORY_ITEM_WITH_GUID (inv, guid, 1, reason)
    SetCurrentPedWeaponByGuid = 0x12FB95FE3D579238,  -- _SET_CURRENT_PED_WEAPON_BY_GUID (ped, guid, true, attachSlot, false, false)
    -- per-gun magazine read (public native DB; verify in game - failures fall back to the per-model read)
    GetAmmoInClipByGuid       = 0x678F00858980F516,  -- _GET_AMMO_IN_CLIP_BY_INVENTORY_UID (ped, &ammo, guid)
    GetPedWeaponGuidAtAttach  = 0x6929E22158E52265,  -- _GET_PED_WEAPON_GUID_AT_ATTACH_POINT (ped, attachPoint, outGuid)
}

NI.INVENTORY_ID   = 1                -- the local player's native inventory
NI.GUID_SIZE      = 8 * 13
NI.SLOT_CHARACTER = 0xA1212100       -- SLOTID_NONE
NI.SLOT_WARDROBE  = 0x3DABBFA7
NI.HOLSTER_SLOT    = 0xF20B6B4A      -- wardrobe slot of the off-hand holster clothing item
NI.HOLSTER_UPGRADE = { item = 'UPGRADE_OFFHAND_HOLSTER', slot = 0x39E57B01 }
-- Default list (male, default style); NI.HolsterItems(ped) builds the real list per ped sex + style.
NI.HOLSTER_ITEMS  = {                -- off-hand holster: item -> wardrobe slot hash
    { item = 'CLOTHING_ITEM_M_OFFHAND_000_TINT_004', slot = NI.HOLSTER_SLOT },
    NI.HOLSTER_UPGRADE,
}

-- Off-hand holster styles (category holsters_left, multiplayer): CLOTHING_ITEM_<M|F>_OFFHAND_<sss>_TINT_<ttt>.
-- Game item-name facts from the public cloth hash-name list: 53 male + 53 female entries, the same
-- style numbers for both sexes (no 011-013); styles 000-010, 014, 015 have tints 001-004, 302 tint 001 only.
local ALL_TINTS = { 1, 2, 3, 4 }
local STYLE_LIST = {
    { style = 0,   tints = ALL_TINTS }, { style = 1,  tints = ALL_TINTS }, { style = 2,  tints = ALL_TINTS },
    { style = 3,   tints = ALL_TINTS }, { style = 4,  tints = ALL_TINTS }, { style = 5,  tints = ALL_TINTS },
    { style = 6,   tints = ALL_TINTS }, { style = 7,  tints = ALL_TINTS }, { style = 8,  tints = ALL_TINTS },
    { style = 9,   tints = ALL_TINTS }, { style = 10, tints = ALL_TINTS }, { style = 14, tints = ALL_TINTS },
    { style = 15,  tints = ALL_TINTS }, { style = 302, tints = { 1 } },
    -- extra off-hand sets (same category, own names): R-series with 6 tints, and three one-offs
    -- whose item names carry no tint. fmt(sexLetter, tint) builds the item name.
    { style = 500, label = 'R05',        tints = { 1, 2, 3, 4, 5, 6 }, fmt = function(x, t) return ('CLOTHING_%s_R05_OFFHAND_000_TINT_%03d'):format(x, t) end },
    { style = 510, label = 'R1',         tints = { 1, 2, 3, 4, 5, 6 }, fmt = function(x, t) return ('CLOTHING_%s_R1_OFFHAND_000_TINT_%03d'):format(x, t) end },
    { style = 511, label = 'R1 B',       tints = { 1, 2, 3, 4, 5, 6 }, fmt = function(x, t) return ('CLOTHING_%s_R1_OFFHAND_001_TINT_%03d'):format(x, t) end },
    { style = 520, label = 'R2',         tints = { 1, 2, 3, 4, 5, 6 }, fmt = function(x, t) return ('CLOTHING_%s_R2_OFFHAND_000_TINT_%03d'):format(x, t) end },
    { style = 530, label = 'R3',         tints = { 1, 2, 3, 4, 5, 6 }, fmt = function(x, t) return ('CLOTHING_%s_R3_OFFHAND_000_TINT_%03d'):format(x, t) end },
    { style = 540, label = 'R4',         tints = { 1, 2, 3, 4, 5, 6 }, fmt = function(x, t) return ('CLOTHING_%s_R4_OFFHAND_000_TINT_%03d'):format(x, t) end },
    { style = 601, label = 'Black Rose', tints = { 1 }, fmt = function(x) return ('CLOTHING_ITEM_%s_BLACKROSE_OFFHAND_000'):format(x) end },
    { style = 602, label = 'Copperhead', tints = { 1 }, fmt = function(x) return ('CLOTHING_ITEM_%s_COPPERHEAD_OFFHAND_000'):format(x) end },
    { style = 603, label = 'Sony',       tints = { 1 }, fmt = function(x) return ('CLOTHING_ITEM_%s_SONY_OFFHAND_000'):format(x) end },
}
NI.OFFHAND_STYLES = { male = STYLE_LIST, female = STYLE_LIST }
NI.OFFHAND_DEFAULT = { style = 0, tint = 4, always = false }
NI.WEAPON_SLOTS   = { [0] = 'SLOTID_WEAPON_0', [1] = 'SLOTID_WEAPON_1' }  -- 0 = main (right), 1 = off-hand (left)

-- overridable for tests
NI.invoke = NI.invoke or function(...) return Citizen.InvokeNative(...) end
NI.pedId  = NI.pedId or function() return PlayerPedId() end

local function H(v)
    if type(v) == 'number' then return v end
    return GetHashKey(v)
end
NI.hash = H

local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    if Config and Config.Debug then print(('[MULTIinventory] native inventory: %s: %s'):format(key, tostring(msg))) end
end
NI.warnOnce = warnOnce

---Run fn under pcall; nil (and a one-time debug line) on error.
local function safe(key, fn, ...)
    local ok, a, b = pcall(fn, ...)
    if not ok then warnOnce(key, a); return nil end
    return a, b
end

-- ------------------------------------------------------------
-- GUID buffers
-- ------------------------------------------------------------
---A fresh, zeroed, non-interned 8*13-byte GUID buffer.
function NI.newGuid()
    if string.blob then return string.blob(NI.GUID_SIZE) end
    return string.rep('\0', NI.GUID_SIZE)
end

---Did a native write a GUID into this buffer (any non-zero byte)?
function NI.isSet(g)
    return type(g) == 'string' and g:find('[^\0]') ~= nil
end

local function truthy(v) return v ~= nil and v ~= false and v ~= 0 end

-- ------------------------------------------------------------
-- core helpers
-- ------------------------------------------------------------
---GUID of a native inventory item / container. category + slot = names or hashes; parent = GUID or nil.
function NI.GetGuid(category, slot, parent)
    return safe('GetGuid', function()
        local out = NI.newGuid()
        NI.invoke(NI.Natives.GetGuidFromItemId, NI.INVENTORY_ID, parent or 0, H(category), H(slot), out)
        if NI.isSet(out) then return out end
        warnOnce('GetGuid:' .. tostring(category), 'no guid')
        return nil
    end)
end

function NI.CharacterGuid() return NI.GetGuid('CHARACTER', NI.SLOT_CHARACTER, nil) end

function NI.WardrobeGuid()
    local c = NI.CharacterGuid()
    return c and NI.GetGuid('WARDROBE', NI.SLOT_WARDROBE, c) or nil
end

function NI.CarriedWeaponsGuid()
    local c = NI.CharacterGuid()
    return c and NI.GetGuid('CARRIED_WEAPONS', 'SLOTID_CARRIED_WEAPONS', c) or nil
end

---Add itemHash into slotHash under parentGuid and equip it. -> item GUID or nil.
function NI.AddAndEquip(itemHash, slotHash, parentGuid)
    if not parentGuid then return nil end
    return safe('AddAndEquip', function()
        local item = H(itemHash)
        local valid = NI.invoke(NI.Natives.IsKeyValid, item, 0, Citizen.ResultAsInteger())
        if valid ~= nil and not truthy(valid) then
            warnOnce('IsKeyValid:' .. tostring(itemHash), 'item key not valid')
            return nil
        end
        local out = NI.newGuid()
        NI.invoke(NI.Natives.AddItemWithGuid, NI.INVENTORY_ID, out, parentGuid, item, H(slotHash), 1, H('ADD_REASON_DEFAULT'))
        if not NI.isSet(out) then
            warnOnce('Add:' .. tostring(itemHash), 'add returned no guid')
            return nil
        end
        NI.invoke(NI.Natives.EquipItemWithGuid, NI.INVENTORY_ID, out, true)
        return out
    end)
end

---Move an item to slotHash under newParent. -> new GUID or nil.
function NI.Move(guid, newParent, slotHash)
    if not guid or not newParent then return nil end
    return safe('Move', function()
        local out = NI.newGuid()
        NI.invoke(NI.Natives.MoveItemWithGuid, NI.INVENTORY_ID, guid, newParent, H(slotHash), 1, out)
        if NI.isSet(out) then return out end
        return nil
    end)
end

---Remove an item from the native inventory. -> true when the call went through.
function NI.Remove(guid)
    if not guid then return false end
    return safe('Remove', function()
        NI.invoke(NI.Natives.RemoveItemWithGuid, NI.INVENTORY_ID, guid, 1, H('ADD_REASON_DEFAULT'))
        return true
    end) == true
end

-- ------------------------------------------------------------
-- off-hand holster (wardrobe)
-- ------------------------------------------------------------
local holster = { ped = nil, guids = nil, item = nil }

-- the character's chosen style (set through the SetOffhandHolsterStyle export); nil fields = config default
local chosen = { style = nil, tint = nil, always = nil }

local function cfgHolster()
    local w = Config and Config.Weapons
    return (type(w) == 'table' and type(w.offhandHolster) == 'table') and w.offhandHolster or {}
end

---'male' | 'female' for a ped (IsPedMale; anything unreadable counts as male, the old behaviour).
function NI.pedSex(ped)
    local ok, male = pcall(function() return IsPedMale(ped) end)
    if ok and (male == false or male == 0) then return 'female' end
    return 'male'
end

---Style entry { style, tints } for this sex, or nil when the game has no such style.
function NI.findStyle(sex, style)
    for _, s in ipairs(NI.OFFHAND_STYLES[sex] or NI.OFFHAND_STYLES.male) do
        if s.style == style then return s end
    end
    return nil
end

---Is style/tint a real off-hand item for this sex?
function NI.validStyle(sex, style, tint)
    local s = NI.findStyle(sex, tonumber(style))
    if not s then return false end
    for _, t in ipairs(s.tints) do if t == tonumber(tint) then return true end end
    return false
end

---Effective { style, tint, always } for a ped: the character's choice, else config, else 000 / 004;
---an invalid pair (e.g. a style this sex lacks) falls back to the default.
function NI.HolsterStyle(ped)
    local c, d = cfgHolster(), NI.OFFHAND_DEFAULT
    local sex = NI.pedSex(ped or NI.pedId())
    local style = tonumber(chosen.style or c.style or d.style)
    local tint = tonumber(chosen.tint or c.tint or d.tint)
    if not NI.validStyle(sex, style, tint) then
        style, tint = d.style, d.tint
        if NI.validStyle(sex, tonumber(c.style), tonumber(c.tint)) then style, tint = tonumber(c.style), tonumber(c.tint) end
    end
    local always = chosen.always
    if always == nil then always = c.always == true end
    if c.allowAlways == false then always = false end
    return { style = style, tint = tint, always = always == true, sex = sex }
end

---Wear the off-hand holster with the left hip empty?
function NI.AlwaysHolster() return NI.HolsterStyle().always end

---Item name of the off-hand holster clothing for a ped.
function NI.OffhandItemName(ped)
    local s = NI.HolsterStyle(ped)
    local x = s.sex == 'female' and 'F' or 'M'
    local def = NI.findStyle(s.sex, s.style)
    if def and def.fmt then return def.fmt(x, s.tint) end
    return ('CLOTHING_ITEM_%s_OFFHAND_%03d_TINT_%03d'):format(x, s.style, s.tint)
end

---Wardrobe items for this ped: the styled clothing item + the off-hand upgrade.
function NI.HolsterItems(ped)
    return { { item = NI.OffhandItemName(ped), slot = NI.HOLSTER_SLOT }, NI.HOLSTER_UPGRADE }
end

---Set the character's choice. nil args keep the current value. -> true, or false + reason
---('style' = no such style/tint for this ped's sex). Does not touch the ped (the caller re-applies).
function NI.SetHolsterStyle(style, tint, always)
    local sex = NI.pedSex(NI.pedId())
    local cur = NI.HolsterStyle()
    local s = style ~= nil and tonumber(style) or cur.style
    local t = tint ~= nil and tonumber(tint) or cur.tint
    if not NI.validStyle(sex, s, t) then return false, 'style' end
    chosen.style, chosen.tint = s, t
    if always ~= nil then chosen.always = (always == true or always == 1) end
    return true
end

---Forget the character's choice (back to the config default; character switch / no saved choice).
function NI.ResetHolsterStyle()
    chosen.style, chosen.tint, chosen.always = nil, nil, nil
end

---Available styles for the current ped's sex: { sex, styles = { { style, label, tints } }, current }.
function NI.StyleList()
    local cur = NI.HolsterStyle()
    local out = {}
    for _, s in ipairs(NI.OFFHAND_STYLES[cur.sex] or {}) do
        local tints = {}
        for i, t in ipairs(s.tints) do tints[i] = t end
        out[#out + 1] = { style = s.style, label = s.label or ('%03d'):format(s.style), tints = tints }
    end
    return { sex = cur.sex, styles = out, current = { style = cur.style, tint = cur.tint, always = cur.always } }
end

-- The wardrobe items make the game treat the left hip as a real off-hand holster (draw / dual
-- wield), but in multiplayer the game does not DRAW wardrobe clothing on its own. The leather is
-- put on the ped like any clothing: _APPLY_SHOP_ITEM_TO_PED with the item's hash, then a ped
-- variation update. The holsters_left category (0xB6B6122D) only holds off-hand holsters (the main
-- holster belongs to the gunbelt), so removing that tag never touches the right-hip holster.
NI.HOLSTERS_LEFT_CATEGORY = 0xB6B6122D
local APPLY_SHOP_ITEM_TO_PED   = 0xD3A7B003ED343FD9
local REMOVE_TAG_FROM_META_PED = 0xD710A5007C2AC539
local UPDATE_PED_VARIATION     = 0xCC8CA3E88256E58F

function NI.ShowHolsterLeather(ped, itemName)
    if not ped or ped == 0 or type(itemName) ~= 'string' then return false end
    local ok = pcall(NI.invoke, APPLY_SHOP_ITEM_TO_PED, ped, NI.hash(itemName), true, true, false)
    pcall(NI.invoke, UPDATE_PED_VARIATION, ped, false, true, true, true, false)
    return ok
end

function NI.HideHolsterLeather(ped)
    if not ped or ped == 0 then return false end
    local ok = pcall(NI.invoke, REMOVE_TAG_FROM_META_PED, ped, NI.HOLSTERS_LEFT_CATEGORY, 0)
    pcall(NI.invoke, UPDATE_PED_VARIATION, ped, false, true, true, true, false)
    return ok
end

-- Leather hidden on request (another resource draws its own holster model, e.g. RINGOweaponpositions'
-- "Custom holster"). The wardrobe items stay, so the left hip still works as an off-hand holster.
local leatherHidden = false
function NI.SetLeatherHidden(hidden) leatherHidden = hidden == true end
function NI.LeatherHidden() return leatherHidden end

---Add + equip the off-hand holster wardrobe items. Idempotent per ped and item; force = re-apply
---(spawn, character load, ped model change, clothing reload). -> true when both items are on.
function NI.EnsureOffhandHolster(force)
    local p = NI.pedId()
    local items = NI.HolsterItems(p)
    if not force and holster.guids and holster.ped == p and holster.item == items[1].item then return true end
    if holster.guids and (force or holster.item ~= items[1].item) then
        for _, g in ipairs(holster.guids) do NI.Remove(g) end
    end
    holster.guids, holster.ped, holster.item = nil, nil, nil
    -- the visible leather goes on first: it shows even if the wardrobe step below fails
    if leatherHidden then NI.HideHolsterLeather(p) else NI.ShowHolsterLeather(p, items[1].item) end
    holster.shownPed = p
    local wardrobe = NI.WardrobeGuid()
    if not wardrobe then return false end
    local guids = {}
    for _, h in ipairs(items) do
        local g = NI.AddAndEquip(h.item, h.slot, wardrobe)
        if not g then
            for _, x in ipairs(guids) do NI.Remove(x) end
            return false
        end
        guids[#guids + 1] = g
    end
    holster.guids, holster.ped, holster.item = guids, p, items[1].item
    return true
end

---Take the off-hand holster items off again (left hip emptied).
function NI.RemoveOffhandHolster()
    if holster.guids then for _, g in ipairs(holster.guids) do NI.Remove(g) end end
    -- only take the leather off a ped we put it on (never strip another script's clothing)
    if holster.shownPed and holster.shownPed == NI.pedId() then NI.HideHolsterLeather(holster.shownPed) end
    holster.guids, holster.ped, holster.item, holster.shownPed = nil, nil, nil, nil
end

function NI.HasOffhandHolster() return holster.guids ~= nil end
---Item name currently worn (nil when none).
function NI.WornOffhandItem() return holster.item end

-- ------------------------------------------------------------
-- sidearms in CARRIED_WEAPONS
-- ------------------------------------------------------------
---Add a sidearm into CARRIED_WEAPONS at SLOTID_WEAPON_<idx> (0 right / 1 left). -> GUID or nil.
function NI.AddSidearm(weaponHash, idx, carried)
    carried = carried or NI.CarriedWeaponsGuid()
    if not carried then return nil end
    return NI.AddAndEquip(weaponHash, NI.WEAPON_SLOTS[idx] or NI.WEAPON_SLOTS[0], carried)
end

---Move a sidearm to the other weapon slot. -> new GUID or nil.
function NI.MoveSidearm(guid, idx, carried)
    carried = carried or NI.CarriedWeaponsGuid()
    return NI.Move(guid, carried, NI.WEAPON_SLOTS[idx] or NI.WEAPON_SLOTS[0])
end

---Bind a weapon (by GUID) to hand attach slot 0 (main) / 1 (off-hand). -> true when the call went through.
function NI.BindToHand(ped, guid, attachSlot)
    if not guid then return false end
    return safe('BindToHand', function()
        NI.invoke(NI.Natives.SetCurrentPedWeaponByGuid, ped, guid, true, attachSlot or 0, false, false)
        return true
    end) == true
end

---Rounds in this gun's magazine (by GUID). nil when the native is unavailable.
function NI.ClipByGuid(ped, guid)
    if not guid then return nil end
    return safe('ClipByGuid', function()
        local ok, n = NI.invoke(NI.Natives.GetAmmoInClipByGuid, ped, Citizen.PointerValueInt(), guid, Citizen.ReturnResultAnyway())
        if not truthy(ok) then return nil end
        return tonumber(n)
    end)
end

---GUID of the weapon at an attach point (0 main hand / 1 off-hand). nil when none / unavailable.
function NI.GuidAtAttach(ped, attachPoint)
    return safe('GuidAtAttach', function()
        local out = NI.newGuid()
        NI.invoke(NI.Natives.GetPedWeaponGuidAtAttach, ped, attachPoint, out)
        if NI.isSet(out) then return out end
        return nil
    end)
end
