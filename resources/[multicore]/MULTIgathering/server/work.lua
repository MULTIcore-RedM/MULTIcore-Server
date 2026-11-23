-- ============================================================
-- MULTIgathering :: mining, lumber and gold panning (server)
-- Every job runs in two steps, the way rsg-lumberjack's secure chop works (RSG v2, GPL v3,
-- see CREDITS.md):
--   Start(src, activity, target)  checks tool, place, charges and cooldown, notes the start
--                                 time and returns how long the work takes;
--   Finish(src)                   checks the time really passed and the player is still
--                                 there, rolls the chance table, gives the items, uses up
--                                 one charge of the spot.
-- The client only plays the animation; it never names an item or an amount.
-- ============================================================

MG.Pending = {}     -- [src] = { activity, target, startedAt, duration }
MG.NextAt = {}      -- [src] = { [activity] = ms when the next job may start }
MG.SpotState = {}   -- [spotId] = { left = charges left, refillAt = ms or nil }

local settings = {
    mining  = function() return Config.Mining end,
    lumber  = function() return Config.Lumber end,
    panning = function() return Config.Panning end,
}

---------------------------------
-- spots (mine faces and lumber zones)
---------------------------------

--- The spot's state, refilled when its time has come. → { left, refillAt }
function MG.Spot(id)
    local s = MG.Spots[id]
    if not s then return nil end
    local st = MG.SpotState[id]
    if not st then
        st = { left = math.tointeger(tonumber(s.def.charges)) or 1 }
        MG.SpotState[id] = st
    end
    if st.refillAt and MG.Now() >= st.refillAt then
        st.left, st.refillAt = math.tointeger(tonumber(s.def.charges)) or 1, nil
        TriggerClientEvent('MULTIgathering:client:spotState', -1, id, false)
    end
    return st
end

local function useCharge(id)
    local s, st = MG.Spots[id], MG.Spot(id)
    if not st then return end
    st.left = st.left - 1
    if st.left <= 0 then
        st.left = 0
        st.refillAt = MG.Now() + (tonumber(s.def.respawnMinutes) or 10) * 60000
        TriggerClientEvent('MULTIgathering:client:spotState', -1, id, true)
    end
end

--- The lumber zone the player stands in (first match), or nil.
local function lumberZoneAt(src)
    local pos = MG.PlayerCoords(src)
    if not pos then return nil end
    for _, z in ipairs(Config.LumberZones or {}) do
        local dx, dy = pos.x - z.coords.x, pos.y - z.coords.y
        if dx * dx + dy * dy <= z.radius * z.radius then return z.id end
    end
    return nil
end

---------------------------------
-- single trees: each tree gives Config.Lumber.ChopsPerTree chops, then it is "felled" until it regrows
---------------------------------
MG.TreeState = {}   -- [key] = { left, refillAt }

--- "x,y,z" from the client -> vector3, key | nil
local function parseTree(target)
    if type(target) ~= 'string' then return nil end
    local x, y, z = target:match('^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$')
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not (x and y and z) then return nil end
    return vector3(x, y, z), ('%d_%d'):format(math.floor(x + 0.5), math.floor(y + 0.5))
end

local function treeLeft(key)
    local st = MG.TreeState[key]
    if not st then return Config.Lumber.ChopsPerTree end
    if st.refillAt and MG.Now() >= st.refillAt then
        MG.TreeState[key] = nil
        return Config.Lumber.ChopsPerTree
    end
    return st.left
end

local function useTree(key)
    local left = treeLeft(key) - 1
    if left <= 0 then
        MG.TreeState[key] = { left = 0, refillAt = MG.Now() + (tonumber(Config.Lumber.TreeRegrowMinutes) or 20) * 60000 }
    else
        MG.TreeState[key] = { left = left }
    end
end

