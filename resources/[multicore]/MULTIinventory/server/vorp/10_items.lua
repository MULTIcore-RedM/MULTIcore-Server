-- ============================================================
-- MULTIinventory :: vorp_inventory face - items (server exports)
-- Signatures follow https://docs.vorp-core.com/api-reference/inventory:
-- every export takes an optional callback and also returns the answer.
-- ============================================================

local V = MULTIVorp
local Items = {}
V.Items = Items

local function reason() return 'vorp:' .. tostring(V.Invoker()) end

-- ------------------------------------------------------------
-- Adding and removing
-- ------------------------------------------------------------

--- addItem(source, item, amount, metadata?, callback?, event?)
--- event = true: do not fire vorp_inventory:Server:OnItemCreated
function Items.addItem(src, name, amount, metadata, cb, event)
    if V.IsCallable(metadata) and cb == nil then cb, metadata = metadata, nil end
    local invId = V.InvOf(src)
    name = V.Norm(name)
    amount = V.Amount(amount, 1)
    if not invId or not name or not amount then return V.Done(cb, false) end
    if not V.FitsCapacity(src, invId, name, amount) then return V.Done(cb, false) end
    local info = V.InfoFrom(metadata)
    local def = V.Def(name)
    if V.IsWeaponDef(def, name) and V.Weapons then
        -- a VORP script handing out a weapon through addItem: make real weapons
        local ok = V.Weapons.giveNew(src, name, amount, info)
        return V.Done(cb, ok)
    end
    local ok = MULTIInv.AddItem(invId, name, amount, info, nil, reason())
    ok = ok == true
    if ok and event ~= true then
        TriggerEvent('vorp_inventory:Server:OnItemCreated', { name = name, count = amount, metadata = info or {} }, V.Src(src))
    end
    return V.Done(cb, ok)
end

--- subItem(source, item, amount, metadata?, callback?, event?, percentage?)
function Items.subItem(src, name, amount, metadata, cb, event, pct)
    if V.IsCallable(metadata) and cb == nil then cb, metadata = metadata, nil end
    local invId = V.InvOf(src)
    name = V.Norm(name)
    amount = V.Amount(amount, 1)
    if not invId or not name or not amount then return V.Done(cb, false) end
    local list = V.Find(invId, name, metadata, pct)
    local ok = V.RemoveFrom(invId, name, amount, list, reason())
    if ok and event ~= true then
        TriggerEvent('vorp_inventory:Server:OnItemRemoved', { name = name, count = amount, metadata = V.IsEmpty(metadata) and {} or metadata }, V.Src(src))
    end
    return V.Done(cb, ok == true)
end

--- subItemById(source, itemId, callback?, event?, amount?)  (amount nil = the whole stack)
function Items.subItemById(src, id, cb, event, amount)
    local invId = V.InvOf(src)
    if not invId then return V.Done(cb, false) end
    local inv, slot, st = V.Resolve(id, invId)
    if not inv or inv ~= invId then return V.Done(cb, false) end
    local have = V.StackAmount(st)
    if amount == nil then amount = have else amount = V.Amount(amount) end
    if not amount or amount > have then return V.Done(cb, false) end
    local ok = MULTIInv.RemoveItem(invId, st.name, amount, slot, nil, reason()) == true
    if ok and event ~= true then
        TriggerEvent('vorp_inventory:Server:OnItemRemoved', { name = st.name, count = amount, metadata = V.CleanMeta(st.info) }, V.Src(src))
    end
    return V.Done(cb, ok)
end

-- ------------------------------------------------------------
-- Reading
-- ------------------------------------------------------------

--- getItemCount(source, callback?, item, metadata?, percentage?)
--- also takes getItemCount(source, item, metadata?) as some scripts call it
function Items.getItemCount(src, cb, name, metadata, pct)
    if type(cb) == 'string' then
        cb, name, metadata, pct = nil, cb, name, metadata
    end
    local invId = V.InvOf(src)
    name = V.Norm(name)
    if not invId or not name then return V.Done(cb, 0) end
    return V.Done(cb, V.CountOf(invId, name, metadata, pct))
end

--- getItem(source, item, callback?, metadata?, percentage?) -> the first matching item or nil
function Items.getItem(src, name, cb, metadata, pct)
    if type(cb) == 'table' and not V.IsCallable(cb) then cb, metadata, pct = nil, cb, metadata end
    local invId = V.InvOf(src)
    name = V.Norm(name)
    if not invId or not name then return V.Done(cb, nil) end
    local e = V.Find(invId, name, metadata, pct)[1]
    return V.Done(cb, e and V.ToItem(invId, e.slot, e.stack) or nil)
end

--- getItemContainingMetadata(source, item, metadata, callback?) -> first stack whose metadata holds these keys
function Items.getItemContainingMetadata(src, name, metadata, cb)
    local invId = V.InvOf(src)
    name = V.Norm(name)
    if not invId or not name then return V.Done(cb, nil) end
    local e = V.Find(invId, name, metadata, nil, 'contains')[1]
    return V.Done(cb, e and V.ToItem(invId, e.slot, e.stack) or nil)
