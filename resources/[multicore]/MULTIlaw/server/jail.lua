-- ============================================================
-- MULTIlaw :: jail and Sisika
-- A sentence is a row in multilaw_jail with a release time (os.time),
-- so time is served offline too. metadata.injail mirrors the minutes
-- left for RSG scripts (rsg-horses, rsg-appearance, rsg-mdt ...).
-- Sisika data comes from rsg-prison (RSG v2, GPL v3); see CREDITS.md.
-- ============================================================

local getP, fail, okRes, dbg = Law.getP, Law.fail, Law.okRes, Law.dbg

Law.jail = {}   -- citizenid -> { cid, name, place, cell, minutes, releaseAt, released, itemsTaken, officer, reason }

function Law.IsJailed(cid)
    local j = cid and Law.jail[cid]
    return j ~= nil and not j.released
end

--- seconds left of a sentence (0 when served)
function Law.JailLeft(cid)
    local j = Law.jail[cid]
    if not j or j.released then return 0 end
    return math.max(0, j.releaseAt - os.time())
end

local function minutesLeft(cid) return math.ceil(Law.JailLeft(cid) / 60) end

local function cellById(id)
    for _, c in ipairs(Config.Cells) do if c.id == id then return c end end
end

--- where a sentence is served: { spot = vector4, center = vector3, radius, release = vector4, label }
function Law.JailPlace(j)
    if j.place == 'cell' then
        local c = cellById(j.cell)
        if c then
            return { spot = c.spot, center = vector3(c.spot.x, c.spot.y, c.spot.z), radius = c.radius, release = c.release, label = c.label }
        end
    end
    local p = Config.Prison
    return { spot = p.spawns[math.random(1, #p.spawns)], center = p.center, radius = p.radius, release = p.release, label = p.label, prison = true }
end

--- free town cell nearest to `src` within the search radius (pretend players: the first cell)
local function pickCell(src)
    local pos = Law.coordsOf(src)
    local used = {}
    for _, j in pairs(Law.jail) do if j.place == 'cell' and not j.released then used[j.cell] = (used[j.cell] or 0) + 1 end end
    local best, bestD, bestUse
    for _, c in ipairs(Config.Cells) do
        local d = pos and #(pos - vector3(c.spot.x, c.spot.y, c.spot.z)) or 0
        if d <= Config.Jail.CellSearchRadius then
            local u = used[c.id] or 0
            -- fewest prisoners first, then the closest
            if not best or u < bestUse or (u == bestUse and d < bestD) then best, bestD, bestUse = c, d, u end
        end
    end
    if not pos and not Law.SELFTEST then return nil end
    return best
end

local function saveRow(j)
    MySQL.query.await([[INSERT INTO `multilaw_jail` (`citizenid`, `name`, `place`, `cell`, `minutes`, `release_at`, `released`, `items_taken`, `officer`, `reason`, `jailed_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `place` = VALUES(`place`), `cell` = VALUES(`cell`), `minutes` = VALUES(`minutes`),
        `release_at` = VALUES(`release_at`), `released` = VALUES(`released`), `items_taken` = VALUES(`items_taken`), `officer` = VALUES(`officer`),
        `reason` = VALUES(`reason`), `jailed_at` = VALUES(`jailed_at`)]],
        { j.cid, j.name, j.place, j.cell, j.minutes, j.releaseAt, j.released and 1 or 0, j.itemsTaken and 1 or 0, j.officer, j.reason, j.jailedAt })
end

local function itemStash(cid) return 'stash:' .. Config.Jail.ItemStashPrefix .. cid end

--- moves the whole satchel into the prisoner's item stash (only items that fit are moved)
local function takeItems(src, cid)
    if GetResourceState('MULTIinventory') ~= 'started' then return false end
    local MI = exports.MULTIinventory
    local from = MI:PlayerInv(src)
    local inv = from and MI:Get(from)
    if not inv then return false end
    local stash = itemStash(cid)
    if not MI:Exists(stash) then MI:Create(stash, { label = _L('jail_items_label'), slots = 200, maxWeight = 10000000 }) end
    local moved = false
    for slot, s in pairs(inv.items or {}) do
        slot = tonumber(slot)
        if MI:CanAdd(stash, s.name, s.amount, s.info) then
            local ok, _, info = MI:RemoveItem(from, s.name, s.amount, slot, nil, 'multilaw-jail')
            if ok then
                local added = MI:AddItem(stash, s.name, s.amount, info or s.info, nil, 'multilaw-jail')
                if not added then MI:AddItem(from, s.name, s.amount, info or s.info, slot, 'multilaw-jail-undo') else moved = true end
            end
        end
    end
    return moved
end

--- gives the stash back (what does not fit stays in the stash for next time)
local function giveItems(src, cid)
    if GetResourceState('MULTIinventory') ~= 'started' then return true end
    local MI = exports.MULTIinventory
    local stash = itemStash(cid)
    local inv = MI:Exists(stash) and MI:Get(stash)
    if not inv then return true end
    local to = MI:PlayerInv(src)
    if not to then return false end
    local all = true
    for slot, s in pairs(inv.items or {}) do
        slot = tonumber(slot)
        if MI:CanAdd(to, s.name, s.amount, s.info) then
            local ok, _, info = MI:RemoveItem(stash, s.name, s.amount, slot, nil, 'multilaw-release')
            if ok then MI:AddItem(to, s.name, s.amount, info or s.info, nil, 'multilaw-release') end
        else
            all = false
        end
    end
    if all then MI:Delete(stash) end
    return all
end

local function sendToClient(src, j)
    local place = Law.JailPlace(j)
    j.liveCenter, j.liveRadius = place.center, place.radius
    TriggerClientEvent('MULTIlaw:client:jailed', src, {
        spot = place.spot, center = place.center, radius = place.radius, prison = place.prison == true,
        label = _L(place.label), seconds = Law.JailLeft(j.cid), outfit = place.prison == true and Config.Jail.PrisonOutfit,
    })
end

--- jails the target. officer = lawman src (nil for scripts / exports). place = 'cell' | 'prison'.
--- opts = { reason, officerName, skipChecks (export / MDT) } → answer table (res.claimed = bounty money paid)
function Law.Jail(officer, target, minutes, place, opts)
    opts = opts or {}
    officer, target = tonumber(officer), tonumber(target)
    local T = getP(target)
    if not T then return fail('no_player') end
    local P = officer and getP(officer)
    if officer and not opts.skipChecks then
        if not P or officer == target then return fail('no_player') end
        local ok, err = Law.Can(P, 'jail')
        if not ok then return fail(err) end
        if not Law.playersNear(officer, target, Config.Jail.Distance) then return fail('too_far') end
        if Config.Jail.RequireCuffed and not Law.IsCuffed(target) then return fail('need_cuffed') end
    end
    place = place == 'cell' and 'cell' or 'prison'
    minutes = Law.int(minutes)
    local max = place == 'cell' and Config.Jail.CellMaxMinutes or Config.Jail.PrisonMaxMinutes
    if not minutes or minutes < 1 then return fail('bad_minutes', max) end
    if minutes > max then return fail('too_long', max) end
    local cid = Law.cidOf(T)
    if Law.IsJailed(cid) then return fail('already_jailed') end
    local cell
    if place == 'cell' then
        cell = pickCell(officer or target)
        if not cell then return fail('no_cell') end
    end

    local now = os.time()
    local j = {
        cid = cid, name = Law.nameOf(T), place = place, cell = cell and cell.id or nil, minutes = minutes,
        releaseAt = now + minutes * 60, released = false, itemsTaken = false,
        officer = opts.officerName or (P and Law.nameOf(P)) or nil, reason = Law.text(opts.reason or '', 200), jailedAt = now,
    }
    Law.jail[cid] = j
    -- the cuffs come off in the cell
    if Law.IsCuffed(target) then Law.SetCuffed(target, false, officer, true) end
    Law.StopEscort(target)
    if Config.Jail.TakeItems[place] then j.itemsTaken = takeItems(target, cid) end
    if place == 'prison' and Config.Jail.RemoveJob and T.PlayerData.job and T.PlayerData.job.name ~= 'unemployed' then
        T.Functions.SetJob('unemployed', 0)
    end
    saveRow(j)
    local date = os.date('*t')
    if date.day == 31 then date.day = 30 end
    T.Functions.SetMetaData('injail', minutes)
    T.Functions.SetMetaData('criminalrecord', { hasRecord = true, date = date })
    Law.AddRecord(cid, j.name, 'arrest', {
        detail = (j.reason ~= '' and j.reason or _L(place == 'cell' and 'record_cell' or 'record_prison')),
        minutes = minutes, officer = j.officer,
    })
    sendToClient(target, j)
    Law.notify(target, _L('you_jailed', minutes, _L(Law.JailPlace(j).label)), 'police')
    TriggerEvent('MULTIlaw:server:jailed', target, minutes, place, officer)

    local res = okRes('jailed', j.name, minutes)
    res.claimed = 0
    if P and Law.LawJob(P) then res.claimed = Law.ClaimBounties(cid, officer) or 0 end
    return res
end

--- lets a prisoner go. who = citizenid or online src. by = lawman src (nil = time served / script)
function Law.Release(who, by, silent)
    local cid = type(who) == 'string' and who or Law.cidOf(getP(who))
    local j = cid and Law.jail[cid]
    if not j then return fail('not_jailed') end
    by = tonumber(by)
    if by then
        local P = getP(by)
        if not Law.IsAdmin(by) then
            local ok, err = Law.Can(P, 'release')
            if not ok then return fail(err) end
        end
        if not j.released and Law.JailLeft(cid) > 0 then
            Law.AddRecord(cid, j.name, 'release', { detail = _L('record_early_release'), officer = Law.nameOf(P) })
        end
    end
    local T = Law.byCid(cid)
    if not T then
        -- offline: the next login lets him out (and hands his things back)
        j.released = true
        saveRow(j)
        return okRes('released', j.name)
    end
    local src = Law.srcOf(T)
    local place = Law.JailPlace(j)
    Law.jail[cid] = nil
    MySQL.query.await('DELETE FROM `multilaw_jail` WHERE `citizenid` = ?', { cid })
    T.Functions.SetMetaData('injail', 0)
    if j.itemsTaken then giveItems(src, cid) end
    TriggerClientEvent('MULTIlaw:client:released', src, place.release, j.place == 'prison' and Config.Jail.PrisonOutfit)
    if not silent then Law.notify(src, _L('you_released'), 'police') end
    TriggerEvent('MULTIlaw:server:released', src, cid)
    dbg('released', cid)
    return okRes('released', j.name)
end

--- a jail written into metadata by another script (rsg-mdt, rsg-lawman callers) becomes a real sentence
function Law.JailFromMeta(src)
    local T = getP(src)
    if not T then return fail('no_player') end
    local cid = Law.cidOf(T)
    if Law.IsJailed(cid) then return fail('already_jailed') end
    local mins = Law.int(T.PlayerData.metadata and T.PlayerData.metadata.injail) or 0
    if mins < 1 then return fail('not_jailed') end
    local place = Config.Compat.MetaJailPlace == 'cell' and 'cell' or 'prison'
    local max = place == 'cell' and Config.Jail.CellMaxMinutes or Config.Jail.PrisonMaxMinutes
    local res = Law.Jail(nil, src, math.min(mins, max), place, { skipChecks = true, officerName = _L('record_court') })
    if not res.ok and place == 'cell' then
        res = Law.Jail(nil, src, math.min(mins, Config.Jail.PrisonMaxMinutes), 'prison', { skipChecks = true, officerName = _L('record_court') })
    end
    return res
end

---------------------------------
-- start, login, tick
---------------------------------
--- reads every sentence from the table (start, and the self-test's "server restart")
function Law.LoadJail()
    Law.jail = {}
    local rows = MySQL.query.await('SELECT * FROM `multilaw_jail`') or {}
    for _, r in ipairs(rows) do
        Law.jail[r.citizenid] = {
            cid = r.citizenid, name = r.name, place = r.place, cell = r.cell, minutes = tonumber(r.minutes) or 0,
            releaseAt = tonumber(r.release_at) or 0, released = tonumber(r.released) == 1, itemsTaken = tonumber(r.items_taken) == 1,
            officer = r.officer, reason = r.reason, jailedAt = tonumber(r.jailed_at) or 0,
        }
    end
    dbg(('%d sentences loaded'):format(#rows))
    return #rows
end
Law.OnReady(Law.LoadJail)

--- what a player who just logged in has to serve (or be let out of)
function Law.CheckLogin(src)
    local T = getP(src)
    if not T then return end
    local cid = Law.cidOf(T)
    local j = Law.jail[cid]
    if j then
        if j.released or Law.JailLeft(cid) <= 0 then
            Law.Release(cid, nil, false)
        else
            T.Functions.SetMetaData('injail', minutesLeft(cid))
            sendToClient(src, j)
            Law.notify(src, _L('still_jailed', minutesLeft(cid)), 'police')
        end
        return
    end
    -- jailed by another script while MULTIlaw was not watching
    if (Law.int(T.PlayerData.metadata and T.PlayerData.metadata.injail) or 0) > 0 then Law.JailFromMeta(src) end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    local src = Law.srcOf(P)
    if not src then return end
    CreateThread(function()
        Law.WaitReady()
        Law.CheckLogin(src)
    end)
end)

-- the minutes left are written to metadata before the core saves on logout
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    local T = getP(src)
    local cid = Law.cidOf(T)
    if cid and Law.IsJailed(cid) then T.Functions.SetMetaData('injail', minutesLeft(cid)) end
end)

--- one pass: let out whoever has served, refresh metadata, keep prisoners in place
function Law.JailTick()
    for cid, j in pairs(Law.jail) do
        local T = Law.byCid(cid)
        if T then
            local src = Law.srcOf(T)
            if j.released or Law.JailLeft(cid) <= 0 then
                Law.Release(cid, nil, false)
            else
                local m = minutesLeft(cid)
                if (T.PlayerData.metadata and T.PlayerData.metadata.injail) ~= m then T.Functions.SetMetaData('injail', m) end
                if not Config.Jail.AllowEscape and Config.ServerDistanceCheck and j.liveCenter then
                    local pos = Law.coordsOf(src)
                    if pos and #(pos - j.liveCenter) > (j.liveRadius or 5.0) + 10.0 then
                        sendToClient(src, j)
                        dbg('put back', cid)
                    end
                end
            end
        end
    end
end

CreateThread(function()
    Law.WaitReady(60000)
    while true do
        Wait(Config.Jail.TickSeconds * 1000)
        local ok, err = pcall(Law.JailTick)
        if not ok then print(('^1[MULTIlaw] jail tick failed: %s^7'):format(tostring(err))) end
    end
end)

-- the prisoner's client asks for its sentence again (resource restart, after a respawn)
lib.callback.register('MULTIlaw:jail:state', function(src)
    local cid = Law.cidOf(getP(src))
    if not Law.IsJailed(cid) then return nil end
    local j = Law.jail[cid]
    local place = Law.JailPlace(j)
    j.liveCenter, j.liveRadius = place.center, place.radius
    return { spot = place.spot, center = place.center, radius = place.radius, prison = place.prison == true,
        label = _L(place.label), seconds = Law.JailLeft(cid), outfit = place.prison == true and Config.Jail.PrisonOutfit, keepPos = true }
end)
