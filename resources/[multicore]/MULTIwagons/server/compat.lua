-- ============================================================
-- MULTIwagons :: rsg-wagons answers (server)
-- MULTIwagons `provide`s 'rsg-wagons'. rsg-wagons has no exports; scripts and
-- radial menus reach it through its table `rsg_wagons` (kept in the same
-- shape, see server/main.lua) and these event / callback names. Names,
-- arguments and return shapes follow RSG v2's rsg-wagons server/server.lua
-- (GPL v3, Phil and mack / Rexshack-RedM, see CREDITS.md).
--
--   callback rsg-wagons:checkMyWagons          -> models[], customs[]
--   callback rsg-wagons:isWagonRegistered(netId) -> registered, isOwner, wagonId, model, netId
--   callback rsg-wagons:getAnimalStorage(id)   -> {} (carcass storage is not part of the basic set)
--   event    rsg-wagons:getWagonDataByCitizenID([serverSource]) -> client rsg-wagons:receiveWagonData(model, custom, animals, id)
--   event    rsg-wagons:openWagonStash(stash, model, wagonId, netId) -> opens that wagon's storage
--   event    rsg-wagons:saveWagonToDatabase(model, custom, moneyType) -> buys at a dealer (custom.name)
--   event    rsg-wagons:sellWagon(model, custom) -> sells at a dealer (custom.name)
--   event    rsg-wagons:removeWagon(netId)      -> puts the sender's wagon away
--   event    rsg-wagons:toggleWagonActive(model, custom) -> takes that wagon out at the nearest dealer / call point
-- GPL v3, part of MULTIcore.
-- ============================================================

local C = {}

local function nearestPoint(src, dealerOnly)
    local pos = MW.PlayerPos(src)
    if not Config.ServerDistanceCheck then
        for name, p in pairs(MW.Points) do if not dealerOnly or p.dealer then return name end end
    end
    if not pos then return nil end
    for name, p in pairs(MW.Points) do
        if (not dealerOnly or p.dealer) and MW.NearPoint(pos, name, Config.MaxUseDistance) then return name end
    end
end

local function byName(src, name)
    local cid = MW.CitizenId(src)
    if not cid or type(name) ~= 'string' then return nil end
    for _, w in ipairs(MW.ListOf(cid)) do
        if w.name == name then return w end
    end
end

