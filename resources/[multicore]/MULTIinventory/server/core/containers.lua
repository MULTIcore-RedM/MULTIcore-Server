-- ============================================================
-- MULTIinventory :: server/core/containers.lua
--
-- A container is any place that holds items:
--   'player:<charid>'  player grid (Config.Player.slots, weight = character capacity)
--   'equip:<charid>'   worn clothing, slot = ClothingCategories[].order
--   'drop:<n>'         a world pile (server/core/drops.lua)
--   '<any other id>'   registered secondary (stash, saddlebag, trunk...), id kept exactly as
--                      the caller registers it
-- Containers are loaded lazily from the DB, cached, and flushed by persistence.lua.
--
-- Container = { id, kind, ownerCharId, label, slots, maxWeight|nil, flags = {}, perms = {},
--               stacks = { [slot] = Entry }, dirty, defDirty, lastUsed }
-- Entry (stack)    = { id, slot, item, count, metadata, key, hash, createdAt, decayAt, updatedAt,
--                      legacy, batch }
-- Entry (occupant) = { kind = 'weapon', id = 'w<weaponId>', weaponId, slot, item, count = 1,
--                      metadata, weight }   -- placed by the weapons part; never persisted here
--
-- Low-level only (no rule checks) - rules live in inventory.lua:
--   Containers.get(id, opts) -> c|nil        (yields on first load; opts.create for unknown secondary)
--   Containers.peek(id) -> c|nil             (cache only, never yields)
--   Containers.define(id, def) -> c          (register / update a secondary definition)
--   Containers.undefine(id, purge)
--   Containers.unload(id)                    (flush + evict)
--   Containers.newStack(item, count, meta, createdAt, decayAt) -> stack (id allocated)
--   Containers.place(c, slot, entry) / Containers.take(c, slot) -> entry
--   Containers.touch(c, slot)                (dirty + UI delta)
--   Containers.freeSlot(c) -> slot|nil       Containers.usedSlots(c) -> n
--   Containers.findStack(stackId) -> c, stack (loaded containers only)
--   Containers.locateStack(stackId) -> c, stack (loads the owning container if needed)
--   Containers.each(fn(c))
-- ============================================================

Containers = Containers or {}

local cache, index, loading, defs = {}, {}, {}, {}

local KINDS = { player = 'player', equip = 'equip', drop = 'drop' }

function Containers.kindOf(id)
    local p = tostring(id):match('^(%a+):%d+$')
    return KINDS[p] or 'custom'
end

local function charOf(id)
    return tonumber(tostring(id):match('^%a+:(%d+)$'))
end

