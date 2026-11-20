-- ============================================================
-- MULTIbank :: server
-- Every money change happens here, through MULTIcore's player
-- money functions (Player.Functions.AddMoney / RemoveMoney).
-- The only direct `players` write is the offline transfer credit,
-- a single atomic JSON update of players.money (see creditOffline).
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local sessions = {}   -- [src] = bank index the player has open
local busy = {}       -- [src] = true while an action is running
local calls = {}      -- [src] = { timestamps } for the spam guard
local society = {}    -- [name] = balance (rsg-banking compatible society accounts)

local function dbg(...)
    if Config.Debug then print('[MULTIbank]', ...) end
end

---------------------------------
-- tables
---------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multicore_bank_log` (
          `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
          `citizenid` VARCHAR(50) NOT NULL,
          `kind` VARCHAR(24) NOT NULL,
          `amount` DECIMAL(14,2) NOT NULL,
          `balance_after` DECIMAL(14,2) DEFAULT NULL,
          `other` VARCHAR(120) DEFAULT NULL,
          `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `citizenid_id` (`citizenid`, `id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multicore_bank_accounts` (
          `name` VARCHAR(50) NOT NULL,
          `balance` DECIMAL(14,2) NOT NULL DEFAULT 0,
          PRIMARY KEY (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    local days = tonumber(Config.History.KeepDays) or 0
    if days > 0 then
        MySQL.update.await('DELETE FROM `multicore_bank_log` WHERE `created` < (NOW() - INTERVAL ? DAY)', { math.floor(days) })
    end
    local rows = MySQL.query.await('SELECT `name`, `balance` FROM `multicore_bank_accounts`') or {}
    for _, r in ipairs(rows) do society[r.name] = tonumber(r.balance) or 0 end
end)

---------------------------------
-- helpers
---------------------------------
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end
local function fmt(n) return ('%.2f'):format(n or 0) end

-- Parses a client amount: a plain number (or numeric string), finite, at least
-- Config.MinAmount, at most `max`, rounded to cents. Returns nil when invalid.
local function parseAmount(v, max)
    if type(v) == 'string' then
        if #v > 16 or not v:match('^%s*%d+%.?%d*%s*$') then return nil end
        v = tonumber(v)
    end
    if type(v) ~= 'number' or v ~= v or v == math.huge or v == -math.huge then return nil end
    v = round2(v)
    if v < (Config.MinAmount or 0.01) then return nil end
    if v > Config.HardCap then return nil, 'max' end
    if max and v > max then return nil, 'max' end
    return v
end

local function notify(src, msg, kind)
    exports.MULTIcore:Notify(src, { text = msg, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end

local function charName(charinfo)
    if type(charinfo) == 'string' then charinfo = json.decode(charinfo) end
    if type(charinfo) ~= 'table' then return _L('unknown') end
    return ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '')
end

local function shortName(charinfo)
    if type(charinfo) == 'string' then charinfo = json.decode(charinfo) end
    if type(charinfo) ~= 'table' then return _L('unknown') end
    local last = tostring(charinfo.lastname or '')
    return ('%s %s.'):format(charinfo.firstname or '?', last:sub(1, 1))
end

-- money types MULTIbank may move: 'bank' plus every bank's own moneytype that
-- exists in MULTIcore's money config
local allowedAccounts = { bank = true }
for _, b in ipairs(Config.Banks) do
    if b.moneytype and RSGCore.Config.Money.MoneyTypes[b.moneytype] ~= nil then
        allowedAccounts[b.moneytype] = true
    end
end

local function accountFor(bank)
    if Config.SeparateTownAccounts and bank.moneytype and allowedAccounts[bank.moneytype] then
        return bank.moneytype
    end
    return 'bank'
end

local function log(citizenid, kind, amount, after, other)
    MySQL.insert('INSERT INTO `multicore_bank_log` (`citizenid`, `kind`, `amount`, `balance_after`, `other`) VALUES (?, ?, ?, ?, ?)',
        { citizenid, kind, amount, after, other and tostring(other):sub(1, 120) or nil })
end

local function rateLimited(src)
    local now = GetGameTimer()
    local list = calls[src] or {}
    local keep = {}
    for _, t in ipairs(list) do
        if now - t < Config.RateLimit.WindowMs then keep[#keep + 1] = t end
    end
    if #keep >= Config.RateLimit.Calls then
        calls[src] = keep
        return true
    end
    keep[#keep + 1] = now
    calls[src] = keep
    return false
end

-- the player's position (nil without a ped); the self-test gives its pretend players one
local testCoords = {}
local function playerPos(src)
    if testCoords[src] then return testCoords[src] end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function nearBank(src, idx)
    local bank = Config.Banks[idx]
    if not bank then return false end
    if not Config.ServerDistanceCheck then return true end
    local pos = playerPos(src)
    if not pos then return false end
    return #(pos - bank.coords) <= Config.MaxUseDistance
end

local function updateClient(src, Player, account)
    -- rsg-banking's own event, for HUDs that listen to it
    TriggerClientEvent('rsg-banking:client:UpdateBanking', src, Player.Functions.GetMoney(account), account)
end

---------------------------------
-- state sent to the passbook
---------------------------------
local function history(citizenid)
    local rows = MySQL.query.await(
        'SELECT `kind`, `amount`, `balance_after`, `other`, UNIX_TIMESTAMP(`created`) AS `t` FROM `multicore_bank_log` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?',
        { citizenid, math.floor(Config.History.Rows) }) or {}
    for _, r in ipairs(rows) do
        r.amount = tonumber(r.amount) or 0
        r.balance_after = tonumber(r.balance_after)
        r.t = tonumber(r.t) or 0
    end
    return rows
end

local function buildState(Player, idx)
    local bank = Config.Banks[idx]
    local account = accountFor(bank)
    local d = Player.PlayerData
    return {
        bank = _L(bank.label),
        account = account,
        holder = charName(d.charinfo),
        citizenid = d.citizenid,
        charId = d.id,
        cash = Player.Functions.GetMoney('cash') or 0,
        balance = Player.Functions.GetMoney(account) or 0,
        gold = Player.Functions.GetMoney('gold') or 0,
        goldEnabled = Config.Gold.Enabled,
        goldBuy = Config.Gold.BuyPrice,
        goldSell = Config.Gold.SellPrice,
        goldPayWith = Config.Gold.PayWith == 'bank' and 'bank' or 'cash',
        goldMax = Config.Gold.MaxPerTrade,
        transferEnabled = Config.Transfer.Enabled,
        maxDeposit = Config.MaxDeposit,
        maxWithdraw = Config.MaxWithdraw,
        maxTransfer = Config.MaxTransfer,
        withdrawFee = Config.WithdrawFeePercent,
        transferFee = Config.TransferFeePercent,
        safeDeposit = Config.SafeDeposit.Enabled == true,
        moneyClip = Config.MoneyClip.Enabled == true,
        clipMax = Config.MoneyClip.Max,
        clipFrom = Config.MoneyClip.From == 'bank' and 'bank' or 'cash',
        history = history(d.citizenid),
    }
end

---------------------------------
-- recipients
---------------------------------
-- Finds a character by players.id (digits) or citizenid. Returns the row or nil.
local function findCharacter(target)
    if type(target) ~= 'string' and type(target) ~= 'number' then return nil end
    target = tostring(target):gsub('^%s+', ''):gsub('%s+$', '')
    if target:match('^%d+$') and #target <= 10 then
        return MySQL.single.await('SELECT `id`, `citizenid`, `charinfo` FROM `players` WHERE `id` = ? LIMIT 1', { tonumber(target) })
    elseif target:match('^[%w]+$') and #target <= 50 then
        return MySQL.single.await('SELECT `id`, `citizenid`, `charinfo` FROM `players` WHERE `citizenid` = ? LIMIT 1', { target })
    end
    return nil
end

-- Adds money to an offline character in one atomic statement, so nothing else
-- in players.money is touched. Returns the new balance or nil.
local function creditOffline(citizenid, account, amount)
    if not allowedAccounts[account] then return nil end
    local path = '$.' .. account
    local affected = MySQL.update.await(
        'UPDATE `players` SET `money` = JSON_SET(`money`, ?, ROUND(COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(`money`, ?)) AS DECIMAL(16,2)), 0) + ?, 2)) WHERE `citizenid` = ? AND JSON_VALID(`money`)',
        { path, path, amount, citizenid })
    if not affected or affected < 1 then return nil end
    local after = MySQL.scalar.await(
        'SELECT CAST(JSON_UNQUOTE(JSON_EXTRACT(`money`, ?)) AS DECIMAL(16,2)) FROM `players` WHERE `citizenid` = ?',
        { path, citizenid })
    return tonumber(after) or 0
end

---------------------------------
-- actions
---------------------------------
local Actions = {}

function Actions.deposit(src, Player, idx, data)
    local amount, why = parseAmount(data.amount, Config.MaxDeposit)
    if not amount then return false, why == 'max' and _L('too_much', fmt(Config.MaxDeposit)) or _L('bad_amount') end
    local account = accountFor(Config.Banks[idx])
    if (Player.Functions.GetMoney('cash') or 0) < amount then return false, _L('no_cash') end
    if not Player.Functions.RemoveMoney('cash', amount, 'bank-deposit') then return false, _L('no_cash') end
    if not Player.Functions.AddMoney(account, amount, 'bank-deposit') then
        Player.Functions.AddMoney('cash', amount, 'bank-deposit-refund')
        return false, _L('failed')
    end
    log(Player.PlayerData.citizenid, 'deposit', amount, Player.Functions.GetMoney(account), _L(Config.Banks[idx].label))
    updateClient(src, Player, account)
    return true, _L('deposited', fmt(amount))
end

function Actions.withdraw(src, Player, idx, data)
    local amount, why = parseAmount(data.amount, Config.MaxWithdraw)
    if not amount then return false, why == 'max' and _L('too_much', fmt(Config.MaxWithdraw)) or _L('bad_amount') end
    local account = accountFor(Config.Banks[idx])
    local fee = round2(amount * (tonumber(Config.WithdrawFeePercent) or 0) / 100)
    local total = round2(amount + fee)
    if (Player.Functions.GetMoney(account) or 0) < total then return false, _L('no_funds') end
    if not Player.Functions.RemoveMoney(account, total, 'bank-withdraw') then return false, _L('no_funds') end
    if not Player.Functions.AddMoney('cash', amount, 'bank-withdraw') then
        Player.Functions.AddMoney(account, total, 'bank-withdraw-refund')
        return false, _L('failed')
    end
    local other = _L(Config.Banks[idx].label)
    if fee > 0 then other = _L('note_fee', other, fmt(fee)) end
    log(Player.PlayerData.citizenid, 'withdraw', total, Player.Functions.GetMoney(account), other)
    updateClient(src, Player, account)
    return true, _L('withdrew', fmt(amount))
end

function Actions.lookup(src, Player, idx, data)
    if not Config.Transfer.Enabled then return false, _L('transfer_off') end
    local row = findCharacter(data.target)
    if not row then return false, _L('no_target') end
    if row.citizenid == Player.PlayerData.citizenid then return false, _L('self_target') end
    return true, nil, { name = shortName(row.charinfo), id = row.id }
end

function Actions.transfer(src, Player, idx, data)
    if not Config.Transfer.Enabled then return false, _L('transfer_off') end
    local amount, why = parseAmount(data.amount, Config.MaxTransfer)
    if not amount then return false, why == 'max' and _L('too_much', fmt(Config.MaxTransfer)) or _L('bad_amount') end
    local row = findCharacter(data.target)
    if not row then return false, _L('no_target') end
    -- the player may have left or switched character while the database answered
    Player = RSGCore.Functions.GetPlayer(src)
    if not Player or sessions[src] ~= idx then return false, _L('failed') end
    local me = Player.PlayerData
    if row.citizenid == me.citizenid then return false, _L('self_target') end

    local target = RSGCore.Functions.GetPlayerByCitizenId(row.citizenid)
    if not target and not Config.Transfer.AllowOffline then return false, _L('target_offline') end

    local account = accountFor(Config.Banks[idx])
    local fee = round2(amount * (tonumber(Config.TransferFeePercent) or 0) / 100)
    local total = round2(amount + fee)
    if (Player.Functions.GetMoney(account) or 0) < total then return false, _L('no_funds') end
    if not Player.Functions.RemoveMoney(account, total, 'bank-transfer') then return false, _L('no_funds') end

    local myName = charName(me.charinfo)
    local theirName = charName(row.charinfo)
    local theirAfter
    if target then
        if target.Functions.AddMoney(account, amount, 'bank-transfer') then
            theirAfter = target.Functions.GetMoney(account)
            notify(target.PlayerData.source, _L('received', fmt(amount), myName), 'success')
            updateClient(target.PlayerData.source, target, account)
        end
    else
        theirAfter = creditOffline(row.citizenid, account, amount)
        if theirAfter and RSGCore.Functions.GetPlayerByCitizenId(row.citizenid) then
            -- logged in while the update ran: their loaded copy may predate it
            print(('[MULTIbank] WARNING: offline transfer to %s raced a login; check their %s balance (+%s).'):format(row.citizenid, account, fmt(amount)))
        end
    end
    if not theirAfter then
        Player.Functions.AddMoney(account, total, 'bank-transfer-refund')
        return false, _L('failed')
    end

    local outNote = _L('note_party', theirName, row.id)
    if fee > 0 then outNote = _L('note_fee', outNote, fmt(fee)) end
    log(me.citizenid, 'transfer_out', total, Player.Functions.GetMoney(account), outNote)
    log(row.citizenid, 'transfer_in', amount, theirAfter, _L('note_party', myName, me.id or '?'))
    updateClient(src, Player, account)
    dbg(('transfer %s -> %s %s %s'):format(me.citizenid, row.citizenid, account, fmt(amount)))
    return true, _L('sent', fmt(amount), theirName)
end

local function goldAccount(idx)
    return Config.Gold.PayWith == 'bank' and accountFor(Config.Banks[idx]) or 'cash'
end

function Actions.gold_buy(src, Player, idx, data)
    if not Config.Gold.Enabled then return false, _L('gold_off') end
    local gold, why = parseAmount(data.amount, Config.Gold.MaxPerTrade)
    if not gold then return false, why == 'max' and _L('too_much', fmt(Config.Gold.MaxPerTrade)) or _L('bad_amount') end
    local cost = round2(gold * Config.Gold.BuyPrice)
    if cost <= 0 then return false, _L('bad_amount') end
    local pay = goldAccount(idx)
    if (Player.Functions.GetMoney(pay) or 0) < cost then return false, pay == 'cash' and _L('no_cash') or _L('no_funds') end
    if not Player.Functions.RemoveMoney(pay, cost, 'bank-gold-buy') then return false, _L('no_funds') end
    if not Player.Functions.AddMoney('gold', gold, 'bank-gold-buy') then
        Player.Functions.AddMoney(pay, cost, 'bank-gold-buy-refund')
        return false, _L('failed')
    end
    log(Player.PlayerData.citizenid, 'gold_buy', gold, Player.Functions.GetMoney('gold'), _L('note_gold_buy', fmt(cost), _L('acct_' .. (pay == 'cash' and 'cash' or 'bank'))))
    return true, _L('gold_bought', fmt(gold), fmt(cost))
end

function Actions.gold_sell(src, Player, idx, data)
    if not Config.Gold.Enabled then return false, _L('gold_off') end
    local gold, why = parseAmount(data.amount, Config.Gold.MaxPerTrade)
    if not gold then return false, why == 'max' and _L('too_much', fmt(Config.Gold.MaxPerTrade)) or _L('bad_amount') end
    local pay = round2(gold * Config.Gold.SellPrice)
    if pay <= 0 then return false, _L('bad_amount') end
    local into = goldAccount(idx)
    if (Player.Functions.GetMoney('gold') or 0) < gold then return false, _L('no_gold') end
    if not Player.Functions.RemoveMoney('gold', gold, 'bank-gold-sell') then return false, _L('no_gold') end
    if not Player.Functions.AddMoney(into, pay, 'bank-gold-sell') then
        Player.Functions.AddMoney('gold', gold, 'bank-gold-sell-refund')
        return false, _L('failed')
    end
    log(Player.PlayerData.citizenid, 'gold_sell', gold, Player.Functions.GetMoney('gold'), _L('note_gold_sell', fmt(pay), _L('acct_' .. (into == 'cash' and 'cash' or 'bank'))))
    return true, _L('gold_sold', fmt(gold), fmt(pay))
end

-- cash (or the account, Config.MoneyClip.From) folded into a money clip item (server/safedeposit.lua)
function Actions.money_clip(src, Player, idx, data)
    return MULTIBank.MakeClip(src, Player, idx, data)
end

---------------------------------
-- callbacks for the client
---------------------------------
lib.callback.register('MULTIbank:open', function(src, idx)
    idx = tonumber(idx)
    if not idx or not Config.Banks[idx] then return false end
    if rateLimited(src) then return false, _L('busy') end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    if not nearBank(src, idx) then return false, _L('too_far') end
    sessions[src] = idx
    return true, buildState(Player, idx)
end)

lib.callback.register('MULTIbank:close', function(src)
    sessions[src] = nil
    return true
end)

lib.callback.register('MULTIbank:action', function(src, action, data)
    if type(action) ~= 'string' or not Actions[action] or type(data) ~= 'table' then return { ok = false, msg = _L('failed') } end
    local idx = sessions[src]
    if not idx then return { ok = false, msg = _L('failed') } end
    if rateLimited(src) or busy[src] then return { ok = false, msg = _L('busy') } end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return { ok = false, msg = _L('failed') } end
    if not nearBank(src, idx) then
        sessions[src] = nil
        return { ok = false, msg = _L('too_far'), close = true }
    end
    busy[src] = true
    local okCall, ok, msg, extra = pcall(Actions[action], src, Player, idx, data)
    busy[src] = nil
    if not okCall then
        print(('[MULTIbank] %s failed for %s: %s'):format(action, src, tostring(ok)))
        return { ok = false, msg = _L('failed') }
    end
    dbg(action, src, ok, msg)
    Player = RSGCore.Functions.GetPlayer(src)
    local res = { ok = ok, msg = msg, extra = extra }
    if Player and action ~= 'lookup' then res.state = buildState(Player, idx) end
    return res
end)

AddEventHandler('playerDropped', function()
    local src = source
    sessions[src], busy[src], calls[src] = nil, nil, nil
end)

---------------------------------
-- exports (player bank account = 'bank')
---------------------------------
local function playerOf(src)
    return RSGCore.Functions.GetPlayer(tonumber(src) or src)
end

--- Bank balance of an online player (main 'bank' account, or `account` if given and allowed).
exports('GetBalance', function(src, account)
    local Player = playerOf(src)
    if not Player then return 0 end
    account = (type(account) == 'string' and allowedAccounts[account]) and account or 'bank'
    return Player.Functions.GetMoney(account) or 0
end)

--- Credits an online player's bank account. Returns true / false.
exports('AddBank', function(src, amount, reason)
    local Player = playerOf(src)
    amount = parseAmount(amount)
    if not Player or not amount then return false end
    if not Player.Functions.AddMoney('bank', amount, reason or 'bank-credit') then return false end
    log(Player.PlayerData.citizenid, 'credit', amount, Player.Functions.GetMoney('bank'), reason or GetInvokingResource())
    return true
end)

--- Debits an online player's bank account if it holds enough. Returns true / false.
exports('RemoveBank', function(src, amount, reason)
    local Player = playerOf(src)
    amount = parseAmount(amount)
    if not Player or not amount then return false end
    if (Player.Functions.GetMoney('bank') or 0) < amount then return false end
    if not Player.Functions.RemoveMoney('bank', amount, reason or 'bank-debit') then return false end
    log(Player.PlayerData.citizenid, 'debit', amount, Player.Functions.GetMoney('bank'), reason or GetInvokingResource())
    return true
end)

---------------------------------
-- rsg-banking compatible society accounts
-- rsg-core's paycheck code (RSGConfig.Money.PayCheckSociety) calls
-- exports['rsg-banking']:GetAccountBalance(job) and :RemoveMoney(job, amount, reason).
-- Kept in memory, written through to multicore_bank_accounts.
---------------------------------
local function validName(name)
    return type(name) == 'string' and #name > 0 and #name <= 50 and name:match('^[%w_%-]+$') ~= nil
end

local function GetAccountBalance(name)
    if not validName(name) then return 0 end
    return society[name] or 0
end

local function AddAccountMoney(name, amount, reason)
    amount = parseAmount(amount)
    if not validName(name) or not amount then return false end
    society[name] = round2((society[name] or 0) + amount)
    MySQL.insert('INSERT INTO `multicore_bank_accounts` (`name`, `balance`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `balance` = ?',
        { name, society[name], society[name] })
    log('job:' .. name, 'credit', amount, society[name], reason or GetInvokingResource())
    return true
end

local function RemoveAccountMoney(name, amount, reason)
    amount = parseAmount(amount)
    if not validName(name) or not amount then return false end
    if (society[name] or 0) < amount then return false end
    society[name] = round2(society[name] - amount)
    MySQL.update('UPDATE `multicore_bank_accounts` SET `balance` = ? WHERE `name` = ?', { society[name], name })
    log('job:' .. name, 'debit', amount, society[name], reason or GetInvokingResource())
    return true
end

exports('GetAccountBalance', GetAccountBalance)
exports('AddAccountMoney', AddAccountMoney)
exports('RemoveAccountMoney', RemoveAccountMoney)

-- same functions under the rsg-banking resource name
local function exportAs(resourceName, exportName, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resourceName, exportName), function(setCB) setCB(fn) end)
end
exportAs('rsg-banking', 'GetAccountBalance', GetAccountBalance)
exportAs('rsg-banking', 'AddMoney', AddAccountMoney)
exportAs('rsg-banking', 'RemoveMoney', RemoveAccountMoney)

---------------------------------
-- rsg-banking compatible events
-- Same names and argument shapes as rsg-banking, so RSG v2 scripts (and an
-- rsg-banking style UI) keep working. Every call goes through the same checks
-- as the MULTIbank passbook: spam guard, amount check, limits, the player must
-- stand at a bank counter.
---------------------------------
local rsgMoneyTypes = { bank = true }
for _, b in ipairs(Config.Banks) do
    if b.moneytype then rsgMoneyTypes[b.moneytype] = true end
end

-- nearest bank within reach of the player, or nil
local function bankAt(src)
    local pos = playerPos(src)
    if not pos then return (not Config.ServerDistanceCheck) and 1 or nil end
    local best, bestDist
    for i, b in ipairs(Config.Banks) do
        local d = #(pos - b.coords)
        if d <= Config.MaxUseDistance and (not bestDist or d < bestDist) then best, bestDist = i, d end
    end
    if not best and not Config.ServerDistanceCheck then return 1 end
    return best
end

local function runCompat(src, action, data)
    if rateLimited(src) or busy[src] then notify(src, _L('busy'), 'error') return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local idx = bankAt(src)
    if not idx then notify(src, _L('too_far'), 'error') return end
    busy[src] = true
    local okCall, ok, msg = pcall(Actions[action], src, Player, idx, data)
    busy[src] = nil
    if not okCall then
        print(('[MULTIbank] rsg-banking %s failed for %s: %s'):format(action, src, tostring(ok)))
        ok, msg = false, _L('failed')
    end
    if msg then notify(src, msg, ok and 'success' or 'error') end
end

-- type 1 = withdraw, 2 = deposit, 3 = money clip (server/safedeposit.lua, Config.MoneyClip)
RegisterNetEvent('rsg-banking:server:transact', function(kind, amount, moneytype)
    local src = source
    if type(moneytype) ~= 'string' or not rsgMoneyTypes[moneytype] then
        print(('[MULTIbank] %s sent rsg-banking:server:transact with an unknown moneytype'):format(src))
        return
    end
    -- the account used is the one of the bank the player stands at (see Config.SeparateTownAccounts)
    if kind == 1 then
        runCompat(src, 'withdraw', { amount = amount })
    elseif kind == 2 then
        runCompat(src, 'deposit', { amount = amount })
    elseif kind == 3 then
        runCompat(src, 'money_clip', { amount = amount })
    end
end)

-- hand cash to another player standing close by
RegisterNetEvent('rsg-banking:server:givemoney', function(targetPlayerId, amount)
    local src = source
    if rateLimited(src) or busy[src] then notify(src, _L('busy'), 'error') return end
    local targetId = tonumber(targetPlayerId)
    local value, why = parseAmount(amount, Config.GiveCash.Max)
    if not value then
        notify(src, why == 'max' and _L('too_much', fmt(Config.GiveCash.Max)) or _L('bad_amount'), 'error')
        return
    end
    if not targetId or targetId == src then notify(src, _L('no_target'), 'error') return end
    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Player then return end
    if not Target then notify(src, _L('no_target'), 'error') return end
    local a, b = GetPlayerPed(src), GetPlayerPed(targetId)
    if Config.ServerDistanceCheck and (not a or a == 0 or not b or b == 0
        or #(GetEntityCoords(a) - GetEntityCoords(b)) > Config.GiveCash.MaxDistance) then
        notify(src, _L('too_far'), 'error')
        return
    end
    if (Player.Functions.GetMoney('cash') or 0) < value then notify(src, _L('no_cash'), 'error') return end
    busy[src] = true
    local ok = Player.Functions.RemoveMoney('cash', value, 'give-cash')
    if ok and not Target.Functions.AddMoney('cash', value, 'give-cash') then
        Player.Functions.AddMoney('cash', value, 'give-cash-refund')
        ok = false
    end
    busy[src] = nil
    if not ok then notify(src, _L('failed'), 'error') return end
    notify(src, _L('gave_cash', fmt(value), charName(Target.PlayerData.charinfo)), 'success')
    notify(targetId, _L('got_cash', charName(Player.PlayerData.charinfo), fmt(value)), 'success')
end)

-- rsg-banking's safe-deposit event (arg: town name). Opens the player's box at the bank they
-- stand at, or the rent / pay menu when there is none or the rent is due (server/safedeposit.lua).
RegisterNetEvent('rsg-banking:server:opensafedeposit', function(town)
    local src = source
    if rateLimited(src) then return end
    MULTIBank.OpenSafeDepositEvent(src, town)
end)

-- rsg-banking's balance callback: returns { bank = <balance of moneytype>, cash = <cash> }
RSGCore.Functions.CreateCallback('rsg-banking:getBankingInformation', function(src, cb, moneytype)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(moneytype) ~= 'string' or not rsgMoneyTypes[moneytype] then return cb(nil) end
    cb({ bank = Player.PlayerData.money[moneytype], cash = Player.Functions.GetMoney('cash') })
end)

---------------------------------
-- shared with server/safedeposit.lua (safe-deposit boxes, money clips)
---------------------------------
MULTIBank = {
    Core = RSGCore,
    round2 = round2,
    fmt = fmt,
    parseAmount = parseAmount,
    notify = notify,
    log = log,
    accountFor = accountFor,
    nearBank = nearBank,
    bankAt = bankAt,
    rateLimited = rateLimited,
    busy = busy,
    updateClient = updateClient,
}

-- self-test hook (only with  setr multicore_selftest true): pretend players have no ped
if GetConvar('multicore_selftest', 'false') == 'true' then
    exports('_TestSetCoords', function(src, x, y, z)
        src = tonumber(src)
        if not src then return false end
        testCoords[src] = x and vector3(x + 0.0, y + 0.0, z + 0.0) or nil
        return true
    end)
end
