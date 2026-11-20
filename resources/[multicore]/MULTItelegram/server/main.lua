-- ============================================================
-- MULTItelegram :: server
-- Telegrams between characters, kept in rsg-telegram's own tables
-- (`telegrams`, `address_book`) so RSG scripts that read or insert
-- rows by SQL keep working. Money through the RSGCore player object,
-- parcel items through MULTIinventory exports. Every action is
-- checked here; the client only asks.
-- GPL v3. Table shapes and office places follow rsg-telegram
-- (RSG v2 framework, GPL v3), see CREDITS.md.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
AddEventHandler('RSGCore:Server:UpdateObject', function()
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

MT = {}
MT.SELFTEST = GetConvar('multicore_selftest', 'false') == 'true'

local PERSONAL = 'personal'        -- rsg-telegram's personal mailbox name
local ready = false
local calls = {}                   -- [src] = { timestamps } spam guard
local lastSend = {}                -- [src] = GetGameTimer() of the last telegram sent
local officeOverride = {}          -- [src] = office index | false (self-test only)
local announced = {}               -- [telegram id] = true when this script already told the recipient
local lastSeenId = 0               -- newest telegrams.id the poll has looked at

local function dbg(...)
    if Config.Debug then print('^5[MULTItelegram]^7', ...) end
end

---------------------------------
-- tables
---------------------------------
-- rsg-telegram's shapes (MULTIcore's sql/rsg_core.sql makes them too); the parcel table is ours.
local TELEGRAM_COLUMNS = {
    { 'status', 'INT NOT NULL DEFAULT 0' },
    { 'birdstatus', 'INT NOT NULL DEFAULT 0' },
    { 'fromPostOffice', 'INT NOT NULL DEFAULT 0' },
    { 'pickedUp', 'INT NOT NULL DEFAULT 1' },
    { 'mailbox', "VARCHAR(20) NOT NULL DEFAULT 'personal'" },
    { 'jobTarget', 'VARCHAR(100) DEFAULT NULL' },
}

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `address_book` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `citizenid` VARCHAR(50) NOT NULL,
          `name` VARCHAR(255) NOT NULL,
          `owner` VARCHAR(50) NOT NULL,
          PRIMARY KEY (`id`),
          KEY `owner` (`owner`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `telegrams` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `citizenid` VARCHAR(50) NOT NULL,
          `recipient` VARCHAR(255) DEFAULT NULL,
          `sender` VARCHAR(255) DEFAULT NULL,
          `sendername` VARCHAR(255) DEFAULT NULL,
          `subject` VARCHAR(255) DEFAULT NULL,
          `sentDate` VARCHAR(64) DEFAULT NULL,
          `message` TEXT DEFAULT NULL,
          `status` INT NOT NULL DEFAULT 0,
          `birdstatus` INT NOT NULL DEFAULT 0,
          `fromPostOffice` INT NOT NULL DEFAULT 0,
          `pickedUp` INT NOT NULL DEFAULT 1,
          `mailbox` VARCHAR(20) NOT NULL DEFAULT 'personal',
          `jobTarget` VARCHAR(100) DEFAULT NULL,
          PRIMARY KEY (`id`),
          KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    -- an older rsg-telegram table may lack the later columns: add them (with rsg-telegram's defaults)
    local have = {}
    for _, r in ipairs(MySQL.query.await("SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'telegrams'") or {}) do
        have[r.c] = true
    end
    for _, col in ipairs(TELEGRAM_COLUMNS) do
        if not have[col[1]] then
            MySQL.query.await(('ALTER TABLE `telegrams` ADD COLUMN `%s` %s'):format(col[1], col[2]))
            print(('[MULTItelegram] added missing column telegrams.%s'):format(col[1]))
        end
    end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multicore_telegram_parcels` (
          `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
          `telegram_id` INT NOT NULL,
          `citizenid` VARCHAR(50) NOT NULL,
          `sender` VARCHAR(50) NOT NULL,
          `item` VARCHAR(100) NOT NULL,
          `amount` INT NOT NULL,
          `info` LONGTEXT DEFAULT NULL,
          `collected` TINYINT NOT NULL DEFAULT 0,
          `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          UNIQUE KEY `telegram_id` (`telegram_id`),
          KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    lastSeenId = tonumber(MySQL.scalar.await('SELECT COALESCE(MAX(`id`), 0) FROM `telegrams`')) or 0
    ready = true
end)

---------------------------------
-- helpers
---------------------------------
local function round2(n) return math.floor(n * 100 + 0.5) / 100 end

local function getP(src) return RSGCore.Functions.GetPlayer(tonumber(src)) end

local function notify(src, msg, kind)
    exports.MULTIcore:Notify(src, { text = msg, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end

local function fullName(charinfo)
    if type(charinfo) == 'string' then charinfo = json.decode(charinfo) end
    if type(charinfo) ~= 'table' then return _L('unknown') end
    local name = (('%s %s'):format(charinfo.firstname or '', charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or _L('unknown')
end

-- Text from a player: no control characters (newlines kept), trimmed, cut to `max` letters.
local function clean(s, max)
    if type(s) == 'number' then s = tostring(s) end
    if type(s) ~= 'string' then return '' end
    s = s:gsub('\r\n', '\n'):gsub('[%z\1-\9\11-\31\127]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    local n = utf8.len(s)
    if not n then
        s = s:gsub('[\128-\255]', '')
        n = #s
    end
    if n > max then s = s:sub(1, utf8.offset(s, max + 1) - 1) end
    return s
end

local function limited(src)
    local now = GetGameTimer()
    local keep = {}
    for _, t in ipairs(calls[src] or {}) do
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

--- Index of the office the player stands at, or nil.
function MT.OfficeAt(src)
    src = tonumber(src)
    if officeOverride[src] ~= nil then return officeOverride[src] or nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local pos = GetEntityCoords(ped)
    local best, bestDist
    for i, o in ipairs(Config.Offices) do
        local d = #(pos - o.coords)
        if d <= Config.MaxUseDistance and (not bestDist or d < bestDist) then best, bestDist = i, d end
    end
    return best
end

local function canRead(src)
    return Config.ReadAnywhere or MT.OfficeAt(src) ~= nil
end

local myIdCache = {}
local function charNumber(citizenid)
    if not myIdCache[citizenid] then
        myIdCache[citizenid] = tonumber(MySQL.scalar.await('SELECT `id` FROM `players` WHERE `citizenid` = ?', { citizenid }))
    end
    return myIdCache[citizenid]
end

---------------------------------
-- unread count and notices
---------------------------------
function MT.Unread(citizenid)
    if type(citizenid) ~= 'string' then return 0 end
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `telegrams` WHERE `citizenid` = ? AND `mailbox` = ? AND `status` = 0',
        { citizenid, PERSONAL })) or 0
end

--- Updates the player's unread count (state bag telegramUnreadMessages, as rsg-telegram) and,
--- with `kind` ('arrived' | 'login'), tells them.
function MT.RefreshUnread(src, kind)
    local P = getP(src)
    if not P then return 0 end
    local n = MT.Unread(P.PlayerData.citizenid)
    if GetPlayerName(src) then Player(src).state:set('telegramUnreadMessages', n, true) end -- rsg-telegram's state bag
    if kind == 'arrived' then
        notify(src, _L('notice_arrived', n), 'info')
    elseif kind == 'login' and n > 0 then
        notify(src, _L('notice_waiting', n), 'info')
    end
    if kind then TriggerEvent('MULTItelegram:notice', src, kind, n) end
    return n
end

local function announce(citizenid, telegramId)
    if Config.PollSeconds > 0 and telegramId then announced[telegramId] = true end
    local T = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    if T then MT.RefreshUnread(T.PlayerData.source, 'arrived') end
end

-- Rows other scripts wrote straight into `telegrams` (rsg-horses does) are announced here.
function MT.Poll()
    if not ready then return 0 end
    local rows = MySQL.query.await('SELECT `id`, `citizenid` FROM `telegrams` WHERE `id` > ? ORDER BY `id`', { lastSeenId }) or {}
    local who = {}
    for _, r in ipairs(rows) do
        if r.id > lastSeenId then lastSeenId = r.id end
        if announced[r.id] then
            announced[r.id] = nil
        else
            who[r.citizenid] = true
        end
    end
    local n = 0
    for cid in pairs(who) do
        local T = RSGCore.Functions.GetPlayerByCitizenId(cid)
        if T then
            MT.RefreshUnread(T.PlayerData.source, 'arrived')
            n = n + 1
        end
    end
    return n
end

CreateThread(function()
    if Config.PollSeconds <= 0 then return end
    while true do
        Wait(Config.PollSeconds * 1000)
        MT.Poll()
    end
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    local src = P and P.PlayerData and P.PlayerData.source
    local cid = P and P.PlayerData and P.PlayerData.citizenid
    if not src then return end
    SetTimeout(Config.LoginNoticeDelayMs, function()
        local now = getP(src)
        if now and now.PlayerData.citizenid == cid then MT.RefreshUnread(src, 'login') end
    end)
end)

---------------------------------
-- who is it?
---------------------------------
local function playerRow(sql, args)
    local row = MySQL.single.await(sql, args)
    if not row then return nil end
    return { citizenid = row.citizenid, name = fullName(row.charinfo), id = tonumber(row.id) }
end

--- Finds a character from what a player typed: character number (#12), citizen id,
--- a name in `ownerCid`'s address book, or "First Last".
--- → { citizenid, name, id } or nil, err ('no_recipient' | 'unknown_recipient' | 'ambiguous')
function MT.Resolve(ownerCid, to)
    to = clean(to, Config.MaxRecipient)
    if to == '' then return nil, 'no_recipient' end
    local num = to:match('^#?(%d+)$')
    if num then
        local t = playerRow('SELECT `id`, `citizenid`, `charinfo` FROM `players` WHERE `id` = ?', { tonumber(num) })
        if t then return t end
    end
    local t = playerRow('SELECT `id`, `citizenid`, `charinfo` FROM `players` WHERE `citizenid` = ?', { to })
    if t then return t end
    if ownerCid then
        local book = MySQL.query.await('SELECT `citizenid` FROM `address_book` WHERE `owner` = ? AND LOWER(`name`) = LOWER(?) LIMIT 2', { ownerCid, to }) or {}
        if #book == 1 then
            t = playerRow('SELECT `id`, `citizenid`, `charinfo` FROM `players` WHERE `citizenid` = ?', { book[1].citizenid })
            if t then return t end
        end
    end
    local first, last = to:match('^(%S+)%s+(.-)$')
    if first and last ~= '' then
        local rows = MySQL.query.await([[SELECT `id`, `citizenid`, `charinfo` FROM `players`
            WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.firstname'))) = LOWER(?)
              AND LOWER(JSON_UNQUOTE(JSON_EXTRACT(`charinfo`, '$.lastname'))) = LOWER(?) LIMIT 2]], { first, last }) or {}
        if #rows > 1 then return nil, 'ambiguous' end
        if #rows == 1 then return { citizenid = rows[1].citizenid, name = fullName(rows[1].charinfo), id = tonumber(rows[1].id) } end
    end
    return nil, 'unknown_recipient'
end

---------------------------------
-- parcels
---------------------------------
local function MI() return exports.MULTIinventory end
local function hasInventory() return GetResourceState('MULTIinventory') == 'started' end

local function postable(def)
    if not def then return false end
    if Config.Parcel.Blacklist[def.name] then return false end
    if def.type == 'weapon' and not Config.Parcel.AllowWeapons then return false end
    return true
end

-- satchel stacks that may go into a parcel, for the compose page
local function parcelChoices(src)
    if not Config.Parcel.Enabled or not hasInventory() then return {} end
    local inv = MI():Get(MI():PlayerInv(src))
    local out = {}
    for slot, st in pairs(inv and inv.items or {}) do
        local def = MI():GetItemDef(st.name)
        if postable(def) and (tonumber(st.amount) or 0) > 0 then
            out[#out + 1] = { slot = tonumber(slot) or st.slot, name = st.name, label = def.label or st.name, amount = st.amount }
        end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

---------------------------------
-- sending
---------------------------------
local function refundCash(P, amount)
    if amount > 0 then P.Functions.AddMoney('cash', amount, 'telegram refund') end
end

--- Writes one telegram row in rsg-telegram's shape (waits at the post office: fromPostOffice 1, pickedUp 0).
local function insertTelegram(citizenid, recipientName, sender, sendername, subject, message)
    return MySQL.insert.await('INSERT INTO `telegrams` (`citizenid`, `recipient`, `sender`, `sendername`, `subject`, `sentDate`, `message`, `fromPostOffice`, `pickedUp`, `mailbox`) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, ?)',
        { citizenid, recipientName, sender, sendername, subject, os.date(Config.DateFormat), message, PERSONAL })
end

--- A player sends a telegram from the office they stand at.
--- parcel = nil | { slot, amount }. → true, { id, name, price } or false, err
function MT.Send(src, to, subject, message, parcel)
    src = tonumber(src)
    local P = getP(src)
    if not P or not ready then return false, 'failed' end
    if limited(src) then return false, 'slow_down' end
    if MT.OfficeAt(src) == nil then return false, 'not_at_office' end
    local now = GetGameTimer()
    if lastSend[src] and now - lastSend[src] < Config.SendCooldownMs then return false, 'wait' end

    subject = clean(subject, Config.MaxSubject)
    message = clean(message, Config.MaxMessage)
    if message == '' then return false, 'empty' end
    if subject == '' then subject = _L('no_subject') end

    local me = P.PlayerData.citizenid
    local target, err = MT.Resolve(me, to)
    if not target then return false, err end
    if target.citizenid == me and not Config.AllowSendToSelf then return false, 'self' end

    -- parcel checks before any money moves
    local stack, amount, invId
    if parcel ~= nil then
        if not Config.Parcel.Enabled or not hasInventory() then return false, 'parcel_off' end
        if type(parcel) ~= 'table' then return false, 'parcel_bad' end
        local slot = tonumber(parcel.slot)
        amount = math.floor(tonumber(parcel.amount) or 0)
        if not slot or amount < 1 or amount > Config.Parcel.MaxAmount then return false, 'parcel_amount' end
        invId = MI():PlayerInv(src)
        stack = MI():GetSlot(invId, slot)
        if not stack or (tonumber(stack.amount) or 0) < amount then return false, 'parcel_bad' end
        if not postable(MI():GetItemDef(stack.name)) then return false, 'parcel_forbidden' end
        stack = { name = stack.name, slot = slot }
    end

    local price = round2(Config.Price + (stack and Config.Parcel.Price or 0))
    if price > 0 then
        if (tonumber(P.PlayerData.money.cash) or 0) < price then return false, 'no_cash' end
        if not P.Functions.RemoveMoney('cash', price, 'telegram') then return false, 'no_cash' end
    end

    local info
    if stack then
        local ok, _, removedInfo = MI():RemoveItem(invId, stack.name, amount, stack.slot, nil, 'telegram parcel')
        if not ok then
            refundCash(P, price)
            return false, 'parcel_bad'
        end
        info = removedInfo
    end

    local sendername = fullName(P.PlayerData.charinfo)
    local id = insertTelegram(target.citizenid, target.name, me, sendername, subject, message)
    if id and stack then
        local pid = MySQL.insert.await('INSERT INTO `multicore_telegram_parcels` (`telegram_id`, `citizenid`, `sender`, `item`, `amount`, `info`) VALUES (?, ?, ?, ?, ?, ?)',
            { id, target.citizenid, me, stack.name, amount, info and json.encode(info) or nil })
        if not pid then
            MySQL.update.await('DELETE FROM `telegrams` WHERE `id` = ?', { id })
            id = nil
        end
    end
    if not id then
        refundCash(P, price)
        if stack then MI():AddItem(invId, stack.name, amount, info, nil, 'telegram refund') end
        return false, 'failed'
    end

    lastSend[src] = now
    dbg(('%s sent telegram %d to %s (%s)'):format(me, id, target.citizenid, stack and (amount .. 'x ' .. stack.name) or 'no parcel'))
    announce(target.citizenid, id)
    TriggerEvent('MULTItelegram:sent', src, id, target.citizenid)
    return true, { id = id, name = target.name, price = price }
end

--- A telegram from the server or a script (no money, no office). → id or false, err
function MT.SendSystem(to, sendername, subject, message, sender)
    if not ready then return false, 'failed' end
    local target, err = MT.Resolve(nil, to)
    if not target then return false, err end
    subject = clean(subject, Config.MaxSubject)
    message = clean(message, Config.MaxMessage)
    if message == '' then return false, 'empty' end
    local id = insertTelegram(target.citizenid, target.name, clean(sender or 'system', 50), clean(sendername or _L('sender_system'), 60),
        subject ~= '' and subject or _L('no_subject'), message)
    if not id then return false, 'failed' end
    announce(target.citizenid, id)
    return id
end

---------------------------------
-- inbox
---------------------------------
function MT.Inbox(citizenid)
    local rows = MySQL.query.await([[SELECT t.`id`, t.`sender`, t.`sendername`, t.`subject`, t.`sentDate`, t.`message`, t.`status`,
            p.`item`, p.`amount`, p.`collected`
        FROM `telegrams` t LEFT JOIN `multicore_telegram_parcels` p ON p.`telegram_id` = t.`id`
        WHERE t.`citizenid` = ? AND t.`mailbox` = ? AND (t.`birdstatus` = 0 OR t.`birdstatus` = 1)
        ORDER BY t.`id` DESC LIMIT ?]], { citizenid, PERSONAL, Config.InboxRows }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local parcel
        if r.item then
            local def = hasInventory() and MI():GetItemDef(r.item) or nil
            parcel = { label = def and def.label or r.item, amount = r.amount, collected = tonumber(r.collected) == 1 }
        end
        out[#out + 1] = {
            id = r.id, sender = r.sender, sendername = r.sendername or _L('unknown'), subject = r.subject or '',
            date = r.sentDate or '', message = r.message or '', unread = tonumber(r.status) == 0, parcel = parcel,
        }
    end
    return out
end

--- Marks a telegram read (and picked up). → true or false, err
function MT.Read(src, id)
    local P = getP(src)
    if not P then return false, 'failed' end
    if not canRead(src) then return false, 'not_at_office' end
    id = tonumber(id)
    if not id then return false, 'not_found' end
    local n = MySQL.update.await('UPDATE `telegrams` SET `status` = 1, `birdstatus` = 1, `pickedUp` = 1 WHERE `id` = ? AND `citizenid` = ?',
        { id, P.PlayerData.citizenid })
    if not n or n < 1 then
        -- already read is fine, someone else's is not
        local own = MySQL.scalar.await('SELECT 1 FROM `telegrams` WHERE `id` = ? AND `citizenid` = ?', { id, P.PlayerData.citizenid })
        if not own then return false, 'not_found' end
    end
    MT.RefreshUnread(src)
    return true
end

--- Deletes one of the player's telegrams (not while a parcel still waits). → true or false, err
function MT.Delete(src, id)
    local P = getP(src)
    if not P then return false, 'failed' end
    if limited(src) then return false, 'slow_down' end
    if not canRead(src) then return false, 'not_at_office' end
    id = tonumber(id)
    local cid = P.PlayerData.citizenid
    local row = id and MySQL.single.await([[SELECT t.`id`, p.`collected` FROM `telegrams` t
        LEFT JOIN `multicore_telegram_parcels` p ON p.`telegram_id` = t.`id`
        WHERE t.`id` = ? AND t.`citizenid` = ?]], { id, cid })
    if not row then return false, 'not_found' end
    if row.collected ~= nil and tonumber(row.collected) == 0 then return false, 'parcel_waiting' end
    MySQL.update.await('DELETE FROM `telegrams` WHERE `id` = ? AND `citizenid` = ?', { id, cid })
    MySQL.update.await('DELETE FROM `multicore_telegram_parcels` WHERE `telegram_id` = ?', { id })
    MT.RefreshUnread(src)
    return true
end

--- Hands a parcel to the player at an office. → true, { label, amount } or false, err
function MT.Collect(src, id)
    local P = getP(src)
    if not P then return false, 'failed' end
    if limited(src) then return false, 'slow_down' end
    if MT.OfficeAt(src) == nil then return false, 'not_at_office' end
    if not hasInventory() then return false, 'parcel_off' end
    id = tonumber(id)
    local row = id and MySQL.single.await('SELECT * FROM `multicore_telegram_parcels` WHERE `telegram_id` = ? AND `citizenid` = ?',
        { id, P.PlayerData.citizenid })
    if not row or tonumber(row.collected) == 1 then return false, 'no_parcel' end
    local info = row.info and json.decode(row.info) or nil
    local invId = MI():PlayerInv(src)
    if not MI():CanAdd(invId, row.item, row.amount, info) then return false, 'no_space' end
    -- claim first so two quick clicks cannot both pay out
    local n = MySQL.update.await('UPDATE `multicore_telegram_parcels` SET `collected` = 1 WHERE `id` = ? AND `collected` = 0', { row.id })
    if n ~= 1 then return false, 'no_parcel' end
    local ok = MI():AddItem(invId, row.item, row.amount, info, nil, 'telegram parcel')
    if not ok then
        MySQL.update.await('UPDATE `multicore_telegram_parcels` SET `collected` = 0 WHERE `id` = ?', { row.id })
        return false, 'no_space'
    end
    local def = MI():GetItemDef(row.item)
    return true, { label = def and def.label or row.item, amount = row.amount }
end

---------------------------------
-- address book
---------------------------------
function MT.Contacts(citizenid)
    return MySQL.query.await('SELECT `id`, `citizenid`, `name` FROM `address_book` WHERE `owner` = ? ORDER BY `name` ASC', { citizenid }) or {}
end

--- Adds a contact: `to` is a character number, citizen id or name; `name` how it is listed (empty = the character's name).
function MT.AddContact(src, name, to)
    local P = getP(src)
    if not P then return false, 'failed' end
    if limited(src) then return false, 'slow_down' end
    if not Config.ContactsAnywhere and not canRead(src) then return false, 'not_at_office' end
    local me = P.PlayerData.citizenid
    local target, err = MT.Resolve(me, to)
    if not target then return false, err end
    if target.citizenid == me then return false, 'self' end
    name = clean(name, Config.MaxContactName)
    if name == '' then name = target.name end
    if MySQL.scalar.await('SELECT 1 FROM `address_book` WHERE `owner` = ? AND `citizenid` = ?', { me, target.citizenid }) then
        return false, 'contact_exists'
    end
    local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `address_book` WHERE `owner` = ?', { me })) or 0
    if count >= Config.MaxContacts then return false, 'contacts_full' end
    MySQL.insert.await('INSERT INTO `address_book` (`citizenid`, `name`, `owner`) VALUES (?, ?, ?)', { target.citizenid, name, me })
    return true, { name = name, citizenid = target.citizenid }
end

function MT.RemoveContact(src, citizenid)
    local P = getP(src)
    if not P then return false, 'failed' end
    if limited(src) then return false, 'slow_down' end
    if not Config.ContactsAnywhere and not canRead(src) then return false, 'not_at_office' end
    if type(citizenid) ~= 'string' and type(citizenid) ~= 'number' then return false, 'not_found' end
    local n = MySQL.update.await('DELETE FROM `address_book` WHERE `owner` = ? AND `citizenid` = ?', { P.PlayerData.citizenid, tostring(citizenid) })
    if not n or n < 1 then return false, 'not_found' end
    return true
end

---------------------------------
-- the page
---------------------------------
--- What the page shows. mode = 'inbox' | 'compose' | 'contacts'
function MT.State(src)
    local P = getP(src)
    if not P then return nil end
    local cid = P.PlayerData.citizenid
    local idx = MT.OfficeAt(src)
    local read = Config.ReadAnywhere or idx ~= nil
    return {
        office = idx and _L(Config.Offices[idx].label) or nil,
        atOffice = idx ~= nil,
        canRead = read,
        me = { name = fullName(P.PlayerData.charinfo), citizenid = cid, id = charNumber(cid) },
        cash = tonumber(P.PlayerData.money.cash) or 0,
        price = Config.Price,
        parcel = Config.Parcel.Enabled and hasInventory() and { price = Config.Parcel.Price, max = Config.Parcel.MaxAmount, items = idx and parcelChoices(src) or {} } or nil,
        inbox = read and MT.Inbox(cid) or {},
        contacts = MT.Contacts(cid),
        limits = { subject = Config.MaxSubject, message = Config.MaxMessage, recipient = Config.MaxRecipient, name = Config.MaxContactName },
    }
end

local function errText(err) return _L('err_' .. tostring(err or 'failed')) end
MT.ErrText = errText

lib.callback.register('MULTItelegram:open', function(src, mode)
    local P = getP(src)
    if not P then return false end
    if mode == 'contacts' then
        if not Config.ContactsAnywhere and not canRead(src) then return false, errText('not_at_office') end
    elseif mode == 'compose' then
        if MT.OfficeAt(src) == nil then return false, errText('not_at_office') end
    elseif not canRead(src) then
        return false, errText('not_at_office')
    end
    return true, MT.State(src)
end)

lib.callback.register('MULTItelegram:action', function(src, action, data)
    if type(data) ~= 'table' then data = {} end
    local ok, res
    if action == 'send' then
        ok, res = MT.Send(src, data.to, data.subject, data.message, data.parcel)
        if ok then
            res = res.price > 0 and _L('sent_paid', res.name, ('%.2f'):format(res.price)) or _L('sent', res.name)
        end
    elseif action == 'read' then
        ok, res = MT.Read(src, data.id)
    elseif action == 'delete' then
        ok, res = MT.Delete(src, data.id)
        if ok then res = _L('deleted') end
    elseif action == 'collect' then
        ok, res = MT.Collect(src, data.id)
        if ok then res = _L('collected', res.amount, res.label) end
    elseif action == 'contact_add' then
        ok, res = MT.AddContact(src, data.name, data.to)
        if ok then res = _L('contact_added', res.name) end
    elseif action == 'contact_remove' then
        ok, res = MT.RemoveContact(src, data.citizenid)
        if ok then res = _L('contact_removed') end
    elseif action == 'lookup' then
        local P = getP(src)
        local t, err = MT.Resolve(P and P.PlayerData.citizenid, data.to)
        if t then return { ok = true, extra = { name = t.name, id = t.id } } end
        return { ok = false, msg = errText(err) }
    elseif action == 'refresh' then
        ok = true
    else
        return { ok = false, msg = errText('failed') }
    end
    local out = { ok = ok == true, state = MT.State(src) }
    if ok then
        out.msg = type(res) == 'string' and res or nil
    else
        out.msg = errText(res)
        if res == 'not_at_office' then out.close = not (out.state and out.state.canRead) end
    end
    return out
end)

---------------------------------
-- clean-up
---------------------------------
local function forget(src)
    calls[src], lastSend[src], officeOverride[src] = nil, nil, nil
end
AddEventHandler('playerDropped', function() forget(source) end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) forget(src) end)

-- the core deletes telegrams and contacts pointing at the character; these are the rest
AddEventHandler('MULTIcore:characterDeleted', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    MySQL.update('DELETE FROM `address_book` WHERE `owner` = ?', { citizenid })
    MySQL.update('DELETE FROM `multicore_telegram_parcels` WHERE `citizenid` = ?', { citizenid })
    myIdCache[citizenid] = nil
end)

---------------------------------
-- exports (server)
---------------------------------
exports('IsReady', function() return ready end)
exports('Send', MT.Send)                       -- (src, to, subject, message, parcel?) → ok, result|err
exports('SendTelegram', MT.SendSystem)         -- (to, sendername, subject, message, sender?) → id | false, err
exports('GetUnread', function(who)             -- (src or citizenid) → number
    if type(who) == 'number' then
        local P = getP(who)
        who = P and P.PlayerData.citizenid
    end
    return MT.Unread(who)
end)
exports('Resolve', function(to) return MT.Resolve(nil, to) end) -- (to) → { citizenid, name, id } | nil, err
exports('GetInbox', function(citizenid) return MT.Inbox(citizenid) end)
exports('GetContacts', function(citizenid) return MT.Contacts(citizenid) end)

---------------------------------
-- self-test hooks (only with  setr multicore_selftest true)
---------------------------------
if MT.SELFTEST then
    --- Pretend the player stands at office `idx` (false = nowhere, nil = use the real position).
    exports('_TestSetOffice', function(src, idx) officeOverride[tonumber(src)] = idx; return true end)
    --- Runs the direct-SQL announce poll now.
    exports('_TestPoll', function() return MT.Poll() end)
    --- Changes one top-level config value (e.g. SendCooldownMs).
    exports('_TestConfig', function(key, value)        -- 'Parcel.Enabled' style paths reach into tables
        local t, last = Config, nil
        for part in tostring(key):gmatch('[^%.]+') do
            if last then t = t[last] end
            last = part
        end
        t[last] = value
        return true
    end)
    exports('_TestDelete', function(src, id) calls[tonumber(src)] = nil; return MT.Delete(src, id) end)
    exports('_TestCollect', function(src, id) calls[tonumber(src)] = nil; return MT.Collect(src, id) end)
    exports('_TestRead', function(src, id) return MT.Read(src, id) end)
    exports('_TestAddContact', function(src, name, to) calls[tonumber(src)] = nil; return MT.AddContact(src, name, to) end)
    exports('_TestRemoveContact', function(src, cid) calls[tonumber(src)] = nil; return MT.RemoveContact(src, cid) end)
    exports('_TestState', function(src) return MT.State(src) end)
    --- Clears the spam guard and send cooldown of one pretend player.
    exports('_TestReset', function(src) calls[tonumber(src)], lastSend[tonumber(src)] = nil, nil; return true end)
end
