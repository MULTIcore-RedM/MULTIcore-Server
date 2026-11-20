-- ============================================================
-- MULTIinventory :: server/core/log.lua
--
-- Audit log -> multiinv_log (buffered, flushed every Config.Log.flushSeconds
-- and on stop). admin_* actions are always written; others per Config.Log.actions.
--
--   InvLog.write(action, e)
--     e = { actorSrc, actorCharId, actor (text), targetCharId, from, to, item, count, data (table) }
--   InvLog.flush(async?)
--   InvLog.recent(filter, limit) -> rows (yields; filter = { charId, action, id })
-- data should carry the full stacks ({ item, count, metadata }) so /invrestore can rebuild them.
-- ============================================================

InvLog = InvLog or {}

local buffer = {}

local function actorName(src)
    if not src or src == 0 then return 'console' end
    local name = GetPlayerName and GetPlayerName(src)
    return name and tostring(name):sub(1, 64) or ('src:' .. tostring(src))
end

function InvLog.write(action, e)
    if not Config.Log.enabled then return end
    if not tostring(action):match('^admin_') and not (Config.Log.actions or {})[action] then return end
    e = e or {}
    local actorCharId = e.actorCharId
    if not actorCharId and e.actorSrc and e.actorSrc ~= 0 then
        local st = State.get(e.actorSrc)
        actorCharId = st and st.charId
    end
    buffer[#buffer + 1] = {
        Util.now(), actorCharId, e.actor or actorName(e.actorSrc), e.targetCharId, tostring(action):sub(1, 32),
        e.from, e.to, e.item, e.count, e.data and Util.jsonEncode(e.data) or nil,
    }
    TriggerEvent('MULTIinventory:logged', action, e)
end

function InvLog.flush(async)
    if #buffer == 0 then return true end
    local rows = buffer
    buffer = {}
    local ph, vals = {}, {}
    for i, r in ipairs(rows) do ph[i] = InvDB.bind(r, 10, vals) end
    local sql = 'INSERT INTO `multiinv_log` (`at`,`actor_charid`,`actor`,`target_charid`,`action`,`container_from`,`container_to`,`item`,`count`,`data`) VALUES ' .. table.concat(ph, ',')
    if async then MySQL.insert(sql, vals) return true end
    local ok = pcall(MySQL.insert.await, sql, vals)
    if not ok then
        for i = #rows, 1, -1 do table.insert(buffer, 1, rows[i]) end
        return false
    end
    return true
end

function InvLog.pending() return #buffer end

function InvLog.recent(filter, limit)
    filter = filter or {}
    local where, params = {}, {}
    if filter.id then where[#where + 1] = '`id` = ?'; params[#params + 1] = filter.id end
    if filter.charId then
        where[#where + 1] = '(`actor_charid` = ? OR `target_charid` = ?)'
        params[#params + 1] = filter.charId; params[#params + 1] = filter.charId
    end
    if filter.action then where[#where + 1] = '`action` = ?'; params[#params + 1] = filter.action end
    local sql = 'SELECT * FROM `multiinv_log`' .. (#where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or '')
        .. ' ORDER BY `id` DESC LIMIT ' .. math.floor(Util.clamp(limit or 20, 1, 200))
    InvLog.flush()
    return InvDB.query(sql, params)
end
