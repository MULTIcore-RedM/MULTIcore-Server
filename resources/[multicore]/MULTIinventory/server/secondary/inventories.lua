-- ============================================================
-- MULTIinventory :: server/secondary/inventories.lua
--
-- Registered secondary inventories: stashes, bank boxes, house/boat-house storage,
-- horse saddlebags (bagId), wagon trunks, vehicle trunks (mechboot_<id>), business
-- storages, RINGOitemplacer boxes/bags. The caller's id is kept EXACTLY as the
-- container id, so ids stored by other resources keep working.
--
-- registerInventory semantics (vorp_inventory public API, own implementation):
--   id, name, limit (= slots, Config.Secondary.limitMode), acceptWeapons, shared,
--   ignoreItemStackLimit, whitelistItems, UsePermissions, UseBlackList, whitelistWeapons,
--   webhook, useWeight + weight (kg limit, used by RINGOstables/itemplacer/wagons).
--   Registration lives for the running session (like vorp: callers re-register after a
--   restart); re-registering an id that is already registered changes nothing unless the
--   native API passes opts.update. Contents are always persisted.
--
-- shared = false  -> every character has its OWN contents of that inventory. The container
--                    of one character is the "instance" '<id>@<charId>'
--                    (Secondary.instanceId; the migration part maps vorp rows with
--                    inventory_type = <id> and character_id = <charId> to it).
-- shared = true   -> one set of contents; several viewers at once (Config.Secondary.
--                    allowMultipleViewers / maxViewers / singleViewerPatterns).
--
-- Lua API (in-resource; the vorp_inventory face forwards the vorp names through SecondaryCompat):
--   Secondary.register(data, opts) -> ok, 'exists'|err      opts.update, opts.resource
--   Secondary.isRegistered(id) -> bool        Secondary.registration(id) -> reg|nil
--   Secondary.unregister(id, purge, actor) -> ok
--   Secondary.instanceId(id, charId) -> '<id>@<charId>'     Secondary.parseInstance(cid) -> id, charId
--   Secondary.target(id, charId) -> containerId (instance for per-character inventories)
--   Secondary.open(src, id, opts) -> ok, err                 opts.label, opts.admin
--   Secondary.openSaddlebag(src, bagId, label) -> ok, err
--   Secondary.setSlots(id, slots) / Secondary.getSlots(id)
--   Secondary.getItems(id, charId) / count / addItems / removeItem / updateItem
--   Secondary.getWeapons(id, charId) / countWeapons / addWeapons / removeWeaponById / removeWeaponByName
--   Secondary.apply(id)    (re-save definition of base + instances after a list change)
--   Secondary.notifyErr(src, err)
-- Server events (local): MULTIinventory:secondaryDeposit (src, baseId, item{name,amount,metadata,id?}, containerId)
--                        MULTIinventory:secondaryWithdraw (same)
-- InvHooks emitted: containerPurged(containerId)
-- ============================================================

Secondary = Secondary or {}
Secondary.SEP = '@'

local regs = {}       -- [id] = registration
local activity = {}   -- [containerId] = last change/open (unix s)
local webhookQueue = {} -- [url] = { lines }

local function cfg() return Config.Secondary or {} end
local function truthy(v) return v == true or v == 1 or v == '1' or v == 'true' end

local RESERVED_KINDS = { player = true, equip = true, drop = true }

-- ------------------------------------------------------------
-- ids
-- ------------------------------------------------------------
function Secondary.instanceId(id, charId)
    local n = math.tointeger(tonumber(charId))
    if not n then return nil end
    return tostring(id) .. Secondary.SEP .. tostring(n)
end

function Secondary.parseInstance(cid)
    local base, ch = tostring(cid):match('^(.+)@(%d+)$')
    if not base then return nil end
    return base, math.tointeger(tonumber(ch))
end

---Registered base id of a container id (instance -> base), or nil.
function Secondary.baseOf(cid)
    if regs[cid] then return cid end
    local base = Secondary.parseInstance(cid)
    if base and regs[base] then return base end
    return nil
end

function Secondary.registration(id) return regs[tostring(id)] end
function Secondary.isRegistered(id) return id ~= nil and regs[tostring(id)] ~= nil end
function Secondary.all() return regs end

-- ------------------------------------------------------------
-- normalisation of registerInventory data
-- ------------------------------------------------------------
local function clampSlots(n)
    local c = cfg()
    n = math.floor(tonumber(n) or (c.defaults and c.defaults.slots) or 50)
    return math.max(c.minSlots or 1, math.min(c.maxSlots or 1000, n))
