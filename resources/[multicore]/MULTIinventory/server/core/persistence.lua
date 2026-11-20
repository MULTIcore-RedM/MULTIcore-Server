-- ============================================================
-- MULTIinventory :: server/core/persistence.lua
--
-- Write-behind saving. Every mutation marks its container dirty; dirty
-- containers are flushed every Config.Persistence.saveIntervalSeconds, on
-- character unload, on /invflush, on txAdmin shutdown and on resource stop.
-- A flush is ONE transaction: for each dirty container
--   DELETE its stack rows; INSERT its current stacks (explicit ids)
-- (+ definition upserts, purges, drop rows, from drops.lua). Flushes are
-- serialised so an older snapshot can never overwrite a newer one.
--
-- Stack ids are allocated in memory (no DB round trip inside an action) from
-- blocks of Config.Persistence.idBlock ids; the table's AUTO_INCREMENT is moved
-- past each block, so other writers using AUTO_INCREMENT never collide.
--
--   Persistence.init()                       (boot: id allocator)
--   Persistence.allocId() -> integer
--   Persistence.markDirty(c)                 Persistence.saveDefLater(id, def)
--   Persistence.purgeLater(id)               Persistence.addExtra(fn(list))  (drops.lua)
--   Persistence.flush(id|nil, async?) -> ok
-- ============================================================

Persistence = Persistence or {}

local dirty = {}          -- [containerId] = true
local pendingDefs = {}    -- [id] = def (definitions of containers not loaded)
local pendingPurge = {}   -- [id] = true
local extras = {}         -- fns adding queries (drops)
local nextId, blockEnd = nil, nil
local flushing = nil      -- promise of the flush in progress

local STACK_COLS = '(`id`,`container_id`,`slot`,`item`,`count`,`metadata`,`meta_hash`,`created_at`,`decay_at`,`legacy_crafted_id`,`migration_batch`,`updated_at`)'
local CHUNK = 200

local function reserveBlock(from, await)
    local size = (Config.Persistence and Config.Persistence.idBlock) or 1000
    nextId = from
    blockEnd = from + size - 1
    local sql = ('ALTER TABLE `multiinv_stacks` AUTO_INCREMENT = %d'):format(blockEnd + 1)
    if await then InvDB.query(sql) else MySQL.query(sql, {}) end
end

function Persistence.init()
    local maxId = tonumber(InvDB.scalar('SELECT COALESCE(MAX(`id`), 0) FROM `multiinv_stacks`')) or 0
    local ai = tonumber(InvDB.scalar("SELECT `AUTO_INCREMENT` FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'multiinv_stacks'")) or 1
    local from = math.max(maxId + 1, ai)
    reserveBlock(math.tointeger(from), true)
end

function Persistence.allocId()
    if not nextId then error('Persistence.init() not called') end
    if nextId > blockEnd then reserveBlock(blockEnd + 1, false) end
    local id = nextId
    nextId = nextId + 1
    return id
end

function Persistence.markDirty(c)
    dirty[type(c) == 'table' and c.id or c] = true
end

function Persistence.saveDefLater(id, def)
    pendingDefs[id] = def
    dirty[id] = true
end

function Persistence.purgeLater(id)
    pendingPurge[id] = true
    pendingDefs[id] = nil   -- a definition saved before the purge must not bring the row back
    dirty[id] = true
end

