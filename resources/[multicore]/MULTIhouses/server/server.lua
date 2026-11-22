-- ============================================================
-- MULTIhouses :: server
-- Buying, the balance, land tax credit, guest keys, the house stash,
-- outfits, door locks and break-ins. Every action is checked here:
-- the player exists, owns or holds a key for the house, stands near it
-- where it matters, and has the money. Amounts from the client are
-- only taken after they pass the checks.
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- ============================================================

local Core = exports.MULTIcore:GetCoreObject()

H = {
    Owned = {},          -- [houseid] = { owner = fullname, citizenid = cid }
    Prices = {},         -- [houseid] = price
    Doors = {},          -- [doorid number] = 1 locked / 0 open (saved state)
    Picks = {},          -- [src] = { houseid, doorid, startedAt } a lockpicking attempt in progress
    Robberies = {},      -- [houseid] = { robber = cid, src, doorid, startedAt }
    RobberyDoors = {},   -- [doorid] = { houseid, unlockedAt }
    HouseCooldowns = {}, -- [houseid] = os.time() when it may be broken into again
    PlayerCooldowns = {},-- [cid] = os.time() when this player may break in again
    TestCoords = {},     -- [src] = vector3 (self-test only: pretend players have no ped)
    ready = false,
}

local SELFTEST = GetConvar('multicore_selftest', 'false') == 'true'

local HouseCfg = {}      -- [houseid] = Config.Houses entry
local DoorCfg = {}       -- [doorid] = Config.HouseDoors entry
local HouseDoorIds = {}  -- [houseid] = { doorid, ... }

for _, h in ipairs(Config.Houses) do
    HouseCfg[h.houseid] = h
    HouseDoorIds[h.houseid] = HouseDoorIds[h.houseid] or {}
end
for _, d in ipairs(Config.HouseDoors) do
    DoorCfg[d.doorid] = d
    HouseDoorIds[d.houseid] = HouseDoorIds[d.houseid] or {}
    table.insert(HouseDoorIds[d.houseid], d.doorid)
end

local function dbg(...)
    if Config.Debug then print('[MULTIhouses]', ...) end
end

---------------------------------
-- helpers
---------------------------------
local function getP(src)
    src = tonumber(src)
    return src and Core.Functions.GetPlayer(src) or nil
end

-- oxmysql hands TINYINT(1) columns back as true / false
local function flag(v) return v == true or tonumber(v) == 1 end

local function cidOf(P) return P and P.PlayerData and P.PlayerData.citizenid or nil end

local function fullName(P)
    local ci = P.PlayerData.charinfo or {}
    local name = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

--- The name players see for a house ("House 12" or its own label).
function H.HouseName(houseid)
    local h = HouseCfg[houseid]
    if h and h.label and h.label ~= '' then return h.label end
    local n = tostring(houseid or ''):match('(%d+)$')
    return n and _L('house_name', n) or tostring(houseid)
end

local function notify(src, ntype, key, ...)
    local text = _L(key, ...)
    if not src or src == 0 then
        print('[MULTIhouses] ' .. text)
        return
    end
    pcall(function()
        exports.MULTIcore:Notify(src, { title = _L('notify_title'), text = text, type = ntype })
    end)
end

local function log(titleKey, color, message)
    if not Config.LogName or Config.LogName == '' then return end
    if GetResourceState('MULTIserver') ~= 'started' then return end
    pcall(function() exports.MULTIserver:Log(Config.LogName, _L(titleKey), color, message) end)
end

local function telegram(citizenid, subjectKey, message)
    if GetResourceState('MULTItelegram') ~= 'started' then return end
    pcall(function()
        exports.MULTItelegram:SendTelegram(citizenid, _L('telegram_sender'), _L(subjectKey), message)
    end)
end

