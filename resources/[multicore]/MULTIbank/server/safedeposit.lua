-- ============================================================
-- MULTIbank :: safe-deposit boxes and money clips (server)
-- A box is a MULTIinventory storage 'custom:safedeposit:<citizenid>:<bank id>'
-- ('...:all' when Config.SafeDeposit.PerBank = false). The rental lives in
-- multicore_bank_boxes; items go in and out only through MULTIinventory
-- (Open / ItemCount / Delete / AddItem / RemoveItem / RegisterUsable).
-- The box is opened only by this script (MULTIinventory's Config.ServerOpenOnly
-- keeps clients from asking for it) and only at the counter.
-- GPL v3.
-- ============================================================

local MB = MULTIBank
local RSGCore = MB.Core
local SD = Config.SafeDeposit
local MC = Config.MoneyClip
local INV = 'MULTIinventory'
local DAY = 86400

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multicore_bank_boxes` (
          `citizenid` VARCHAR(50) NOT NULL,
          `bank` VARCHAR(32) NOT NULL,
          `tier` VARCHAR(24) NOT NULL,
          `paid_until` INT UNSIGNED DEFAULT NULL,
          `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`citizenid`, `bank`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

local function inv() return exports[INV] end
local function invReady() return GetResourceState(INV) == 'started' end

---------------------------------
-- boxes
---------------------------------
local function boxKey(bank) return SD.PerBank and bank.id or 'all' end
local function boxInv(citizenid, key) return ('custom:safedeposit:%s:%s'):format(citizenid, key) end

local function tierOf(id)
    for _, t in ipairs(SD.Tiers) do if t.id == id then return t end end
    return SD.Tiers[1]
end

local function monthly() return SD.Billing ~= 'once' end
local function period() return math.max(1, tonumber(SD.PeriodDays) or 30) * DAY end

local function getBox(citizenid, key)
    return MySQL.single.await('SELECT `tier`, `paid_until` FROM `multicore_bank_boxes` WHERE `citizenid` = ? AND `bank` = ?', { citizenid, key })
end

-- dollars owed now (0 when paid), and how many periods that is
local function owed(row, tier)
    if not monthly() or not row.paid_until then return 0, 0 end
    local late = os.time() - tonumber(row.paid_until)
    if late < 0 then return 0, 0 end
    local n = math.floor(late / period()) + 1
    return MB.round2(n * tier.fee), n
end

local function payAccount(idx)
    return SD.PayWith == 'cash' and 'cash' or MB.accountFor(Config.Banks[idx])
end

local function charge(src, Player, idx, amount, kind, note)
    local acct = payAccount(idx)
    if (Player.Functions.GetMoney(acct) or 0) < amount then return false, acct == 'cash' and _L('no_cash') or _L('no_funds') end
    if not Player.Functions.RemoveMoney(acct, amount, 'bank-' .. kind) then return false, _L('no_funds') end
    MB.log(Player.PlayerData.citizenid, kind, amount, acct ~= 'cash' and Player.Functions.GetMoney(acct) or nil, note)
    if acct ~= 'cash' then MB.updateClient(src, Player, acct) end
    return true
end

local function boxLabel(bank)
    return SD.PerBank and _L('sd_label', _L(bank.label)) or _L('sd_label_all')
end

