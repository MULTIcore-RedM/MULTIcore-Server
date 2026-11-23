-- ============================================================
-- MULTIinventory :: server/core/usables.lua
--
--   Usables.register(name, fn, ownerResource, opts) -> true
--       opts.builtin = true  : a fallback that runs only when no other handler takes the item
--       opts.style   = 'multi': fn(src, stack, invId) (MULTIinventory export API shape)
--                     default: fn({ source = src, item = itemTable })
--       A later registration by the same owner (same builtin flag) replaces the earlier one;
--       registrations of different resources all run.
--   Usables.unregister(name, owner|nil)    nil owner = every handler of that item
--   Usables.isRegistered(name) -> bool     (also true for items with an rsg-core usable)
--   Usables.use(src, containerId, slot, ctx) -> ok, err
--   Usables.useByName(src, name, stack|nil, ctx) -> ok, err   (no slot: RSG UseItem(name) style)
--   Usables.rsgCallback(name) -> callable|nil   provider set by server/rsg/rsg_api.lua
--
-- Order for one use: the rsg-core usable (RSGCore.Functions.CreateUseableItem) and every
-- non-builtin handler run; built-in handlers run only when none of those exist; with nothing
-- at all a usable item fires RedEM:RP's 'RegisterUsableItem:<name>' (Config.Redem.UsableEvents).
-- After a successful use:
--   TriggerEvent('MULTIinventory:itemUsed', src, itemTable)   (server-local)
--   InvHooks.emit('itemUsed', src, itemTable, ctx)             (vorp face fires vorp_inventory:Server:OnItemUse)
-- Registrations of a resource are dropped when that resource stops.
-- Refusals: not_usable, expired (unless items.useExpired / metadata.useExpired), broken
-- (metadata.durability <= 0), cooldown (UI uses only), handler_error.
-- ============================================================

Usables = Usables or {}

local handlers = {}   -- [name] = { { fn, owner, builtin, style }, ... }
local lastUse = {}    -- [src] = ms
local BRIDGE_OWNER = GetCurrentResourceName() .. ':rsg'   -- rsg_api's generic dispatcher