end

--- getItemMatchingMetadata(source, item, metadata, callback?) -> first stack with exactly this metadata
function Items.getItemMatchingMetadata(src, name, metadata, cb)
    local invId = V.InvOf(src)
    name = V.Norm(name)
    if not invId or not name then return V.Done(cb, nil) end
    for _, e in ipairs(V.Find(invId, name, nil, nil)) do
        if V.DeepEqual(V.CleanMeta(e.stack.info), type(metadata) == 'table' and metadata or {}) then
            return V.Done(cb, V.ToItem(invId, e.slot, e.stack))
        end
    end
    return V.Done(cb, nil)
end

--- getItemById(source, id, callback?) / getItemByMainId
function Items.getItemById(src, id, cb)
    local invId = V.InvOf(src)
    if not invId then return V.Done(cb, nil) end
    local inv, slot, st = V.Resolve(id, invId)
    if inv ~= invId then return V.Done(cb, nil) end
    return V.Done(cb, V.ToItem(invId, slot, st))
end

--- getUserInventoryItems(source, callback?) -> list of items (weapons are not items on VORP)
function Items.getUserInventoryItems(src, cb)
    local invId = V.InvOf(src)
    local out = {}
    local inv = invId and V.Get(invId)
    if inv then
        for _, e in ipairs(V.Stacks(inv)) do
            local def = V.Def(e.stack.name)
            if not V.IsWeaponDef(def, e.stack.name) then
                out[#out + 1] = V.ToItem(invId, e.slot, e.stack)
            end
        end
    end
    return V.Done(cb, out)
end

--- getItemDB(item, callback?) -> the item's definition, shaped like a row of VORP's items table
function Items.getItemDB(name, cb)
    name = V.Norm(name)
    local def = name and V.Def(name)
    if not def then return V.Done(cb, nil) end
    local usable = def.usable
    if usable == nil then usable = def.useable end
    local weight = (tonumber(def.weight) or 0) / 1000
    local row = {
        item = def.name or name,
        name = def.name or name,
        label = def.label or name,
        limit = tonumber(def.limit) or 0,
        can_remove = def.canRemove == false and 0 or 1,
        canRemove = def.canRemove ~= false,
        type = def.type == 'weapon' and 'item_weapon' or 'item_standard',
        usable = usable and 1 or 0,
        canUse = usable and true or false,
        weight = weight,
        desc = def.description or def.desc or '',
        description = def.description or def.desc or '',
        metadata = V.Copy(def.metadata or {}),
        groupId = tonumber(def.group) or 1,
        group = tonumber(def.group) or 1,
        image = def.image,
        degradation = def.decay,
    }
    return V.Done(cb, row)
end

-- ------------------------------------------------------------
-- Capacity checks
-- ------------------------------------------------------------

--- canCarryItem(source, item, amount, callback?)
function Items.canCarryItem(src, name, amount, cb)
    local invId = V.InvOf(src)
    name = V.Norm(name)
    amount = V.Amount(amount, 1)
    if not invId or not name or not amount then return V.Done(cb, false) end
    if not V.FitsCapacity(src, invId, name, amount) then return V.Done(cb, false) end
    local ok = MULTIInv.CanAdd(invId, name, amount)
    return V.Done(cb, ok == true)
end

--- canCarryItems(source, amount, callback?) -> room for `amount` more items in invCapacity
function Items.canCarryItems(src, amount, cb)
    local invId = V.InvOf(src)
    amount = V.Amount(amount, 1)
    if not invId or not amount then return V.Done(cb, false) end
    local cap = V.Capacity(src)
    if not cap then return V.Done(cb, true) end
    return V.Done(cb, V.UsedCapacity(invId) + amount <= cap)
end

-- ------------------------------------------------------------
-- Metadata
-- ------------------------------------------------------------

--- setItemMetadata(source, itemId, metadata, amount?, callback?)
--- amount below the stack size splits that many off with the new
--- metadata (they join a stack that already has it); otherwise the
--- whole stack gets it. The engine's own keys (decay clock) are kept.
function Items.setItemMetadata(src, id, metadata, amount, cb)
    if V.IsCallable(amount) and cb == nil then cb, amount = amount, nil end
    local invId = V.InvOf(src)
    if not invId or type(metadata) ~= 'table' then return V.Done(cb, false) end
    local inv, slot, st = V.Resolve(id, invId)
    if inv ~= invId then return V.Done(cb, false) end
    local have = V.StackAmount(st)
    local n = amount == nil and have or V.Amount(amount)
    if not n then return V.Done(cb, false) end
    local info = V.Copy(metadata)
    for k, v in pairs(V.HiddenPart(st.info)) do if info[k] == nil then info[k] = v end end
    if n >= have then
        local ok = MULTIInv.ReplaceInfo(invId, slot, info)
        return V.Done(cb, ok ~= false)
    end
    local name = st.name
    local okRm = MULTIInv.RemoveItem(invId, name, n, slot, nil, reason())
    if okRm ~= true then return V.Done(cb, false) end
    local okAdd = MULTIInv.AddItem(invId, name, n, info, nil, reason())
    if okAdd ~= true then
        -- put them back as they were
        MULTIInv.AddItem(invId, name, n, V.Copy(st.info), slot, reason())
        return V.Done(cb, false)
    end
    return V.Done(cb, true)
end

-- ------------------------------------------------------------
-- Usable items
-- registerUsableItem(item, callback, resourceName?)
-- The callback gets VORP's data: { source, item = { id, name, label,
-- metadata, count, ... } }, and the item fields are copied to the top
-- level too (the docs list them there).
-- ------------------------------------------------------------
local usable = {}      -- name -> { cb, res }
local hooked = {}      -- name -> resource it is registered under with the engine

