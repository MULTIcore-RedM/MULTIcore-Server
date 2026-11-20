-- ============================================================
-- MULTIcore :: database tables
-- Creates every table the core needs if it is missing (RSG core tables
-- from sql/rsg_core.sql, MULTIcore's own from sql/multicore.sql), before
-- any player can log in. Only CREATE TABLE IF NOT EXISTS statements run;
-- nothing existing is changed.
-- ============================================================

MULTI.Schema = { ready = false }

local function statements(file)
    local text = LoadResourceFile(GetCurrentResourceName(), file)
    if not text then return {} end
    text = text:gsub('%-%-[^\n]*', '')
    local out = {}
    for stmt in text:gmatch('[^;]+') do
        stmt = stmt:match('^%s*(.-)%s*$')
        if stmt:upper():find('^CREATE TABLE IF NOT EXISTS') then out[#out + 1] = stmt end
    end
    return out
end

function MULTI.Schema.Wait()
    while not MULTI.Schema.ready do Wait(50) end
end

CreateThread(function()
    local made, failed = 0, 0
    for _, file in ipairs({ 'sql/rsg_core.sql', 'sql/multicore.sql', 'sql/vorp_compat.sql' }) do
        for _, stmt in ipairs(statements(file)) do
            local ok, err = pcall(MySQL.query.await, stmt)
            if ok then made = made + 1 else
                failed = failed + 1
                print(('^1[MULTIcore] table setup failed: %s^7'):format(tostring(err)))
            end
        end
    end
    -- users.license was added by MULTIcore; a VORP users table brought over from an old server lacks it
    pcall(MySQL.query.await, 'ALTER TABLE `users` ADD COLUMN IF NOT EXISTS `license` VARCHAR(255) DEFAULT NULL')
    -- the same for a VORP characters table: MULTIcore links its rows to players.citizenid
    pcall(MySQL.query.await, 'ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `citizenid` VARCHAR(50) DEFAULT NULL')
    MULTI.Schema.ready = true
    print(('[MULTIcore] database tables ready (%d checked%s)'):format(made, failed > 0 and (', ' .. failed .. ' failed') or ''))
end)