function Usables.register(name, fn, owner, opts)
    if type(name) ~= 'string' or name == '' then return false end
    if fn == nil then return false end
    -- another developer's spelling of an item we have: the use lands on that item
    if Registry and Registry.resolve then name = Registry.resolve(name) end
    opts = type(opts) == 'table' and opts or {}
    local builtin = opts.builtin == true
    local list = handlers[name] or {}
    for i = #list, 1, -1 do
        if list[i].owner == owner and list[i].builtin == builtin then table.remove(list, i) end
    end
    list[#list + 1] = { fn = fn, owner = owner, builtin = builtin, style = opts.style }
    handlers[name] = list
    return true
end

function Usables.unregister(name, owner)
    if type(name) == 'string' and Registry and Registry.resolve then name = Registry.resolve(name) end
    local list = handlers[name]
    if not list then return true end
    for i = #list, 1, -1 do
        if owner == nil or list[i].owner == owner then table.remove(list, i) end
    end
    if #list == 0 then handlers[name] = nil end
    return true
end

---Provider: the rsg-core usable callback of an item (replaced by server/rsg/rsg_api.lua).
function Usables.rsgCallback(_name) return nil end

local function realHandlers(name)
    local list = handlers[name]
    if not list then return false end
    for _, h in ipairs(list) do
        if h.owner ~= BRIDGE_OWNER then return true end
    end
    return false
end

function Usables.isRegistered(name)
    if type(name) ~= 'string' then return false end
    if realHandlers(name) then return true end
    return Usables.rsgCallback(name) ~= nil
end

---First owner per item (non-builtin first), for the rsg bridge's "is it taken" check.
function Usables.owners()
    local out = {}
    for k, list in pairs(handlers) do
        for _, h in ipairs(list) do
            if not h.builtin then out[k] = h.owner break end
        end
        if out[k] == nil and list[1] then out[k] = list[1].owner end
    end
    return out
end

local function nowMs()
    return GetGameTimer and GetGameTimer() or math.floor(os.clock() * 1000)
end

---The stack in the MULTIinventory export shape { name, amount, info, slot, label, ... }.
local function multiStack(itemTable, c)
    if MultiInv and MultiInv.stackOfTable then return MultiInv.stackOfTable(itemTable, c) end
    return { name = itemTable.name, amount = itemTable.count, info = Util.deepcopy(itemTable.metadata or {}),
             slot = itemTable.slot, label = itemTable.label }
end

---Runs the handlers of one item. -> ok, err
local function run(src, name, itemTable, c, invId)
    local list = handlers[name] or {}
    local external, builtin = {}, {}
    for _, h in ipairs(list) do
        if h.owner ~= BRIDGE_OWNER then
            if h.builtin then builtin[#builtin + 1] = h else external[#external + 1] = h end
        end
    end
    local rsgCb = Usables.rsgCallback(name)
    local chosen = (#external > 0 or rsgCb) and external or builtin
    if not rsgCb and #chosen == 0 then return false, 'not_usable' end
    if rsgCb then
        local ok, err = pcall(rsgCb, src, multiStack(itemTable, c))
        if not ok then print(('^1[MULTIinventory] usable %s (rsg-core) failed: %s^7'):format(name, tostring(err))) end
    end
    local failed = 0
    for _, h in ipairs(chosen) do
        local ok, err
        if h.style == 'multi' then
            ok, err = pcall(h.fn, src, multiStack(itemTable, c), invId)
        else
            ok, err = pcall(h.fn, { source = src, item = itemTable })
        end
        if not ok then
            failed = failed + 1
            print(('^1[MULTIinventory] usable %s (%s) failed: %s^7'):format(name, tostring(h.owner), tostring(err)))
        end
    end
    if failed > 0 and failed == #chosen and not rsgCb then return false, 'handler_error' end
    return true
end

---RedEM:RP scripts listen for 'RegisterUsableItem:<name>' (items marked usable, no other handler).
local function redemFallback(src, name, itemTable)
    if Config.Redem and Config.Redem.UsableEvents == false then return false end
    local def = Registry.get(name)
    if not def or not def.usable then return false end
    local data = { name = name, amount = itemTable.count, meta = Util.deepcopy(itemTable.metadata or {}),
                   label = itemTable.label, slot = itemTable.slot }
    TriggerEvent('RegisterUsableItem:' .. name, src, data)
    if name ~= name:upper() then TriggerEvent('RegisterUsableItem:' .. name:upper(), src, data) end
    return true
end

local function finish(src, itemTable, ctx)
    TriggerEvent('MULTIinventory:itemUsed', src, itemTable)
    InvHooks.emit('itemUsed', src, itemTable, ctx)
end

function Usables.use(src, containerId, slot, ctx)
    ctx = ctx or { src = src, reason = 'use' }
    local c = Containers.peek(containerId)
    if not c then return false, 'unknown_container' end
    local e = c.stacks[slot]
    if not e or e.kind == 'weapon' then return false, 'no_item' end
    if Money and Money.isMoney and Money.isMoney(e.item) then return false, 'not_usable' end   -- cash is never "used"
    local def = Inv.def(e.item)
    if Sync.isExpired(e) and not (def.useExpired or Util.tbool(e.metadata.useExpired)) then
        return false, 'expired'
    end
    local dur = tonumber(e.metadata.durability)
    if dur and dur <= 0 then return false, 'broken' end
    if not ctx.api then
        local t = nowMs()
        local cd = Config.Actions.useCooldownMs or 0
        if src and lastUse[src] and t - lastUse[src] < cd then return false, 'cooldown' end
        if src then lastUse[src] = t end
    end
    local itemTable = Sync.itemTable(e, c)
    local ok, err = run(src, e.item, itemTable, c, c.id)
    if not ok then
        if err == 'not_usable' and redemFallback(src, e.item, itemTable) then
            finish(src, itemTable, ctx)
            return true
        end
        return false, err
    end
    finish(src, itemTable, ctx)
    return true
end

---Runs the handlers of an item by name (no slot). stack = { name, amount, info, slot } or nil.
function Usables.useByName(src, name, stack, ctx)
    if type(name) ~= 'string' or name == '' then return false, 'not_usable' end
    ctx = ctx or { src = src, reason = 'use', api = true }
    stack = type(stack) == 'table' and stack or {}
    local c, e
    local slot = tonumber(stack.slot)
    local st = src and State.get(src)
    if st then
        c = Containers.peek('player:' .. st.charId)
        e = c and slot and c.stacks[slot] or nil
        if e and tostring(e.item):lower() ~= name:lower() then e = nil end
    end
    local itemTable
    if e and e.kind ~= 'weapon' then
        itemTable = Sync.itemTable(e, c)
    else
        local d = Registry.get(name) or {}
        local n = tonumber(stack.amount or stack.count) or 1
        itemTable = { name = name, item = name, label = stack.label or d.label or name, count = n, amount = n,
                      metadata = Util.deepcopy(stack.info or stack.metadata or {}), slot = slot,
                      container = c and c.id or nil, weight = d.weight, type = d.type }
    end
    local ok, err = run(src, name, itemTable, c, c and c.id or nil)
    if not ok then
        if err == 'not_usable' and redemFallback(src, name, itemTable) then
            finish(src, itemTable, ctx)
            return true
        end
        return false, err
    end
    finish(src, itemTable, ctx)
    return true
end

AddEventHandler('onResourceStop', function(res)
    for name, list in pairs(handlers) do
        for i = #list, 1, -1 do if list[i].owner == res then table.remove(list, i) end end
        if #list == 0 then handlers[name] = nil end
    end
end)

AddEventHandler('playerDropped', function()
    lastUse[source] = nil
end)
