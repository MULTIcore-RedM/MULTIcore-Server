-- ============================================================
-- MULTIinventory :: server/core/money.lua
--
-- Money as items. Two physical items ARE the character's cash:
--   Config.Money.dollarItem (one-dollar bills, stack = whole dollars)
--   Config.Money.centItem   (coins, stack = cents)
--   cash = dollars + cents / 100
-- The framework cash stays the source of truth for every other script (VORP: character money,
-- addCurrency/removeCurrency; RSG: PlayerData.money.cash through the house bridge). This file keeps
-- the items of every ONLINE player's grid equal to that cash, in both directions:
--
--   framework -> items : Money.reconcile(src) sets the player's dollar/cent stacks to the framework
--                        cash (normalised: cents 0-99, the rest in dollars). Triggered by
--                        characterLoaded, the VORP 'Character' state bag (Money field, set by
--                        addCurrency/removeCurrency), RSGCore:Server:OnMoneyChange, and a periodic
--                        safety net (Config.Money.reconcileSeconds). Item changes made here carry
--                        ctx.reason = 'money_sync' and never touch the framework.
--   items -> framework : InvHooks itemAdded / itemRemoved on a player grid (any reason except
--                        'money_sync': drop, give, stash, pickup, robbery, admin, compat addItem/
--                        subItem, rsg AddItem/RemoveItem, ...) add / remove the same amount of
--                        framework cash at once. Cash in a stash or on the ground is therefore NOT
--                        in anybody's wallet.
--
-- All arithmetic is in integer cents. Framework floats are rounded to the nearest cent on read.
-- Loop guard: a per-player busy counter around every framework call; framework events only
-- SCHEDULE a reconcile (deduplicated), and a reconcile is idempotent (target = framework cash), so
-- the echo of our own addCurrency/removeCurrency finds nothing to do.
--
--   Money.enabled() -> bool                 Money.isMoney(item) -> bool
--   Money.cfg() -> Config.Money             Money.unitCents(item) -> 100|1|nil
--   Money.toCents(number) -> int            Money.fmt(cents) -> '3.45'
--   Money.fwCents(src) -> int|nil           Money.itemCents(container) -> int
--   Money.reconcile(src) -> ok, err         Money.schedule(src, delayMs)   Money.runPending() (tests)
--   Money.setDenoms(c, dollars, cents, src) -> ok, err   (sync change, framework untouched)
--   Money.transfer(src, op, cents, target) -> ok, err|result   op = 'give'|'drop'|'store'
--   Money.patchDef(def)                     (registry: limit 0, not usable, weight from config)
-- NUI action: 'cash' { op = 'give'|'drop'|'store', dollars, cents, target }
-- Exports: IsMoneyItem(name), GetWallet(src) -> { items = cents, framework = cents }, SyncMoney(src)
-- ============================================================

Money = Money or {}

local SYNC = 'money_sync'
local busy = {}       -- [src] = depth of our own framework / sync calls
local pending = {}    -- [src] = true while a reconcile is scheduled
local warned = {}     -- [src|key] = true (one console warning per cause)

local function cfg() return Config.Money or {} end
Money.cfg = cfg

function Money.enabled() return cfg().enabled == true end

function Money.isMoney(item)
    if type(item) ~= 'string' then return false end
    local c = cfg()
    return item == (c.dollarItem or 'money_dollar') or item == (c.centItem or 'money_cent')
end

function Money.unitCents(item)
    local c = cfg()
    if item == (c.dollarItem or 'money_dollar') then return 100 end
    if item == (c.centItem or 'money_cent') then return 1 end
    return nil
end

local function DOLLAR() return cfg().dollarItem or 'money_dollar' end
local function CENT() return cfg().centItem or 'money_cent' end

function Money.toCents(v)
    v = tonumber(v) or 0
    if v ~= v or v == math.huge or v == -math.huge then return 0 end
    if v >= 0 then return math.floor(v * 100 + 0.5) end
    return -math.floor(-v * 100 + 0.5)
