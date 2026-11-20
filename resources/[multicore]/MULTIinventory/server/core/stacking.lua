-- ============================================================
-- MULTIinventory :: server/core/stacking.lua
--
-- Slot placement inside ONE container. No permission/weight checks here
-- (inventory.lua does them); these functions never yield.
--
-- Rules
--   * Two stacks merge only when Meta.stackKey(item, meta) is equal
--     (shared/metadata.lua: sorted keys, Config.Stacking.ignoreKeys ignored).
--   * Decaying items (items.degradation > 0) merge only when their expiry
--     times are within Config.Degradation.mergeWindowSeconds; the merged stack
--     keeps the earlier expiry.
--   * Config.Stacking.limitIsPerStack = true -> items.limit is the stack size cap.
--   * Weapons/occupants never stack. Equipment slots hold exactly one piece.
--
--   Stacking.decayFor(def, now) -> decayAt|nil
--   Stacking.plan(c, def, count, meta, opts) -> plan|nil, err   opts.slot, opts.decayAt
--   Stacking.apply(c, def, plan, meta, opts) -> placed { { slot, id, count } }
--   Stacking.add(c, def, count, meta, opts) -> placed|nil, err
--   Stacking.candidates(c, item, meta|nil) -> stacks (removal order)
--   Stacking.count(c, item, meta|nil) -> n
--   Stacking.remove(c, item, count, meta|nil) -> removed|nil, err   removed = { {item,count,metadata,id} }
--   Stacking.sort(c, mode) ('name'|'type'|'weight'|'group')
-- ============================================================

Stacking = Stacking or {}

local function window() return (Config.Degradation and Config.Degradation.mergeWindowSeconds) or 3600 end

function Stacking.decayFor(def, now)
    if not (Config.Degradation and Config.Degradation.enabled) then return nil end
    local m = def and tonumber(def.degradation) or 0
    if m <= 0 then return nil end
    return (now or Util.now()) + math.floor(m * 60)
end

function Stacking.perStackCap(def)
    if Config.Stacking.limitIsPerStack and def and (tonumber(def.limit) or 0) > 0 then return def.limit end
    return math.huge
end

local function decayCompatible(a, b)
    if a == nil and b == nil then return true end
    if a == nil or b == nil then return false end
    return math.abs(a - b) <= window()
end

function Stacking.compatible(e, key, decayAt)
    return e.kind ~= 'weapon' and e.key == key and decayCompatible(e.decayAt, decayAt)
end

local function equipSlotFor(item)
    local cat = ClothingCategoriesByItem and ClothingCategoriesByItem[item]
    return cat and cat.order or nil
end

