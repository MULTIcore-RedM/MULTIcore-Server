-- ============================================================
-- MULTIinventory :: server/workshop/sharpen.lua
--
-- Grinding wheel (Config.Sharpening, config_workshop.lua): a worn tool back to full
-- durability. Server authority, same pattern as hand crafting:
--   sharpenList   {}            -> { tools = { { id, slot, item, label, durability } }, cost }
--   sharpenBegin  { id }        -> { token, duration, anim, label }      (locks the player)
--   sharpenFinish { token }     -> { durability }                        (takes the oil, writes metadata)
--   sharpenCancel { token }     -> true
-- The stack is named by its id; the finish re-checks everything (still carried, still below
-- full, still at the wheel, cost still there). One finish per begin.
-- Metadata written: durability = max, the owning script's broken label removed, description
-- refreshed (Config.Sharpening.tools[item]) - e.g. RINGOminingcorp reads metadata.durability.
-- Server event: MULTIinventory:toolSharpened (src, item, stackId, oldDurability, newDurability)
-- ============================================================

Sharpen = Sharpen or {}

local SH = Config.Sharpening or { enabled = false, tools = {} }
local HC = Config.HandCraft or {}
local L = WorkshopLogic

local busy = {}        -- [src] = { token, stackId, started, duration, coords }
local lastStart = {}
local tokenSeq = 0

local function nowMs() return GetGameTimer() end
local function maxDur() return L.num(SH.maxDurability) or 100 end

local function stackById(c, id)
    id = math.tointeger(tonumber(id))
    if not id then return nil end
    for _, e in pairs(c.stacks) do if e.id == id and e.kind ~= 'weapon' then return e end end
    return nil
end

local function toolView(e)
    local def = Inv.def(e.item)
    local dur = L.durability(e.metadata, def, maxDur())
    return { id = e.id, slot = e.slot, item = e.item, label = (e.metadata and e.metadata.label) or def.label or e.item,
             durability = math.floor(dur + 0.5), image = def.image or (e.item .. '.png') }
end