local function int(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.floor(n)
end

local function validHouse(houseid)
    return type(houseid) == 'string' and HouseCfg[houseid] ~= nil
end

local function position(src)
    if H.TestCoords[src] then return H.TestCoords[src] end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function near(src, coords, dist)
    if not dist or dist <= 0 then return true end
    local p = position(src)
    if not p then return false end
    return #(p - vector3(coords.x, coords.y, coords.z)) <= dist
end

local function nearHouse(src, houseid)
    return near(src, HouseCfg[houseid].menucoords, Config.ServerDistance)
end

local function houseRow(houseid)
    return MySQL.single.await('SELECT * FROM `multi_houses` WHERE `houseid` = ?', { houseid })
end

--- 'owner', 'guest' or nil
local function keyOf(citizenid, houseid)
    if not citizenid then return nil end
    local row = MySQL.single.await('SELECT `guest` FROM `multi_housekeys` WHERE `citizenid` = ? AND `houseid` = ?', { citizenid, houseid })
    if not row then return nil end
    return flag(row.guest) and 'guest' or 'owner'
end

local function isOwner(citizenid, row)
    return row and flag(row.owned) and row.citizenid == citizenid
end

local function money(P)
    return tonumber((P.PlayerData.money or {})[Config.Currency]) or 0
end

local function takeMoney(P, amount, reason)
    if amount <= 0 then return true end
    if money(P) < amount then return false end
    return P.Functions.RemoveMoney(Config.Currency, amount, reason) ~= false
end

local function giveMoney(P, amount, reason)
    if amount <= 0 then return true end
    return P.Functions.AddMoney(Config.Currency, amount, reason) ~= false
end

local function isAdmin(src)
    if src == 0 then return true end
    local ok, res = pcall(function() return Core.Functions.HasPermission(src, Config.AdminPermission) end)
    return ok and res == true
end

--- MULTIinventory id of a house stash.
function H.StashId(houseid)
    return 'stash:house_' .. tostring(houseid)
end

---------------------------------
-- sync to clients
---------------------------------
function H.SyncOwned(target)
    TriggerClientEvent('MULTIhouses:client:owned', target or -1, H.Owned)
end

--- The state a door is in for players: open while its house is for sale or broken into.
function H.DoorState(doorid)
    local d = DoorCfg[doorid]
    if d and not H.Owned[d.houseid] then return 0 end
    if H.RobberyDoors[doorid] then return 0 end
    return H.Doors[doorid] or 1
end

function H.DoorStates()
    local out = {}
    for doorid in pairs(DoorCfg) do out[#out + 1] = { doorid = doorid, state = H.DoorState(doorid) } end
    return out
end

local function broadcastDoor(doorid)
    TriggerClientEvent('MULTIhouses:client:door', -1, doorid, H.DoorState(doorid))
end

local function saveDoor(doorid, state)
    H.Doors[doorid] = state
    MySQL.update.await('UPDATE `multi_housedoors` SET `doorstate` = ? WHERE `doorid` = ?', { state, tostring(doorid) })
    broadcastDoor(doorid)
end

local function setHouseDoors(houseid, state)
    for _, doorid in ipairs(HouseDoorIds[houseid] or {}) do saveDoor(doorid, state) end
end

--- Tells a player's client its keys changed (guest added / removed, house bought / lost).
local function keysChanged(citizenid)
    local P = citizenid and Core.Functions.GetPlayerByCitizenId(citizenid)
    if P then TriggerClientEvent('MULTIhouses:client:keysChanged', P.PlayerData.source) end
end

local function keysOf(citizenid)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT `houseid`, `guest` FROM `multi_housekeys` WHERE `citizenid` = ?', { citizenid }) or {}) do
        out[r.houseid] = flag(r.guest) and 'guest' or 'owner'
    end
    return out
end

---------------------------------
-- a house back on the market (sold, released, taken back, removed by an admin)
---------------------------------
function H.ClearHouse(houseid)
    local holders = MySQL.query.await('SELECT `citizenid` FROM `multi_housekeys` WHERE `houseid` = ?', { houseid }) or {}
    MySQL.update.await('DELETE FROM `multi_housekeys` WHERE `houseid` = ?', { houseid })
    MySQL.update.await('UPDATE `multi_houses` SET `citizenid` = ?, `fullname` = ?, `owned` = 0, `credit` = 0, `balance` = 0, `bought_at` = 0 WHERE `houseid` = ?',
        { '', '', houseid })
    if Config.PurgeStorage and GetResourceState('MULTIinventory') == 'started' then
        pcall(function()
            local MI = exports.MULTIinventory
            if MI:Exists(H.StashId(houseid)) then MI:Delete(H.StashId(houseid)) end
        end)
    end
    H.Owned[houseid] = nil
    H.SyncOwned()
    setHouseDoors(houseid, 0)
    for _, k in ipairs(holders) do keysChanged(k.citizenid) end
end

---------------------------------
-- buying
---------------------------------
function H.BuyInfo(houseid)
    local price = H.Prices[houseid] or 0
    local deposit = math.ceil(price * (Config.DepositPercent / 100))
    return {
        price = price,
        deposit = deposit,
        balance = price - deposit,
        sellprice = math.floor(price * Config.SellBack),
        tax = Config.BillingEnabled and Config.LandTaxPerCycle or 0,
    }
end

function H.Buy(src, houseid)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    local cid = cidOf(P)
    local row = houseRow(houseid)
    if not row then return false, 'no_house' end
    if flag(row.owned) then notify(src, 'error', 'already_owned') return false, 'already_owned' end
    local price = tonumber(row.price) or 0
    if price <= 0 then notify(src, 'error', 'not_for_sale') return false, 'not_for_sale' end
    local have = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `multi_houses` WHERE `citizenid` = ? AND `owned` = 1', { cid })) or 0
    if have >= (Config.MaxHousesPerPlayer or 1) then notify(src, 'error', 'already_have') return false, 'already_have' end

    local deposit = math.ceil(price * (Config.DepositPercent / 100))
    local balance = price - deposit
    if money(P) < deposit then notify(src, 'error', 'need_deposit', deposit) return false, 'no_money' end
    if not takeMoney(P, deposit, 'house-deposit') then notify(src, 'error', 'need_deposit', deposit) return false, 'no_money' end

    local name = fullName(P)
    -- owned = 0 in the WHERE: two buyers at once, only one gets it
    local changed = MySQL.update.await('UPDATE `multi_houses` SET `citizenid` = ?, `fullname` = ?, `owned` = 1, `credit` = ?, `balance` = ?, `bought_at` = ? WHERE `houseid` = ? AND `owned` = 0',
        { cid, name, Config.StartCredit, balance, os.time(), houseid })
    if not changed or changed == 0 then
        giveMoney(P, deposit, 'house-deposit-refund')
        notify(src, 'error', 'already_owned')
        return false, 'already_owned'
    end
    MySQL.update.await('DELETE FROM `multi_housekeys` WHERE `houseid` = ?', { houseid })
    MySQL.insert.await('INSERT INTO `multi_housekeys` (`citizenid`, `houseid`, `guest`) VALUES (?, ?, 0)', { cid, houseid })

    H.Owned[houseid] = { owner = name, citizenid = cid }
    H.SyncOwned()
    setHouseDoors(houseid, 1)
    keysChanged(cid)

    if balance > 0 then
        notify(src, 'success', 'bought_with_balance', deposit, balance)
    else
        notify(src, 'success', 'bought')
    end
    log('log_bought_title', 'green', _L('log_bought', name, cid, H.HouseName(houseid), price, deposit))
    return true
end

---------------------------------
-- the balance
---------------------------------
function H.PayBalance(src, houseid, amount)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    local cid = cidOf(P)
    local row = houseRow(houseid)
    if not isOwner(cid, row) then notify(src, 'error', 'not_owner') return false, 'not_owner' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    amount = int(amount)
    local balance = tonumber(row.balance) or 0
    if balance <= 0 then notify(src, 'info', 'no_balance') return false, 'no_balance' end
    if not amount or amount <= 0 then notify(src, 'error', 'bad_amount') return false, 'bad_amount' end
    local pay = math.min(amount, balance)
    if not takeMoney(P, pay, 'house-balance') then notify(src, 'error', 'not_enough_money') return false, 'no_money' end
    local left = balance - pay
    MySQL.update.await('UPDATE `multi_houses` SET `balance` = ? WHERE `houseid` = ?', { left, houseid })
    notify(src, 'success', 'balance_paid', pay, left)
    if left == 0 then
        telegram(cid, 'tg_paid_subject', _L('tg_paid_message', H.HouseName(houseid)))
        log('log_paid_title', 'green', _L('log_paid', row.fullname or '', cid, H.HouseName(houseid)))
    end
    return true, left
end

---------------------------------
-- land tax credit
---------------------------------
function H.AddCredit(src, houseid, amount)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    local cid = cidOf(P)
    local row = houseRow(houseid)
    if not isOwner(cid, row) then notify(src, 'error', 'not_owner') return false, 'not_owner' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    amount = int(amount)
    if not amount or amount <= 0 then notify(src, 'error', 'bad_amount') return false, 'bad_amount' end
    local credit = (tonumber(row.credit) or 0) + amount
    if credit > Config.MaxCredit then notify(src, 'error', 'credit_too_high', Config.MaxCredit) return false, 'too_high' end
    if not takeMoney(P, amount, 'house-tax-credit') then notify(src, 'error', 'not_enough_money') return false, 'no_money' end
    MySQL.update.await('UPDATE `multi_houses` SET `credit` = ? WHERE `houseid` = ?', { credit, houseid })
    notify(src, 'success', 'credit_added', amount, credit)
    return true, credit
end

function H.RemoveCredit(src, houseid, amount)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    local cid = cidOf(P)
    local row = houseRow(houseid)
    if not isOwner(cid, row) then notify(src, 'error', 'not_owner') return false, 'not_owner' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    amount = int(amount)
    if not amount or amount <= 0 then notify(src, 'error', 'bad_amount') return false, 'bad_amount' end
    local credit = tonumber(row.credit) or 0
    if amount > credit then notify(src, 'error', 'cannot_withdraw') return false, 'too_much' end
    -- the row only changes while it still holds the credit read above
    local changed = MySQL.update.await('UPDATE `multi_houses` SET `credit` = `credit` - ? WHERE `houseid` = ? AND `credit` >= ?', { amount, houseid, amount })
    if not changed or changed == 0 then notify(src, 'error', 'cannot_withdraw') return false, 'too_much' end
    giveMoney(P, amount, 'house-tax-credit')
    notify(src, 'success', 'credit_withdrawn', amount, credit - amount)
    return true, credit - amount
end

---------------------------------
-- guests
---------------------------------
function H.AddGuest(src, houseid, guestCid)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    local cid = cidOf(P)
    local row = houseRow(houseid)
    if not isOwner(cid, row) then notify(src, 'error', 'not_owner') return false, 'not_owner' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    if (tonumber(row.balance) or 0) > 0 then notify(src, 'error', 'guests_balance_owed') return false, 'balance_owed' end
    guestCid = type(guestCid) == 'string' and guestCid:upper():gsub('%s', '') or ''
    if guestCid == '' or #guestCid > 50 or not guestCid:match('^[%w_%-]+$') then notify(src, 'error', 'bad_citizenid') return false, 'bad_cid' end
    if guestCid == cid then notify(src, 'error', 'guest_is_you') return false, 'is_you' end
    local known = Core.Functions.GetPlayerByCitizenId(guestCid)
        or MySQL.scalar.await('SELECT 1 FROM `players` WHERE `citizenid` = ? LIMIT 1', { guestCid })
    if not known then notify(src, 'error', 'no_such_citizen', guestCid) return false, 'no_such_cid' end
    if keyOf(guestCid, houseid) then notify(src, 'error', 'guest_has_key') return false, 'has_key' end
    MySQL.insert.await('INSERT INTO `multi_housekeys` (`citizenid`, `houseid`, `guest`) VALUES (?, ?, 1)', { guestCid, houseid })
    notify(src, 'success', 'guest_added', guestCid)
    keysChanged(guestCid)
    return true
end

function H.RemoveGuest(src, houseid, guestCid)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    local cid = cidOf(P)
    local row = houseRow(houseid)
    if not isOwner(cid, row) then notify(src, 'error', 'not_owner') return false, 'not_owner' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    if type(guestCid) ~= 'string' or guestCid == '' then return false, 'bad_cid' end
    local changed = MySQL.update.await('DELETE FROM `multi_housekeys` WHERE `houseid` = ? AND `citizenid` = ? AND `guest` = 1', { houseid, guestCid })
    if not changed or changed == 0 then notify(src, 'error', 'no_such_guest') return false, 'no_such_guest' end
    notify(src, 'success', 'guest_removed', guestCid)
    keysChanged(guestCid)
    return true
end

function H.Guests(src, houseid)
    local P = getP(src)
    if not P or not validHouse(houseid) then return {} end
    if not isOwner(cidOf(P), houseRow(houseid)) then return {} end
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT `citizenid` FROM `multi_housekeys` WHERE `houseid` = ? AND `guest` = 1', { houseid }) or {}) do
        out[#out + 1] = { citizenid = r.citizenid }
    end
    return out
end

---------------------------------
-- selling, releasing, admin removal
---------------------------------
function H.SellInfo(src, houseid)
    local P = getP(src)
    if not P or not validHouse(houseid) then return nil end
    local row = houseRow(houseid)
    if not isOwner(cidOf(P), row) then return nil end
    local offer = math.floor((tonumber(row.price) or 0) * Config.SellBack)
    local balance = tonumber(row.balance) or 0
    return { sellprice = offer, balance = balance, payout = math.max(0, offer - balance) }
end

function H.Sell(src, houseid)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    local cid = cidOf(P)
    local row = houseRow(houseid)
    if not isOwner(cid, row) then notify(src, 'error', 'not_owner') return false, 'not_owner' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    local info = H.SellInfo(src, houseid)
    H.ClearHouse(houseid)
    giveMoney(P, info.payout, 'house-sale')
    if info.balance > 0 then
        notify(src, 'success', 'sold_minus_balance', info.payout, info.balance)
    else
        notify(src, 'success', 'sold', info.payout)
    end
    log('log_sold_title', 'orange', _L('log_sold', row.fullname or '', cid, H.HouseName(houseid), info.payout))
    return true, info.payout
end

function H.Release(src, houseid)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if type(houseid) ~= 'string' or not houseid:match('^[%w_]+$') then notify(src, 'error', 'no_house_found') return false, 'no_house' end
    local row = houseRow(houseid)
    if not row or not flag(row.owned) then notify(src, 'error', 'no_house_found') return false, 'no_house' end
    local cid = cidOf(P)
    if row.citizenid ~= cid and not isAdmin(src) then notify(src, 'error', 'not_owner') return false, 'not_owner' end
    H.ClearHouse(houseid)
    notify(src, 'success', 'released', H.HouseName(houseid))
    log('log_released_title', 'orange', _L('log_released', row.fullname or '', row.citizenid or '', H.HouseName(houseid)))
    return true
end

function H.AdminRemove(src, houseid)
    if src ~= 0 and not getP(src) then return false, 'no_player' end
    if not isAdmin(src) then notify(src, 'error', 'no_permission') return false, 'no_permission' end
    if type(houseid) ~= 'string' or not houseid:match('^[%w_]+$') then notify(src, 'error', 'no_house_found') return false, 'no_house' end
    local row = houseRow(houseid)
    if not row or not flag(row.owned) then notify(src, 'error', 'no_house_found') return false, 'no_house' end
    H.ClearHouse(houseid)
    notify(src, 'success', 'admin_removed', H.HouseName(houseid))
    log('log_removed_title', 'red', _L('log_removed', H.HouseName(houseid), row.fullname or '', src == 0 and _L('log_console') or (GetPlayerName(src) or tostring(src))))
    return true
end

---------------------------------
-- stash and outfits
---------------------------------
local function openStash(src, houseid)
    local id = H.StashId(houseid)
    local ok, res = pcall(function()
        return exports.MULTIinventory:Open(src, {
            id = id,
            label = _L('storage_label', H.HouseName(houseid)),
            slots = Config.StorageMaxSlots,
            maxWeight = Config.StorageMaxWeight,
            coords = HouseCfg[houseid].menucoords,
            reach = Config.ServerDistance,
        })
    end)
    return id, ok and res == true
end

--- ok, stash id, whether MULTIinventory opened it
function H.OpenStorage(src, houseid)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    if not keyOf(cidOf(P), houseid) then notify(src, 'error', 'no_key') return false, 'no_key' end
    local row = houseRow(houseid)
    if row and (tonumber(row.balance) or 0) > 0 then notify(src, 'error', 'storage_balance_owed') return false, 'balance_owed' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    local id, opened = openStash(src, houseid)
    return true, id, opened
end

function H.Outfits(src, houseid)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    if not keyOf(cidOf(P), houseid) then notify(src, 'error', 'no_key') return false, 'no_key' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    if GetResourceState('MULTItailor') ~= 'started' then notify(src, 'error', 'no_wardrobe') return false, 'no_tailor' end
    local ok = pcall(function() exports.MULTItailor:OpenOutfits(src) end)
    return ok
end

---------------------------------
-- doors
---------------------------------
function H.ToggleDoor(src, doorid)
    local P = getP(src)
    if not P then return false, 'no_player' end
    doorid = int(doorid)
    local d = doorid and DoorCfg[doorid]
    if not d then return false, 'no_door' end
    if not H.Owned[d.houseid] then return false, 'not_owned' end
    if not keyOf(cidOf(P), d.houseid) then notify(src, 'error', 'no_key') return false, 'no_key' end
    if not near(src, d.doorcoords, Config.DoorDistance) then notify(src, 'error', 'too_far') return false, 'too_far' end
    local state = H.DoorState(doorid) == 1 and 0 or 1
    if state == 1 and H.RobberyDoors[doorid] then
        -- the owner locking a door a robber opened ends that break-in
        local hid = H.RobberyDoors[doorid].houseid
        H.RobberyDoors[doorid] = nil
        H.Robberies[hid] = nil
    end
    saveDoor(doorid, state)
    notify(src, 'info', state == 1 and 'door_locked' or 'door_unlocked')
    return true, state
end

---------------------------------
-- break-ins
---------------------------------
local function relockRobbery(houseid)
    local r = H.Robberies[houseid]
    H.Robberies[houseid] = nil
    if not r then return end
    H.RobberyDoors[r.doorid] = nil
    broadcastDoor(r.doorid)
    if r.src and GetPlayerName(r.src) then TriggerClientEvent('MULTIhouses:client:robberyEnded', r.src, houseid) end
end

--- ok, locale key, arg
function H.CanLockpick(src, houseid, doorid)
    local R = Config.Robbery
    if not R.Enabled then return false, 'robbery_off' end
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    doorid = int(doorid)
    local d = doorid and DoorCfg[doorid]
    if not d or d.houseid ~= houseid then return false, 'no_door' end
    local cid = cidOf(P)
    if keyOf(cid, houseid) then return false, 'rob_own_house' end
    if R.OnlyRobOwnedHouses and not H.Owned[houseid] then return false, 'house_empty' end
    if H.Robberies[houseid] then return false, 'robbery_running' end
    local now = os.time()
    if H.PlayerCooldowns[cid] and now < H.PlayerCooldowns[cid] then
        return false, 'rob_wait_player', math.ceil((H.PlayerCooldowns[cid] - now) / 60)
    end
    if H.HouseCooldowns[houseid] and now < H.HouseCooldowns[houseid] then
        return false, 'rob_wait_house', math.ceil((H.HouseCooldowns[houseid] - now) / 60)
    end
    if R.RequireLockpick and not P.Functions.GetItemByName(R.LockpickItem) then return false, 'need_lockpick' end
    return true, 'ok'
end

function H.StartPick(src, houseid, doorid)
    local ok, key, arg = H.CanLockpick(src, houseid, doorid)
    if not ok then notify(src, 'error', key, arg) return false, key end
    local d = DoorCfg[int(doorid)]
    if not near(src, d.doorcoords, Config.DoorDistance) then notify(src, 'error', 'too_far') return false, 'too_far' end
    local R = Config.Robbery
    local P = getP(src)
    if R.RequireLockpick and math.random(100) <= (R.LockpickBreakChance or 0) then
        P.Functions.RemoveItem(R.LockpickItem, 1)
        notify(src, 'error', 'lockpick_broke')
        return false, 'broke'
    end
    H.Picks[src] = { houseid = houseid, doorid = d.doorid, startedAt = GetGameTimer() }
    if R.PoliceAlert and GetResourceState('MULTIlaw') == 'started' then
        pcall(function() exports.MULTIlaw:Alert(d.doorcoords, _L('law_alert')) end)
    end
    return true
end

function H.FinishPick(src, success)
    local pick = H.Picks[src]
    H.Picks[src] = nil
    if not pick then return false, 'no_attempt' end
    local P = getP(src)
    if not P then return false, 'no_player' end
    local R = Config.Robbery
    -- the progress bar runs PickSeconds; an answer much faster than that did not come from it
    if GetGameTimer() - pick.startedAt < (R.PickSeconds or 30) * 800 then return false, 'too_fast' end
    if not success then notify(src, 'error', 'lockpick_failed') return false, 'failed' end
    local ok, key, arg = H.CanLockpick(src, pick.houseid, pick.doorid)
    if not ok then notify(src, 'error', key, arg) return false, key end
    if not near(src, DoorCfg[pick.doorid].doorcoords, Config.DoorDistance) then notify(src, 'error', 'too_far') return false, 'too_far' end
    if R.RequireLockpick and R.UseUpOnSuccess then
        if P.Functions.RemoveItem(R.LockpickItem, 1) == false then notify(src, 'error', 'need_lockpick') return false, 'need_lockpick' end
    end

    local cid = cidOf(P)
    local now = os.time()
    H.HouseCooldowns[pick.houseid] = now + (R.CooldownPerHouse or 30) * 60
    H.PlayerCooldowns[cid] = now + (R.GlobalCooldown or 5) * 60
    H.Robberies[pick.houseid] = { robber = cid, src = src, doorid = pick.doorid, startedAt = now }
    H.RobberyDoors[pick.doorid] = { houseid = pick.houseid, unlockedAt = now }
    broadcastDoor(pick.doorid)
    notify(src, 'success', 'door_picked')
    TriggerClientEvent('MULTIhouses:client:robberyStarted', src, pick.houseid)

    local houseid, startedAt = pick.houseid, now
    SetTimeout((R.RobberyMinutes or 5) * 60 * 1000, function()
        local r = H.Robberies[houseid]
        if r and r.startedAt == startedAt then relockRobbery(houseid) end
    end)
    return true
end

function H.RobberyLoot(src, houseid)
    local P = getP(src)
    if not P then return false, 'no_player' end
    if not validHouse(houseid) then return false, 'no_house' end
    local r = H.Robberies[houseid]
    if not r or r.robber ~= cidOf(P) then notify(src, 'error', 'no_robbery') return false, 'no_robbery' end
    if not nearHouse(src, houseid) then notify(src, 'error', 'too_far') return false, 'too_far' end
    local id, opened = openStash(src, houseid)
    return true, id, opened
end

function H.EndRobbery(src, houseid)
    local P = getP(src)
    if not P then return false end
    local r = H.Robberies[houseid]
    if not r or r.robber ~= cidOf(P) then return false end
    relockRobbery(houseid)
    return true
end

---------------------------------
-- callbacks (ox_lib)
---------------------------------
local function cb(name, fn) lib.callback.register('MULTIhouses:server:' .. name, fn) end

cb('GetState', function(src)
    local P = getP(src)
    local robbing
    local cid = cidOf(P)
    for hid, r in pairs(H.Robberies) do if r.robber == cid then robbing = hid end end
    return {
        owned = H.Owned,
        prices = H.Prices,
        keys = cid and keysOf(cid) or {},
        doors = H.DoorStates(),
        robbing = robbing,
    }
end)

cb('GetKeys', function(src)
    local cid = cidOf(getP(src))
    return cid and keysOf(cid) or {}
end)

cb('GetDoors', function() return H.DoorStates() end)

cb('GetBuyInfo', function(src, houseid)
    if not validHouse(houseid) or H.Owned[houseid] then return nil end
    return H.BuyInfo(houseid)
end)

cb('GetMenu', function(src, houseid)
    local P = getP(src)
    if not P or not validHouse(houseid) then return nil end
    local key = keyOf(cidOf(P), houseid)
    if not key then return nil, 'no_key' end
    if not nearHouse(src, houseid) then return nil, 'too_far' end
    local row = houseRow(houseid) or {}
    return { isGuest = key == 'guest', isAdmin = isAdmin(src), hasBalance = (tonumber(row.balance) or 0) > 0 }
end)

cb('GetGuests', function(src, houseid) return H.Guests(src, houseid) end)

cb('GetMoneyInfo', function(src, houseid)
    local P = getP(src)
    if not P or not validHouse(houseid) then return nil end
    local row = houseRow(houseid)
    if not isOwner(cidOf(P), row) then return nil end
    return { credit = tonumber(row.credit) or 0, balance = tonumber(row.balance) or 0 }
end)

cb('GetSellInfo', function(src, houseid) return H.SellInfo(src, houseid) end)

cb('AddGuest', function(src, houseid, guestCid) return H.AddGuest(src, houseid, guestCid) == true end)
cb('RemoveGuest', function(src, houseid, guestCid) return H.RemoveGuest(src, houseid, guestCid) == true end)
cb('StartPick', function(src, houseid, doorid) return H.StartPick(src, houseid, doorid) == true end)

cb('CanLockpick', function(src, houseid, doorid)
    local ok, key, arg = H.CanLockpick(src, houseid, doorid)
    return ok, ok and nil or _L(key, arg)
end)

---------------------------------
-- events from the client
---------------------------------
local function net(name, fn)
    RegisterNetEvent('MULTIhouses:server:' .. name, function(...)
        local src = source
        if not getP(src) then return end
        fn(src, ...)
    end)
end

net('buy', function(src, houseid) H.Buy(src, houseid) end)
net('sell', function(src, houseid) H.Sell(src, houseid) end)
net('release', function(src, houseid) H.Release(src, houseid) end)
net('adminRemove', function(src, houseid) H.AdminRemove(src, houseid) end)
net('payBalance', function(src, houseid, amount) H.PayBalance(src, houseid, amount) end)
net('addCredit', function(src, houseid, amount) H.AddCredit(src, houseid, amount) end)
net('removeCredit', function(src, houseid, amount) H.RemoveCredit(src, houseid, amount) end)
net('addGuest', function(src, houseid, cid) H.AddGuest(src, houseid, cid) end)
net('removeGuest', function(src, houseid, cid) H.RemoveGuest(src, houseid, cid) end)
net('openStorage', function(src, houseid) H.OpenStorage(src, houseid) end)
net('outfits', function(src, houseid) H.Outfits(src, houseid) end)
net('toggleDoor', function(src, doorid) H.ToggleDoor(src, doorid) end)
net('finishPick', function(src, success) H.FinishPick(src, success == true) end)
net('robberyLoot', function(src, houseid) H.RobberyLoot(src, houseid) end)
net('endRobbery', function(src, houseid) H.EndRobbery(src, houseid) end)

AddEventHandler('playerDropped', function()
    local src = source
    H.Picks[src] = nil
    H.TestCoords[src] = nil
    for hid, r in pairs(H.Robberies) do
        if r.src == src then relockRobbery(hid) end
    end
end)

---------------------------------
-- land tax cycle
---------------------------------
local function billingCycle()
    if not Config.BillingEnabled then return end
    local rows = MySQL.query.await('SELECT * FROM `multi_houses` WHERE `owned` = 1') or {}
    for _, row in ipairs(rows) do
        local credit = tonumber(row.credit) or 0
        if credit >= Config.LandTaxPerCycle then
            MySQL.update.await('UPDATE `multi_houses` SET `credit` = ? WHERE `houseid` = ?', { credit - Config.LandTaxPerCycle, row.houseid })
            if credit < Config.LandTaxPerCycle * Config.CreditWarning then
                telegram(row.citizenid, 'tg_tax_low_subject', _L('tg_tax_low_message', H.HouseName(row.houseid)))
            end
        else
            telegram(row.citizenid, 'tg_tax_out_subject', _L('tg_tax_out_message', H.HouseName(row.houseid)))
            local owner = Core.Functions.GetPlayerByCitizenId(row.citizenid)
            H.ClearHouse(row.houseid)
            if owner then notify(owner.PlayerData.source, 'error', 'taken_back_tax', H.HouseName(row.houseid)) end
            log('log_lost_title', 'red', _L('log_lost_tax', row.fullname or '', row.citizenid or '', H.HouseName(row.houseid)))
        end
    end
    print(('[MULTIhouses] land tax cycle done (%d houses)'):format(#rows))
end

---------------------------------
-- balance reminders and taking houses back
---------------------------------
local function balanceCycle()
    local rows = MySQL.query.await('SELECT `houseid`, `citizenid`, `fullname`, `balance`, `bought_at` FROM `multi_houses` WHERE `owned` = 1 AND `balance` > 0') or {}
    for _, row in ipairs(rows) do
        local left = Config.BalanceGracePeriod - (os.time() - (tonumber(row.bought_at) or 0))
        if left <= 0 then
            local owner = Core.Functions.GetPlayerByCitizenId(row.citizenid)
            H.ClearHouse(row.houseid)
            telegram(row.citizenid, 'tg_balance_out_subject', _L('tg_balance_out_message', H.HouseName(row.houseid)))
            if owner then notify(owner.PlayerData.source, 'error', 'taken_back_balance', H.HouseName(row.houseid)) end
            log('log_lost_title', 'red', _L('log_lost_balance', row.fullname or '', row.citizenid or '', H.HouseName(row.houseid)))
        else
            telegram(row.citizenid, 'tg_balance_subject',
                _L('tg_balance_message', H.HouseName(row.houseid), tonumber(row.balance) or 0, math.ceil(left / 86400)))
        end
    end
end

---------------------------------
-- lockpick item
---------------------------------
local function registerLockpick()
    local R = Config.Robbery
    if not (R.Enabled and R.RequireLockpick and R.RegisterItem) then return end
    if GetResourceState('MULTIinventory') ~= 'started' then return end
    local MI = exports.MULTIinventory
    local t = 0
    while not MI:IsReady() and t < 300 do Wait(100) t = t + 1 end
    if not MI:IsReady() or MI:GetItemDef(R.LockpickItem) then return end
    local ok = pcall(function()
        return MI:RegisterItem({
            name = R.LockpickItem, label = _L('lockpick_label'), weight = R.ItemWeight or 50,
            type = 'item', unique = false, useable = false, image = R.LockpickItem .. '.png',
            description = _L('lockpick_desc'),
        })
    end)
    if ok then print(('[MULTIhouses] item %s added to the item list'):format(R.LockpickItem)) end
end

---------------------------------
-- start
---------------------------------
CreateThread(function()
    while not DB.ready do Wait(100) end

    for _, r in ipairs(MySQL.query.await('SELECT `houseid`, `price`, `owned`, `fullname`, `citizenid` FROM `multi_houses`') or {}) do
        H.Prices[r.houseid] = tonumber(r.price) or 0
        if flag(r.owned) then H.Owned[r.houseid] = { owner = r.fullname, citizenid = r.citizenid } end
    end
    -- after a restart: doors of owned houses locked, the rest open
    for doorid, d in pairs(DoorCfg) do
        H.Doors[doorid] = H.Owned[d.houseid] and 1 or 0
    end
    MySQL.update.await('UPDATE `multi_housedoors` SET `doorstate` = 0')
    for doorid, state in pairs(H.Doors) do
        if state == 1 then MySQL.update.await('UPDATE `multi_housedoors` SET `doorstate` = 1 WHERE `doorid` = ?', { tostring(doorid) }) end
    end

    local n = 0
    for _ in pairs(H.Owned) do n = n + 1 end
    print(('[MULTIhouses] %d houses, %d owned, %d doors'):format(#Config.Houses, n, #Config.HouseDoors))

    H.ready = true
    H.SyncOwned()
    TriggerClientEvent('MULTIhouses:client:doors', -1, H.DoorStates())

    registerLockpick()

    -- tax and balance cycles (not during a self-test: they would send telegrams to test characters)
    if not SELFTEST then
        CreateThread(function()
            while true do
                billingCycle()
                Wait(math.max(1, Config.BillingCycle) * 60 * 60 * 1000)
            end
        end)
        CreateThread(function()
            Wait(5000)
            while true do
                balanceCycle()
                Wait(math.max(60000, Config.BalanceReminderInterval))
            end
        end)
    end
end)

-- expired cooldowns and break-ins left open
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for k, t in pairs(H.HouseCooldowns) do if now > t then H.HouseCooldowns[k] = nil end end
        for k, t in pairs(H.PlayerCooldowns) do if now > t then H.PlayerCooldowns[k] = nil end end
        for hid, r in pairs(H.Robberies) do
            if now - r.startedAt > (Config.Robbery.RobberyMinutes or 5) * 60 + 60 then relockRobbery(hid) end
        end
    end
end)

---------------------------------
-- exports
---------------------------------
local function cidFrom(who)
    if type(who) == 'number' then return cidOf(getP(who)) end
    return who
end

exports('IsReady', function() return H.ready end)
exports('StashId', function(houseid) return H.StashId(houseid) end)
exports('GetHouse', function(houseid)
    if type(houseid) ~= 'string' then return nil end
    return houseRow(houseid)
end)
exports('GetHouses', function(who)
    local cid = cidFrom(who)
    if not cid then return {} end
    local out = {}
    for hid, key in pairs(keysOf(cid)) do out[#out + 1] = { houseid = hid, key = key } end
    return out
end)
exports('HasKey', function(who, houseid)
    local cid = cidFrom(who)
    return cid ~= nil and keyOf(cid, houseid) ~= nil
end)
exports('IsDoorLocked', function(doorid) return H.DoorState(int(doorid)) == 1 end)

---------------------------------
-- self-test hooks (only with  setr multicore_selftest true)
---------------------------------
if SELFTEST then
    --- Pretend player src stands at x, y, z (nil = use the real position).
    exports('_TestSetCoords', function(src, x, y, z)
        H.TestCoords[tonumber(src)] = x and vector3(x + 0.0, y + 0.0, z + 0.0) or nil
        return true
    end)
    --- Runs one server action as player src: Buy, Sell, Release, AdminRemove, PayBalance, AddCredit,
    --- RemoveCredit, AddGuest, RemoveGuest, OpenStorage, Outfits, ToggleDoor, StartPick, FinishPick,
    --- RobberyLoot, EndRobbery, CanLockpick, Guests, SellInfo.
    exports('_TestCall', function(name, src, ...)
        local fn = H[name]
        if type(fn) ~= 'function' then return false, 'no_such_action' end
        return fn(tonumber(src), ...)
    end)
    --- Moves the start of src's lockpicking attempt back by ms (the server refuses answers that come too fast).
    exports('_TestAgePick', function(src, ms)
        local p = H.Picks[tonumber(src)]
        if not p then return false end
        p.startedAt = p.startedAt - (tonumber(ms) or 0)
        return true
    end)
    --- Forgets every break-in cooldown and running break-in.
    exports('_TestResetRobbery', function()
        for hid in pairs(H.Robberies) do relockRobbery(hid) end
        table.wipe(H.HouseCooldowns)
        table.wipe(H.PlayerCooldowns)
        table.wipe(H.Picks)
        return true
    end)
    exports('_TestDoorState', function(doorid) return H.DoorState(int(doorid)) end)
    exports('_TestHouseConfig', function(houseid) return HouseCfg[houseid], HouseDoorIds[houseid] end)
    exports('_TestDoorConfig', function(doorid) return DoorCfg[int(doorid)] end)
    exports('_TestSettings', function()
        return { DepositPercent = Config.DepositPercent, SellBack = Config.SellBack, StartCredit = Config.StartCredit,
            RobberyEnabled = Config.Robbery.Enabled }
    end)
end
