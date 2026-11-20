-- ============================================================
-- MULTIjobs :: server
-- Held jobs (multi-job), job centre, boss menu, gang menu and duty.
-- Every check is made here; the pages only ask.
--
-- Held jobs live in the character's metadata.vorp.multijobs
-- ({ [job] = { grade = n, label = '...' } }), the same list MULTIcore's
-- VORP face hands out as character.multiJobs, so VORP's setMultiJob /
-- removeMultiJob and this menu change the same thing. The active job is
-- always one of them (or 'unemployed').
-- GPL v3. Shapes of the rsg-bossmenu / rsg-gangmenu / rsg-multijob calls
-- follow the RSG v2 framework (GPL v3); the code is MULTIjobs' own.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
AddEventHandler('RSGCore:Server:UpdateObject', function()
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

MJ = {}
local SELFTEST = GetConvar('multicore_selftest', 'false') == 'true'

local ready = {}       -- src -> true once the held-jobs list was checked at login
local maxCache = {}    -- src -> most jobs this account may hold
local mirrorSig = {}   -- src -> last held-jobs list written to player_jobs
local lastSwitch = {}  -- src -> GetGameTimer() of the last job switch
local lastTake = {}    -- src -> GetGameTimer() of the last job-centre hire
local calls = {}       -- src -> { t0, n } spam guard

local function dbg(...)
    if Config.Debug then print('^5[MULTIjobs]^7', ...) end
end

---------------------------------
-- small helpers
---------------------------------
local function Jobs() return RSGCore.Shared.Jobs end
local function Gangs() return RSGCore.Shared.Gangs end
local function getP(src) return RSGCore.Functions.GetPlayer(tonumber(src)) end
local function byCid(cid) return RSGCore.Functions.GetPlayerByCitizenId(cid) end

local function count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function validName(s)
    return type(s) == 'string' and #s > 0 and #s <= 50 and s:match('^[%w_%-]+$') ~= nil
end

local function int(n)
    n = tonumber(n)
    if not n or n ~= n then return nil end
    if n == math.floor(n) then return math.tointeger(n) end
    return n
end

local function fullName(ci)
    ci = ci or {}
    local s = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return s ~= '' and s or _L('unknown')
end

local function decode(s)
    if type(s) == 'table' then return s end
    if type(s) ~= 'string' or s == '' then return {} end
    local ok, v = pcall(json.decode, s)
    return ok and type(v) == 'table' and v or {}
end

function MJ.Notify(src, text, kind)
    exports.MULTIcore:Notify(src, { text = text, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end
local notify = MJ.Notify

local function fail(key, ...) return { ok = false, err = key, msg = _L(key, ...) } end
local function okRes(key, ...) return { ok = true, msg = key and _L(key, ...) or nil } end

local function rateOk(src)
    local now = GetGameTimer()
    local c = calls[src]
    if not c or now - c.t0 > Config.RateLimit.WindowMs then
        calls[src] = { t0 = now, n = 1 }
        return true
    end
    c.n = c.n + 1
    return c.n <= Config.RateLimit.Calls
end

local function pedOf(src)
    local ok, ped = pcall(GetPlayerPed, src)
    return ok and ped or 0
end

--- true when the player stands within `dist` of `coords`. A player without a ped
--- (only the self-test's pretend players) passes only in self-test mode.
local function near(src, coords, dist)
    if not Config.ServerDistanceCheck then return true end
    local ped = pedOf(src)
    if not ped or ped == 0 then return SELFTEST end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.MaxUseDistance)
end

local function playersNear(a, b, dist)
    if not Config.ServerDistanceCheck then return true end
    local pa, pb = pedOf(a), pedOf(b)
    if pa == 0 or pb == 0 then return SELFTEST end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb)) <= dist
end

local function nearAny(src, list, key, value)
    local any = false
    for _, p in ipairs(list) do
        if value == nil or p[key] == value then
            any = true
            if near(src, p.coords) then return true, true end
        end
    end
    return false, any
end

---------------------------------
-- jobs, gangs, grades
---------------------------------
local function gradeOf(kind, org, level)
    local def = (kind == 'job' and Jobs() or Gangs())[org]
    return def and def.grades and def.grades[tostring(level)] or nil
end

local function gradeList(kind, org)
    local def = (kind == 'job' and Jobs() or Gangs())[org]
    local out = {}
    if not def then return out end
    for k, g in pairs(def.grades or {}) do
        local lvl = tonumber(k)
        if lvl then out[#out + 1] = { level = lvl, name = g.name or tostring(lvl), payment = int(g.payment) or 0, isboss = g.isboss == true } end
    end
    table.sort(out, function(a, b) return a.level < b.level end)
    return out
end

--- The player's job or gang: name, grade level, boss?, label
local function orgOf(P, kind)
    if kind == 'job' then
        local j = P.PlayerData.job or {}
        local lvl = tonumber(j.grade and j.grade.level) or 0
        local g = gradeOf('job', j.name, lvl)
        local def = Jobs()[j.name]
        return j.name, lvl, g ~= nil and g.isboss == true, def and def.label or j.label or j.name
    end
    local gg = P.PlayerData.gang or {}
    local lvl = tonumber(gg.grade and gg.grade.level) or 0
    local g = gradeOf('gang', gg.name, lvl)
    local def = Gangs()[gg.name]
    return gg.name, lvl, g ~= nil and g.isboss == true, def and def.label or gg.label or gg.name
end

---------------------------------
-- held jobs (metadata.vorp.multijobs)
---------------------------------
local function vorpMeta(P)
    local m = P.PlayerData.metadata or {}
    local v = type(m.vorp) == 'table' and m.vorp or {}
    if type(v.multijobs) ~= 'table' then v.multijobs = {} end
    return v
end
local function heldOf(P) return vorpMeta(P).multijobs end

local function saveHeld(P, held)
    local v = vorpMeta(P)
    v.multijobs = held
    P.Functions.SetMetaData('vorp', v)
end

--- Reads the account's job limit (MULTIcore account, VORP maxJobsAllowed).
local function readMax(src)
    local ok, n = pcall(function()
        local user = exports.vorp_core:GetCore().getUser(src)
        return user and user.maxJobsAllowed
    end)
    n = ok and tonumber(n) or nil
    return n or Config.MultiJob.FallbackMaxJobs
end
local function maxJobs(src)
    if not maxCache[src] then maxCache[src] = readMax(src) end
    return maxCache[src]
end
MJ.MaxJobs = maxJobs

local function listed(job) return validName(job) and not Config.MultiJob.NotListed[job] end

---------------------------------
-- player_jobs mirror (RSG's multijob table)
---------------------------------
local function signature(held)
    local keys = {}
    for job, h in pairs(held or {}) do keys[#keys + 1] = job .. '=' .. tostring(tonumber(h.grade) or 0) end
    table.sort(keys)
    return table.concat(keys, ';')
end

-- Writes are queued per character and done row by row on the exact key (no "delete all and
-- insert again" transaction, which deadlocked when several changes came in at once).
local mirrorRows = {}  -- citizenid -> { [job] = grade } as the table holds it now
local mirrorBusy = {}  -- citizenid -> true while a write runs
local mirrorNext = {}  -- citizenid -> newest list waiting for the running write

local function mirrorWrite(cid, held)
    if not Config.MultiJob.MirrorPlayerJobsTable or not cid then return end
    local want = {}
    for job, h in pairs(held or {}) do want[job] = tonumber(h.grade) or 0 end
    if mirrorBusy[cid] then mirrorNext[cid] = want return end
    mirrorBusy[cid] = true
    CreateThread(function()
        while want do
            local have = mirrorRows[cid]
            if not have then
                have = {}
                for _, r in ipairs(MySQL.query.await('SELECT `job`, `grade` FROM `player_jobs` WHERE `citizenid` = ?', { cid }) or {}) do
                    have[r.job] = tonumber(r.grade) or 0
                end
            end
            for job in pairs(have) do
                if want[job] == nil then
                    MySQL.update.await('DELETE FROM `player_jobs` WHERE `citizenid` = ? AND `job` = ?', { cid, job })
                end
            end
            for job, grade in pairs(want) do
                if have[job] ~= grade then
                    MySQL.insert.await('INSERT INTO `player_jobs` (`citizenid`, `job`, `grade`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `grade` = VALUES(`grade`)',
                        { cid, job, grade })
                end
            end
            mirrorRows[cid] = want
            want = mirrorNext[cid]
            mirrorNext[cid] = nil
        end
        mirrorBusy[cid] = nil
    end)
end
--- Another script changed player_jobs rows of this character: read them again next time.
function MJ.MirrorForget(cid) if not mirrorBusy[cid] then mirrorRows[cid] = nil end end

-- any change to the held list (this script, VORP's setMultiJob, ...) is copied to player_jobs
AddEventHandler('RSGCore:Player:SetPlayerData', function(PlayerData)
    local src = PlayerData and PlayerData.source
    if not src or not ready[src] or not Config.MultiJob.MirrorPlayerJobsTable then return end
    local held = PlayerData.metadata and PlayerData.metadata.vorp and PlayerData.metadata.vorp.multijobs or {}
    local sig = signature(held)
    if sig == mirrorSig[src] then return end
    mirrorSig[src] = sig
    mirrorWrite(PlayerData.citizenid, held)
end)

local function pushRefresh(src)
    TriggerClientEvent('MULTIjobs:client:changed', src)
    if MJ.RsgJobList then
        local P = getP(src)
        if P then TriggerClientEvent('rsg-multijob:client:refreshJobs', src, MJ.RsgJobList(P.PlayerData.citizenid, P), P.PlayerData.job.name) end
    end
end
MJ.PushRefresh = pushRefresh

---------------------------------
-- login: bring the held list, player_jobs and the active job into line
---------------------------------
function MJ.Reconcile(src)
    maxCache[src] = readMax(src)
    local P = getP(src)
    if not P then return end
    local cid = P.PlayerData.citizenid
    local rows, synced = {}, false
    if Config.MultiJob.MirrorPlayerJobsTable then
        rows = MySQL.query.await('SELECT `job`, `grade` FROM `player_jobs` WHERE `citizenid` = ?', { cid }) or {}
        synced = MySQL.scalar.await('SELECT 1 FROM `multijobs_synced` WHERE `citizenid` = ?', { cid }) ~= nil
    end
    P = getP(src) -- fresh after the waits
    if not P then return end
    local held = heldOf(P)
    local max = maxJobs(src)
    local byRow = {}
    for _, r in ipairs(rows) do byRow[r.job] = tonumber(r.grade) or 0 end
    if Config.MultiJob.MirrorPlayerJobsTable and not mirrorBusy[cid] then
        local copy = {}
        for k, v in pairs(byRow) do copy[k] = v end
        mirrorRows[cid] = copy
    end
    if synced then
        -- player_jobs follows the list while online, so a difference was made by SQL while offline
        for job in pairs(held) do
            if byRow[job] == nil then held[job] = nil end
        end
    end
    for job, grade in pairs(byRow) do
        if listed(job) then
            if held[job] then
                if synced then held[job].grade = grade end
            elseif count(held) < max then
                local def = Jobs()[job]
                held[job] = { grade = grade, label = def and def.label or job }
            end
        end
    end
    local j = P.PlayerData.job or {}
    if listed(j.name) then
        local lvl = tonumber(j.grade and j.grade.level) or 0
        if held[j.name] then
            held[j.name].grade = lvl
        elseif count(held) < max then
            held[j.name] = { grade = lvl, label = j.label or j.name }
        end
    end
    saveHeld(P, held)
    if Config.MultiJob.MirrorPlayerJobsTable then
        mirrorSig[src] = signature(held)
        mirrorWrite(cid, held)
        if not synced then MySQL.insert('INSERT IGNORE INTO `multijobs_synced` (`citizenid`) VALUES (?)', { cid }) end
    end
    ready[src] = true
    dbg('reconciled', src, cid, signature(held))
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Pl)
    local src = Pl and Pl.PlayerData and Pl.PlayerData.source
    if not src then return end
    ready[src] = nil
    CreateThread(function()
        while not MJ.TablesReady do Wait(100) end
        MJ.Reconcile(src)
    end)
end)

local function forget(src)
    ready[src], maxCache[src], mirrorSig[src], lastSwitch[src], lastTake[src], calls[src] = nil, nil, nil, nil, nil, nil
end
AddEventHandler('RSGCore:Server:OnPlayerUnload', forget)
AddEventHandler('playerDropped', function() forget(source) end)

-- whatever sets a job (VORP setJob, /setjob, an RSG script, the boss menu) adds it to the held list
function MJ.SyncActive(src)
    local P = getP(src)
    if not ready[src] or not P then return end
    local job = P.PlayerData.job
    if type(job) ~= 'table' or not listed(job.name) then return end
    local lvl = tonumber(job.grade and job.grade.level) or 0
    local held = heldOf(P)
    local h = held[job.name]
    if h and tonumber(h.grade) == lvl then return end
    if not h and count(held) >= maxJobs(src) then
        notify(src, _L('max_jobs_not_kept', maxJobs(src)), 'warning')
        return
    end
    held[job.name] = { grade = lvl, label = job.label or (h and h.label) or job.name }
    saveHeld(P, held)
    pushRefresh(src)
end
AddEventHandler('RSGCore:Server:OnJobUpdate', function(src) MJ.SyncActive(src) end)

function MJ.IsReady(src) return ready[tonumber(src)] == true end

---------------------------------
-- offline characters
---------------------------------
local function loadRow(cid)
    if not validName(cid) then return nil end
    local row = MySQL.single.await('SELECT `citizenid`, `charinfo`, `job`, `gang`, `metadata` FROM `players` WHERE `citizenid` = ?', { cid })
    if not row then return nil end
    row.charinfo, row.job, row.gang, row.metadata = decode(row.charinfo), decode(row.job), decode(row.gang), decode(row.metadata)
    row.metadata.vorp = type(row.metadata.vorp) == 'table' and row.metadata.vorp or {}
    row.metadata.vorp.multijobs = type(row.metadata.vorp.multijobs) == 'table' and row.metadata.vorp.multijobs or {}
    return row
end

local function jobTable(name, lvl)
    local def = Jobs()[name] or {}
    local g = def.grades and def.grades[tostring(lvl)] or {}
    return {
        name = name, label = def.label or name, type = def.type or 'none',
        onduty = def.defaultDuty == true, payment = g.payment or 0, isboss = g.isboss == true,
        grade = { name = g.name or tostring(lvl), level = lvl, payment = g.payment or 0, isboss = g.isboss == true },
    }
end

local function gangTable(name, lvl)
    local def = Gangs()[name] or {}
    local g = def.grades and def.grades[tostring(lvl)] or {}
    return {
        name = name, label = def.label or name, isboss = g.isboss == true,
        grade = { name = g.name or tostring(lvl), level = lvl, isboss = g.isboss == true },
    }
end

local function saveRow(row, cols)
    local sets, vals = {}, {}
    for _, c in ipairs(cols) do
        sets[#sets + 1] = ('`%s` = ?'):format(c)
        vals[#vals + 1] = json.encode(row[c])
    end
    vals[#vals + 1] = row.citizenid
    MySQL.update.await(('UPDATE `players` SET %s WHERE `citizenid` = ?'):format(table.concat(sets, ', ')), vals)
    if table.concat(cols, ','):find('metadata') then mirrorWrite(row.citizenid, row.metadata.vorp.multijobs) end
end

---------------------------------
-- members of a job or gang (online and offline)
---------------------------------
local function members(kind, org)
    local out, seen = {}, {}
    for _, s in ipairs(RSGCore.Functions.GetPlayers() or {}) do
        local P = getP(s)
        if P then
            local d = P.PlayerData
            local entry
            if kind == 'job' then
                local active = d.job and d.job.name == org
                local h = heldOf(P)[org]
                if active or h then
                    local lvl = active and (tonumber(d.job.grade.level) or 0) or (tonumber(h.grade) or 0)
                    entry = { active = active, onduty = active and d.job.onduty == true, grade = lvl }
                end
            elseif d.gang and d.gang.name == org then
                entry = { active = true, grade = tonumber(d.gang.grade and d.gang.grade.level) or 0 }
            end
            if entry then
                local g = gradeOf(kind, org, entry.grade)
                entry.cid, entry.name, entry.online, entry.src = d.citizenid, fullName(d.charinfo), true, d.source
                entry.gradeName, entry.isboss = g and g.name or tostring(entry.grade), g ~= nil and g.isboss == true
                out[#out + 1] = entry
                seen[d.citizenid] = true
            end
        end
    end
    local like = '%"' .. org .. '"%'
    local rows = kind == 'job'
        and MySQL.query.await('SELECT `citizenid`, `charinfo`, `job`, `metadata` FROM `players` WHERE `job` LIKE ? OR `metadata` LIKE ? LIMIT 500', { like, like })
        or MySQL.query.await('SELECT `citizenid`, `charinfo`, `gang` FROM `players` WHERE `gang` LIKE ? LIMIT 500', { like })
    for _, r in ipairs(rows or {}) do
        if not seen[r.citizenid] then
            local lvl, active
            if kind == 'job' then
                local j = decode(r.job)
                local md = decode(r.metadata)
                local h = md.vorp and type(md.vorp.multijobs) == 'table' and md.vorp.multijobs[org]
                active = j.name == org
                if active then lvl = tonumber(j.grade and j.grade.level) or 0
                elseif h then lvl = tonumber(h.grade) or 0 end
            else
                local g = decode(r.gang)
                if g.name == org then lvl, active = tonumber(g.grade and g.grade.level) or 0, true end
            end
            if lvl then
                local g = gradeOf(kind, org, lvl)
                out[#out + 1] = {
                    cid = r.citizenid, name = fullName(decode(r.charinfo)), online = false, active = active,
                    onduty = false, grade = lvl, gradeName = g and g.name or tostring(lvl), isboss = g ~= nil and g.isboss == true,
                }
            end
        end
    end
    table.sort(out, function(a, b)
        if a.grade ~= b.grade then return a.grade > b.grade end
        return a.name < b.name
    end)
    return out
end
MJ.Members = members

---------------------------------
-- duty
---------------------------------
function MJ.OnDuty(job)
    local list = {}
    for _, s in ipairs(RSGCore.Functions.GetPlayers() or {}) do
        local P = getP(s)
        if P and P.PlayerData.job and P.PlayerData.job.name == job and P.PlayerData.job.onduty then
            list[#list + 1] = s
        end
    end
    return list, #list
end
function MJ.DutyCount(job)
    local _, n = MJ.OnDuty(job)
    return n
end

local function setDuty(P, on)
    local src = P.PlayerData.source
    P.Functions.SetJobDuty(on)
    TriggerEvent('RSGCore:Server:SetDuty', src, on)
    TriggerClientEvent('RSGCore:Client:SetDuty', src, on)
end

--- Toggles (or sets, when `want` is a boolean) the player's duty. fromPoint = asked at a duty point.
function MJ.Duty(src, want)
    local P = getP(src)
    if not P then return fail('failed') end
    local job = P.PlayerData.job or {}
    if not listed(job.name) then return fail('no_duty_job') end
    if not Config.Duty.CommandAnywhere then
        local at, any = nearAny(src, Config.DutyPoints, 'job', job.name)
        if any and not at then return fail('duty_go_to_office') end
    end
    local on = want
    if type(on) ~= 'boolean' then on = not job.onduty end
    setDuty(P, on)
    pushRefresh(src)
    return okRes(on and 'on_duty' or 'off_duty')
end

RegisterNetEvent('MULTIjobs:server:afk', function()
    local src = source
    if (Config.Duty.AfkMinutes or 0) <= 0 then return end
    local P = getP(src)
    if not P or not (P.PlayerData.job and P.PlayerData.job.onduty) then return end
    if not listed(P.PlayerData.job.name) then return end
    setDuty(P, false)
    notify(src, _L('afk_off_duty'), 'warning')
    pushRefresh(src)
end)

---------------------------------
-- my jobs: switch, quit
---------------------------------
function MJ.Switch(src, job)
    local P = getP(src)
    if not P then return fail('failed') end
    if type(job) ~= 'string' then return fail('bad_job') end
    if P.PlayerData.job.name == job then return fail('already_active') end
    local now = GetGameTimer()
    if lastSwitch[src] and now - lastSwitch[src] < Config.MultiJob.SwitchCooldownMs then
        return fail('switch_wait', math.ceil((Config.MultiJob.SwitchCooldownMs - (now - lastSwitch[src])) / 1000))
    end
    local grade = 0
    if job ~= 'unemployed' then
        local h = heldOf(P)[job]
        if not h then return fail('not_held') end
        grade = tonumber(h.grade) or 0
    end
    if not Jobs()[job] then return fail('bad_job') end
    lastSwitch[src] = now
    if not P.Functions.SetJob(job, grade) then return fail('failed') end
    if Config.MultiJob.OffDutyOnSwitch and job ~= 'unemployed' then
        local P2 = getP(src)
        if P2 and P2.PlayerData.job.onduty then setDuty(P2, false) end
    end
    dbg('switch', src, job, grade)
    pushRefresh(src)
    return okRes('switched', Jobs()[job].label or job)
end

function MJ.Quit(src, job)
    local P = getP(src)
    if not P then return fail('failed') end
    if not listed(job) then return fail('bad_job') end
    local held = heldOf(P)
    local active = P.PlayerData.job.name == job
    if not held[job] and not active then return fail('not_held') end
    held[job] = nil
    saveHeld(P, held)
    if active then
        local P2 = getP(src)
        if P2 then P2.Functions.SetJob('unemployed', 0) end
    end
    dbg('quit', src, job)
    pushRefresh(src)
    local def = Jobs()[job]
    return okRes('quit_done', def and def.label or job)
end

function MJ.LeaveGang(src)
    if not Config.Gang.AllowLeave then return fail('not_allowed') end
    local P = getP(src)
    if not P then return fail('failed') end
    local org, _, isboss, label = orgOf(P, 'gang')
    if not org or org == 'none' then return fail('no_gang') end
    if isboss then return fail('boss_cannot_leave') end
    P.Functions.SetGang('none', 0)
    pushRefresh(src)
    return okRes('left_gang', label)
end

function MJ.MyJobsState(src)
    local P = getP(src)
    if not P then return nil end
    local d = P.PlayerData
    local list = {}
    local held = heldOf(P)
    for job, h in pairs(held) do
        local def = Jobs()[job]
        local lvl = tonumber(h.grade) or 0
        local g = gradeOf('job', job, lvl)
        list[#list + 1] = {
            job = job, label = def and def.label or h.label or job, grade = lvl,
            gradeName = g and g.name or tostring(lvl), pay = g and int(g.payment) or 0,
            active = d.job.name == job, isboss = g ~= nil and g.isboss == true, known = def ~= nil,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    local gname, glvl, gboss, glabel = orgOf(P, 'gang')
    local gg = gradeOf('gang', gname, glvl)
    return {
        jobs = list, current = d.job.name, currentLabel = (Jobs()[d.job.name] or {}).label or d.job.label,
        onduty = d.job.onduty == true, dutyJob = listed(d.job.name), max = maxJobs(src), count = count(held),
        gang = gname ~= 'none' and { name = gname, label = glabel, gradeName = gg and gg.name or '', isboss = gboss } or nil,
        canLeaveGang = Config.Gang.AllowLeave and gname ~= 'none' and not gboss,
    }
end

---------------------------------
-- job centre
---------------------------------
local function nearCentre(src)
    for i, c in ipairs(Config.JobCentres) do
        if near(src, c.coords) then return i end
    end
    return nil
end
MJ.NearCentre = nearCentre

function MJ.CentreState(src, idx)
    local P = getP(src)
    if not P then return nil end
    local held = heldOf(P)
    local list = {}
    for job, opt in pairs(Config.PublicJobs) do
        local def = Jobs()[job]
        if def then
            local grades = gradeList('job', job)
            list[#list + 1] = {
                job = job, label = def.label or job, desc = _L(opt.desc or ('desc_' .. job)),
                pay = grades[1] and grades[1].payment or 0, grades = grades,
                held = held[job] ~= nil, active = P.PlayerData.job.name == job,
            }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    local c = Config.JobCentres[idx or 0]
    return {
        centre = c and _L(c.label) or _L('centre_title'), jobs = list, count = count(held), max = maxJobs(src),
        current = P.PlayerData.job.name, currentLabel = (Jobs()[P.PlayerData.job.name] or {}).label or P.PlayerData.job.label,
    }
end

function MJ.TakeJob(src, job)
    local P = getP(src)
    if not P then return fail('failed') end
    if not nearCentre(src) then return fail('too_far') end
    if type(job) ~= 'string' or not Config.PublicJobs[job] or not Jobs()[job] then return fail('not_public') end
    if not gradeOf('job', job, 0) then return fail('bad_job') end
    local held = heldOf(P)
    if held[job] then return fail('already_held') end
    maxCache[src] = readMax(src)
    P = getP(src)
    if not P then return fail('failed') end
    held = heldOf(P)
    if count(held) >= maxJobs(src) then return fail('max_jobs', maxJobs(src)) end
    -- the cooldown only guards real hires; a refused request above never counts
    local now = GetGameTimer()
    if lastTake[src] and now - lastTake[src] < Config.TakeCooldownMs then return fail('slow_down') end
    lastTake[src] = now
    held[job] = { grade = 0, label = Jobs()[job].label }
    saveHeld(P, held)
    local P2 = getP(src)
    if not P2 or not P2.Functions.SetJob(job, 0) then return fail('failed') end
    dbg('take', src, job)
    pushRefresh(src)
    return okRes('job_taken', Jobs()[job].label)
end

function MJ.QuitActive(src)
    local P = getP(src)
    if not P then return fail('failed') end
    if not nearCentre(src) then return fail('too_far') end
    local job = P.PlayerData.job.name
    if not listed(job) then return fail('already_unemployed') end
    return MJ.Quit(src, job)
end

---------------------------------
-- boss and gang menus
---------------------------------
local function account(kind, org)
    return kind == 'job' and org or (Config.Gang.AccountPrefix .. org)
end
MJ.Account = account

local function bank(fn, ...)
    if GetResourceState('MULTIbank') ~= 'started' then return nil end
    local args = { ... }
    local ok, res = pcall(function() return exports.MULTIbank[fn](exports.MULTIbank, table.unpack(args)) end)
    if not ok then return nil end
    return res
end
MJ.Bank = bank

local function payLimits(org)
    local l = Config.BossMenu.Pay.Jobs[org] or {}
    return tonumber(l.Min) or Config.BossMenu.Pay.Min, tonumber(l.Max) or Config.BossMenu.Pay.Max
end

local function manageLimit(myGrade)
    return Config.BossMenu.SameGradeCanManage and myGrade or (myGrade - 1)
end

--- May this boss open the menu here? (job: boss desk unless Anywhere / no desk listed)
local function placeOk(src, kind, org)
    if kind == 'job' then
        if Config.BossMenu.Anywhere then return true end
        local at, any = nearAny(src, Config.BossPoints, 'job', org)
        return at or not any
    end
    if Config.Gang.Anywhere then return true end
    local at, any = nearAny(src, Config.GangPoints, 'gang', org)
    return at or not any
end

local function parseAmount(v)
    local n = tonumber(v)
    if not n or n ~= n or n <= 0 or n == math.huge then return nil end
    n = math.floor(n * 100 + 0.5) / 100
    if n <= 0 or n > Config.BossMenu.MaxMoneyMove then return nil end
    return n
end

local function bossState(src, kind)
    local P = getP(src)
    local org, lvl, _, label = orgOf(P, kind)
    local staff = members(kind, org)
    local onduty = 0
    for _, m in ipairs(staff) do if m.onduty then onduty = onduty + 1 end end
    local lo, hi = payLimits(org)
    P = getP(src)
    return {
        kind = kind, org = org, label = label, grade = lvl, gradeName = (gradeOf(kind, org, lvl) or {}).name or '',
        cid = P and P.PlayerData.citizenid, grades = gradeList(kind, org), staff = staff, onduty = onduty,
        manageUpTo = manageLimit(lvl), balance = bank('GetAccountBalance', account(kind, org)), bankOk = GetResourceState('MULTIbank') == 'started',
        cash = P and P.Functions.GetMoney('cash') or 0, payMin = lo, payMax = hi,
        stash = Config.Stash.Enabled and GetResourceState('rsg-inventory') == 'started',
    }
end

local function nearbyList(src, kind, org)
    local out = {}
    local dist = kind == 'job' and Config.BossMenu.HireDistance or Config.Gang.RecruitDistance
    for _, s in ipairs(RSGCore.Functions.GetPlayers() or {}) do
        if s ~= src and playersNear(src, s, dist) then
            local T = getP(s)
            if T then
                local d = T.PlayerData
                local inOrg = kind == 'job' and (d.job.name == org or heldOf(T)[org] ~= nil) or (d.gang and d.gang.name == org)
                if not inOrg then out[#out + 1] = { id = s, name = fullName(d.charinfo), citizenid = d.citizenid } end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end
MJ.Nearby = nearbyList

-- hire / recruit an online player close by
local function hire(src, kind, org, target)
    target = tonumber(target)
    if not target or target == src then return fail('bad_target') end
    local T = getP(target)
    if not T then return fail('not_online') end
    local dist = kind == 'job' and Config.BossMenu.HireDistance or Config.Gang.RecruitDistance
    if not playersNear(src, target, dist) then return fail('target_too_far') end
    local label = (kind == 'job' and Jobs() or Gangs())[org].label
    if kind == 'job' then
        local held = heldOf(T)
        if T.PlayerData.job.name == org or held[org] then return fail('already_staff') end
        maxCache[target] = readMax(target)
        T = getP(target)
        if not T then return fail('not_online') end
        held = heldOf(T)
        if count(held) >= maxJobs(target) then return fail('target_max_jobs') end
        held[org] = { grade = 0, label = label }
        saveHeld(T, held)
        if Config.BossMenu.HireMakesActive then
            local T2 = getP(target)
            if T2 then T2.Functions.SetJob(org, 0) end
        end
    else
        local cur = T.PlayerData.gang and T.PlayerData.gang.name or 'none'
        if cur == org then return fail('already_member') end
        if Config.Gang.RecruitOnlyUnaffiliated and cur ~= 'none' then return fail('in_other_gang') end
        if not T.Functions.SetGang(org, 0) then return fail('failed') end
    end
    local name = fullName(T.PlayerData.charinfo)
    notify(target, _L(kind == 'job' and 'you_were_hired' or 'you_were_recruited', label), 'success')
    pushRefresh(target)
    dbg('hire', kind, org, src, '->', target)
    return okRes(kind == 'job' and 'hired' or 'recruited', name, label)
end

-- find a member (online or offline) by citizenid; returns grade, online player or row
local function findMember(kind, org, cid)
    local T = byCid(cid)
    if T then
        local d = T.PlayerData
        if kind == 'job' then
            if d.job.name == org then return tonumber(d.job.grade.level) or 0, T end
            local h = heldOf(T)[org]
            if h then return tonumber(h.grade) or 0, T end
        elseif d.gang and d.gang.name == org then
            return tonumber(d.gang.grade.level) or 0, T
        end
        return nil
    end
    local row = loadRow(cid)
    if not row then return nil end
    if kind == 'job' then
        if row.job.name == org then return tonumber(row.job.grade and row.job.grade.level) or 0, nil, row end
        local h = row.metadata.vorp.multijobs[org]
        if h then return tonumber(h.grade) or 0, nil, row end
    elseif row.gang.name == org then
        return tonumber(row.gang.grade and row.gang.grade.level) or 0, nil, row
    end
    return nil
end

local function fire(src, kind, org, myGrade, cid)
    local me = getP(src)
    if type(cid) ~= 'string' then return fail('bad_target') end
    if cid == me.PlayerData.citizenid then return fail('not_self') end
    local grade, T, row = findMember(kind, org, cid)
    if not grade then return fail('not_staff') end
    if grade > manageLimit(myGrade) then return fail('rank_too_high') end
    local label = (kind == 'job' and Jobs() or Gangs())[org].label
    if T then
        local tsrc = T.PlayerData.source
        if kind == 'job' then
            local held = heldOf(T)
            held[org] = nil
            saveHeld(T, held)
            local T2 = getP(tsrc)
            if T2 and T2.PlayerData.job.name == org then T2.Functions.SetJob('unemployed', 0) end
        else
            T.Functions.SetGang('none', 0)
        end
        notify(tsrc, _L(kind == 'job' and 'you_were_fired' or 'you_were_kicked', label), 'error')
        pushRefresh(tsrc)
        return okRes(kind == 'job' and 'fired' or 'kicked', fullName(T.PlayerData.charinfo))
    end
    -- offline
    if kind == 'job' then
        row.metadata.vorp.multijobs[org] = nil
        if row.job.name == org then row.job = jobTable('unemployed', 0) end
        saveRow(row, { 'job', 'metadata' })
    else
        row.gang = gangTable('none', 0)
        saveRow(row, { 'gang' })
    end
    return okRes(kind == 'job' and 'fired' or 'kicked', fullName(row.charinfo))
end

local function setGrade(src, kind, org, myGrade, cid, newGrade)
    local me = getP(src)
    newGrade = tonumber(newGrade)
    if type(cid) ~= 'string' or not newGrade then return fail('bad_target') end
    newGrade = math.floor(newGrade)
    if cid == me.PlayerData.citizenid then return fail('not_self_grade') end
    local g = gradeOf(kind, org, newGrade)
    if not g then return fail('bad_grade') end
    local limit = manageLimit(myGrade)
    if newGrade > limit then return fail('grade_too_high') end
    local grade, T, row = findMember(kind, org, cid)
    if not grade then return fail('not_staff') end
    if grade > limit then return fail('rank_too_high') end
    if grade == newGrade then return fail('same_grade') end
    if T then
        local tsrc = T.PlayerData.source
        if kind == 'job' then
            if T.PlayerData.job.name == org then
                T.Functions.SetJob(org, newGrade)
            else
                local held = heldOf(T)
                held[org].grade = newGrade
                saveHeld(T, held)
            end
        else
            T.Functions.SetGang(org, newGrade)
        end
        notify(tsrc, _L('your_rank_now', g.name, (kind == 'job' and Jobs() or Gangs())[org].label), 'info')
        pushRefresh(tsrc)
        return okRes('rank_set', fullName(T.PlayerData.charinfo), g.name)
    end
    if kind == 'job' then
        if row.metadata.vorp.multijobs[org] then row.metadata.vorp.multijobs[org].grade = newGrade end
        if row.job.name == org then
            local duty = row.job.onduty
            row.job = jobTable(org, newGrade)
            row.job.onduty = duty == true
        end
        saveRow(row, { 'job', 'metadata' })
    else
        row.gang = gangTable(org, newGrade)
        saveRow(row, { 'gang' })
    end
    return okRes('rank_set', fullName(row.charinfo), g.name)
end

local function setPay(org, myGrade, grade, amount)
    grade = tonumber(grade)
    amount = tonumber(amount)
    if not grade or not amount or amount ~= amount then return fail('bad_amount') end
    grade = math.floor(grade)
    local def = Jobs()[org]
    local g = def and def.grades[tostring(grade)]
    if not g then return fail('bad_grade') end
    if grade >= myGrade then return fail('pay_own_grade') end
    local lo, hi = payLimits(org)
    amount = math.floor(amount * 100 + 0.5) / 100
    if amount < lo or amount > hi then return fail('pay_limits', lo, hi) end
    g.payment = int(amount)
    RSGCore.Functions.UpdateJob(org, def)
    MySQL.insert.await('INSERT INTO `multijobs_pay` (`job`, `grade`, `payment`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `payment` = VALUES(`payment`)',
        { org, grade, amount })
    return okRes('pay_set', g.name, amount)
end

local function deposit(src, kind, org, amount)
    amount = parseAmount(amount)
    if not amount then return fail('bad_amount') end
    if not (GetResourceState('MULTIbank') == 'started') then return fail('no_bank') end
    local P = getP(src)
    if (P.Functions.GetMoney('cash') or 0) < amount then return fail('no_cash') end
    if not P.Functions.RemoveMoney('cash', amount, 'society-deposit') then return fail('no_cash') end
    if not bank('AddAccountMoney', account(kind, org), amount, 'deposit by ' .. P.PlayerData.citizenid) then
        local P2 = getP(src)
        if P2 then P2.Functions.AddMoney('cash', amount, 'society-deposit-refund') end
        return fail('failed')
    end
    return okRes('deposited', ('%.2f'):format(amount))
end

local function withdraw(src, kind, org, amount)
    amount = parseAmount(amount)
    if not amount then return fail('bad_amount') end
    if not (GetResourceState('MULTIbank') == 'started') then return fail('no_bank') end
    local P = getP(src)
    if not bank('RemoveAccountMoney', account(kind, org), amount, 'withdrawal by ' .. P.PlayerData.citizenid) then
        return fail('society_poor')
    end
    local P2 = getP(src)
    if not P2 or not P2.Functions.AddMoney('cash', amount, 'society-withdraw') then
        bank('AddAccountMoney', account(kind, org), amount, 'refund')
        return fail('failed')
    end
    return okRes('withdrew', ('%.2f'):format(amount))
end

--- Checks the caller runs this job / gang. Returns org, grade or nil, error.
local function bossCheck(src, kind, place)
    local P = getP(src)
    if not P then return nil, fail('failed') end
    local org, lvl, isboss = orgOf(P, kind)
    if kind == 'gang' and (not org or org == 'none') then return nil, fail('no_gang') end
    if not org or not isboss then return nil, fail(kind == 'job' and 'not_boss' or 'not_gang_boss') end
    if place and not placeOk(src, kind, org) then return nil, fail('boss_go_to_desk') end
    return org, lvl
end

--- Every boss / gang-boss action. kind = 'job' | 'gang'. Returns { ok, msg, err, ... }.
function MJ.Boss(src, kind, action, data)
    src = tonumber(src)
    if kind ~= 'job' and kind ~= 'gang' then return fail('failed') end
    data = type(data) == 'table' and data or {}
    local org, lvl = bossCheck(src, kind, true)
    if not org then return lvl end
    local res
    if action == 'state' then
        res = { ok = true }
    elseif action == 'nearby' then
        return { ok = true, list = nearbyList(src, kind, org) }
    elseif action == 'hire' then
        res = hire(src, kind, org, data.target)
    elseif action == 'fire' then
        res = fire(src, kind, org, lvl, data.cid)
    elseif action == 'setgrade' then
        res = setGrade(src, kind, org, lvl, data.cid, data.grade)
    elseif action == 'setpay' and kind == 'job' then
        res = setPay(org, lvl, data.grade, data.amount)
    elseif action == 'deposit' then
        res = deposit(src, kind, org, data.amount)
    elseif action == 'withdraw' then
        res = withdraw(src, kind, org, data.amount)
    elseif action == 'stash' then
        if not Config.Stash.Enabled or GetResourceState('rsg-inventory') ~= 'started' then return fail('no_stash') end
        local name = (kind == 'job' and 'boss_' or 'gang_') .. org
        local ok = pcall(function()
            exports['rsg-inventory']:OpenInventory(src, name, { label = _L('stash_label'), maxweight = Config.Stash.MaxWeight, slots = Config.Stash.Slots })
        end)
        return ok and { ok = true, close = true } or fail('no_stash')
    else
        return fail('failed')
    end
    dbg('boss', kind, org, src, action, res.ok, res.err)
    if res.ok or action == 'state' then res.state = bossState(src, kind) end
    return res
end

--- Gang members who are not bosses may look at their gang (read only).
function MJ.GangView(src)
    local P = getP(src)
    if not P then return fail('failed') end
    local org, lvl, isboss, label = orgOf(P, 'gang')
    if not org or org == 'none' then return fail('no_gang') end
    if isboss then return MJ.Boss(src, 'gang', 'state') end
    return {
        ok = true,
        state = {
            kind = 'gang', org = org, label = label, grade = lvl, gradeName = (gradeOf('gang', org, lvl) or {}).name or '',
            cid = P.PlayerData.citizenid, grades = gradeList('gang', org), staff = members('gang', org), readOnly = true,
        },
    }
end

---------------------------------
-- NUI requests (lib.callback)
---------------------------------
lib.callback.register('MULTIjobs:open', function(src, screen)
    if not rateOk(src) then return fail('slow_down') end
    if screen == 'centre' then
        local idx = nearCentre(src)
        if not idx then return fail('too_far') end
        return { ok = true, state = MJ.CentreState(src, idx) }
    elseif screen == 'myjobs' then
        return { ok = true, state = MJ.MyJobsState(src) }
    elseif screen == 'boss' then
        return MJ.Boss(src, 'job', 'state')
    elseif screen == 'gang' then
        return MJ.GangView(src)
    end
    return fail('failed')
end)

lib.callback.register('MULTIjobs:action', function(src, screen, action, data)
    if not rateOk(src) then return fail('slow_down') end
    data = type(data) == 'table' and data or {}
    local res
    if screen == 'centre' then
        if action == 'take' then res = MJ.TakeJob(src, data.job)
        elseif action == 'quit' then res = MJ.QuitActive(src)
        else return fail('failed') end
        res.state = MJ.CentreState(src, nearCentre(src))
    elseif screen == 'myjobs' then
        if action == 'switch' then res = MJ.Switch(src, data.job)
        elseif action == 'quit' then res = MJ.Quit(src, data.job)
        elseif action == 'duty' then res = MJ.Duty(src)
        elseif action == 'leavegang' then res = MJ.LeaveGang(src)
        else return fail('failed') end
        res.state = MJ.MyJobsState(src)
    elseif screen == 'boss' or screen == 'gang' then
        return MJ.Boss(src, screen == 'boss' and 'job' or 'gang', action, data)
    else
        return fail('failed')
    end
    return res
end)

-- duty from a duty point or the command
RegisterNetEvent('MULTIjobs:server:duty', function()
    local src = source
    if not rateOk(src) then return end
    local res = MJ.Duty(src)
    notify(src, res.msg, res.ok and 'job' or 'error')
end)

---------------------------------
-- tables and saved grade pay
---------------------------------
MJ.TablesReady = false
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `player_jobs` (
          `citizenid` VARCHAR(50) NOT NULL,
          `job` VARCHAR(100) NOT NULL,
          `grade` INT NOT NULL DEFAULT 0,
          PRIMARY KEY (`citizenid`, `job`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multijobs_synced` (
          `citizenid` VARCHAR(50) NOT NULL,
          PRIMARY KEY (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multijobs_pay` (
          `job` VARCHAR(50) NOT NULL,
          `grade` INT NOT NULL,
          `payment` DECIMAL(10,2) NOT NULL DEFAULT 0,
          PRIMARY KEY (`job`, `grade`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    local rows = MySQL.query.await('SELECT `job`, `grade`, `payment` FROM `multijobs_pay`') or {}
    local touched = {}
    for _, r in ipairs(rows) do
        local def = Jobs()[r.job]
        local g = def and def.grades[tostring(r.grade)]
        if g then
            g.payment = int(r.payment) or 0
            touched[r.job] = def
        end
    end
    for name, def in pairs(touched) do RSGCore.Functions.UpdateJob(name, def) end
    MJ.TablesReady = true
    -- players already online (resource restart)
    for _, s in ipairs(RSGCore.Functions.GetPlayers() or {}) do
        CreateThread(function() MJ.Reconcile(s) end)
    end
    print(('[MULTIjobs] ready (%d saved grade pays)'):format(#rows))
end)

---------------------------------
-- exports
---------------------------------
exports('IsReady', function(src) return src == nil and MJ.TablesReady or MJ.IsReady(src) end)
exports('GetHeldJobs', function(src)
    local P = getP(src)
    return P and heldOf(P) or {}
end)
exports('GetMaxJobs', function(src) return maxJobs(tonumber(src)) end)
exports('TakeJob', function(src, job) return MJ.TakeJob(tonumber(src), job) end)
exports('SwitchJob', function(src, job) return MJ.Switch(tonumber(src), job) end)
exports('QuitJob', function(src, job) return MJ.Quit(tonumber(src), job) end)
exports('BossAction', function(src, action, data) return MJ.Boss(tonumber(src), 'job', action, data) end)
exports('GangAction', function(src, action, data) return MJ.Boss(tonumber(src), 'gang', action, data) end)
exports('SetDuty', function(src, on) return MJ.Duty(tonumber(src), on) end)
exports('GetDutyCount', function(job) return MJ.DutyCount(job) end)
exports('GetOnDuty', function(job) return (MJ.OnDuty(job)) end)
exports('GetMembers', function(kind, org) return members(kind == 'gang' and 'gang' or 'job', org) end)
