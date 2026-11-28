-- ============================================================
-- MULTIcore :: switch-over import  (server console:  mcimport vorp | rsg)
--
-- Brings the players of a VORP or RSG-Core server over to MULTIcore:
-- characters, money, job and grade, looks, inventory items, weapons and
-- gunbelt ammo, horses, wagons and (RSG) houses, as far as MULTIcore has
-- a place for them. Anything it cannot place is listed in the console and
-- in `multicore_import_log`; nothing is dropped without a line.
--
--   mcimport vorp dry                 count and report only, nothing is written
--   mcimport vorp                     import
--   mcimport rsg from=old_database    read the old tables from another database
--
-- Safety:
--   * the old tables are only read (SELECT); nothing in them is changed or deleted
--   * `multicore_import_map` records every row brought over, so a second run adds
--     nothing twice (characters, horses, wagons, houses are one transaction each,
--     together with their map row; inventories are marked 'pending' while they fill)
--   * refuses to run while players are connected (add  online  to run anyway)
--
-- VORP characters keep their number: players.id = the old charidentifier whenever
-- that id is free, so VORP scripts' own tables (keyed by charidentifier) still match.
-- VORP accounts are keyed by Steam id; a character whose owner had no licence on
-- record gets the Steam id as its owner and is handed to the licence the first time
-- that player connects (see the playerConnecting handler at the end).
--
-- Table shapes come from the public install SQL of VORP (core, inventory, stables,
-- banking, housing) and RSG-Core (core, horses, wagons, banking). No code of those
-- frameworks is used. GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

MULTI.Import = { running = false }
local I = MULTI.Import
local SELFTEST = GetConvar('multicore_selftest', 'false') == 'true'
local PAGE = 200
local MAX_PRINT = 40         -- notes printed per step (all of them go to multicore_import_log)
local INV = 'MULTIinventory'
local PLATE_CHARS, PLATE_LEN = 'ABCDEFGHJKLMNPRSTUVWXYZ23456789', 6   -- MULTIwagons' default storage ids

-- ---------------------------------------------------------------
-- small helpers
-- ---------------------------------------------------------------

local function out(line) print('[MULTIcore import] ' .. line) end

local function decode(v)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return nil end
    local ok, r = pcall(json.decode, v)
    if ok then return r end
    return nil
end

local function round2(x)
    x = tonumber(x) or 0
    if x < 0 then return -math.floor(-x * 100 + 0.5) / 100 end
    return math.floor(x * 100 + 0.5) / 100
end

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

local function q(name) return '`' .. name .. '`' end

-- oxmysql hands TINYINT(1) columns back as true / false, wider ones as numbers
local function flag(v) return v == true or tonumber(v) == 1 end

--- old table name, in the other database when `from=` was given
local function T(ctx, name)
    if ctx.db then return ('`%s`.`%s`'):format(ctx.db, name) end
    return q(name)
end

local function schemaArgs(ctx, name)
    if ctx.db then return 'TABLE_SCHEMA = ? AND TABLE_NAME = ?', { ctx.db, name } end
    return 'TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name }
end

local function hasTable(ctx, name)
    local where, args = schemaArgs(ctx, name)
    return (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.TABLES WHERE ' .. where, args)) or 0) > 0
end

local function hasTargetTable(name)
    return (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })) or 0) > 0
end

local function columns(ctx, name)
    local where, args = schemaArgs(ctx, name)
    local set = {}
    for _, r in ipairs(MySQL.query.await('SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE ' .. where, args) or {}) do
        set[r.c] = true
    end
    return set
end

