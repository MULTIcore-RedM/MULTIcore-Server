-- ============================================================
-- MULTIcamps :: what a game client may ask (server)
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

local function fail(src, err, arg)
    Camps.Notify(src, 'err_' .. tostring(err or 'error'), 'error', arg)
    return { ok = false, err = err }
end

local function guard(src)
    if not Camps.ready then return 'busy' end
    if not Camps.CitizenId(src) then return 'no_player' end
    if rateLimited(src) then return 'slow_down' end
end

--- Is src close to that part of the camp? → camp | nil, err
local function atCamp(src, id, part)
    local camp = Camps.Get(id)
    if not camp then return nil, 'no_camp' end
    if not Config.ServerDistanceCheck then return camp end
    local pos = Camps.PlayerPos(src)
    if not pos then return nil, 'too_far' end
    local p = part and Camps.PartCoords(camp, part) or vector3(camp.x, camp.y, camp.z)
    -- props are snapped to the ground on the client, so height is not compared tightly
    local d2 = #(vector2(pos.x, pos.y) - vector2(p.x, p.y))
    if d2 > Config.ServerUseDistance or math.abs(pos.z - p.z) > Config.ServerUseDistance then return nil, 'too_far' end
    return camp
end

-- every camp, for drawing (no owner data)
lib.callback.register('MULTIcamps:list', function(src)
    local out = {}
    if not Camps.ready then return out end
    for _, c in pairs(Camps.List) do out[#out + 1] = Camps.Public(c) end
    return out
end)

-- what the camp menu offers this player
lib.callback.register('MULTIcamps:info', function(src, id)
    local err = guard(src)
    if err then return { ok = false, err = err } end
    local camp = Camps.Get(id)
    if not camp then return { ok = false, err = 'no_camp' } end
    local owner = Camps.IsOwner(src, camp)
    local canUse = Camps.CanUseStorage(src, camp) and true or false
    return {
        ok = true,
        owner = owner,
        canUse = canUse,
        ownerName = camp.ownerName,
        lit = camp.lit,
        shared = camp.shared,
        sharing = Config.GangSharing,
        sleep = Config.Sleep.Enabled,
        cook = Config.Fire.CookFromMenu and GetResourceState('MULTIcrafting') == 'started',
    }
end)

lib.callback.register('MULTIcamps:place', function(src, coords, heading)
    local err = guard(src)
    if err then return fail(src, err) end
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return fail(src, 'bad_coords') end
    local ok, perr, arg = Camps.Place(src, coords, heading, not Config.ServerDistanceCheck)
    if not ok then return fail(src, perr, arg) end
    Camps.Notify(src, 'camp_pitched', 'success')
    return { ok = true, id = perr }
end)

lib.callback.register('MULTIcamps:pack', function(src, id)
    local err = guard(src)
    if err then return fail(src, err) end
    local camp, aerr = atCamp(src, id, 'tent')
    if not camp then return fail(src, aerr) end
    local ok, perr = Camps.Pack(src, camp.id)
    if not ok then return fail(src, perr) end
    Camps.Notify(src, perr > 0 and 'camp_packed_items' or 'camp_packed', 'success')
    return { ok = true }
end)

lib.callback.register('MULTIcamps:fire', function(src, id, lit)
    local err = guard(src)
    if err then return fail(src, err) end
    local camp, aerr = atCamp(src, id, 'fire')
    if not camp then return fail(src, aerr) end
    local ok, ferr = Camps.SetFire(src, camp.id, lit)
    if not ok then return fail(src, ferr) end
    return { ok = true }
end)

lib.callback.register('MULTIcamps:share', function(src, id, on)
    local err = guard(src)
    if err then return fail(src, err) end
    local camp, aerr = atCamp(src, id, nil)
    if not camp then return fail(src, aerr) end
    local ok, serr = Camps.SetShared(src, camp.id, on)
    if not ok then return fail(src, serr) end
    Camps.Notify(src, serr and 'camp_shared_on' or 'camp_shared_off', 'success')
    return { ok = true, shared = serr }
end)

lib.callback.register('MULTIcamps:storage', function(src, id)
    local err = guard(src)
    if err then return fail(src, err) end
    local camp, aerr = atCamp(src, id, 'chest')
    if not camp then return fail(src, aerr) end
    local ok, oerr = Camps.OpenStorage(src, camp.id)
    if not ok then return fail(src, oerr) end
    return { ok = true }
end)

lib.callback.register('MULTIcamps:rest', function(src, id)
    local err = guard(src)
    if err then return fail(src, err) end
    local camp, aerr = atCamp(src, id, 'bedroll')
    if not camp then return fail(src, aerr) end
    local ok, bonus = Camps.Rest(src, camp.id)
    if not ok then return fail(src, bonus) end
    if not bonus then Camps.Notify(src, 'rest_cooldown', 'info') end
    return { ok = true, bonus = bonus }
end)

lib.callback.register('MULTIcamps:cook', function(src, id)
    local err = guard(src)
    if err then return fail(src, err) end
    if GetResourceState('MULTIcrafting') ~= 'started' then return fail(src, 'no_crafting') end
    local camp, aerr = atCamp(src, id, 'fire')
    if not camp then return fail(src, aerr) end
    if not camp.lit then return fail(src, 'fire_out') end
    local c = Camps.PartCoords(camp, 'fire')
    -- MULTIcrafting checks again that the player stands at a campfire (a world prop at these coords)
    local ok = exports.MULTIcrafting:OpenMenu(src, { type = 'campfire', coords = { x = c.x, y = c.y, z = c.z } })
    return { ok = ok and true or false }
end)
