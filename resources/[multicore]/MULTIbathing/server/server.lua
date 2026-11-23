-- ============================================================
-- MULTIbathing :: server
-- One player per bath house at a time. The bath and the luxury
-- service are paid here, only near the counter, and cleanliness is
-- set here when the bath ends.
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- ============================================================

local Core = exports.MULTIcore:GetCoreObject()

local Sessions = {}   -- [town] = src
local Deluxe = {}     -- [src] = true once the luxury service is paid for this bath

local function getP(src) return Core.Functions.GetPlayer(tonumber(src)) end

local function notify(src, ntype, key, ...)
    local text = _L(key, ...)
    pcall(function()
        exports.MULTIcore:Notify(src, { title = _L('notify_title'), text = text, type = ntype })
    end)
end

local function money(P) return tonumber((P.PlayerData.money or {})[Config.Currency]) or 0 end

local function pay(P, amount, reason)
    if amount <= 0 then return true end
    if money(P) < amount then return false end
    return P.Functions.RemoveMoney(Config.Currency, amount, reason) ~= false
end

local function nearCounter(src, town)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - Config.BathingZones[town].consumer) <= Config.ServerDistance
end

local function endSession(src)
    for town, s in pairs(Sessions) do
        if s == src then Sessions[town] = nil end
    end
    Deluxe[src] = nil
end

--- MULTIhud (or MULTIp_hud) keeps the needs; without either the metadata is set straight away
local function setClean(src)
    for _, res in ipairs({ 'MULTIhud', 'MULTIp_hud' }) do
        if GetResourceState(res) == 'started' then
            local ok = pcall(function() exports[res]:SetNeed(src, 'cleanliness', Config.Cleanliness) end)
            if ok then return end
        end
    end
    local P = getP(src)
    if P then P.Functions.SetMetaData('cleanliness', Config.Cleanliness) end
end

RegisterNetEvent('MULTIbathing:server:start', function(town)
    local src = source
    local P = getP(src)
    if not P or type(town) ~= 'string' or not Config.BathingZones[town] then return end
    if not nearCounter(src, town) then notify(src, 'error', 'too_far') return end
    if Sessions[town] then notify(src, 'error', 'occupied') return end
    for _, s in pairs(Sessions) do if s == src then return end end
    if not pay(P, Config.NormalBathPrice, 'bath') then notify(src, 'error', 'not_enough_money') return end
    Sessions[town] = src
    Deluxe[src] = nil
    TriggerClientEvent('MULTIbathing:client:start', src, town)
end)

RegisterNetEvent('MULTIbathing:server:deluxe', function(town)
    local src = source
    if type(town) ~= 'string' or Sessions[town] ~= src or Deluxe[src] then return end
    local P = getP(src)
    if not P then return end
    if not pay(P, Config.DeluxeBathPrice, 'bath-deluxe') then
        notify(src, 'error', 'not_enough_money')
        TriggerClientEvent('MULTIbathing:client:deluxeRefused', src)
        return
    end
    Deluxe[src] = true
    TriggerClientEvent('MULTIbathing:client:deluxe', src, town)
end)

RegisterNetEvent('MULTIbathing:server:finish', function(town)
    local src = source
    if type(town) ~= 'string' or Sessions[town] ~= src then return end
    endSession(src)
    setClean(src)
    notify(src, 'success', 'refreshed')
end)

AddEventHandler('playerDropped', function() endSession(source) end)
