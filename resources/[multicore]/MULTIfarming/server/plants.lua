-- ============================================================
-- MULTIfarming :: crops (server)
-- Every crop lives here and in the table multi_farming_plants. Growth is worked out from
-- timestamps when it is needed (no loop per crop per second):
--   progress  watered minutes grown so far (the stage follows from it, FM.StageOf)
--   water     water % left; a growing crop uses crop.waterUse % per minute of growth
--   updated   unix time progress and water were last brought up to date
--   dry_at    when the water ran out (not ripe yet); ripe_at when it became ripe
--   dead_at   when it withered (dry or ripe for too long)
-- A sweep every Config.Growth.SweepSeconds brings every crop up to date, tells the clients
-- about stage changes and takes withered crops away.
-- Work (plant, water, harvest, dig up, fill the can) runs in two steps: begin checks and
-- notes the start, finish checks the time really passed and everything again, then acts.
-- The client never names an item or an amount.
-- ============================================================

FM.Plants = {}      -- [id] = plant
FM.Pending = {}     -- [src] = { action, target, startedAt, duration }

local KVP_ALIVE = 'multifarming_alive'

---------------------------------
-- growth
---------------------------------

--- Brings a crop up to `now` (unix seconds): growth, water, ripening and withering.
function FM.Advance(p, now)
    now = now or FM.Time()
    if p.deadAt then p.updated = now return p end
    local c = Config.Crops[p.crop]
    if not c then
        p.deadAt = now   -- the crop was removed from the config: it withers
        p.updated = now
        return p
    end
    local total = FM.GrowMinutes[p.crop] or 0
    local dt = math.max(0, now - p.updated) / 60
    if p.progress < total then
        local rate = tonumber(c.waterUse) or 0
        local canGrow = rate > 0 and (p.water / rate) or math.huge
        local g = math.max(0, math.min(dt, canGrow, total - p.progress))
        p.progress = p.progress + g
        p.water = math.max(0, p.water - g * rate)
        local at = p.updated + math.floor(g * 60)
        if p.progress >= total - 1e-6 then
            p.progress, p.ripeAt, p.dryAt = total, p.ripeAt or at, nil
        elseif p.water <= 1e-6 then
            p.water = 0
            p.dryAt = p.dryAt or at
        end
    elseif not p.ripeAt then
        p.ripeAt = p.updated
    end
    p.updated = now
    local G = Config.Growth
    if p.ripeAt then
        local deadline = p.ripeAt + G.RipeWitherMinutes * 60
        if now >= deadline then p.deadAt = deadline end
    elseif p.dryAt then
        local deadline = p.dryAt + G.DryWitherMinutes * 60
        if now >= deadline then p.deadAt = deadline end
    end
    return p
end

function FM.Stage(p)
    return FM.StageOf(p.crop, p.progress)
end

function FM.IsRipe(p)
    local c = Config.Crops[p.crop]
    return c ~= nil and not p.deadAt and FM.Stage(p) >= #c.stages
end

--- What clients get about a crop.
function FM.View(p)
    return { id = p.id, crop = p.crop, x = p.x, y = p.y, z = p.z, h = p.h, stage = FM.Stage(p), dead = p.deadAt ~= nil, owner = p.citizenid }
end

--- The crop's label (its harvest item's label).
function FM.CropLabel(cropId)
    local c = Config.Crops[cropId]
    return c and FM.Label(c.item) or tostring(cropId)
end

---------------------------------
-- database
---------------------------------
local SAVE_SQL = 'UPDATE `multi_farming_plants` SET `progress` = ?, `water` = ?, `updated` = ?, `dry_at` = ?, `ripe_at` = ?, `dead_at` = ? WHERE `id` = ?'

local function saveArgs(p)
    return { p.progress, p.water, p.updated, p.dryAt, p.ripeAt, p.deadAt, p.id }
end

function FM.Save(p)
    MySQL.update(SAVE_SQL, saveArgs(p))
end

