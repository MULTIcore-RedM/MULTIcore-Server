-- ============================================================
-- MULTIcore :: VORP `characters` table and RSG `playerskins` rows
-- (docs/COMPAT_SURVEY.md gaps 5 and 8)
--
-- VORP scripts read and write `characters` with SQL. MULTIcore keeps one
-- row per character (charidentifier = players.id) and keeps it in step:
--   * MULTIcore writes the row when a character is created, logs in, is
--     saved and logs out (and every CharactersSyncSeconds while online).
--   * Script writes flow back. `multicore_vorp_sync` holds what MULTIcore
--     last wrote to money / gold / rol / job / jobgrade / joblabel. On login,
--     on every save and on the timer the row is compared with it, and the
--     difference is applied through the player object (AddMoney, SetJob ...),
--     so  UPDATE characters SET money = money + ?  pay-outs land, online or
--     offline. MULTIcore's own money changes are written back as
--     money = money + (live - last written), so a script write that lands
--     in between is never overwritten; it is picked up on the next pass.
--   * Other columns (name, look, coords, xp ...) are written by MULTIcore
--     only; script writes to them are overwritten on the next save.
--   * The row is deleted with the character (players.lua playertables).
-- Written for MULTIcore (GPL v3); column names from VORP's public database
-- shape and the queries scripts run. No VORP code is used.
-- ============================================================

MULTI.Compat = MULTI.Compat or {}
local C = MULTI.Compat
local cfg = MULTIConfig.Compat or {}

local MONEY = { { col = 'money', mtype = 'cash' }, { col = 'gold', mtype = 'gold' }, { col = 'rol', mtype = 'rol' } }

-- columns MULTIcore fills from the character (charidentifier and the money columns are handled apart)
local COLS = {
    'identifier', 'citizenid', 'steamname', 'group', 'xp', 'hours', 'job', 'jobgrade', 'joblabel',
    'firstname', 'lastname', 'character_desc', 'gender', 'age', 'nickname',
    'skinPlayer', 'compPlayer', 'compTints', 'coords', 'isdead', 'status',
}

local ready = {}   -- [source] = charidentifier once the character's row has been synced after login
local busy = {}    -- [charidentifier] = true while a sync runs (two syncs at once would apply a change twice)

local function dbg(...)
    if MULTIConfig.Debug then print('[MULTIcore compat]', ...) end
end

local function round2(x)
    x = tonumber(x) or 0
    if x < 0 then return -math.floor(-x * 100 + 0.5) / 100 end
    return math.floor(x * 100 + 0.5) / 100
end

local function q(name) return '`' .. name .. '`' end

-- ---------------------------------------------------------------
-- building a row
-- ---------------------------------------------------------------

local identifierCache = {}  -- [license] = account identifier (users.identifier) for offline characters

local function identifierFor(d)
    local acc = d.source and MULTI.Accounts.bySource[d.source]
    if acc and acc.identifier then return acc.identifier end
    if not d.license then return '' end
    if identifierCache[d.license] == nil then
        identifierCache[d.license] = MySQL.scalar.await('SELECT identifier FROM users WHERE license = ? LIMIT 1', { d.license }) or false
    end
    return identifierCache[d.license] or d.license
end

--- the synced columns (money, job) as the character holds them now
local function liveValues(d)
    local job = d.job or {}
    local money = d.money or {}
    return {
        money = round2(money.cash), gold = round2(money.gold), rol = round2(money.rol),
        job = job.name, jobgrade = tonumber(job.grade and job.grade.level) or 0, joblabel = job.label,
    }
end

local function sameValues(a, b)
    if not a or not b then return false end
    for _, m in ipairs(MONEY) do
        if math.abs(round2(a[m.col]) - round2(b[m.col])) >= 0.01 then return false end
    end
    return a.job == b.job and tonumber(a.jobgrade) == tonumber(b.jobgrade) and a.joblabel == b.joblabel
end