end

local function multiViewer(id, data, perChar)
    if perChar then return false end
    if data.multiViewer ~= nil then return data.multiViewer == true end
    if cfg().allowMultipleViewers == false then return false end
    for _, p in ipairs(cfg().singleViewerPatterns or {}) do
        if tostring(id):find(p) then return false end
    end
    return true
end

---Name key used in black/white lists and limits (weapons upper-case, items as given).
function Secondary.nameKey(name)
    if type(name) ~= 'string' then return nil end
    if Util.isWeaponName(name) then return name:upper() end
    return name
end

local function eachName(list, fn)
    if type(list) ~= 'table' then return end
    for k, v in pairs(list) do
        if type(k) == 'number' then fn(v, true) else fn(k, v) end
    end
end

---registerInventory data -> definition pieces. Pure (no side effects).
function Secondary.normalize(id, data)
    local c, d = cfg(), cfg().defaults or {}
    local shared
    if data.perCharacter ~= nil then shared = not truthy(data.perCharacter)
    elseif data.shared ~= nil then shared = truthy(data.shared)
    else shared = d.shared == true end
    local perChar = not shared

    local slots, countLimit
    if data.slots ~= nil then
        slots = data.slots
    elseif c.limitMode == 'count' and tonumber(data.limit) then
        countLimit = math.max(0, math.floor(tonumber(data.limit)))
        slots = c.countModeSlots or 100
    else
        slots = data.limit
    end
    slots = clampSlots(slots)

    local maxWeight = tonumber(data.maxWeight)
    if not maxWeight and c.honourUseWeight ~= false and truthy(data.useWeight) then maxWeight = tonumber(data.weight) end
    if not maxWeight then maxWeight = tonumber(d.maxWeight) end
    if maxWeight and maxWeight <= 0 then maxWeight = nil end

    local acceptWeapons
    if data.acceptWeapons == nil then acceptWeapons = d.acceptWeapons ~= false else acceptWeapons = truthy(data.acceptWeapons) end

    local useBlackList = data.UseBlackList
    if useBlackList == nil then useBlackList = data.useBlackList end

    local kind = type(data.kind) == 'string' and data.kind or 'custom'
    if RESERVED_KINDS[kind] then kind = 'custom' end

    return {
        label = tostring(data.label or data.name or id):sub(1, 100),
        slots = slots,
        maxWeight = maxWeight,
        kind = kind,
        webhook = (type(data.webhook) == 'string' and data.webhook:match('^https?://')) and data.webhook or nil,
        flags = {
            registered = true,
            acceptWeapons = acceptWeapons,
            shared = multiViewer(id, data, perChar),      -- core meaning: several viewers allowed
            perCharacter = perChar,                       -- vorp shared = false
            ignoreItemStackLimit = truthy(data.ignoreItemStackLimit),
            whitelistItems = truthy(data.whitelistItems),
            whitelistWeapons = truthy(data.whitelistWeapons),
            usePermissions = truthy(data.UsePermissions) or truthy(data.usePermissions),
            -- nil = automatic (enforced once a name is black-listed), false = off, true = on
            useBlackList = (useBlackList ~= nil) and truthy(useBlackList) or nil,
            countLimit = countLimit,
            freeze = truthy(data.freeze) or nil,
        },
    }
end

local function newLists(flags)
    flags.blacklist = flags.blacklist or {}
    flags.itemLimits = flags.itemLimits or {}
    flags.weaponLimits = flags.weaponLimits or {}
end

local function newPerms()
    return { jobsMove = {}, jobsTake = {}, charsMove = {}, charsTake = {} }
end

-- optional lists in the data table (native API; vorp callers use the Add*/BlackList exports)
local function applyLists(reg, data)
    local f = reg.flags
    eachName(data.blacklist, function(n, on) local k = Secondary.nameKey(n) if k and on then f.blacklist[k] = true end end)
    eachName(data.limitedItems or data.itemLimits, function(n, lim)
        local k, l = Secondary.nameKey(n), tonumber(lim)
        if k and l and l > 0 then f.itemLimits[k] = math.floor(l) end
    end)
    eachName(data.weaponLimits or data.limitedWeapons, function(n, lim)
        local k, l = Secondary.nameKey(n), tonumber(lim)
        if k and l and l > 0 then f.weaponLimits[k] = math.floor(l) end
    end)
    local p = data.perms or data.permissions
    if type(p) == 'table' then
        for _, key in ipairs({ 'jobsMove', 'jobsTake' }) do
            eachName(p[key], function(job, grade)
                if type(job) == 'string' then reg.perms[key][job] = math.floor(tonumber(grade) or 0) end
            end)
        end
        for _, key in ipairs({ 'charsMove', 'charsTake' }) do
            eachName(p[key], function(cid, on)
                local n = math.tointeger(tonumber(cid))
                if n and on then reg.perms[key][tostring(n)] = true end
            end)
        end
    end
