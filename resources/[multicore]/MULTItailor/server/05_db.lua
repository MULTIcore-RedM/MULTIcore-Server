--[[
    Database (oxmysql). Every table is created with CREATE TABLE IF NOT EXISTS at start
    (sql/install.sql holds the same statements for a manual install).

      multitailor_patterns                  the pattern book of every tailor shop
      multitailor_till / multitailor_till_log   shop till + its book
      multitailor_shelf                     counter shelf lines
      multitailor_orders                    customers' written orders
      multitailor_stores                    clothes stores moved / added / hidden in game (/tailorstores)
      multitailor_meta                      one-off flags (first-load clothing import per character)

    No parameter array ever holds a nil: optional values are written as a literal NULL in the SQL.

    TDB.ready()                 block until the tables exist
    TDB.meta(key) / TDB.setMeta(key, value)
    TDB.till.balance(bid) / credit(bid, amount, type, by, note) / debit(...) -> ok / history(bid, n)
]]
TDB = TDB or {}
TDB.till = {}

local P = Config.Designer.patternsTable or 'multitailor_patterns'
TDB.patterns = P

local ready = false
local readyP = promise.new()

function TDB.ready()
    if ready then return true end
    Citizen.Await(readyP)
    return true
end

local SCHEMA = {
    ([[CREATE TABLE IF NOT EXISTS `%s` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `business_id` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `sex` VARCHAR(8) NOT NULL,
        `pieces` LONGTEXT NOT NULL,
        `created_by` VARCHAR(128) NULL,
        `created_cid` VARCHAR(64) NULL,
        `created_at` BIGINT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_business` (`business_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(P),
    [[CREATE TABLE IF NOT EXISTS `multitailor_meta` (
        `k` VARCHAR(64) NOT NULL,
        `v` TEXT NULL,
        PRIMARY KEY (`k`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multitailor_till` (
        `business_id` VARCHAR(64) NOT NULL,
        `balance` DECIMAL(12,2) NOT NULL DEFAULT 0,
        `updated_at` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`business_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multitailor_till_log` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `business_id` VARCHAR(64) NOT NULL,
        `type` VARCHAR(24) NOT NULL,
        `amount` DECIMAL(12,2) NOT NULL DEFAULT 0,
        `by_name` VARCHAR(128) NULL,
        `note` VARCHAR(160) NULL,
        `created_at` BIGINT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_business` (`business_id`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multitailor_shelf` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `business_id` VARCHAR(64) NOT NULL,
        `item` VARCHAR(64) NOT NULL,
        `label` VARCHAR(80) NULL,
        `metadata` LONGTEXT NULL,
        `qty` INT NOT NULL DEFAULT 0,
        `price` DECIMAL(10,2) NOT NULL DEFAULT 0,
        `stocked_by` VARCHAR(128) NULL,
        `updated_at` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_business` (`business_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multitailor_orders` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `business_id` VARCHAR(64) NOT NULL,
        `customer_name` VARCHAR(128) NOT NULL,
        `customer_cid` VARCHAR(64) NOT NULL,
        `sex` VARCHAR(8) NOT NULL,
        `request` TEXT NOT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'open',
        `handled_by` VARCHAR(128) NULL,
        `created_at` BIGINT NOT NULL,
        `updated_at` BIGINT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_business` (`business_id`, `status`),
        KEY `idx_customer` (`customer_cid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `multitailor_stores` (
        `id` VARCHAR(48) NOT NULL,
        `data` LONGTEXT NOT NULL,
        `updated_by` VARCHAR(128) NULL,
        `updated_at` BIGINT NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function TDB.meta(key)
    local v = MySQL.scalar.await('SELECT v FROM `multitailor_meta` WHERE k = ?', { key })
    return v
end

function TDB.setMeta(key, value)
    MySQL.insert.await('INSERT INTO `multitailor_meta` (k, v) VALUES (?, ?) ON DUPLICATE KEY UPDATE v = VALUES(v)',
        { key, tostring(value) })
end


-- ---------------------------------------------------------------- till
function TDB.till.balance(bid)
    local v = MySQL.scalar.await('SELECT balance FROM `multitailor_till` WHERE business_id = ?', { bid })
    return TU.money(v) or 0
end

local function logTx(bid, kind, amount, by, note)
    if note then
        MySQL.insert('INSERT INTO `multitailor_till_log` (business_id, type, amount, by_name, note, created_at) VALUES (?, ?, ?, ?, ?, ?)',
            { bid, kind, amount, tostring(by or 'System'), tostring(note):sub(1, 160), os.time() })
    else
        MySQL.insert('INSERT INTO `multitailor_till_log` (business_id, type, amount, by_name, note, created_at) VALUES (?, ?, ?, ?, NULL, ?)',
            { bid, kind, amount, tostring(by or 'System'), os.time() })
    end
end

function TDB.till.credit(bid, amount, kind, by, note)
    amount = TU.money(amount)
    if not bid or not amount or amount <= 0 then return false end -- nan guard
    MySQL.insert.await('INSERT INTO `multitailor_till` (business_id, balance, updated_at) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE balance = balance + VALUES(balance), updated_at = VALUES(updated_at)',
        { bid, amount, os.time() })
    logTx(bid, kind or 'credit', amount, by, note)
    return true
end

function TDB.till.debit(bid, amount, kind, by, note)
    amount = TU.money(amount)
    if not bid or not amount or amount <= 0 then return false end -- nan guard
    local changed = MySQL.update.await('UPDATE `multitailor_till` SET balance = balance - ?, updated_at = ? WHERE business_id = ? AND balance >= ?',
        { amount, os.time(), bid, amount })
    if (tonumber(changed) or 0) < 1 then return false end
    logTx(bid, kind or 'debit', -amount, by, note)
    return true
end

function TDB.till.history(bid, n)
    local rows = MySQL.query.await('SELECT type, amount, by_name, note, created_at FROM `multitailor_till_log` WHERE business_id = ? ORDER BY id DESC LIMIT ?',
        { bid, TU.int(n, 1, 200) or 25 }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { type = r.type, amount = TU.money(r.amount) or 0, by = r.by_name, note = r.note, at = tonumber(r.created_at) or 0 }
    end
    return out
end

CreateThread(function()
    local ok, err = pcall(function()
        for _, sql in ipairs(SCHEMA) do MySQL.query.await(sql) end
    end)
    if not ok then
        print(('^1[MULTItailor] database setup failed: %s^0'):format(tostring(err)))
    end
    ready = true
    readyP:resolve(true)
    -- prune old finished orders
    local days = TU.int(Config.Orders.keepDays, 1, 3650) or 21
    pcall(function()
        MySQL.update.await("DELETE FROM `multitailor_orders` WHERE status IN ('done','declined','cancelled') AND updated_at < ?",
            { os.time() - days * 86400 })
    end)
end)