function Sharpen.tools(c)
    local out = {}
    for _, e in pairs(c.stacks) do
        if e.kind ~= 'weapon' and (SH.tools or {})[e.item] then
            local v = toolView(e)
            if L.durability(e.metadata, Inv.def(e.item), maxDur()) < maxDur() then out[#out + 1] = v end
        end
    end
    table.sort(out, function(a, b)
        if a.durability ~= b.durability then return a.durability < b.durability end
        return (a.slot or 0) < (b.slot or 0)
    end)
    return out
end

local function costInfo(c)
    local cost = SH.cost
    if not cost or not cost.items or #cost.items == 0 then return nil end
    local have = 0
    for _, it in ipairs(cost.items) do have = have + Inv.count(c, it) end
    local d = Registry.get(cost.items[1])
    return { label = cost.label or (d and d.label) or cost.items[1], count = math.max(1, math.tointeger(tonumber(cost.count)) or 1), have = have }
end

local function atWheel(src)
    return Stations and Stations.at and Stations.at(src, SH.station or 'grinding_wheel')
end

local function lockOf(src)
    local b = busy[src]
    if b and nowMs() > b.started + b.duration + (L.num(HC.lockTimeoutMs) or 15000) then busy[src] = nil; b = nil end
    return b
end

function Sharpen.isBusy(src) return lockOf(src) ~= nil end
HandCraft.otherBusy = function(src) return Sharpen.isBusy(src) end

function Sharpen.list(src)
    if not SH.enabled then return false, 'disabled' end
    if not atWheel(src) then return false, 'station_far' end
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    return true, { tools = Sharpen.tools(c), cost = costInfo(c), max = maxDur() }
end

function Sharpen.begin(src, d)
    if not SH.enabled then return false, 'disabled' end
    if lockOf(src) or HandCraft.isBusy(src) then return false, 'busy' end
    local t = nowMs()
    local gap = L.num(HC.minIntervalMs) or 1500
    if lastStart[src] and t - lastStart[src] < gap then return false, 'rate_limited' end
    if not atWheel(src) then return false, 'station_far' end
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    local e = stackById(c, d.id)
    if not e then return false, 'no_item' end
    if not (SH.tools or {})[e.item] then return false, 'not_a_tool' end
    if L.durability(e.metadata, Inv.def(e.item), maxDur()) >= maxDur() then return false, 'already_sharp' end
    local cost = costInfo(c)
    if cost and cost.have < cost.count then return false, 'no_oil' end
    lastStart[src] = t
    tokenSeq = tokenSeq + 1
    local token = tokenSeq * 1000 + math.random(0, 999)
    local duration = math.floor(math.max(1000, math.min(L.num(SH.time) or 9000, 60000)))
    busy[src] = { token = token, stackId = e.id, started = t, duration = duration, coords = Stations.pedPos(src) }
    local v = toolView(e)
    return true, { token = token, duration = duration, anim = SH.anim, label = 'Sharpening ' .. v.label, qty = 1,
                   cancelDistance = L.num(HC.cancelDistance) or 0.8, animLoadTimeoutMs = HC.animLoadTimeoutMs or 1500 }
end

function Sharpen.cancel(src, d)
    local b = busy[src]
    if not b then return true end
    if math.tointeger(L.num(d and d.token) or -1) ~= b.token then return false, 'bad_token' end
    busy[src] = nil
    return true
end

-- take the cost (first carried item first); returns records for rollback | nil, err
local function takeCost(c, ctx)
    local cost = SH.cost
    if not cost or not cost.items or #cost.items == 0 then return {} end
    local left = math.max(1, math.tointeger(tonumber(cost.count)) or 1)
    local taken = {}
    for _, it in ipairs(cost.items) do
        if left <= 0 then break end
        local n = math.min(Inv.count(c, it), left)
        if n > 0 then
            local ok, recs = Inv.remove(c, it, n, nil, ctx)
            if not ok then
                for _, r in ipairs(taken) do Inv.add(c, r.item, r.count, r.metadata, ctx, { decayAt = r.decayAt, noDecay = r.decayAt == nil }) end
                return nil, 'no_oil'
            end
            for _, r in ipairs(recs or {}) do taken[#taken + 1] = r end
            left = left - n
        end
    end
    if left > 0 then
        for _, r in ipairs(taken) do Inv.add(c, r.item, r.count, r.metadata, ctx, { decayAt = r.decayAt, noDecay = r.decayAt == nil }) end
        return nil, 'no_oil'
    end
    return taken
end

function Sharpen.finish(src, d)
    local b = lockOf(src)
    if not b then return false, 'not_busy' end
    if math.tointeger(L.num(d and d.token) or -1) ~= b.token then return false, 'bad_token' end
    busy[src] = nil   -- one finish per begin
    local elapsed = nowMs() - b.started
    if elapsed < b.duration * (L.num(HC.minElapsedRatio) or 0.9) then return false, 'too_fast' end
    local moved = L.dist(Stations.pedPos(src), b.coords)
    if moved and moved > (L.num(HC.maxMoveDistance) or 3.0) then return false, 'moved' end
    if not atWheel(src) then return false, 'station_far' end
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    local e = stackById(c, b.stackId)
    if not e then return false, 'no_item' end
    if not (SH.tools or {})[e.item] then return false, 'not_a_tool' end
    local def = Inv.def(e.item)
    local old = L.durability(e.metadata, def, maxDur())
    local meta, why = L.sharpenMeta(e.metadata, SH.tools[e.item], maxDur(), def)
    if not meta then return false, why end
    local ctx = { src = src, reason = 'sharpen', from = c.id, to = c.id }
    local taken
    taken, err = takeCost(c, ctx)
    if not taken then return false, err end
    local ok, newId = Inv.setMetadata(c, e.id, meta, e.count > 1 and 1 or nil, ctx)
    if not ok then
        for _, r in ipairs(taken) do Inv.add(c, r.item, r.count, r.metadata, ctx, { decayAt = r.decayAt, noDecay = r.decayAt == nil }) end
        return false, newId == 'slots' and 'no_room' or (newId or 'failed')
    end
    if SH.log ~= false and InvLog then
        local st = State.get(src)
        InvLog.write('sharpen', { actorSrc = src, targetCharId = st and st.charId or nil, from = c.id, to = c.id,
                                  item = e.item, count = 1,
                                  data = { stack = newId, old = old, new = meta.durability, cost = taken } })
    end
    local label = meta.label or def.label or e.item
    Sync.notify(src, ('%s is sharp again (%d%%).'):format(label, math.floor(meta.durability + 0.5)), 'success')
    TriggerEvent('MULTIinventory:toolSharpened', src, e.item, newId, old, meta.durability)
    return true, { durability = meta.durability, id = newId }
end

local REASON = {
    station_far = 'You need to be at a grinding wheel.', no_item = 'You no longer have that tool.',
    not_a_tool = 'That cannot be sharpened on a wheel.', already_sharp = 'That is already as sharp as it gets.',
    no_oil = 'You need oil for the wheel.', busy = 'You are already busy.', moved = 'You moved away from the wheel.',
    too_fast = 'That was too quick.', disabled = 'Sharpening is not available.', no_room = 'You have no room to carry the result.',
    rate_limited = 'Slow down.',
}
Sharpen.REASON = REASON

local function wrap(fn, notifyErr)
    return function(src, d)
        local ok, res = fn(src, d or {})
        if not ok and notifyErr and REASON[res] then Sync.notify(src, REASON[res], 'error') end
        return ok, res
    end
end

Actions.register('sharpenList', wrap(Sharpen.list, true))
Actions.register('sharpenBegin', wrap(Sharpen.begin, true))
Actions.register('sharpenFinish', wrap(Sharpen.finish, true))
Actions.register('sharpenCancel', wrap(Sharpen.cancel, false))

Config.Log = Config.Log or {}
Config.Log.actions = Config.Log.actions or {}
if Config.Log.actions.sharpen == nil then Config.Log.actions.sharpen = SH.log ~= false end

AddEventHandler('playerDropped', function()
    local src = source
    busy[src] = nil
    lastStart[src] = nil
end)

Sharpen._busy = busy   -- tests
