-- ============================================================
-- MULTIinventory :: trading between two players (server)
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting). Written fresh for MULTIinventory.
--
-- Flow: A asks B (TradeRequest) -> B says yes (TradeAnswer) -> both see the trade
-- window. Each puts satchel stacks (TradeSetItem) and cash (TradeSetCash) in;
-- any change clears both accepts. When both have accepted (TradeAccept) the
-- server swaps everything at once or nothing at all.
--
-- No dupes:
--   * an offered satchel slot is locked (inv.tradeLocks): Move / Use / Give / Drop
--     refuse it until the trade ends;
--   * the swap re-checks every offered stack (the very same stack table still in
--     the slot, enough of it), both players' cash, room in both satchels,
--     distance, death and handcuffs, all without yielding;
--   * every step has a rollback, so a refusal leaves both satchels and purses
--     exactly as they were.
-- Walking apart, dying, leaving, logging out or opening another inventory cancels.
--
-- Net events / callbacks (client -> server):
--   net MULTIinventory:server:tradeRequest (targetServerId)
--   net MULTIinventory:server:tradeAnswer (fromServerId, accept)
--   cb  MULTIinventory:server:tradeItem (satchelSlot, amount)  amount 0 = take back -> ok, err
--   cb  MULTIinventory:server:tradeCash (amount)                                     -> ok, err
--   cb  MULTIinventory:server:tradeAccept (state)                                    -> ok, err
--   net MULTIinventory:server:tradeCancel ()
-- Server -> client:
--   MULTIinventory:client:tradeRequest (fromServerId, name, seconds)
--   MULTIinventory:client:tradeRequestGone (fromServerId)
--   MULTIinventory:client:tradeOpen (ownInv, defs, view, viewDefs)
--   MULTIinventory:client:tradeUpdate (view, viewDefs)
--   MULTIinventory:client:tradeEnd ()
-- Server events: MULTIinventory:tradeStarted (id, a, b), MULTIinventory:tradeDone (id, a, b),
--                MULTIinventory:tradeCancelled (id, a, b, reasonKey)
-- ============================================================

local Inv = MULTIInv
local Cfg = Config.Trade

local trades = {}      -- id -> trade
local bySrc = {}       -- source -> trade id
local requests = {}    -- target source -> { from = source, expires = game timer ms }
local nextId = 0

local function now() return GetGameTimer() end
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

local function ownInv(src)
    local id = Inv.BySrc[src]
    return id and Inv.List[id] or nil
end

local function blocked(P)
    local m = P and P.PlayerData and P.PlayerData.metadata or {}
    return m.isdead or m.inlaststand or m.ishandcuffed or false
end

local function nameOf(src)
    local P = Inv.GetPlayer(src)
    local ci = P and P.PlayerData and P.PlayerData.charinfo
    if type(ci) == 'table' and ci.firstname then return ci.firstname .. ' ' .. (ci.lastname or '') end
    return GetPlayerName(src) or tostring(src)
end

--- Both players have a position and stand within dist metres of each other.
local function near(a, b, dist)
    local pa, pb = Inv.PlayerCoords(a), Inv.PlayerCoords(b)
    return pa ~= nil and pb ~= nil and #(pa - pb) <= dist
end

local function stackable(def)
    local w = MULTIInvData.Weapons[def.name]
    return not def.unique and not (def.type == 'weapon' and not (w and w.thrown))
end

local function cashOf(src)
    local P = Inv.GetPlayer(src)
    if not P then return 0 end
    local ok, v = pcall(P.Functions.GetMoney, 'cash')
    return ok and tonumber(v) or 0
end

local function setBusy(src, v)
    pcall(function() Player(src).state.inv_busy = v end)
end

local function other(t, src) return src == t.a and t.b or t.a end

--- Is src in a trade? → trade id or nil
function Inv.InTrade(src)
    return bySrc[tonumber(src) or -1]
end

-- ------------------------------------------------------------
-- locks
-- ------------------------------------------------------------

local function lock(inv, slot, id)
    inv.tradeLocks = inv.tradeLocks or {}
    inv.tradeLocks[slot] = id
end

local function unlock(inv, slot)
    if not inv or not inv.tradeLocks then return end
    inv.tradeLocks[slot] = nil
    if next(inv.tradeLocks) == nil then inv.tradeLocks = nil end
end

local function unlockAll(t)
    for _, s in ipairs({ t.a, t.b }) do
        local inv = t.inv[s]
        for _, l in ipairs(t.side[s].items) do unlock(inv, l.slot) end
    end
end

-- ------------------------------------------------------------
-- what each player sees
-- ------------------------------------------------------------