local function targetColumns(name)
    local set = {}
    for _, r in ipairs(MySQL.query.await('SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name }) or {}) do
        set[r.c] = true
    end
    return set
end

local function inv() return exports[INV] end

local function nonEmptyJson(v)
    return type(v) == 'string' and v ~= '' and v ~= '[]' and v ~= '{}' and v ~= 'null'
end

-- ---------------------------------------------------------------
-- report, notes and the map
-- ---------------------------------------------------------------

local function step(ctx, name)
    local st = { name = name, found = 0, moved = 0, already = 0, skipped = 0, notes = 0, extra = {} }
    ctx.steps[#ctx.steps + 1] = st
    return st
end

--- one thing that could not be brought over (console + multicore_import_log)
local function note(ctx, st, key, msgKey, ...)
    st.notes = st.notes + 1
    ctx.notes = ctx.notes + 1
    local msg = _L(msgKey, ...)
    if st.notes <= MAX_PRINT then
        print(('^3[MULTIcore import] %s %s: %s^7'):format(st.name, key ~= nil and ('[' .. tostring(key) .. ']') or '', msg))
    elseif st.notes == MAX_PRINT + 1 then
        out(_L('import_more_notes', st.name))
    end
    if not ctx.dry then
        pcall(MySQL.insert.await, 'INSERT INTO multicore_import_log (run, source, step, source_key, message) VALUES (?, ?, ?, ?, ?)',
            { ctx.run, ctx.source, st.name, key ~= nil and tostring(key):sub(1, 150) or nil, msg })
    end
end

local function mapGet(ctx, kind, key)
    return MySQL.single.await('SELECT target_key, status FROM multicore_import_map WHERE source = ? AND kind = ? AND source_key = ?',
        { ctx.source, kind, tostring(key) })
end

local function mapQuery(ctx, kind, key, target, status)
    return {
        query = 'INSERT INTO multicore_import_map (source, kind, source_key, target_key, status) VALUES (?, ?, ?, ?, ?) '
            .. 'ON DUPLICATE KEY UPDATE target_key = VALUES(target_key), status = VALUES(status)',
        values = { ctx.source, kind, tostring(key), target ~= nil and tostring(target) or '', status or 'done' },
    }
end

local function mapPut(ctx, kind, key, target, status)
    local qy = mapQuery(ctx, kind, key, target, status)
    return pcall(MySQL.insert.await, qy.query, qy.values)
end

local function transaction(list)
    local ok, res = pcall(MySQL.transaction.await, list)
    if not ok then return false, tostring(res) end
    return res and true or false, res and nil or 'transaction failed'
end

-- unknown item names, gathered per step and listed once at the end of it
local function unknownItem(ctx, st, name, n)
    st.unknown = st.unknown or {}
    st.unknown[name] = (st.unknown[name] or 0) + (n or 1)
end

local function flushUnknown(ctx, st)
    if not st.unknown then return end
    local names = {}
    for n in pairs(st.unknown) do names[#names + 1] = n end
    table.sort(names)
    for _, n in ipairs(names) do note(ctx, st, n, 'import_unknown_item', n, st.unknown[n]) end
end

-- ---------------------------------------------------------------
-- jobs
-- ---------------------------------------------------------------

--- RSG job table for a job and grade; the job (and grade) is added when this server lacks it.
--- Returns the job table and whether it was new.
local function jobFor(ctx, name, grade, label)
    name = trim(name):lower()
    grade = math.floor(tonumber(grade) or 0)
    if name == '' then name, grade = 'unemployed', 0 end
    local job = RSGCore.Shared.Jobs[name]
    local isNew = not job or not job.grades[tostring(grade)]
    if isNew and not ctx.dry then
        MULTI.Jobs.Ensure(name, grade, (label and label ~= '') and label or nil)
        job = RSGCore.Shared.Jobs[name]
    end
    local g = job and job.grades[tostring(grade)] or {}
    return {
        name = name,
        label = (job and job.label) or ((label and label ~= '') and label) or name,
        payment = tonumber(g.payment) or 0,
        type = (job and job.type) or 'none',
        onduty = not job or job.defaultDuty ~= false,
        isboss = g.isboss == true,
        grade = { name = g.name or ('Grade ' .. grade), level = grade, isboss = g.isboss == true },
    }, isNew
end

local function jobQuery(name, grade, label)
    return {
        query = 'INSERT IGNORE INTO multicore_import_jobs (name, grade, label) VALUES (?, ?, ?)',
        values = { name, grade, label or '' },
    }
end

-- ---------------------------------------------------------------
-- character rows
-- ---------------------------------------------------------------

local function applyDefaults(data, defaults)
    for k, v in pairs(defaults) do
        if type(v) == 'function' then
            if data[k] == nil then data[k] = v() end
        elseif type(v) == 'table' and type(k) == 'string' then
            data[k] = data[k] or {}
            if type(data[k]) == 'table' then applyDefaults(data[k], v) end
        elseif data[k] == nil then
            data[k] = v
        end
    end
end

local function moneyDefaults()
    local m = {}
    for k in pairs(RSGCore.Config.Money.MoneyTypes) do m[k] = 0 end
    return m
end

local function idTaken(id)
    return MySQL.scalar.await('SELECT id FROM players WHERE id = ? LIMIT 1', { id }) ~= nil
end

local function citizenidTaken(cid)
    return MySQL.scalar.await('SELECT id FROM players WHERE citizenid = ? LIMIT 1', { cid }) ~= nil
end

local function nextFreeId(floor)
    local top = tonumber(MySQL.scalar.await('SELECT COALESCE(MAX(id), 0) FROM players')) or 0
    return math.max(top, floor or 0) + 1
end

local PLAYER_INSERT = 'INSERT INTO players (id, citizenid, cid, license, name, money, charinfo, job, gang, position, metadata, inventory) '
    .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'

local function playerQuery(id, d)
    return {
        query = PLAYER_INSERT,
        values = {
            id, d.citizenid, d.cid or 1, d.license, d.name or '', json.encode(d.money), json.encode(d.charinfo),
            json.encode(d.job), json.encode(d.gang), json.encode(d.position), json.encode(d.metadata), '[]',
        },
    }
end

local function countFor(ctx, license)
    ctx.cidCount[license] = ctx.cidCount[license]
        or tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM players WHERE license = ?', { license })) or 0
    ctx.cidCount[license] = ctx.cidCount[license] + 1
    return ctx.cidCount[license]
end

--- old inventory JSON (list or slot map) -> { { name, amount, info, slot } }
local function decodeItems(raw)
    local list = decode(raw)
    local outList = {}
    if type(list) ~= 'table' then return outList end
    for k, s in pairs(list) do
        if type(s) == 'table' and type(s.name or s.item) == 'string' then
            outList[#outList + 1] = {
                name = s.name or s.item,
                amount = math.floor(tonumber(s.amount or s.count) or 1),
                info = type(s.info) == 'table' and s.info or (type(s.metadata) == 'table' and s.metadata) or {},
                slot = tonumber(s.slot) or tonumber(k),
            }
        elseif type(k) == 'string' and tonumber(s) then
            -- the oldest shape: { item_name = count }
            outList[#outList + 1] = { name = k, amount = math.floor(tonumber(s)), info = {} }
        end
    end
    return outList
end

local function countItems(list)
    local n = 0
    for _, s in ipairs(list) do n = n + math.max(0, s.amount or 0) end
    return n
end

--- items whose name this server does not know (dry run and report)
local function checkNames(ctx, st, list)
    if GetResourceState(INV) ~= 'started' then return end
    for _, s in ipairs(list) do
        local ok, _, known = pcall(function() return inv():ImportResolve(s.name) end)
        if ok and not known then unknownItem(ctx, st, s.name, s.amount) end
    end
end

--- fills one inventory once. kind/key = its map entry. Returns 'done' | 'already' | 'failed'
local function fillOnce(ctx, st, kind, key, id, list, opts)
    if #list == 0 then return 'empty' end
    local m = mapGet(ctx, kind, key)
    if m and m.status == 'done' then st.already = st.already + 1 return 'already' end
    if ctx.dry then
        checkNames(ctx, st, list)
        st.moved = st.moved + 1
        st.dryItems = (st.dryItems or 0) + countItems(list)
        return 'done'
    end
    mapPut(ctx, kind, key, id, 'pending')
    local ok, r = pcall(function() return inv():ImportInventory(id, list, opts) end)
    if not ok or type(r) ~= 'table' then
        note(ctx, st, key, 'import_inventory_failed', id, tostring(r))
        return 'failed'
    end
    if r.status == 'present' then
        -- a run that stopped half way filled it already, or another import did
        mapPut(ctx, kind, key, id, 'done')
        if not m and (ctx.db or ctx.fw == 'vorp') then note(ctx, st, key, 'import_inventory_present', id) end
        st.already = st.already + 1
        return 'already'
    elseif r.status ~= 'done' then
        note(ctx, st, key, 'import_inventory_failed', id, tostring(r.status))
        return 'failed'
    end
    mapPut(ctx, kind, key, id, 'done')
    st.moved = st.moved + 1
    st.items = (st.items or 0) + (r.stacks or 0)
    st.weapons = (st.weapons or 0) + (r.weapons or 0)
    for _, n in ipairs(r.unknownNames or {}) do unknownItem(ctx, st, n) end
    for old, new in pairs(r.renamed or {}) do st.extra['renamed:' .. old] = new end
    if (r.skipped or 0) > 0 then note(ctx, st, key, 'import_inventory_skipped', r.skipped, id) end
    return 'done'
end

local function randomPlate()
    for _ = 1, 50 do
        local t = {}
        for i = 1, PLATE_LEN do
            local k = math.random(1, #PLATE_CHARS)
            t[i] = PLATE_CHARS:sub(k, k)
        end
        local plate = table.concat(t)
        local n = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM rsg_wagons WHERE custom LIKE ?', { '%"plate":"' .. plate .. '"%' })) or 0
        if n == 0 then return plate end
    end
end

local function newHorseId()
    for _ = 1, 100 do
        local id = tostring(RSGCore.Shared.RandomStr(3) .. RSGCore.Shared.RandomInt(3)):upper()
        if (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE horseid = ?', { id })) or 0) == 0 then return id end
    end
end

-- ===============================================================
-- VORP
-- ===============================================================

local VORP = {}

--- accounts (users) - only when the old tables are in another database; in the same
--- database MULTIcore already uses the old `users` table as it is
function VORP.accounts(ctx)
    if not ctx.db then return end
    local st = step(ctx, 'accounts')
    if not hasTable(ctx, 'users') then return end
    local cols = columns(ctx, 'users')
    local want = { 'identifier', 'group', 'warnings', 'banned', 'banneduntil', 'char', 'max_jobs', 'license' }
    local use = {}
    for _, c in ipairs(want) do if cols[c] then use[#use + 1] = q(c) end end
    for _, r in ipairs(MySQL.query.await(('SELECT %s FROM %s'):format(table.concat(use, ', '), T(ctx, 'users'))) or {}) do
        st.found = st.found + 1
        local have = MySQL.scalar.await('SELECT identifier FROM users WHERE identifier = ?', { r.identifier })
        if have then
            st.already = st.already + 1
        elseif ctx.dry then
            st.moved = st.moved + 1
        else
            local names, marks, vals = {}, {}, {}
            for _, c in ipairs(want) do
                if r[c] ~= nil then names[#names + 1] = q(c); marks[#marks + 1] = '?'; vals[#vals + 1] = r[c] end
            end
            local ok = pcall(MySQL.insert.await, ('INSERT IGNORE INTO users (%s) VALUES (%s)'):format(table.concat(names, ', '), table.concat(marks, ', ')), vals)
            if ok then st.moved = st.moved + 1 else note(ctx, st, r.identifier, 'import_account_failed') end
        end
    end
end

local function vorpLicenses(ctx)
    local map = {}
    local tbl = ctx.db and T(ctx, 'users') or 'users'
    local cols = ctx.db and columns(ctx, 'users') or { license = true }
    if cols.license and (not ctx.db or hasTable(ctx, 'users')) then
        for _, r in ipairs(MySQL.query.await(('SELECT identifier, license FROM %s WHERE license IS NOT NULL AND license <> ?'):format(tbl), { '' }) or {}) do
            map[r.identifier] = r.license
        end
    end
    -- MULTIcore's own users table learns licences as players join
    if ctx.db then
        for _, r in ipairs(MySQL.query.await('SELECT identifier, license FROM users WHERE license IS NOT NULL AND license <> ?', { '' }) or {}) do
            map[r.identifier] = map[r.identifier] or r.license
        end
    end
    return map
end

local function vorpBanks(ctx)
    local per = {}
    if not hasTable(ctx, 'bank_users') then return per end
    local cols = columns(ctx, 'bank_users')
    if not cols.charidentifier then return per end
    local sel = { 'charidentifier', cols.money and 'money' or '0 AS money', cols.gold and 'gold' or '0 AS gold', cols.items and 'items' or 'NULL AS items', cols.name and 'name' or "'' AS name" }
    for _, r in ipairs(MySQL.query.await(('SELECT %s FROM %s'):format(table.concat(sel, ', '), T(ctx, 'bank_users'))) or {}) do
        local id = tonumber(r.charidentifier)
        if id then
            local b = per[id] or { money = 0, gold = 0, n = 0, boxes = {} }
            b.money = b.money + (tonumber(r.money) or 0)
            b.gold = b.gold + (tonumber(r.gold) or 0)
            b.n = b.n + 1
            if nonEmptyJson(r.items) then b.boxes[#b.boxes + 1] = { bank = r.name, items = r.items } end
            per[id] = b
        end
    end
    return per
end

local function genderOf(g)
    g = tostring(g or ''):lower()
    return (g == 'female' or g == 'f' or g == '1' or g == 'woman') and 1 or 0
end

local function vorpPosition(raw)
    local c = decode(raw)
    if type(c) == 'table' and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) then
        return { x = tonumber(c.x), y = tonumber(c.y), z = tonumber(c.z), w = tonumber(c.heading or c.h or c.w) or 0.0 }
    end
    local s = RSGCore.Config.DefaultSpawn
    return { x = s.x, y = s.y, z = s.z, w = s.w or 0.0 }
end

local function parseTarget(t)
    local id, cid = tostring(t or ''):match('^(%d+):(.+)$')
    return tonumber(id), cid
end

function VORP.characters(ctx)
    local st = step(ctx, 'characters')
    ctx.chars = {}
    if not hasTable(ctx, 'characters') then note(ctx, st, nil, 'import_no_table', 'characters') return end
    local cols = columns(ctx, 'characters')
    if not cols.charidentifier then note(ctx, st, nil, 'import_not_vorp_characters') return end
    local licenses = vorpLicenses(ctx)
    local banks = vorpBanks(ctx)
    ctx.banks = banks
    local maxOld = tonumber(MySQL.scalar.await('SELECT COALESCE(MAX(charidentifier), 0) FROM ' .. T(ctx, 'characters'))) or 0
    -- in the same database MULTIcore keeps its own rows in `characters` too. It always fills the
    -- citizenid column (its own addition); VORP never does, so a row with one is not an old character.
    local function mine(r) return not ctx.db and type(r.citizenid) == 'string' and r.citizenid ~= '' end
    local hasSync = hasTargetTable('multicore_vorp_sync') and hasTargetTable('characters')
    local last = -1
    while true do
        local rows = MySQL.query.await(('SELECT * FROM %s WHERE charidentifier > ? ORDER BY charidentifier LIMIT %d'):format(T(ctx, 'characters'), PAGE), { last }) or {}
        if #rows == 0 then break end
        for _, r in ipairs(rows) do
            last = tonumber(r.charidentifier) or last
            local old = math.tointeger(tonumber(r.charidentifier))
            local m = mapGet(ctx, 'character', old)
            if m and m.status == 'done' then
                st.found = st.found + 1
                st.already = st.already + 1
                local id, cid = parseTarget(m.target_key)
                if id then ctx.chars[old] = { id = id, citizenid = cid, row = r } end
            elseif mine(r) then
                -- MULTIcore's own copy of one of its characters: nothing to bring over
            else
                st.found = st.found + 1
                VORP.character(ctx, st, r, old, licenses, banks, maxOld, hasSync)
            end
        end
        if #rows < PAGE then break end
    end
    local jobs = 0
    for _ in pairs(ctx.newJobs) do jobs = jobs + 1 end
    if jobs > 0 then st.extra.jobs = jobs end
end

function VORP.character(ctx, st, r, old, licenses, banks, maxOld, hasSync)
    local identifier = tostring(r.identifier or '')
    local license = licenses[identifier] or identifier
    if license == '' then note(ctx, st, old, 'import_no_owner') st.skipped = st.skipped + 1 return end
    if license:find('^steam:') then ctx.steamOwners = ctx.steamOwners + 1 end

    local first, lastName = trim(r.firstname), trim(r.lastname)
    if first == '' then first = 'Unknown' end
    if lastName == '' then lastName = 'Unknown' end
    local age = math.floor(tonumber(r.age) or 0)
    local birth = (age > 0 and age < 120) and ('%04d-01-01'):format(1899 - age) or MULTIConfig.Look.DefaultBirthdate

    local bank = banks[old]
    local money = moneyDefaults()
    money.cash = round2(r.money)
    money.gold = round2((tonumber(r.gold) or 0) + (bank and bank.gold or 0))
    money.rol = round2(r.rol)
    money.bank = round2(bank and bank.money or 0)
    if bank and bank.n > 1 then st.extra.banks = (st.extra.banks or 0) + 1 end

    local job, newJob = jobFor(ctx, r.job, r.jobgrade, r.joblabel)
    if newJob then ctx.newJobs[job.name .. ':' .. job.grade.level] = true end

    local meta = {}
    applyDefaults(meta, RSGCore.Config.Player.PlayerDefaults.metadata or {})
    meta.isdead = flag(r.isdead)
    meta.vorp = {
        group = r.group or 'user', xp = tonumber(r.xp) or 0, age = age,
        nickname = trim(r.nickname), description = trim(r.character_desc),
        skills = decode(r.skills) or {}, multijobs = decode(r.multijobs) or {},
        invCapacity = tonumber(r.slots), isdead = flag(r.isdead), hours = tonumber(r.hours) or 0,
    }
    MULTI.Accounts.VorpDefaults({ metadata = meta })

    if ctx.dry then
        st.moved = st.moved + 1
        ctx.chars[old] = { id = old, citizenid = '?', row = r, new = true }
        return
    end

    local id = (not idTaken(old)) and old or nil
    if not id then
        id = nextFreeId(maxOld)
        note(ctx, st, old, 'import_new_number', old, id, old)
    end
    local d = {
        citizenid = RSGCore.Player.CreateCitizenId(),
        cid = countFor(ctx, license),
        license = license,
        name = trim(r.steamname) ~= '' and trim(r.steamname) or (first .. ' ' .. lastName),
        money = money,
        charinfo = {
            firstname = first, lastname = lastName, birthdate = birth, gender = genderOf(r.gender),
            nationality = MULTIConfig.Look.DefaultNationality or 'USA',
            account = RSGCore.Functions.CreateAccountNumber(),
        },
        job = job,
        position = vorpPosition(r.coords),
        metadata = meta,
    }
    applyDefaults(d, { gang = RSGCore.Config.Player.PlayerDefaults.gang })
    local queries = { playerQuery(id, d) }
    if r.skinPlayer or r.compPlayer or r.compTints then
        queries[#queries + 1] = {
            query = "INSERT INTO multicore_appearance (citizenid, format, skin, comps, comp_tints) VALUES (?, 'vorp', ?, ?, ?) "
                .. 'ON DUPLICATE KEY UPDATE skin = VALUES(skin), comps = VALUES(comps), comp_tints = VALUES(comp_tints)',
            values = { d.citizenid, r.skinPlayer or '{}', r.compPlayer or '{}', r.compTints or '{}' },
        }
    end
    -- same database and same number: MULTIcore takes the old `characters` row over as its own.
    -- Its "last written" copy starts as the row is now, so a later script pay-out into it still lands.
    if hasSync and not ctx.db and id == old then
        queries[#queries + 1] = {
            query = 'INSERT INTO multicore_vorp_sync (charidentifier, citizenid, money, gold, rol, job, jobgrade, joblabel) '
                .. 'SELECT charidentifier, ?, money, gold, rol, job, jobgrade, joblabel FROM characters WHERE charidentifier = ? '
                .. 'ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid), money = VALUES(money), gold = VALUES(gold), rol = VALUES(rol), '
                .. 'job = VALUES(job), jobgrade = VALUES(jobgrade), joblabel = VALUES(joblabel)',
            values = { d.citizenid, id },
        }
    end
    if newJob then queries[#queries + 1] = jobQuery(job.name, job.grade.level, job.label) end
    queries[#queries + 1] = mapQuery(ctx, 'character', old, id .. ':' .. d.citizenid)
    local ok, err = transaction(queries)
    if not ok then
        note(ctx, st, old, 'import_character_failed', tostring(err))
        st.skipped = st.skipped + 1
        ctx.cidCount[license] = ctx.cidCount[license] - 1
        return
    end
    st.moved = st.moved + 1
    ctx.chars[old] = { id = id, citizenid = d.citizenid, row = r, new = true }
end

--- character_inventories (+ items_crafted, items), loadout, gunbelt ammo, custom inventories
function VORP.inventory(ctx)
    local st = step(ctx, 'inventory')
    if GetResourceState(INV) ~= 'started' then note(ctx, st, nil, 'import_no_inventory') return end
    local hasCI = hasTable(ctx, 'character_inventories')
    local ciCols = hasCI and columns(ctx, 'character_inventories') or {}
    local hasIC = hasTable(ctx, 'items_crafted')
    local icCols = hasIC and columns(ctx, 'items_crafted') or {}
    local hasItems = hasTable(ctx, 'items')
    local hasLoadout = hasTable(ctx, 'loadout')
    local loCols = hasLoadout and columns(ctx, 'loadout') or {}

    -- how many characters use each custom inventory (one = it is that character's own or a shared one)
    local owners = {}
    if hasCI then
        for _, r in ipairs(MySQL.query.await(('SELECT inventory_type AS t, COUNT(DISTINCT character_id) AS n FROM %s WHERE inventory_type <> ? GROUP BY inventory_type')
            :format(T(ctx, 'character_inventories')), { 'default' }) or {}) do owners[r.t] = tonumber(r.n) or 0 end
    end
    if hasLoadout and loCols.curr_inv then
        for _, r in ipairs(MySQL.query.await(('SELECT curr_inv AS t, COUNT(DISTINCT charidentifier) AS n FROM %s WHERE curr_inv <> ? GROUP BY curr_inv')
            :format(T(ctx, 'loadout')), { 'default' }) or {}) do owners[r.t] = math.max(owners[r.t] or 0, tonumber(r.n) or 0) end
    end

    local sel = { 'ci.inventory_type AS inv', 'ci.amount' }
    local join = ''
    if ciCols.item_name then sel[#sel + 1] = 'ci.item_name AS ci_name' end
    if ciCols.percentage then sel[#sel + 1] = 'ci.percentage' end
    if hasIC then
        join = (' LEFT JOIN %s ic ON ic.id = ci.item_crafted_id'):format(T(ctx, 'items_crafted'))
        if icCols.metadata then sel[#sel + 1] = 'ic.metadata' end
        if icCols.item_name then sel[#sel + 1] = 'ic.item_name AS ic_name' end
        if hasItems and icCols.item_id then
            join = join .. (' LEFT JOIN %s i ON i.id = ic.item_id'):format(T(ctx, 'items'))
            sel[#sel + 1] = 'i.item AS i_name'
        end
    end
    local itemQuery = hasCI and ('SELECT %s FROM %s ci%s WHERE ci.character_id = ?'):format(table.concat(sel, ', '), T(ctx, 'character_inventories'), join)
    local loWhere = loCols.dropped and ' AND (dropped IS NULL OR dropped = 0)' or ''
    local weaponQuery = hasLoadout and ('SELECT * FROM %s WHERE charidentifier = ?%s ORDER BY id'):format(T(ctx, 'loadout'), loWhere)

    local function itemName(r)
        for _, n in ipairs({ r.ci_name, r.ic_name, r.i_name }) do
            if type(n) == 'string' and n ~= '' and n ~= 'item' then return n end
        end
    end

    local ids = {}
    for old in pairs(ctx.chars) do ids[#ids + 1] = old end
    table.sort(ids)
    for _, old in ipairs(ids) do
        local ch = ctx.chars[old]
        local lists = { default = {} }
        local function add(invType, entry)
            invType = (invType == nil or invType == '') and 'default' or invType
            lists[invType] = lists[invType] or {}
            local l = lists[invType]
            l[#l + 1] = entry
        end
        if itemQuery then
            for _, r in ipairs(MySQL.query.await(itemQuery, { old }) or {}) do
                local name = itemName(r)
                if not name then
                    note(ctx, st, old, 'import_item_no_name')
                else
                    local info = decode(r.metadata)
                    info = type(info) == 'table' and info or {}
                    if r.percentage and tonumber(r.percentage) and info.quality == nil then info.quality = tonumber(r.percentage) end
                    add(r.inv, { name = name, amount = math.floor(tonumber(r.amount) or 1), info = info })
                end
            end
        end
        -- the oldest VORP shape kept items in characters.inventory
        if #lists.default == 0 and nonEmptyJson(ch.row.inventory) then
            for _, e in ipairs(decodeItems(ch.row.inventory)) do add('default', e) end
        end
        if weaponQuery then
            for _, w in ipairs(MySQL.query.await(weaponQuery, { old }) or {}) do
                local info = {
                    serie = w.serial_number, custom_label = w.custom_label, custom_desc = w.custom_desc,
                    components = decode(w.components), comps = decode(w.comps),
                    ammo = decode(w.ammo),
                }
                if type(info.components) == 'table' and next(info.components) == nil then info.components = nil end
                if type(info.comps) == 'table' and next(info.comps) == nil then info.comps = nil end
                if type(info.ammo) == 'table' and next(info.ammo) == nil then info.ammo = nil end
                add(w.curr_inv, { name = tostring(w.name or ''), amount = 1, info = info })
            end
        end

        st.found = st.found + 1
        local target = ctx.dry and ('player:' .. old) or ('player:' .. ch.id)
        local res = fillOnce(ctx, st, 'inventory', old, target, lists.default)
        if res == 'empty' then st.extra.empty = (st.extra.empty or 0) + 1 end

        -- gunbelt ammo (characters.ammo), once per character
        local ammo = decode(ch.row.ammo)
        if type(ammo) == 'table' and next(ammo) then
            local m = mapGet(ctx, 'ammo', old)
            if not (m and m.status == 'done') then
                if ctx.dry then
                    st.ammo = (st.ammo or 0) + 1
                else
                    local ok, r = pcall(function() return inv():ImportAmmo(ch.id, ammo) end)
                    if ok and type(r) == 'table' then
                        mapPut(ctx, 'ammo', old, ch.id, 'done')
                        st.ammo = (st.ammo or 0) + 1
                        for _, t in ipairs(r.unknown or {}) do note(ctx, st, old, 'import_unknown_ammo', t) end
                    else
                        note(ctx, st, old, 'import_ammo_failed', tostring(r))
                    end
                end
            end
        end

        -- custom inventories (VORP scripts' own storages): same id here, per character when several use it
        for invType, list in pairs(lists) do
            if invType ~= 'default' then
                local key = invType .. '|' .. old
                local id = invType
                if not ctx.dry then
                    local ok, t = pcall(function() return inv():ImportTarget(invType, ch.id, (owners[invType] or 1) <= 1) end)
                    id = ok and t or invType
                end
                if fillOnce(ctx, st, 'custominv', key, id, list) == 'done' then
                    st.extra.custom = (st.extra.custom or 0) + 1
                end
            end
        end
    end
    flushUnknown(ctx, st)
end

--- stables (horses and carts) and wagons
function VORP.horses(ctx)
    local st = step(ctx, 'horses')
    local bags = step(ctx, 'saddlebags')
    local wt = step(ctx, 'wagons')
    local trunks = step(ctx, 'wagon storage')
    local horsesHere, wagonsHere = hasTargetTable('player_horses'), hasTargetTable('rsg_wagons')
    if hasTable(ctx, 'stables') then
        for _, r in ipairs(MySQL.query.await('SELECT * FROM ' .. T(ctx, 'stables') .. ' ORDER BY id') or {}) do
            local kind = tostring(r.type or 'horse'):lower()
            local isHorse = kind == 'horse' or kind == ''
            local s = isHorse and st or wt
            s.found = s.found + 1
            local ch = ctx.chars[tonumber(r.charidentifier)]
            if not ch then
                note(ctx, s, r.id, 'import_owner_missing', tostring(r.charidentifier))
                s.skipped = s.skipped + 1
            elseif isHorse then
                if not horsesHere then
                    note(ctx, s, r.id, 'import_no_target', 'player_horses', 'MULTIhorses')
                    s.skipped = s.skipped + 1
                else
                    VORP.horse(ctx, s, bags, r, ch)
                end
            elseif not wagonsHere then
                note(ctx, s, r.id, 'import_no_target', 'rsg_wagons', 'MULTIwagons')
                s.skipped = s.skipped + 1
            else
                VORP.wagon(ctx, s, trunks, 'stables:' .. r.id, ch, r.modelname, r.name, flag(r.isDefault), r.inventory)
            end
        end
    end
    if hasTable(ctx, 'wagons') then
        local cols = columns(ctx, 'wagons')
        if cols.charid and cols.model then
            for _, r in ipairs(MySQL.query.await('SELECT * FROM ' .. T(ctx, 'wagons') .. ' ORDER BY id') or {}) do
                wt.found = wt.found + 1
                local ch = ctx.chars[tonumber(r.charid)]
                if not ch then
                    note(ctx, wt, 'wagons:' .. r.id, 'import_owner_missing', tostring(r.charid))
                    wt.skipped = wt.skipped + 1
                elseif not wagonsHere then
                    note(ctx, wt, 'wagons:' .. r.id, 'import_no_target', 'rsg_wagons', 'MULTIwagons')
                    wt.skipped = wt.skipped + 1
                else
                    VORP.wagon(ctx, wt, trunks, 'wagons:' .. r.id, ch, r.model, r.name, flag(r.selected), r.items)
                end
            end
        end
    end
    if hasTable(ctx, 'horse_complements') then
        local n = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM ' .. T(ctx, 'horse_complements'))) or 0
        if n > 0 then note(ctx, st, 'horse_complements', 'import_tack_owned', n) end
    end
    flushUnknown(ctx, bags)
    flushUnknown(ctx, trunks)
end

function VORP.horse(ctx, st, bags, r, ch)
    local m = mapGet(ctx, 'horse', r.id)
    local horseid
    if m and m.status == 'done' then
        st.already = st.already + 1
        horseid = m.target_key
    else
        if nonEmptyJson(r.gear) then st.extra.tack = (st.extra.tack or 0) + 1 end
        local status = decode(r.status) or {}
        local gender = tostring(status.gender or status.sex or 'male'):lower()
        gender = (gender == 'female' or gender == 'f' or gender == '1') and 'female' or 'male'
        if ctx.dry then
            st.moved = st.moved + 1
            horseid = 'DRY' .. r.id
        else
            horseid = newHorseId()
            local ok, err = transaction({
                {
                    query = 'INSERT INTO player_horses (stable, citizenid, horseid, name, horse, gender, active, born, horsexp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    values = { 'valentine', ch.citizenid, horseid, tostring(r.name or 'Horse'):sub(1, 50), tostring(r.modelname or ''),
                               gender, flag(r.isDefault) and 1 or 0, os.time(), tonumber(r.xp) or 0 },
                },
                mapQuery(ctx, 'horse', r.id, horseid),
            })
            if not ok then
                note(ctx, st, r.id, 'import_row_failed', tostring(err))
                st.skipped = st.skipped + 1
                return
            end
            st.moved = st.moved + 1
        end
    end
    if nonEmptyJson(r.inventory) then
        bags.found = bags.found + 1
        fillOnce(ctx, bags, 'horseinv', r.id, 'custom:horse_' .. horseid, decodeItems(r.inventory), { label = tostring(r.name or 'Horse') })
    end
end

function VORP.wagon(ctx, st, trunks, key, ch, model, name, active, items)
    local m = mapGet(ctx, 'wagon', key)
    local plate
    if m and m.status == 'done' then
        st.already = st.already + 1
        plate = m.target_key
    elseif ctx.dry then
        st.moved = st.moved + 1
        plate = 'DRY'
    else
        plate = randomPlate()
        local custom = { name = tostring(name or ''):sub(1, 40), tint = 0, livery = -1, props = false, extras = {}, buyMoneyType = 'cash', plate = plate }
        local ok, err = transaction({
            {
                query = 'INSERT INTO rsg_wagons (citizenid, wagon, custom, animals, active) VALUES (?, ?, ?, ?, ?)',
                values = { ch.citizenid, tostring(model or ''), json.encode(custom), '[]', active and 1 or 0 },
            },
            mapQuery(ctx, 'wagon', key, plate),
        })
        if not ok then
            note(ctx, st, key, 'import_row_failed', tostring(err))
            st.skipped = st.skipped + 1
            return
        end
        st.moved = st.moved + 1
    end
    if nonEmptyJson(items) then
        trunks.found = trunks.found + 1
        fillOnce(ctx, trunks, 'wagoninv', key, 'trunk:' .. plate, decodeItems(items), { label = tostring(name or 'Wagon') })
    end
end

--- houses and bank boxes: MULTIcore has no matching place; every one is listed
function VORP.leftovers(ctx)
    local st = step(ctx, 'houses')
    for _, tbl in ipairs({ 'housing', 'rooms' }) do
        if hasTable(ctx, tbl) then
            local cols = columns(ctx, tbl)
            local sel = cols.charidentifier and 'id, charidentifier' or 'id, NULL AS charidentifier'
            for _, r in ipairs(MySQL.query.await(('SELECT %s FROM %s'):format(sel, T(ctx, tbl))) or {}) do
                st.found = st.found + 1
                st.skipped = st.skipped + 1
                note(ctx, st, tbl .. ':' .. tostring(r.id), 'import_house_vorp', tostring(r.charidentifier))
            end
        end
    end
    local bt = step(ctx, 'bank')
    for old, b in pairs(ctx.banks or {}) do
        bt.found = bt.found + b.n
        if not ctx.chars[old] then bt.skipped = bt.skipped + b.n elseif ctx.chars[old].new then bt.moved = bt.moved + b.n else bt.already = bt.already + b.n end
        for _, box in ipairs(b.boxes) do
            note(ctx, bt, old, 'import_bank_box', tostring(box.bank), #decodeItems(box.items))
        end
    end
end

-- ===============================================================
-- RSG-Core
-- ===============================================================

local RSG = {}

local function rsgCid(ctx, old) return ctx.cids[old] end

local JSON_COLS = { 'money', 'charinfo', 'job', 'gang', 'position', 'metadata' }

function RSG.characters(ctx)
    local st = step(ctx, 'characters')
    ctx.chars = {}
    if not hasTable(ctx, 'players') then note(ctx, st, nil, 'import_no_table', 'players') return end
    local cols = columns(ctx, 'players')
    if not cols.citizenid or not cols.license then note(ctx, st, nil, 'import_not_rsg_players') return end
    local extraTables = {}
    if ctx.db then
        for _, t in ipairs({ 'playerskins', 'playeroutfit', 'player_jobs' }) do
            if hasTable(ctx, t) and hasTargetTable(t) then extraTables[#extraTables + 1] = t end
        end
    end
    local last = -1
    while true do
        local rows = MySQL.query.await(('SELECT * FROM %s WHERE id > ? ORDER BY id LIMIT %d'):format(T(ctx, 'players'), PAGE), { last }) or {}
        if #rows == 0 then break end
        for _, r in ipairs(rows) do
            last = tonumber(r.id) or last
            st.found = st.found + 1
            local old = r.citizenid
            local job = decode(r.job) or {}
            local m = mapGet(ctx, 'character', old)
            if m and m.status == 'done' then
                st.already = st.already + 1
                local id, cid = parseTarget(m.target_key)
                if id then ctx.chars[old] = { id = id, citizenid = cid, row = r } ctx.cids[old] = cid end
            elseif not ctx.db then
                -- the same database: RSG's players table is MULTIcore's own, the character is already here
                st.already = st.already + 1
                local jt, newJob = jobFor(ctx, job.name, job.grade and job.grade.level, job.label)
                local queries = { mapQuery(ctx, 'character', old, r.id .. ':' .. old) }
                if newJob then
                    ctx.newJobs[jt.name .. ':' .. jt.grade.level] = true
                    queries[#queries + 1] = jobQuery(jt.name, jt.grade.level, jt.label)
                end
                if not ctx.dry then transaction(queries) end
                ctx.chars[old] = { id = tonumber(r.id), citizenid = old, row = r }
                ctx.cids[old] = old
            else
                RSG.character(ctx, st, r, old, job, extraTables)
            end
        end
        if #rows < PAGE then break end
    end
    local jobs = 0
    for _ in pairs(ctx.newJobs) do jobs = jobs + 1 end
    if jobs > 0 then st.extra.jobs = jobs end
end

function RSG.character(ctx, st, r, old, job, extraTables)
    local jt, newJob = jobFor(ctx, job.name, job.grade and job.grade.level, job.label)
    if newJob then ctx.newJobs[jt.name .. ':' .. jt.grade.level] = true end
    if ctx.dry then
        st.moved = st.moved + 1
        ctx.chars[old] = { id = tonumber(r.id), citizenid = old, row = r }
        ctx.cids[old] = old
        return
    end
    local cid = old
    if citizenidTaken(old) then
        local sameOwner = MySQL.scalar.await('SELECT id FROM players WHERE citizenid = ? AND license = ?', { old, r.license })
        if sameOwner then
            -- brought over before (by hand or another tool): use it as it is
            transaction({ mapQuery(ctx, 'character', old, sameOwner .. ':' .. old) })
            st.already = st.already + 1
            ctx.chars[old] = { id = tonumber(sameOwner), citizenid = old, row = r }
            ctx.cids[old] = old
            return
        end
        cid = RSGCore.Player.CreateCitizenId()
        note(ctx, st, old, 'import_new_citizenid', old, cid)
    end
    local d = { citizenid = cid, cid = tonumber(r.cid) or 1, license = r.license, name = r.name }
    for _, c in ipairs(JSON_COLS) do d[c] = decode(r[c]) end
    d.money = d.money or moneyDefaults()
    d.job = jt
    d.charinfo = d.charinfo or {}
    d.metadata = d.metadata or {}
    d.position = d.position or {}
    applyDefaults(d, { gang = RSGCore.Config.Player.PlayerDefaults.gang })
    local id = nextFreeId()
    local queries = { playerQuery(id, d) }
    for _, t in ipairs(extraTables) do
        local cols, mine = columns(ctx, t), targetColumns(t)
        local names = {}
        for c in pairs(cols) do if c ~= 'id' and c ~= 'citizenid' and mine[c] then names[#names + 1] = q(c) end end
        table.sort(names)
        if #names > 0 then
            local list = table.concat(names, ', ')
            queries[#queries + 1] = {
                query = ('INSERT INTO %s (citizenid, %s) SELECT ?, %s FROM %s WHERE citizenid = ?'):format(q(t), list, list, T(ctx, t)),
                values = { cid, old },
            }
        end
    end
    if newJob then queries[#queries + 1] = jobQuery(jt.name, jt.grade.level, jt.label) end
    queries[#queries + 1] = mapQuery(ctx, 'character', old, id .. ':' .. cid)
    local ok, err = transaction(queries)
    if not ok then
        note(ctx, st, old, 'import_character_failed', tostring(err))
        st.skipped = st.skipped + 1
        return
    end
    st.moved = st.moved + 1
    ctx.chars[old] = { id = id, citizenid = cid, row = r }
    ctx.cids[old] = cid
end

--- players.inventory (the satchel) and `inventories` (stashes, trunks, horse bags ...)
function RSG.inventory(ctx)
    local st = step(ctx, 'inventory')
    if GetResourceState(INV) ~= 'started' then note(ctx, st, nil, 'import_no_inventory') return end
    -- the same database: MULTIinventory moved players.inventory and `inventories` itself on its first
    -- start. Those old columns are not kept up to date afterwards, so they must not be read again.
    if not ctx.db and hasTargetTable('multiinv_migration')
        and (tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM multiinv_migration WHERE step = 'old_multiinventory' AND status = 'done'")) or 0) > 0 then
        for _ in pairs(ctx.chars) do st.found = st.found + 1 end
        st.already = st.found
        st.extra.byInventory = true
        return
    end
    local ids = {}
    for old in pairs(ctx.chars) do ids[#ids + 1] = old end
    table.sort(ids)
    for _, old in ipairs(ids) do
        local ch = ctx.chars[old]
        local list = decodeItems(ch.row.inventory)
        st.found = st.found + 1
        local res = fillOnce(ctx, st, 'inventory', old, 'player:' .. tostring(ch.id), list)
        if res == 'empty' then st.extra.empty = (st.extra.empty or 0) + 1 end
    end
    flushUnknown(ctx, st)

    local ss = step(ctx, 'stashes')
    if not hasTable(ctx, 'inventories') then return end
    local cols = columns(ctx, 'inventories')
    if not cols.identifier or not cols.items then return end
    local last = ''
    while true do
        local rows = MySQL.query.await(('SELECT identifier, items FROM %s WHERE identifier > ? ORDER BY identifier LIMIT %d'):format(T(ctx, 'inventories'), PAGE), { last }) or {}
        if #rows == 0 then break end
        for _, r in ipairs(rows) do
            last = r.identifier
            local list = decodeItems(r.items)
            if #list > 0 then
                ss.found = ss.found + 1
                local ok, id = pcall(function() return inv():ImportStashId(r.identifier) end)
                id = ok and id or nil
                if not id or id:match('^player:') or #id > 100 then
                    note(ctx, ss, r.identifier, 'import_stash_unusable')
                    ss.skipped = ss.skipped + 1
                else
                    fillOnce(ctx, ss, 'stash', r.identifier, id, list)
                end
            end
        end
        if #rows < PAGE then break end
    end
    flushUnknown(ctx, ss)
end

--- rsg-horses: player_horses is MULTIhorses' own table; rows are copied only from another database
function RSG.horses(ctx)
    local st = step(ctx, 'horses')
    if not hasTable(ctx, 'player_horses') then return end
    if not ctx.db then
        st.found = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM player_horses')) or 0
        st.already = st.found
        return
    end
    if not hasTargetTable('player_horses') then note(ctx, st, nil, 'import_no_target', 'player_horses', 'MULTIhorses') return end
    local cols = columns(ctx, 'player_horses')
    local mine = targetColumns('player_horses')
    for _, r in ipairs(MySQL.query.await('SELECT * FROM ' .. T(ctx, 'player_horses') .. ' ORDER BY id') or {}) do
        st.found = st.found + 1
        local cid = rsgCid(ctx, r.citizenid)
        local m = mapGet(ctx, 'horse', r.id)
        if m and m.status == 'done' then
            st.already = st.already + 1
        elseif not cid then
            note(ctx, st, r.id, 'import_owner_missing', tostring(r.citizenid))
            st.skipped = st.skipped + 1
        elseif ctx.dry then
            st.moved = st.moved + 1
        else
            local horseid = r.horseid
            if not horseid or (tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM player_horses WHERE horseid = ?', { horseid })) or 0) > 0 then
                local new = newHorseId()
                note(ctx, st, r.id, 'import_new_horseid', tostring(horseid), new)
                horseid = new
            end
            local names, marks, vals = {}, {}, {}
            for c in pairs(cols) do
                if c ~= 'id' and mine[c] and r[c] ~= nil then
                    local v = r[c]
                    if c == 'citizenid' then v = cid elseif c == 'horseid' then v = horseid end
                    names[#names + 1] = q(c); marks[#marks + 1] = '?'; vals[#vals + 1] = v
                end
            end
            local ok, err = transaction({
                { query = ('INSERT INTO player_horses (%s) VALUES (%s)'):format(table.concat(names, ', '), table.concat(marks, ', ')), values = vals },
                mapQuery(ctx, 'horse', r.id, horseid),
            })
            if ok then st.moved = st.moved + 1 else
                note(ctx, st, r.id, 'import_row_failed', tostring(err))
                st.skipped = st.skipped + 1
            end
        end
    end
end

--- rsg-wagons (player_wagons) -> MULTIwagons (rsg_wagons)
function RSG.wagons(ctx)
    local st = step(ctx, 'wagons')
    if not hasTable(ctx, 'player_wagons') then return end
    if not hasTargetTable('rsg_wagons') then note(ctx, st, nil, 'import_no_target', 'rsg_wagons', 'MULTIwagons') return end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM ' .. T(ctx, 'player_wagons') .. ' ORDER BY id') or {}) do
        st.found = st.found + 1
        local cid = rsgCid(ctx, r.citizenid)
        local m = mapGet(ctx, 'wagon', r.id)
        if m and m.status == 'done' then
            st.already = st.already + 1
        elseif not cid then
            note(ctx, st, r.id, 'import_owner_missing', tostring(r.citizenid))
            st.skipped = st.skipped + 1
        elseif ctx.dry then
            st.moved = st.moved + 1
            if nonEmptyJson(r.cargo) then note(ctx, st, r.id, 'import_wagon_cargo') end
        else
            local plate = randomPlate()
            local tint, livery = tonumber(r.tint) or -1, tonumber(r.livery) or -1
            local custom = {
                name = tostring(r.name or ''):sub(1, 40), tint = tint >= 0 and tint or 0, livery = livery,
                props = false, extras = {}, buyMoneyType = 'cash', plate = plate,
            }
            local ok, err = transaction({
                {
                    query = 'INSERT INTO rsg_wagons (citizenid, wagon, custom, animals, active) VALUES (?, ?, ?, ?, ?)',
                    values = { cid, tostring(r.model or ''), json.encode(custom), '[]', flag(r.active) and 1 or 0 },
                },
                mapQuery(ctx, 'wagon', r.id, plate),
            })
            if ok then
                st.moved = st.moved + 1
                if nonEmptyJson(r.cargo) then note(ctx, st, r.id, 'import_wagon_cargo') end
            else
                note(ctx, st, r.id, 'import_row_failed', tostring(err))
                st.skipped = st.skipped + 1
            end
        end
    end
end

--- rsg-houses (player_houses, player_housekeys) -> MULTIhouses (multi_houses, multi_housekeys)
function RSG.houses(ctx)
    local st = step(ctx, 'houses')
    if not hasTable(ctx, 'player_houses') then return end
    if not hasTargetTable('multi_houses') then note(ctx, st, nil, 'import_no_target', 'multi_houses', 'MULTIhouses') return end
    local cols = columns(ctx, 'player_houses')
    local where = cols.owned and ' WHERE owned = 1' or ''
    for _, r in ipairs(MySQL.query.await('SELECT * FROM ' .. T(ctx, 'player_houses') .. where) or {}) do
        st.found = st.found + 1
        local key = tostring(r.houseid)
        local cid = rsgCid(ctx, r.citizenid)
        local m = mapGet(ctx, 'house', key)
        local here = MySQL.single.await('SELECT citizenid, owned FROM multi_houses WHERE houseid = ?', { key })
        if m and m.status == 'done' then
            st.already = st.already + 1
        elseif not cid then
            note(ctx, st, key, 'import_owner_missing', tostring(r.citizenid))
            st.skipped = st.skipped + 1
        elseif not here then
            note(ctx, st, key, 'import_house_unknown')
            st.skipped = st.skipped + 1
        elseif flag(here.owned) and here.citizenid ~= cid then
            note(ctx, st, key, 'import_house_taken', tostring(here.citizenid))
            st.skipped = st.skipped + 1
        elseif ctx.dry then
            st.moved = st.moved + 1
        else
            local ok, err = transaction({
                {
                    query = 'UPDATE multi_houses SET citizenid = ?, fullname = ?, owned = 1, credit = ?, bought_at = ? WHERE houseid = ?',
                    values = { cid, tostring(r.fullname or ''), math.floor(tonumber(r.credit) or 0), os.time(), key },
                },
                mapQuery(ctx, 'house', key, cid),
            })
            if ok then st.moved = st.moved + 1 else
                note(ctx, st, key, 'import_row_failed', tostring(err))
                st.skipped = st.skipped + 1
            end
        end
    end
    local kt = step(ctx, 'housekeys')
    if not hasTable(ctx, 'player_housekeys') or not hasTargetTable('multi_housekeys') then return end
    local kcols = columns(ctx, 'player_housekeys')
    for _, r in ipairs(MySQL.query.await('SELECT * FROM ' .. T(ctx, 'player_housekeys')) or {}) do
        kt.found = kt.found + 1
        local key = (r.id ~= nil) and tostring(r.id) or (tostring(r.houseid) .. '|' .. tostring(r.citizenid))
        local cid = rsgCid(ctx, r.citizenid)
        local m = mapGet(ctx, 'housekey', key)
        if m and m.status == 'done' then
            kt.already = kt.already + 1
        elseif not cid then
            note(ctx, kt, key, 'import_owner_missing', tostring(r.citizenid))
            kt.skipped = kt.skipped + 1
        elseif ctx.dry then
            kt.moved = kt.moved + 1
        else
            local guest = kcols.guest and (flag(r.guest) and 1 or 0) or 0
            local ok, err = transaction({
                {
                    query = 'INSERT INTO multi_housekeys (houseid, citizenid, guest) SELECT ?, ?, ? FROM DUAL WHERE NOT EXISTS '
                        .. '(SELECT 1 FROM multi_housekeys WHERE houseid = ? AND citizenid = ?)',
                    values = { tostring(r.houseid), cid, guest, tostring(r.houseid), cid },
                },
                mapQuery(ctx, 'housekey', key, cid),
            })
            if ok then kt.moved = kt.moved + 1 else
                note(ctx, kt, key, 'import_row_failed', tostring(err))
                kt.skipped = kt.skipped + 1
            end
        end
    end
end

--- newer rsg-banking keeps town accounts in its own table: listed, not moved
function RSG.bank(ctx)
    if not hasTable(ctx, 'rsg_bank_accounts') then return end
    local st = step(ctx, 'bank')
    local r = MySQL.single.await('SELECT COUNT(*) AS n, COALESCE(SUM(balance), 0) AS total FROM ' .. T(ctx, 'rsg_bank_accounts')) or {}
    st.found = tonumber(r.n) or 0
    st.skipped = st.found
    if st.found > 0 then note(ctx, st, 'rsg_bank_accounts', 'import_rsg_bank', st.found, round2(r.total)) end
end

-- ===============================================================
-- running it
-- ===============================================================

local FRAMEWORKS = {
    vorp = { VORP.accounts, VORP.characters, VORP.inventory, VORP.horses, VORP.leftovers },
    rsg = { RSG.characters, RSG.inventory, RSG.horses, RSG.wagons, RSG.houses, RSG.bank },
}

local function printReport(ctx)
    out(_L(ctx.dry and 'import_report_dry' or 'import_report', ctx.fw:upper(), ctx.db or _L('import_same_db')))
    for _, st in ipairs(ctx.steps) do
        local line = _L('import_step_line', st.name, st.found, st.moved, st.already, st.skipped)
        local extra = {}
        if st.items then extra[#extra + 1] = _L('import_extra_items', st.items) end
        if st.dryItems then extra[#extra + 1] = _L('import_extra_items_dry', st.dryItems) end
        if (st.weapons or 0) > 0 then extra[#extra + 1] = _L('import_extra_weapons', st.weapons) end
        if st.ammo then extra[#extra + 1] = _L('import_extra_ammo', st.ammo) end
        if st.extra.custom then extra[#extra + 1] = _L('import_extra_custom', st.extra.custom) end
        if st.extra.empty then extra[#extra + 1] = _L('import_extra_empty', st.extra.empty) end
        if st.extra.jobs then extra[#extra + 1] = _L('import_extra_jobs', st.extra.jobs) end
        if st.extra.banks then extra[#extra + 1] = _L('import_extra_banks', st.extra.banks) end
        if st.extra.tack then extra[#extra + 1] = _L('import_extra_tack', st.extra.tack) end
        if st.extra.byInventory then extra[#extra + 1] = _L('import_extra_by_inventory') end
        if st.notes > 0 then extra[#extra + 1] = _L('import_extra_notes', st.notes) end
        if #extra > 0 then line = line .. ' (' .. table.concat(extra, ', ') .. ')' end
        -- a step that found nothing and has nothing to say stays out of the report
        if st.found > 0 or st.notes > 0 or st.name == 'characters' then out(line) end
    end
    local renamed = {}
    for _, st in ipairs(ctx.steps) do
        for k, v in pairs(st.extra) do
            if type(k) == 'string' and k:find('^renamed:') then renamed[k:sub(9)] = v end
        end
    end
    for old, new in pairs(renamed) do out(_L('import_renamed', old, new)) end
    if ctx.steamOwners > 0 then out(_L('import_steam_owners', ctx.steamOwners)) end
    if ctx.notes > 0 then
        out(ctx.dry and _L('import_notes_dry', ctx.notes) or _L('import_notes', ctx.notes, ctx.run))
    else
        out(_L('import_no_notes'))
    end
    out(ctx.dry and _L('import_done_dry') or _L('import_done'))
end

--- Runs an import. opts = { dry = bool, from = 'database' | nil }. Returns the report table or nil, reason.
function I.Run(fw, opts)
    opts = opts or {}
    fw = tostring(fw or ''):lower()
    if fw == 'redm' then fw = 'rsg' end
    local steps = FRAMEWORKS[fw]
    if not steps then return nil, 'framework' end
    if opts.from ~= nil and not tostring(opts.from):match('^[%w_%$]+$') then return nil, 'database_name' end
    if I.running then return nil, 'running' end
    MULTI.Schema.Wait()
    if GetResourceState(INV) == 'started' then
        local t = 0
        while not inv():IsReady() and t < 600 do Wait(100) t = t + 1 end
    end
    local ctx = {
        fw = fw, db = opts.from, dry = opts.dry == true,
        source = fw .. (opts.from and ('@' .. opts.from) or ''),
        run = os.time(), steps = {}, notes = 0, chars = {}, cids = {}, newJobs = {}, cidCount = {}, steamOwners = 0,
    }
    if ctx.db then
        local ok, n = pcall(MySQL.scalar.await, 'SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = ?', { ctx.db })
        if not ok or (tonumber(n) or 0) == 0 then return nil, 'database_missing' end
    end
    I.running = true
    out(_L(ctx.dry and 'import_start_dry' or 'import_start', fw:upper(), ctx.db or _L('import_same_db')))
    local ok, err = pcall(function()
        for _, fn in ipairs(steps) do fn(ctx) end
    end)
    I.running = false
    if not ok then
        print(('^1[MULTIcore import] %s^7'):format(_L('import_crashed', tostring(err))))
        return nil, 'error'
    end
    printReport(ctx)
    if not ctx.dry then I.CountSteamOwners() end
    local report = { dry = ctx.dry, source = ctx.source, run = ctx.run, notes = ctx.notes, steps = {} }
    for _, st in ipairs(ctx.steps) do
        report.steps[st.name] = {
            found = st.found, moved = st.moved, already = st.already, skipped = st.skipped, notes = st.notes,
            items = st.items, weapons = st.weapons, ammo = st.ammo, custom = st.extra.custom,
        }
    end
    return report
end

local REASONS = {
    framework = 'import_usage', database_name = 'import_bad_db', database_missing = 'import_db_missing',
    running = 'import_running', error = 'import_failed',
}

RegisterCommand('mcimport', function(src, args)
    if src ~= 0 then return end   -- server console only
    local fw = args[1]
    local opts = {}
    local online = false
    for i = 2, #args do
        local a = tostring(args[i]):lower()
        if a == 'dry' or a == 'dryrun' or a == '--dry' or a == 'test' then opts.dry = true
        elseif a == 'online' then online = true
        elseif a:find('^from=') then opts.from = args[i]:sub(6)
        end
    end
    if not fw or not FRAMEWORKS[tostring(fw):lower()] then out(_L('import_usage')) return end
    if not opts.dry and not online and #GetPlayers() > 0 then out(_L('import_players_online', #GetPlayers())) return end
    CreateThread(function()
        local report, why = I.Run(fw, opts)
        if not report then out(_L(REASONS[why] or 'import_failed', tostring(opts.from))) end
    end)
end, true)

-- ---------------------------------------------------------------
-- after an import
-- ---------------------------------------------------------------

-- jobs imported characters hold that no job list knew: added again on every start
CreateThread(function()
    MULTI.Schema.Wait()
    local ok, rows = pcall(MySQL.query.await, 'SELECT name, grade, label FROM multicore_import_jobs')
    if not ok or type(rows) ~= 'table' then return end
    for _, r in ipairs(rows) do MULTI.Jobs.Ensure(r.name, tonumber(r.grade) or 0, (r.label ~= '' and r.label) or nil) end
    if #rows > 0 then out(_L('import_jobs_restored', #rows)) end
end)

-- VORP characters whose owner had no licence on record belong to the Steam id until that
-- player connects; then they are handed to the player's licence (the character list goes by licence)
local steamOwned = 0
function I.CountSteamOwners()
    local ok, n = pcall(MySQL.scalar.await, "SELECT COUNT(*) FROM players WHERE license LIKE 'steam:%'")
    steamOwned = ok and tonumber(n) or 0
end
CreateThread(function() MULTI.Schema.Wait() I.CountSteamOwners() end)

AddEventHandler('playerConnecting', function()
    if steamOwned <= 0 then return end
    local src = source
    local steam = GetPlayerIdentifierByType(src, 'steam')
    local license = GetPlayerIdentifierByType(src, 'license')
    if not steam or not license then return end
    local n = MySQL.update.await('UPDATE players SET license = ? WHERE license = ?', { license, steam }) or 0
    if n > 0 then
        MySQL.update.await('UPDATE playerskins SET license = ? WHERE license = ?', { license, steam })
        steamOwned = math.max(0, steamOwned - n)
        out(_L('import_steam_claimed', n, license:sub(1, 16) .. '...'))
    end
end)

if SELFTEST then
    exports('_TestImport', function(fw, opts) return I.Run(fw, opts) end)
    exports('_TestImportClaim', function(steam, license)
        local n = MySQL.update.await('UPDATE players SET license = ? WHERE license = ?', { license, steam }) or 0
        return n
    end)
end