end

function Money.fmt(cents)
    cents = math.tointeger(cents) or 0
    local neg = cents < 0
    if neg then cents = -cents end
    return ('%s%d.%02d'):format(neg and '-' or '', cents // 100, cents % 100)
end

local function isSync(ctx) return type(ctx) == 'table' and ctx.reason == SYNC end
local function syncCtx(src) return { src = src, reason = SYNC } end

-- ------------------------------------------------------------
-- registry: money items never have a carry limit, are never usable, never decay
-- ------------------------------------------------------------
function Money.patchDef(d)
    if not d or not Money.isMoney(d.name) then return d end
    local c = cfg()
    local w = c.weights or {}
    d.limit = 0
    d.usable = false
    d.degradation = 0
    d.canRemove = true
    if c.countWeight == false then
        d.weight = 0.0
    elseif d.name == DOLLAR() then
        d.weight = tonumber(w.dollar) or 0.001
    else
        d.weight = tonumber(w.cent) or 0.0025
    end
    d.money = Money.unitCents(d.name)
    return d
end

-- ------------------------------------------------------------
-- framework access (house bridge: same shape on VORP and RSG)
-- ------------------------------------------------------------
local function fwChar(src)
    local ok, user = pcall(function() return MBridge.Core.getUser(src) end)
    if not ok or not user then return nil end
    local ch = user.getUsedCharacter
    if type(ch) == 'function' then ch = ch() end
    return ch
end

function Money.fwCents(src)
    local ch = fwChar(src)
    if not ch then return nil end
    local ok, v = pcall(function() return ch.money end)
    if not ok then return nil end
    return Money.toCents(v)
end

local function enter(src) busy[src] = (busy[src] or 0) + 1 end
local function leave(src) busy[src] = math.max(0, (busy[src] or 1) - 1); if busy[src] == 0 then busy[src] = nil end end

---Apply `delta` cents to the framework cash. Removals are clamped to what the character has
---(never negative cash). Returns the cents really applied.
local function fwAdjust(src, delta)
    if delta == 0 then return 0 end
    local ch = fwChar(src)
    if not ch then return 0 end
    enter(src)
    local applied = 0
    local ok, err = pcall(function()
        if delta > 0 then
            local r = ch.addCurrency(0, delta / 100)
            if r ~= false then applied = delta end
        else
            local have = Money.toCents(ch.money)
            local take = math.min(-delta, math.max(0, have))
            if take > 0 then
                local r = ch.removeCurrency(0, take / 100)
                if r ~= false then applied = -take end
            end
        end
    end)
    leave(src)
    if not ok then print(('^1[MULTIinventory] money: framework call failed for %s: %s^7'):format(tostring(src), tostring(err))) end
    if applied ~= delta then
        print(('^3[MULTIinventory] money: framework cash change for %s was %s, applied %s^7'):format(
            tostring(src), Money.fmt(delta), Money.fmt(applied)))
    end
    return applied
end
Money._fwAdjust = fwAdjust

-- ------------------------------------------------------------
-- items
-- ------------------------------------------------------------
function Money.itemCents(c)
    if not c then return 0 end
    local n = 0
    for _, e in pairs(c.stacks) do
        if e.kind ~= 'weapon' then
            local u = Money.unitCents(e.item)
            if u then n = n + u * e.count end
        end
    end
    return n
end

local function counts(c)
    return Stacking.count(c, DOLLAR(), nil), Stacking.count(c, CENT(), nil)
end

local function syncRemove(c, item, n, ctx)
    if n <= 0 then return true end
    local removed, err = Stacking.remove(c, item, n, nil)
    if not removed then return false, err end
    for _, r in ipairs(removed) do Inv._emitRemoved(c, r.item, r.count, r.metadata, ctx) end
    return true
end

local function syncAdd(c, item, n, ctx)
    if n <= 0 then return true end
    local def = Inv.def(item)
    if def._missing then return false, 'unknown_item' end
    -- weight is not checked: the framework already holds this cash, the items only show it
    local plan, err = Stacking.plan(c, def, n, {}, nil)
    if not plan then return false, err end
    Stacking.apply(c, def, plan, {}, nil)
    Inv._emitAdded(c, item, n, {}, ctx)
    return true
end

---Set a grid's money stacks to exactly `wantD` dollars and `wantK` cents (sync change: the
---framework is NOT touched). Removals first, so a failed add (no free slot) leaves the grid
---showing LESS cash than the framework holds, never more.
function Money.setDenoms(c, wantD, wantK, src)
    local d, k = counts(c)
    if d == wantD and k == wantK then return true end
    local ctx = syncCtx(src)
    if src then enter(src) end
    local ok, err = true, nil
    if d > wantD then ok, err = syncRemove(c, DOLLAR(), d - wantD, ctx) end
    if ok and k > wantK then ok, err = syncRemove(c, CENT(), k - wantK, ctx) end
    if ok and d < wantD then ok, err = syncAdd(c, DOLLAR(), wantD - d, ctx) end
    if ok and k < wantK then ok, err = syncAdd(c, CENT(), wantK - k, ctx) end
    if src then leave(src) end
    return ok, err
