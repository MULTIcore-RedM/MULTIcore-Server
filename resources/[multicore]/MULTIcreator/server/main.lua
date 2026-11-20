-- ============================================================
-- MULTIcreator :: server
-- Barber payment. Cash is taken through the RSGCore player object
-- (MULTIcore's rsg-core face). The look itself is saved by the
-- client through MULTIcore's 'MULTIcore:look:save' callback.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local paid = {} -- [src] = { amount, at } last barber payment, for a refund if the save fails

local function dbg(...)
    if Config.Debug then print('[MULTIcreator]', ...) end
end

local function nearBarber(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    for _, shop in ipairs(Config.BarberShops) do
        if #(p - shop.coords) <= Config.Barber.useRange then return true end
        if shop.seat and #(p - vector3(shop.seat.x, shop.seat.y, shop.seat.z)) <= Config.Barber.useRange then return true end
    end
    return false
end

lib.callback.register('MULTIcreator:barber:pay', function(src)
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return false, 'player' end
    local price = Config.Barber.price
    if price <= 0 then return true end
    if Config.Barber.requireShop and not nearBarber(src) then return false, 'range' end
    if (P.PlayerData.money.cash or 0) < price then return false, 'money' end
    if not P.Functions.RemoveMoney('cash', price, 'barber') then return false, 'money' end
    paid[src] = { amount = price, at = os.time() }
    dbg(('player %s paid %s'):format(src, price))
    return true
end)

lib.callback.register('MULTIcreator:barber:refund', function(src)
    local p = paid[src]
    paid[src] = nil
    if not p or os.time() - p.at > Config.Barber.refundWindowSec then return false end
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return false end
    P.Functions.AddMoney('cash', p.amount, 'barber-refund')
    dbg(('player %s refunded %s'):format(src, p.amount))
    return true
end)

AddEventHandler('playerDropped', function() paid[source] = nil end)

-- TEMPORARY while testing (Config.DebugReport): the creator's in-game state, printed to the server console
RegisterNetEvent('MULTIcreator:debugReport', function(d)
    if not Config.DebugReport or type(d) ~= 'table' then return end
    local parts = {}
    for _, k in ipairs({ 'stage', 'model', 'male', 'pos', 'visible', 'alpha', 'ready', 'collision', 'imaps', 'cam', 'camActive', 'rendering', 'faded' }) do
        parts[#parts + 1] = k .. '=' .. tostring(d[k]):sub(1, 60)
    end
    print(('[MULTIcreator report] player %d: %s'):format(source, table.concat(parts, ' ')))
end)