function C.checkMyWagons(src)
    local models, customs = {}, {}
    for _, w in ipairs(MW.ListOf(MW.CitizenId(src))) do
        models[#models + 1] = w.model
        customs[#customs + 1] = w.custom
    end
    return models, customs
end

function C.isWagonRegistered(src, netId)
    local o = MW.OutByNetId(netId)
    if not o then return false end
    return true, o.citizenid == MW.CitizenId(src), o.id, o.model, tonumber(netId)
end

function C.getAnimalStorage() return {} end

--- model, custom, animals, id of the sender's wagon that is out (nil when none)
function C.activeWagonData(src)
    local o = MW.OutOf(MW.CitizenId(src))
    local w = o and MW.Get(o.id)
    if not w then return nil end
    return w.model, w.custom, {}, w.id
end

function C.openWagonStash(src, stash, model, wagonId, netId)
    local o = MW.OutByNetId(netId) or MW.Out[tonumber(wagonId)]
    if not o then
        local id = type(stash) == 'string' and tonumber(stash:match('^Wagon_Stash_(%d+)$'))
        o = id and MW.Out[id]
    end
    if not o or o.pending then return false, 'no_wagon' end
    if Config.StorageOpenTo ~= 'anyone' and o.citizenid ~= MW.CitizenId(src) then return false, 'not_owner' end
    if Config.ServerDistanceCheck then
        local wpos, ppos = MW.WagonEntity(o), MW.PlayerPos(src)
        if not wpos or not ppos or #(ppos - wpos) > Config.StorageServerDistance then return false, 'too_far_wagon' end
    end
    return MW.OpenStorage(src, o.id)
end

function C.saveWagonToDatabase(src, model, custom)
    if type(custom) ~= 'table' then return false, 'bad_name' end
    if not nearestPoint(src, true) then return false, 'too_far' end
    return MW.Buy(src, model, custom.name)
end

function C.sellWagon(src, model, custom)
    local w = type(custom) == 'table' and byName(src, custom.name)
    if not w or w.model ~= model then return false, 'no_wagon' end
    if not nearestPoint(src, true) then return false, 'too_far' end
    return MW.Sell(src, w.id)
end

function C.removeWagon(src, netId)
    local o = MW.OutByNetId(netId) or MW.OutOf(MW.CitizenId(src))
    if not o then return false, 'not_out' end
    return MW.Store(src, o.id)
end

function C.toggleWagonActive(src, model, custom)
    local w = type(custom) == 'table' and byName(src, custom.name)
    if not w or w.model ~= model then return false, 'no_wagon' end
    local point = nearestPoint(src, false)
    if not point and not Config.CallAnywhere then return false, 'too_far' end
    return MW.TakeOut(src, w.id, point and MW.Points[point].def.spawn or nil)
end

-- ------------------------------------------------------------
-- registration under rsg-wagons' names
-- ------------------------------------------------------------

lib.callback.register('rsg-wagons:checkMyWagons', function(src) return C.checkMyWagons(src) end)
lib.callback.register('rsg-wagons:isWagonRegistered', function(src, netId) return C.isWagonRegistered(src, netId) end)
lib.callback.register('rsg-wagons:getAnimalStorage', function(src, id) return C.getAnimalStorage(src, id) end)

local function sendActive(src)
    local model, custom, animals, id = C.activeWagonData(src)
    if model then TriggerClientEvent('rsg-wagons:receiveWagonData', src, model, custom, animals, id) end
end

-- rsg-wagons also fires this one server-side with the player's id
RegisterNetEvent('rsg-wagons:getWagonDataByCitizenID', function(serverSource)
    local src = source
    if (src == nil or src == '' or tonumber(src) == nil) and serverSource then src = serverSource end
    sendActive(tonumber(src))
end)

local function report(src, ok, err)
    if not ok and err then MW.Notify(src, 'err_' .. tostring(err), 'error') end
end

RegisterNetEvent('rsg-wagons:openWagonStash', function(stash, model, wagonId, netId)
    local src = source
    local ok, err = C.openWagonStash(src, stash, model, wagonId, netId)
    if err ~= 'in_use' then report(src, ok, err) end
end)

RegisterNetEvent('rsg-wagons:saveWagonToDatabase', function(model, custom)
    local src = source
    local ok, err = C.saveWagonToDatabase(src, model, custom)
    report(src, ok, err)
    if ok then MW.Notify(src, 'bought', 'money', _L('wagon_' .. tostring(model)), MW.Money(MW.ByModel[model].price)) end
end)

RegisterNetEvent('rsg-wagons:sellWagon', function(model, custom)
    local src = source
    local ok, res = C.sellWagon(src, model, custom)
    report(src, ok, res)
    if ok then MW.Notify(src, 'sold', 'money', MW.Money(res)) end
end)

RegisterNetEvent('rsg-wagons:removeWagon', function(netId)
    local src = source
    report(src, C.removeWagon(src, netId))
end)

RegisterNetEvent('rsg-wagons:toggleWagonActive', function(model, custom)
    local src = source
    local ok, data = C.toggleWagonActive(src, model, custom)
    report(src, ok, data)
    if ok then TriggerClientEvent('MULTIwagons:client:spawn', src, data) end
end)

-- self-test only: lets test resources call the answers above with a pretend player
if GetConvar('multicore_selftest', 'false') == 'true' then
    exports('_TestCompat', function(name, src, ...)
        local fn = C[name]
        if not fn then return nil end
        return fn(src, ...)
    end)
end
