-- ============================================================
-- MULTIinventory :: vorp_inventory face - custom inventories (server)
-- A VORP custom inventory is a MULTIinventory inventory:
--   shared = true  -> 'custom:<id>'
--   shared = false -> 'custom:<id>:<charIdentifier>' (one per character)
-- VORP's `limit` (total item count) becomes the inventory's maxCount.
-- Rules VORP scripts set (job / character permissions, black list,
-- white list with per-item limits, no weapons) are given to the
-- engine as hooks on the inventory table:
--   inv.canPut(src, name, amount, info)  -> true / false
--   inv.canTake(src, name, amount, info) -> true / false
--   inv.onPut(src, name, amount, info) / inv.onTake(src, name, amount, info)
--   inv.ignoreItemLimit (VORP ignoreItemStackLimit)
-- ============================================================

local V = MULTIVorp
local C = {}
V.Customs = C

local defs = {}       -- VORP id -> settings
local instances = {}  -- VORP id -> { [invId] = true } (inventories made this session)

local function reason() return 'vorp:' .. tostring(V.Invoker()) end

local function bool(v, default)
    if v == nil then return default end
    return v and true or false
end

--- 'custom:<id>' or 'custom:<id>:<charid>' -> VORP id (for weapon currInv and events)
function C.NameOf(invId)
    if type(invId) ~= 'string' then return nil end
    local rest = invId:match('^custom:(.+)$')
    if not rest then return nil end
    if defs[rest] then return rest end
    local base = rest:match('^(.+):[^:]+$')
    if base and defs[base] then return base end
    return rest
end

function C.InvIdFor(id, charid)
    local d = defs[id]
    if d and not d.shared and charid ~= nil then return ('custom:%s:%s'):format(id, tostring(charid)) end
    return 'custom:' .. tostring(id)
end

