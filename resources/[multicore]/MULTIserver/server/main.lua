-- ============================================================
-- MULTIserver :: server helpers
-- Staff check, identifiers, notifications and the database table.
-- GPL v3, part of MULTIcore.
-- ============================================================

RSGCore = exports['rsg-core']:GetCoreObject()
MS = MS or {}
MS.testMode = GetConvar('multicore_selftest', 'false') == 'true'
MS.dbReady = false

local forcedAdmin = {}   -- test mode only: pretend players marked as staff

--- True when src counts as staff (Config.AdminAce / Config.AdminLevels). Console (0) is staff.
function MS.IsAdmin(src)
    src = tonumber(src)
    if src == 0 then return true end
    if not src then return false end
    if MS.testMode and forcedAdmin[src] ~= nil then return forcedAdmin[src] end
    for _, ace in ipairs(Config.AdminAce or {}) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    for _, level in ipairs(Config.AdminLevels or {}) do
        if RSGCore.Functions.HasPermission(src, level) then return true end
    end
    return false
end

function MS._ForceAdmin(src, on) forcedAdmin[tonumber(src)] = on end

--- Every identifier of a player, as { 'license:..', 'steam:..' }.
function MS.Identifiers(src)
    local out = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then out[#out + 1] = id end
    end
    return out
end

--- Answer to a command: notification for a player, console line for the console.
function MS.Reply(src, text, kind)
    if not src or src == 0 then
        print(('[MULTIserver] %s'):format(text))
        return
    end
    exports.MULTIcore:Notify(src, { text = text, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end

function MS.Debug(fmt, ...)
    if Config.Debug then print(('^5[MULTIserver]^7 ' .. fmt):format(...)) end
end

-- database: the whitelist table (also in sql/multiserver.sql)
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multiserver_whitelist` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(100) NOT NULL,
            `note` VARCHAR(150) DEFAULT NULL,
            `added_by` VARCHAR(100) DEFAULT NULL,
            `created` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    MS.dbReady = true
end)

exports('IsReady', function() return MS.dbReady end)
