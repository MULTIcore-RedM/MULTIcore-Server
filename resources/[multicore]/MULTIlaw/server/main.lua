-- ============================================================
-- MULTIlaw :: server core
-- Shared helpers, the law check, tables and the place lookups.
-- Everything that changes money, items or state is decided here; the
-- client only asks. GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
AddEventHandler('RSGCore:Server:UpdateObject', function()
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

Law = {}
Law.SELFTEST = GetConvar('multicore_selftest', 'false') == 'true'
Law.ready = false

function Law.Core() return RSGCore end

function Law.dbg(...)
    if Config.Debug then print('^5[MULTIlaw]^7', ...) end
end

---------------------------------
-- players
---------------------------------
function Law.getP(src)
    src = tonumber(src)
    return src and RSGCore.Functions.GetPlayer(src) or nil
end

function Law.byCid(cid)
    if type(cid) ~= 'string' then return nil end
    return RSGCore.Functions.GetPlayerByCitizenId(cid)
end

function Law.srcOf(P) return P and P.PlayerData and P.PlayerData.source end
function Law.cidOf(P) return P and P.PlayerData and P.PlayerData.citizenid end

function Law.nameOf(P)
    local ci = P and P.PlayerData and P.PlayerData.charinfo or {}
    local n = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or tostring(Law.cidOf(P) or '?')
end

function Law.nameFromCharinfo(ci)
    if type(ci) == 'string' then ci = json.decode(ci) end
    ci = type(ci) == 'table' and ci or {}
    local n = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return n ~= '' and n or nil
end

---------------------------------
-- answers
---------------------------------
function Law.fail(key, ...) return { ok = false, err = key, msg = _L(key, ...) } end
function Law.okRes(key, ...) return { ok = true, msg = key and _L(key, ...) or nil } end

function Law.notify(src, text, kind)
    if not src or not text then return end
    exports.MULTIcore:Notify(src, { text = text, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end

--- tells the player the outcome of an answer table (msg / ok)
function Law.say(src, res)
    if type(res) == 'table' and res.msg then Law.notify(src, res.msg, res.ok and 'success' or 'error') end
    return res
end

---------------------------------
-- spam guard
---------------------------------
local calls = {}
function Law.rateOk(src)
    local now = GetGameTimer()
    local c = calls[src]
    if not c or now - c.t0 > Config.RateLimit.WindowMs then
        calls[src] = { t0 = now, n = 1 }
        return true
    end
    c.n = c.n + 1
    return c.n <= Config.RateLimit.Calls
end
AddEventHandler('playerDropped', function() calls[source] = nil end)

---------------------------------
-- positions (a player without a ped is only the self-test's pretend player)
---------------------------------
function Law.pedOf(src)
    local ok, ped = pcall(GetPlayerPed, tonumber(src))
    return ok and ped or 0
end

function Law.coordsOf(src)
    local ped = Law.pedOf(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

--- true when both players stand within dist of each other
function Law.playersNear(a, b, dist)
    if not Config.ServerDistanceCheck then return true end
    local pa, pb = Law.coordsOf(a), Law.coordsOf(b)
    if not pa or not pb then return Law.SELFTEST end
    return #(pa - pb) <= dist
end

--- true when the player stands within dist of coords
function Law.near(src, coords, dist)
    if not Config.ServerDistanceCheck then return true end
    local p = Law.coordsOf(src)
    if not p then return Law.SELFTEST end
    return #(p - vector3(coords.x, coords.y, coords.z)) <= dist
end

---------------------------------
-- who is the law
---------------------------------
function Law.IsAdmin(src)
    src = tonumber(src)
    if not src then return false end
    if IsPlayerAceAllowed(src, 'command') then return true end
    local ok, res = pcall(RSGCore.Functions.HasPermission, src, Config.AdminPermission)
    return ok and res == true
end

--- the player's job if it is a law job type (on duty or not)
function Law.LawJob(P)
    local job = P and P.PlayerData and P.PlayerData.job
    if not job or not Config.LawTypes[job.type or ''] then return nil end
    return job
end

--- may this player use the law tool `action` right now? → true | false, errKey
function Law.Can(P, action)
    if not P then return false, 'failed' end
    local job = Law.LawJob(P)
    if not job then return false, 'not_law' end
    local allowed = Config.Permissions[action]
    if not allowed or not allowed[job.type] then return false, 'not_allowed' end
    if Config.RequireOnDuty and not job.onduty then return false, 'off_duty' end
    return true
end

--- server ids of law on duty (types = set of job types, nil = every law type)
function Law.OnDuty(types)
    local out = {}
    for _, s in ipairs(RSGCore.Functions.GetPlayers() or {}) do
        local P = Law.getP(s)
        local job = P and Law.LawJob(P)
        if job and job.onduty and (not types or types[job.type]) then out[#out + 1] = tonumber(s) end
    end
    return out
end

---------------------------------
-- places
---------------------------------
function Law.OfficeById(id)
    for _, o in ipairs(Config.Offices) do if o.id == id then return o end end
end

--- the office the player stands at (one he may use), or nil
function Law.OfficeAt(src, P)
    local job = Law.LawJob(P)
    for _, o in ipairs(Config.Offices) do
        if (Config.OfficesOpenToAllLaw or (job and job.name == o.job)) and Law.near(src, o.coords, Config.CloseDistance) then
            -- with no ped (self-test) the first allowed office answers
            return o
        end
    end
end

--- where the evidence of this lawman goes
function Law.EvidenceOffice(P)
    local job = Law.LawJob(P)
    for _, o in ipairs(Config.Offices) do
        if job and o.job == job.name then return o end
    end
    return Law.OfficeById(Config.DefaultEvidenceOffice) or Config.Offices[1]
end

function Law.EvidenceId(office) return 'stash:' .. Config.Evidence.Prefix .. office.id end

--- MULTIbank account for money of this lawman ('job' = his job's account)
function Law.AccountFor(P, setting)
    if setting == 'job' then
        local job = Law.LawJob(P)
        return job and job.name or nil
    end
    return setting
end

function Law.Bank(fn, ...)
    if GetResourceState('MULTIbank') ~= 'started' then return nil end
    local args = { ... }
    local ok, res = pcall(function() return exports.MULTIbank[fn](exports.MULTIbank, table.unpack(args)) end)
    if not ok then print(('^1[MULTIlaw] MULTIbank %s failed: %s^7'):format(fn, tostring(res))) return nil end
    return res
end

---------------------------------
-- small parsers
---------------------------------
function Law.money(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.floor(v * 100 + 0.5) / 100
end

function Law.int(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.floor(v)
end

function Law.text(s, max)
    if type(s) ~= 'string' and type(s) ~= 'number' then return '' end
    s = tostring(s):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return s:sub(1, max or 120)
end

function Law.fmt(n) return ('%.2f'):format(tonumber(n) or 0) end

---------------------------------
-- tables
---------------------------------
local schema = {
    [[CREATE TABLE IF NOT EXISTS `multilaw_jail` (
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `place` VARCHAR(20) NOT NULL DEFAULT 'prison',
        `cell` VARCHAR(50) DEFAULT NULL,
        `minutes` INT NOT NULL DEFAULT 0,
        `release_at` BIGINT NOT NULL DEFAULT 0,
        `released` TINYINT(1) NOT NULL DEFAULT 0,
        `items_taken` TINYINT(1) NOT NULL DEFAULT 0,
        `officer` VARCHAR(100) DEFAULT NULL,
        `reason` VARCHAR(200) DEFAULT NULL,
        `jailed_at` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multilaw_fines` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `amount` DECIMAL(12,2) NOT NULL DEFAULT 0,
        `reason` VARCHAR(200) NOT NULL DEFAULT '',
        `account` VARCHAR(50) NOT NULL DEFAULT '',
        `officer_cid` VARCHAR(50) DEFAULT NULL,
        `officer` VARCHAR(100) DEFAULT NULL,
        `created_at` BIGINT NOT NULL DEFAULT 0,
        `paid_at` BIGINT DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multilaw_bounties` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `reward` DECIMAL(12,2) NOT NULL DEFAULT 0,
        `reason` VARCHAR(200) NOT NULL DEFAULT '',
        `account` VARCHAR(50) NOT NULL DEFAULT '',
        `poster_cid` VARCHAR(50) DEFAULT NULL,
        `poster` VARCHAR(100) DEFAULT NULL,
        `created_at` BIGINT NOT NULL DEFAULT 0,
        `expires_at` BIGINT NOT NULL DEFAULT 0,
        `status` VARCHAR(12) NOT NULL DEFAULT 'open',
        `claimed_by` VARCHAR(100) DEFAULT NULL,
        `closed_at` BIGINT DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multilaw_records` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `citizenid` VARCHAR(50) NOT NULL,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `kind` VARCHAR(20) NOT NULL,
        `detail` VARCHAR(200) NOT NULL DEFAULT '',
        `amount` DECIMAL(12,2) DEFAULT NULL,
        `minutes` INT DEFAULT NULL,
        `officer` VARCHAR(100) DEFAULT NULL,
        `created_at` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `name` (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

--- waits until the tables exist and the saved state is loaded
function Law.WaitReady(maxMs)
    local t = 0
    while not Law.ready and t < (maxMs or 30000) do Wait(100) t = t + 100 end
    return Law.ready
end

local readyHooks = {}
function Law.OnReady(fn) readyHooks[#readyHooks + 1] = fn end

CreateThread(function()
    for _, q in ipairs(schema) do MySQL.query.await(q) end
    -- wait for MULTIinventory (evidence lockers, jail item stashes)
    local t = 0
    while GetResourceState('MULTIinventory') == 'started' and not exports.MULTIinventory:IsReady() and t < 600 do Wait(100) t = t + 1 end
    for _, fn in ipairs(readyHooks) do
        local ok, err = pcall(fn)
        if not ok then print(('^1[MULTIlaw] start step failed: %s^7'):format(tostring(err))) end
    end
    Law.ready = true
    Law.dbg('ready')
end)

-- evidence lockers: one stash per office, made with the configured size
Law.OnReady(function()
    if GetResourceState('MULTIinventory') ~= 'started' then return end
    for _, o in ipairs(Config.Offices) do
        local id = Law.EvidenceId(o)
        local data = { label = _L('evidence_label', _L(o.label)), slots = Config.Evidence.Slots, maxWeight = Config.Evidence.MaxWeight, coords = o.coords }
        if exports.MULTIinventory:Exists(id) then exports.MULTIinventory:Configure(id, data) else exports.MULTIinventory:Create(id, data) end
    end
end)

-- handcuff item: MULTIcore's item list already has 'handcuffs'; register it only when missing
Law.OnReady(function()
    if GetResourceState('MULTIinventory') ~= 'started' or Config.Cuff.Item == '' then return end
    if not exports.MULTIinventory:GetItemDef(Config.Cuff.Item) then
        exports.MULTIinventory:RegisterItem({
            name = Config.Cuff.Item, label = _L('item_handcuffs'), weight = 100, type = 'item', image = 'handcuffs.png',
            unique = false, useable = true, shouldClose = true, description = _L('item_handcuffs_desc'),
        })
    end
end)
