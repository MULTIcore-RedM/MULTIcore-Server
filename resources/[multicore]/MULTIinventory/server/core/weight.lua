-- ============================================================
-- MULTIinventory :: server/core/weight.lua
--
-- Weight model. A player's grid and equipment share one "weight pool" whose
-- capacity is the character's framework capacity (VORP invCapacity =
-- characters.slots, 150 kg here; fallback Config.Player.defaultMaxWeight).
-- Worn clothing (equip:<charid>) is NOT counted unless
-- Config.Player.wornClothingCountsWeight = true. Other containers have their
-- own pool with c.maxWeight (nil = slot-limited only).
--
--   Weight.unit(def, meta) -> kg per unit (metadata.weight overrides items.weight)
--   Weight.ofEntry(e) -> kg            Weight.ofContainer(c) -> kg
--   Weight.pool(c) -> key, capacity|nil, load
--   Weight.capacity(charId) -> kg
--   Weight.itemTotal(c, item) -> n     Weight.itemLimit(c, def) -> n|nil
--   Weight.canFit(c, def, count, meta, opts) -> ok, 'weight'|'limit'
--       opts.samePool = key  (moves inside one pool skip the weight check)
--       opts.freeKg   = kg   (weight that leaves the pool in the same operation, swaps)
--   Weight.maxAddable(c, def, meta) -> n (math.huge when unlimited)
-- ============================================================

Weight = Weight or {}

local EPS = 1e-6

function Weight.unit(def, meta)
    local mw = type(meta) == 'table' and tonumber(meta.weight) or nil
    if mw and mw >= 0 then return mw end
    return def and tonumber(def.weight) or 0.0
end

function Weight.ofEntry(e)
    if e.kind == 'weapon' then return (tonumber(e.weight) or 0) * (e.count or 1) end
    return Weight.unit(Registry.get(e.item), e.metadata) * e.count
end

function Weight.ofContainer(c)
    local w = 0.0
    for _, e in pairs(c.stacks) do w = w + Weight.ofEntry(e) end
    return w
end

function Weight.capacity(charId)
    local cap = InvHooks.first('capacity', charId)
    if cap then return cap end
    cap = State and State.capacityOf and State.capacityOf(charId)
    return tonumber(cap) or Config.Player.defaultMaxWeight
end

local function wornCounts() return Config.Player.wornClothingCountsWeight == true end

function Weight.pool(c)
    if c.kind == 'player' or (c.kind == 'equip' and wornCounts()) then
        local cid = c.ownerCharId
        local p = Containers.peek('player:' .. cid)
        local e = Containers.peek('equip:' .. cid)
        local load = (p and Weight.ofContainer(p) or 0) + ((wornCounts() and e) and Weight.ofContainer(e) or 0)
        return 'char:' .. tostring(cid), Weight.capacity(cid), load
    end
    return c.id, c.maxWeight, Weight.ofContainer(c)
end

function Weight.itemTotal(c, item)
    local n = 0
    for _, e in pairs(c.stacks) do
        if e.item == item and e.kind ~= 'weapon' then n = n + e.count end
    end
    return n
end

---Max total of one item a container may hold (nil = unlimited).
function Weight.itemLimit(c, def)
    if not def or Config.Stacking.limitIsPerStack then return nil end
    local lim = tonumber(def.limit) or 0
    if lim <= 0 then return nil end
    if c.kind == 'player' then return lim end
    if c.kind == 'equip' or c.kind == 'drop' then return nil end
    if c.flags and c.flags.ignoreItemStackLimit then return nil end
    return lim
end

function Weight.canFit(c, def, count, meta, opts)
    opts = opts or {}
    local lim = Weight.itemLimit(c, def)
    if lim and not opts.ignoreLimit and Weight.itemTotal(c, def.name) - (opts.freeCount or 0) + count > lim then
        return false, 'limit'
    end
    local key, cap, load = Weight.pool(c)
    if cap and opts.samePool ~= key and not opts.ignoreWeight then
        local add = Weight.unit(def, meta) * count
        if add > 0 and load - (opts.freeKg or 0) + add > cap + EPS then return false, 'weight' end
    end
    return true
end

function Weight.maxAddable(c, def, meta)
    local n = math.huge
    local lim = Weight.itemLimit(c, def)
    if lim then n = math.max(0, lim - Weight.itemTotal(c, def.name)) end
    local _, cap, load = Weight.pool(c)
    local u = Weight.unit(def, meta)
    if cap and u > 0 then
        n = math.min(n, math.max(0, math.floor((cap - load + EPS) / u)))
    end
    return n
end