end

local function defOf(reg, charId)
    return {
        label = reg.label,
        slots = reg.slots,
        maxWeight = reg.maxWeight or false,   -- false clears a previous weight limit (Containers.define merges)
        kind = reg.kind,
        ownerCharId = charId,
        flags = reg.flags,                    -- the SAME tables for base + instances
        perms = reg.perms,
    }
end

---(Re)define the base container and every known instance from the registration.
function Secondary.apply(id)
    local reg = regs[id]
    if not reg then return false end
    Containers.define(id, defOf(reg, nil))
    for ch in pairs(reg.instances) do
        Containers.define(Secondary.instanceId(id, ch), defOf(reg, ch))
    end
    return true
end

---Register an inventory (registerInventory). Idempotent.
function Secondary.register(data, opts)
    opts = opts or {}
    if type(data) ~= 'table' then return false, 'bad_data' end
    local id = data.id
    if type(id) == 'number' then id = tostring(math.tointeger(id) or id) end
    if type(id) ~= 'string' or id == '' or #id > 90 then return false, 'bad_id' end
    if Containers.kindOf(id) ~= 'custom' then return false, 'reserved_id' end
    local prev = regs[id]
    if prev and not opts.update then return true, 'exists' end

    local n = Secondary.normalize(id, data)
    local reg
    if prev then
        reg = prev
        -- keep the runtime lists (black list, limits, permissions) of the registration
        local keep = { blacklist = reg.flags.blacklist, itemLimits = reg.flags.itemLimits, weaponLimits = reg.flags.weaponLimits }
        for k in pairs(reg.flags) do reg.flags[k] = nil end
        for k, v in pairs(n.flags) do reg.flags[k] = v end
        for k, v in pairs(keep) do reg.flags[k] = v end
        reg.label, reg.slots, reg.maxWeight, reg.kind = n.label, n.slots, n.maxWeight, n.kind
        reg.webhook = n.webhook or reg.webhook
    else
        reg = {
            id = id, label = n.label, slots = n.slots, maxWeight = n.maxWeight, kind = n.kind,
            flags = n.flags, perms = newPerms(), webhook = n.webhook, instances = {},
            resource = opts.resource, registeredAt = Util.now(),
        }
    end
    newLists(reg.flags)
    applyLists(reg, data)
    regs[id] = reg
    Secondary.apply(id)
    return true
end

local function likeEscape(s) return (tostring(s):gsub('[\\%%_]', '\\%0')) end

