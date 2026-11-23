-- ============================================================
-- MULTIhotel :: server
-- Renting, checking in, room credit, the room locker, guests,
-- throwing guests out and the hourly rent. Every action is checked
-- here: room actions only work for the room you are standing in,
-- desk actions only near the desk, and every amount is worked out
-- on the server.
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- ============================================================

local Core = exports.MULTIcore:GetCoreObject()

local Inside = {}         -- [src] = { roomid = n, location = id, owner = bool }
local EvictCooldown = {}  -- [citizenid] = os.time() when the owner may throw guests out again

local HotelCfg = {}
for _, h in ipairs(Config.Hotels) do HotelCfg[h.id] = h end

local function dbg(...)
    if Config.Debug then print('[MULTIhotel]', ...) end
end

---------------------------------
-- helpers
---------------------------------
local function getP(src)
    src = tonumber(src)
    return src and Core.Functions.GetPlayer(src) or nil
end

local function cidOf(P) return P and P.PlayerData and P.PlayerData.citizenid or nil end

local function fullName(P)
    local ci = P.PlayerData.charinfo or {}
    local name = ('%s %s'):format(ci.firstname or '', ci.lastname or '')
    return (name:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function hotelName(id)
    local h = HotelCfg[id]
    if not h then return tostring(id) end
    local label = h.label or id
    if label:sub(1, 6) == 'hotel_' then return _L(label) end
    return label
end

local function notify(src, ntype, key, ...)
    local text = _L(key, ...)
    if not src or src == 0 then print('[MULTIhotel] ' .. text) return end
    pcall(function()
        exports.MULTIcore:Notify(src, { title = _L('notify_title'), text = text, type = ntype })
    end)
end

local function log(titleKey, color, message)
    if not Config.LogName or Config.LogName == '' then return end
    if GetResourceState('MULTIserver') ~= 'started' then return end
    pcall(function() exports.MULTIserver:Log(Config.LogName, _L(titleKey), color, message) end)
end

-- MULTItelegram, or MULTIp_telegram when that one runs instead (same SendTelegram export)
local function telegramResource()
    for _, res in ipairs({ 'MULTItelegram', 'MULTIp_telegram' }) do
        if GetResourceState(res) == 'started' then return res end
    end
end

local function telegram(citizenid, subjectKey, message)
    local res = telegramResource()
    if not res then return end
    pcall(function()
        exports[res]:SendTelegram(citizenid, _L('telegram_sender'), _L(subjectKey), message)
    end)
end

local function int(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.floor(n)
end

local function position(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function near(src, coords, dist)
    local p = position(src)
    if not p then return false end
    return #(p - vector3(coords.x, coords.y, coords.z)) <= dist
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

local function bucketOf(roomid) return Config.BucketOffset + roomid end

local function stashId(roomid) return 'stash:hotel_room_' .. tostring(roomid) end

local function roomById(roomid)
    return MySQL.single.await('SELECT * FROM `multi_hotel_rooms` WHERE `roomid` = ?', { roomid })
end

local function roomAt(citizenid, location)
    return MySQL.single.await('SELECT * FROM `multi_hotel_rooms` WHERE `citizenid` = ? AND `location` = ?', { citizenid, location })
end

--- a room at this hotel the player is invited to
local function guestRoomAt(citizenid, location)
    return MySQL.single.await([[
        SELECT r.* FROM `multi_hotel_guests` g
        JOIN `multi_hotel_rooms` r ON r.`roomid` = g.`roomid`
        WHERE g.`guest_citizenid` = ? AND r.`location` = ?
        LIMIT 1
    ]], { citizenid, location })
end

local function newRoomId()
    for _ = 1, 200 do
        local id = math.random(1000, 9999)
        if not roomById(id) then return id end
    end
    return nil
end

--- The room the player stands in, as the owner. nil when not inside or not the owner.
local function ownedInside(src, P)
    local inside = Inside[src]
    if not inside then return nil end
    local row = roomById(inside.roomid)
    if not row or row.citizenid ~= cidOf(P) then return nil end
    return row
end

---------------------------------
-- moving players in and out of rooms
---------------------------------
local function enterRoom(src, row, asOwner)
    Inside[src] = { roomid = row.roomid, location = row.location, owner = asOwner }
    SetPlayerRoutingBucket(src, bucketOf(row.roomid))
    dbg(('player %s in room %s (bucket %s)'):format(src, row.roomid, GetPlayerRoutingBucket(src)))
    TriggerClientEvent('MULTIhotel:client:enter', src, row.location)
end

--- reason: 'leave' | 'evicted' | 'lost'
local function putOut(src, reason, ownerName)
    local inside = Inside[src]
    Inside[src] = nil
    SetPlayerRoutingBucket(src, 0)
    if inside then
        TriggerClientEvent('MULTIhotel:client:exit', src, inside.location, reason, ownerName, inside.roomid)
    end
end

local function guestsInside(roomid)
    local out = {}
    for s, inside in pairs(Inside) do
        if inside.roomid == roomid and not inside.owner then out[#out + 1] = s end
    end
    return out
end

local function everyoneInside(roomid)
    local out = {}
    for s, inside in pairs(Inside) do
        if inside.roomid == roomid then out[#out + 1] = s end
    end
    return out
end

---------------------------------
-- desk: rent, check in, guest check in
---------------------------------
local function atDesk(src, location)
    local h = type(location) == 'string' and HotelCfg[location]
    if not h or Inside[src] then return nil end
    if not near(src, h.desk, Config.ServerDistance) then notify(src, 'error', 'too_far') return nil end
    return h
end

RegisterNetEvent('MULTIhotel:server:rent', function(location)
    local src = source
    local P = getP(src)
    if not P or not atDesk(src, location) then return end
    local cid = cidOf(P)
    if roomAt(cid, location) then notify(src, 'error', 'already_have_room') return end
    if money(P) < Config.StartCredit then notify(src, 'error', 'not_enough_money') return end
    local roomid = newRoomId()
    if not roomid then notify(src, 'error', 'no_free_room') return end
    if not takeMoney(P, Config.StartCredit, 'hotel-room-rent') then notify(src, 'error', 'not_enough_money') return end
    local name = fullName(P)
    MySQL.insert.await('INSERT INTO `multi_hotel_rooms` (`roomid`, `citizenid`, `fullname`, `location`, `credit`, `rented_at`) VALUES (?, ?, ?, ?, ?, ?)',
        { roomid, cid, name, location, Config.StartCredit, os.time() })
    notify(src, 'success', 'rented', roomid, hotelName(location))
    log('log_rented', 'green', ('%s (%s) rented room %s at %s'):format(name, cid, roomid, hotelName(location)))
end)

RegisterNetEvent('MULTIhotel:server:checkIn', function(location)
    local src = source
    local P = getP(src)
    if not P or not atDesk(src, location) then return end
    local row = roomAt(cidOf(P), location)
    if not row then notify(src, 'error', 'no_room_here') return end
    enterRoom(src, row, true)
end)

RegisterNetEvent('MULTIhotel:server:guestCheckIn', function(location)
    local src = source
    local P = getP(src)
    if not P or not atDesk(src, location) then return end
    local row = guestRoomAt(cidOf(P), location)
    if not row then notify(src, 'error', 'not_a_guest') return end
    enterRoom(src, row, false)
    notify(src, 'success', 'guest_checked_in', row.roomid)
end)

---------------------------------
-- in the room
---------------------------------
RegisterNetEvent('MULTIhotel:server:leave', function()
    local src = source
    if not Inside[src] then return end
    putOut(src, 'leave')
end)

RegisterNetEvent('MULTIhotel:server:addCredit', function(amount)
    local src = source
    local P = getP(src)
    if not P then return end
    local row = ownedInside(src, P)
    if not row then notify(src, 'error', 'not_owner') return end
    amount = int(amount)
    if not amount or amount < 1 then notify(src, 'error', 'bad_amount') return end
    local credit = tonumber(row.credit) or 0
    if credit + amount > Config.MaxCredit then notify(src, 'error', 'credit_too_high', Config.MaxCredit) return end
    if not takeMoney(P, amount, 'hotel-room-credit') then notify(src, 'error', 'not_enough_money') return end
    MySQL.update.await('UPDATE `multi_hotel_rooms` SET `credit` = `credit` + ? WHERE `roomid` = ?', { amount, row.roomid })
    notify(src, 'success', 'credit_added', amount, credit + amount)
end)

RegisterNetEvent('MULTIhotel:server:removeCredit', function(amount)
    local src = source
    local P = getP(src)
    if not P then return end
    local row = ownedInside(src, P)
    if not row then notify(src, 'error', 'not_owner') return end
    amount = int(amount)
    if not amount or amount < 1 then notify(src, 'error', 'bad_amount') return end
    local credit = tonumber(row.credit) or 0
    if amount > credit then notify(src, 'error', 'cannot_withdraw') return end
    local changed = MySQL.update.await('UPDATE `multi_hotel_rooms` SET `credit` = `credit` - ? WHERE `roomid` = ? AND `credit` >= ?', { amount, row.roomid, amount })
    if not changed or changed < 1 then notify(src, 'error', 'cannot_withdraw') return end
    giveMoney(P, amount, 'hotel-room-credit-back')
    notify(src, 'success', 'credit_withdrawn', amount, credit - amount)
end)

RegisterNetEvent('MULTIhotel:server:storage', function()
    local src = source
    local P = getP(src)
    if not P then return end
    local row = ownedInside(src, P)
    if not row then notify(src, 'error', 'not_owner') return end
    local h = HotelCfg[row.location]
    local ok, res = pcall(function()
        return exports.MULTIinventory:Open(src, {
            id = stashId(row.roomid),
            label = _L('locker_label', row.roomid),
            slots = Config.StorageMaxSlots,
            maxWeight = Config.StorageMaxWeight,
            coords = h and h.room or nil,
            reach = Config.ServerDistance,
        })
    end)
    if not ok or res == false then notify(src, 'error', 'locker_failed') end
end)

---------------------------------
-- guests
---------------------------------
RegisterNetEvent('MULTIhotel:server:addGuest', function(target)
    local src = source
    local P = getP(src)
    if not P then return end
    local row = ownedInside(src, P)
    if not row then notify(src, 'error', 'not_owner') return end
    target = int(target)
    local T = target and target ~= src and getP(target)
    if not T then notify(src, 'error', 'player_not_found') return end
    local me, them = position(src), position(target)
    if not me or not them or #(me - them) > Config.InviteDistance then notify(src, 'error', 'player_not_near') return end
    local tcid = cidOf(T)
    if MySQL.scalar.await('SELECT COUNT(*) FROM `multi_hotel_guests` WHERE `roomid` = ? AND `guest_citizenid` = ?', { row.roomid, tcid }) > 0 then
        notify(src, 'error', 'already_guest') return
    end
    if MySQL.scalar.await('SELECT COUNT(*) FROM `multi_hotel_guests` WHERE `roomid` = ?', { row.roomid }) >= Config.MaxGuests then
        notify(src, 'error', 'max_guests', Config.MaxGuests) return
    end
    local tname, oname = fullName(T), fullName(P)
    MySQL.insert.await('INSERT INTO `multi_hotel_guests` (`roomid`, `owner_citizenid`, `guest_citizenid`, `guest_name`, `added_at`) VALUES (?, ?, ?, ?, ?)',
        { row.roomid, cidOf(P), tcid, tname, os.time() })
    notify(src, 'success', 'guest_added', tname)
    notify(target, 'info', 'you_were_invited', oname, row.roomid, hotelName(row.location))
    telegram(tcid, 'tg_invite_subject', _L('tg_invite_body', oname, row.roomid, hotelName(row.location)))
end)

RegisterNetEvent('MULTIhotel:server:removeGuest', function(guestRow)
    local src = source
    local P = getP(src)
    if not P then return end
    local row = ownedInside(src, P)
    if not row then notify(src, 'error', 'not_owner') return end
    local g = MySQL.single.await('SELECT * FROM `multi_hotel_guests` WHERE `id` = ? AND `roomid` = ?', { int(guestRow), row.roomid })
    if not g then return end
    MySQL.update.await('DELETE FROM `multi_hotel_guests` WHERE `id` = ?', { g.id })
    notify(src, 'success', 'guest_removed', g.guest_name)
    local T = Core.Functions.GetPlayerByCitizenId(g.guest_citizenid)
    if T then notify(T.PlayerData.source, 'info', 'you_were_removed', row.roomid) end
end)

RegisterNetEvent('MULTIhotel:server:evict', function()
    local src = source
    local P = getP(src)
    if not P then return end
    local row = ownedInside(src, P)
    if not row then notify(src, 'error', 'not_owner') return end
    local cid = cidOf(P)
    local left = (EvictCooldown[cid] or 0) - os.time()
    if left > 0 then notify(src, 'error', 'evict_cooldown', left) return end

    local guests = MySQL.query.await('SELECT * FROM `multi_hotel_guests` WHERE `roomid` = ?', { row.roomid }) or {}
    if #guests == 0 then notify(src, 'info', 'no_guests_to_evict') return end

    local ownerName = fullName(P)
    local kicked = 0
    for _, s in ipairs(guestsInside(row.roomid)) do
        putOut(s, 'evicted', ownerName)
        kicked = kicked + 1
    end
    local bodyKey = Config.RemoveGuestsOnEviction and 'tg_evicted_body_removed' or 'tg_evicted_body'
    for _, g in ipairs(guests) do
        telegram(g.guest_citizenid, 'tg_evicted_subject', _L(bodyKey, ownerName, row.roomid))
    end
    if Config.RemoveGuestsOnEviction then
        MySQL.update.await('DELETE FROM `multi_hotel_guests` WHERE `roomid` = ?', { row.roomid })
        notify(src, 'success', 'evicted_and_removed', kicked)
    else
        notify(src, 'success', 'evicted', kicked)
    end
    EvictCooldown[cid] = os.time() + Config.EvictionCooldown
    log('log_evicted', 'orange', ('%s threw %d guest(s) out of room %s'):format(ownerName, kicked, row.roomid))
end)

---------------------------------
-- callbacks (ox_lib)
---------------------------------
local function cb(name, fn) lib.callback.register('MULTIhotel:server:' .. name, fn) end

cb('GetDesk', function(src, location)
    local P = getP(src)
    if not P or type(location) ~= 'string' or not HotelCfg[location] then return nil end
    local cid = cidOf(P)
    local own = roomAt(cid, location)
    return {
        hasRoom = own ~= nil,
        roomid = own and own.roomid or nil,
        credit = own and tonumber(own.credit) or 0,
        isGuest = guestRoomAt(cid, location) ~= nil,
        price = Config.StartCredit,
    }
end)

cb('GetRoom', function(src)
    local P = getP(src)
    local inside = Inside[src]
    if not P or not inside then return nil end
    local row = roomById(inside.roomid)
    if not row then return nil end
    local isOwner = row.citizenid == cidOf(P)
    return {
        roomid = row.roomid,
        location = row.location,
        credit = isOwner and (tonumber(row.credit) or 0) or nil,
        isOwner = isOwner,
        owner = row.fullname,
    }
end)

cb('GetGuests', function(src)
    local P = getP(src)
    local row = P and ownedInside(src, P)
    if not row then return nil end
    local out = {}
    for _, g in ipairs(MySQL.query.await('SELECT `id`, `guest_name`, `added_at` FROM `multi_hotel_guests` WHERE `roomid` = ? ORDER BY `added_at` DESC', { row.roomid }) or {}) do
        out[#out + 1] = { id = g.id, name = g.guest_name, added = os.date('%d/%m/%Y', tonumber(g.added_at) or 0) }
    end
    return out
end)

cb('GetNearby', function(src)
    local P = getP(src)
    if not P or not ownedInside(src, P) then return {} end
    local me = position(src)
    if not me then return {} end
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local t = tonumber(id)
        if t ~= src then
            local T = getP(t)
            local p = T and position(t)
            if p and #(me - p) <= Config.InviteDistance then
                out[#out + 1] = { id = t, name = fullName(T) }
            end
        end
    end
    return out
end)

cb('GuestCount', function(src)
    local P = getP(src)
    local row = P and ownedInside(src, P)
    if not row then return 0 end
    return MySQL.scalar.await('SELECT COUNT(*) FROM `multi_hotel_guests` WHERE `roomid` = ?', { row.roomid }) or 0
end)

---------------------------------
-- rent
---------------------------------
local function loseRoom(row)
    for _, s in ipairs(everyoneInside(row.roomid)) do putOut(s, 'lost') end
    MySQL.update.await('DELETE FROM `multi_hotel_guests` WHERE `roomid` = ?', { row.roomid })
    MySQL.update.await('DELETE FROM `multi_hotel_rooms` WHERE `roomid` = ?', { row.roomid })
    if Config.PurgeStorage and GetResourceState('MULTIinventory') == 'started' then
        pcall(function()
            local MI = exports.MULTIinventory
            if MI:Exists(stashId(row.roomid)) then MI:Delete(stashId(row.roomid)) end
        end)
    end
    telegram(row.citizenid, 'tg_lost_subject', _L('tg_lost_body', row.roomid, hotelName(row.location)))
    log('log_lost', 'red', ('%s lost room %s at %s (no credit left)'):format(row.fullname, row.roomid, hotelName(row.location)))
end

local function billing()
    local rent = Config.RentPerCycle
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `multi_hotel_rooms`') or {}) do
        local credit = tonumber(row.credit) or 0
        dbg(row.citizenid, row.location, row.roomid, credit)
        if credit >= rent then
            local after = credit - rent
            MySQL.update.await('UPDATE `multi_hotel_rooms` SET `credit` = ? WHERE `roomid` = ?', { after, row.roomid })
            if after < rent * Config.CreditWarning then
                telegram(row.citizenid, 'tg_low_subject', _L('tg_low_body', row.roomid, hotelName(row.location), after))
            end
        else
            loseRoom(row)
        end
    end
end

CreateThread(function()
    while not DB.ready do Wait(100) end
    local cycle = math.max(1, math.floor((Config.BillingCycle or 1) * 3600000))
    while true do
        Wait(cycle)
        local ok, err = pcall(billing)
        if not ok then print('^1[MULTIhotel] rent cycle failed: ' .. tostring(err) .. '^7') end
    end
end)

---------------------------------
-- clean up
---------------------------------
AddEventHandler('playerDropped', function()
    Inside[source] = nil
end)

-- a restart must not leave anyone stuck in a room bucket (the client walks them out of the room itself)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for s in pairs(Inside) do SetPlayerRoutingBucket(s, 0) end
    Inside = {}
end)
