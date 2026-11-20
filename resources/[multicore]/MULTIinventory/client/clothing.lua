-- ============================================================
-- MULTIinventory :: client/clothing.lua
--
-- Puts the worn pieces (server event 'MULTIinventory:cl:clothing') on the local ped with public
-- RDR3 ped natives and keeps them on: re-apply after character load, respawn, ped/model change
-- (Config.Clothing.reapplyDelayMs after the framework applied its own look).
--   route A  apply shop item        0xD3A7B003ED343FD9 (ped, comp, false, false|true, false)
--            base wearable state    0x66B957AAC2EAAEAB, components updated 0xAAB86462966168CE
--            tint on the category   0x4EFC1F8FF1AD94DE (ped, categoryHash, palette, tint0, tint1, tint2)
--   route B  set metaped tag        0xBC6DF00D7A4A6819 (ped, drawable, albedo, normal, material, palette, t0, t1, t2)
--   remove   remove tag from ped    0xD710A5007C2AC539 (ped, categoryHash, 0)
--   refresh  update ped variation   0xCC8CA3E88256E58F (ped, false, true, true, true, false)
--   ready    is ped ready to render 0xA0BC8FAED8CFEB3C (ped)
-- Unworn categories are removed only when the server says the character is managed by the
-- inventory ("authoritative" = seeded) - otherwise only pieces this client put on are removed,
-- so a character whose clothes were never imported keeps the framework look.
-- vorp_character's clothing toggles (vorp_character:Client:OnClothingRemoved/Added, event names
-- only) mark a category "hidden, still owned": it is not re-applied until shown again.
--
-- Client exports (exports.MULTIinventory:<Name>):
--   PreviewClothing(meta | { meta, ... }) -> ok, err    live preview on the own ped (tailor panel)
--   ClearPreview()                                     back to the worn set
--   GetWornLocal() -> { [key] = meta }                 ReapplyClothing()
-- Client-local events: MULTIinventory:client:clothingChanged (pieces), :client:clothingApplied (reason)
-- ============================================================

ClothingClient = ClothingClient or {}
local CL = ClothingClient

CL.pieces = {}          -- [key] = meta (server truth)
CL.applied = {}         -- [key] = true  categories this client put on
CL.hidden = {}          -- [key] = true  hidden by a framework toggle
CL.preview = nil        -- [key] = meta  while previewing
CL.authoritative = false
CL.loaded = false

local function CC() return Config.Clothing or {} end

local catHashes = {}
local function catHash(cat)
    local h = catHashes[cat.key]
    if not h then h = joaat(cat.game); catHashes[cat.key] = h end
    return h
end

local function pedGender(ped)
    if IsPedMale(ped) then return 'male' end
    return 'female'
end

local function waitReady(ped)
    local deadline = GetGameTimer() + (tonumber(CC().readyTimeoutMs) or 3000)
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and GetGameTimer() < deadline do Wait(0) end
end

local function refresh(ped)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

-- Layering: every shop item is put back in its "base" wearable state and the ped's active
-- components are marked updated (same steps as vorp_character's skin reload), otherwise the
-- pieces under a coat / over boots keep a stale layer state and clip through each other.
local WEARABLE_BASE = joaat('base')
local NO_BASE_STATE = { Boots = true }   -- boots keep their own state (pants tucked or over)
local LAST_LAYER = { 'Shirt', 'Vest', 'Boots' }   -- re-applied once more at the end, like the reload

local function applyPiece(ped, cat, m)
    local comp = tonumber(m.comp)
    if comp then
        comp = math.tointeger(comp)
        -- same two calls as vorp_character's ApplyShopItemToPed: the story pass then the MP pass, so
        -- the piece lands whichever kind it is (no guessing, no double layer from a wrong flag)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, comp, false, false, false)
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, comp, false, true, false)
        if not NO_BASE_STATE[cat.key] then
            Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, comp, WEARABLE_BASE, 0, true, true)
        end
        Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
        if m.palette and m.palette ~= 0 then
            Citizen.InvokeNative(0x4EFC1F8FF1AD94DE, ped, catHash(cat), math.tointeger(m.palette),
                m.tint0 or 0, m.tint1 or 0, m.tint2 or 0)
        end
        if m.drawable then
            Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, m.drawable, m.albedo or 0, m.normal or 0, m.material or 0,
                m.palette or 0, m.tint0 or 0, m.tint1 or 0, m.tint2 or 0)
        end
    elseif m.drawable then
        -- a drawable set is added as a tag: clear the category first so it replaces the old piece, not stacks on it
        Citizen.InvokeNative(0xD710A5007C2AC539, ped, catHash(cat), 0)
        Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, m.drawable, m.albedo or 0, m.normal or 0, m.material or 0,
            m.palette or 0, m.tint0 or 0, m.tint1 or 0, m.tint2 or 0)
    end
