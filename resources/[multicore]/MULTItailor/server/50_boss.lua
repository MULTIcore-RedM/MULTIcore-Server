--[[
    Boss office (till + staff) and the stockroom stash.

    lib.callback (boss of the shop only):
      multitailor:boss:open      (pointId)                          -> payload | nil, err
      multitailor:boss:withdraw  ({ pointId, amount })              -> { ok, error?, payload? }
      multitailor:boss:deposit   ({ pointId, amount })              -> { ok, error?, payload? }
      multitailor:boss:hire      ({ pointId, target })              -> { ok, error?, payload? }   target = server id, standing near
      multitailor:boss:fire      ({ pointId, target })              -> { ok, error?, payload? }   online staff only
      multitailor:boss:grade     ({ pointId, target, grade })       -> { ok, error?, payload? }
    Net event: MULTItailor:openStorage (pointId)  - staff of the shop, stash 'multi_storage_<businessId>'.
    The till takes the counter's sales; it is the same money RINGOjobsandcrafting's ledger held
    (imported once, see server/05_db.lua).
]]
local busy = {}

local function bossPoint(src, pointId)
    local p, role = TP.access(src, pointId, 'boss')
    if not p then return nil, role end
    if p.kind ~= 'boss' or not p.businessId then return nil, L('err_no_access') end
    return p
end

local function staffOnline(p)
    local out = {}
    for _, id in ipairs(TA.players()) do
        local job = TA.job(id)
        if job and job.name == p.townJob then
            out[#out + 1] = { id = id, name = TA.name(id), grade = job.grade }
        end
    end
    table.sort(out, function(a, b) return a.grade > b.grade end)
    return out
end

local function nearby(src, p)
    local out = {}
    for _, id in ipairs(TA.players()) do
        if id ~= src and TA.dist(id, p.coords) <= 6.0 then
            local job = TA.job(id)
            if not (job and job.name == p.townJob) then out[#out + 1] = { id = id, name = TA.name(id) } end
        end
    end
    return out
end

local function payload(src, p)
    local b = TP.business(p)
    return {
        pointId = p.id, businessLabel = b.label, town = b.town, townJob = p.townJob,
        balance = TDB.till.balance(b.id), history = TDB.till.history(b.id, Config.Till.historyRows or 25),
        cash = TA.money(src), staff = staffOnline(p), nearby = nearby(src, p), bossGrade = Config.Tailor.bossGrade,
        maxTx = Config.Till.maxTransaction,
    }
end

lib.callback.register('multitailor:boss:open', function(src, pointId)
    if not TA.rate(src, 'default') then return nil, L('err_slow') end
    local p, err = bossPoint(src, pointId)
    if not p then return nil, err end
    local job = TA.job(src)
    local okL, why = TA.licence(src, 'boss', job and job.name)
    if not okL then return nil, why end
    TDB.ready()
    return payload(src, p)
end)

local function amountOf(v)
    local n = TU.money(v)
    if not n or n <= 0 or n > (Config.Till.maxTransaction or 5000) then return nil end
    return n
end

lib.callback.register('multitailor:boss:withdraw', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'buy') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    local p, err = bossPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local amount = amountOf(data.amount)
    if not amount then return { ok = false, error = L('err_bad_amount') } end
    busy[src] = true
    local res
    local ok, e = pcall(function()
        if not TDB.till.debit(p.businessId, amount, 'withdraw', TA.name(src)) then res = { ok = false, error = L('err_till_short') } return end
        if not TA.giveMoney(src, amount) then
            TDB.till.credit(p.businessId, amount, 'refund', 'System', 'withdrawal failed')
            res = { ok = false, error = L('err_generic') }
            return
        end
        TA.notify(src, L('till_withdrawn', amount), 'success')
        res = { ok = true, payload = payload(src, p) }
    end)
    busy[src] = nil
    if not ok then print(('^1[MULTItailor] withdraw failed: %s^0'):format(tostring(e))) return { ok = false, error = L('err_generic') } end
    return res
end)

lib.callback.register('multitailor:boss:deposit', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'buy') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    local p, err = bossPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local amount = amountOf(data.amount)
    if not amount then return { ok = false, error = L('err_bad_amount') } end
    busy[src] = true
    local res
    local ok, e = pcall(function()
        if not TA.takeMoney(src, amount) then res = { ok = false, error = L('err_no_money', amount) } return end
        TDB.till.credit(p.businessId, amount, 'deposit', TA.name(src))
        TA.notify(src, L('till_deposited', amount), 'success')
        res = { ok = true, payload = payload(src, p) }
    end)
    busy[src] = nil
    if not ok then print(('^1[MULTItailor] deposit failed: %s^0'):format(tostring(e))) return { ok = false, error = L('err_generic') } end
    return res
end)

lib.callback.register('multitailor:boss:hire', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, err = bossPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local target = TU.int(data.target, 1, 100000)
    if not target or target == src or not GetPlayerName(target) or TA.dist(target, p.coords) > 6.0 then return { ok = false, error = L('err_target') } end
    if not TA.setJob(target, p.townJob, 0) then return { ok = false, error = L('err_generic') } end
    TA.notify(target, L('hired', TP.business(p).label), 'success')
    TA.notify(src, L('hired_boss', TA.name(target)), 'success')
    return { ok = true, payload = payload(src, p) }
end)

lib.callback.register('multitailor:boss:fire', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, err = bossPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local target = TU.int(data.target, 1, 100000)
    local job = target and TA.job(target)
    if not target or target == src or not job or job.name ~= p.townJob then return { ok = false, error = L('err_target') } end
    local me = TA.job(src)
    if job.grade >= (me and me.grade or 0) then return { ok = false, error = L('err_rank') } end
    if not TA.setJob(target, 'unemployed', 0) then return { ok = false, error = L('err_generic') } end
    TA.notify(target, L('fired', TP.business(p).label), 'error')
    return { ok = true, payload = payload(src, p) }
end)

lib.callback.register('multitailor:boss:grade', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, err = bossPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local target, grade = TU.int(data.target, 1, 100000), TU.int(data.grade, 0, 100)
    local job = target and TA.job(target)
    local me = TA.job(src)
    if not target or not grade or target == src or not job or job.name ~= p.townJob then return { ok = false, error = L('err_target') } end
    if grade >= (me and me.grade or 0) or job.grade >= (me and me.grade or 0) then return { ok = false, error = L('err_rank') } end
    if not TA.setJob(target, p.townJob, grade) then return { ok = false, error = L('err_generic') } end
    TA.notify(target, L('graded', grade), 'inform')
    return { ok = true, payload = payload(src, p) }
end)

-- ---------------------------------------------------------------- stockroom
local lastStash = {}
RegisterNetEvent('MULTItailor:openStorage', function(pointId)
    local src = source
    local now = GetGameTimer()
    if lastStash[src] and now - lastStash[src] < 1500 then return end
    lastStash[src] = now
    local p, err = TP.access(src, pointId, 'staff')
    if not p then return TA.notify(src, err, 'error') end
    if p.kind ~= 'storage' or not p.businessId then return TA.notify(src, L('err_no_access'), 'error') end
    local s = p.storage or {}
    local d = Config.Tailor.storage or {}
    TA.stashOpen(src, TL.storageKey(p.businessId), { label = s.label or d.label, slots = s.slots or d.slots, maxWeight = s.maxWeight or d.maxWeight })
end)

AddEventHandler('playerDropped', function() busy[source] = nil lastStash[source] = nil end)