local function sideView(t, s)
    local side, inv = t.side[s], t.inv[s]
    local items = {}
    for i, l in ipairs(side.items) do
        local st = inv and inv.items[l.slot]
        local def = Inv.Items[l.name] or {}
        items[#items + 1] = {
            slot = i, from = l.slot, name = l.name, amount = l.amount,
            info = st and st.info or {}, label = def.label, weight = def.weight, type = def.type,
        }
    end
    return { items = items, cash = side.cash, accepted = side.accepted }
end

--- The trade as player src sees it.
function Inv.TradeView(src)
    local id = bySrc[tonumber(src) or -1]
    local t = id and trades[id]
    if not t then return nil end
    local o = other(t, src)
    return {
        id = t.id,
        partner = nameOf(o),
        mine = sideView(t, src),
        theirs = sideView(t, o),
        myCash = cashOf(src),
        maxItems = Cfg.MaxItems,
        maxCash = Cfg.MaxCash,
        acceptDelay = Cfg.AcceptDelayMs,
    }
end

local function viewDefs(t)
    local out = {}
    for _, s in ipairs({ t.a, t.b }) do
        for _, l in ipairs(t.side[s].items) do out[l.name] = Inv.Items[l.name] end
    end
    return out
end

local function push(t)
    local defs = viewDefs(t)
    for _, s in ipairs({ t.a, t.b }) do
        TriggerClientEvent('MULTIinventory:client:tradeUpdate', s, Inv.TradeView(s), defs)
    end
end

--- Any change: both accepts are cleared and the accept delay starts again.
local function changed(t)
    t.changedAt = now()
    t.side[t.a].accepted = false
    t.side[t.b].accepted = false
    push(t)
end

-- ------------------------------------------------------------
-- start / end
-- ------------------------------------------------------------

local function endTrade(t, reasonKey, kind)
    if not trades[t.id] then return end
    trades[t.id] = nil
    unlockAll(t)
    for _, s in ipairs({ t.a, t.b }) do
        if bySrc[s] == t.id then bySrc[s] = nil end
        setBusy(s, false)
        TriggerClientEvent('MULTIinventory:client:tradeEnd', s)
        if reasonKey then Inv.Notify(s, reasonKey, kind or 'error') end
        -- the satchel view is pushed again so the page drops any lock marks
        local inv = t.inv[s]
        if inv and inv.ownerSrc == s then Inv.SendUpdate(s, inv) end
    end
    if reasonKey ~= 'trade_done' then TriggerEvent('MULTIinventory:tradeCancelled', t.id, t.a, t.b, reasonKey) end
end

local function startTrade(a, b)
    nextId = nextId + 1
    local t = {
        id = nextId, a = a, b = b, changedAt = now(),
        inv = { [a] = ownInv(a), [b] = ownInv(b) },
        side = {
            [a] = { items = {}, cash = 0, accepted = false },
            [b] = { items = {}, cash = 0, accepted = false },
        },
    }
    trades[t.id] = t
    bySrc[a], bySrc[b] = t.id, t.id
    local defs = viewDefs(t)
    for _, s in ipairs({ a, b }) do
        Inv.Close(s, true)       -- frees any stash the player had open; the page stays up
        setBusy(s, true)
        local inv = t.inv[s]
        TriggerClientEvent('MULTIinventory:client:tradeOpen', s, Inv.View(inv), Inv.DefsFor(inv), Inv.TradeView(s), defs)
    end
    TriggerEvent('MULTIinventory:tradeStarted', t.id, a, b)
    return true, t.id
end

--- Ends src's trade (reasonKey = locale key shown to both, default 'trade_cancelled').
function Inv.TradeCancel(src, reasonKey)
    local id = bySrc[tonumber(src) or -1]
    local t = id and trades[id]
    if not t then return false, 'no_trade' end
    endTrade(t, reasonKey or 'trade_cancelled', 'error')
    return true
end

-- the checks shared by a request and its answer
local function canTrade(a, b)
    if not Cfg.Enabled then return false, 'disabled' end
    if not a or not b or a == b then return false, 'bad_target' end
    local A, B = Inv.GetPlayer(a), Inv.GetPlayer(b)
    if not A or not B or not ownInv(a) or not ownInv(b) then return false, 'no_player' end
    if blocked(A) or blocked(B) then return false, 'blocked' end
    if bySrc[a] or bySrc[b] then return false, 'busy' end
    if not near(a, b, Cfg.Distance) then return false, 'too_far' end
    return true
end

