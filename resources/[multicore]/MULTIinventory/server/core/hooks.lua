-- ============================================================
-- MULTIinventory :: server/core/hooks.lua
--
-- In-resource extension points for the other parts (secondary, weapons,
-- clothing, compat, rsg). Not exported - parts live in this resource.
--
--   local id = InvHooks.register(name, fn)    InvHooks.remove(id)
--   InvHooks.check(name, ...) -> ok, err      every fn may veto: return false, 'reason'
--   InvHooks.emit(name, ...)                  notifications (errors are caught + printed)
--   InvHooks.first(name, ...) -> value        first non-nil result (providers)
--
-- Hook names (args):
--   canAdd(container, item, count, meta, ctx)     veto adding into a container (whitelists, perms)
--   canRemove(container, entry, count, ctx)       veto taking out of a container (perms, robbery)
--   canPlace(container, slot, entry, ctx)         veto a specific slot (equipment rules)
--   canOpen(src, container, opts)                 veto opening a secondary
--   containerLoaded(container) / containerUnloaded(container)
--   containerChanged(container, slots)            after any mutation (slots = { [slot]=true })
--   itemAdded(container, item, count, meta, ctx) / itemRemoved(container, item, count, meta, ctx)
--   itemUsed(src, itemTable, ctx)                 after a successful use (compat forwards to
--                                                 vorp_inventory:Server:OnItemUse)
--   occupantMoved(fromC, toC, entry, ctx)         a non-stack occupant (weapon) changed container/slot
--   occupantRemoved(container, entry, ctx)        a non-stack occupant was deleted (clear/expiry)
--   hotbarWeapon(src, weaponId, entry)            hotbar key on a weapon
--   characterLoaded(src, charId) / characterUnloaded(src, charId)
--   openPayload(src, payload)                     parts add fields to the NUI open message
--   capacity(charId, src) -> kg|nil               provider
-- ctx = { src = acting player or nil, reason = 'api'|'move'|'give'|'drop'|'pickup'|'admin'|
--         'use'|'sort'|'split'|'expire'|'death', from = containerId, to = containerId }
-- ============================================================

InvHooks = InvHooks or {}

local lists, byId, nextId = {}, {}, 0

function InvHooks.register(name, fn)
    assert(type(name) == 'string', 'hook name')
    nextId = nextId + 1
    lists[name] = lists[name] or {}
    local e = { id = nextId, fn = fn }
    table.insert(lists[name], e)
    byId[nextId] = name
    return nextId
end

---Like register, but the hook runs before the ones already registered.
function InvHooks.prepend(name, fn)
    assert(type(name) == 'string', 'hook name')
    nextId = nextId + 1
    lists[name] = lists[name] or {}
    table.insert(lists[name], 1, { id = nextId, fn = fn })
    byId[nextId] = name
    return nextId
end

function InvHooks.remove(id)
    local name = byId[id]
    if not name then return false end
    byId[id] = nil
    for i, e in ipairs(lists[name]) do
        if e.id == id then table.remove(lists[name], i) return true end
    end
    return false
end

function InvHooks.has(name)
    return lists[name] ~= nil and #lists[name] > 0
end

function InvHooks.check(name, ...)
    local l = lists[name]
    if not l then return true end
    for _, e in ipairs(l) do
        local ok, res, err = pcall(e.fn, ...)
        if not ok then
            print(('^1[MULTIinventory] hook %s failed: %s^7'):format(name, tostring(res)))
            return false, 'hook_error'
        end
        if res == false then return false, err or 'denied' end
    end
    return true
end

function InvHooks.emit(name, ...)
    local l = lists[name]
    if not l then return end
    for _, e in ipairs(l) do
        local ok, err = pcall(e.fn, ...)
        if not ok then print(('^1[MULTIinventory] hook %s failed: %s^7'):format(name, tostring(err))) end
    end
end

function InvHooks.first(name, ...)
    local l = lists[name]
    if not l then return nil end
    for _, e in ipairs(l) do
        local ok, res = pcall(e.fn, ...)
        if ok and res ~= nil then return res end
    end
    return nil
end