local function equipSlots()
    return (ClothingCategories and #ClothingCategories > 0) and #ClothingCategories or 35
end

local function defaults(id, kind)
    if kind == 'player' then
        return { kind = 'player', ownerCharId = charOf(id), slots = Config.Player.slots, label = 'Inventory' }
    elseif kind == 'equip' then
        return { kind = 'equip', ownerCharId = charOf(id), slots = equipSlots(), label = 'Equipment' }
    elseif kind == 'drop' then
        return { kind = 'drop', slots = Config.Drop.slots or 20, label = 'Ground', flags = { acceptWeapons = true } }
    end
    local d = Config.Secondary and Config.Secondary.defaults or {}
    return { kind = 'custom', slots = d.slots or 50, maxWeight = d.maxWeight,
             flags = { acceptWeapons = d.acceptWeapons ~= false, shared = d.shared == true } }
end

local function newContainer(id, def)
    local kind = def.kind or Containers.kindOf(id)
    local base = defaults(id, kind)
    return {
        id = id,
        kind = kind,
        ownerCharId = def.ownerCharId or base.ownerCharId,
        label = def.label or base.label or id,
        slots = tonumber(def.slots) or base.slots,
        maxWeight = tonumber(def.maxWeight) or base.maxWeight,
        flags = def.flags or base.flags or {},
        perms = def.perms or {},
        stacks = {},
        changed = {},
        dirty = false,
        defDirty = false,
        lastUsed = Util.now(),
    }
end

function Containers.stackFromRow(r)
    local meta = Util.jsonDecode(r.metadata, {})
    if type(meta) ~= 'table' then meta = {} end
    return {
        id = math.tointeger(tonumber(r.id)),
        slot = tonumber(r.slot),
        item = r.item,
        count = tonumber(r.count) or 0,
        metadata = meta,
        key = Meta.stackKey(r.item, meta),
        hash = r.meta_hash or Meta.hash(meta),
        createdAt = tonumber(r.created_at) or Util.now(),
        decayAt = tonumber(r.decay_at),
        updatedAt = tonumber(r.updated_at) or Util.now(),
        legacy = tonumber(r.legacy_crafted_id),
        batch = tonumber(r.migration_batch),
    }
end

function Containers.newStack(item, count, meta, createdAt, decayAt)
    meta = Meta.normalize(meta)
    return {
        id = Persistence.allocId(),
        item = item,
        count = count,
        metadata = meta,
        key = Meta.stackKey(item, meta),
        hash = Meta.hash(meta),
        createdAt = createdAt or Util.now(),
        decayAt = decayAt,
        updatedAt = Util.now(),
    }
end

function Containers.peek(id)
    local c = cache[id]
    if c then c.lastUsed = Util.now() end
    return c
end

function Containers.isLoaded(id) return cache[id] ~= nil end

function Containers.freeSlot(c, from)
    for s = from or 1, c.slots do
        if not c.stacks[s] then return s end
    end
    return nil
end

function Containers.usedSlots(c)
    local n = 0
    for _ in pairs(c.stacks) do n = n + 1 end
    return n
end

function Containers.touch(c, slot)
    c.dirty = true
    c.lastUsed = Util.now()
    if slot then c.changed[slot] = true end
    Persistence.markDirty(c)
    Sync.queue(c, slot)
end

function Containers.place(c, slot, entry)
    assert(c.stacks[slot] == nil, 'slot occupied')
    entry.slot = slot
    entry.updatedAt = Util.now()
    c.stacks[slot] = entry
    index[entry.id] = c.id
    Containers.touch(c, slot)
end

function Containers.take(c, slot)
    local e = c.stacks[slot]
    if not e then return nil end
    c.stacks[slot] = nil
    if index[e.id] == c.id then index[e.id] = nil end
    Containers.touch(c, slot)
    return e
end

function Containers.findStack(stackId)
    stackId = math.tointeger(tonumber(stackId))
    if not stackId then return nil end
    local cid = index[stackId]
    local c = cid and cache[cid]
    if not c then return nil end
    for _, e in pairs(c.stacks) do
        if e.id == stackId then return c, e end
    end
    return nil
end

function Containers.locateStack(stackId)
    local c, e = Containers.findStack(stackId)
    if c then return c, e end
    local cid = InvDB.scalar('SELECT `container_id` FROM `multiinv_stacks` WHERE `id` = ?', { tonumber(stackId) })
    if not cid then return nil end
    Containers.get(cid, { create = true })
    return Containers.findStack(stackId)
end

local function decodeDefRow(row)
    return {
        kind = row.kind,
        ownerCharId = tonumber(row.owner_charid),
        label = row.label,
        slots = tonumber(row.slots),
        maxWeight = tonumber(row.max_weight),
        flags = Util.jsonDecode(row.flags, {}) or {},
        perms = Util.jsonDecode(row.perms, {}) or {},
    }
end

local function load(id, opts)
    local kind = Containers.kindOf(id)
    local rows = InvDB.query('SELECT * FROM `multiinv_containers` WHERE `id` = ?', { id })
    local def = defs[id]
    local fromRow = rows[1] and decodeDefRow(rows[1]) or nil
    local stacks = InvDB.query('SELECT * FROM `multiinv_stacks` WHERE `container_id` = ? ORDER BY `slot`, `id`', { id })
    if kind == 'custom' and not def and not fromRow and #stacks == 0 and not (opts and opts.create) then
        return nil
    end
    local c = newContainer(id, def or fromRow or { kind = kind })
    if kind == 'player' or kind == 'equip' then
        -- slot count of built-in kinds always follows the config
        c.slots = defaults(id, kind).slots
    end
    if not fromRow then c.defDirty = true end
    local overflow = {}
    for _, r in ipairs(stacks) do
        local s = Containers.stackFromRow(r)
        if s.slot and s.slot >= 1 and s.slot <= c.slots and not c.stacks[s.slot] then
            c.stacks[s.slot] = s
            index[s.id] = id
        else
            overflow[#overflow + 1] = s
        end
    end
    -- rows with a slot outside the grid (slot count lowered) or a duplicate: re-home, never lose
    for _, s in ipairs(overflow) do
        local slot = Containers.freeSlot(c)
        if not slot then
            c.slots = c.slots + 1
            slot = c.slots
            print(('^3[MULTIinventory] %s over capacity - grew to %d slots to keep stack %d^7'):format(id, c.slots, s.id))
        end
        s.slot = slot
        c.stacks[slot] = s
        index[s.id] = id
        c.dirty = true
    end
    if c.dirty then Persistence.markDirty(c) end
    if c.defDirty then Persistence.markDirty(c) end
    return c
end

function Containers.get(id, opts)
    if type(id) ~= 'string' or id == '' then return nil end
    local c = cache[id]
    if c then c.lastUsed = Util.now() return c end
    if loading[id] then
        Citizen.Await(loading[id])
        c = cache[id]
        if c or not (opts and opts.create) then return c end
    end
    local p = promise.new()
    loading[id] = p
    local ok, res = pcall(load, id, opts)
    loading[id] = nil
    if not ok then
        print(('^1[MULTIinventory] load %s failed: %s^7'):format(id, tostring(res)))
        p:resolve(false)
        return nil
    end
    if res then
        cache[id] = res
        InvHooks.emit('containerLoaded', res)
    end
    p:resolve(true)
    return res
end

---Register or update a secondary definition. Idempotent.
---def = { label, slots, maxWeight, ownerCharId, flags = {}, perms = {}, kind = 'custom'|'stash'|... }
function Containers.define(id, def)
    assert(type(id) == 'string' and id ~= '', 'container id')
    def = def or {}
    local prev = defs[id] or {}
    local merged = {}
    for k, v in pairs(prev) do merged[k] = v end
    for k, v in pairs(def) do merged[k] = v end
    defs[id] = merged
    local c = cache[id]
    if c then
        c.label = merged.label or c.label
        -- lowering slots never deletes: occupied slots above the new limit stay until moved
        if merged.slots then c.slots = tonumber(merged.slots) or c.slots end
        c.maxWeight = tonumber(merged.maxWeight)
        c.flags = merged.flags or c.flags
        c.perms = merged.perms or c.perms
        c.ownerCharId = merged.ownerCharId or c.ownerCharId
        if merged.kind then c.kind = merged.kind end
    end
    -- not cached: stacks are loaded on the first Containers.get; the definition row is saved now
    if c then
        c.defDirty = true
        Persistence.markDirty(c)
    else
        Persistence.saveDefLater(id, merged)
    end
    return true
end

function Containers.getDefinition(id) return defs[id] end
function Containers.isDefined(id) return defs[id] ~= nil end

function Containers.undefine(id, purge)
    defs[id] = nil
    if purge then
        local c = cache[id]
        if c then
            for slot in pairs(c.stacks) do Containers.take(c, slot) end
        end
        Persistence.purgeLater(id)
    end
    return true
end

function Containers.unload(id)
    local c = cache[id]
    if not c then return true end
    if not Persistence.flush() then
        -- keep it cached (and dirty) - the periodic flush retries; never drop unsaved state
        return false
    end
    if cache[id] ~= c then return true end
    if c.dirty or c.defDirty then return false end -- changed while saving: next round
    InvHooks.emit('containerUnloaded', c)
    for _, e in pairs(c.stacks) do if index[e.id] == id then index[e.id] = nil end end
    cache[id] = nil
end

---Create a brand-new, empty container in the cache without a DB read (never yields).
---Only for ids that cannot exist in the DB yet (fresh drop piles).
function Containers.create(id, def)
    assert(not cache[id], 'container exists: ' .. tostring(id))
    local c = newContainer(id, def or {})
    c.defDirty = true
    cache[id] = c
    Persistence.markDirty(c)
    InvHooks.emit('containerLoaded', c)
    return c
end

---Drop from the cache WITHOUT saving (the caller purged it).
function Containers.forget(id)
    local c = cache[id]
    if not c then return end
    for _, e in pairs(c.stacks) do if index[e.id] == id then index[e.id] = nil end end
    cache[id] = nil
    return true
end

function Containers.each(fn)
    for _, c in pairs(cache) do fn(c) end
end

-- tests only: forget everything (simulates a restart)
function Containers._reset()
    cache, index, loading, defs = {}, {}, {}, {}
end
