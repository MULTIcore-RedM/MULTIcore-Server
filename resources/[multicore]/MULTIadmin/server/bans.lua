-- ============================================================
-- MULTIadmin :: bans
-- Own table `multicore_bans` (made on start, also in sql/multiadmin.sql).
-- A ban matches on any of license, license2, steam, discord or fivem id.
-- ============================================================

Admin.Bans = {}
local Bans = Admin.Bans

local ID_TYPES = { 'license', 'license2', 'steam', 'discord', 'fivem' }
local ready = false

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multicore_bans` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(100) NULL,
            `license` VARCHAR(80) NULL,
            `license2` VARCHAR(80) NULL,
            `steam` VARCHAR(80) NULL,
            `discord` VARCHAR(80) NULL,
            `fivem` VARCHAR(80) NULL,
            `reason` VARCHAR(255) NOT NULL DEFAULT '',
            `expire` BIGINT NOT NULL DEFAULT 0,
            `bannedby` VARCHAR(100) NOT NULL DEFAULT '',
            `created` BIGINT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `license` (`license`),
            KEY `steam` (`steam`),
            KEY `discord` (`discord`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    ready = true
end)

local function identifiers(src)
    local ids = {}
    for _, t in ipairs(ID_TYPES) do
        ids[t] = GetPlayerIdentifierByType(src, t)
    end
    return ids
end

local function untilText(expire)
    if expire == 0 then return _L('ban_permanent') end
    return os.date(Config.DateFormat, expire)
end
Bans.UntilText = untilText

--- The active ban row for these identifiers, or nil.
function Bans.Find(ids)
    local where, params = {}, {}
    for _, t in ipairs(ID_TYPES) do
        if ids[t] then
            where[#where + 1] = ('`%s` = ?'):format(t)
            params[#params + 1] = ids[t]
        end
    end
    if #where == 0 then return nil end
    params[#params + 1] = os.time()
    return MySQL.single.await(('SELECT * FROM multicore_bans WHERE (%s) AND (expire = 0 OR expire > ?) ORDER BY id DESC LIMIT 1')
        :format(table.concat(where, ' OR ')), params)
end

--- Bans an online player. hours = 0 is permanent. Returns the ban id.
function Bans.Add(target, hours, reason, by)
    local ids = identifiers(target)
    hours = math.max(0, math.floor(tonumber(hours) or 0))
    local now = os.time()
    local expire = hours == 0 and 0 or now + hours * 3600
    local id = MySQL.insert.await([[INSERT INTO multicore_bans
        (name, license, license2, steam, discord, fivem, reason, expire, bannedby, created)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        GetPlayerName(target) or '?', ids.license, ids.license2, ids.steam, ids.discord, ids.fivem,
        reason, expire, by, now,
    })
    return id, expire
end

function Bans.Remove(id)
    return (MySQL.update.await('DELETE FROM multicore_bans WHERE id = ?', { id }) or 0) > 0
end

function Bans.ListActive()
    local rows = MySQL.query.await('SELECT id, name, license, steam, discord, reason, expire, bannedby, created FROM multicore_bans WHERE expire = 0 OR expire > ? ORDER BY id DESC LIMIT ?', { os.time(), Config.BanListLimit }) or {}
    for _, r in ipairs(rows) do
        r.untilText = untilText(tonumber(r.expire) or 0)
        r.createdText = os.date(Config.DateFormat, tonumber(r.created) or 0)
    end
    return rows
end

function Bans.Message(row)
    return _L('ban_message', row.reason or '', untilText(tonumber(row.expire) or 0), tonumber(row.id) or 0)
end

-- Refuse banned players while they connect
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(_L('ban_checking'))
    local giveUp = GetGameTimer() + Config.BanDbWaitMs
    while not ready and GetGameTimer() < giveUp do Wait(0) end
    local ok, row = pcall(Bans.Find, identifiers(src))
    if ok and row then
        print(('^3[MULTIadmin]^7 refused banned player %s (ban %d)'):format(GetPlayerName(src) or '?', row.id))
        deferrals.done(Bans.Message(row))
        return
    end
    deferrals.done()
end)