--- every column of the characters row for a player (online or offline player object)
local function rowFor(P)
    local d = P.PlayerData
    local f = MULTI.Vorp.CharacterFields(P)
    local lv = liveValues(d)
    local pos = d.position
    if type(pos) == 'vector3' or type(pos) == 'vector4' then pos = { x = pos.x, y = pos.y, z = pos.z } end
    return {
        identifier = identifierFor(d),
        citizenid = d.citizenid,
        steamname = tostring(d.name or ''):sub(1, 255),
        group = f.group or 'user',
        xp = tonumber(f.xp) or 0,
        hours = tonumber(f.hours) or 0,
        job = lv.job or 'unemployed',
        jobgrade = lv.jobgrade,
        joblabel = lv.joblabel or '',
        firstname = tostring(f.firstname or ''):sub(1, 50),
        lastname = tostring(f.lastname or ''):sub(1, 50),
        character_desc = f.charDescription or '',
        gender = f.gender,
        age = tonumber(f.age) or 0,
        nickname = tostring(f.nickname or ''):sub(1, 50),
        skinPlayer = type(f.skin) == 'string' and f.skin or json.encode(f.skin or {}),
        compPlayer = type(f.comps) == 'string' and f.comps or json.encode(f.comps or {}),
        compTints = type(f.compTints) == 'string' and f.compTints or json.encode(f.compTints or {}),
        coords = json.encode(pos or {}),
        isdead = f.isdead and 1 or 0,
        status = json.encode(f.status or {}),
    }, lv
end

-- ---------------------------------------------------------------
-- writing (MULTIcore -> characters)
-- ---------------------------------------------------------------

local function shadowQuery(id, citizenid, lv)
    return {
        query = 'INSERT INTO multicore_vorp_sync (charidentifier, citizenid, money, gold, rol, job, jobgrade, joblabel) VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
            .. 'ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid), money = VALUES(money), gold = VALUES(gold), rol = VALUES(rol), '
            .. 'job = VALUES(job), jobgrade = VALUES(jobgrade), joblabel = VALUES(joblabel)',
        values = { id, citizenid, lv.money, lv.gold, lv.rol, lv.job, lv.jobgrade, lv.joblabel },
    }
end