--- tree the player works on → key | nil (no single-tree rule) | false, err
local function checkTree(src, target)
    if (tonumber(Config.Lumber.ChopsPerTree) or 0) <= 0 then return nil end
    local pos, key = parseTree(target)
    if not pos then return nil end
    if not MG.PlayerNear(src, pos, tonumber(Config.Lumber.TreeReach) or 6.0) then return false, 'too_far' end
    if treeLeft(key) <= 0 then return false, 'tree_done' end
    return key
end

local function inPanningZone(src)
    local zones = Config.PanningZones or {}
    if #zones == 0 then return true end
    local pos = MG.PlayerCoords(src)
    if not pos then return Config.AllowWithoutPosition == true end
    for _, z in ipairs(zones) do
        local dx, dy = pos.x - z.coords.x, pos.y - z.coords.y
        if dx * dx + dy * dy <= z.radius * z.radius then return true end
    end
    return false
end

---------------------------------
-- where the job happens; → spot id (or true for panning) | nil, err
---------------------------------
local function checkPlace(src, activity, target)
    if activity == 'mining' then
        local s = type(target) == 'string' and MG.Spots[target]
        if not s or s.kind ~= 'mining' then return nil, 'bad_spot' end
        if not MG.PlayerNear(src, s.def.coords, s.def.radius) then return nil, 'too_far' end
        if MG.Spot(target).left <= 0 then return nil, 'depleted' end
        return target
    elseif activity == 'lumber' then
        if #(Config.LumberZones or {}) == 0 then return 'anywhere' end
        local zone = lumberZoneAt(src)
        if not zone then
            if not MG.PlayerCoords(src) and Config.AllowWithoutPosition then return 'anywhere' end
            return nil, 'no_zone'
        end
        if MG.Spot(zone).left <= 0 then return nil, 'depleted' end
        return zone
    elseif activity == 'panning' then
        if not inPanningZone(src) then return nil, 'no_zone' end
        return 'water'
    end
    return nil, 'bad_activity'
end

local function rewardTable(activity, place)
    if activity == 'panning' then return Config.PanningRewards end
    local s = MG.Spots[place]
    if activity == 'mining' then return s and Config.MiningRewards[s.def.rewards] end
    if s then return Config.LumberRewards[s.def.rewards] end
    return Config.LumberRewards.forest or select(2, next(Config.LumberRewards))
end

--- Starts a job. → true, durationMs | false, err
--- err: no_player, disabled, stand_down, busy, cooldown, need_tool, bad_spot, too_far, depleted, no_zone, bad_activity
function MG.Start(src, activity, target)
    src = tonumber(src)
    local cfg = settings[activity] and settings[activity]()
    if not cfg then return false, 'bad_activity' end
    if not MG.Player(src) then return false, 'no_player' end
    local ok, err = MG.Active(activity)
    if not ok then return false, err end
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end

    local now = MG.Now()
    local p = MG.Pending[src]
    if p and now - p.startedAt < Config.PendingTimeoutMs then return false, 'busy' end
    local nextAt = (MG.NextAt[src] or {})[activity]
    if nextAt and now < nextAt then return false, 'cooldown' end
    if not MG.Has(pid, cfg.Tool) then return false, 'need_tool' end
    local place, perr = checkPlace(src, activity, target)
    if not place then return false, perr end
    local tree
    if activity == 'lumber' then
        local terr
        tree, terr = checkTree(src, target)
        if tree == false then return false, terr end
    end

    MG.Pending[src] = { activity = activity, target = place, tree = tree, treeTarget = tree and target or nil, startedAt = now, duration = cfg.DurationMs }
    MG.Debug(('%s started %s at %s'):format(src, activity, tostring(place)))
    return true, cfg.DurationMs
end

