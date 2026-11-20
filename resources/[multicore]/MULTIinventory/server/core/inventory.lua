-- ============================================================
-- MULTIinventory :: server/core/inventory.lua
--
-- The rule layer. Every state change of any part goes through these
-- functions
-- server/core APIs"). Check + apply never yield in between, so two calls can
-- never interleave (Lua runs one thread at a time; only Containers.get yields,
-- and it is always called before the checks).
--
-- target = player source (number), 'player:<charid>' (offline OK), any container id, or a container table.
-- ctx    = { src = acting player|nil, reason = 'api'|'move'|..., actor = 'name' } (optional)
--
--   Inv.resolve(target, opts) -> c|nil, err
--   Inv.def(item) -> def (stub for unknown items already stored)
--   Inv.canAdd(target, item, count, meta, ctx) -> ok, err
--   Inv.add(target, item, count, meta, ctx, opts) -> ok, err|placed     opts.slot, opts.createdAt, opts.decayAt
--   Inv.remove(target, item, count, meta|nil, ctx) -> ok, err|removed
--   Inv.removeStack(target|nil, stackId, count|nil, ctx) -> ok, err|removed
--   Inv.count(target, item, meta|nil) -> n
--   Inv.getStacks(target, filter|nil) -> { itemTable, ... }     filter = { item, meta, group }
--   Inv.getStack(stackId) -> itemTable|nil, containerId
--   Inv.setMetadata(target|nil, stackId, meta, count|nil, ctx) -> ok, err|stackId
--   Inv.move(fromC, fromSlot, toC, toSlot|nil, count|nil, ctx) -> ok, err
--   Inv.clear(target, opts, ctx) -> ok, removed      opts.keep = { item = true }, opts.occupants
--   Inv.weight(target) -> load, capacity|nil
-- Errors: unknown_item, unknown_container, is_weapon, bad_count, bad_slot, slots, weight, limit,
--         not_enough, no_item, stack_full, slot_taken, equip_slot, no_weapons, denied (hooks), ...
-- ============================================================

Inv = Inv or {}

local function ctxOf(ctx) return ctx or { reason = 'api' } end

function Inv.def(item)
    return Registry.get(item) or { name = item, label = item, weight = 0.0, limit = 0, canRemove = true,
                                   degradation = 0, groupId = 1, group = 'default', _missing = true }
end

function Inv.resolve(target, opts)
    if type(target) == 'table' and target.stacks then return target end
    local n = tonumber(target)
    if n and (type(target) == 'number' or tostring(target):match('^%d+$')) then
        local st = State.get(math.tointeger(n))
        if not st then return nil, 'player_not_loaded' end
        return Containers.get('player:' .. st.charId, { create = true })
    end
    if type(target) ~= 'string' or target == '' then return nil, 'unknown_container' end
    local kind = Containers.kindOf(target)
    if kind == 'player' or kind == 'equip' then
        local cid = tonumber(target:match(':(%d+)$'))
        State.prefetchCapacity(cid)
        return Containers.get(target, { create = true })
    end
    local c = Containers.get(target, opts)
    if not c then return nil, 'unknown_container' end
    return c
end

local function ownerSrc(c)
    return c.ownerCharId and State.srcOfChar(c.ownerCharId) or nil
end

local function emitAdded(c, item, count, meta, ctx)
    InvHooks.emit('itemAdded', c, item, count, meta, ctx)
    TriggerEvent('MULTIinventory:itemAdded', c.id, item, count, meta, ctx.reason, ownerSrc(c))
end

local function emitRemoved(c, item, count, meta, ctx)
    InvHooks.emit('itemRemoved', c, item, count, meta, ctx)
    TriggerEvent('MULTIinventory:itemRemoved', c.id, item, count, meta, ctx.reason, ownerSrc(c))
end
Inv._emitAdded, Inv._emitRemoved = emitAdded, emitRemoved