function Stacking.plan(c, def, count, meta, opts)
    opts = opts or {}
    if type(count) ~= 'number' or count < 1 or count ~= math.floor(count) then return nil, 'bad_count' end
    local key = Meta.stackKey(def.name, meta)
    local decayAt = opts.decayAt
    if decayAt == nil and not opts.noDecay then decayAt = Stacking.decayFor(def) end
    local cap = Stacking.perStackCap(def)
    local plan = { merges = {}, news = {}, key = key, decayAt = decayAt }

    if c.kind == 'equip' then
        local slot = opts.slot or equipSlotFor(def.name)
        if not slot or count ~= 1 then return nil, 'equip_slot' end
        if c.stacks[slot] then return nil, 'slot_taken' end
        plan.news[1] = { slot = slot, n = 1 }
        return plan
    end

    if opts.slot then
        local s = opts.slot
        if s < 1 or s > c.slots then return nil, 'bad_slot' end
        local e = c.stacks[s]
        if not e then
            if count > cap then return nil, 'stack_full' end
            plan.news[1] = { slot = s, n = count }
        elseif Stacking.compatible(e, key, decayAt) then
            if e.count + count > cap then return nil, 'stack_full' end
            plan.merges[1] = { stack = e, n = count }
        else
            return nil, 'slot_taken'
        end
        return plan
    end

    local left = count
    -- 1) top up equal stacks (lowest slot first)
    for s = 1, c.slots do
        if left <= 0 then break end
        local e = c.stacks[s]
        if e and Stacking.compatible(e, key, decayAt) and e.count < cap then
            local n = math.min(left, cap - e.count)
            plan.merges[#plan.merges + 1] = { stack = e, n = n }
            left = left - n
        end
    end
    -- 2) new stacks in free slots
    local s = 1
    while left > 0 do
        while s <= c.slots and c.stacks[s] do s = s + 1 end
        if s > c.slots then return nil, 'slots' end
        local n = math.min(left, cap)
        plan.news[#plan.news + 1] = { slot = s, n = n }
        left = left - n
        s = s + 1
    end
    return plan
end

function Stacking.apply(c, def, plan, meta, opts)
    opts = opts or {}
    local placed = {}
    for _, m in ipairs(plan.merges) do
        local e = m.stack
        e.count = e.count + m.n
        if plan.decayAt and e.decayAt and plan.decayAt < e.decayAt then e.decayAt = plan.decayAt end
        e.updatedAt = Util.now()
        Containers.touch(c, e.slot)
        placed[#placed + 1] = { slot = e.slot, id = e.id, count = m.n }
    end
    for _, nw in ipairs(plan.news) do
        local st = Containers.newStack(def.name, nw.n, Util.deepcopy(Meta.normalize(meta)), opts.createdAt, plan.decayAt)
        if opts.legacy then st.legacy = opts.legacy end
        if opts.batch then st.batch = opts.batch end
        Containers.place(c, nw.slot, st)
        placed[#placed + 1] = { slot = nw.slot, id = st.id, count = nw.n }
    end
    return placed
end

function Stacking.add(c, def, count, meta, opts)
    local plan, err = Stacking.plan(c, def, count, meta, opts)
    if not plan then return nil, err end
    return Stacking.apply(c, def, plan, meta, opts)
end

---Stacks of `item` in removal order. meta nil = any stack: plain (empty metadata)
---stacks first, then the oldest; meta given = only stacks with equal metadata, oldest first.
function Stacking.candidates(c, item, meta)
    local list = {}
    local key = meta ~= nil and Meta.stackKey(item, meta) or nil
    local plainKey = Meta.stackKey(item, {})
    for _, e in pairs(c.stacks) do
        if e.kind ~= 'weapon' and e.item == item and (key == nil or e.key == key) then
            list[#list + 1] = e
        end
    end
    table.sort(list, function(a, b)
        if key == nil then
            local pa, pb = a.key == plainKey, b.key == plainKey
            if pa ~= pb then return pa end
        end
        local da, db = a.decayAt or math.huge, b.decayAt or math.huge
        if da ~= db then return da < db end
        if a.createdAt ~= b.createdAt then return a.createdAt < b.createdAt end
        return a.id < b.id
    end)
    return list
end

function Stacking.count(c, item, meta)
    local n = 0
    for _, e in ipairs(Stacking.candidates(c, item, meta)) do n = n + e.count end
    return n
end

function Stacking.remove(c, item, count, meta)
    if type(count) ~= 'number' or count < 1 or count ~= math.floor(count) then return nil, 'bad_count' end
    local list = Stacking.candidates(c, item, meta)
    local have = 0
    for _, e in ipairs(list) do have = have + e.count end
    if have < count then return nil, 'not_enough' end
    local removed, left = {}, count
    for _, e in ipairs(list) do
        if left <= 0 then break end
        local n = math.min(left, e.count)
        removed[#removed + 1] = { item = e.item, count = n, metadata = Util.deepcopy(e.metadata), id = e.id, decayAt = e.decayAt }
        if n == e.count then
            Containers.take(c, e.slot)
        else
            e.count = e.count - n
            e.updatedAt = Util.now()
            Containers.touch(c, e.slot)
        end
        left = left - n
    end
    return removed
end

local function sortKey(mode, e)
    local d = Registry.get(e.item)
    local label = tostring(e.metadata and e.metadata.label or (d and d.label) or e.item):lower()
    if mode == 'type' or mode == 'group' then return (d and d.groupId or 999), label end
    if mode == 'weight' then return -Weight.ofEntry(e), label end
    return 0, label
end

---Re-orders a grid; equal stacks are merged first (per-stack cap respected).
---Totals never change. Equipment containers are not sortable.
---mode = 'name' | 'type' ('group') | 'weight'
function Stacking.sort(c, mode)
    if c.kind == 'equip' then return false, 'not_sortable' end
    local entries = {}
    for _, e in pairs(c.stacks) do entries[#entries + 1] = e end
    table.sort(entries, function(a, b) return a.slot < b.slot end)
    local oldSlot = {}
    for _, e in ipairs(entries) do oldSlot[e] = e.slot end
    -- merge equal stacks into the first one seen
    local keep = {}
    for _, e in ipairs(entries) do
        local gone = false
        if e.kind ~= 'weapon' then
            local cap = Stacking.perStackCap(Registry.get(e.item))
            for _, k in ipairs(keep) do
                if k.kind ~= 'weapon' and k.key == e.key and decayCompatible(k.decayAt, e.decayAt) and k.count < cap then
                    local n = math.min(e.count, cap - k.count)
                    k.count = k.count + n
                    if e.decayAt and k.decayAt and e.decayAt < k.decayAt then k.decayAt = e.decayAt end
                    e.count = e.count - n
                    if e.count == 0 then gone = true break end
                end
            end
        end
        if not gone then keep[#keep + 1] = e end
    end
    local keys = {}
    for _, e in ipairs(keep) do keys[e] = { sortKey(mode, e) } end
    table.sort(keep, function(a, b)
        local ka, kb = keys[a], keys[b]
        if ka[1] ~= kb[1] then return ka[1] < kb[1] end
        if ka[2] ~= kb[2] then return ka[2] < kb[2] end
        return tostring(a.id) < tostring(b.id)
    end)
    for _, e in ipairs(entries) do Containers.take(c, e.slot) end
    for i, e in ipairs(keep) do Containers.place(c, i, e) end
    for _, e in ipairs(keep) do
        if e.kind == 'weapon' and oldSlot[e] ~= e.slot then
            InvHooks.emit('occupantMoved', c, c, e, { reason = 'sort' })
        end
    end
    return true
end

