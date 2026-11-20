-- ============================================================
-- MULTIinventory :: server/core/sync.lua
--
-- Serialisation + client push (NUI message contract,.
-- The server pushes only changed slots ("delta"), batched every 100 ms.
--
--   Sync.itemTable(e, c) -> API item table (compat-style fields, see
--   Sync.entryView(e)    -> UI tile view
--   Sync.containerView(c) -> { id, kind, label, slots, weight, maxWeight, items = { view, ... } }
--   Sync.queue(c, slot)   Sync.flush()   Sync.viewers(c) -> { src, ... }
--   Sync.sendFull(src)    (player + equipment + hotbar cache, no UI open)
--   Sync.notify(src, text, kind)
-- Client events: MULTIinventory:cl:sync, :cl:delta, :cl:open, :cl:close, :cl:notify, :cl:result
-- ============================================================

Sync = Sync or {}

local pending = {}   -- [containerId] = { c = c, slots = { [slot] = true } }

function Sync.percentage(e, def)
    if not e.decayAt or not def or (def.degradation or 0) <= 0 then return nil end
    local total = def.degradation * 60
    local left = e.decayAt - Util.now()
    return Util.round(Util.clamp(left / total * 100, 0, 100), 1)
end

function Sync.isExpired(e)
    return e.decayAt ~= nil and e.decayAt <= Util.now()
end

function Sync.itemTable(e, c)
    if e.kind == 'weapon' then
        return { id = e.weaponId, weaponId = e.weaponId, kind = 'weapon', name = e.item, label = e.label or e.item,
                 count = 1, metadata = e.metadata or {}, slot = e.slot, container = c and c.id, weight = e.weight or 0 }
    end
    local d = Registry.get(e.item) or {}
    local m = e.metadata or {}
    return {
        id = e.id,
        name = e.item,
        item = e.item,
        label = m.label or d.label or e.item,
        count = e.count,
        amount = e.count,
        metadata = Util.deepcopy(m),
        limit = d.limit,
        weight = Weight.unit(d, m),
        desc = m.description or d.desc,
        description = m.description or d.desc,
        group = d.groupId,
        groupName = d.group,
        type = d.type,
        canUse = d.usable or Usables.isRegistered(e.item),
        canRemove = d.canRemove,
        rarity = d.rarity,
        percentage = Sync.percentage(e, d),
        decayAt = e.decayAt,
        expired = Sync.isExpired(e),
        createdAt = e.createdAt,
        slot = e.slot,
        container = c and c.id,
        image = m.image or d.image or (e.item .. '.png'),
    }
end

function Sync.entryView(e)
    local t = Sync.itemTable(e)
    t.container = nil
    return t
end

function Sync.containerView(c)
    local items = {}
    for _, e in pairs(c.stacks) do items[#items + 1] = Sync.entryView(e) end
    table.sort(items, function(a, b) return a.slot < b.slot end)
    local _, cap, load = Weight.pool(c)
    return { id = c.id, kind = c.kind, label = c.label, slots = c.slots,
             weight = Util.round(load, 2), maxWeight = cap, items = items }
end

function Sync.viewers(c)
    local out, seen = {}, {}
    if (c.kind == 'player' or c.kind == 'equip') and c.ownerCharId then
        local src = State.srcOfChar(c.ownerCharId)
        if src then out[#out + 1] = src; seen[src] = true end
    end
    for src in pairs(State.viewersOf(c.id)) do
        if not seen[src] then out[#out + 1] = src; seen[src] = true end
    end
    return out
end

function Sync.queue(c, slot)
    local p = pending[c.id]
    if not p then p = { c = c, slots = {} }; pending[c.id] = p end
    if slot then p.slots[slot] = true end
end

function Sync.flush()
    if next(pending) == nil then return end
    local batch = pending
    pending = {}
    for id, p in pairs(batch) do
        local c = p.c
        local changed = c.changed or {}
        c.changed = {}
        InvHooks.emit('containerChanged', c, changed)
        local viewers = Sync.viewers(c)
        if #viewers > 0 then
            local slots = {}
            for slot in pairs(p.slots) do
                local e = c.stacks[slot]
                slots[#slots + 1] = { slot = slot, item = e and Sync.entryView(e) or false }
            end
            table.sort(slots, function(a, b) return a.slot < b.slot end)
            local _, cap, load = Weight.pool(c)
            local msg = { container = id, kind = c.kind, slots = slots, weight = Util.round(load, 2), maxWeight = cap }
            for _, src in ipairs(viewers) do
                TriggerClientEvent('MULTIinventory:cl:delta', src, msg)
            end
        end
    end
end

function Sync.sendFull(src)
    local st = State.get(src)
    if not st then return end
    local p = Containers.peek('player:' .. st.charId)
    local e = Containers.peek('equip:' .. st.charId)
    TriggerClientEvent('MULTIinventory:cl:sync', src, {
        charId = st.charId,
        player = p and Sync.containerView(p) or nil,
        equipment = e and Sync.containerView(e) or nil,
        hotbar = Hotbar.view(st.charId),
    })
end

function Sync.notify(src, text, kind)
    if not src or src == 0 then print('[MULTIinventory] ' .. tostring(text)) return end
    TriggerClientEvent('MULTIinventory:cl:notify', src, { text = text, type = kind or 'inform' })
end

CreateThread(function()
    while true do
        Wait(100)
        local ok, err = pcall(Sync.flush)
        if not ok then print('^1[MULTIinventory] sync: ' .. tostring(err) .. '^7') end
    end
end)
