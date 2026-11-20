-- ============================================================
-- MULTIcamps :: engine (server)
-- The server holds the truth about every camp: where it stands, whether
-- its fire burns, whether its chest is shared with the owner's gang, and
-- when the owner last came by. Clients only draw the props near them.
--
-- Table `multicamps` (made on start):
--   id, citizenid, owner_name, x, y, z, heading, fire_lit, shared, gang,
--   created, last_visit (unix seconds)
-- Table `multicamps_notices`: messages for owners who were away when their
-- camp decayed, shown at their next login.
-- Chest: the MULTIinventory custom inventory 'custom:camp:<citizenid>'.
--
-- The functions here are server-trusted (exports for other scripts and the
-- self-test). What a game client may ask goes through server/net.lua, which
-- checks distance, ownership and the rate limit first.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local MI = exports.MULTIinventory

Camps = {
    ready = false,
    List = {},        -- [id] = camp (see decode)
    Allowed = {},     -- [src] = storage id the server opened for src (other camp chests are closed at once)
    Rested = {},      -- [citizenid] = os.time() of the last rest that gave the bonus
    TestCoords = {},  -- [src] = vector3 (self-test only: pretend players have no ped)
}

local STORAGE_PREFIX = 'custom:camp:'
local DAY = 86400
local NO_GANG = 'none'

local function dbg(fmt, ...)
    if Config.Debug then print(('[MULTIcamps] ' .. fmt):format(...)) end
end

function Camps.Notify(src, key, kind, ...)
    src = tonumber(src)
    if not src or src <= 0 then return end
    local text = _L(key, ...)
    pcall(function() exports.MULTIcore:Notify(src, { text = text, title = _L('title'), type = kind or 'info' }) end)
end

function Camps.GetPlayer(src) return RSGCore.Functions.GetPlayer(tonumber(src)) end

function Camps.CitizenId(src)
    local P = Camps.GetPlayer(src)
    return P and P.PlayerData.citizenid or nil
end

local function gangOf(P)
    local g = P and P.PlayerData.gang
    local name = type(g) == 'table' and g.name or nil
    if not name or name == '' or name == NO_GANG then return nil end
    return name
end

function Camps.PlayerPos(src)
    src = tonumber(src)
    if not src then return nil end
    if Camps.TestCoords[src] then return Camps.TestCoords[src] end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function Camps.StorageId(citizenid) return STORAGE_PREFIX .. tostring(citizenid) end

-- one action at a time per character (awaits yield, so two calls could cross)
local locks = {}
local function locked(key, fn, ...)
    if not key then return false, 'no_player' end
    if locks[key] then return false, 'busy' end
    locks[key] = true
    local res = table.pack(pcall(fn, ...))
    locks[key] = nil
    if not res[1] then
        print(('^1[MULTIcamps] %s^7'):format(tostring(res[2])))
        return false, 'error'
    end
    return table.unpack(res, 2, res.n)
end

-- ------------------------------------------------------------
-- geometry (the client uses the same sums to set the props down)
-- ------------------------------------------------------------