--- What the rent / box menu shows.
local function info(src, idx)
    local Player = RSGCore.Functions.GetPlayer(src)
    local bank = Config.Banks[idx]
    if not Player or not bank then return { ok = false, msg = _L('failed') } end
    local out = {
        ok = true,
        bank = _L(bank.label),
        billing = monthly() and 'monthly' or 'once',
        periodDays = tonumber(SD.PeriodDays) or 30,
        payWith = SD.PayWith == 'cash' and 'cash' or 'bank',
        tiers = {},
    }
    for _, t in ipairs(SD.Tiers) do
        out.tiers[#out.tiers + 1] = { id = t.id, label = _L(t.label), slots = t.slots, weight = t.weight, price = t.price, fee = t.fee }
    end
    local row = getBox(Player.PlayerData.citizenid, boxKey(bank))
    if row then
        local tier = tierOf(row.tier)
        local due, periods = owed(row, tier)
        local left = row.paid_until and math.floor((tonumber(row.paid_until) - os.time()) / DAY) or nil
        out.box = {
            tier = tier.id, label = _L(tier.label), slots = tier.slots, weight = tier.weight, fee = tier.fee,
            overdue = due > 0, owed = due, periods = periods, daysLeft = left,
            canPrepay = monthly() and due == 0 and row.paid_until ~= nil
                and (tonumber(row.paid_until) - os.time()) < (SD.MaxPrepaid * period()),
        }
    end
    return out
end

local function checkAt(src, idx)
    if not SD.Enabled then return nil, _L('sd_off') end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not Config.Banks[idx] then return nil, _L('failed') end
    if not MB.nearBank(src, idx) then return nil, _L('too_far') end
    if not invReady() then return nil, _L('failed') end
    return Player
end

--- Rents a box of tier `tierId` at bank idx. → ok, msg
local function rent(src, idx, tierId)
    local Player, err = checkAt(src, idx)
    if not Player then return false, err end
    local tier
    for _, t in ipairs(SD.Tiers) do if t.id == tierId then tier = t end end
    if not tier then return false, _L('failed') end
    local bank = Config.Banks[idx]
    local cid, key = Player.PlayerData.citizenid, boxKey(bank)
    if getBox(cid, key) then return false, _L('sd_have') end
    local cost = MB.round2(monthly() and tier.fee or tier.price)
    local ok, why = charge(src, Player, idx, cost, 'box_rent', _L(tier.label))
    if not ok then return false, why end
    local untilTs = monthly() and (os.time() + period()) or nil
    local inserted = MySQL.insert.await('INSERT IGNORE INTO `multicore_bank_boxes` (`citizenid`, `bank`, `tier`, `paid_until`) VALUES (?, ?, ?, ?)',
        { cid, key, tier.id, untilTs })
    if not getBox(cid, key) then
        Player.Functions.AddMoney(payAccount(idx), cost, 'bank-box-refund')
        print(('[MULTIbank] box rent for %s failed (%s)'):format(cid, tostring(inserted)))
        return false, _L('failed')
    end
    return true, _L('sd_rented', _L(tier.label), MB.fmt(cost))
end

--- Pays the rent owed, or one period ahead. → ok, msg
local function pay(src, idx)
    local Player, err = checkAt(src, idx)
    if not Player then return false, err end
    if not monthly() then return false, _L('sd_paid_for_good') end
    local bank = Config.Banks[idx]
    local cid, key = Player.PlayerData.citizenid, boxKey(bank)
    local row = getBox(cid, key)
    if not row then return false, _L('sd_none') end
    local tier = tierOf(row.tier)
    local due, n = owed(row, tier)
    local paidUntil = tonumber(row.paid_until) or os.time()
    if due == 0 then
        if paidUntil - os.time() >= SD.MaxPrepaid * period() then return false, _L('sd_prepaid_max') end
        due, n = MB.round2(tier.fee), 1
    end
    local ok, why = charge(src, Player, idx, due, 'box_fee', _L(tier.label))
    if not ok then return false, why end
    MySQL.update.await('UPDATE `multicore_bank_boxes` SET `paid_until` = ? WHERE `citizenid` = ? AND `bank` = ?',
        { paidUntil + n * period(), cid, key })
    return true, _L('sd_paid', MB.fmt(due))
end

--- Opens the box (the satchel next to it). → ok, msg
local function open(src, idx)
    local Player, err = checkAt(src, idx)
    if not Player then return false, err end
    local bank = Config.Banks[idx]
    local cid, key = Player.PlayerData.citizenid, boxKey(bank)
    local row = getBox(cid, key)
    if not row then return false, _L('sd_none') end
    local tier = tierOf(row.tier)
    local due = owed(row, tier)
    if due > 0 then return false, _L('sd_overdue', MB.fmt(due)) end
    local c = bank.coords
    local ok, why = inv():Open(src, {
        id = boxInv(cid, key),
        label = boxLabel(bank),
        slots = tier.slots,
        maxWeight = tier.weight,
        coords = { x = c.x, y = c.y, z = c.z },
        reach = Config.MaxUseDistance,
    })
    if not ok then return false, why == 'in_use' and _L('sd_in_use') or _L('failed') end
    return true
end

--- Gives the box up (only when empty). → ok, msg
local function giveUp(src, idx)
    local Player, err = checkAt(src, idx)
    if not Player then return false, err end
    local bank = Config.Banks[idx]
    local cid, key = Player.PlayerData.citizenid, boxKey(bank)
    if not getBox(cid, key) then return false, _L('sd_none') end
    local id = boxInv(cid, key)
    if (inv():ItemCount(id, {}) or 0) > 0 then return false, _L('sd_not_empty') end
    inv():Delete(id)
    MySQL.update.await('DELETE FROM `multicore_bank_boxes` WHERE `citizenid` = ? AND `bank` = ?', { cid, key })
    return true, _L('sd_given_up')
end

local Calls = { info = info, rent = rent, pay = pay, open = open, giveup = giveUp }

--- One box action with the spam guard and one-at-a-time rule. → { ok, msg, ... }
local function run(src, action, idx, arg)
    idx = tonumber(idx)
    if not Calls[action] or not idx or not Config.Banks[idx] then return { ok = false, msg = _L('failed') } end
    if action ~= 'info' and (MB.rateLimited(src) or MB.busy[src]) then return { ok = false, msg = _L('busy') } end
    if action == 'info' then
        if not SD.Enabled then return { ok = false, msg = _L('sd_off') } end
        if not MB.nearBank(src, idx) then return { ok = false, msg = _L('too_far') } end
        return info(src, idx)
    end
    MB.busy[src] = true
    local okCall, ok, msg = pcall(Calls[action], src, idx, arg)
    MB.busy[src] = nil
    if not okCall then
        print(('[MULTIbank] safe-deposit %s failed for %s: %s'):format(action, src, tostring(ok)))
        return { ok = false, msg = _L('failed') }
    end
    return { ok = ok == true, msg = msg }
end

lib.callback.register('MULTIbank:sd', function(src, action, idx, arg)
    if type(action) ~= 'string' then return { ok = false, msg = _L('failed') } end
    return run(src, action, idx, arg)
end)

--- rsg-banking:server:opensafedeposit (town): open the box, or the menu when there is
--- none yet or the rent is due.
function MULTIBank.OpenSafeDepositEvent(src, town)
    if not SD.Enabled then return MB.notify(src, _L('sd_off'), 'error') end
    local idx = MB.bankAt(src)
    if type(town) == 'string' then
        for i, b in ipairs(Config.Banks) do
            if b.town == town then
                if MB.nearBank(src, i) then idx = i end
                break
            end
        end
    end
    if not idx then return MB.notify(src, _L('too_far'), 'error') end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local row = getBox(Player.PlayerData.citizenid, boxKey(Config.Banks[idx]))
    if row and owed(row, tierOf(row.tier)) == 0 then
        local res = run(src, 'open', idx)
        if not res.ok and res.msg then MB.notify(src, res.msg, 'error') end
        return res.ok
    end
    TriggerClientEvent('MULTIbank:client:safedeposit', src, idx)
    return false
end

-- a deleted character's boxes go with it
AddEventHandler('MULTIcore:characterDeleted', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    local rows = MySQL.query.await('SELECT `bank` FROM `multicore_bank_boxes` WHERE `citizenid` = ?', { citizenid }) or {}
    for _, r in ipairs(rows) do
        if invReady() then inv():Delete(boxInv(citizenid, r.bank)) end
    end
    MySQL.update.await('DELETE FROM `multicore_bank_boxes` WHERE `citizenid` = ?', { citizenid })
end)

---------------------------------
-- money clips
---------------------------------
--- Passbook action 'money_clip' and rsg-banking transact type 3. → ok, msg
function MULTIBank.MakeClip(src, Player, idx, data)
    if not MC.Enabled then return false, _L('clip_off') end
    if not invReady() then return false, _L('failed') end
    local amount, why = MB.parseAmount(data.amount, MC.Max)
    if not amount then return false, why == 'max' and _L('too_much', MB.fmt(MC.Max)) or _L('bad_amount') end
    local from = MC.From == 'bank' and MB.accountFor(Config.Banks[idx]) or 'cash'
    if (Player.Functions.GetMoney(from) or 0) < amount then return false, from == 'cash' and _L('no_cash') or _L('no_funds') end
    local invId = inv():PlayerInv(src)
    local info = { money = amount }
    if not invId or not inv():CanAdd(invId, MC.Item, 1, info) then return false, _L('clip_no_room') end
    if not Player.Functions.RemoveMoney(from, amount, 'bank-money_clip') then return false, _L('no_funds') end
    if not inv():AddItem(invId, MC.Item, 1, info, nil, 'money clip') then
        Player.Functions.AddMoney(from, amount, 'bank-money_clip-refund')
        return false, _L('clip_no_room')
    end
    MB.log(Player.PlayerData.citizenid, 'money_clip', amount, from ~= 'cash' and Player.Functions.GetMoney(from) or nil, _L('acct_' .. (from == 'cash' and 'cash' or 'bank')))
    if from ~= 'cash' then MB.updateClient(src, Player, from) end
    return true, _L('clip_made', MB.fmt(amount))
end

-- using a clip anywhere unfolds the cash
local function useClip(src, stack, invId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(stack) ~= 'table' then return end
    local amount = MB.round2(tonumber(stack.info and stack.info.money) or 0)
    local match = { money = stack.info and stack.info.money }
    if not inv():RemoveItem(invId, MC.Item, 1, stack.slot, match, 'money clip opened') then return end
    if amount > 0 then Player.Functions.AddMoney('cash', amount, 'money-clip') end
    MB.notify(src, _L('clip_opened', MB.fmt(amount)), 'success')
end

local function registerClip()
    if not MC.Enabled or not invReady() then return end
    local I = inv()
    if not I:GetItemDef(MC.Item) then
        I:RegisterItem({
            name = MC.Item, label = _L('clip_label'), weight = 0, type = 'item', image = MC.Item .. '.png',
            unique = true, useable = true, shouldClose = true, description = _L('clip_desc'),
        })
    end
    I:RegisterUsable(MC.Item, useClip)
end

CreateThread(function()
    local t = 0
    while not (invReady() and inv():IsReady()) and t < 600 do Wait(100) t = t + 1 end
    registerClip()
end)
AddEventHandler('MULTIinventory:ready', registerClip)

---------------------------------
-- self-test hooks (only with  setr multicore_selftest true)
---------------------------------
if GetConvar('multicore_selftest', 'false') == 'true' then
    -- the same path the client's box menu takes (lib.callback 'MULTIbank:sd')
    exports('_TestSafeDeposit', function(src, action, idx, arg) return run(tonumber(src), action, idx, arg) end)
    -- the same path rsg-banking:server:opensafedeposit takes
    exports('_TestOpenSafeDepositEvent', function(src, town) return MULTIBank.OpenSafeDepositEvent(tonumber(src), town) end)
    -- the money-clip passbook action / rsg-banking transact type 3
    exports('_TestMakeClip', function(src, idx, amount)
        local Player = RSGCore.Functions.GetPlayer(tonumber(src))
        if not Player then return false end
        return MULTIBank.MakeClip(tonumber(src), Player, tonumber(idx), { amount = amount })
    end)
end