--- the inventories a call without a character id acts on
local function targets(id)
    local d = defs[id]
    if not d or d.shared then return { C.InvIdFor(id) } end
    local out = {}
    for invId in pairs(instances[id] or {}) do out[#out + 1] = invId end
    table.sort(out)
    if #out == 0 then out[1] = C.InvIdFor(id) end
    return out
end

-- ------------------------------------------------------------
-- Rules
-- ------------------------------------------------------------
local function jobAllowed(list, src)
    local job, grade = V.Job(src)
    if not job then return false end
    local need = list[job]
    return need ~= nil and grade >= (tonumber(need) or 0)
end

local function permitted(d, src, kind)
    if not d.UsePermissions then return true end
    local jobs = kind == 'move' and d.permMove or d.permTake
    local chars = kind == 'move' and d.charMove or d.charTake
    if next(jobs) == nil and next(chars) == nil then return true end
    local cid = V.CharId(src)
    if cid ~= nil and chars[tonumber(cid) or cid] then return true end
    return jobAllowed(jobs, src)
end

local function countIn(invId, name)
    return V.CountOf(invId, name)
end

local function canPut(id, invId, src, name, amount)
    local d = defs[id]
    if not d then return true end
    amount = tonumber(amount) or 1
    local isWeapon = V.IsWeaponDef(V.Def(name), name)
    if isWeapon and not d.acceptWeapons then return false end
    if d.UseBlackList and (d.blacklist[name] or d.blacklist[name:upper()]) then return false end
    if isWeapon and d.whitelistWeapons then
        local lim = d.weaponLimits[name]
        if not lim or countIn(invId, name) + amount > lim then return false end
    elseif not isWeapon and d.whitelistItems then
        local lim = d.itemLimits[name]
        if not lim or countIn(invId, name) + amount > lim then return false end
    end
    if src and not permitted(d, src, 'move') then return false end
    return true
end

local function canTake(id, src)
    local d = defs[id]
    if not d or not src then return true end
    return permitted(d, src, 'take')
end

local function webhook(d, text)
    if type(d.webhook) ~= 'string' or not d.webhook:find('^https://') then return end
    PerformHttpRequest(d.webhook, function() end, 'POST', json.encode({
        username = 'MULTIinventory',
        embeds = { { title = d.name, description = text, color = 4777493 } },
    }), { ['Content-Type'] = 'application/json' })
end

local function playerName(src)
    return GetPlayerName and GetPlayerName(src) or tostring(src)
end

local function hook(id, invId, inv)
    inv.vorpCustom = id
    inv.canPut = function(src, name, amount)
        return canPut(id, invId, src, name, amount)
    end
    inv.canTake = function(src)
        return canTake(id, src)
    end
    inv.onPut = function(src, name, amount, info)
        local item = { name = name, amount = amount, count = amount, metadata = V.CleanMeta(info), id = nil }
        TriggerEvent('vorp_inventory:Server:OnItemMovedToCustomInventory', item, id, src)
        local d = defs[id]
        if d then webhook(d, V.T('vorp_webhook_put', '%s put %sx %s in %s', playerName(src), amount, name, d.name)) end
    end
    inv.onTake = function(src, name, amount, info)
        local item = { name = name, amount = amount, count = amount, metadata = V.CleanMeta(info), id = nil }
        TriggerEvent('vorp_inventory:Server:OnItemTakenFromCustomInventory', item, id, src)
        local d = defs[id]
        if d then webhook(d, V.T('vorp_webhook_take', '%s took %sx %s from %s', playerName(src), amount, name, d.name)) end
    end
    local d = defs[id]
    inv.ignoreItemLimit = d and d.ignoreItemStackLimit or nil
end

--- the engine spec of one custom inventory
local function spec(id, invId)
    local d = defs[id]
    local slots = math.floor(tonumber(V.Cfg('CustomInventorySlots', 50)) or 50)
    local maxWeight = tonumber(V.Cfg('CustomInventoryMaxWeight', 1000000000)) or 1000000000
    if d and d.useWeight and tonumber(d.weight) then maxWeight = math.floor(tonumber(d.weight) * 1000) end
    return {
        id = invId,
        label = d and d.name or tostring(id),
        slots = slots,
        maxWeight = maxWeight,
        maxCount = d and d.limit or nil,
        type = 'custom',
        vorp = true,
    }
end

--- The engine's own limit fields for a VORP custom inventory
--- (Inv.Create / Inv.Configure: whitelist, blacklist, itemLimits, acceptWeapons, ignoreItemLimits).
local function engineRules(d)
    local r = { acceptWeapons = d.acceptWeapons, ignoreItemLimits = d.ignoreItemStackLimit }
    local limits = {}
    for n, l in pairs(d.itemLimits) do limits[n] = l end
    for n, l in pairs(d.weaponLimits) do limits[n] = l end
    r.itemLimits = limits
    if d.whitelistItems or d.whitelistWeapons then
        -- the engine's white list covers every item: let through the side VORP does not list
        local wl = {}
        local items = MULTIInv and MULTIInv.Items or {}
        for n, def in pairs(items) do
            local isW = V.IsWeaponDef(def, n)
            if isW and not d.whitelistWeapons then wl[n] = true end
            if not isW and not d.whitelistItems then wl[n] = true end
        end
        if d.whitelistItems then for n in pairs(d.itemLimits) do wl[n] = true end end
        if d.whitelistWeapons then for n in pairs(d.weaponLimits) do wl[n] = true end end
        r.whitelist = wl
    else
        r.whitelist = false
    end
    if d.UseBlackList and next(d.blacklist) then
        local bl = {}
        for n in pairs(d.blacklist) do bl[n:lower()] = true end
        r.blacklist = bl
    else
        r.blacklist = false
    end
    return r
end

--- makes sure the engine knows the inventory; returns invId, inv
function C.Ensure(id, charid)
    local invId = C.InvIdFor(id, charid)
    local s = spec(id, invId)
    local E = MULTIInv
    if not E then return invId, nil end
    local d = defs[id]
    local data = { label = s.label, maxCount = s.maxCount and s.maxCount > 0 and s.maxCount or false }
    if d and d.useWeight then data.maxWeight = s.maxWeight end
    if d then
        for k, v in pairs(engineRules(d)) do data[k] = v end
    end
    local inv = type(E.Exists) == 'function' and E.Exists(invId) or nil
    if inv then
        if type(E.Configure) == 'function' then E.Configure(invId, data) end
    elseif type(E.Create) == 'function' then
        data.slots, data.maxWeight = s.slots, data.maxWeight or s.maxWeight
        inv = E.Create(invId, data)
    else
        inv = V.Get(invId)
    end
    if not inv then return invId, nil end
    -- false above means "none": the engine's fields take nil for that
    if inv.maxCount == false or data.maxCount == false then inv.maxCount = nil end
    if inv.whitelist == false then inv.whitelist = nil end
    if inv.blacklist == false then inv.blacklist = nil end
    if d then hook(id, invId, inv) end
    instances[id] = instances[id] or {}
    instances[id][invId] = true
    return invId, inv
end

--- re-applies the rules to every copy of a custom inventory made this session
local function reapply(id)
    for invId in pairs(instances[id] or {}) do
        local charid = invId:match('^custom:.+:([^:]+)$')
        if defs[id] and not defs[id].shared and charid then C.Ensure(id, charid) else C.Ensure(id) end
    end
end

-- ------------------------------------------------------------
-- Registration
-- ------------------------------------------------------------

--- registerInventory(data) - data: id, name, limit, acceptWeapons, shared,
--- ignoreItemStackLimit, whitelistItems, UsePermissions, UseBlackList,
--- whitelistWeapons, webhook, useWeight, weight
function C.registerInventory(data)
    if type(data) ~= 'table' or data.id == nil then return false end
    local id = tostring(data.id)
    local old = defs[id]
    local d = {
        id = id,
        name = tostring(data.name or id),
        limit = math.floor(tonumber(data.limit) or 0),
        acceptWeapons = bool(data.acceptWeapons, true),
        shared = bool(data.shared, false),
        ignoreItemStackLimit = bool(data.ignoreItemStackLimit, false),
        whitelistItems = bool(data.whitelistItems, false),
        whitelistWeapons = bool(data.whitelistWeapons, false),
        UsePermissions = bool(data.UsePermissions, false),
        UseBlackList = bool(data.UseBlackList, false),
        webhook = data.webhook,
        useWeight = bool(data.useWeight, false),
        weight = tonumber(data.weight),
        isPermanent = bool(data.isPermanent, true),
        -- kept across a second register of the same id (scripts register on every start)
        itemLimits = old and old.itemLimits or {},
        weaponLimits = old and old.weaponLimits or {},
        permMove = old and old.permMove or {},
        permTake = old and old.permTake or {},
        charMove = old and old.charMove or {},
        charTake = old and old.charTake or {},
        blacklist = old and old.blacklist or {},
        resource = V.Invoker(),
    }
    defs[id] = d
    if d.shared then C.Ensure(id) end
    reapply(id) -- copies already made get the new settings
    return true
end

function C.isCustomInventoryRegistered(id, cb)
    return V.Done(cb, id ~= nil and defs[tostring(id)] ~= nil)
end

function C.removeInventory(id)
    if id == nil then return false end
    id = tostring(id)
    for invId in pairs(instances[id] or {}) do
        local inv = V.Get(invId)
        if inv then inv.canPut, inv.canTake, inv.onPut, inv.onTake, inv.vorpCustom = nil, nil, nil, nil, nil end
    end
    defs[id] = nil
    return true
end

--- deleteCustomInventory(id) - empties its stored items and forgets it
function C.deleteCustomInventory(id)
    if id == nil then return false end
    id = tostring(id)
    local E = MULTIInv
    for _, invId in ipairs(targets(id)) do
        local done = false
        V.Get(invId) -- loaded, so the engine's Delete also clears the saved row
        for _, fn in ipairs({ 'Delete', 'DeleteInventory', 'Wipe' }) do
            if E and type(E[fn]) == 'function' then
                done = pcall(E[fn], invId)
                if done then break end
            end
        end
        if not done then
            local inv = V.Get(invId)
            for _, e in ipairs(V.Stacks(inv)) do
                E.RemoveItem(invId, e.stack.name, V.StackAmount(e.stack), e.slot, nil, reason())
            end
        end
    end
    instances[id] = nil
    defs[id] = nil
    return true
end

--- getCustomInventorySlots(id, cb?) -> the item limit
function C.getCustomInventorySlots(id, cb)
    local d = id ~= nil and defs[tostring(id)]
    return V.Done(cb, d and d.limit or nil)
end

--- updateCustomInventorySlots(id, slots)
function C.updateCustomInventorySlots(id, slots, cb)
    local d = id ~= nil and defs[tostring(id)]
    slots = tonumber(slots)
    if not d or not slots then return V.Done(cb, false) end
    d.limit = math.max(0, math.floor(slots))
    reapply(d.id)
    return V.Done(cb, true)
end

function C.setCustomInventoryItemLimit(id, item, limit, cb)
    local d = id ~= nil and defs[tostring(id)]
    item = V.Norm(item)
    if not d or not item then return V.Done(cb, false) end
    d.itemLimits[item] = math.max(0, math.floor(tonumber(limit) or 0))
    reapply(d.id)
    return V.Done(cb, true)
end

function C.setCustomInventoryWeaponLimit(id, weapon, limit, cb)
    local d = id ~= nil and defs[tostring(id)]
    if not d or type(weapon) ~= 'string' then return V.Done(cb, false) end
    d.weaponLimits[weapon:lower()] = math.max(0, math.floor(tonumber(limit) or 0))
    reapply(d.id)
    return V.Done(cb, true)
end

function C.BlackListCustomAny(id, item)
    local d = id ~= nil and defs[tostring(id)]
    if not d or type(item) ~= 'string' then return false end
    d.blacklist[item] = true
    d.blacklist[item:lower()] = true
    reapply(d.id)
    return true
end

function C.AddPermissionMoveToCustom(id, job, grade)
    local d = id ~= nil and defs[tostring(id)]
    if not d or type(job) ~= 'string' then return false end
    d.permMove[job] = tonumber(grade) or 0
    return true
end

function C.AddPermissionTakeFromCustom(id, job, grade)
    local d = id ~= nil and defs[tostring(id)]
    if not d or type(job) ~= 'string' then return false end
    d.permTake[job] = tonumber(grade) or 0
    return true
end

function C.AddCharIdPermissionMoveToCustom(id, charid, state)
    local d = id ~= nil and defs[tostring(id)]
    if not d or charid == nil then return false end
    d.charMove[tonumber(charid) or charid] = (state ~= false) or nil
    return true
end

function C.AddCharIdPermissionTakeFromCustom(id, charid, state)
    local d = id ~= nil and defs[tostring(id)]
    if not d or charid == nil then return false end
    d.charTake[tonumber(charid) or charid] = (state ~= false) or nil
    return true
end

-- ------------------------------------------------------------
-- Items in custom inventories
-- ------------------------------------------------------------
local function idOf(id) return id ~= nil and tostring(id) or nil end

local function itemsOf(invId, wantWeapons)
    local out = {}
    for _, e in ipairs(V.Stacks(V.Get(invId))) do
        local isW = V.IsWeaponDef(V.Def(e.stack.name), e.stack.name)
        if isW == (wantWeapons == true) then
            if isW then out[#out + 1] = V.Weapons.ToWeapon(invId, e.slot, e.stack)
            else out[#out + 1] = V.ToItem(invId, e.slot, e.stack) end
        end
    end
    return out
end

--- getCustomInventoryItems(id, cb?) -> items (all characters' copies for a non-shared inventory)
function C.getCustomInventoryItems(id, cb)
    id = idOf(id)
    if not id then return V.Done(cb, {}) end
    if defs[id] then C.Ensure(id) end
    local out = {}
    for _, invId in ipairs(targets(id)) do
        for _, it in ipairs(itemsOf(invId, false)) do out[#out + 1] = it end
    end
    return V.Done(cb, out)
end

function C.getCustomInventoryWeapons(id, cb)
    id = idOf(id)
    if not id then return V.Done(cb, {}) end
    local out = {}
    for _, invId in ipairs(targets(id)) do
        for _, w in ipairs(itemsOf(invId, true)) do out[#out + 1] = w end
    end
    return V.Done(cb, out)
end

--- getCustomInventoryItemCount(id, itemName, cb?, metadata?)
function C.getCustomInventoryItemCount(id, name, cb, metadata)
    if type(cb) == 'table' and not V.IsCallable(cb) then cb, metadata = nil, cb end
    id, name = idOf(id), V.Norm(name)
    if not id or not name then return V.Done(cb, 0) end
    local n = 0
    for _, invId in ipairs(targets(id)) do n = n + V.CountOf(invId, name, metadata) end
    return V.Done(cb, n)
end

function C.getCustomInventoryWeaponCount(id, name, cb)
    id = idOf(id)
    if not id or type(name) ~= 'string' then return V.Done(cb, 0) end
    local n = 0
    for _, invId in ipairs(targets(id)) do n = n + V.CountOf(invId, name:lower()) end
    return V.Done(cb, n)
end

--- addItemsToCustomInventory(id, items, charid?, cb?)
--- items: { { name, amount (or count), metadata? }, ... } or { [name] = amount }
function C.addItemsToCustomInventory(id, items, charid, cb)
    if V.IsCallable(charid) and cb == nil then cb, charid = charid, nil end
    id = idOf(id)
    if not id or type(items) ~= 'table' then return V.Done(cb, false) end
    local invId, inv = C.Ensure(id, charid)
    if not inv then return V.Done(cb, false) end
    local list = {}
    for k, v in pairs(items) do
        if type(v) == 'table' then
            list[#list + 1] = { name = V.Norm(v.name or v.item), amount = V.Amount(v.amount or v.count, 1), info = V.InfoFrom(v.metadata or v.info) }
        elseif type(k) == 'string' then
            list[#list + 1] = { name = V.Norm(k), amount = V.Amount(v, 1) }
        end
    end
    -- check everything first: all or nothing
    for _, it in ipairs(list) do
        if not it.name or not it.amount then return V.Done(cb, false) end
        if MULTIInv.CanAdd(invId, it.name, it.amount, it.info) ~= true then return V.Done(cb, false) end
    end
    for _, it in ipairs(list) do
        if MULTIInv.AddItem(invId, it.name, it.amount, it.info, nil, reason()) ~= true then return V.Done(cb, false) end
    end
    return V.Done(cb, true)
end

--- addWeaponsToCustomInventory(id, weapons, charid?, cb?)
--- weapons: { { name, serial_number?, custom_label?, custom_desc?, components?, comps?, ammo? }, ... }
function C.addWeaponsToCustomInventory(id, weapons, charid, cb)
    if V.IsCallable(charid) and cb == nil then cb, charid = charid, nil end
    id = idOf(id)
    if not id or type(weapons) ~= 'table' then return V.Done(cb, false) end
    local invId, inv = C.Ensure(id, charid)
    if not inv then return V.Done(cb, false) end
    for _, w in pairs(weapons) do
        if type(w) == 'table' and type(w.name) == 'string' then
            local name = w.name:lower()
            local comps = type(w.comps) == 'table' and w.comps or nil
            local components = type(w.components) == 'table' and w.components or {}
            -- components given as { [category] = component } go to comps
            if not comps and next(components) and #components == 0 then comps, components = components, {} end
            local info = V.Weapons.NewInfo(name, {
                serie = w.serial_number,
                custom_label = w.custom_label,
                custom_desc = w.custom_desc,
                components = V.Copy(components),
                comps = V.Copy(comps or {}),
                ammo = V.AmmoNumber(w.ammo),
            })
            if MULTIInv.AddItem(invId, name, 1, info, nil, reason()) ~= true then return V.Done(cb, false) end
        end
    end
    return V.Done(cb, true)
end

--- removeItemFromCustomInventory(id, itemName, amount, itemCraftedId?, cb?)
--- itemCraftedId = a VORP item id: take from that stack only
function C.removeItemFromCustomInventory(id, name, amount, itemId, cb)
    if V.IsCallable(itemId) and cb == nil then cb, itemId = itemId, nil end
    if V.IsCallable(amount) and cb == nil then cb, amount = amount, nil end
    id, name = idOf(id), V.Norm(name)
    amount = V.Amount(amount, 1)
    if not id or not name or not amount then return V.Done(cb, false) end
    if itemId ~= nil and tonumber(itemId) and tonumber(itemId) > 0 then
        local invId, slot, st = V.Resolve(itemId)
        if not invId or C.NameOf(invId) ~= id or st.name ~= name then return V.Done(cb, false) end
        if V.StackAmount(st) < amount then return V.Done(cb, false) end
        return V.Done(cb, MULTIInv.RemoveItem(invId, name, amount, slot, nil, reason()) == true)
    end
    for _, invId in ipairs(targets(id)) do
        local list = V.Find(invId, name)
        if V.CountOf(invId, name) >= amount then
            return V.Done(cb, V.RemoveFrom(invId, name, amount, list, reason()) == true)
        end
    end
    return V.Done(cb, false)
end

--- updateCustomInventoryItem(id, itemId, metadata, amount?, cb?)
function C.updateCustomInventoryItem(id, itemId, metadata, amount, cb)
    if V.IsCallable(amount) and cb == nil then cb, amount = amount, nil end
    id = idOf(id)
    local invId, slot, st = V.Resolve(itemId)
    if not id or not invId or C.NameOf(invId) ~= id or type(metadata) ~= 'table' then return V.Done(cb, false) end
    local info = V.Copy(metadata)
    for k, v in pairs(V.HiddenPart(st.info)) do if info[k] == nil then info[k] = v end end
    local have = V.StackAmount(st)
    local n = amount == nil and have or V.Amount(amount)
    if not n then return V.Done(cb, false) end
    if n >= have then return V.Done(cb, MULTIInv.ReplaceInfo(invId, slot, info) ~= false) end
    if MULTIInv.RemoveItem(invId, st.name, n, slot, nil, reason()) ~= true then return V.Done(cb, false) end
    return V.Done(cb, MULTIInv.AddItem(invId, st.name, n, info, nil, reason()) == true)
end

function C.removeCustomInventoryWeaponById(id, weaponId, cb)
    id = idOf(id)
    if not id then return V.Done(cb, false) end
    for _, invId in ipairs(targets(id)) do
        local fi, slot, st = V.Weapons.Find(weaponId, nil, invId)
        if fi == invId then
            return V.Done(cb, MULTIInv.RemoveItem(invId, st.name, 1, slot, nil, reason()) == true)
        end
    end
    return V.Done(cb, false)
end

function C.removeWeaponFromCustomInventory(id, name, cb)
    id = idOf(id)
    if not id or type(name) ~= 'string' then return V.Done(cb, false) end
    name = name:lower()
    for _, invId in ipairs(targets(id)) do
        local e = V.Find(invId, name)[1]
        if e then return V.Done(cb, MULTIInv.RemoveItem(invId, name, 1, e.slot, nil, reason()) == true) end
    end
    return V.Done(cb, false)
end

-- ------------------------------------------------------------
-- Opening and closing
-- ------------------------------------------------------------

--- openInventory(source, id?) - no id: the player's own satchel
-- MULTIInv.Open returns true | false, err (and may raise if the engine is not ready)
local function open(src, target, opts)
    local ok, res, err = pcall(MULTIInv.Open, src, target, opts)
    if not ok then V.Warn('Open failed: %s', tostring(res)) return false end
    if res == false then V.Debug('Open(%s) refused: %s', tostring(target), tostring(err)) return false end
    return true
end

function C.openInventory(src, id)
    src = V.Src(src)
    if not src then return false end
    if id == nil then return open(src) end          -- the satchel alone
    id = tostring(id)
    if defs[id] then
        local invId, inv = C.Ensure(id, V.CharId(src))
        if not inv then return open(src, spec(id, invId)) end
        return open(src, invId)
    end
    -- not registered: an engine inventory id ('stash:x', 'custom:x') or a bare stash name
    if not id:find(':') then id = 'stash:' .. id end
    return open(src, id)
end

--- closeInventory(source, invId?) - closes the screen (satchel and second inventory)
function C.closeInventory(src)
    src = V.Src(src)
    if not src then return false end
    pcall(MULTIInv.Close, src)
    return true
end

--- openPlayerInventory({ source, target, title?, blacklist?, itemsLimit?, timeout? })
--- Opens the target's satchel for source (search). title / blacklist / itemsLimit / timeout
--- are not applied yet (see the README).
function C.openPlayerInventory(data)
    if type(data) ~= 'table' then return false end
    local src, target = V.Src(data.source), V.Src(data.target)
    if not src or not target or src == target then return false end
    if type(MULTIInv.OpenPlayer) == 'function' then
        local ok, res = pcall(MULTIInv.OpenPlayer, src, target)
        return ok and res ~= false
    end
    local invId = V.InvOf(target)
    return invId ~= nil and open(src, invId)
end

-- a stopped resource takes its custom inventories' rules with it (items stay saved)
AddEventHandler('onResourceStop', function(res)
    for id, d in pairs(defs) do
        if d.resource == res then C.removeInventory(id) end
    end
end)

-- ------------------------------------------------------------
-- Exports
-- ------------------------------------------------------------
for _, name in ipairs({
    'registerInventory', 'isCustomInventoryRegistered', 'removeInventory', 'deleteCustomInventory',
    'getCustomInventorySlots', 'updateCustomInventorySlots', 'setCustomInventoryItemLimit',
    'setCustomInventoryWeaponLimit', 'BlackListCustomAny', 'AddPermissionMoveToCustom',
    'AddPermissionTakeFromCustom', 'AddCharIdPermissionMoveToCustom', 'AddCharIdPermissionTakeFromCustom',
    'getCustomInventoryItems', 'getCustomInventoryWeapons', 'getCustomInventoryItemCount',
    'getCustomInventoryWeaponCount', 'addItemsToCustomInventory', 'addWeaponsToCustomInventory',
    'removeItemFromCustomInventory', 'updateCustomInventoryItem', 'removeCustomInventoryWeaponById',
    'removeWeaponFromCustomInventory', 'openInventory', 'closeInventory', 'openPlayerInventory',
}) do
    V.Export(name, C[name])
end
V.Export('removeCustomInventory', C.removeInventory)
