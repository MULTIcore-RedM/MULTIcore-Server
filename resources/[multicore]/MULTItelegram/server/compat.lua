-- ============================================================
-- MULTItelegram :: rsg-telegram face (server)
-- The fxmanifest `provide`s rsg-telegram. These are the server
-- events and callbacks of rsg-telegram 2.1.1 that scripts and old
-- clients use, with the same arguments, answered by MULTItelegram.
-- rsg-telegram has no exports. Direct SQL on `telegrams` /
-- `address_book` works because the tables keep rsg-telegram's shape.
-- Not answered (premium features, by design): bird post, job mailboxes.
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
AddEventHandler('RSGCore:Server:UpdateObject', function()
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

local function getP(src) return RSGCore.Functions.GetPlayer(tonumber(src)) end

local function notify(src, ok, msg)
    exports.MULTIcore:Notify(src, { text = msg, title = _L('title'), type = ok and 'success' or 'error', duration = Config.NotifyDuration })
end

local Compat = {}

-- (sender, sendername, citizenid, subject, message, jobSenderAlias): the sender fields are ignored,
-- as in rsg-telegram 2.1.1 (the server decides who sends); job aliases are not supported.
Compat['rsg-telegram:server:SendMessagePostOffice'] = function(src, _, _, to, subject, message)
    local ok, res = MT.Send(src, to, subject, message)
    if ok then
        notify(src, true, res.price > 0 and _L('sent_paid', res.name, ('%.2f'):format(res.price)) or _L('sent', res.name))
    else
        notify(src, false, MT.ErrText(res))
    end
    return ok, res
end

Compat['rsg-telegram:server:SavePerson'] = function(src, name, cid)
    local ok, res = MT.AddContact(src, name, cid)
    notify(src, ok, ok and _L('contact_added', res.name) or MT.ErrText(res))
    return ok, res
end

Compat['rsg-telegram:server:RemovePerson'] = function(src, cid)
    local ok, res = MT.RemoveContact(src, cid)
    notify(src, ok, ok and _L('contact_removed') or MT.ErrText(res))
    return ok, res
end

Compat['rsg-telegram:server:DeleteMessage'] = function(src, tid)
    local ok, res = MT.Delete(src, tid)
    notify(src, ok, ok and _L('deleted') or MT.ErrText(res))
    return ok, res
end

Compat['rsg-telegram:server:MarkAsRead'] = function(src, tid)
    return MT.Read(src, tid)
end

-- old clients ask for the inbox and get it back as rsg-telegram's 'InboxList' event
Compat['rsg-telegram:server:CheckInbox'] = function(src)
    local P = getP(src)
    if not P then return false end
    TriggerClientEvent('rsg-telegram:client:InboxList', src, { list = MT.RawInbox(src) })
    return true
end

-- marks every waiting telegram picked up (MULTItelegram reads them at any office anyway)
Compat['rsg-telegram:server:pickupMessages'] = function(src)
    local P = getP(src)
    if not P or MT.OfficeAt(src) == nil then return false end
    MySQL.update.await('UPDATE `telegrams` SET `pickedUp` = 1 WHERE `citizenid` = ? AND `fromPostOffice` = 1 AND `pickedUp` = 0', { P.PlayerData.citizenid })
    return true
end

for name, fn in pairs(Compat) do
    RegisterNetEvent(name, function(...) fn(source, ...) end)
end

---------------------------------
-- callbacks (RSGCore.Functions.CreateCallback, as rsg-telegram)
---------------------------------
function MT.RawInbox(src)
    local P = getP(src)
    if not P then return {} end
    if not Config.ReadAnywhere and MT.OfficeAt(src) == nil then return {} end
    return MySQL.query.await("SELECT * FROM `telegrams` WHERE `citizenid` = ? AND `mailbox` = 'personal' AND (`birdstatus` = 0 OR `birdstatus` = 1) ORDER BY `id` DESC LIMIT ?",
        { P.PlayerData.citizenid, Config.InboxRows }) or {}
end

local function book(src)
    local P = getP(src)
    return P and MT.Contacts(P.PlayerData.citizenid) or {}
end

RSGCore.Functions.CreateCallback('rsg-telegram:server:getTelegramsAmount', function(src, cb)
    local P = getP(src)
    cb(P and MT.Unread(P.PlayerData.citizenid) or 0)
end)

RSGCore.Functions.CreateCallback('rsg-telegram:server:checkWaitingMessages', function(src, cb)
    local P = getP(src)
    cb(P and MT.Unread(P.PlayerData.citizenid) or 0)
end)

RSGCore.Functions.CreateCallback('rsg-telegram:server:getInbox', function(src, cb) cb(MT.RawInbox(src)) end)
RSGCore.Functions.CreateCallback('rsg-telegram:server:getJobInbox', function(_, cb) cb({}) end)
RSGCore.Functions.CreateCallback('rsg-telegram:server:getJobRecipients', function(_, cb) cb({}) end)
RSGCore.Functions.CreateCallback('rsg-telegram:server:getJobSenders', function(_, cb) cb({}) end)
RSGCore.Functions.CreateCallback('rsg-telegram:server:getAddressbook', function(src, cb) cb(book(src)) end)

-- these two answer nil for an empty book, like rsg-telegram
RSGCore.Functions.CreateCallback('rsg-telegram:server:GetPlayers', function(src, cb)
    local b = book(src)
    cb(b[1] and b or nil)
end)
RSGCore.Functions.CreateCallback('rsg-telegram:server:GetPlayersPostOffice', function(src, cb)
    local b = book(src)
    cb(b[1] and b or nil)
end)

if MT.SELFTEST then
    --- Runs one rsg-telegram net event as if pretend player `src` sent it.
    exports('_TestCompat', function(name, src, ...)
        local fn = Compat[name]
        if not fn then return false, 'no_handler' end
        return fn(src, ...)
    end)
end