--- Finishes the running job. → true, given | false, err
--- err: no_job, too_soon, expired, plus the Start errors and no_space / too_heavy / limit
function MG.Finish(src)
    src = tonumber(src)
    local p = MG.Pending[src]
    if not p then return false, 'no_job' end
    local now = MG.Now()
    local cfg = settings[p.activity]()
    if now - p.startedAt < p.duration - Config.FinishSlackMs then return false, 'too_soon' end
    MG.Pending[src] = nil
    if now - p.startedAt > Config.PendingTimeoutMs then return false, 'expired' end
    if not MG.Player(src) then return false, 'no_player' end
    local ok, err = MG.Active(p.activity)
    if not ok then return false, err end
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end
    if not MG.Has(pid, cfg.Tool) then return false, 'need_tool' end

    -- the player must still be at the same place
    local place, perr
    if p.activity == 'mining' then place, perr = checkPlace(src, 'mining', p.target)
    else place, perr = checkPlace(src, p.activity, nil) end
    if not place then return false, perr end
    if place ~= p.target then return false, 'too_far' end
    if p.tree then
        local key, terr = checkTree(src, p.treeTarget)
        if key == false then return false, terr end
    end

    local list = MG.Roll(rewardTable(p.activity, place))
    MG.NextAt[src] = MG.NextAt[src] or {}
    MG.NextAt[src][p.activity] = now + (cfg.CooldownMs or 0)

    local given = {}
    if #list > 0 then
        local gok, res = MG.GiveAll(src, pid, list, 'gathering ' .. p.activity)
        if not gok then
            MG.NextAt[src][p.activity] = nil
            return false, res
        end
        given = res
    end
    if MG.Spots[place] then useCharge(place) end
    if p.tree then useTree(p.tree) end
    MG.MaybeBreak(src, pid, cfg.Tool, cfg.ToolBreakChance)

    MG.Debug(('%s finished %s at %s: %s'):format(src, p.activity, tostring(place), MG.Summary(given)))
    TriggerEvent('MULTIgathering:gathered', src, p.activity, place, given)
    return true, given
end

--- Drops the running job (cancelled on the client).
function MG.Cancel(src)
    MG.Pending[tonumber(src)] = nil
    return true
end

MG.DropHooks[#MG.DropHooks + 1] = function(src)
    MG.Pending[src], MG.NextAt[src] = nil, nil
end

---------------------------------
-- client calls
---------------------------------
local silent = { busy = true }

lib.callback.register('MULTIgathering:start', function(src, activity, target)
    if MG.RateLimited(src, 'start') then return false, 'rate' end
    if type(activity) ~= 'string' or (target ~= nil and type(target) ~= 'string') then return false, 'bad_activity' end
    local ok, res = MG.Start(src, activity, target)
    if not ok and not silent[res] then
        MG.Refuse(src, res, settings[activity] and settings[activity]().Tool)
    end
    return ok, res
end)

lib.callback.register('MULTIgathering:finish', function(src)
    if MG.RateLimited(src, 'finish') then return false, 'rate' end
    local p = MG.Pending[src]
    local activity = p and p.activity
    local ok, res = MG.Finish(src)
    if ok then
        if #res > 0 then
            MG.Notify(src, _L('found', MG.Summary(res)), 'success')
        else
            MG.Notify(src, _L('found_nothing_' .. tostring(activity)), 'info')
        end
    else
        MG.Refuse(src, res, activity and settings[activity] and settings[activity]().Tool)
    end
    return ok
end)

RegisterNetEvent('MULTIgathering:cancel', function()
    MG.Cancel(source)
end)

-- worked-out spots for a client that just joined
lib.callback.register('MULTIgathering:spots', function(src)
    local out = {}
    for id in pairs(MG.Spots) do
        local st = MG.Spot(id)
        if st and st.left <= 0 then out[#out + 1] = id end
    end
    return out
end)

---------------------------------
-- gold pan: using it starts panning on the client (which checks the water)
---------------------------------
MG.UsableHooks[#MG.UsableHooks + 1] = function()
    MI:RegisterUsable(Config.Panning.Tool, function(src)
        if not MG.Active('panning') then return end
        TriggerClientEvent('MULTIgathering:client:pan', src)
    end)
end
