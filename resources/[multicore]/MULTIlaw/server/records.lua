-- ============================================================
-- MULTIlaw :: criminal records
-- One line per arrest, fine, bounty, confiscation and early release,
-- per character. Read by law on duty at an office (NUI list).
-- Not an MDT: no reports, charges or warrants.
-- ============================================================

local getP, fail, okRes = Law.getP, Law.fail, Law.okRes

Law.RecordKinds = { arrest = true, fine = true, bounty = true, bounty_claimed = true, confiscate = true, release = true, note = true }

--- adds one line. data = { detail, amount, minutes, officer }
function Law.AddRecord(cid, name, kind, data)
    if type(cid) ~= 'string' or not Law.RecordKinds[kind] then return false end
    data = data or {}
    MySQL.insert.await([[INSERT INTO `multilaw_records` (`citizenid`, `name`, `kind`, `detail`, `amount`, `minutes`, `officer`, `created_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)]], { cid, Law.text(name or '', 100), kind, Law.text(data.detail or '', 200),
        data.amount and Law.money(data.amount) or nil, data.minutes and Law.int(data.minutes) or nil, data.officer and Law.text(data.officer, 100) or nil, os.time() })
    return true
end

--- every line on one character, newest first
function Law.GetRecord(cid)
    local out = {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `multilaw_records` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?', { cid, Config.Records.MaxEntries }) or {}) do
        out[#out + 1] = { id = tonumber(r.id), kind = r.kind, detail = r.detail, amount = tonumber(r.amount), minutes = tonumber(r.minutes),
            officer = r.officer, at = tonumber(r.created_at) or 0 }
    end
    return out
end

--- people with a record whose name (or citizenid) matches; empty query = most recent
function Law.SearchRecords(query)
    query = Law.text(query or '', 50)
    local sql = [[SELECT `citizenid`, MAX(`name`) AS `name`, COUNT(*) AS `entries`, SUM(`kind` = 'arrest') AS `arrests`,
        SUM(`kind` = 'fine') AS `fines`, COALESCE(SUM(`minutes`), 0) AS `minutes`, MAX(`created_at`) AS `last`
        FROM `multilaw_records` %s GROUP BY `citizenid` ORDER BY `last` DESC LIMIT ?]]
    local rows
    if query == '' then
        rows = MySQL.query.await(sql:format(''), { Config.Records.SearchLimit })
    else
        local like = '%' .. query:gsub('[%%_\\]', '\\%0') .. '%'
        rows = MySQL.query.await(sql:format('WHERE `name` LIKE ? OR `citizenid` = ?'), { like, query, Config.Records.SearchLimit })
    end
    local out = {}
    for _, r in ipairs(rows or {}) do
        out[#out + 1] = { cid = r.citizenid, name = r.name, entries = tonumber(r.entries) or 0, arrests = tonumber(r.arrests) or 0,
            fines = tonumber(r.fines) or 0, minutes = tonumber(r.minutes) or 0, last = tonumber(r.last) or 0 }
    end
    return out
end

--- a person's page: record lines, unpaid fines, open bounties, current sentence
function Law.RecordPage(cid)
    local fines = Law.GetFines(cid, true)
    local owed = 0
    for _, f in ipairs(fines) do owed = owed + f.amount end
    local bounties = {}
    for _, b in ipairs(Law.GetBounties()) do if b.cid == cid then bounties[#bounties + 1] = b end end
    local name
    local rows = Law.GetRecord(cid)
    local nameRow = MySQL.single.await('SELECT `name` FROM `multilaw_records` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT 1', { cid })
    name = nameRow and nameRow.name or cid
    return { cid = cid, name = name, entries = rows, unpaid = #fines, owed = owed, bounties = bounties,
        jailed = Law.IsJailed(cid), jailLeft = Law.JailLeft(cid) }
end

---------------------------------
-- NUI: records page (law on duty at an office)
---------------------------------
local function mayRead(src)
    local P = getP(src)
    local ok, err = Law.Can(P, 'records')
    if not ok then return false, err end
    if not Config.Records.Anywhere and not Law.OfficeAt(src, P) then return false, 'not_at_office' end
    return true
end

lib.callback.register('MULTIlaw:records:search', function(src, query)
    if not Law.rateOk(src) then return fail('busy') end
    local ok, err = mayRead(src)
    if not ok then return fail(err) end
    local res = okRes()
    res.list = Law.SearchRecords(query)
    return res
end)

lib.callback.register('MULTIlaw:records:get', function(src, cid)
    if not Law.rateOk(src) then return fail('busy') end
    local ok, err = mayRead(src)
    if not ok then return fail(err) end
    if type(cid) ~= 'string' or #cid > 50 then return fail('failed') end
    local res = okRes()
    res.page = Law.RecordPage(cid)
    return res
end)