local function fromRow(r)
    return {
        id = math.tointeger(r.id) or r.id, citizenid = r.citizenid, crop = r.crop,
        x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, h = (r.heading or 0) + 0.0,
        progress = (r.progress or 0) + 0.0, water = (r.water or 0) + 0.0, updated = math.tointeger(r.updated) or 0,
        dryAt = math.tointeger(r.dry_at), ripeAt = math.tointeger(r.ripe_at), deadAt = math.tointeger(r.dead_at),
        planted = math.tointeger(r.planted) or 0,
    }
end

FM.LoadHooks[#FM.LoadHooks + 1] = function(rows)
    local now = FM.Time()
    local alive = GetResourceKvpInt(KVP_ALIVE) or 0
    local gap = (not Config.Growth.CountOfflineTime and alive > 0 and now > alive) and (now - alive) or 0
    local queries = {}
    for _, r in ipairs(rows) do
        local p = fromRow(r)
        if gap > 0 then
            -- the server was off: move the crop's clock forward so that time does not count
            p.updated = p.updated + gap
            if p.dryAt then p.dryAt = p.dryAt + gap end
            if p.ripeAt then p.ripeAt = p.ripeAt + gap end
            if p.deadAt then p.deadAt = p.deadAt + gap end
            queries[#queries + 1] = { query = SAVE_SQL, values = saveArgs(p) }
        end
        FM.Plants[p.id] = p
    end
    if #queries > 0 then MySQL.transaction(queries) end
    SetResourceKvpInt(KVP_ALIVE, now)
end

---------------------------------
-- sync to clients
---------------------------------
local CHUNK = 100

--- Sends every crop to one player, CHUNK at a time.
function FM.SendAll(src)
    local list = {}
    for _, p in pairs(FM.Plants) do list[#list + 1] = FM.View(p) end
    if #list == 0 then
        TriggerClientEvent('MULTIfarming:client:plants', src, {}, true, true)
        return
    end
    for i = 1, #list, CHUNK do
        local chunk = {}
        for j = i, math.min(i + CHUNK - 1, #list) do chunk[#chunk + 1] = list[j] end
        TriggerClientEvent('MULTIfarming:client:plants', src, chunk, i == 1, i + CHUNK > #list)
    end
end

function FM.Broadcast(p)
    TriggerClientEvent('MULTIfarming:client:plant', -1, FM.View(p))
end

--- Takes a crop out of the world and the database.
function FM.Delete(p)
    if not FM.Plants[p.id] then return end
    FM.Plants[p.id] = nil
    MySQL.query('DELETE FROM `multi_farming_plants` WHERE `id` = ?', { p.id })
    TriggerClientEvent('MULTIfarming:client:remove', -1, { p.id })
end

RegisterNetEvent('MULTIfarming:server:sync', function()
    local src = source
    if FM.RateLimited(src, 'sync') or not FM.ready then return end
    FM.SendAll(src)
end)

---------------------------------
-- the sweep: stage changes, withering, taking away withered crops
---------------------------------
CreateThread(function()
    while not FM.ready do Wait(500) end
    while true do
        local now = FM.Time()
        local removeAfter = Config.Growth.DeadRemoveMinutes * 60
        local gone = {}
        for id, p in pairs(FM.Plants) do
            local stage, dead = FM.Stage(p), p.deadAt ~= nil
            FM.Advance(p, now)
            if p.deadAt and now - p.deadAt >= removeAfter then
                FM.Plants[id] = nil
                gone[#gone + 1] = id
            elseif FM.Stage(p) ~= stage or (p.deadAt ~= nil) ~= dead then
                if p.deadAt and not dead then FM.Save(p) end
                FM.Broadcast(p)
            end
        end
        if #gone > 0 then
            MySQL.query(('DELETE FROM `multi_farming_plants` WHERE `id` IN (%s)'):format(('?,'):rep(#gone):sub(1, -2)), gone)
            TriggerClientEvent('MULTIfarming:client:remove', -1, gone)
            FM.Debug(('%d withered crops taken away'):format(#gone))
        end
        SetResourceKvpInt(KVP_ALIVE, now)
        Wait(math.max(5, Config.Growth.SweepSeconds) * 1000)
    end
end)

---------------------------------
-- lookups
---------------------------------

--- How many crops a character has in the ground (withered ones included).
function FM.CountOf(citizenid)
    local n = 0
    for _, p in pairs(FM.Plants) do if p.citizenid == citizenid then n = n + 1 end end
    return n
end

--- Is there a crop within Config.Planting.MinSpacing of `pos`?
function FM.TooClose(pos)
    local s2 = Config.Planting.MinSpacing * Config.Planting.MinSpacing
    for _, p in pairs(FM.Plants) do
        if FM.Dist2(pos, p) < s2 and math.abs(pos.z - p.z) < 3.0 then return true end
    end
    return false
end

--- The watering can stacks in a player's satchel: → list of { slot, water }
local function cans(pid)
    local out = {}
    for _, s in ipairs(MI:FindItems(pid, Config.Watering.Can) or {}) do
        local info = type(s.info) == 'table' and s.info or {}
        out[#out + 1] = { slot = s.slot, water = math.tointeger(tonumber(info.water) or 0) or 0 }
    end
    return out
end

local function validPos(t)
    if type(t) ~= 'table' then return nil end
    local x, y, z, h = tonumber(t.x), tonumber(t.y), tonumber(t.z), tonumber(t.h) or 0.0
    if not (x and y and z) then return nil end
    for _, v in ipairs({ x, y, z, h }) do
        if v ~= v or v == math.huge or v == -math.huge or math.abs(v) > 20000 then return nil end
    end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, h = (h % 360) + 0.0 }
end

---------------------------------
-- checks per action; → target | nil, err
---------------------------------
local actions = {}

local function plantFor(src, id, needOwner)
    local p = FM.Plants[math.tointeger(tonumber(id)) or -1]
    if not p then return nil, 'gone' end
    FM.Advance(p)
    if not FM.PlayerNear(src, p, Config.InteractDistance) then return nil, 'too_far' end
    if needOwner and p.citizenid ~= FM.CitizenId(src) then return nil, 'not_owner' end
    return p
end

actions.plant = {
    duration = function() return Config.Planting.DurationMs end,
    check = function(src, pid, crop, data)
        local c = type(crop) == 'string' and Config.Crops[crop]
        if not c then return nil, 'bad_crop' end
        if FM.Count(pid, c.seed) < 1 then return nil, 'no_seed' end
        if FM.Count(pid, Config.Planting.Tool) < 1 then return nil, 'need_tool', Config.Planting.Tool end
        if FM.CountOf(FM.CitizenId(src)) >= Config.Planting.MaxPlantsPerPlayer then return nil, 'limit' end
        if data then
            local pos = validPos(data)
            if not pos then return nil, 'bad_pos' end
            if not FM.PlayerNear(src, pos, Config.InteractDistance) then return nil, 'too_far' end
            if not FM.InFarmZone(pos) then return nil, 'no_zone' end
            if FM.TooClose(pos) then return nil, 'too_close' end
            return crop, pos
        end
        local here = FM.PlayerCoords(src)
        if here and not FM.InFarmZone(here) then return nil, 'no_zone' end
        return crop
    end,
    run = function(src, pid, crop, pos)
        local c = Config.Crops[crop]
        local cid = FM.CitizenId(src)
        if not MI:RemoveItem(pid, c.seed, 1, nil, nil, 'farming plant') then return false, 'no_seed' end
        MI:ItemBox(src, c.seed, 1, 'remove')
        local now = FM.Time()
        local water = math.max(0, math.min(100, tonumber(Config.Planting.StartWater) or 0)) + 0.0
        local id = MySQL.insert.await(
            'INSERT INTO `multi_farming_plants` (`citizenid`, `crop`, `x`, `y`, `z`, `heading`, `progress`, `water`, `updated`, `planted`) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?)',
            { cid, crop, pos.x, pos.y, pos.z, pos.h, water, now, now })
        if not id then
            MI:AddItem(pid, c.seed, 1, nil, nil, 'farming plant rollback')
            return false, 'failed'
        end
        local p = { id = id, citizenid = cid, crop = crop, x = pos.x, y = pos.y, z = pos.z, h = pos.h,
                    progress = 0.0, water = water, updated = now, planted = now }
        FM.Advance(p, now)   -- a crop planted dry starts its dry clock now
        if p.dryAt then FM.Save(p) end
        FM.Plants[id] = p
        FM.Broadcast(p)
        FM.Notify(src, _L('planted', FM.CropLabel(crop)), 'success')
        FM.Debug(('%s planted %s #%s'):format(src, crop, id))
        return true
    end,
}

actions.water = {
    duration = function() return Config.Watering.DurationMs end,
    check = function(src, pid, id)
        local p, err = plantFor(src, id, false)
        if not p then return nil, err end
        if p.deadAt then return nil, 'dead' end
        if FM.IsRipe(p) or p.water >= 99.5 then return nil, 'wet_enough' end
        local list = cans(pid)
        if #list == 0 then return nil, 'need_tool', Config.Watering.Can end
        for _, cn in ipairs(list) do if cn.water > 0 then return p end end
        return nil, 'can_empty'
    end,
    run = function(src, pid, p)
        local slot
        for _, cn in ipairs(cans(pid)) do if cn.water > 0 then slot = cn break end end
        if not slot then return false, 'can_empty' end
        if not MI:SetInfo(pid, slot.slot, { water = slot.water - 1 }) then return false, 'failed' end
        FM.Advance(p)
        p.water = math.min(100.0, p.water + (tonumber(Config.Watering.Amount) or 0))
        p.dryAt = nil
        FM.Save(p)
        FM.Broadcast(p)
        FM.Notify(src, _L('watered', math.floor(p.water + 0.5)), 'success')
        return true
    end,
}

actions.harvest = {
    duration = function() return Config.Harvest.DurationMs end,
    check = function(src, pid, id)
        local p, err = plantFor(src, id, Config.Harvest.OwnerOnly)
        if not p then return nil, err end
        if p.deadAt then return nil, 'dead' end
        if not FM.IsRipe(p) then return nil, 'not_ripe' end
        return p
    end,
    run = function(src, pid, p)
        local c = Config.Crops[p.crop]
        local function roll(lo, hi)
            lo = math.tointeger(tonumber(lo)) or 1
            hi = math.max(lo, math.tointeger(tonumber(hi)) or lo)
            return lo == hi and lo or FM.random(lo, hi)
        end
        local list = { { name = c.item, amount = roll(c.min, c.max) } }
        local sb = c.seedBack
        if sb and FM.random() * 100 < (tonumber(sb.chance) or 0) then
            list[#list + 1] = { name = c.seed, amount = roll(sb.min, sb.max) }
        end
        local ok, res = FM.GiveAll(src, pid, list, 'farming harvest')
        if not ok then return false, res end
        FM.Delete(p)
        FM.Notify(src, _L('harvested', FM.Summary(res)), 'success')
        FM.Debug(('%s harvested %s #%s: %s'):format(src, p.crop, p.id, FM.Summary(res)))
        TriggerEvent('MULTIfarming:harvested', src, p.crop, res)
        return true
    end,
}

actions.remove = {
    duration = function() return Config.Harvest.RemoveDurationMs end,
    check = function(src, pid, id)
        return plantFor(src, id, true)
    end,
    run = function(src, pid, p)
        FM.Delete(p)
        FM.Notify(src, _L('removed'), 'success')
        return true
    end,
}

-- filling the can: the server cannot see water, it trusts the client's water check
actions.fill = {
    duration = function() return Config.Watering.FillDurationMs end,
    check = function(src, pid)
        local list = cans(pid)
        if #list == 0 then return nil, 'need_tool', Config.Watering.Can end
        for _, cn in ipairs(list) do if cn.water < Config.Watering.CanUses then return 'can' end end
        return nil, 'can_full'
    end,
    run = function(src, pid)
        local slot
        for _, cn in ipairs(cans(pid)) do if cn.water < Config.Watering.CanUses then slot = cn break end end
        if not slot then return false, 'can_full' end
        if not MI:SetInfo(pid, slot.slot, { water = Config.Watering.CanUses }) then return false, 'failed' end
        FM.Notify(src, _L('filled', Config.Watering.CanUses), 'success')
        return true
    end,
}

---------------------------------
-- begin / finish
---------------------------------

--- Starts a job. → true, durationMs | false, err, arg
function FM.Begin(src, action, target)
    src = tonumber(src)
    local a = actions[action]
    if not a then return false, 'bad_action' end
    if not FM.ready or not FM.CitizenId(src) then return false, 'no_player' end
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end
    local now = FM.Now()
    local pend = FM.Pending[src]
    if pend and now - pend.startedAt < Config.PendingTimeoutMs then return false, 'busy' end
    local t, err, arg = a.check(src, pid, target)
    if not t then return false, err, arg end
    local dur = a.duration()
    FM.Pending[src] = { action = action, target = target, startedAt = now, duration = dur }
    return true, dur
end

--- Finishes the running job. data = { x, y, z, h } for planting. → true | false, err, arg
function FM.Finish(src, data)
    src = tonumber(src)
    local pend = FM.Pending[src]
    if not pend then return false, 'no_job' end
    local now = FM.Now()
    if now - pend.startedAt < pend.duration - Config.FinishSlackMs then return false, 'too_soon' end
    FM.Pending[src] = nil
    if now - pend.startedAt > Config.PendingTimeoutMs then return false, 'expired' end
    if not FM.CitizenId(src) then return false, 'no_player' end
    local pid = MI:PlayerInv(src)
    if not pid then return false, 'no_player' end
    local a = actions[pend.action]
    local t, extra, arg
    if pend.action == 'plant' then
        t, extra, arg = a.check(src, pid, pend.target, data or false)
        if t and not extra then return false, 'bad_pos' end
    else
        t, extra, arg = a.check(src, pid, pend.target)
    end
    if not t then return false, extra, arg end
    return a.run(src, pid, t, extra)
end

function FM.Cancel(src)
    FM.Pending[tonumber(src)] = nil
end

FM.DropHooks[#FM.DropHooks + 1] = function(src) FM.Pending[src] = nil end

---------------------------------
-- client calls
---------------------------------
local silent = { busy = true }

lib.callback.register('MULTIfarming:begin', function(src, action, target)
    if FM.RateLimited(src, 'begin') then return false, 'rate' end
    if type(action) ~= 'string' or (target ~= nil and type(target) ~= 'string' and type(target) ~= 'number') then return false, 'bad_action' end
    local ok, res, arg = FM.Begin(src, action, target)
    if not ok and not silent[res] then FM.Refuse(src, res, arg) end
    return ok, res
end)

lib.callback.register('MULTIfarming:finish', function(src, data)
    if FM.RateLimited(src, 'finish') then return false, 'rate' end
    local ok, res, arg = FM.Finish(src, type(data) == 'table' and data or nil)
    if not ok then FM.Refuse(src, res, arg) end
    return ok == true
end)

RegisterNetEvent('MULTIfarming:cancel', function() FM.Cancel(source) end)

-- the crop's state as a note: "Corn: growing, water 40%"
lib.callback.register('MULTIfarming:status', function(src, id)
    if FM.RateLimited(src, 'status') then return false end
    local p = FM.Plants[math.tointeger(tonumber(id)) or -1]
    if not p then FM.Refuse(src, 'gone') return false end
    if not FM.PlayerNear(src, p, Config.InteractDistance + 2.0) then FM.Refuse(src, 'too_far') return false end
    FM.Advance(p)
    local stage = p.deadAt and _L('stage_dead') or _L('stage_' .. FM.Stage(p))
    FM.Notify(src, _L('status', FM.CropLabel(p.crop), stage, math.floor(p.water + 0.5)), 'info')
    return true
end)

---------------------------------
-- usable items: seeds start planting, the can waters or fills (the client finds out which)
---------------------------------
FM.UsableHooks[#FM.UsableHooks + 1] = function()
    for seed, crop in pairs(FM.CropBySeed) do
        MI:RegisterUsable(seed, function(src)
            TriggerClientEvent('MULTIfarming:client:plant', src, crop)
        end)
    end
    MI:RegisterUsable(Config.Watering.Can, function(src)
        TriggerClientEvent('MULTIfarming:client:useCan', src)
    end)
end