--- src asks target to trade. → true | false, err
function Inv.TradeRequest(src, target)
    src, target = tonumber(src), tonumber(target)
    local ok, err = canTrade(src, target)
    if not ok then return false, err end
    -- both asked each other: start straight away
    local mine = requests[src]
    if mine and mine.from == target and mine.expires > now() then return Inv.TradeAnswer(src, target, true) end
    local r = requests[target]
    if r and r.from ~= src and r.expires > now() then return false, 'busy' end
    requests[target] = { from = src, expires = now() + Cfg.RequestSeconds * 1000 }
    TriggerClientEvent('MULTIinventory:client:tradeRequest', target, src, nameOf(src), Cfg.RequestSeconds)
    Inv.Notify(src, 'trade_sent', 'info', nameOf(target))
    return true
end

--- src answers the request from `from`. → true | false, err
function Inv.TradeAnswer(src, from, accept)
    src, from = tonumber(src), tonumber(from)
    local r = src and requests[src]
    if not r or r.from ~= from then return false, 'no_request' end
    requests[src] = nil
    if r.expires < now() then return false, 'expired' end
    if accept ~= true then
        Inv.Notify(from, 'trade_declined', 'error', nameOf(src))
        return true
    end
    local ok, err = canTrade(from, src)
    if not ok then
        Inv.Notify(from, 'trade_failed', 'error')
        return false, err
    end
    return startTrade(from, src)
end

-- ------------------------------------------------------------
-- offers
-- ------------------------------------------------------------

local function tradeOf(src)
    local id = bySrc[tonumber(src) or -1]
    return id and trades[id] or nil
end

