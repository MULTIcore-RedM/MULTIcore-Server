-- ============================================================
-- MULTIwagons :: what a game client may ask (server)
-- Every request is rate limited, and checked for ownership and distance
-- (OneSync) before the engine in server/main.lua runs it. The server
-- answers with { ok, err } and tells the player itself.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local calls = {}
local function rateLimited(src)
    local now = GetGameTimer()
    local keep = {}
    for _, t in ipairs(calls[src] or {}) do
        if now - t < Config.RateLimit.WindowMs then keep[#keep + 1] = t end
    end
    calls[src] = keep
    if #keep >= Config.RateLimit.Calls then return true end
    keep[#keep + 1] = now
    return false
end
AddEventHandler('playerDropped', function() calls[source] = nil end)

local function fail(src, err)
    MW.Notify(src, 'err_' .. tostring(err or 'error'), 'error')
    return { ok = false, err = err }
end

--- Is src standing at the named dealer / call point? dealerOnly = must be a dealer.
local function atPoint(src, name, dealerOnly)
    local p = type(name) == 'string' and MW.Points[name]
    if not p then return false end
    if dealerOnly and not p.dealer then return false end
    if not Config.ServerDistanceCheck then return true end
    return MW.NearPoint(MW.PlayerPos(src), name, Config.MaxUseDistance)
end

--- Is src close enough to his wagon that is out? → o, wagonPos | nil, err
local function atOwnWagon(src, id, dist)
    local cid = MW.CitizenId(src)
    local o = id and MW.Out[tonumber(id)] or MW.OutOf(cid)
    if not o then return nil, 'not_out' end
    if o.citizenid ~= cid then return nil, 'not_owner' end
    local wpos = MW.WagonEntity(o)
    if not Config.ServerDistanceCheck then return o, wpos end
    local ppos = MW.PlayerPos(src)
    if not wpos or not ppos or #(ppos - wpos) > dist then return nil, 'too_far_wagon' end
    return o, wpos
end

local function guard(src)
    if not MW.ready then return 'busy' end
    if not MW.CitizenId(src) then return 'no_player' end
    if rateLimited(src) then return 'slow_down' end
end

-- the player's wagons, for the menus
lib.callback.register('MULTIwagons:mine', function(src)
    local cid = MW.CitizenId(src)
    if not cid or not MW.ready then return {} end
    local out = {}
    for _, w in ipairs(MW.ListOf(cid)) do
        local p = MW.Public(w)
        p.sellPrice = MW.SellPrice(w)
        w.health = p.health
        p.repairFee = MW.RepairFee(w)
        out[#out + 1] = p
    end
    return out
end)

lib.callback.register('MULTIwagons:buy', function(src, point, model, name)
    local g = guard(src) if g then return fail(src, g) end
    if not atPoint(src, point, true) then return fail(src, 'too_far') end
    local ok, err = MW.Buy(src, model, name)
    if not ok then return fail(src, err) end
    local cfg = MW.ByModel[model]
    MW.Notify(src, 'bought', 'money', _L('wagon_' .. model), MW.Money(cfg.price))
    return { ok = true, id = err }
end)

lib.callback.register('MULTIwagons:sell', function(src, point, id)
    local g = guard(src) if g then return fail(src, g) end
    if not atPoint(src, point, true) then return fail(src, 'too_far') end
    local ok, res = MW.Sell(src, id)
    if not ok then return fail(src, res) end
    MW.Notify(src, 'sold', 'money', MW.Money(res))
    return { ok = true }
end)

lib.callback.register('MULTIwagons:rename', function(src, point, id, name)
    local g = guard(src) if g then return fail(src, g) end
    if not atPoint(src, point, false) then return fail(src, 'too_far') end
    local ok, err = MW.Rename(src, id, name)
    if not ok then return fail(src, err) end
    MW.Notify(src, 'renamed', 'success')
    return { ok = true }
end)

-- point = dealer / call point name, or nil to call it to the road nearby (Config.CallAnywhere)
lib.callback.register('MULTIwagons:takeOut', function(src, point, id)
    local g = guard(src) if g then return fail(src, g) end
    local spawn
    if point ~= nil then
        if not atPoint(src, point, false) then return fail(src, 'too_far') end
        spawn = MW.Points[point].def.spawn
    elseif not Config.CallAnywhere then
        return fail(src, 'too_far')
    end
    local ok, data = MW.TakeOut(src, id, spawn)
    if not ok then return fail(src, data) end
    return { ok = true, wagon = data }
end)

RegisterNetEvent('MULTIwagons:server:spawned', function(id, netId)
    local src = source
    local ok, err = MW.Spawned(src, id, netId)
    for _ = 1, 10 do -- the server may learn about a new entity a moment after the client made it
        if ok or err ~= 'no_entity' then break end
        Wait(200)
        ok, err = MW.Spawned(src, id, netId)
    end
    if not ok then
        MW.PutAway(id, nil, 'spawn_failed')
        fail(src, err)
        return
    end
    MW.Notify(src, 'taken_out', 'success')
end)

-- the owner's game could not make the wagon (no model, no room): undo the take-out
RegisterNetEvent('MULTIwagons:server:spawnFailed', function(id)
    local src = source
    local o = MW.Out[tonumber(id)]
    if o and o.src == src and o.pending then MW.PutAway(o.id, nil, 'spawn_failed') end
end)

RegisterNetEvent('MULTIwagons:server:health', function(id, pct)
    MW.ReportHealth(source, id, pct)
end)

lib.callback.register('MULTIwagons:store', function(src, id, health)
    local g = guard(src) if g then return fail(src, g) end
    local o, wpos = atOwnWagon(src, id, Config.StoreDistance)
    if not o then return fail(src, wpos) end
    if not Config.StoreAnywhere and Config.ServerDistanceCheck and not MW.PointAt(wpos, Config.StoreRadius) then
        return fail(src, 'not_at_point')
    end
    local ok, err = MW.Store(src, o.id, health)
    if not ok then return fail(src, err) end
    MW.Notify(src, 'stored', 'success')
    return { ok = true }
end)

lib.callback.register('MULTIwagons:repair', function(src, point, id)
    local g = guard(src) if g then return fail(src, g) end
    if not atPoint(src, point, true) then return fail(src, 'too_far') end
    local ok, fee = MW.Repair(src, id, 'dealer')
    if not ok then return fail(src, fee) end
    MW.Notify(src, 'repaired', 'money', MW.Money(fee))
    return { ok = true }
end)

-- after the repair kit's work is done in the game
lib.callback.register('MULTIwagons:repairKit', function(src)
    local g = guard(src) if g then return fail(src, g) end
    local o, err = atOwnWagon(src, nil, Config.Repair.ItemDistance)
    if not o then return fail(src, err) end
    local ok, res = MW.Repair(src, o.id, 'item')
    if not ok then return fail(src, res) end
    MW.Notify(src, 'repaired_kit', 'success')
    return { ok = true }
end)

-- storage at the wagon's back
RegisterNetEvent('MULTIwagons:server:openStorage', function(netId)
    local src = source
    local g = guard(src) if g then return fail(src, g) end
    local o = MW.OutByNetId(netId)
    if not o or o.pending then return fail(src, 'no_wagon') end
    if Config.StorageOpenTo ~= 'anyone' and o.citizenid ~= MW.CitizenId(src) then return fail(src, 'not_owner') end
    if Config.ServerDistanceCheck then
        local wpos, ppos = MW.WagonEntity(o), MW.PlayerPos(src)
        if not wpos or not ppos or #(ppos - wpos) > Config.StorageServerDistance then return fail(src, 'too_far_wagon') end
    end
    local ok, err = MW.OpenStorage(src, o.id)
    if not ok and err ~= 'in_use' then fail(src, err) end
end)