-- checks shared by canAdd/add (no yield)
local function checkAdd(c, item, count, meta, ctx, opts)
    if Util.isWeaponName(item) then return nil, 'is_weapon' end
    local def = Registry.get(item)
    if not def then return nil, 'unknown_item' end
    count = Util.toInt(count)
    if not count or count < 1 then return nil, 'bad_count' end
    local ok, err = InvHooks.check('canAdd', c, item, count, meta, ctx)
    if not ok then return nil, err end
    ok, err = Weight.canFit(c, def, count, meta)
    if not ok then return nil, err end
    local plan
    plan, err = Stacking.plan(c, def, count, meta, opts)
    if not plan then return nil, err end
    if c.kind == 'equip' then
        for _, nw in ipairs(plan.news) do
            local entry = { item = item, count = 1, metadata = meta }
            ok, err = Inv.checkPlace(c, nw.slot, entry, ctx)
            if not ok then return nil, err end
        end
    end
    return plan, def, count
end

function Inv.canAdd(target, item, count, meta, ctx)
    local c, err = Inv.resolve(target)
    if not c then return false, err end
    local plan, e2 = checkAdd(c, item, count, Meta.normalize(meta), ctxOf(ctx))
    if not plan then return false, e2 end
    return true
end

function Inv.add(target, item, count, meta, ctx, opts)
    ctx = ctxOf(ctx)
    local c, err = Inv.resolve(target)
    if not c then return false, err end
    meta = Util.deepcopy(Meta.normalize(meta))
    local plan, def, n = checkAdd(c, item, count, meta, ctx, opts)
    if not plan then return false, def end
    local placed = Stacking.apply(c, def, plan, meta, opts)
    emitAdded(c, item, n, meta, ctx)
    return true, placed
end

function Inv.remove(target, item, count, meta, ctx)
    ctx = ctxOf(ctx)
    local c, err = Inv.resolve(target)
    if not c then return false, err end
    count = Util.toInt(count)
    if not count or count < 1 then return false, 'bad_count' end
    if meta ~= nil then meta = Meta.normalize(meta) end
    if InvHooks.has('canRemove') then
        local left = count
        for _, e in ipairs(Stacking.candidates(c, item, meta)) do
            if left <= 0 then break end
            local ok, e2 = InvHooks.check('canRemove', c, e, math.min(left, e.count), ctx)
            if not ok then return false, e2 end
            left = left - e.count
        end
    end
    local removed
    removed, err = Stacking.remove(c, item, count, meta)
    if not removed then return false, err end
    for _, r in ipairs(removed) do emitRemoved(c, r.item, r.count, r.metadata, ctx) end
    return true, removed
end

function Inv.removeStack(target, stackId, count, ctx)
    ctx = ctxOf(ctx)
    local c, e
    if target ~= nil then
        local err
        c, err = Inv.resolve(target)
        if not c then return false, err end
        stackId = math.tointeger(tonumber(stackId))
        for _, x in pairs(c.stacks) do if x.id == stackId then e = x break end end
    else
        c, e = Containers.locateStack(stackId)
    end
    if not e or e.kind == 'weapon' then return false, 'no_item' end
    count = count == nil and e.count or Util.toInt(count)
    if not count or count < 1 then return false, 'bad_count' end
    if count > e.count then return false, 'not_enough' end
    local ok, err = InvHooks.check('canRemove', c, e, count, ctx)
    if not ok then return false, err end
    local removed = { { item = e.item, count = count, metadata = Util.deepcopy(e.metadata), id = e.id, decayAt = e.decayAt } }
    if count == e.count then
        Containers.take(c, e.slot)
    else
        e.count = e.count - count
        e.updatedAt = Util.now()
        Containers.touch(c, e.slot)
    end
    emitRemoved(c, e.item, count, removed[1].metadata, ctx)
    return true, removed
end

function Inv.count(target, item, meta)
    local c = Inv.resolve(target)
    if not c then return 0 end
    if meta ~= nil then meta = Meta.normalize(meta) end
    return Stacking.count(c, item, meta)
end

