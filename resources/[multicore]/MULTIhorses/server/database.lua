-- ============================================================
-- MULTIhorses :: database
-- Makes player_horses on start when it is missing, adds the columns an
-- older table lacks (servers that ran the earlier MULTIhorses or an older
-- stable script), and carries horses of the earlier MULTIhorses over once.
-- sql/multihorses.sql holds the same table for those who import by hand.
-- ============================================================

DB = { ready = false }

-- a horse is grown up after this many seconds (Config.Growth); rows that other
-- scripts insert without an age start grown up, never as foals
local ADULT_SECONDS = math.max(7 * 24 * 60 * 60, ((Config.Growth and Config.Growth.growthMinutesToAdult) or 720) * 60)

local CREATE = [[
CREATE TABLE IF NOT EXISTS `player_horses` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `stable` VARCHAR(50) NOT NULL DEFAULT 'valentine',
  `citizenid` VARCHAR(50) NOT NULL,
  `horseid` VARCHAR(6) NOT NULL,
  `name` VARCHAR(50) NOT NULL,
  `horse` VARCHAR(100) NOT NULL,
  `gender` VARCHAR(10) NOT NULL DEFAULT 'male',
  `active` TINYINT(1) NOT NULL DEFAULT 0,
  `born` INT(11) NOT NULL DEFAULT 0,
  `components` LONGTEXT DEFAULT NULL,
  `coat` LONGTEXT DEFAULT NULL,
  `horsexp` INT(11) NOT NULL DEFAULT 0,
  `dirt` INT(11) NOT NULL DEFAULT 0,
  `age_seconds` INT(11) NOT NULL DEFAULT 604800,
  `pregnant_until` INT(11) DEFAULT NULL,
  `last_bred` INT(11) DEFAULT NULL,
  `stored_weapon` VARCHAR(100) DEFAULT NULL,
  `stored_weapon_name` VARCHAR(100) DEFAULT NULL,
  `stored_weapon_data` LONGTEXT DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`),
  KEY `idx_horseid` (`horseid`),
  KEY `idx_active` (`citizenid`, `active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

-- every column MULTIhorses uses, in table order (name, definition)
local COLUMNS = {
    { 'stable',             "VARCHAR(50) NOT NULL DEFAULT 'valentine'" },
    { 'gender',             "VARCHAR(10) NOT NULL DEFAULT 'male'" },
    { 'active',             'TINYINT(1) NOT NULL DEFAULT 0' },
    { 'born',               'INT(11) NOT NULL DEFAULT 0' },
    { 'components',         'LONGTEXT DEFAULT NULL' },
    { 'coat',               'LONGTEXT DEFAULT NULL' },
    { 'horsexp',            'INT(11) NOT NULL DEFAULT 0' },
    { 'dirt',               'INT(11) NOT NULL DEFAULT 0' },
    { 'age_seconds',        'INT(11) NOT NULL DEFAULT 604800' },
    { 'pregnant_until',     'INT(11) DEFAULT NULL' },
    { 'last_bred',          'INT(11) DEFAULT NULL' },
    { 'stored_weapon',      'VARCHAR(100) DEFAULT NULL' },
    { 'stored_weapon_name', 'VARCHAR(100) DEFAULT NULL' },
    { 'stored_weapon_data', 'LONGTEXT DEFAULT NULL' },
}

local function tableExists(name)
    local n = MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })
    return (tonumber(n) or 0) > 0
end

local function existingColumns()
    local have = {}
    for _, r in ipairs(MySQL.query.await("SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_horses'") or {}) do
        have[r.c] = true
    end
    return have
end

--- Earlier MULTIhorses kept saddle and blanket (as shop item hashes) in multihorses_state.tack.
--- Here they become customization components; every carried-over horse also gets saddlebags,
--- because every horse had them before.
local function componentIndex(comps, category, hash)
    hash = tonumber(hash)
    if not hash or type(comps[category]) ~= 'table' then return nil end
    for _, item in ipairs(comps[category]) do
        if tonumber(item.hash) == hash or tonumber(item.hash_dec_signed) == hash then return item.hashid end
    end
end

local function migrateEarlierMULTIhorses()
    if GetResourceKvpInt('multihorses_migrated_v2') == 1 then return end
    if not tableExists('multihorses_state') then
        SetResourceKvpInt('multihorses_migrated_v2', 1)
        return
    end

    print('[MULTIhorses] carrying over horses of the earlier MULTIhorses ...')

    -- grown up: the earlier version had no foals
    MySQL.update.await('UPDATE player_horses SET age_seconds = ? WHERE age_seconds < ? AND pregnant_until IS NULL AND last_bred IS NULL', { ADULT_SECONDS, ADULT_SECONDS })

    -- saddle and blanket -> components, plus saddlebags
    local comps = lib.load('shared.horse_comp') or {}
    local rows = MySQL.query.await([[SELECT h.id, h.components, s.tack FROM player_horses h
        LEFT JOIN multihorses_state s ON s.horseid = h.horseid
        WHERE h.components IS NULL OR h.components = '' OR h.components = '[]' OR h.components = '{}']]) or {}
    local moved = 0
    for _, r in ipairs(rows) do
        local tack = {}
        if type(r.tack) == 'string' and r.tack ~= '' then
            local ok, t = pcall(json.decode, r.tack)
            if ok and type(t) == 'table' then tack = t end
        end
        local c = { Saddlebags = 1 }
        c.Saddles = componentIndex(comps, 'Saddles', tack.saddle)
        c.Blankets = componentIndex(comps, 'Blankets', tack.blanket)
        MySQL.update.await('UPDATE player_horses SET components = ? WHERE id = ?', { json.encode(c), r.id })
        moved = moved + 1
    end

    SetResourceKvpInt('multihorses_migrated_v2', 1)
    print(('[MULTIhorses] %d horses carried over (multihorses_state is kept, it is no longer used)'):format(moved))
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end

    MySQL.query.await(CREATE)

    local have = existingColumns()
    for _, col in ipairs(COLUMNS) do
        if not have[col[1]] then
            -- information_schema decides, so this works on MariaDB and MySQL alike
            MySQL.query.await(('ALTER TABLE `player_horses` ADD COLUMN `%s` %s'):format(col[1], col[2]))
            print(('[MULTIhorses] added missing column player_horses.%s'):format(col[1]))
        end
    end

    -- rows other scripts insert (starter horses ...) start grown up
    MySQL.query.await(('ALTER TABLE `player_horses` ALTER COLUMN `age_seconds` SET DEFAULT %d'):format(ADULT_SECONDS))

    local ok, err = pcall(migrateEarlierMULTIhorses)
    if not ok then print('^1[MULTIhorses] carrying over the earlier horses failed: ' .. tostring(err) .. '^7') end

    DB.ready = true
    TriggerEvent('MULTIhorses:ready')
end)