--- Writes a character's row. `shadow` = what MULTIcore last wrote (nil = unknown: money is written as is).
--- full = every column; otherwise only the money and job columns, and only when they changed.
local function push(P, shadow, full, online)
    local d = P.PlayerData
    local id = tonumber(d.id)
    if not id then return false end
    local lv = liveValues(d)
    local queries
    if full or not shadow then
        local row = rowFor(P)
        local names, marks, values, updates = { q('charidentifier') }, { '?' }, { id }, {}
        for _, col in ipairs(COLS) do
            local v = row[col]
            if v == nil then v = '' end
            names[#names + 1] = q(col); marks[#marks + 1] = '?'; values[#values + 1] = v
            updates[#updates + 1] = ('%s = VALUES(%s)'):format(q(col), q(col))
        end
        if online then
            names[#names + 1] = q('LastLogin'); marks[#marks + 1] = '?'; values[#values + 1] = os.date('%Y-%m-%d')
            updates[#updates + 1] = '`LastLogin` = VALUES(`LastLogin`)'
        end
        for _, m in ipairs(MONEY) do
            names[#names + 1] = q(m.col); marks[#marks + 1] = '?'; values[#values + 1] = lv[m.col]
        end
        -- money: add what changed since the last write, so a script's write in between survives
        local deltas = {}
        for _, m in ipairs(MONEY) do
            if shadow then
                updates[#updates + 1] = ('%s = %s + ?'):format(q(m.col), q(m.col))
                deltas[#deltas + 1] = round2(lv[m.col] - (tonumber(shadow[m.col]) or 0))
            else
                updates[#updates + 1] = ('%s = VALUES(%s)'):format(q(m.col), q(m.col))
            end
        end
        for _, v in ipairs(deltas) do values[#values + 1] = v end
        queries = { {
            query = ('INSERT INTO characters (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s')
                :format(table.concat(names, ', '), table.concat(marks, ', '), table.concat(updates, ', ')),
            values = values,
        } }
    else
        if sameValues(lv, shadow) then return true end
        queries = { {
            query = 'UPDATE characters SET money = money + ?, gold = gold + ?, rol = rol + ?, job = ?, jobgrade = ?, joblabel = ? WHERE charidentifier = ?',
            values = {
                round2(lv.money - (tonumber(shadow.money) or 0)), round2(lv.gold - (tonumber(shadow.gold) or 0)),
                round2(lv.rol - (tonumber(shadow.rol) or 0)), lv.job or 'unemployed', lv.jobgrade, lv.joblabel or '', id,
            },
        } }
    end
    queries[#queries + 1] = shadowQuery(id, d.citizenid, lv)
    local ok, res = pcall(MySQL.transaction.await, queries)
    if not ok or not res then
        print(('^1[MULTIcore] characters row %s not written: %s^7'):format(id, tostring(ok and 'transaction failed' or res)))
        return false
    end
    return true
end

-- ---------------------------------------------------------------
-- reading (characters -> MULTIcore)
-- ---------------------------------------------------------------

local PULL_QUERY = 'SELECT c.money, c.gold, c.rol, c.job, c.jobgrade, c.joblabel, s.charidentifier AS s_id, '
    .. 's.money AS s_money, s.gold AS s_gold, s.rol AS s_rol, s.job AS s_job, s.jobgrade AS s_jobgrade, s.joblabel AS s_joblabel '
    .. 'FROM characters c LEFT JOIN multicore_vorp_sync s ON s.charidentifier = c.charidentifier WHERE c.charidentifier = ?'

--- Applies script writes to an online character. Returns the row's synced values (the new "last
--- written" baseline, nil when unknown) and whether anything was applied.
local function pull(P)
    local d = P.PlayerData
    local ok, row = pcall(MySQL.single.await, PULL_QUERY, { d.id })
    if not ok or not row or not row.s_id then return nil, false end
    local changed = false
    for _, m in ipairs(MONEY) do
        local diff = round2((tonumber(row[m.col]) or 0) - (tonumber(row['s_' .. m.col]) or 0))
        if diff >= 0.01 then
            changed = true
            P.Functions.AddMoney(m.mtype, diff, 'characters-table')
            dbg('characters', d.id, m.col, '+' .. diff)
        elseif diff <= -0.01 then
            changed = true
            if not P.Functions.RemoveMoney(m.mtype, -diff, 'characters-table') then
                print(('^3[MULTIcore] characters.%s of %s dropped by %s, but the character cannot go that low; the row is reset^7')
                    :format(m.col, d.id, -diff))
            end
            dbg('characters', d.id, m.col, diff)
        end
    end
    local job, grade, label = row.job, tonumber(row.jobgrade) or 0, row.joblabel
    if type(job) == 'string' and job ~= ''
        and (job ~= row.s_job or grade ~= (tonumber(row.s_jobgrade) or 0) or label ~= row.s_joblabel) then
        changed = true
        local cur = d.job or {}
        local curGrade = tonumber(cur.grade and cur.grade.level) or 0
        if job:lower() ~= cur.name or grade ~= curGrade then
            if not MULTI.Jobs.Set(P, job, grade, (label and label ~= '') and label or nil) then
                print(('^3[MULTIcore] characters.job of %s set to %s %s by a script, but the job could not be set^7'):format(d.id, job, grade))
            end
        elseif label and label ~= '' and label ~= cur.label then
            P.PlayerData.job.label = label
            P.Functions.UpdatePlayerData()
        end
        dbg('characters', d.id, 'job', job, grade, label)
    end
    return {
        money = row.money, gold = row.gold, rol = row.rol, job = row.job, jobgrade = row.jobgrade, joblabel = row.joblabel,
    }, changed
end

local function loadShadow(id)
    local ok, row = pcall(MySQL.single.await, 'SELECT * FROM multicore_vorp_sync WHERE charidentifier = ?', { id })
    return ok and row or nil
end

local function lock(id)
    local untilTime = GetGameTimer() + 10000
    while busy[id] and GetGameTimer() < untilTime do Wait(20) end
    busy[id] = true
end
local function unlock(id) busy[id] = nil end

-- ---------------------------------------------------------------
-- when the row is synced
-- ---------------------------------------------------------------

local origSave = RSGCore.Player.Save
local origSaveOffline = RSGCore.Player.SaveOffline

--- Pull then push for an online character. `between` runs after the pull (the players save).
local function sync(P, full, between)
    local id = tonumber(P.PlayerData.id)
    if not id then if between then between() end return end
    lock(id)
    local saved = false
    local ok, err = pcall(function()
        local shadow, changed = pull(P)
        saved = true
        if between then between()
        elseif changed then origSave(P.PlayerData.source) end   -- keep the players row in step with what was applied
        push(P, shadow, full, true)
    end)
    unlock(id)
    if not ok then print(('^1[MULTIcore] characters sync of %s failed: %s^7'):format(id, tostring(err))) end
    if between and not saved then between() end  -- the players save must happen whatever went wrong here
end
C.SyncCharacter = sync

function C.IsSynced(src)
    local P = RSGCore.Players[src]
    return P ~= nil and ready[src] == P.PlayerData.id
end

if cfg.CharactersTable ~= false then
    -- every save of an online character: pick up script writes first, so the players row has them, then write the row
    RSGCore.Player.Save = function(source, ...)
        local P = RSGCore.Players[source]
        if not P or ready[source] ~= P.PlayerData.id then return origSave(source, ...) end
        -- the read below waits on the database; keep where the ped is now (it may be gone after, on a drop)
        local ped = GetPlayerPed(source)
        local c = ped and ped ~= 0 and GetEntityCoords(ped)
        if c and (c.x ~= 0.0 or c.y ~= 0.0 or c.z ~= 0.0) then P.PlayerData.position = { x = c.x, y = c.y, z = c.z } end
        local args, result = { ... }, nil
        sync(P, true, function() result = origSave(source, table.unpack(args)) end)
        return result
    end

    -- an offline character changed by a script (RSG bossmenu ...): write its row, keeping script writes
    RSGCore.Player.SaveOffline = function(PlayerData, ...)
        local result = origSaveOffline(PlayerData, ...)
        local id = PlayerData and tonumber(PlayerData.id)
        if id then
            lock(id)
            pcall(push, { PlayerData = PlayerData }, loadShadow(id), true, false)
            unlock(id)
        end
        return result
    end

    -- login: pick up whatever scripts wrote while the character was away, then write the row
    AddEventHandler('RSGCore:Server:PlayerLoaded', function(loaded)
        local src = loaded.PlayerData.source
        if not src then return end
        CreateThread(function()
            MULTI.Schema.Wait()
            -- event arguments arrive as a copy; work on the live player object
            local P = RSGCore.Players[src]
            if not P or P.PlayerData.id ~= loaded.PlayerData.id then return end
            sync(P, true)
            if RSGCore.Players[src] == P then ready[src] = P.PlayerData.id end
        end)
    end)

    -- online characters: pick up script writes every CharactersSyncSeconds
    CreateThread(function()
        local every = tonumber(cfg.CharactersSyncSeconds) or 60
        if every <= 0 then return end
        while true do
            Wait(every * 1000)
            for src, P in pairs(RSGCore.Players) do
                if ready[src] == P.PlayerData.id then sync(P, false) end
            end
        end
    end)

    -- forget the character once it has left. Logout fires the unload event just before its save,
    -- so this waits a tick; the next login of the same source syncs again after its PlayerLoaded.
    AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
        local id = ready[src]
        SetTimeout(0, function() if ready[src] == id then ready[src] = nil end end)
    end)
    AddEventHandler('playerDropped', function()
        local src = source
        SetTimeout(5000, function() if not RSGCore.Players[src] then ready[src] = nil end end)
    end)

    -- the character was deleted: its row goes too (players.lua playertables also does this by citizenid)
    AddEventHandler('MULTIcore:characterDeleted', function(_, citizenid)
        if type(citizenid) ~= 'string' then return end
        MySQL.query('DELETE FROM characters WHERE citizenid = ?', { citizenid })
        MySQL.query('DELETE FROM multicore_vorp_sync WHERE citizenid = ?', { citizenid })
    end)

    -- characters made before this table existed get a row, so offline pay-outs find them
    CreateThread(function()
        MULTI.Schema.Wait()
        if cfg.CharactersBackfill == false then return end
        local ok, rows = pcall(MySQL.query.await,
            'SELECT p.* FROM players p LEFT JOIN characters c ON c.charidentifier = p.id WHERE c.charidentifier IS NULL')
        if not ok or type(rows) ~= 'table' or #rows == 0 then return end
        local n = 0
        for _, row in ipairs(rows) do
            if not RSGCore.Functions.GetPlayerByCitizenId(row.citizenid) then
                for _, col in ipairs({ 'money', 'job', 'gang', 'position', 'metadata', 'charinfo' }) do
                    local okj, v = pcall(json.decode, row[col] or 'null')
                    row[col] = okj and v or nil
                end
                row.money = row.money or {}
                row.metadata = row.metadata or {}
                row.charinfo = row.charinfo or {}
                if pcall(push, { PlayerData = row }, nil, true, false) then n = n + 1 end
            end
        end
        print(('[MULTIcore] characters table: %d character rows added'):format(n))
    end)
end

-- ---------------------------------------------------------------
-- playerskins (RSG): one row per character, filled from the MULTIcore look
-- ---------------------------------------------------------------

local Clothes = (MULTIData and MULTIData.Clothes) or {}
local Palettes = (MULTIData and MULTIData.Palettes) or {}
local SKIN_CATS = { heads = true, bodies_upper = true, bodies_lower = true, eyes = true, teeth = true, hair = true, beards_complete = true }

--- MULTIcore comps -> RSG clothes { [category] = { hash, palette, tint0, tint1, tint2 } }
local function rsgClothes(comps, sex)
    local out = {}
    for cat, piece in pairs(type(comps) == 'table' and comps or {}) do
        local list = not SKIN_CATS[cat] and Clothes[sex] and Clothes[sex][cat]
        local item = list and type(piece) == 'table' and list[math.floor(tonumber(piece.index) or 0)]
        if item then
            local e = { hash = item.h }
            local pal = piece.palette and Palettes[math.floor(tonumber(piece.palette) or 0)]
            if pal then
                e.palette = pal
                e.tint0, e.tint1, e.tint2 = tonumber(piece.tint0) or 0, tonumber(piece.tint1) or 0, tonumber(piece.tint2) or 0
            end
            out[cat] = e
        end
    end
    return out
end

--- Writes the character's playerskins row (skin = the MULTIcore skin JSON, clothes = RSG shape).
--- Only for characters with a MULTIcore look; a row written by an RSG creator is left alone.
function C.MirrorSkin(citizenid, license)
    if cfg.PlayerskinsMirror == false or type(citizenid) ~= 'string' then return false end
    local look = MULTI.Login.GetLook(citizenid)
    if not look or type(look.skin) ~= 'table' or not look.skin.sex then return false end
    local sex = look.skin.sex == 'female' and 'female' or 'male'
    local skin, clothes = json.encode(look.skin), json.encode(rsgClothes(look.comps, sex))
    local id = MySQL.scalar.await('SELECT id FROM playerskins WHERE citizenid = ? LIMIT 1', { citizenid })
    if id then
        MySQL.update.await('UPDATE playerskins SET skin = ?, clothes = ?, license = COALESCE(?, license) WHERE id = ?', { skin, clothes, license, id })
    else
        MySQL.insert.await('INSERT INTO playerskins (citizenid, license, skin, clothes) VALUES (?, ?, ?, ?)', { citizenid, license, skin, clothes })
    end
    return true
end

if cfg.PlayerskinsMirror ~= false then
    AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
        local d = P.PlayerData
        CreateThread(function() pcall(C.MirrorSkin, d.citizenid, d.license) end)
    end)
    AddEventHandler('MULTIcore:lookChanged', function(src)
        local P = RSGCore.Players[src]
        if not P then return end
        local d = P.PlayerData
        CreateThread(function() pcall(C.MirrorSkin, d.citizenid, d.license) end)
    end)
end
