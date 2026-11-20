-- ============================================================
-- MULTIinventory :: rsg-inventory client face
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
--
-- The client exports and events RSG v2 scripts use, answered by MULTIinventory.
-- Reused from RSG v2 rsg-inventory (GPL v3, Copyright (C) RSG Framework contributors):
--   * client/exports.lua  HasItem(items, amount): same rules (string, array of
--     names, or { name = amount } map; the best single stack counts)
--   * client/events.lua   give animation (mech_butcher / small_fish_give_player)
--   * client/main.lua     rsg-inventory:client:isInMelee callback
-- Event names: from callers in rsg-v2-framework and other resources.
-- ============================================================

-- ---------------------------------------------------------------
-- exports
-- ---------------------------------------------------------------

local function isArray(t)
    if type(t) ~= 'table' then return false end
    local n = 0
    for k in pairs(t) do
        if type(k) ~= 'number' then return false end
        if k > n then n = k end
    end
    return n == #t
end

--- exports['rsg-inventory']:HasItem(items, amount)
local function HasItem(items, amount)
    local inv = MIC.PlayerItems()
    if type(items) ~= 'table' then
        for _, it in pairs(inv) do
            if it.name == items and (amount == nil or (tonumber(it.amount) or 0) >= amount) then return true end
        end
        return false
    end
    local best = {}
    for _, it in pairs(inv) do
        local a = tonumber(it.amount) or 0
        if not best[it.name] or a > best[it.name] then best[it.name] = a end
    end
    if isArray(items) then
        for _, name in ipairs(items) do
            local have = best[name]
            if have == nil or (amount ~= nil and have < amount) then return false end
        end
        return true
    end
    for name, need in pairs(items) do
        local have = best[name]
        if have == nil or (need ~= nil and have < need) then return false end
    end
    return true
end
exports('HasItem', HasItem)

-- MULTI extras some scripts find handy
exports('GetItemCount', function(name) return MIC.CountItem(name) end)
exports('GetPlayerItems', function() return MIC.PlayerItems() end)
exports('IsOpen', function() return MIC.IsOpen end)
exports('OpenInventory', function() MIC.RequestOpen() end)
exports('CloseInventory', function() MIC.Close(true) end)
exports('ItemBox', function(def, kind, amount) MIC.ItemBox(def, amount, kind) end)

-- ---------------------------------------------------------------
-- events
-- ---------------------------------------------------------------

-- the server (or a script's fallback) asks to show the satchel, maybe with a second inventory;
-- we never trust the contents sent here, only the id, and ask the engine to open it properly
local function openFromRsg(a, b)
    local other = type(b) == 'table' and b or nil
    local id
    if type(a) == 'string' then
        id = a
    elseif other then
        id = other.name or other.id
    elseif type(a) == 'table' and (a.type or a.id) then
        id = a.id or a.name
    end
    if id then
        TriggerServerEvent('MULTIinventory:server:openInventory', id)
    else
        TriggerServerEvent('MULTIinventory:server:openSelf')
    end
end
RegisterNetEvent('rsg-inventory:client:openInventory', openFromRsg)
RegisterNetEvent('rsg-inventory:client:OpenInventory', openFromRsg)

RegisterNetEvent('rsg-inventory:client:closeInv', function() MIC.Close(true) end)

RegisterNetEvent('rsg-inventory:client:updateInventory', function()
    TriggerServerEvent('MULTIinventory:server:refresh')
end)

RegisterNetEvent('rsg-inventory:client:refreshInventory', function()
    TriggerServerEvent('MULTIinventory:server:refresh')
end)

-- item box: RSG v2 name and the older QBCore-style name both seen in callers
RegisterNetEvent('rsg-inventory:client:ItemBox', function(def, kind, amount) MIC.ItemBox(def, amount, kind) end)
RegisterNetEvent('inventory:client:ItemBox', function(def, kind, amount) MIC.ItemBox(def, amount, kind) end)

RegisterNetEvent('rsg-inventory:client:hotbar', function() MIC.ToggleHotbar() end)
RegisterNetEvent('rsg-inventory:client:updateHotbar', function() MIC.ShowHotbar(false) end)

RegisterNetEvent('rsg-inventory:client:giveAnim', function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsPedOnMount(ped) then return end
    local dict = MIC.Cfg('Give.AnimDict', 'mech_butcher')          -- UNVERIFIED locally (rsg-inventory uses it)
    local anim = MIC.Cfg('Give.AnimName', 'small_fish_give_player') -- UNVERIFIED locally (rsg-inventory uses it)
    if not dict or dict == '' then return end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    if not HasAnimDictLoaded(dict) then return end
    TaskPlayAnim(ped, dict, anim, 8.0, 1.0, -1, 16, 0, false, false, false)
    RemoveAnimDict(dict)
end)

lib.callback.register('rsg-inventory:client:isInMelee', function()
    return IsPedInMeleeCombat(PlayerPedId())
end)

