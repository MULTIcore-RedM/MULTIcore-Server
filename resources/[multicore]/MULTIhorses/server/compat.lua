-- ============================================================
-- MULTIhorses :: server answers for scripts written for rsg-horses
-- MULTIhorses provides 'rsg-horses' (fxmanifest). Every server event and
-- callback of MULTIhorses is also answered under its rsg-horses name,
-- running the very same function with the same checks:
--   events     rsg-horses:server:<name>   (and rsg-horses:renameHorse)
--   callbacks  rsg-horses:server:<name>   as ox_lib callbacks and as core callbacks
-- Known callers: starter horses that character scripts insert straight into
-- player_horses (same table and columns), scripts that read player_horses,
-- and scripts that talk to rsg-horses the way its own client does.
-- ============================================================
local Core = exports['rsg-core']:GetCoreObject()
local OLD = 'rsg-horses'

-- events
for name, fn in pairs(Horses.events) do
    RegisterNetEvent(OLD .. ':server:' .. name, fn)
end
if Horses.events.renameHorse then
    RegisterNetEvent(OLD .. ':renameHorse', Horses.events.renameHorse)
end

-- ox_lib callbacks, also answered as core callbacks
for name, fn in pairs(Horses.callbacks) do
    lib.callback.register(OLD .. ':server:' .. name, fn)
    Core.Functions.CreateCallback(OLD .. ':server:' .. name, function(source, cb, ...)
        cb(fn(source, ...))
    end)
end

-- core callbacks, also answered as ox_lib callbacks
for name, fn in pairs(Horses.coreCallbacks) do
    Core.Functions.CreateCallback(OLD .. ':server:' .. name, fn)
    lib.callback.register(OLD .. ':server:' .. name, function(source, ...)
        local p = promise.new()
        fn(source, function(result) p:resolve(result) end, ...)
        return Citizen.Await(p)
    end)
end

-- and the same answers under MULTIhorses' own name the other way round, so a
-- script may use either kind of callback with either name
for name, fn in pairs(Horses.callbacks) do
    Core.Functions.CreateCallback('MULTIhorses:server:' .. name, function(source, cb, ...)
        cb(fn(source, ...))
    end)
end
for name, fn in pairs(Horses.coreCallbacks) do
    lib.callback.register('MULTIhorses:server:' .. name, function(source, ...)
        local p = promise.new()
        fn(source, function(result) p:resolve(result) end, ...)
        return Citizen.Await(p)
    end)
end

-- ------------------------------------------------------------
-- server exports, as MULTIhorses and as rsg-horses
-- ------------------------------------------------------------
local function export(name, fn)
    exports(name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(OLD, name), function(setCB) setCB(fn) end)
end

local function cidOf(srcOrCid)
    if type(srcOrCid) == 'string' and not tonumber(srcOrCid) then return srcOrCid end
    local P = Core.Functions.GetPlayer(tonumber(srcOrCid))
    return P and P.PlayerData.citizenid or nil
end

--- every horse of a player (server id) or citizenid
export('GetHorses', function(srcOrCid)
    local cid = cidOf(srcOrCid)
    if not cid then return {} end
    return MySQL.query.await('SELECT * FROM player_horses WHERE citizenid = ?', { cid }) or {}
end)

--- the active horse row of a player (server id) or citizenid, or nil
export('GetActiveHorse', function(srcOrCid)
    local cid = cidOf(srcOrCid)
    if not cid then return nil end
    return MySQL.single.await('SELECT * FROM player_horses WHERE citizenid = ? AND active = 1 LIMIT 1', { cid })
end)

--- the MULTIinventory id of a horse's saddlebags
export('SaddlebagId', function(horseid) return SaddlebagId(horseid) end)

--- what a stable pays for a horse of this model (nil = not sold here)
export('SellPrice', function(model) return SellPrice(model) end)

--- true once the table is set up
export('IsReady', function() return DB and DB.ready == true end)
