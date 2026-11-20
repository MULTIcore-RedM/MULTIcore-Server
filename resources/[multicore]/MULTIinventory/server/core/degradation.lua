-- ============================================================
-- MULTIinventory :: server/core/degradation.lua
--
-- Expiry: stack.decayAt = created + items.degradation minutes (set when the
-- stack is created, kept on moves; merges keep the earlier expiry).
-- percentage (UI/API) = remaining / total * 100 (Sync.percentage).
-- Durability: metadata.durability 0..100 lowered by use handlers / wear;
-- 0 = broken (Usables refuses). Degradation.wear() is the helper for parts.
--
-- Tick (Config.Degradation.tickSeconds):
--   * containers with flags.freeze (and non-player containers when
--     Config.Degradation.onlyInPlayerInventory) push decayAt forward while loaded
--   * Config.Degradation.removeWhenExpired = true -> expired stacks are removed (logged 'expired')
--
--   Degradation.tick(elapsed)
--   Degradation.wear(target, stackId, amount, ctx) -> ok, newDurability
-- ============================================================

Degradation = Degradation or {}

local function frozen(c)
    if c.flags and c.flags.freeze then return true end
    if Config.Degradation.onlyInPlayerInventory and c.kind ~= 'player' then return true end
    return false
end

function Degradation.tick(elapsed)
    if not Config.Degradation.enabled then return end
    local now = Util.now()
    Containers.each(function(c)
        local isFrozen = frozen(c)
        local expired = {}
        for slot, e in pairs(c.stacks) do
            if e.decayAt then
                if isFrozen then
                    e.decayAt = e.decayAt + elapsed
                    c.dirty = true
                    Persistence.markDirty(c)
                elseif Config.Degradation.removeWhenExpired and e.decayAt <= now then
                    expired[#expired + 1] = slot
                end
            end
        end
        for _, slot in ipairs(expired) do
            local e = c.stacks[slot]
            local ok, removed = Inv.removeStack(c, e.id, nil, { reason = 'expire' })
            if ok then
                InvLog.write('expired', { actor = 'system', from = c.id, item = e.item, count = removed[1].count,
                                          targetCharId = c.ownerCharId, data = { stacks = removed } })
            end
        end
    end)
end

function Degradation.wear(target, stackId, amount, ctx)
    local c = Inv.resolve(target)
    if not c then return false, 'unknown_container' end
    stackId = math.tointeger(tonumber(stackId))
    local e
    for _, x in pairs(c.stacks) do if x.id == stackId then e = x break end end
    if not e or e.kind == 'weapon' then return false, 'no_item' end
    local meta = Util.deepcopy(e.metadata)
    local cur = tonumber(meta.durability) or tonumber(Inv.def(e.item).durability) or 100
    meta.durability = Util.clamp(cur - (tonumber(amount) or 1), 0, 100)
    -- wear one piece out of a stack: it splits off with its own durability
    local ok, newId = Inv.setMetadata(c, e.id, meta, e.count > 1 and 1 or nil, ctx)
    if not ok then return false, newId end
    return true, meta.durability, newId
end