function Inv.getStacks(target, filter)
    local c = Inv.resolve(target)
    if not c then return {} end
    local out = {}
    local key = filter and filter.item and filter.meta ~= nil and Meta.stackKey(filter.item, filter.meta) or nil
    for _, e in pairs(c.stacks) do
        local okItem = not (filter and filter.item) or e.item == filter.item
        local okKey = key == nil or e.key == key
        local okGroup = not (filter and filter.group) or (Inv.def(e.item).group == filter.group)
        local okKind = not (filter and filter.kind) or (filter.kind == 'weapon') == (e.kind == 'weapon')
        if okItem and okKey and okGroup and okKind then out[#out + 1] = Sync.itemTable(e, c) end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

function Inv.getStack(stackId)
    local c, e = Containers.locateStack(stackId)
    if not e then return nil end
    return Sync.itemTable(e, c), c.id
end

function Inv.setMetadata(target, stackId, meta, count, ctx)
    ctx = ctxOf(ctx)
    local c, e
    if target ~= nil then
        c = Inv.resolve(target)
        if not c then return false, 'unknown_container' end
        stackId = math.tointeger(tonumber(stackId))
        for _, x in pairs(c.stacks) do if x.id == stackId then e = x break end end
    else
        c, e = Containers.locateStack(stackId)
    end
    if not e or e.kind == 'weapon' then return false, 'no_item' end
    meta = Util.deepcopy(Meta.normalize(meta))
    count = count == nil and e.count or Util.toInt(count)
    if not count or count < 1 or count > e.count then return false, 'bad_count' end
    if count == e.count then
        e.metadata = meta
        e.key = Meta.stackKey(e.item, meta)
        e.hash = Meta.hash(meta)
        e.updatedAt = Util.now()
        Containers.touch(c, e.slot)
        InvHooks.emit('metadataChanged', c, e, ctx)
        return true, e.id
    end
    local slot = Containers.freeSlot(c)
    if not slot then return false, 'slots' end
    e.count = e.count - count
    Containers.touch(c, e.slot)
    local ns = Containers.newStack(e.item, count, meta, e.createdAt, e.decayAt)
    Containers.place(c, slot, ns)
    InvHooks.emit('metadataChanged', c, ns, ctx)
    return true, ns.id
end

-- Built-in placement rules + the canPlace hook.
function Inv.checkPlace(c, slot, entry, ctx)
    if c.kind == 'equip' then
        local cat = ClothingCategories and ClothingCategories[slot]
        if not cat or cat.order ~= slot or cat.item ~= entry.item then return false, 'equip_slot' end
    end
    if entry.kind == 'weapon' and c.flags and c.flags.acceptWeapons == false then return false, 'no_weapons' end
    return InvHooks.check('canPlace', c, slot, entry, ctx)
end

local function newSplitStack(e, count)
    local ns = Containers.newStack(e.item, count, Util.deepcopy(e.metadata), e.createdAt, e.decayAt)
    ns.legacy, ns.batch = nil, nil
    return ns
end

local function moveOccupant(fromC, e, toC, toSlot, ctx)
    local cross = fromC ~= toC
    toSlot = toSlot or Containers.freeSlot(toC)
    if not toSlot then return false, 'slots' end
    local t = toC.stacks[toSlot]
    if t and (cross or t == e) then return false, 'slot_taken' end
    local ok, err = Inv.checkPlace(toC, toSlot, e, ctx)
    if not ok then return false, err end
    if cross then
        ok, err = InvHooks.check('canRemove', fromC, e, 1, ctx)
        if not ok then return false, err end
        ok, err = InvHooks.check('canAdd', toC, e.item, 1, e.metadata, ctx)
        if not ok then return false, err end
        local fk = Weight.pool(fromC)
        local tk, cap, load = Weight.pool(toC)
        if cap and fk ~= tk and load + (e.weight or 0) > cap + 1e-6 then return false, 'weight' end
    end
    local fromSlot = e.slot
    Containers.take(fromC, fromSlot)
    if t then
        Containers.take(toC, toSlot)
        Containers.place(fromC, fromSlot, t)
        if t.kind == 'weapon' then InvHooks.emit('occupantMoved', toC, fromC, t, ctx) end
    end
    Containers.place(toC, toSlot, e)
    InvHooks.emit('occupantMoved', fromC, toC, e, ctx)
    return true
end

---Move `count` of the entry at fromC[fromSlot] to toC[toSlot] (nil = auto place).
---Empty target: move/split. Equal stack: merge. Different entry: swap (full count only).
function Inv.move(fromC, fromSlot, toC, toSlot, count, ctx)
    ctx = ctxOf(ctx)
    local e = fromC.stacks[fromSlot]
    if not e then return false, 'no_item' end
    if toC.kind == 'equip' and count == nil then count = 1 end
    count = count == nil and e.count or Util.toInt(count)
    if not count or count < 1 or count > e.count then return false, 'bad_count' end
    if toSlot ~= nil then
        toSlot = Util.toInt(toSlot)
        if not toSlot or toSlot < 1 or toSlot > toC.slots then return false, 'bad_slot' end
    end
    local cross = fromC ~= toC
    if not cross and (toSlot == nil or toSlot == fromSlot) then return true end
    if e.kind == 'weapon' then
        if count ~= 1 then return false, 'bad_count' end
        return moveOccupant(fromC, e, toC, toSlot, ctx)
    end

    local def = Inv.def(e.item)
    local meta = e.metadata
    local ok, err
    if cross then
        ok, err = InvHooks.check('canRemove', fromC, e, count, ctx)
        if not ok then return false, err end
        ok, err = InvHooks.check('canAdd', toC, e.item, count, meta, ctx)
        if not ok then return false, err end
    end
    local fromKey = Weight.pool(fromC)
    local cap = Stacking.perStackCap(def)

    if toSlot == nil then
        ok, err = Weight.canFit(toC, def, count, meta, { samePool = fromKey })
        if not ok then return false, err end
        local plan
        plan, err = Stacking.plan(toC, def, count, meta, { decayAt = e.decayAt, noDecay = true })
        if not plan then return false, err end
        for _, nw in ipairs(plan.news) do
            ok, err = Inv.checkPlace(toC, nw.slot, e, ctx)
            if not ok then return false, err end
        end
        if count == e.count and #plan.merges == 0 and #plan.news == 1 then
            Containers.take(fromC, fromSlot)
            Containers.place(toC, plan.news[1].slot, e)
        else
            for _, m in ipairs(plan.merges) do
                m.stack.count = m.stack.count + m.n
                if e.decayAt and m.stack.decayAt and e.decayAt < m.stack.decayAt then m.stack.decayAt = e.decayAt end
                m.stack.updatedAt = Util.now()
                Containers.touch(toC, m.stack.slot)
            end
            for _, nw in ipairs(plan.news) do Containers.place(toC, nw.slot, newSplitStack(e, nw.n)) end
            if count == e.count then Containers.take(fromC, fromSlot)
            else e.count = e.count - count; e.updatedAt = Util.now(); Containers.touch(fromC, fromSlot) end
        end
    else
        local t = toC.stacks[toSlot]
        if not t then
            ok, err = Inv.checkPlace(toC, toSlot, e, ctx)
            if not ok then return false, err end
            if cross then
                ok, err = Weight.canFit(toC, def, count, meta, { samePool = fromKey })
                if not ok then return false, err end
            end
            if count > cap then return false, 'stack_full' end
            if count == e.count then
                Containers.take(fromC, fromSlot)
                Containers.place(toC, toSlot, e)
            else
                e.count = e.count - count
                e.updatedAt = Util.now()
                Containers.touch(fromC, fromSlot)
                Containers.place(toC, toSlot, newSplitStack(e, count))
            end
        elseif Stacking.compatible(t, e.key, e.decayAt) then
            if t.count + count > cap then return false, 'stack_full' end
            if toC.kind == 'equip' then return false, 'slot_taken' end
            if cross then
                ok, err = Weight.canFit(toC, def, count, meta, { samePool = fromKey })
                if not ok then return false, err end
            end
            t.count = t.count + count
            if e.decayAt and t.decayAt and e.decayAt < t.decayAt then t.decayAt = e.decayAt end
            t.updatedAt = Util.now()
            Containers.touch(toC, toSlot)
            if count == e.count then Containers.take(fromC, fromSlot)
            else e.count = e.count - count; e.updatedAt = Util.now(); Containers.touch(fromC, fromSlot) end
        else
            -- swap: whole entries only
            if count ~= e.count then return false, 'slot_taken' end
            ok, err = Inv.checkPlace(toC, toSlot, e, ctx)
            if not ok then return false, err end
            ok, err = Inv.checkPlace(fromC, fromSlot, t, ctx)
            if not ok then return false, err end
            if cross then
                ok, err = InvHooks.check('canRemove', toC, t, t.count, ctx)
                if not ok then return false, err end
                ok, err = InvHooks.check('canAdd', fromC, t.item, t.count, t.metadata, ctx)
                if not ok then return false, err end
                local toKey = Weight.pool(toC)
                if toKey ~= fromKey then
                    local we, wt = Weight.ofEntry(e), Weight.ofEntry(t)
                    local same = (t.kind ~= 'weapon' and t.item == e.item)
                    ok, err = Weight.canFit(toC, def, e.count, meta, { freeKg = wt, freeCount = same and t.count or 0 })
                    if not ok then return false, err end
                    if t.kind ~= 'weapon' then
                        ok, err = Weight.canFit(fromC, Inv.def(t.item), t.count, t.metadata, { freeKg = we, freeCount = same and e.count or 0 })
                        if not ok then return false, err end
                    else
                        local _, fcap, fload = Weight.pool(fromC)
                        if fcap and fload - we + wt > fcap + 1e-6 then return false, 'weight' end
                    end
                end
            end
            Containers.take(fromC, fromSlot)
            Containers.take(toC, toSlot)
            Containers.place(toC, toSlot, e)
            Containers.place(fromC, fromSlot, t)
            if t.kind == 'weapon' then InvHooks.emit('occupantMoved', toC, fromC, t, ctx) end
            if cross and t.kind ~= 'weapon' then
                emitRemoved(toC, t.item, t.count, t.metadata, ctx)
                emitAdded(fromC, t.item, t.count, t.metadata, ctx)
            end
        end
    end
    if cross then
        emitRemoved(fromC, e.item, count, meta, ctx)
        emitAdded(toC, e.item, count, meta, ctx)
    end
    return true
end

---Remove everything (optionally keeping some items). Occupants (weapons) only with opts.occupants.
function Inv.clear(target, opts, ctx)
    ctx = ctxOf(ctx)
    opts = opts or {}
    local c, err = Inv.resolve(target)
    if not c then return false, err end
    local removed = {}
    local slots = {}
    for slot in pairs(c.stacks) do slots[#slots + 1] = slot end
    table.sort(slots)
    for _, slot in ipairs(slots) do
        local e = c.stacks[slot]
        local keep = opts.keep and opts.keep[e.item]
        if not keep then
            if e.kind == 'weapon' then
                if opts.occupants then
                    Containers.take(c, slot)
                    removed[#removed + 1] = { kind = 'weapon', weaponId = e.weaponId, item = e.item, count = 1 }
                    InvHooks.emit('occupantRemoved', c, e, ctx)
                end
            else
                Containers.take(c, slot)
                removed[#removed + 1] = { item = e.item, count = e.count, metadata = Util.deepcopy(e.metadata), id = e.id, decayAt = e.decayAt }
                emitRemoved(c, e.item, e.count, e.metadata, ctx)
            end
        end
    end
    return true, removed
end

function Inv.weight(target)
    local c = Inv.resolve(target)
    if not c then return 0, nil end
    local _, cap, load = Weight.pool(c)
    return load, cap
end