end

local function removeCat(ped, cat)
    Citizen.InvokeNative(0xD710A5007C2AC539, ped, catHash(cat), 0)
end

-- layering order: Config.Clothing.applyOrder first, then slot order
local orderList
local function order()
    if orderList then return orderList end
    orderList = {}
    local seen = {}
    for _, k in ipairs(CC().applyOrder or {}) do
        local c = ClothingCategoriesByKey[k]
        if c and not seen[k] then orderList[#orderList + 1] = c; seen[k] = true end
    end
    for _, c in ipairs(ClothingCategories) do
        if not seen[c.key] then orderList[#orderList + 1] = c; seen[c.key] = true end
    end
    return orderList
end

local function conflictsOf(key)
    local out = {}
    for _, pair in ipairs(CC().exclusions or {}) do
        if pair[1] == key then out[#out + 1] = pair[2] elseif pair[2] == key then out[#out + 1] = pair[1] end
    end
    return out
end

local applying = false
---Put the worn set (plus an active preview) on the ped.
function CL.apply(reason)
    if applying then CL.dirty = true return end
    applying = true
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        local g = pedGender(ped)
        local hideByPreview = {}
        if CL.preview then
            for k in pairs(CL.preview) do for _, o in ipairs(conflictsOf(k)) do hideByPreview[o] = true end end
        end
        local now = {}
        for _, cat in ipairs(order()) do
            local m = (CL.preview and CL.preview[cat.key]) or CL.pieces[cat.key]
            local show = m ~= nil and not hideByPreview[cat.key]
                and (CL.preview and CL.preview[cat.key] or not CL.hidden[cat.key])
                and ClothingMeta.genderOk(m.gender, g)
            if show then
                applyPiece(ped, cat, m)
                now[cat.key] = true
            elseif CL.authoritative or CL.applied[cat.key] or hideByPreview[cat.key] then
                removeCat(ped, cat)
            end
        end
        CL.applied = now
        refresh(ped)
        waitReady(ped)
        for _, key in ipairs(LAST_LAYER) do
            local cat = ClothingCategoriesByKey[key]
            local m = cat and now[key] and ((CL.preview and CL.preview[key]) or CL.pieces[key])
            if m then applyPiece(ped, cat, m) end
        end
        Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
        refresh(ped)
        waitReady(ped)
        TriggerEvent('MULTIinventory:client:clothingApplied', reason)
    end
    applying = false
    if CL.dirty then CL.dirty = false; CL.apply('again') end
end

-- debounced re-apply (load / respawn / model change: let the framework finish first)
local token = 0
function CL.schedule(reason, delay)
    token = token + 1
    local my = token
    SetTimeout(delay or tonumber(CC().reapplyDelayMs) or 1500, function()
        if my ~= token then return end
        CL.apply(reason)
    end)
end

RegisterNetEvent('MULTIinventory:cl:clothing', function(data)
    if type(data) ~= 'table' then return end
    CL.pieces = type(data.pieces) == 'table' and data.pieces or {}
    CL.authoritative = data.authoritative == true
    CL.charId = data.charId
    TriggerEvent('MULTIinventory:client:clothingChanged', CL.pieces)
    if data.reason == 'load' then
        CL.loaded = true
        CL.hidden = {}
        CL.schedule('load')
    elseif CL.loaded then
        CreateThread(function() CL.apply(data.reason or 'change') end)
    else
        CL.loaded = true
        CL.schedule(data.reason or 'change')
    end
end)

-- rsg face (server/clothing/appearance_rsg.lua) pings after its mirror: our own set is the truth
RegisterNetEvent('MULTIinventory:rsg:applyClothes', function()
    if CL.loaded then CL.schedule('rsg', 250) end
end)

-- framework lifecycle (event names only)
-- vorp_core sends this from the server (TriggerClientEvent), so it must be net-registered here
RegisterNetEvent('vorp:SelectedCharacter', function() CL.hidden = {}; if CL.loaded then CL.schedule('vorp_select') end end)
AddEventHandler('vorpcharacter:reloadafterdeath', function() if CL.loaded then CL.schedule('vorp_death') end end)
AddEventHandler('RSGCore:Client:OnPlayerLoaded', function() if CL.loaded then CL.schedule('rsg_load') end end)

-- vorp_character clothing toggles: hidden, still owned (the item is NOT moved)
local function keyFromArgs(...)
    for _, a in ipairs({ ... }) do
        if type(a) == 'string' then
            local c = ClothingCategoriesByKey[a] or ClothingCategoriesByGame[a:lower()]
            if c then return c.key end
        elseif type(a) == 'table' then
            local k = a.category or a.key or a.name
            if type(k) == 'string' then
                local c = ClothingCategoriesByKey[k] or ClothingCategoriesByGame[k:lower()]
                if c then return c.key end
            end
        end
    end
    return nil
end
AddEventHandler('vorp_character:Client:OnClothingRemoved', function(...)
    local k = keyFromArgs(...)
    if k then CL.hidden[k] = true end
end)
AddEventHandler('vorp_character:Client:OnClothingAdded', function(...)
    local k = keyFromArgs(...)
    if k then CL.hidden[k] = nil end
end)

-- watcher: new ped handle, model change, back alive after death -> re-apply
CreateThread(function()
    local lastPed, lastModel, wasDead = 0, 0, false
    while true do
        Wait(tonumber(CC().watchIntervalMs) or 1000)
        if CL.loaded and not applying then
            local ped = PlayerPedId()
            local model = GetEntityModel(ped)
            local dead = IsEntityDead(ped)
            if ped ~= lastPed or model ~= lastModel then
                lastPed, lastModel = ped, model
                CL.schedule('ped_change')
            elseif wasDead and not dead then
                CL.schedule('respawn')
            end
            wasDead = dead
        end
    end
end)

-- ------------------------------------------------------------
-- preview (tailor trade in RINGOjobsandcrafting, shops)
-- ------------------------------------------------------------
local function previewPiece(m)
    local built, err = ClothingMeta.build(m, { trusted = true })
    if not built then return nil, err end
    return built
end

function CL.previewSet(input)
    if type(input) ~= 'table' then return false, 'bad_spec' end
    local list = input.category and { input } or input
    if type(list.pieces) == 'table' then list = list.pieces end   -- an outfit bundle's metadata
    local map = {}
    for _, m in ipairs(list) do
        local built, err = previewPiece(m)
        if not built then return false, err end
        map[built.category] = built
    end
    if next(map) == nil then return false, 'no_pieces' end
    CL.preview = map
    CreateThread(function() CL.apply('preview') end)
    return true
end

function CL.clearPreview()
    if not CL.preview then return true end
    CL.preview = nil
    CreateThread(function() CL.apply('preview_end') end)
    return true
end

exports('PreviewClothing', function(meta) return CL.previewSet(meta) end)
exports('ClearPreview', function() return CL.clearPreview() end)
exports('GetWornLocal', function()
    local out = {}
    for k, m in pairs(CL.pieces) do
        local c = {}
        for kk, v in pairs(m) do c[kk] = v end
        out[k] = c
    end
    return out
end)
exports('ReapplyClothing', function() CreateThread(function() CL.apply('export') end) end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and CL.preview then
        CL.preview = nil
        CL.apply('stop')
    end
end)
