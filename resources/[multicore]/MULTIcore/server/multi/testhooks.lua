-- ============================================================
-- MULTIcore :: test hooks
-- Only active when the server sets  setr multicore_selftest true
-- (never on a live server). They let a test resource log a pretend
-- player in and out, so both faces can be checked without a game client.
-- ============================================================

if GetConvar('multicore_selftest', 'false') ~= 'true' then return end

print('^3[MULTIcore] self-test hooks are ON (multicore_selftest) - never use this on a live server^7')

exports('IsReady', function() return MULTI.Schema.ready end)

--- Logs pretend player `src` in. With a citizenid it loads that saved character,
--- otherwise it makes a new one from `data`.
exports('_TestLogin', function(src, citizenid, data, license)
    MULTI.Schema.Wait()
    -- the last 8 characters plus a hash of the whole licence: tests that start in the same
    -- second (same time stamp at the end of their licences) still get their own accounts
    local identifier = ('steam:test%s%08x'):format(tostring(license):sub(-8), joaat(tostring(license)) & 0xFFFFFFFF)
    MySQL.insert.await('INSERT IGNORE INTO users (identifier, license) VALUES (?, ?)', { identifier, license })
    local row = MySQL.single.await('SELECT * FROM users WHERE identifier = ?', { identifier }) or {}
    MULTI.Accounts._Inject(src, {
        source = src, identifier = identifier, license = license, group = row.group or 'user',
        warnings = tonumber(row.warnings) or 0, maxCharacters = tonumber(row.char) or 5,
        maxJobs = tonumber(row.max_jobs) or 3, banneduntil = 0,
    })
    if citizenid then
        local row = MySQL.single.await('SELECT * FROM players WHERE citizenid = ?', { citizenid })
        if not row then return false end
        for _, col in ipairs({ 'money', 'job', 'gang', 'position', 'metadata', 'charinfo' }) do
            row[col] = json.decode(row[col] or 'null')
        end
        RSGCore.Player.CheckPlayerData(src, row)
    else
        data = data or {}
        data.license = license
        RSGCore.Player.CheckPlayerData(src, data)
    end
    local P = RSGCore.Players[src]
    return P and P.PlayerData.citizenid or false
end)

exports('_TestSaveLook', function(src, part, value)
    return MULTI.Login.SaveLook(src, part, value)
end)

exports('_TestLogout', function(src)
    RSGCore.Player.Logout(src)
    MULTI.Accounts.bySource[src] = nil
    return true
end)