--- Where one part of a camp stands (x / y from the tent and heading; z is the tent's, the client snaps to the ground).
function Camps.PartCoords(camp, part)
    local def = Config.Props[part]
    local off = def and def.offset or vector3(0.0, 0.0, 0.0)
    local h = math.rad(camp.heading or 0.0)
    local fx, fy = -math.sin(h), math.cos(h)   -- forward
    local rx, ry = math.cos(h), math.sin(h)    -- right
    return vector3(camp.x + rx * off.x + fx * off.y, camp.y + ry * off.x + fy * off.y, camp.z + off.z)
end

--- The no-camp zone a point lies in, or nil.
function Camps.TownAt(x, y)
    for _, z in ipairs(Config.NoCampZones or {}) do
        local dx, dy = x - z.x, y - z.y
        if dx * dx + dy * dy <= z.radius * z.radius then return z end
    end
end

-- ------------------------------------------------------------
-- rows
-- ------------------------------------------------------------

local function flag(v) return v == true or tonumber(v) == 1 end

local function decode(row)
    if not row then return nil end
    return {
        id = tonumber(row.id),
        citizenid = row.citizenid,
        ownerName = row.owner_name or '',
        x = tonumber(row.x) + 0.0, y = tonumber(row.y) + 0.0, z = tonumber(row.z) + 0.0,
        heading = (tonumber(row.heading) or 0.0) + 0.0,
        lit = flag(row.fire_lit),
        shared = flag(row.shared),
        gang = row.gang ~= '' and row.gang or nil,
        created = tonumber(row.created) or 0,
        lastVisit = tonumber(row.last_visit) or 0,
    }
end

--- What every client gets to draw a camp (no owner ids).
function Camps.Public(camp)
    return { id = camp.id, x = camp.x, y = camp.y, z = camp.z, heading = camp.heading, lit = camp.lit }
end

local function broadcast(camp)
    TriggerClientEvent('MULTIcamps:client:upsert', -1, Camps.Public(camp))
end

function Camps.Get(id) return Camps.List[tonumber(id) or -1] end

function Camps.Of(citizenid)
    local out = {}
    if not citizenid then return out end
    for _, c in pairs(Camps.List) do
        if c.citizenid == citizenid then out[#out + 1] = c end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

--- A camp a player stands at (nearest within dist), or nil.
function Camps.NearestTo(pos, dist)
    local best, bestD
    for _, c in pairs(Camps.List) do
        local d = #(vector3(pos.x, pos.y, pos.z) - vector3(c.x, c.y, c.z))
        if d <= dist and (not bestD or d < bestD) then best, bestD = c, d end
    end
    return best, bestD
end

function Camps.Visit(camp)
    if not camp then return end
    camp.lastVisit = os.time()
    MySQL.update.await('UPDATE multicamps SET last_visit = ? WHERE id = ?', { camp.lastVisit, camp.id })
end

local function ensureStorage(citizenid, camp)
    local spec = {
        label = _L('storage_label'),
        slots = Config.Storage.Slots,
        maxWeight = Config.Storage.MaxWeight,
        reach = Config.ServerUseDistance,
    }
    if camp then
        local c = Camps.PartCoords(camp, 'chest')
        spec.coords = { x = c.x, y = c.y, z = c.z }
    end
    MI:Create(Camps.StorageId(citizenid), spec)
end

-- ------------------------------------------------------------
-- access
-- ------------------------------------------------------------

--- May src use this camp's chest (owner, or a member of the gang it is shared with)?
function Camps.CanUseStorage(src, camp)
    if type(camp) ~= 'table' then camp = Camps.Get(camp) end
    if not camp then return false, 'no_camp' end
    local P = Camps.GetPlayer(src)
    if not P then return false, 'no_player' end
    if P.PlayerData.citizenid == camp.citizenid then return true end
    if not Config.GangSharing or not camp.shared or not camp.gang then return false, 'not_owner' end
    if gangOf(P) ~= camp.gang then return false, 'not_owner' end
    return true
end

function Camps.IsOwner(src, camp)
    if type(camp) ~= 'table' then camp = Camps.Get(camp) end
    return camp ~= nil and Camps.CitizenId(src) == camp.citizenid
end

-- ------------------------------------------------------------
-- pitching
-- ------------------------------------------------------------

--- Every rule for a new camp at coords (the road check is the game's; see client).
--- → true | false, err, arg
function Camps.CheckPlace(citizenid, coords, playerPos)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return false, 'bad_coords' end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return false, 'bad_coords' end
    if #Camps.Of(citizenid) >= Config.MaxCampsPerCharacter then return false, 'limit' end
    if playerPos and #(vector3(playerPos.x, playerPos.y, playerPos.z) - vector3(x, y, z)) > Config.PlaceDistance then
        return false, 'too_far'
    end
    local town = Camps.TownAt(x, y)
    if town then return false, 'in_town', town.name end
    for _, c in pairs(Camps.List) do
        local dx, dy = c.x - x, c.y - y
        if dx * dx + dy * dy < Config.MinCampDistance * Config.MinCampDistance then return false, 'near_camp' end
    end
    return true
end

local function doPlace(src, coords, heading, skipDistance)
    local P = Camps.GetPlayer(src)
    if not P then return false, 'no_player' end
    local cid = P.PlayerData.citizenid
    local ok, err, arg = Camps.CheckPlace(cid, coords, not skipDistance and Camps.PlayerPos(src) or nil)
    if not ok then return false, err, arg end
    local pinv = MI:PlayerInv(src)
    if (MI:Count(pinv, Config.KitItem) or 0) < 1 then return false, 'no_kit' end
    local removed = MI:RemoveItem(pinv, Config.KitItem, 1, nil, nil, 'multicamps:pitch')
    if not removed then return false, 'no_kit' end

    heading = (tonumber(heading) or 0.0) % 360.0
    local now = os.time()
    local ci = P.PlayerData.charinfo or {}
    local ownerName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    local id = MySQL.insert.await(
        'INSERT INTO multicamps (citizenid, owner_name, x, y, z, heading, fire_lit, shared, gang, created, last_visit) VALUES (?, ?, ?, ?, ?, ?, ?, 0, NULL, ?, ?)',
        { cid, ownerName, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, heading, Config.Fire.StartsLit and 1 or 0, now, now })
    if not id then
        MI:AddItem(pinv, Config.KitItem, 1, nil, nil, 'multicamps:refund')
        return false, 'error'
    end
    local camp = decode(MySQL.single.await('SELECT * FROM multicamps WHERE id = ?', { id }))
    Camps.List[camp.id] = camp
    ensureStorage(cid, camp)
    broadcast(camp)
    dbg('%s pitched camp %d at %.1f %.1f %.1f', cid, camp.id, camp.x, camp.y, camp.z)
    TriggerEvent('MULTIcamps:placed', src, camp.id)
    return true, camp.id
end

--- Pitches a camp for src at coords (takes one kit). skipDistance: trusted callers only.
--- → true, id | false, err, arg
function Camps.Place(src, coords, heading, skipDistance)
    return locked(Camps.CitizenId(src), doPlace, src, coords, heading, skipDistance)
end

-- ------------------------------------------------------------
-- removing
-- ------------------------------------------------------------

local function closeViewers(storageId)
    for src, id in pairs(Camps.Allowed) do
        if id == storageId then
            Camps.Allowed[src] = nil
            pcall(function() MI:Close(src) end)
        end
    end
end

--- Takes a camp down: row, props on every client, and the chest when it was the owner's last camp.
local function removeCamp(camp, reason)
    Camps.List[camp.id] = nil
    MySQL.update.await('DELETE FROM multicamps WHERE id = ?', { camp.id })
    if #Camps.Of(camp.citizenid) == 0 then
        local sid = Camps.StorageId(camp.citizenid)
        closeViewers(sid)
        if MI:Exists(sid) then MI:Delete(sid) end
        MySQL.update.await('DELETE FROM inventories WHERE identifier = ?', { sid })
    end
    TriggerClientEvent('MULTIcamps:client:remove', -1, camp.id)
    TriggerEvent('MULTIcamps:removed', camp.id, camp.citizenid, reason)
    dbg('camp %d of %s removed (%s)', camp.id, camp.citizenid, tostring(reason))
end

--- Removes a camp without giving anything back (admins, decay, deleted characters). → bool
function Camps.Remove(id, reason)
    local camp = Camps.Get(id)
    if not camp then return false end
    removeCamp(camp, reason or 'removed')
    return true
end

local function storageStacks(sid)
    local inv = MI:Exists(sid)
    local out = {}
    if not inv or type(inv.items) ~= 'table' then return out end
    for _, s in pairs(inv.items) do
        if type(s) == 'table' and s.name and (tonumber(s.amount) or 0) > 0 then
            out[#out + 1] = { name = s.name, amount = tonumber(s.amount), info = s.info, slot = tonumber(s.slot) }
        end
    end
    return out
end

local function doPack(src, id)
    local camp = Camps.Get(id)
    if not camp then return false, 'no_camp' end
    if not Camps.IsOwner(src, camp) then return false, 'not_owner' end
    local pinv = MI:PlayerInv(src)
    local sid = Camps.StorageId(camp.citizenid)
    local lastCamp = #Camps.Of(camp.citizenid) <= 1
    local stacks = lastCamp and storageStacks(sid) or {}
    if #stacks > 0 and not Config.Storage.PackMovesToSatchel then return false, 'not_empty' end

    -- the kit and every chest stack must fit in the satchel; anything added is taken back if one does not
    local added = {}
    local function rollback()
        for i = #added, 1, -1 do
            local a = added[i]
            MI:RemoveItem(pinv, a.name, a.amount, nil, a.info, 'multicamps:rollback')
        end
    end
    local function give(name, amount, info)
        local ok = MI:AddItem(pinv, name, amount, info, nil, 'multicamps:pack')
        if ok then added[#added + 1] = { name = name, amount = amount, info = info } end
        return ok
    end
    if not give(Config.KitItem, 1, nil) then return false, 'no_room' end
    if #stacks > 0 then
        closeViewers(sid)
        for _, s in ipairs(stacks) do
            if not give(s.name, s.amount, s.info) then
                rollback()
                return false, 'no_room'
            end
        end
        for _, s in ipairs(stacks) do MI:RemoveItem(sid, s.name, s.amount, s.slot, nil, 'multicamps:pack') end
    end
    removeCamp(camp, 'packed')
    return true, #stacks
end

--- Packs a camp up: the owner gets the kit back (and the chest contents, see Config.Storage).
--- → true, stacksMoved | false, err
function Camps.Pack(src, id)
    return locked(Camps.CitizenId(src), doPack, src, id)
end

-- ------------------------------------------------------------
-- fire, sharing, resting
-- ------------------------------------------------------------

function Camps.SetFire(src, id, lit)
    local camp = Camps.Get(id)
    if not camp then return false, 'no_camp' end
    if not Camps.CanUseStorage(src, camp) then return false, 'not_owner' end
    lit = lit and true or false
    if camp.lit == lit then return true end
    camp.lit = lit
    MySQL.update.await('UPDATE multicamps SET fire_lit = ? WHERE id = ?', { lit and 1 or 0, camp.id })
    broadcast(camp)
    return true
end

function Camps.SetShared(src, id, on)
    if not Config.GangSharing then return false, 'sharing_off' end
    local camp = Camps.Get(id)
    if not camp then return false, 'no_camp' end
    if not Camps.IsOwner(src, camp) then return false, 'not_owner' end
    local gang = gangOf(Camps.GetPlayer(src))
    if on and not gang then return false, 'no_gang' end
    camp.shared = on and true or false
    camp.gang = gang
    MySQL.update.await('UPDATE multicamps SET shared = ?, gang = ? WHERE id = ?', { camp.shared and 1 or 0, gang, camp.id })
    if not camp.shared then
        -- gang members who have the chest open lose it
        local sid = Camps.StorageId(camp.citizenid)
        for s, open in pairs(Camps.Allowed) do
            if open == sid and Camps.CitizenId(s) ~= camp.citizenid then
                Camps.Allowed[s] = nil
                pcall(function() MI:Close(s) end)
            end
        end
    end
    return true, camp.shared
end

--- A rest in the tent. → true, bonus (table { health, stamina, skipHours } or false while on cooldown) | false, err
function Camps.Rest(src, id)
    if not Config.Sleep.Enabled then return false, 'sleep_off' end
    local camp = Camps.Get(id)
    if not camp then return false, 'no_camp' end
    if not Camps.CanUseStorage(src, camp) then return false, 'not_owner' end
    local cid = Camps.CitizenId(src)
    local now = os.time()
    local last = Camps.Rested[cid]
    if last and now - last < Config.Sleep.CooldownMinutes * 60 then return true, false end
    Camps.Rested[cid] = now
    if Camps.IsOwner(src, camp) then Camps.Visit(camp) end
    return true, { health = Config.Sleep.HealthCore, stamina = Config.Sleep.StaminaCore, skipHours = Config.Sleep.TimeSkipHours }
end

--- Opens the camp chest next to src's satchel. Distance is checked by the caller (net.lua) and by MULTIinventory (reach).
function Camps.OpenStorage(src, id)
    local camp = Camps.Get(id)
    if not camp then return false, 'no_camp' end
    local ok, err = Camps.CanUseStorage(src, camp)
    if not ok then return false, err end
    local sid = Camps.StorageId(camp.citizenid)
    ensureStorage(camp.citizenid, camp)
    Camps.Allowed[src] = sid
    local opened, oerr = MI:Open(src, sid)
    if not opened then
        Camps.Allowed[src] = nil
        return false, oerr or 'error'
    end
    if Camps.IsOwner(src, camp) then Camps.Visit(camp) end
    return true
end

-- A camp chest may only be opened through Camps.OpenStorage: MULTIinventory lets a client ask for
-- any stash-type id in reach, so a chest opened any other way is closed again at once.
AddEventHandler('MULTIinventory:opened', function(src, invId)
    if type(invId) ~= 'string' or invId:sub(1, #STORAGE_PREFIX) ~= STORAGE_PREFIX then return end
    if Camps.Allowed[src] == invId then return end
    pcall(function() MI:Close(src) end)
    Camps.Notify(src, 'err_not_owner', 'error')
end)
AddEventHandler('MULTIinventory:closed', function(src, invId)
    if Camps.Allowed[src] == invId then Camps.Allowed[src] = nil end
end)

-- ------------------------------------------------------------
-- decay
-- ------------------------------------------------------------

--- Removes every camp whose owner has not come by for Config.Decay.Days. → number removed
function Camps.Sweep()
    if not Config.Decay.Enabled then return 0 end
    local cutoff = os.time() - Config.Decay.Days * DAY
    local n = 0
    local list = {}
    for _, c in pairs(Camps.List) do
        if c.lastVisit < cutoff then list[#list + 1] = c end
    end
    for _, c in ipairs(list) do
        local P = RSGCore.Functions.GetPlayerByCitizenId(c.citizenid)
        removeCamp(c, 'decayed')
        if P then
            Camps.Notify(P.PlayerData.source, 'camp_decayed', 'warning', Config.Decay.Days)
        else
            MySQL.insert.await('INSERT INTO multicamps_notices (citizenid, msg, created) VALUES (?, ?, ?)',
                { c.citizenid, 'camp_decayed', os.time() })
        end
        n = n + 1
    end
    if n > 0 then dbg('%d camps decayed', n) end
    return n
end

--- Shows (and clears) the messages kept for a character while it was away. → number shown
function Camps.DeliverNotices(src, citizenid)
    local rows = MySQL.query.await('SELECT id, msg FROM multicamps_notices WHERE citizenid = ? ORDER BY id', { citizenid }) or {}
    for _, r in ipairs(rows) do
        Camps.Notify(src, r.msg, 'warning', Config.Decay.Days)
    end
    if #rows > 0 then MySQL.update.await('DELETE FROM multicamps_notices WHERE citizenid = ?', { citizenid }) end
    return #rows
end

-- owners standing at their camp count as a visit
local function visitCheck()
    for _, c in pairs(Camps.List) do
        local P = RSGCore.Functions.GetPlayerByCitizenId(c.citizenid)
        if P then
            local pos = Camps.PlayerPos(P.PlayerData.source)
            if pos and #(vector3(pos.x, pos.y, pos.z) - vector3(c.x, c.y, c.z)) <= Config.Decay.VisitRadius then
                Camps.Visit(c)
            end
        end
    end
end

-- keeps the gang a shared camp belongs to in step with its owner
local function refreshGang(P)
    if not P then return end
    local cid = P.PlayerData.citizenid
    local gang = gangOf(P)
    for _, c in ipairs(Camps.Of(cid)) do
        if c.gang ~= gang then
            c.gang = gang
            MySQL.update.await('UPDATE multicamps SET gang = ? WHERE id = ?', { gang, c.id })
        end
    end
end
Camps.RefreshGang = refreshGang

AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    if not Camps.ready or not P then return end
    local src, cid = P.PlayerData.source, P.PlayerData.citizenid
    CreateThread(function()
        refreshGang(P)
        Camps.DeliverNotices(src, cid)
    end)
end)

AddEventHandler('RSGCore:Server:OnGangUpdate', function(src)
    if not Camps.ready then return end
    refreshGang(Camps.GetPlayer(src))
end)

AddEventHandler('MULTIcore:characterDeleted', function(_, citizenid)
    for _, c in ipairs(Camps.Of(citizenid)) do removeCamp(c, 'character_deleted') end
    MySQL.update.await('DELETE FROM multicamps_notices WHERE citizenid = ?', { citizenid })
end)

AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    Camps.Allowed[src] = nil
end)
AddEventHandler('playerDropped', function()
    Camps.Allowed[source] = nil
    Camps.TestCoords[source] = nil
end)

-- ------------------------------------------------------------
-- start
-- ------------------------------------------------------------

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `multicamps` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `owner_name` VARCHAR(100) DEFAULT NULL,
        `x` DOUBLE NOT NULL,
        `y` DOUBLE NOT NULL,
        `z` DOUBLE NOT NULL,
        `heading` DOUBLE NOT NULL DEFAULT 0,
        `fire_lit` TINYINT(1) NOT NULL DEFAULT 1,
        `shared` TINYINT(1) NOT NULL DEFAULT 0,
        `gang` VARCHAR(50) DEFAULT NULL,
        `created` INT NOT NULL DEFAULT 0,
        `last_visit` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multicamps_notices` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `msg` VARCHAR(64) NOT NULL,
        `created` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function onKitUse(src)
    local cid = Camps.CitizenId(src)
    if not cid then return end
    if #Camps.Of(cid) >= Config.MaxCampsPerCharacter then return Camps.Notify(src, 'err_limit', 'error') end
    TriggerClientEvent('MULTIcamps:client:startPlace', src)
end

CreateThread(function()
    local t = 0
    while not (GetResourceState('MULTIinventory') == 'started' and MI:IsReady()) and t < 600 do Wait(100) t = t + 1 end
    for _, q in ipairs(SCHEMA) do MySQL.query.await(q) end
    for name, def in pairs(Config.NewItems or {}) do
        if not MI:GetItemDef(name) then MI:RegisterItem(def) end
    end
    if MI:GetItemDef(Config.KitItem) then
        MI:RegisterUsable(Config.KitItem, function(src) onKitUse(src) end)
    else
        print(('^1[MULTIcamps] kit item "%s" is not in the item registry; camps cannot be pitched^7'):format(Config.KitItem))
    end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM multicamps') or {}) do
        local c = decode(row)
        Camps.List[c.id] = c
    end
    Camps.ready = true
    local n = 0
    for _ in pairs(Camps.List) do n = n + 1 end
    print(('[MULTIcamps] %d camps loaded'):format(n))
    Camps.Sweep()
    TriggerClientEvent('MULTIcamps:client:reload', -1)
end)

CreateThread(function()
    while not Camps.ready do Wait(500) end
    local nextSweep = os.time() + Config.Decay.SweepMinutes * 60
    while true do
        Wait(Config.Decay.VisitCheckMinutes * 60000)
        visitCheck()
        if os.time() >= nextSweep then
            nextSweep = os.time() + Config.Decay.SweepMinutes * 60
            Camps.Sweep()
        end
    end
end)

-- ------------------------------------------------------------
-- exports (server-trusted: callers check the rules they need)
-- ------------------------------------------------------------

local function copy(c)
    if not c then return nil end
    return {
        id = c.id, citizenid = c.citizenid, ownerName = c.ownerName, x = c.x, y = c.y, z = c.z, heading = c.heading,
        lit = c.lit, shared = c.shared, gang = c.gang, created = c.created, lastVisit = c.lastVisit,
        storage = Camps.StorageId(c.citizenid),
    }
end

local function cidOf(who)
    if type(who) == 'number' then return Camps.CitizenId(who) end
    return who
end

exports('IsReady', function() return Camps.ready end)
--- One camp. → { id, citizenid, ownerName, x, y, z, heading, lit, shared, gang, created, lastVisit, storage } | nil
exports('GetCamp', function(id) return copy(Camps.Get(id)) end)
--- A character's camps (server id or citizenid). → list
exports('GetCamps', function(who)
    local out = {}
    if who == nil then
        for _, c in pairs(Camps.List) do out[#out + 1] = copy(c) end
    else
        for _, c in ipairs(Camps.Of(cidOf(who))) do out[#out + 1] = copy(c) end
    end
    return out
end)
--- The nearest camp to coords within dist. → camp | nil
exports('GetCampAt', function(coords, dist) return copy((Camps.NearestTo(coords, tonumber(dist) or Config.ServerUseDistance))) end)
exports('GetStorageId', function(who) local cid = cidOf(who) return cid and Camps.StorageId(cid) or nil end)
exports('CanPlace', function(src, coords) return Camps.CheckPlace(Camps.CitizenId(src), coords, nil) end)
exports('Place', function(src, coords, heading) return Camps.Place(src, coords, heading, true) end)
exports('PackUp', function(src, id) return Camps.Pack(src, id) end)
exports('RemoveCamp', function(id, reason) return Camps.Remove(id, reason) end)
exports('SetFire', function(src, id, lit) return Camps.SetFire(src, id, lit) end)
exports('SetShared', function(src, id, on) return Camps.SetShared(src, id, on) end)
exports('CanUseStorage', function(src, id) return Camps.CanUseStorage(src, id) end)
exports('OpenStorage', function(src, id) return Camps.OpenStorage(src, id) end)
exports('Sweep', function() return Camps.Sweep() end)

if GetConvar('multicore_selftest', 'false') == 'true' then
    exports('_TestSetCoords', function(src, x, y, z)
        Camps.TestCoords[tonumber(src)] = x and vector3(x + 0.0, y + 0.0, z + 0.0) or nil
        return true
    end)
    exports('_TestAge', function(id, days)
        local c = Camps.Get(id)
        if not c then return false end
        c.lastVisit = os.time() - math.floor(days * DAY)
        MySQL.update.await('UPDATE multicamps SET last_visit = ? WHERE id = ?', { c.lastVisit, c.id })
        return true
    end)
    exports('_TestPlace', function(src, coords, heading) return Camps.Place(src, coords, heading, false) end)
    exports('_TestRest', function(src, id) return Camps.Rest(src, id) end)
    exports('_TestResetRest', function(cid) Camps.Rested[cid] = nil return true end)
    exports('_TestNotices', function(cid, src) return Camps.DeliverNotices(src or 0, cid) end)
    exports('_TestAllowed', function(src) return Camps.Allowed[tonumber(src)] end)
end
