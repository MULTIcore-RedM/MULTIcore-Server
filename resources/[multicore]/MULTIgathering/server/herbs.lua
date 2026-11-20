-- ============================================================
-- MULTIgathering :: herb picking (server)
-- The game's own herb plants are put into the world at the spots of config/herb_spots.lua.
-- The rules follow rsg-herbalist's server (RSG v2, GPL v3, see CREDITS.md): the client only
-- names the spot it picked; the server knows which plant grows there, checks the player is
-- next to it and the plant is not already picked, gives the herb and lets it regrow later.
-- ============================================================

MG.Picked = {}      -- [key] = ms when the plant grows back
MG.LastPick = {}    -- [src] = ms

--- Picks the plant at a spot key. → true, given | false, err
--- err: no_player, disabled, stand_down, bad_spot, picked, too_far, cooldown, no_item, no_space, too_heavy, limit, failed
function MG.Pick(src, key)
    src = tonumber(src)
    if not MG.Player(src) then return false, 'no_player' end
    local ok, err = MG.Active('herbs')
    if not ok then return false, err end
    local spot = type(key) == 'string' and MG.HerbSpots[key]
    if not spot then return false, 'bad_spot' end
    local now = MG.Now()
    if MG.Picked[key] and now < MG.Picked[key] then return false, 'picked' end
    if MG.LastPick[src] and now - MG.LastPick[src] < Config.Herbs.CooldownMs then return false, 'cooldown' end
    local pos = MG.PlayerCoords(src)
    if pos then
        if #(pos - spot.coord) > Config.Herbs.MaxDistance then return false, 'too_far' end
    elseif not Config.AllowWithoutPosition then
        return false, 'too_far'
    end
    local item = Config.HerbItems[spot.plant]
    if not item then return false, 'no_item' end
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end

    local lo = math.tointeger(tonumber(Config.Herbs.Amount.min)) or 1
    local hi = math.max(lo, math.tointeger(tonumber(Config.Herbs.Amount.max)) or lo)
    local amount = lo == hi and lo or MG.random(lo, hi)
    MG.LastPick[src] = now
    local gok, res = MG.GiveAll(src, pid, { { name = item, amount = amount } }, 'herbs')
    if not gok then
        MG.LastPick[src] = nil
        return false, res
    end
    MG.Picked[key] = now + Config.Herbs.RegrowMinutes * 60000
    TriggerClientEvent('MULTIgathering:client:herbPicked', -1, key, true)
    MG.Debug(('%s picked %s at %s'):format(src, item, key))
    TriggerEvent('MULTIgathering:gathered', src, 'herbs', key, res)
    return true, res
end

--- Is the plant at this key picked right now?
function MG.IsPicked(key)
    local t = MG.Picked[key]
    return t ~= nil and MG.Now() < t
end

-- plants grow back
CreateThread(function()
    while true do
        Wait(30000)
        local now = MG.Now()
        for key, t in pairs(MG.Picked) do
            if now >= t then
                MG.Picked[key] = nil
                TriggerClientEvent('MULTIgathering:client:herbPicked', -1, key, false)
            end
        end
    end
end)

MG.DropHooks[#MG.DropHooks + 1] = function(src) MG.LastPick[src] = nil end

lib.callback.register('MULTIgathering:herb:pick', function(src, key)
    if MG.RateLimited(src, 'pick') then return false, 'rate' end
    local ok, res = MG.Pick(src, key)
    if ok then
        MG.Notify(src, _L('picked', MG.Summary(res)), 'success')
    elseif res == 'picked' then
        MG.Notify(src, _L('already_picked'), 'error')
    else
        MG.Refuse(src, res)
    end
    return ok, res
end)

-- picked plants for a client that just joined
lib.callback.register('MULTIgathering:herb:picked', function(src)
    local out, now = {}, MG.Now()
    for key, t in pairs(MG.Picked) do if now < t then out[#out + 1] = key end end
    return out
end)