--- Offers `amount` of the stack in src's satchel slot; amount 0 takes it back. → true | false, err
function Inv.TradeSetItem(src, slot, amount)
    src, slot = tonumber(src), tonumber(slot)
    local t = tradeOf(src)
    if not t then return false, 'no_trade' end
    local inv = t.inv[src]
    if not inv or not Inv.IsPositiveInt(slot, inv.slots) then return false, 'bad_slot' end
    local side = t.side[src]
    local idx
    for i, l in ipairs(side.items) do if l.slot == slot then idx = i break end end
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then
        if not idx then return false, 'no_item' end
        table.remove(side.items, idx)
        unlock(inv, slot)
        changed(t)
        return true
    end

    local st = inv.items[slot]
    if not st then return false, 'no_item' end
    local def = Inv.Items[st.name]
    if not def then return false, 'unknown_item' end
    if def.canRemove == false then return false, 'not_allowed' end
    if not stackable(def) then amount = 1 end
    if not Inv.IsPositiveInt(amount, st.amount) then return false, 'bad_amount' end
    if idx then
        local l = side.items[idx]
        if l.ref == st and l.amount == amount then return true end
        l.ref, l.name, l.amount = st, st.name, amount
    else
        if #side.items >= Cfg.MaxItems then return false, 'trade_full' end
        side.items[#side.items + 1] = { slot = slot, ref = st, name = st.name, amount = amount }
        lock(inv, slot, t.id)
    end
    changed(t)
    return true
end

--- Sets the cash src offers (dollars, cents kept). → true | false, err
function Inv.TradeSetCash(src, amount)
    src = tonumber(src)
    local t = tradeOf(src)
    if not t then return false, 'no_trade' end
    if type(amount) == 'string' then
        if #amount > 16 or not amount:match('^%s*%d*%.?%d*%s*$') then return false, 'bad_amount' end
        amount = tonumber(amount) or 0
    end
    if type(amount) ~= 'number' or amount ~= amount or amount == math.huge or amount < 0 then return false, 'bad_amount' end
    amount = round2(amount)
    if amount > Cfg.MaxCash then return false, 'too_much' end
    if amount > cashOf(src) then return false, 'no_cash' end
    if t.side[src].cash == amount then return true end
    t.side[src].cash = amount
    changed(t)
    return true
end

-- ------------------------------------------------------------
-- the swap
-- ------------------------------------------------------------

--- Takes every offered stack out of both satchels, then puts each into the other one.
--- Any failure undoes all of it. → true | false, reasonKey, whoSrc
local function swapItems(t)
    local removed, added = {}, {}
    local function undo()
        for i = #added, 1, -1 do
            local x = added[i]
            Inv.RemoveFrom(x.inv, x.name, x.amount, x.slot, nil, 'trade rollback')
        end
        for i = #removed, 1, -1 do
            local x = removed[i]
            Inv.AddTo(x.inv, x.name, x.amount, x.info, x.slot, 'rollback')
        end
    end
    for _, s in ipairs({ t.a, t.b }) do
        local inv = t.inv[s]
        for _, l in ipairs(t.side[s].items) do
            local st = inv.items[l.slot]
            local name, info = st.name, st.info
            if not Inv.RemoveFrom(inv, name, l.amount, l.slot, nil, ('trade to %s'):format(other(t, s))) then
                undo()
                return false, 'trade_changed', s
            end
            removed[#removed + 1] = { inv = inv, name = name, amount = l.amount, info = info, slot = l.slot, from = s }
        end
    end
    for _, x in ipairs(removed) do
        local to = other(t, x.from)
        local ok, _, placed = Inv.AddTo(t.inv[to], x.name, x.amount, x.info, nil, ('trade from %s'):format(x.from))
        if not ok then
            undo()
            return false, 'trade_no_room', to
        end
        added[#added + 1] = { inv = t.inv[to], name = x.name, amount = x.amount, slot = placed }
    end
    return true, removed
end

--- Re-checks everything, then swaps items and cash at once. → true | false, reasonKey, whoSrc
local function swap(t)
    local a, b = t.a, t.b
    local A, B = Inv.GetPlayer(a), Inv.GetPlayer(b)
    if not A or not B or ownInv(a) ~= t.inv[a] or ownInv(b) ~= t.inv[b] then return false, 'trade_gone' end
    if blocked(A) or blocked(B) then return false, 'trade_blocked' end
    if not near(a, b, Cfg.KeepDistance) then return false, 'trade_too_far' end
    -- every offered stack is still the same stack, with enough in it
    for _, s in ipairs({ a, b }) do
        local inv = t.inv[s]
        for _, l in ipairs(t.side[s].items) do
            local st = inv.items[l.slot]
            local def = st and Inv.Items[st.name]
            if not st or st ~= l.ref or st.amount < l.amount or not def or def.canRemove == false then
                return false, 'trade_changed', s
            end
        end
    end
    local ca, cb = t.side[a].cash, t.side[b].cash
    if ca > cashOf(a) then return false, 'trade_no_cash', a end
    if cb > cashOf(b) then return false, 'trade_no_cash', b end

    -- cash out of both purses first (easy to put back)
    if ca > 0 and not A.Functions.RemoveMoney('cash', ca, 'trade') then return false, 'trade_no_cash', a end
    if cb > 0 and not B.Functions.RemoveMoney('cash', cb, 'trade') then
        if ca > 0 then A.Functions.AddMoney('cash', ca, 'trade refund') end
        return false, 'trade_no_cash', b
    end
    local okCall, ok, res, who = pcall(Inv.Batch, swapItems, t)
    if not okCall then
        print(('^1[MULTIinventory] trade %d failed: %s^7'):format(t.id, tostring(ok)))
        ok, res, who = false, 'trade_failed', nil
    end
    if not ok then
        if ca > 0 then A.Functions.AddMoney('cash', ca, 'trade refund') end
        if cb > 0 then B.Functions.AddMoney('cash', cb, 'trade refund') end
        return false, res, who
    end
    if ca > 0 then B.Functions.AddMoney('cash', ca, 'trade') end
    if cb > 0 then A.Functions.AddMoney('cash', cb, 'trade') end
    return true, res
end

--- Drops offer lines whose stack is gone or smaller than offered (after a 'trade_changed').
local function pruneOffers(t)
    for _, s in ipairs({ t.a, t.b }) do
        local inv, items = t.inv[s], t.side[s].items
        for i = #items, 1, -1 do
            local l = items[i]
            local st = inv.items[l.slot]
            if not st or st ~= l.ref or st.amount < l.amount then
                table.remove(items, i)
                unlock(inv, l.slot)
            end
        end
    end
end

local function complete(t)
    local ok, res, who = Inv.WithLock(t.a, function()
        return Inv.WithLock(t.b, swap, t)
    end)
    if not ok then
        if res == 'trade_changed' then pruneOffers(t) end
        local key = (type(res) == 'string' and res:find('^trade_')) and res or 'trade_failed'
        for _, s in ipairs({ t.a, t.b }) do
            if who then Inv.Notify(s, key, 'error', nameOf(who)) else Inv.Notify(s, key, 'error') end
        end
        changed(t)
        return false, res
    end
    -- pop-ups, weapons leaving the ped
    for _, x in ipairs(res) do
        local to = other(t, x.from)
        Inv.ItemBox(x.from, x.name, x.amount, 'remove')
        Inv.ItemBox(to, x.name, x.amount, 'add')
        local def = Inv.Items[x.name]
        if def and def.type == 'weapon' then
            TriggerClientEvent('MULTIinventory:client:weaponRemoved', x.from, x.name, x.info and x.info.serie)
        end
    end
    -- locks go with the trade (the slots are empty or hold what is left)
    endTrade(t, 'trade_done', 'success')
    TriggerEvent('MULTIinventory:tradeDone', t.id, t.a, t.b)
    return true
end

--- src accepts (state true) or takes back the accept. Both accepted = the swap runs.
--- → true | false, err  ('wait' = a change was made less than AcceptDelayMs ago)
function Inv.TradeAccept(src, state)
    src = tonumber(src)
    local t = tradeOf(src)
    if not t then return false, 'no_trade' end
    state = state ~= false
    if state and now() - t.changedAt < Cfg.AcceptDelayMs then return false, 'wait' end
    t.side[src].accepted = state
    if state and t.side[other(t, src)].accepted then return complete(t) end
    push(t)
    return true
end

-- ------------------------------------------------------------
-- walking away, death, leaving
-- ------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(math.max(250, Cfg.CheckMs))
        local tnow = now()
        for target, r in pairs(requests) do
            if r.expires < tnow then
                requests[target] = nil
                TriggerClientEvent('MULTIinventory:client:tradeRequestGone', target, r.from)
            end
        end
        for _, t in pairs(trades) do
            local A, B = Inv.GetPlayer(t.a), Inv.GetPlayer(t.b)
            if not A or not B or ownInv(t.a) ~= t.inv[t.a] or ownInv(t.b) ~= t.inv[t.b] then
                endTrade(t, 'trade_gone')
            elseif blocked(A) or blocked(B) then
                endTrade(t, 'trade_blocked')
            elseif not near(t.a, t.b, Cfg.KeepDistance) then
                endTrade(t, 'trade_too_far')
            end
        end
    end
end)

local function left(src)
    src = tonumber(src)
    if not src then return end
    requests[src] = nil
    for target, r in pairs(requests) do
        if r.from == src then
            requests[target] = nil
            TriggerClientEvent('MULTIinventory:client:tradeRequestGone', target, src)
        end
    end
    if bySrc[src] then Inv.TradeCancel(src, 'trade_gone') end
end

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) left(src) end)
AddEventHandler('playerDropped', function() left(source) end)