local function dispatch(name)
    return function(src, stack, invId)
        local h = usable[name]
        if not h then return end
        invId = invId or V.InvOf(src)
        local slot = type(stack) == 'table' and stack.slot
        local live = invId and slot and V.Get(invId)
        live = live and live.items and live.items[slot] or stack
        local item = V.ToItem(invId, slot, type(live) == 'table' and live or stack) or { name = name, metadata = {} }
        local data = { source = src, item = item }
        for k, v in pairs(item) do if data[k] == nil then data[k] = v end end
        TriggerEvent('vorp_inventory:Server:OnItemUse', data)
        local ok, err = pcall(h.cb, data)
        if not ok then V.Warn('usable item "%s" (%s) failed: %s', name, tostring(h.res), tostring(err)) end
    end
end

function Items.registerUsableItem(name, cb, resourceName)
    name = V.Norm(name)
    if not name or not V.IsCallable(cb) then return false end
    local res = resourceName or V.Invoker()
    if usable[name] and usable[name].res ~= res then
        V.Debug('usable item "%s" registered again by %s (was %s)', name, tostring(res), tostring(usable[name].res))
    end
    -- VORP keeps one callback per item: the newest wins
    local old = usable[name]
    if old and old.res ~= res and hooked[name] and type(MULTIInv.UnregisterUsable) == 'function' then
        pcall(MULTIInv.UnregisterUsable, name, hooked[name])
    end
    usable[name] = { cb = cb, res = res }
    -- registered with the engine under the calling resource, so the engine
    -- drops it when that resource stops (one dispatcher per item)
    local ok, err = pcall(MULTIInv.RegisterUsable, name, dispatch(name), { face = 'vorp', resource = res })
    if not ok then V.Warn('RegisterUsable(%s) failed: %s', name, tostring(err)) return false end
    hooked[name] = res
    return true
end

function Items.unRegisterUsableItem(name)
    name = V.Norm(name)
    if not name then return false end
    usable[name] = nil
    if hooked[name] and MULTIInv and type(MULTIInv.UnregisterUsable) == 'function' then
        pcall(MULTIInv.UnregisterUsable, name, hooked[name])
    end
    hooked[name] = nil
    return true
end

function Items.isUsable(name)
    return usable[V.Norm(name) or ''] ~= nil
end

-- a stopped resource takes its usable items with it
AddEventHandler('onResourceStop', function(res)
    for name, h in pairs(usable) do
        if h.res == res then Items.unRegisterUsableItem(name) end
    end
end)

-- ------------------------------------------------------------
-- Exports
-- ------------------------------------------------------------
V.Export('addItem', Items.addItem)
V.Export('subItem', Items.subItem)
V.Export('subItemById', Items.subItemById)
V.Export('subItemID', Items.subItemById)              -- the name before VORP 3.9
V.Export('getItemCount', Items.getItemCount)
V.Export('getItem', Items.getItem)
V.Export('getItemByName', function(src, name, cb, metadata) return Items.getItem(src, name, cb, metadata) end)
V.Export('getItemContainingMetadata', Items.getItemContainingMetadata)
V.Export('getItemMatchingMetadata', Items.getItemMatchingMetadata)
V.Export('getItemById', Items.getItemById)
V.Export('getItemByMainId', Items.getItemById)
V.Export('getUserInventoryItems', Items.getUserInventoryItems)
V.Export('getUserInventory', Items.getUserInventoryItems)
V.Export('getItemDB', Items.getItemDB)
V.Export('canCarryItem', Items.canCarryItem)
V.Export('canCarryItems', Items.canCarryItems)
V.Export('setItemMetadata', Items.setItemMetadata)
V.Export('registerUsableItem', Items.registerUsableItem)
V.Export('unRegisterUsableItem', Items.unRegisterUsableItem)

-- for the client face
if lib and lib.callback then
    lib.callback.register('MULTIinventory:vorp:items', function(src)
        return Items.getUserInventoryItems(src)
    end)
    lib.callback.register('MULTIinventory:vorp:itemDB', function(_, names)
        if type(names) == 'table' then
            local out = {}
            for _, n in pairs(names) do
                if type(n) == 'string' then out[n] = Items.getItemDB(n) end
            end
            return out
        end
        return Items.getItemDB(names)
    end)
end