end

---framework -> items for one online player.
function Money.reconcile(src)
    src = tonumber(src)
    if not Money.enabled() then return false, 'disabled' end
    local st = src and State.get(src)
    if not st then return false, 'player_not_loaded' end
    if busy[src] then Money.schedule(src, 50) return false, 'busy' end
    local target = Money.fwCents(src)
    if not target then return false, 'no_character' end
    if target < 0 then target = 0 end
    local c = Containers.peek('player:' .. st.charId)
    if not c then return false, 'not_loaded' end
    local ok, err = Money.setDenoms(c, target // 100, target % 100, src)
    if not ok then
        local key = src .. ':' .. tostring(err)
        if not warned[key] then
            warned[key] = true
            print(('^3[MULTIinventory] money: cannot show $%s as items for %s (%s) - the cash stays in the framework; retrying^7'):format(
                Money.fmt(target), tostring(src), tostring(err)))
        end
        return false, err
    end
    warned[src .. ':slots'] = nil
    return true
end

function Money.schedule(src, delayMs)
    src = tonumber(src)
    if not src or not Money.enabled() or pending[src] then return end
    pending[src] = true
    SetTimeout(delayMs or 0, function()
        pending[src] = nil
        local ok, err = pcall(Money.reconcile, src)
        if not ok then print(('^1[MULTIinventory] money reconcile %s: %s^7'):format(tostring(src), tostring(err))) end
    end)
end

-- tests / admin: run every scheduled reconcile now
function Money.runPending()
    local list = {}
    for src in pairs(pending) do list[#list + 1] = src end
    pending = {}
    for _, src in ipairs(list) do Money.reconcile(src) end
end

local function onlineOwner(c)
    if c.kind ~= 'player' or not c.ownerCharId then return nil end
    return State.srcOfChar(c.ownerCharId)
end

-- ------------------------------------------------------------
-- hooks: vetoes
-- ------------------------------------------------------------
InvHooks.register('canAdd', function(c, item, count, meta, ctx)
    if not Money.isMoney(item) or isSync(ctx) then return true end
    if not Money.enabled() then
        if cfg().freezeWhenDisabled ~= false and not (ctx and ctx.reason == 'admin') then return false, 'money_disabled' end
        return true
    end
    if c.kind == 'player' then
        local src = onlineOwner(c)
        if not src then return false, 'player_offline' end
        if not Money.fwCents(src) then return false, 'no_character' end
        return true
    end
    if c.kind == 'equip' then return false, 'equip_slot' end
    if c.kind == 'drop' then
        if cfg().allowOnGround == false then return false, 'not_allowed' end
        return true
    end
    if cfg().allowInStashes == false then return false, 'not_allowed' end
    return true
end)

InvHooks.register('canRemove', function(c, entry, count, ctx)
    if not Money.enabled() or not entry or entry.kind == 'weapon' or not Money.isMoney(entry.item) or isSync(ctx) then return true end
    if c.kind ~= 'player' then return true end
    if ctx and ctx.reason == 'destroy' and not cfg().allowDestroy then return false, 'cannot_drop' end
    local src = onlineOwner(c)
    if not src then return false, 'player_offline' end
    local fw = Money.fwCents(src)
    if not fw then return false, 'no_character' end
    local need = (Money.unitCents(entry.item) or 0) * (tonumber(count) or 0)
    if need > fw then
        -- the grid shows more than the framework holds (a script just took cash): re-sync, refuse
        Money.schedule(src, 0)
        return false, 'not_enough'
    end
    return true
end)

-- ------------------------------------------------------------
-- hooks: items -> framework
-- ------------------------------------------------------------
local function logMoney(action, c, item, count, ctx, cents, applied)
    InvLog.write(action, { actorSrc = ctx and ctx.src, targetCharId = c.ownerCharId,
        from = ctx and ctx.from, to = ctx and ctx.to or c.id, item = item, count = count,
        data = { cents = cents, applied = applied, reason = ctx and ctx.reason, resource = ctx and ctx.resource } })
end

InvHooks.register('itemAdded', function(c, item, count, meta, ctx)
    if not Money.enabled() or c.kind ~= 'player' or not Money.isMoney(item) or isSync(ctx) then return end
    local src = onlineOwner(c)
    if not src then return end   -- offline grids are refused by canAdd; Inv.clear/admin paths: login re-syncs
    local cents = Money.unitCents(item) * count
    local applied = fwAdjust(src, cents)
    logMoney('money_in', c, item, count, ctx, cents, applied)
    Money.schedule(src, 0)   -- normalise the denominations (e.g. 150 cents -> 1 dollar 50 cents)
end)

InvHooks.register('itemRemoved', function(c, item, count, meta, ctx)
    if not Money.enabled() or c.kind ~= 'player' or not Money.isMoney(item) or isSync(ctx) then return end
    local src = onlineOwner(c)
    if not src then return end
    local cents = Money.unitCents(item) * count
    local applied = fwAdjust(src, -cents)
    logMoney('money_out', c, item, count, ctx, cents, -applied)
    Money.schedule(src, 0)
end)

-- open payload: the UI reads the wallet from the items when enabled
InvHooks.register('openPayload', function(src, payload)
    if not payload or not payload.config then return end
    local c = cfg()
    payload.config.money = { enabled = Money.enabled(), dollarItem = DOLLAR(), centItem = CENT(),
                             allowOnGround = c.allowOnGround ~= false, allowInStashes = c.allowInStashes ~= false }
end)

-- ------------------------------------------------------------
-- framework -> items triggers
-- ------------------------------------------------------------
InvHooks.register('characterLoaded', function(src)
    if not Money.enabled() then return end
    pending[src] = nil
    Money.schedule(src, cfg().loadDelayMs or 2000)
end)

InvHooks.register('characterUnloaded', function(src)
    pending[src] = nil
    busy[src] = nil
    for k in pairs(warned) do if tostring(k):match('^' .. tostring(src) .. ':') then warned[k] = nil end end
end)

-- RSG: rsg-core fires this server-local event after every AddMoney / RemoveMoney / SetMoney
AddEventHandler('RSGCore:Server:OnMoneyChange', function(src, moneyType)
    if not Money.enabled() or (moneyType ~= nil and moneyType ~= 'cash') then return end
    Money.schedule(tonumber(src), 0)
end)

-- VORP: vorp_core replicates the character as the player state bag 'Character' (field Money is
-- updated by addCurrency / removeCurrency). setMoney does not touch the bag: the loop catches it.
if type(AddStateBagChangeHandler) == 'function' then
    local lastSeen = {}
    AddStateBagChangeHandler('Character', nil, function(bagName, _, value)
        if not Money.enabled() or type(value) ~= 'table' then return end
        local src = GetPlayerFromStateBagName and GetPlayerFromStateBagName(bagName)
        src = tonumber(src)
        if not src or src == 0 then return end
        local m = Money.toCents(value.Money)
        if lastSeen[src] == m then return end
        lastSeen[src] = m
        Money.schedule(src, 0)
    end)
    AddEventHandler('playerDropped', function() lastSeen[source] = nil end)
end

-- safety net: every online player, every Config.Money.reconcileSeconds (started once the core is ready)
local loopStarted = false
AddEventHandler('MULTIinventory:ready', function()
    if loopStarted then return end
    loopStarted = true
    CreateThread(function()
    while true do
        Wait(math.max(1, tonumber(cfg().reconcileSeconds) or 5) * 1000)
        if Money.enabled() then
            for src in pairs(State.all()) do
                if not pending[src] then
                    local ok, err = pcall(Money.reconcile, src)
                    if not ok then print(('^1[MULTIinventory] money loop %s: %s^7'):format(tostring(src), tostring(err))) end
                end
            end
        end
    end
    end)
end)

-- ------------------------------------------------------------
-- exact-amount transfers ($3.45): the 'cash' NUI action
-- ------------------------------------------------------------
local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local v = GetEntityCoords(ped)
    return { x = v.x, y = v.y, z = v.z }
end

local function dist(a, b)
    if not a or not b then return math.huge end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---Move `D` dollars then `C` cents out of the grid with `mover(item, slot, n) -> ok, err`.
local function moveDenoms(pc, D, C, mover)
    local done = {}
    for _, spec in ipairs({ { DOLLAR(), D }, { CENT(), C } }) do
        local item, left = spec[1], spec[2]
        while left > 0 do
            local e = Stacking.candidates(pc, item, nil)[1]
            if not e then return false, 'not_enough', done end
            local n = math.min(left, e.count)
            local ok, err = mover(item, e.slot, n)
            if not ok then return false, err, done end
            done[#done + 1] = { item = item, n = n }
            left = left - n
        end
    end
    return true, nil, done
end

---Put moved money back (rollback). Ordinary item changes: the hooks move the framework cash too.
local function putBack(fromC, pc, done, src)
    local ctx = { src = src, reason = 'cash_rollback' }
    for i = #done, 1, -1 do
        local x = done[i]
        if fromC and Inv.remove(fromC, x.item, x.n, nil, ctx) then Inv.add(pc, x.item, x.n, nil, ctx) end
    end
end

---op = 'give' (target = server id) | 'drop' | 'store' (the open secondary). cents = integer > 0.
function Money.transfer(src, op, cents, target)
    if not Money.enabled() then return false, 'money_disabled' end
    cents = math.tointeger(tonumber(cents))
    if not cents or cents < 1 then return false, 'bad_count' end
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local pc = Containers.peek('player:' .. st.charId)
    if not pc then return false, 'player_not_loaded' end

    -- destination first (cheap refusals before touching anything)
    local toC, tst, tgt
    if op == 'give' then
        tgt = math.tointeger(tonumber(target))
        if not tgt or tgt == src then return false, 'bad_target' end
        tst = State.get(tgt)
        if not tst then return false, 'target_not_loaded' end
        if dist(pedCoords(src), pedCoords(tgt)) > (Config.Give.maxDistance or 3.0) then return false, 'too_far' end
        toC = Containers.get('player:' .. tst.charId, { create = true })
    elseif op == 'store' then
        local err
        toC, err = Actions.ref(src, 'secondary')
        if not toC then return false, err end
        if toC == pc then return false, 'bad_target' end
    elseif op == 'drop' then
        if Config.Drop.mode ~= 'world' and not cfg().allowDestroy then return false, 'cannot_drop' end
    else
        return false, 'bad_op'
    end

    -- the grid must show the framework cash right now
    Money.reconcile(src)
    local fw = Money.fwCents(src) or 0
    local have = Money.itemCents(pc)
    if cents > have or cents > fw then return false, 'not_enough' end

    -- make change: arrange the grid so it holds at least D dollars and C cents, same total
    local D, C = cents // 100, cents % 100
    local R = have - cents
    local d0, k0 = counts(pc)
    local ok, err = Money.setDenoms(pc, D + R // 100, C + R % 100, src)
    if not ok then
        Money.setDenoms(pc, d0, k0, src)
        return false, err
    end

    local done, dropId
    if op == 'drop' then
        ok, err, done = moveDenoms(pc, D, C, function(_, slot, n)
            local r1, r2 = Drops.dropFromPlayer(src, slot, n)
            if r1 then dropId = r2 end
            return r1, r2
        end)
        if not ok then
            local d = dropId and Drops.get(dropId)
            putBack(d and Containers.peek(d.cid), pc, done, src)
            if d then
                local dc = Containers.peek(d.cid)
                if dc and next(dc.stacks) == nil then Drops.remove(d, 'failed')
                else TriggerClientEvent('MULTIinventory:drops:set', -1, Drops.view(d)) end
            end
        end
    else
        local ctx = { src = src, reason = op == 'give' and 'give' or 'move', from = pc.id, to = toC.id, target = tgt }
        ok, err, done = moveDenoms(pc, D, C, function(item, slot, n)
            return Inv.move(pc, slot, toC, nil, n, ctx)
        end)
        if not ok then putBack(toC, pc, done, src) end
    end
    Money.schedule(src, 0)
    if tgt then Money.schedule(tgt, 0) end
    if not ok then return false, err end

    local text = '$' .. Money.fmt(cents)
    InvLog.write('cash', { actorSrc = src, targetCharId = tst and tst.charId, from = pc.id,
        to = toC and toC.id or (dropId and ('drop:' .. dropId)), item = 'cash', count = cents,
        data = { op = op, cents = cents, dollars = D, coins = C, dropId = dropId } })
    if op == 'give' then
        Sync.notify(src, L('money_given', { amount = text }), 'success')
        Sync.notify(tgt, L('money_received', { amount = text }), 'success')
        TriggerEvent('MULTIinventory:cashGiven', src, tgt, cents)
    elseif op == 'drop' then
        Sync.notify(src, L('money_dropped', { amount = text }), 'success')
    else
        Sync.notify(src, L('money_stored', { amount = text }), 'success')
    end
    return true, { cents = cents, dropId = dropId }
end

Actions.register('cash', function(src, d)
    local cents
    if d.amount ~= nil then
        cents = Money.toCents(d.amount)                       -- 3.45
    else
        local dollars = math.tointeger(tonumber(d.dollars or 0))
        local c = math.tointeger(tonumber(d.cents or 0))
        if not dollars or not c or dollars < 0 or c < 0 or c > 99 then return false, 'bad_count' end
        cents = dollars * 100 + c
    end
    return Money.transfer(src, d.op, cents, d.target)
end)

-- ------------------------------------------------------------
-- exports
-- ------------------------------------------------------------
exports('IsMoneyItem', function(name) return Money.isMoney(name) end)
exports('GetWallet', function(src)
    src = tonumber(src)
    local st = src and State.get(src)
    local c = st and Containers.peek('player:' .. st.charId)
    return { items = Money.itemCents(c), framework = Money.fwCents(src), enabled = Money.enabled() }
end)
exports('SyncMoney', function(src) return Money.reconcile(src) end)

-- tests only
function Money._reset() busy, pending, warned = {}, {}, {} end
function Money._busy(src) return busy[src] end