---Every per-character instance id of `id` that exists in the database or the cache. Yields.
function Secondary.findInstances(id)
    local out, seen = {}, {}
    local function add(x)
        local b, ch = Secondary.parseInstance(x)
        if b == id and ch and not seen[x] then seen[x] = true; out[#out + 1] = x end
    end
    local reg = regs[id]
    if reg then for ch in pairs(reg.instances) do add(Secondary.instanceId(id, ch)) end end
    Containers.each(function(c) add(c.id) end)
    local pat = likeEscape(id) .. Secondary.SEP .. '%'
    for _, r in ipairs(InvDB.query('SELECT `id` FROM `multiinv_containers` WHERE `id` LIKE ?', { pat })) do add(r.id) end
    for _, r in ipairs(InvDB.query('SELECT DISTINCT `container_id` FROM `multiinv_stacks` WHERE `container_id` LIKE ?', { pat })) do add(r.container_id) end
    return out
end

---Forget a registration (removeInventory) or delete it with everything inside
---(deleteCustomInventory, purge = true). Viewers are closed first. Yields.
function Secondary.unregister(id, purge, actor)
    if id == nil then return false, 'bad_id' end
    id = tostring(id)
    local reg = regs[id]
    local ids = { id }
    if purge then
        for _, x in ipairs(Secondary.findInstances(id)) do ids[#ids + 1] = x end
    elseif reg then
        for ch in pairs(reg.instances) do ids[#ids + 1] = Secondary.instanceId(id, ch) end
    end
    for _, cid in ipairs(ids) do
        for vsrc in pairs(Util.deepcopy(State.viewersOf(cid))) do State.close(vsrc, true) end
    end
    regs[id] = nil
    if purge then
        local removed = {}
        for _, cid in ipairs(ids) do
            local c = Containers.get(cid) -- loads it (the weapons part places weapon occupants on load)
            if c then
                local ok, r = Inv.clear(c, { occupants = true }, { reason = 'purge', resource = actor })
                if ok then for _, x in ipairs(r) do x.container = cid; removed[#removed + 1] = x end end
            end
            InvHooks.emit('containerPurged', cid)
            Containers.undefine(cid, true)
            Containers.forget(cid)
            activity[cid] = nil
        end
        InvLog.write('admin_stash_delete', { actor = tostring(actor or 'script'):sub(1, 64), from = id,
                                             data = { containers = ids, stacks = removed } })
    else
        for _, cid in ipairs(ids) do
            Containers.undefine(cid, false)
            if Containers.isLoaded(cid) then Containers.unload(cid) end
        end
    end
    TriggerEvent('MULTIinventory:secondaryRemoved', id, purge == true)
    return true
end

-- ------------------------------------------------------------
-- instances + targets
-- ------------------------------------------------------------
---Container id of `charId`'s contents of a registered per-character inventory
---(defines the instance on first use). Shared/unregistered ids are returned unchanged.
function Secondary.instance(id, charId)
    local reg = regs[id]
    if not reg then return id end
    if not reg.flags.perCharacter then return id end
    local n = math.tointeger(tonumber(charId))
    if not n then return nil, 'no_charid' end
    local iid = Secondary.instanceId(id, n)
    if not reg.instances[n] or not Containers.isDefined(iid) then
        reg.instances[n] = true
        Containers.define(iid, defOf(reg, n))
    end
    return iid
end

---Container id for API calls: per-character inventory + charId -> instance, else the id itself.
function Secondary.target(id, charId)
    if id == nil then return nil end
    id = tostring(id)
    local reg = regs[id]
    if reg and reg.flags.perCharacter and charId ~= nil then return Secondary.instance(id, charId) end
    return id
end

-- ------------------------------------------------------------
-- open
-- ------------------------------------------------------------
function Secondary.notifyErr(src, err)
    if not src or not err then return end
    local m = (cfg().messages or {})[err]
    if m then Sync.notify(src, m, 'error') end
end

---openInventory(src, id): next to the player grid. id nil = player inventory only.
function Secondary.open(src, id, opts)
    opts = opts or {}
    src = tonumber(src)
    local st = src and State.get(src)
    if not st then return false, 'player_not_loaded' end
    if id == nil or id == '' then return State.open(src, nil) end
    id = tostring(id)
    local reg = regs[id]
    local cid, err = id, nil
    if reg then
        cid, err = Secondary.instance(id, st.charId)
        if not cid then return false, err end
    end
    local ok
    ok, err = State.open(src, cid, { label = opts.label or (reg and reg.label), admin = opts.admin })
    if not ok then Secondary.notifyErr(src, err) end
    return ok, err
end

---Saddlebags by bagId (RINGOstables / RINGOitemplacer register them themselves; this is the
---native path for scripts that only know the bag id).
function Secondary.openSaddlebag(src, bagId, label)
    local sb = cfg().saddlebags or {}
    if sb.enabled == false then return false, 'disabled' end
    if type(bagId) ~= 'string' or bagId == '' then return false, 'bad_id' end
    if not regs[bagId] then
        local ok, err = Secondary.register({ id = bagId, name = label or 'Saddlebags', limit = sb.slots or 40,
            acceptWeapons = sb.acceptWeapons ~= false, shared = true, ignoreItemStackLimit = true,
            maxWeight = sb.maxWeight, kind = 'saddlebag' })
        if not ok then return false, err end
    end
    return Secondary.open(src, bagId, { label = label })
end

-- ------------------------------------------------------------
-- slots
-- ------------------------------------------------------------
function Secondary.setSlots(id, slots)
    id = tostring(id)
    local n = tonumber(slots)
    if not n then return false, 'bad_slots' end
    local reg = regs[id]
    if reg then
        reg.slots = clampSlots(n)
        if reg.flags.countLimit then reg.slots = clampSlots(cfg().countModeSlots or 100); reg.flags.countLimit = math.floor(n) end
        Secondary.apply(id)
        return true
    end
    if Containers.isDefined(id) or Containers.isLoaded(id) then
        Containers.define(id, { slots = clampSlots(n) })
        return true
    end
    return false, 'unknown_container'
end

function Secondary.getSlots(id)
    id = tostring(id)
    local reg = regs[id]
    if reg then return reg.flags.countLimit or reg.slots end
    local c = Containers.peek(id)
    return c and c.slots or nil
end

-- ------------------------------------------------------------
-- items / weapons in a secondary (API side, no player rules)
-- ------------------------------------------------------------
local function apiCtx(reason) return { reason = reason or 'api', resource = GetInvokingResource and GetInvokingResource() or nil } end

local function compatItem(t)
    t.crafted_id = t.id
    t.amount = t.count
    return t
end

function Secondary.getItems(id, charId)
    local cid = Secondary.target(id, charId)
    if not cid then return {} end
    local out = {}
    for _, t in ipairs(Inv.getStacks(cid)) do
        if t.kind ~= 'weapon' then out[#out + 1] = compatItem(t) end
    end
    return out
end

function Secondary.count(id, name, meta, charId)
    local cid = Secondary.target(id, charId)
    if not cid then return 0 end
    return Inv.count(cid, name, meta)
end

---items = { { name|item, amount|count, metadata }, ... } - all or nothing.
function Secondary.addItems(id, items, charId, ctx)
    local cid, err = Secondary.target(id, charId)
    if not cid then return false, err end
    local c
    c, err = Inv.resolve(cid)
    if not c then return false, err end
    if type(items) ~= 'table' then return false, 'bad_items' end
    if items.name or items.item then items = { items } end
    ctx = ctx or apiCtx('api')
    local done = {}
    for _, it in ipairs(items) do
        local ok, res = Inv.add(c, it.name or it.item, tonumber(it.amount or it.count) or 1, it.metadata, ctx)
        if not ok then
            for _, p in ipairs(done) do Inv.removeStack(c, p.id, p.count, { reason = 'rollback' }) end
            return false, res
        end
        for _, p in ipairs(res) do done[#done + 1] = p end
    end
    return true, done
end

function Secondary.removeItem(id, name, amount, stackId, charId, ctx)
    local cid, err = Secondary.target(id, charId)
    if not cid then return false, err end
    ctx = ctx or apiCtx('api')
    amount = tonumber(amount) or 1
    if stackId ~= nil and tonumber(stackId) then
        return Inv.removeStack(cid, stackId, amount, ctx)
    end
    return Inv.remove(cid, name, amount, nil, ctx)
end

function Secondary.updateItem(id, stackId, meta, amount, charId, ctx)
    local cid, err = Secondary.target(id, charId)
    if not cid then return false, err end
    return Inv.setMetadata(cid, stackId, meta or {}, amount ~= nil and tonumber(amount) or nil, ctx or apiCtx('api'))
end

local function weaponView(t)
    local m = t.metadata or {}
    t.serial_number = t.serial_number or m.serial or m.serial_number
    t.custom_label = t.custom_label or m.custom_label
    t.custom_desc = t.custom_desc or m.custom_desc
    return t
end

function Secondary.getWeapons(id, charId)
    local cid = Secondary.target(id, charId)
    if not cid then return {} end
    local W = rawget(_G, 'Weapons')
    if type(W) == 'table' and type(W.list) == 'function' then return W.list(cid) end  -- vorp-shaped rows
    local out = {}
    for _, t in ipairs(Inv.getStacks(cid, { kind = 'weapon' })) do out[#out + 1] = weaponView(t) end
    return out
end

function Secondary.countWeapons(id, name, charId)
    local key = Secondary.nameKey(name)
    local n = 0
    for _, w in ipairs(Secondary.getWeapons(id, charId)) do
        if key == nil or Secondary.nameKey(w.name) == key then n = n + 1 end
    end
    return n
end

local function weaponsLane()
    local W = rawget(_G, 'Weapons')
    if type(W) == 'table' and type(W.create) == 'function' and type(W.delete) == 'function' then return W end
    return nil
end

-- delete a weapon that sits in a container: weapons part (row + occupant) when present,
-- otherwise take the occupant out and signal occupantRemoved (core contract)
local function takeWeapon(c, e, ctx)
    local W = weaponsLane()
    if W then return W.delete(e.weaponId, ctx) end
    Containers.take(c, e.slot)
    InvHooks.emit('occupantRemoved', c, e, ctx)
    return true
end

local function containersOf(id, charId)
    local list = {}
    local cid = Secondary.target(id, charId)
    if cid then list[#list + 1] = cid end
    local reg = regs[tostring(id)]
    if charId == nil and reg and reg.flags.perCharacter then
        for ch in pairs(reg.instances) do list[#list + 1] = Secondary.instanceId(id, ch) end
    end
    return list
end

function Secondary.removeWeaponById(id, weaponId, charId, ctx)
    local wid = math.tointeger(tonumber(weaponId))
    if not wid then return false, 'bad_weapon' end
    for _, cid in ipairs(containersOf(id, charId)) do
        local c = Inv.resolve(cid)
        if c then
            for _, e in pairs(c.stacks) do
                if e.kind == 'weapon' and math.tointeger(tonumber(e.weaponId)) == wid then
                    return takeWeapon(c, e, ctx or apiCtx('api'))
                end
            end
        end
    end
    return false, 'no_weapon'
end

function Secondary.removeWeaponByName(id, name, charId, ctx)
    local key = Secondary.nameKey(name)
    if not key then return false, 'bad_weapon' end
    for _, cid in ipairs(containersOf(id, charId)) do
        local c = Inv.resolve(cid)
        if c then
            local best
            for _, e in pairs(c.stacks) do
                if e.kind == 'weapon' and Secondary.nameKey(e.item) == key and (not best or e.slot < best.slot) then best = e end
            end
            if best then return takeWeapon(c, best, ctx or apiCtx('api')) end
        end
    end
    return false, 'no_weapon'
end

---weapons = { { name, serial_number?, custom_label?, custom_desc?, components?, comps? }, ... }
---Needs the weapons part: Weapons.create(containerId, name, opts, ctx) -> ok, rec|err.
function Secondary.addWeapons(id, weapons, charId, ctx)
    local cid, err = Secondary.target(id, charId)
    if not cid then return false, err end
    local c
    c, err = Inv.resolve(cid)
    if not c then return false, err end
    local W = weaponsLane()
    if not W then return false, 'weapons_unavailable' end
    if type(weapons) ~= 'table' then return false, 'bad_weapons' end
    if weapons.name then weapons = { weapons } end
    ctx = ctx or apiCtx('api')
    -- check everything first (all or nothing as far as the rules go)
    for _, w in ipairs(weapons) do
        if not Util.isWeaponName(w.name) then return false, 'bad_weapon' end
        if c.flags and c.flags.acceptWeapons == false then return false, 'no_weapons' end
        local ok, e2 = InvHooks.check('canAdd', c, w.name, 1, {}, ctx)
        if not ok then return false, e2 end
    end
    local created = {}
    for _, w in ipairs(weapons) do
        local ok, res = W.create(cid, w.name, {
            serial = w.serial_number or w.serial, serialFallback = true,
            customLabel = w.custom_label or w.label, customDesc = w.custom_desc or w.desc,
            components = w.components, comps = w.comps, ammo = w.ammo, metadata = w.metadata,
            owner = math.tointeger(tonumber(charId)),
        }, ctx)
        if not ok then return false, res, created end
        created[#created + 1] = type(res) == 'table' and res.id or res
    end
    return true, created
end

-- ------------------------------------------------------------
-- activity (stale single-viewer locks), viewer rules, events, webhooks
-- ------------------------------------------------------------
function Secondary.touch(cid) activity[cid] = Util.now() end
function Secondary.lastActivity(cid) return activity[cid] end

InvHooks.register('containerChanged', function(c) activity[c.id] = Util.now() end)
AddEventHandler('MULTIinventory:containerOpened', function(_, id) if id then activity[id] = Util.now() end end)

-- Viewer rules for every secondary opened through State.open (non-admin).
InvHooks.register('canOpen', function(src, c, opts)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local f = c.flags or {}
    -- someone else's per-character contents
    if f.perCharacter and c.ownerCharId and c.ownerCharId ~= st.charId then return false, 'no_access' end
    local others = {}
    for v in pairs(State.viewersOf(c.id)) do if v ~= src then others[#others + 1] = v end end
    if #others == 0 then return true end
    if f.shared then
        local max = tonumber(cfg().maxViewers) or 0
        if max > 0 and #others >= max then return false, 'locked' end
        return true
    end
    -- single viewer: a holder idle for lockTimeoutSeconds loses the lock
    local timeout = tonumber(cfg().lockTimeoutSeconds) or 0
    if timeout > 0 and Util.now() - (activity[c.id] or 0) >= timeout then
        for _, v in ipairs(others) do State.close(v, true) end
        return true
    end
    return false, 'locked'
end)

-- extra info for the UI (kind, per-character, viewers)
InvHooks.register('openPayload', function(src, payload)
    local sec = payload.secondary
    if not sec then return end
    local c = Containers.peek(sec.id)
    local f = c and c.flags or {}
    local n = 0
    for _ in pairs(State.viewersOf(sec.id)) do n = n + 1 end
    payload.secondaryInfo = {
        id = Secondary.baseOf(sec.id) or sec.id,
        kind = c and c.kind or sec.kind,
        perCharacter = f.perCharacter == true,
        shared = f.shared == true,
        acceptWeapons = f.acceptWeapons ~= false,
        viewers = n,
        countLimit = f.countLimit,
    }
end)

local function itemLabel(name, meta)
    if type(meta) == 'table' and meta.label then return tostring(meta.label) end
    local d = Registry.get(name)
    return d and d.label or tostring(name)
end

local function queueWebhook(reg, line)
    local w = cfg().webhook or {}
    if w.enabled == false or not reg.webhook or not PerformHttpRequest then return end
    local q = webhookQueue[reg.webhook]
    if not q then q = { label = reg.label, lines = {} }; webhookQueue[reg.webhook] = q end
    q.lines[#q.lines + 1] = line
end

function Secondary.flushWebhooks()
    local w = cfg().webhook or {}
    local batch = webhookQueue
    webhookQueue = {}
    for url, q in pairs(batch) do
        local max = w.maxLinesPerMessage or 15
        for i = 1, #q.lines, max do
            local part = {}
            for j = i, math.min(i + max - 1, #q.lines) do part[#part + 1] = q.lines[j] end
            local body = json.encode({
                username = w.username or 'MULTIinventory',
                embeds = { { title = tostring(q.label), description = table.concat(part, '\n'), color = w.color or 9807270,
                             footer = { text = os.date('%Y-%m-%d %H:%M:%S') } } },
            })
            PerformHttpRequest(url, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
        end
    end
end

local function actorName(src)
    local st = State.get(src)
    return (st and st.name and st.name ~= '' and st.name) or (GetPlayerName and GetPlayerName(src)) or ('#' .. tostring(src))
end

local function onMove(kind, c, name, count, meta, ctx, weaponId)
    local base = Secondary.baseOf(c.id)
    if not base then return end
    local item = { name = name, amount = count, metadata = Util.deepcopy(meta or {}), id = weaponId }
    TriggerEvent(kind == 'deposit' and 'MULTIinventory:secondaryDeposit' or 'MULTIinventory:secondaryWithdraw', ctx.src, base, item, c.id)
    local reg = regs[base]
    if reg then
        queueWebhook(reg, ('%s %s %dx %s'):format(actorName(ctx.src), kind == 'deposit' and 'put in' or 'took out',
            count, itemLabel(name, meta)))
    end
end

InvHooks.register('itemAdded', function(c, item, count, meta, ctx)
    if ctx and ctx.src and c.flags and c.flags.registered then onMove('deposit', c, item, count, meta, ctx) end
end)
InvHooks.register('itemRemoved', function(c, item, count, meta, ctx)
    if ctx and ctx.src and c.flags and c.flags.registered then onMove('withdraw', c, item, count, meta, ctx) end
end)
InvHooks.register('occupantMoved', function(fromC, toC, e, ctx)
    if fromC == toC or not ctx or not ctx.src then return end
    if toC.flags and toC.flags.registered then onMove('deposit', toC, e.item, 1, e.metadata, ctx, e.weaponId) end
    if fromC.flags and fromC.flags.registered then onMove('withdraw', fromC, e.item, 1, e.metadata, ctx, e.weaponId) end
end)

CreateThread(function()
    while true do
        Wait(math.max(1, (cfg().webhook or {}).batchSeconds or 5) * 1000)
        local ok, err = pcall(Secondary.flushWebhooks)
        if not ok then print('^1[MULTIinventory] webhook: ' .. tostring(err) .. '^7') end
    end
end)

-- tests only
function Secondary._reset() regs, activity, webhookQueue = {}, {}, {} end
function Secondary._webhookQueue() return webhookQueue end

-- ------------------------------------------------------------
-- vorp-shaped adapter for the vorp_inventory face (plain returns; the vorp_inventory face adds callbacks)
-- ------------------------------------------------------------
SecondaryCompat = SecondaryCompat or {}
local SC = SecondaryCompat

function SC.registerInventory(data) return Secondary.register(data, { resource = GetInvokingResource and GetInvokingResource() or nil }) end
function SC.isCustomInventoryRegistered(id) return Secondary.isRegistered(id) end
function SC.deleteCustomInventory(id)
    return Secondary.unregister(id, cfg().deletePurges ~= false, 'resource:' .. tostring(GetInvokingResource and GetInvokingResource() or '?'))
end
function SC.removeInventory(id) return Secondary.unregister(id, false) end
function SC.updateCustomInventorySlots(id, slots) return Secondary.setSlots(id, slots) end
function SC.getCustomInventorySlots(id) return Secondary.getSlots(id) end
function SC.AddPermissionMoveToCustom(id, job, grade) return SecondaryPerms.addJob(id, 'move', job, grade) end
function SC.AddPermissionTakeFromCustom(id, job, grade) return SecondaryPerms.addJob(id, 'take', job, grade) end
function SC.AddCharIdPermissionMoveToCustom(id, charId, state) return SecondaryPerms.addChar(id, 'move', charId, state) end
function SC.AddCharIdPermissionTakeFromCustom(id, charId, state) return SecondaryPerms.addChar(id, 'take', charId, state) end
function SC.BlackListCustomAny(id, name) return SecondaryPerms.blacklist(id, name, true) end
function SC.setCustomInventoryItemLimit(id, item, limit) return SecondaryPerms.setItemLimit(id, item, limit) end
function SC.setCustomInventoryWeaponLimit(id, weapon, limit) return SecondaryPerms.setWeaponLimit(id, weapon, limit) end
function SC.getCustomInventoryItems(id, charId) return Secondary.getItems(id, charId) end
function SC.getCustomInventoryItemCount(id, name, metadata, charId) return Secondary.count(id, name, metadata, charId) end
function SC.addItemsToCustomInventory(id, items, charId) return (Secondary.addItems(id, items, charId)) end
function SC.removeItemFromCustomInventory(id, name, amount, craftedId, charId) return (Secondary.removeItem(id, name, amount, craftedId, charId)) end
function SC.updateCustomInventoryItem(id, stackId, metadata, amount) return (Secondary.updateItem(id, stackId, metadata, amount)) end
function SC.getCustomInventoryWeapons(id, charId) return Secondary.getWeapons(id, charId) end
function SC.getCustomInventoryWeaponCount(id, name, charId) return Secondary.countWeapons(id, name, charId) end
function SC.addWeaponsToCustomInventory(id, weapons, charId) return (Secondary.addWeapons(id, weapons, charId)) end
function SC.removeWeaponFromCustomInventory(id, name, charId) return (Secondary.removeWeaponByName(id, name, charId)) end
function SC.removeCustomInventoryWeaponById(id, weaponId) return (Secondary.removeWeaponById(id, weaponId)) end
function SC.openInventory(src, id) InvDB.awaitReady() return Secondary.open(src, id) end
function SC.openPlayerInventory(data) InvDB.awaitReady() return SecondarySearch.openFor(data) end

-- ------------------------------------------------------------
-- native exports (exports.MULTIinventory:<Name>)
-- ------------------------------------------------------------
local function res() return GetInvokingResource and GetInvokingResource() or nil end

exports('RegisterSecondary', function(def, update)
    return Secondary.register(def, { update = update == true or (type(def) == 'table' and def.update == true), resource = res() })
end)
exports('UnregisterSecondary', function(id, purge)
    InvDB.awaitReady()
    return Secondary.unregister(id, purge == true, 'resource:' .. tostring(res()))
end)
exports('IsSecondaryRegistered', function(id) return Secondary.isRegistered(id) end)
exports('OpenSecondary', function(src, id, opts) InvDB.awaitReady() return Secondary.open(src, id, opts) end)
exports('OpenSaddlebag', function(src, bagId, label) InvDB.awaitReady() return Secondary.openSaddlebag(src, bagId, label) end)
exports('SecondaryContainerId', function(id, charId) return Secondary.target(id, charId) end)
exports('SetSecondarySlots', function(id, slots) return Secondary.setSlots(id, slots) end)
exports('GetSecondary', function(id)
    local r = regs[tostring(id)]
    if not r then return nil end
    local inst = {}
    for ch in pairs(r.instances) do inst[#inst + 1] = ch end
    return { id = r.id, label = r.label, slots = r.slots, maxWeight = r.maxWeight, kind = r.kind,
             flags = Util.deepcopy(r.flags), perms = Util.deepcopy(r.perms), instances = inst, resource = r.resource }
end)
exports('GetSecondaryViewers', function(id, charId)
    local out = {}
    for s in pairs(State.viewersOf(Secondary.target(id, charId) or tostring(id))) do out[#out + 1] = s end
    return out
end)
exports('GetSecondaryItems', function(id, charId) InvDB.awaitReady() return Secondary.getItems(id, charId) end)