function Persistence.addExtra(fn) extras[#extras + 1] = fn end

function Persistence.isDirty(id) return dirty[id] == true end

local function defUpsert(id, def, now)
    local vals = {}
    local ph = InvDB.bind({ id, def.kind or Containers.kindOf(id), def.ownerCharId,
        def.label and tostring(def.label):sub(1, 100), tonumber(def.slots) or 50, tonumber(def.maxWeight),
        Util.jsonEncode(def.flags), Util.jsonEncode(def.perms), now, now }, 10, vals)
    return {
        query = 'INSERT INTO `multiinv_containers` (`id`,`kind`,`owner_charid`,`label`,`slots`,`max_weight`,`flags`,`perms`,`created_at`,`updated_at`) VALUES ' .. ph .. ' ON DUPLICATE KEY UPDATE `kind`=VALUES(`kind`),`owner_charid`=VALUES(`owner_charid`),`label`=VALUES(`label`),`slots`=VALUES(`slots`),`max_weight`=VALUES(`max_weight`),`flags`=VALUES(`flags`),`perms`=VALUES(`perms`),`updated_at`=VALUES(`updated_at`)',
        values = vals,
    }
end

local function stackInserts(c, inserts, now)
    local rows = {}
    for _, e in pairs(c.stacks) do
        if e.kind ~= 'weapon' and e.count > 0 then rows[#rows + 1] = e end
    end
    table.sort(rows, function(a, b) return a.slot < b.slot end)
    for i = 1, #rows, CHUNK do
        local ph, vals = {}, {}
        for j = i, math.min(i + CHUNK - 1, #rows) do
            local e = rows[j]
            -- decay_at / legacy / batch may be nil -> literal NULL (no holes in vals)
            ph[#ph + 1] = InvDB.bind({ e.id, c.id, e.slot, e.item, e.count, Util.jsonEncode(e.metadata), e.hash,
                e.createdAt, e.decayAt, e.legacy, e.batch, e.updatedAt or now }, 12, vals)
        end
        inserts[#inserts + 1] = { query = 'INSERT INTO `multiinv_stacks` ' .. STACK_COLS .. ' VALUES ' .. table.concat(ph, ','), values = vals }
    end
end

-- Snapshot of EVERYTHING dirty, dirty flags cleared. All DELETEs come before all
-- INSERTs: a stack that moved A -> B keeps its id, so A's old row must be gone
-- before B's row is written. (That is also why a flush is always a full flush.)
local function snapshot()
    local deletes, inserts, defsList, taken, now = {}, {}, {}, {}, Util.now()
    local ids = {}
    for id in pairs(dirty) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        dirty[id] = nil
        local entry = { id = id }
        if pendingPurge[id] then
            pendingPurge[id] = nil
            entry.purge = true
            deletes[#deletes + 1] = { query = 'DELETE FROM `multiinv_stacks` WHERE `container_id` = ?', values = { id } }
            deletes[#deletes + 1] = { query = 'DELETE FROM `multiinv_containers` WHERE `id` = ?', values = { id } }
        end
        local c = Containers.peek(id)
        if c then
            if c.defDirty then
                c.defDirty = false
                entry.def = true
                defsList[#defsList + 1] = defUpsert(id, c, now)
            end
            if c.dirty then
                c.dirty = false
                entry.stacks = true
                deletes[#deletes + 1] = { query = 'DELETE FROM `multiinv_stacks` WHERE `container_id` = ?', values = { id } }
                stackInserts(c, inserts, now)
            end
        elseif pendingDefs[id] then
            entry.pendingDef = pendingDefs[id]
            defsList[#defsList + 1] = defUpsert(id, pendingDefs[id], now)
        end
        pendingDefs[id] = nil
        taken[#taken + 1] = entry
    end
    local list = {}
    for _, q in ipairs(deletes) do list[#list + 1] = q end
    for _, q in ipairs(defsList) do list[#list + 1] = q end
    for _, q in ipairs(inserts) do list[#list + 1] = q end
    local undo = {}
    for _, fn in ipairs(extras) do
        local u = fn(list, now)
        if u then undo[#undo + 1] = u end
    end
    taken.undo = undo
    return list, taken
end

local function restore(taken)
    for _, t in ipairs(taken) do
        dirty[t.id] = true
        local c = Containers.peek(t.id)
        if c then
            if t.def then c.defDirty = true end
            if t.stacks then c.dirty = true end
        end
        if t.pendingDef then pendingDefs[t.id] = t.pendingDef end
        if t.purge then pendingPurge[t.id] = true end
    end
    for _, u in ipairs(taken.undo or {}) do pcall(u) end
end

---Flush everything that is dirty. async = true for resource stop (no await).
---Always a full flush (see snapshot). Returns ok.
function Persistence.flush(_, async)
    if async then
        local list = snapshot()
        if #list > 0 then MySQL.transaction(list, function() end) end
        return true
    end
    while flushing do Citizen.Await(flushing) end
    local p = promise.new()
    flushing = p
    local list, taken = snapshot()
    local ok = InvDB.transaction(list)
    if not ok then
        restore(taken)
        print(('^1[MULTIinventory] flush failed (%d statements) - will retry^7'):format(#list))
    end
    flushing = nil
    p:resolve(ok)
    return ok
end

-- tests only
function Persistence._reset()
    dirty, pendingDefs, pendingPurge, extras, nextId, blockEnd, flushing = {}, {}, {}, {}, nil, nil, nil
end