-- ------------------------------------------------------------
-- what the page and the player send
-- ------------------------------------------------------------

local function notifyErr(src, err)
    local key = 'err_' .. tostring(err or 'failed')
    if not (Locales.en and Locales.en[key]) then key = 'err_failed' end
    Inv.Notify(src, key, 'error')
end

RegisterNetEvent('MULTIinventory:server:tradeRequest', function(target)
    local src = source
    if Inv.RateLimited(src, 'trade') then return end
    local ok, err = Inv.TradeRequest(src, tonumber(target))
    if not ok then notifyErr(src, err) end
end)

RegisterNetEvent('MULTIinventory:server:tradeAnswer', function(from, accept)
    local src = source
    if Inv.RateLimited(src, 'trade') then return end
    local ok, err = Inv.TradeAnswer(src, tonumber(from), accept == true)
    if not ok then notifyErr(src, err) end
end)

lib.callback.register('MULTIinventory:server:tradeItem', function(src, slot, amount)
    if Inv.RateLimited(src, 'trade') then return false, 'busy' end
    return Inv.TradeSetItem(src, slot, amount)
end)

lib.callback.register('MULTIinventory:server:tradeCash', function(src, amount)
    if Inv.RateLimited(src, 'trade') then return false, 'busy' end
    return Inv.TradeSetCash(src, amount)
end)

lib.callback.register('MULTIinventory:server:tradeAccept', function(src, state)
    if Inv.RateLimited(src, 'trade') then return false, 'busy' end
    return Inv.TradeAccept(src, state ~= false)
end)

RegisterNetEvent('MULTIinventory:server:tradeCancel', function()
    Inv.TradeCancel(source, 'trade_cancelled')
end)

-- ------------------------------------------------------------
-- self-test hook (only with  setr multicore_selftest true): pretend players have no ped,
-- so the test gives them positions. Never active on a live server.
-- ------------------------------------------------------------
if GetConvar('multicore_selftest', 'false') == 'true' then
    local fake = {}
    local real = Inv.PlayerCoords
    Inv.PlayerCoords = function(src)
        local c = fake[tonumber(src) or -1]
        if c then return c end
        return real(src)
    end
    exports('_TestSetCoords', function(src, x, y, z)
        src = tonumber(src)
        if not src then return false end
        fake[src] = x and vector3(x + 0.0, y + 0.0, z + 0.0) or nil
        return true
    end)
end
