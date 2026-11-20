-- ============================================================
-- MULTIcore :: RedEM:RP face - the core object, callbacks, events
-- exports['redem_roleplay']:RedEM() returns this. Written from RedEM:RP's
-- public API (the 2023 redem_roleplay); no RedEM:RP code is used.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

MULTI.Redem = MULTI.Redem or {}
local R = MULTI.Redem

local RedEM = { Functions = {}, Players = {} }

-- ------------------------------------------------------------
-- players
-- ------------------------------------------------------------

function RedEM.GetPlayer(src) return R.BuildPlayer(src) end

function RedEM.GetPlayerByCitizenId(cid)
    local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
    return P and R.BuildPlayer(P.PlayerData.source) or nil
end

--- cb(map of source -> player) for every online player with a character.
function RedEM.GetAllPlayers(cb)
    local out = {}
    for src in pairs(RSGCore.Players) do out[src] = R.BuildPlayer(src) end
    if cb then cb(out) end
    return out
end

-- Players as a field: filled when the object is handed out (a snapshot, as on RedEM:RP)
local function snapshot()
    RedEM.Players = RedEM.GetAllPlayers()
    return RedEM
end

--- The redemrp_inventory API (MULTIinventory answers it).
function RedEM.GetInventory()
    local inv
    TriggerEvent('redemrp_inventory:getData', function(data) inv = data end)
    return inv
end

-- ------------------------------------------------------------
-- callbacks: RedEM.RegisterCallback (server) / RedEM.TriggerCallback (client)
-- ------------------------------------------------------------

local serverCallbacks = {}

function RedEM.RegisterCallback(name, fn)
    if type(name) == 'string' and fn then serverCallbacks[name] = fn end
end

RegisterNetEvent('MULTIcore:redem:cb', function(name, reqId, ...)
    local src = source
    local fn = serverCallbacks[name]
    if not fn then return end
    local ok, err = pcall(fn, src, function(...)
        TriggerClientEvent('MULTIcore:redem:cbReply', src, reqId, ...)
    end, ...)
    if not ok then print(('^1[MULTIcore] RedEM callback %s failed: %s^7'):format(tostring(name), tostring(err))) end
end)

-- server asks a client: RedEM.TriggerClientCallback(name, src, cb, ...)
local pending, nextId = {}, 0

function RedEM.TriggerClientCallback(name, src, cb, ...)
    nextId = nextId + 1
    pending[nextId] = { src = tonumber(src), cb = cb }
    TriggerClientEvent('MULTIcore:redem:ccb', src, name, nextId, ...)
end

RegisterNetEvent('MULTIcore:redem:ccbReply', function(reqId, ...)
    local p = pending[reqId]
    if not p or p.src ~= source then return end
    pending[reqId] = nil
    if p.cb then p.cb(...) end
end)

-- ------------------------------------------------------------
-- notifications: all drawn by MULTIcore
-- ------------------------------------------------------------

function RedEM.Functions.NotifyLeft(src, title, text, _dict, _icon, ms)
    MULTI.Notify(src, { title = title, text = text, duration = tonumber(ms) })
end

function RedEM.Functions.NotifyRight(src, text, ms)
    MULTI.Notify(src, { text = text, duration = tonumber(ms), style = 'tip' })
end

function RedEM.Functions.NotifyTip(src, text, ms)
    MULTI.Notify(src, { text = text, duration = tonumber(ms), style = 'tip' })
end

RedEM.NotifyLeft = RedEM.Functions.NotifyLeft
RedEM.NotifyRight = RedEM.Functions.NotifyRight

-- ------------------------------------------------------------
-- the export, and the old event forms
-- ------------------------------------------------------------

R.Core = RedEM
MULTI.ExportAs('redem_roleplay', 'RedEM', snapshot)

AddEventHandler('redemrp:getPlayerFromId', function(src, cb) if cb then cb(R.BuildPlayer(src)) end end)
AddEventHandler('redem:getPlayerFromId', function(src, cb) if cb then cb(R.BuildPlayer(src)) end end)

-- ------------------------------------------------------------
-- loaded / unloaded and data changes
-- ------------------------------------------------------------

AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    local src = P.PlayerData.source
    if not src then return end
    R.Push(src)
    TriggerEvent('redemrp:playerLoaded', src, R.BuildPlayer(src))
    TriggerClientEvent('redemrp:moneyLoaded', src, P.PlayerData.money.cash or 0)
    TriggerClientEvent('redemrp_charselect:client:FinishSelection', src, false)
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    local obj = R.BuildPlayer(src)
    if obj then TriggerEvent('redemrp:playerDropped', obj) end
    pcall(function() Player(src).state:set('isLoggedIn', false, true) end)
end)

-- leaving the server: RSG's PlayerDropped runs while the player is still loaded
AddEventHandler('RSGCore:Server:PlayerDropped', function(P)
    local obj = P and R.BuildPlayer(P.PlayerData.source)
    if obj then TriggerEvent('redemrp:playerDropped', obj) end
end)

local function refresh(src) if RSGCore.Players[src] then R.Push(src) end end
AddEventHandler('RSGCore:Server:OnJobUpdate', function(src) refresh(src) end)
AddEventHandler('RSGCore:Server:OnGangUpdate', function(src) refresh(src) end)
AddEventHandler('RSGCore:Server:OnMoneyChange', function(src) refresh(src) end)
