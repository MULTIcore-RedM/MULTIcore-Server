-- ============================================================
-- MULTIcoroner :: server
-- Inquest reports: filing, the ledger, printed copies (item) and deleting.
-- Based on phils-coroner by Phil. Part of MULTIcore (GPL v3).
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local TableName = Config.DatabaseTable or 'multicoroner_reports'
local TableRef = '`' .. TableName .. '`'

-- ------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------
local function Clean(value, maxLength)
    local text = tostring(value or ''):gsub('%c', ' ')
    return text:sub(1, maxLength or 200)
end

local function Debug(message)
    if Config.Debug then print('[MULTIcoroner] ' .. message) end
end

local function IsAdmin(src)
    return IsPlayerAceAllowed(src, Config.AdminAce or 'multicoroner.admin')
        or IsPlayerAceAllowed(src, 'admin')
end

local function CanUse(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    if IsAdmin(src) then return true end

    local job = Player.PlayerData and Player.PlayerData.job or {}
    local allowed = (Config.Jobs or {})[job.name] or (job.type and (Config.JobTypes or {})[job.type])
    if not allowed then return false end
    if Config.RequireOnDuty and not job.onduty then return false end
    return true
end

local function Notify(src, kind, label, message)
    TriggerClientEvent('MULTIcoroner:client:toast', src, kind, label, message)
end

local function IsValidManner(manner)
    for _, allowed in ipairs(Config.Manners or {}) do
        if allowed == manner then return true end
    end
    return false
end

local function CharName(Player, src)
    local c = Player and Player.PlayerData and Player.PlayerData.charinfo or {}
    local name = (tostring(c.firstname or '') .. ' ' .. tostring(c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = GetPlayerName(src) or '' end
    return name
end

-- ------------------------------------------------------------
-- the dead player's character name, so the coroner need not type it
-- ------------------------------------------------------------
lib.callback.register('MULTIcoroner:server:charName', function(src, targetServerId)
    if not CanUse(src) then return nil end
    targetServerId = tonumber(targetServerId)
    if not targetServerId or targetServerId <= 0 then return nil end
    local target = RSGCore.Functions.GetPlayer(targetServerId)
    if not target then return nil end
    local name = CharName(target, targetServerId)
    return name ~= '' and name or nil
end)

-- ------------------------------------------------------------
-- database
-- ------------------------------------------------------------
local function CreateTable()
    MySQL.update.await(([[
        CREATE TABLE IF NOT EXISTS %s (
            `id` int unsigned NOT NULL AUTO_INCREMENT,
            `report_id` varchar(32) NOT NULL,
            `created_at` datetime NOT NULL,
            `subject_type` varchar(20) NOT NULL DEFAULT 'NPC',
            `subject_id` int unsigned NOT NULL DEFAULT 0,
            `subject_name` varchar(80) NOT NULL DEFAULT '',
            `location` varchar(120) NOT NULL DEFAULT '',
            `identified_name` varchar(80) NOT NULL DEFAULT '',
            `cause` varchar(120) NOT NULL,
            `manner` varchar(40) NOT NULL DEFAULT 'UNDETERMINED',
            `notes` text,
            `conclusion` varchar(120) NOT NULL,
            `coroner` varchar(80) NOT NULL DEFAULT '',
            PRIMARY KEY (`id`),
            UNIQUE KEY `multicoroner_report_id_unique` (`report_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]):format(TableRef))
end

local function InsertReport(report)
    local tmpId = 'TMP-' .. os.time() .. '-' .. math.random(100000, 999999)
    local insertId = MySQL.insert.await(([[
        INSERT INTO %s
            (`report_id`, `created_at`, `subject_type`, `subject_id`, `subject_name`,
             `location`, `identified_name`, `cause`, `manner`, `notes`, `conclusion`, `coroner`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]):format(TableRef), {
        tmpId,
        os.date('%Y-%m-%d %H:%M:%S'),
        Clean(report.subjectType, 20),
        tonumber(report.subjectId) or 0,
        Clean(report.subjectName, 80),
        Clean(report.location, 120),
        Clean(report.subjectNameForm, 80),
        Clean(report.cause, 120),
        Clean(report.manner, 40),
        Clean(report.notes, 500),
        Clean(report.conclusion, 120),
        Clean(report.coroner, 80),
    })
    if not insertId then return nil end

    local reportId = ('INQ-%s-%06d'):format(os.date('%y%m%d'), tonumber(insertId) or 0)
    MySQL.update.await(('UPDATE %s SET `report_id` = ? WHERE `id` = ?'):format(TableRef), { reportId, insertId })
    return reportId
end

local function TrimReports()
    local maxReports = tonumber(Config.MaxReports) or 100
    if maxReports <= 0 then return end
    local rows = MySQL.query.await(('SELECT `id` FROM %s ORDER BY `id` DESC LIMIT ?, 1'):format(TableRef), { maxReports })
    if rows and rows[1] then
        MySQL.update.await(('DELETE FROM %s WHERE `id` <= ?'):format(TableRef), { rows[1].id })
    end
end

local function RowToReport(row)
    if not row then return nil end
    return {
        id = row.report_id,
        time = tostring(row.created_at or ''):sub(1, 16),
        subjectType = row.subject_type,
        subjectId = row.subject_id,
        subjectName = row.subject_name,
        location = row.location,
        subjectNameForm = row.identified_name,
        cause = row.cause,
        manner = row.manner,
        notes = row.notes,
        conclusion = row.conclusion,
        coroner = row.coroner,
    }
end

local function FetchReports()
    local rows = MySQL.query.await(('SELECT * FROM %s ORDER BY `id` ASC'):format(TableRef))
    local reports = {}
    for _, row in ipairs(rows or {}) do reports[#reports + 1] = RowToReport(row) end
    return reports
end

local function FetchReportById(reportId)
    if type(reportId) ~= 'string' or reportId == '' then return nil end
    local rows = MySQL.query.await(('SELECT * FROM %s WHERE `report_id` = ? LIMIT 1'):format(TableRef), { Clean(reportId, 32) })
    return rows and rows[1] and RowToReport(rows[1]) or nil
end

local function GiveReportItem(src, reportId)
    local itemName = Config.ReportItem or 'coroner_report'
    local itemData = RSGCore.Shared.Items and RSGCore.Shared.Items[itemName]
    if not itemData then
        print(('[MULTIcoroner] the report item "%s" is missing from MULTIcore shared/items.lua'):format(itemName))
        return false
    end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    if not Player.Functions.AddItem(itemName, 1, false, { reportId = Clean(reportId, 32) }) then return false end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemData, 'add', 1)
    Debug(('gave report item src=%d report=%s'):format(src, tostring(reportId)))
    return true
end

MySQL.ready(function()
    CreateThread(function()
        local ok, err = pcall(CreateTable)
        if not ok then
            print(('[MULTIcoroner] could not create the table: %s'):format(tostring(err)))
            return
        end
        Debug(('SQL ready, table %s'):format(TableName))
        TrimReports()
    end)
end)

-- ------------------------------------------------------------
-- access (the client asks so it knows whether to offer the option)
-- ------------------------------------------------------------
RegisterNetEvent('MULTIcoroner:server:checkAccess', function()
    local src = source
    local allowed = CanUse(src)
    Debug(('access src=%d allowed=%s'):format(src, tostring(allowed)))
    TriggerClientEvent('MULTIcoroner:client:access', src, allowed)
end)

-- ------------------------------------------------------------
-- file an inquest report
-- ------------------------------------------------------------
RegisterNetEvent('MULTIcoroner:server:fileReport', function(caseData, form)
    local src = source
    if not CanUse(src) then
        return Notify(src, 'error', _L('t_denied'), _L('m_no_file'))
    end
    if type(caseData) ~= 'table' or type(form) ~= 'table' then
        return Notify(src, 'error', _L('t_failed'), _L('m_incomplete'))
    end

    local cause = Clean(form.cause, 120)
    local conclusion = Clean(form.conclusion, 120)
    if cause:match('^%s*$') or conclusion:match('^%s*$') then
        return Notify(src, 'error', _L('t_failed'), _L('m_need_cause'))
    end

    local manner = Clean(form.manner, 40)
    if not IsValidManner(manner) then manner = 'UNDETERMINED' end

    local subjectType = caseData.type == 'PLAYER' and 'PLAYER' or (caseData.type == 'ANIMAL' and 'ANIMAL' or 'NPC')

    local ok, reportId = pcall(InsertReport, {
        subjectType = subjectType,
        subjectId = tonumber(caseData.id) or 0,
        subjectName = Clean(caseData.name, 80),
        location = Clean(caseData.location, 120),
        subjectNameForm = Clean(form.subjectName, 80),
        cause = cause,
        manner = manner,
        notes = Clean(form.notes, 500),
        conclusion = conclusion,
        coroner = CharName(RSGCore.Functions.GetPlayer(src), src),
    })
    if not ok or not reportId then
        print(('[MULTIcoroner] could not file a report: %s'):format(tostring(reportId)))
        return Notify(src, 'error', _L('t_failed'), _L('m_not_saved'))
    end

    if Config.GiveReportItemOnFile then GiveReportItem(src, reportId) end
    TrimReports()
    Debug(('report filed src=%d id=%s type=%s'):format(src, reportId, subjectType))
    Notify(src, 'success', _L('t_filed'), _L('m_filed', reportId))
end)

-- ------------------------------------------------------------
-- the ledger
-- ------------------------------------------------------------
local function OpenReports(src)
    if not CanUse(src) then
        return Notify(src, 'error', _L('t_denied'), _L('m_no_view'))
    end
    local ok, reports = pcall(FetchReports)
    if not ok then
        print(('[MULTIcoroner] could not load reports: %s'):format(tostring(reports)))
        return Notify(src, 'error', _L('t_error'), _L('m_ledger_failed'))
    end
    TriggerClientEvent('MULTIcoroner:client:openReports', src, reports)
end

RegisterNetEvent('MULTIcoroner:server:getReports', function() OpenReports(source) end)

RegisterCommand(Config.ReportsCommand or 'inquests', function(src)
    if src == 0 then return print('[MULTIcoroner] the ledger can only be opened in game') end
    OpenReports(src)
end, false)

-- ------------------------------------------------------------
-- the report item: anyone holding a copy can read it
-- ------------------------------------------------------------
RSGCore.Functions.CreateUseableItem(Config.ReportItem or 'coroner_report', function(src, item)
    local info = item and (item.info or item.metadata) or {}
    local report = FetchReportById(info.reportId)
    if not report then
        return Notify(src, 'error', _L('t_unreadable'), _L('m_gone'))
    end
    TriggerClientEvent('MULTIcoroner:client:openReportDetail', src, report, CanUse(src))
end)

RegisterNetEvent('MULTIcoroner:server:printReport', function(reportId)
    local src = source
    if not CanUse(src) then
        return Notify(src, 'error', _L('t_denied'), _L('m_no_print'))
    end
    local report = FetchReportById(reportId)
    if not report then
        return Notify(src, 'error', _L('t_failed'), _L('m_not_found'))
    end
    if GiveReportItem(src, report.id) then
        Notify(src, 'success', _L('t_printed'), _L('m_printed', report.id))
    else
        Notify(src, 'error', _L('t_failed'), _L('m_cant_carry'))
    end
end)

RegisterNetEvent('MULTIcoroner:server:deleteReport', function(reportId)
    local src = source
    if not CanUse(src) then
        return Notify(src, 'error', _L('t_denied'), _L('m_no_delete'))
    end
    local report = FetchReportById(reportId)
    if not report then
        return Notify(src, 'error', _L('t_failed'), _L('m_not_found'))
    end
    local ok, affected = pcall(function()
        return MySQL.update.await(('DELETE FROM %s WHERE `report_id` = ?'):format(TableRef), { report.id })
    end)
    if not ok or not affected or affected < 1 then
        return Notify(src, 'error', _L('t_failed'), _L('m_not_deleted'))
    end
    Debug(('report deleted src=%d id=%s'):format(src, report.id))
    Notify(src, 'success', _L('t_deleted'), _L('m_deleted', report.id))
end)

-- ------------------------------------------------------------
-- /coronerdebug (admins): a short summary in the server console
-- ------------------------------------------------------------
RegisterCommand('coronerdebug', function(src)
    if src == 0 then return print('[MULTIcoroner] /coronerdebug must be run in game') end
    if not IsAdmin(src) then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    local job = Player and Player.PlayerData and Player.PlayerData.job or {}
    local ok, count = pcall(function() return MySQL.scalar.await(('SELECT COUNT(*) FROM %s'):format(TableRef)) end)
    print(('[MULTIcoroner] /coronerdebug src=%d job=%s type=%s onduty=%s allowed=%s table=%s rows=%s'):format(
        src, tostring(job.name), tostring(job.type), tostring(job.onduty), tostring(CanUse(src)), TableName, tostring(ok and count or 'error')))
    TriggerClientEvent('MULTIcoroner:client:debugDump', src)
end, false)
