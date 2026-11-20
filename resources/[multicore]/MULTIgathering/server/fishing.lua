-- ============================================================
-- MULTIgathering :: fishing (server)
-- The rules follow rsg-fishing's server (RSG v2, GPL v3, see CREDITS.md): only a player who
-- really used up a bait may land a fish, one fish per bait, a short cooldown, the fish model
-- must be a known one and the weight is kept inside the species' range. MULTIgathering also
-- checks the rod is carried and that the bait can catch that fish.
--   Cast(src, bait)            uses one bait; opens a window for one fish
--   Catch(src, model, kg)      gives the fish item (info.weight) for that window
-- ============================================================

MG.Casts = {}       -- [src] = { bait, untilAt }
MG.LastCatch = {}   -- [src] = ms

--- Uses one bait for a cast. → true | false, err
--- err: no_player, disabled, stand_down, bad_bait, need_tool (rod), no_bait
function MG.Cast(src, bait)
    src = tonumber(src)
    if not MG.Player(src) then return false, 'no_player' end
    local ok, err = MG.Active('fishing')
    if not ok then return false, err end
    if type(bait) ~= 'string' or not MG.IsBait[bait] then return false, 'bad_bait' end
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end
    if not MG.Has(pid, Config.Fishing.Rod) then return false, 'need_tool' end
    if not MG.Has(pid, bait) then return false, 'no_bait' end
    if not MI:RemoveItem(pid, bait, 1, nil, nil, 'fishing bait') then return false, 'no_bait' end
    MI:ItemBox(src, bait, 1, 'remove')
    MG.Casts[src] = { bait = bait, untilAt = MG.Now() + Config.Fishing.CastWindowSeconds * 1000 }
    MG.Debug(('%s cast with %s'):format(src, bait))
    return true
end

local function clampWeight(def, kg)
    kg = tonumber(kg)
    if not kg or kg ~= kg then kg = def.min end
    kg = math.max(def.min, math.min(def.max, kg))
    return math.floor(kg * 100 + 0.5) / 100
end

--- Lands a fish for the current cast. → true, given | false, err
--- err: no_player, disabled, stand_down, no_cast, unknown_fish, wrong_bait, cooldown, need_tool,
---      no_space, too_heavy, limit, failed
function MG.Catch(src, model, kg)
    src = tonumber(src)
    if not MG.Player(src) then return false, 'no_player' end
    local ok, err = MG.Active('fishing')
    if not ok then return false, err end
    local now = MG.Now()
    local cast = MG.Casts[src]
    if not cast or now > cast.untilAt then MG.Casts[src] = nil return false, 'no_cast' end
    local def = MG.FishDef(model)
    if not def then return false, 'unknown_fish' end
    if Config.Fishing.CheckBaitFish then
        local set = MG.BaitSet[cast.bait]
        if set and not set[MG.Hash(def.model)] then return false, 'wrong_bait' end
    end
    if MG.LastCatch[src] and now - MG.LastCatch[src] < Config.Fishing.CatchCooldownMs then return false, 'cooldown' end
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end
    if not MG.Has(pid, Config.Fishing.Rod) then return false, 'need_tool' end

    -- the bait is spent on this fish whether or not it fits in the satchel (it is off the hook)
    MG.Casts[src] = nil
    MG.LastCatch[src] = now
    local list = { { name = def.item, amount = 1, info = { weight = clampWeight(def, kg) } } }
    local gok, res = MG.GiveAll(src, pid, list, 'fishing ' .. def.model)
    if not gok then return false, res end
    MG.Debug(('%s caught %s (%.2f kg)'):format(src, def.model, list[1].info.weight))
    TriggerEvent('MULTIgathering:gathered', src, 'fishing', def.model, res)
    return true, res
end

--- Is a cast open for this player?
function MG.HasCast(src)
    local c = MG.Casts[tonumber(src)]
    return c ~= nil and MG.Now() <= c.untilAt
end

MG.DropHooks[#MG.DropHooks + 1] = function(src)
    MG.Casts[src], MG.LastCatch[src] = nil, nil
end

-- bait items: using one asks the client to put it on the rod (the client checks the rod is in hand)
MG.UsableHooks[#MG.UsableHooks + 1] = function()
    for _, bait in ipairs(Config.Fishing.Baits or {}) do
        MI:RegisterUsable(bait, function(src, item)
            if not MG.Active('fishing') then return end
            TriggerClientEvent('MULTIgathering:client:bait', src, bait)
        end)
    end
end

lib.callback.register('MULTIgathering:fish:cast', function(src, bait)
    if MG.RateLimited(src, 'cast') then return false, 'rate' end
    local ok, err = MG.Cast(src, bait)
    if not ok then MG.Refuse(src, err, err == 'no_bait' and bait or Config.Fishing.Rod) end
    return ok, err
end)

lib.callback.register('MULTIgathering:fish:keep', function(src, model, kg)
    if MG.RateLimited(src, 'keep') then return false, 'rate' end
    if type(model) ~= 'number' then return false, 'unknown_fish' end
    local ok, res = MG.Catch(src, model, kg)
    if ok then
        local it = res[1]
        MG.Notify(src, _L('caught', MG.Label(it.name), it.info.weight), 'success')
    else
        MG.Refuse(src, res, Config.Fishing.Rod)
    end
    return ok
end)
