-- ============================================================
-- MULTIinventory :: server/core/db.lua
--
-- Schema auto-migration on start (sql/install.sql, idempotent, versioned in
-- multiinv_schema) + thin oxmysql wrappers. Never touches vorp tables
-- except read-only selects (items, item_group, item_rarity, characters.slots).
--
--   InvDB.ready() -> boolean         InvDB.awaitReady()
--   InvDB.query(sql, params) -> rows (never throws; {} on error)
--   InvDB.scalar(sql, params)        InvDB.update(sql, params) -> affected|nil
--   InvDB.transaction(list) -> bool  list = { { query = sql, values = {...} }, ... }
--   InvDB.splitStatements(text) -> { sql, ... }
--   InvDB.SCHEMA_VERSION
-- ============================================================

InvDB = InvDB or {}
InvDB.SCHEMA_VERSION = 2

local RES = GetCurrentResourceName()
local isReady = false
local readyWaiters = {}

local function log(fmt, ...)
    print(('[%s] ' .. fmt):format(RES, ...))
end

function InvDB.query(sql, params)
    local ok, res = pcall(MySQL.query.await, sql, params or {})
    if not ok then log('^1SQL error: %s^7 (%s)', tostring(res), sql:sub(1, 120)) return {} end
    return res or {}
end

function InvDB.scalar(sql, params)
    local ok, res = pcall(MySQL.scalar.await, sql, params or {})
    if not ok then log('^1SQL error: %s^7 (%s)', tostring(res), sql:sub(1, 120)) return nil end
    return res
end

function InvDB.update(sql, params)
    local ok, res = pcall(MySQL.update.await, sql, params or {})
    if not ok then log('^1SQL error: %s^7 (%s)', tostring(res), sql:sub(1, 120)) return nil end
    return res
end

function InvDB.transaction(list)
    if #list == 0 then return true end
    local ok, res = pcall(MySQL.transaction.await, list)
    if not ok then log('^1SQL transaction error: %s^7', tostring(res)) return false end
    return res and true or false
end

---Placeholder group for one row without nil holes in the parameter list
---(nil values become a literal NULL - oxmysql parameter arrays must not contain holes).
---InvDB.bind({ a, nil, c }, 3, params) -> '(?,NULL,?)', params gets a and c appended.
function InvDB.bind(row, ncols, params)
    local ph = {}
    for i = 1, ncols do
        local v = row[i]
        if v == nil then
            ph[i] = 'NULL'
        else
            ph[i] = '?'
            params[#params + 1] = v
        end
    end
    return '(' .. table.concat(ph, ',') .. ')'
end

---Split install.sql into statements (comment lines dropped, ';' at end of line ends a statement).
function InvDB.splitStatements(text)
    local out, buf = {}, {}
    for line in (text .. '\n'):gmatch('([^\n]*)\n') do
        line = line:gsub('\r$', '')
        if not line:match('^%s*%-%-') and line:match('%S') then
            buf[#buf + 1] = line
            if line:match(';%s*$') then
                out[#out + 1] = table.concat(buf, '\n'):gsub(';%s*$', '')
                buf = {}
            end
        end
    end
    if #buf > 0 then out[#out + 1] = table.concat(buf, '\n') end
    return out
end

local function columnExists(tbl, col)
    local n = InvDB.scalar('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { tbl, col })
    return (tonumber(n) or 0) > 0
end

local function indexExists(tbl, idx)
    local n = InvDB.scalar('SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?', { tbl, idx })
    return (tonumber(n) or 0) > 0
end

-- Columns / indexes added after the version 1 draft (tables created by the
-- draft get them via ALTER; fresh installs already have them).
local UPGRADES = {
    columns = {
        { 'multiinv_hotbar', 'item',          '`item` VARCHAR(50) NULL' },
        { 'multiinv_drops',  'owner_charid',  '`owner_charid` INT NULL' },
        { 'multiinv_drops',  'created_at',    '`created_at` BIGINT NOT NULL DEFAULT 0' },
        { 'multiinv_log',    'actor',         '`actor` VARCHAR(64) NULL' },
        { 'multiinv_log',    'target_charid', '`target_charid` INT NULL' },
    },
    indexes = {
        { 'multiinv_stacks', 'idx_name',    'ADD KEY `idx_name` (`item`)' },
        { 'multiinv_drops',  'idx_expires', 'ADD KEY `idx_expires` (`expires_at`)' },
        { 'multiinv_log',    'idx_target',  'ADD KEY `idx_target` (`target_charid`)' },
        { 'multiinv_log',    'idx_action',  'ADD KEY `idx_action` (`action`)' },
    },
}

local function waitForMysql()
    local deadline = GetGameTimer() + 30000
    while GetResourceState('oxmysql') ~= 'started' and GetGameTimer() < deadline do Wait(100) end
    while GetGameTimer() < deadline do
        local ok = pcall(MySQL.query.await, 'SELECT 1')
        if ok then return true end
        Wait(250)
    end
    log('^1oxmysql did not become ready in time^7')
    return false
end

function InvDB.migrate()
    local sql = LoadResourceFile(RES, 'sql/install.sql')
    if not sql or sql == '' then
        log('^1sql/install.sql missing - schema not applied^7')
        return false
    end
    local failed = 0
    for _, stmt in ipairs(InvDB.splitStatements(sql)) do
        local ok, err = pcall(MySQL.query.await, stmt)
        if not ok then failed = failed + 1; log('^1schema: %s^7', tostring(err)) end
    end
    for _, c in ipairs(UPGRADES.columns) do
        if not columnExists(c[1], c[2]) then
            InvDB.query(('ALTER TABLE `%s` ADD COLUMN %s'):format(c[1], c[3]))
            log('added column %s.%s', c[1], c[2])
        end
    end
    for _, i in ipairs(UPGRADES.indexes) do
        if not indexExists(i[1], i[2]) then
            InvDB.query(('ALTER TABLE `%s` %s'):format(i[1], i[3]))
            log('added index %s.%s', i[1], i[2])
        end
    end
    local v = tonumber(InvDB.scalar('SELECT MAX(`version`) FROM `multiinv_schema`')) or 0
    if v < InvDB.SCHEMA_VERSION then
        log('^1schema version %d < %d after migration^7', v, InvDB.SCHEMA_VERSION)
        return false
    end
    return failed == 0
end

function InvDB.ready() return isReady end

function InvDB.awaitReady()
    if isReady then return true end
    local p = promise.new()
    readyWaiters[#readyWaiters + 1] = p
    Citizen.Await(p)
    return isReady
end

function InvDB.setReady()
    isReady = true
    for _, p in ipairs(readyWaiters) do p:resolve(true) end
    readyWaiters = {}
end

-- Boot is driven by server/core/boot.lua (needs every module loaded first).
function InvDB.boot()
    if not waitForMysql() then return false end
    local ok = InvDB.migrate()
    log(ok and 'schema v%d ready' or '^3schema v%d applied with warnings^7', InvDB.SCHEMA_VERSION)
    return true
end
