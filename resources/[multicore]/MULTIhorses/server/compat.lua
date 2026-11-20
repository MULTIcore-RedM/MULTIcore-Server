-- ============================================================
-- MULTIhorses :: rsg-horses server compatibility
-- Names and argument shapes follow rsg-horses 2.3.3 (RSG v2 framework,
-- GPL v3; server/server.lua). Each one runs MULTIhorses' own checks.
-- Callers found: rsg-multicharacter and RINGOmulticharacterV2 insert
-- starter horses into player_horses; RINGOwagons / RINGOitemplacer read
-- player_horses; rsg-appearance and rsg-radialmenu fire client events
-- (client/compat.lua). The rest is here for scripts that talk to
-- rsg-horses the way its own client does.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local function cidOf(src)
    local P = RSGCore.Functions.GetPlayer(src)
    return P and P.PlayerData.citizenid or nil
end

--- The stable the player stands at, for rsg-horses events that name none.
local function hereId(src)
    local s = Horses.StableAt(src)
    return s and s.id or nil
end

-- rsg-horses rows (player_horses columns) --------------------------------
local function rawActive(cid)
    return cid and MySQL.single.await('SELECT * FROM player_horses WHERE citizenid = ? AND active = 1 LIMIT 1', { cid }) or nil
end

lib.callback.register('rsg-horses:server:GetActiveHorse', function(src)
    return rawActive(cidOf(src))
end)

lib.callback.register('rsg-horses:server:GetHorse', function(src, stableid)
    local cid = cidOf(src)
    if not cid or type(stableid) ~= 'string' then return {} end
    return MySQL.query.await('SELECT * FROM player_horses WHERE citizenid = ? AND stable = ?', { cid, stableid }) or {}
end)

lib.callback.register('rsg-horses:server:GetAllHorses', function(src)
    local cid = cidOf(src)
    if not cid then return {} end
    return MySQL.query.await('SELECT name, stable, active FROM player_horses WHERE citizenid = ?', { cid }) or {}
end)

lib.callback.register('rsg-horses:server:GetPlayerHorses', function(src)
    local cid = cidOf(src)
    if not cid then return {} end
    return MySQL.query.await('SELECT id, name, horse, gender, age_seconds, pregnant_until FROM player_horses WHERE citizenid = ?', { cid }) or {}
end)

-- the client asks before an item is used up (rsg-horses' check); MULTIhorses checks on the server instead
lib.callback.register('rsg-horses:server:getHorseWeapon', function() return nil end)

-- events -------------------------------------------------------------------

-- (model, stableid, horsename, gender)
RegisterNetEvent('rsg-horses:server:BuyHorse', function(model, stableid, horsename, gender)
    Horses.Buy(source, stableid, model, horsename, gender)
end)

-- (id) make this horse the active one; at the stable the player stands at
RegisterNetEvent('rsg-horses:server:SetHoresActive', function(id)
    local src = source
    Horses.SetActive(src, id, hereId(src))
end)

-- (stableid) put the active horse in this stable
RegisterNetEvent('rsg-horses:server:SetHoresUnActive', function(stableid)
    Horses.Store(source, stableid)
end)

-- (id) sell the horse to the stable the player stands at
RegisterNetEvent('rsg-horses:server:deletehorse', function(id)
    local src = source
    Horses.Sell(src, id, hereId(src))
end)

-- (id, newStableId) send a horse from the stable the player stands at to another
RegisterNetEvent('rsg-horses:server:MoveHorse', function(id, newStableId)
    local src = source
    Horses.Transfer(src, id, newStableId, hereId(src))
end)

-- (name) rename the active horse
RegisterNetEvent('rsg-horses:renameHorse', function(name)
    local src = source
    local horse = Horses.Active(cidOf(src))
    if not horse then return Horses.notify(src, _L('err_no_active'), 'error') end
    Horses.Rename(src, horse.id, name)
end)

-- open the saddlebags of the horse beside the player
RegisterNetEvent('rsg-horses:server:openhorseinventory', function()
    Horses.OpenSaddlebag(source)
end)

-- the active horse died (rsg-horses deleted it; here it is hurt until revived)
RegisterNetEvent('rsg-horses:server:HorseDied', function()
    Horses.Died(source)
end)

-- (dirt 0-100) saved on the active horse
RegisterNetEvent('rsg-horses:server:sethorseAttributes', function(dirt)
    local cid = cidOf(source)
    dirt = tonumber(dirt)
    if not cid or not dirt or dirt < 0 or dirt > 100 then return end
    MySQL.update('UPDATE player_horses SET dirt = ? WHERE citizenid = ? AND active = 1', { math.floor(dirt), cid })
end)

-- shop: rsg-horses opened its own 'horse' shop; MULTIstores' general stores sell horse care
RegisterNetEvent('rsg-horses:server:openShop', function()
    Horses.dbg('ignored rsg-horses:server:openShop from', source)
end)

-- accepted and ignored: breeding, trading, horse holster weapons, customisation buckets are premium features
for _, name in ipairs({ 'rsg-horses:server:fleeStoreHorse', 'rsg-horses:server:breedHorse', 'rsg-horses:server:TradeHorse',
    'rsg-horses:server:AcceptTrade', 'rsg-horses:server:storeHorseWeapon', 'rsg-horses:server:retrieveHorseWeapon',
    'rsg-horses:server:SaveComponents', 'rsg-horses:server:SetPlayerBucket' }) do
    RegisterNetEvent(name, function() Horses.dbg('ignored', name, 'from', source) end)
end
