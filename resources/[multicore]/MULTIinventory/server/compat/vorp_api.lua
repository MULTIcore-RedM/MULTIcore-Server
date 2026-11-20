-- ============================================================
-- MULTIinventory :: server/compat/vorp_api.lua
--
-- The vorp_inventory-shaped API, written from the public
-- docs (docs.vorp-core.com/api-reference/inventory) and from how the callers on
-- this server use each name. No vorp_inventory source was opened.
--
-- Exposed as
--   exports.MULTIinventory:Compat_<name>(...)                 direct (RINGO bridges with
--                                                             inventory = multi, vorp-style args,
--                                                             no self argument)
--   exports.MULTIinventory:Compat__call(name, invoker, ...)   used by the vorp_inventory
--                                                             export aliases (server/multi/faces.lua) so the
--                                                             real calling resource is known
-- Return contract: every function RETURNS its result AND calls cb(result)
-- when a callback is passed. cb runs exactly once and synchronously before the return,
-- also on failure (RINGOjobsandcrafting awaits createWeapon's cb; spooni_nordheim_script
-- reads getUserInventoryItems' cb result right after the call). Callbacks may be plain
-- functions or FXServer function references (tables with __call).
--
-- Built on:
--   items      Inv.*, Stacking.candidates, Registry.get, Usables.register      (core)
--   weapons    Weapons.* (server/weapons/weapons.lua), Ammo.* (server/weapons/ammo.lua)
--   secondary  SecondaryCompat.<vorpName> (server/secondary/inventories.lua, plain returns)
-- Never MBridge.INV (that is this resource -> loop). A part table/function that is missing
-- at call time prints one ^1 line per minute and the export returns its failure value.
--
-- Caller-driven details (call-site survey, compatibility_matrix.csv):
--   * metadata nil / {} / '' / '[]' = "any stack" for subItem / getItem / getItemCount
--   * a callback in the metadata (or amount) slot is accepted: awaitVorp helpers in
--     RINGOitemplacer / RINGOlawmansystem / RINGOdoctorsystem append cb after the last non-nil arg
--   * getItemCount(src, name, cb) (swapped) is accepted; a non-numeric first arg is a container id
--     (RINGOjobsandcrafting storage keys)
--   * item tables carry id = mainid = stack id, count = amount; no `slot` key (kept as gridSlot)
--     because callers read `item.slot or item.id` as the item id (RINGObutcherjob)
--   * subItemById amount defaults to 1 (RINGOcustoms / RINGOhud pass no amount)
--   * vorp_inventory:Server:OnItemUse fires BEFORE a compat-registered usable runs, with the
--     pre-use count (RINGOjobsandcrafting crafting/server/50_food.lua compares counts after 400 ms)
--
-- Compat events (server, Config.Compat.emitVorpEvents):
--   vorp_inventory:Server:OnItemUse                     ({ source, item })
--   vorp_inventory:Server:OnItemCreated / OnItemRemoved ({ count, name, metadata }, src)  player grid,
--                                                       scripted adds/removes and uses (not drags)
--   vorp_inventory:Server:OnItemMovedToCustomInventory / OnItemTakenFromCustomInventory
--                                                       ({ amount, name, id, metadata }, invId, src)
--                                                       from MULTIinventory:secondaryDeposit/Withdraw
-- Client side: client/exports.lua compat section.
-- ============================================================

VorpCompat = VorpCompat or {}
local VC = VorpCompat
local RES = GetCurrentResourceName()

-- ------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------
local CALLER = nil
local function caller() return CALLER or GetInvokingResource() or RES end

local function ready() if InvDB and InvDB.awaitReady then InvDB.awaitReady() end end

---Plain functions and FXServer function references (tables with __call) are callable.
local function callable(f)
    if type(f) == 'function' then return true end
    if type(f) == 'table' then
        local mt = getmetatable(f)
        return type(mt) == 'table' and mt.__call ~= nil
    end
    return false
end
VC.callable = callable

---Return value(s) AND call cb with them (once). A failing callback is reported, never re-thrown.
local function done(cb, ...)
    if callable(cb) then
        local ok, err = pcall(cb, ...)
        if not ok then print(('^1[MULTIinventory] compat callback of %s failed: %s^7'):format(tostring(caller()), tostring(err))) end
    end
    return ...
end

local function ctx(reason, extra)
    local who = caller()
    local c = { reason = reason or 'api', resource = who, actor = 'resource:' .. tostring(who) }
    if extra then for k, v in pairs(extra) do c[k] = v end end
    return c
end

local function debugFail(fn, err)
    if Config.Debug then print(('[MULTIinventory] compat %s by %s refused: %s'):format(fn, tostring(caller()), tostring(err))) end
end

---Metadata filter argument: nil, '', '{}', '[]' or {} mean "any stack".
local function metaFilter(m)
    if m == nil or m == '' or callable(m) then return nil end
    local t = Meta.normalize(m)
    if next(t) == nil then return nil end
    return t
end

local function pctOk(t, pct)
    pct = tonumber(pct)
    if not pct then return true end
    return (t.percentage or 100) >= pct
end

local function toCount(n, default)
    if n == nil then return default end
    return Util.toInt(n)
end

local function shallow(t)
    local o = {}
    for k, v in pairs(t or {}) do o[k] = v end
    return o
end

---vorp-shaped item table from a core item table (6.2). Mutates and returns t.
local function vItem(t)
    if not t then return nil end
    t.mainid = t.id
    t.amount = t.count
    t.description = t.description or t.desc
    t.isDegradable = t.percentage ~= nil
    t.canUse = t.canUse == true
    if t.slot ~= nil then t.gridSlot, t.slot = t.slot, nil end
    t._vorpUseFired = nil
    return t
end
VC.vItem = vItem

---Player source -> that player's grid. A non-numeric string is taken as a container id.
local function playerContainer(src)
    local n = tonumber(src)
    if n then return Inv.resolve(n) end
    if type(src) == 'string' and src ~= '' then return Inv.resolve(src) end
    return nil, 'player_not_loaded'
end

---A callback appended in the metadata slot moves to the cb slot.
local function shiftCb(meta, cb)
    if cb == nil and callable(meta) then return nil, meta end
    return meta, cb
end

-- ------------------------------------------------------------
-- part access
-- ------------------------------------------------------------
local warnedAt = {}
function VC.missing(export, part, name)
    local key = export .. '|' .. name
    local now = os.time()
    if not warnedAt[key] or now - warnedAt[key] >= 60 then
        warnedAt[key] = now
        print(('^1[MULTIinventory] compat %s (called by %s): %s part function %s is not available - returned failure^7')
            :format(export, tostring(caller()), part, name))
    end
    VC.lastMissing = { export = export, part = part, name = name }
end

local PARTS = { weapons = 'Weapons', ammo = 'Ammo', secondary = 'SecondaryCompat' }

---fn or nil (+ error line). part = 'weapons' | 'ammo' | 'secondary'
local function need(export, part, name)
    local t = rawget(_G, PARTS[part])
    local fn = type(t) == 'table' and t[name] or nil
    if type(fn) ~= 'function' then VC.missing(export, PARTS[part], PARTS[part] .. '.' .. name) return nil end
    return fn
end

---Protected part call: found(bool), results...
local function partCall(export, part, name, ...)
    local fn = need(export, part, name)
    if not fn then return false end
    local r = table.pack(pcall(fn, ...))
    if not r[1] then
        print(('^1[MULTIinventory] compat %s: %s.%s failed: %s^7'):format(export, PARTS[part], name, tostring(r[2])))
        return false
    end
    return true, table.unpack(r, 2, r.n)
end

local function okOf(found, ok) return found and ok ~= nil and ok ~= false or false end

---Weapon row of `src` (in their grid) or nil.
local function owned(export, src, weaponId)
    local found, r = partCall(export, 'weapons', 'ownedBy', tonumber(src), tonumber(weaponId))
    if not found then return nil end
    return r
end

local function toTable(r)
    local fn = need('weapon table', 'weapons', 'toTable')
    if not fn or not r then return nil end
    local t = fn(r)
    if t and t.slot ~= nil then t.gridSlot = t.slot end
    return t
end

local function charOf(export, src)
    local found, cid = partCall(export, 'ammo', 'charOf', tonumber(src))
    if not found then return nil end
    return cid
end

-- ============================================================
-- SERVER API
-- ============================================================
local S = {}
VC.server = S

-- ---------------- items (core) ----------------
---addItem(src, name, amount, metadata?, cb?, allowEvent?) -> bool
function S.addItem(src, name, count, metadata, cb, allowEvent)
    local c0 = ctx('api', { noVorpEvent = allowEvent == false })
    metadata, cb = shiftCb(metadata, cb)
    if cb == nil and callable(count) then cb, count = count, nil end
    ready()
    count = toCount(count, 1)
    if not count or count < 1 then return done(cb, false) end
    local c, e0 = playerContainer(src)
    if not c then debugFail('addItem', e0) return done(cb, false) end
    local ok, err = Inv.add(c, name, count, Meta.normalize(metadata), c0)
    if not ok then debugFail('addItem', err) end
    return done(cb, ok == true)
end

local function removeByPercentage(c, name, count, meta, pct, c0)
    local list, have = {}, 0
    for _, e in ipairs(Stacking.candidates(c, name, meta)) do
        if pctOk(Sync.itemTable(e, c), pct) then list[#list + 1] = e; have = have + e.count end
    end
    if have < count then return false, 'not_enough' end
    local left = count
    for _, e in ipairs(list) do
        if left <= 0 then break end
        local n = math.min(left, e.count)
        local ok, err = Inv.removeStack(c, e.id, n, c0)
        if not ok then return false, err end
        left = left - n
    end
    return true
end

---subItem(src, name, amount, metadata?, cb?, allowEvent?, percentage?) -> bool (all or nothing)
function S.subItem(src, name, count, metadata, cb, allowEvent, percentage)
    local c0 = ctx('api', { noVorpEvent = allowEvent == false })
    metadata, cb = shiftCb(metadata, cb)
    if cb == nil and callable(count) then cb, count = count, nil end
    ready()
    count = toCount(count, 1)
    if not count or count < 1 then return done(cb, false) end
    local meta = metaFilter(metadata)
    local ok, err
    local c, e2 = playerContainer(src)
    if not c then ok, err = false, e2
    elseif tonumber(percentage) then ok, err = removeByPercentage(c, name, count, meta, percentage, c0)
    else ok, err = Inv.remove(c, name, count, meta, c0) end
    if not ok then debugFail('subItem', err) end
    return done(cb, ok == true)
end

---getItem(src, name, cb?, metadata?, percentage?) -> item table | nil (first matching stack)
function S.getItem(src, name, cb, metadata, percentage)
    if cb ~= nil and not callable(cb) and metadata == nil then cb, metadata = nil, cb end
    ready()
    local c = playerContainer(src)
    if not c or type(name) ~= 'string' then return done(cb, nil) end
    for _, e in ipairs(Stacking.candidates(c, name, metaFilter(metadata))) do
        local t = Sync.itemTable(e, c)
        if pctOk(t, percentage) then return done(cb, vItem(t)) end
    end
    return done(cb, nil)
end

---getItemByName(src, name, cb?) -> item table | nil  (older name)
function S.getItemByName(src, name, cb)
    return S.getItem(src, name, cb)
end

---getItemCount(src, cb|nil, name, metadata?, percentage?) -> number
function S.getItemCount(src, cb, name, metadata, percentage)
    if type(cb) == 'string' and (name == nil or callable(name)) then cb, name = name, cb end
    ready()
    local c = playerContainer(src)
    if not c or type(name) ~= 'string' then return done(cb, 0) end
    local n = 0
    for _, e in ipairs(Stacking.candidates(c, name, metaFilter(metadata))) do
        if percentage == nil or pctOk(Sync.itemTable(e, c), percentage) then n = n + e.count end
    end
    return done(cb, n)
end

---getItemById(src, id, cb?) -> item table | nil (player grid only)
function S.getItemById(src, id, cb)
    ready()
    local c = playerContainer(src)
    id = tonumber(id)
    if c and id then
        for _, e in pairs(c.stacks) do
            if e.kind ~= 'weapon' and e.id == id then return done(cb, vItem(Sync.itemTable(e, c))) end
        end
    end
    return done(cb, nil)
end

---getItemDB(name, cb?) -> definition | nil
function S.getItemDB(name, cb)
    ready()
    local d = type(name) == 'string' and Registry.get(name) or nil
    if not d then return done(cb, nil) end
    return done(cb, {
        item = d.name, name = d.name, label = d.label, weight = d.weight, limit = d.limit,
        desc = d.desc, description = d.desc, metadata = Util.deepcopy(d.metadata or {}),
        group = d.groupId, groupId = d.groupId, groupName = d.group, rarity = d.rarity, rarityName = d.rarityName,
        type = d.type, usable = d.usable, canUse = d.usable or Usables.isRegistered(d.name),
        can_remove = d.canRemove and 1 or 0, canRemove = d.canRemove, useExpired = d.useExpired,
        degradation = d.degradation, durability = d.durability, instructions = d.instructions, image = d.image,
    })
end

---canCarryItem(src, name, amount, cb?) -> bool (weight + slots + per-item limit)
function S.canCarryItem(src, name, count, cb)
    if cb == nil and callable(count) then cb, count = count, nil end
    if Util.isWeaponName(name) then return S.canCarryWeapons(src, toCount(count, 1), cb, name) end
    ready()
    count = toCount(count, 1)
    if not count or count < 1 then return done(cb, false) end
    local c, e0 = playerContainer(src)
    if not c then debugFail('canCarryItem', e0) return done(cb, false) end
    local ok, err = Inv.canAdd(c, name, count, nil, ctx('api'))
    if not ok then debugFail('canCarryItem', err) end
    return done(cb, ok == true)
end

---canCarryItems(src, totalAmount, cb?) -> bool. No item is named: headroom check only
---(loaded, a free slot, not over capacity). vorp_core /additems runs canCarryItem afterwards.
function S.canCarryItems(src, total, cb)
    if cb == nil and callable(total) then cb, total = total, nil end
    ready()
    local c = playerContainer(src)
    if not c then return done(cb, false) end
    total = toCount(total, 1) or 1
    if total < 1 then return done(cb, true) end
    local free = c.slots - Containers.usedSlots(c)
    local load, cap = Inv.weight(c)
    return done(cb, free > 0 and (cap == nil or load < cap))
end

---getUserInventoryItems(src, cb?) -> { item table, ... } (weapons excluded, by slot)
function S.getUserInventoryItems(src, cb)
    ready()
    local c = playerContainer(src)
    if not c then return done(cb, {}) end
    local out = {}
    for _, t in ipairs(Inv.getStacks(c, { kind = 'item' })) do out[#out + 1] = vItem(t) end
    return done(cb, out)
end

---subItemById(src, itemId, cb?, allowEvent?, amount?) -> bool. amount nil = 1.
function S.subItemById(src, id, cb, allowEvent, amount)
    local c0 = ctx('api', { noVorpEvent = allowEvent == false })
    ready()
    local c = playerContainer(src)
    if not c then return done(cb, false) end
    local n = toCount(amount, 1)
    if not n or n < 1 then return done(cb, false) end
    local ok, err = Inv.removeStack(c, id, n, c0)
    if not ok then debugFail('subItemById', err) end
    return done(cb, ok == true)
end

---setItemMetadata(src, itemId, metadata, amount?, cb?) -> bool. Replaces the metadata;
---amount < stack count splits that many off into a new stack.
function S.setItemMetadata(src, id, metadata, amount, cb)
    local c0 = ctx('api')
    if callable(amount) and cb == nil then cb, amount = amount, nil end
    ready()
    local c = playerContainer(src)
    if not c then return done(cb, false) end
    local n = amount ~= nil and toCount(amount) or nil
    local ok, err = Inv.setMetadata(c, id, Meta.normalize(metadata), n, c0)
    if not ok then debugFail('setItemMetadata', err) end
    return done(cb, ok == true)
end

---registerUsableItem(name, fn(data), resourceName?) -> true
---data = { source, _source, item = item table } + the flat documented fields (id, name, label,
---metadata, count, mainid, ...). OnItemUse is fired before fn (see header).
function S.registerUsableItem(name, fn, owner)
    local who = (type(owner) == 'string' and owner ~= '') and owner or caller()
    if type(name) ~= 'string' or not callable(fn) then return false end
    local function handler(d)
        local it = vItem(shallow(d.item))
        if VC.emitOn() then
            d.item._vorpUseFired = true   -- read by the itemUsed hook below
            TriggerEvent('vorp_inventory:Server:OnItemUse', { source = d.source, item = Util.deepcopy(it) })
        end
        local data = { source = d.source, _source = d.source, item = it }
        for k, v in pairs(it) do if data[k] == nil then data[k] = v end end
        return fn(data)
    end
    return Usables.register(name, handler, who)
end

function S.unRegisterUsableItem(name)
    return Usables.unregister(name)
end

-- ---------------- weapons ----------------
---createWeapon(src, name, ammo?, components?, comps?, cb?, weaponId?, serial?, label?, desc?) -> bool
function S.createWeapon(src, name, ammo, components, comps, cb, weaponId, serial, label, desc)
    local c0 = ctx('api')
    ready()
    if type(name) ~= 'string' then return done(cb, false) end
    local found, ok, err = partCall('createWeapon', 'weapons', 'create', tonumber(src) or src, name:upper(), {
        ammo = ammo, components = type(components) == 'table' and components or {},
        comps = type(comps) == 'table' and comps or {}, id = tonumber(weaponId),
        serial = serial, serialFallback = true, customLabel = label, customDesc = desc,
    }, c0)
    if found and not ok then debugFail('createWeapon', err) end
    return done(cb, okOf(found, ok))
end

---giveWeapon(src, weaponId, target, cb?) -> bool
function S.giveWeapon(src, weaponId, target, cb)
    local c0 = ctx('give')
    ready()
    if not owned('giveWeapon', src, weaponId) then return done(cb, false) end
    local found, ok = partCall('giveWeapon', 'weapons', 'moveTo', tonumber(weaponId), tonumber(target) or target, c0)
    return done(cb, okOf(found, ok))
end

---canCarryWeapons(src, amount, cb?, weaponName?) -> bool
function S.canCarryWeapons(src, amount, cb, weaponName)
    if cb ~= nil and not callable(cb) and weaponName == nil then cb, weaponName = nil, cb end
    ready()
    if not playerContainer(src) then return done(cb, false) end
    local name = type(weaponName) == 'string' and weaponName:upper() or nil
    local found, ok, err = partCall('canCarryWeapons', 'weapons', 'canCarry', tonumber(src), toCount(amount, 1) or 1, name)
    if found and not ok then debugFail('canCarryWeapons', err) end
    return done(cb, okOf(found, ok))
end

---getUserInventoryWeapons(src, cb?) -> { weapon table, ... } (player grid, incl. equipped)
function S.getUserInventoryWeapons(src, cb)
    ready()
    local c = playerContainer(src)
    if not c then return done(cb, {}) end
    local found, list = partCall('getUserInventoryWeapons', 'weapons', 'list', c.id)
    return done(cb, found and type(list) == 'table' and list or {})
end

---getUserWeapon(src, cb?, weaponId) -> weapon table | nil
function S.getUserWeapon(src, cb, weaponId)
    if weaponId == nil and not callable(cb) then cb, weaponId = nil, cb end
    ready()
    return done(cb, toTable(owned('getUserWeapon', src, weaponId)))
end

---getWeaponComponents(src, weaponId, cb?) -> { [category] = component }
function S.getWeaponComponents(src, weaponId, cb)
    ready()
    if not owned('getWeaponComponents', src, weaponId) then return done(cb, {}) end
    local found, comps = partCall('getWeaponComponents', 'weapons', 'getComponents', tonumber(weaponId))
    return done(cb, found and type(comps) == 'table' and comps or {})
end

local function editComps(export, fname, src, weaponId, t)
    if not owned(export, src, weaponId) then return false end
    if type(t) ~= 'table' then return false end
    if next(t) == nil then return true end -- nothing to change (RINGOcustoms re-writes empty sets)
    local found, ok = partCall(export, 'weapons', fname, tonumber(weaponId), t)
    return okOf(found, ok)
end

---addWeaponComponents(src, weaponId, { [category] = component } | { 'COMPONENT_X' }, cb?) -> bool
function S.addWeaponComponents(src, weaponId, comps, cb)
    ready()
    return done(cb, editComps('addWeaponComponents', 'addComponents', src, weaponId, comps))
end

---subWeaponComponents(src, weaponId, { [category] = component } | { 'COMPONENT_X' }, cb?) -> bool
function S.subWeaponComponents(src, weaponId, comps, cb)
    ready()
    return done(cb, editComps('subWeaponComponents', 'subComponents', src, weaponId, comps))
end

---addWeaponComponent(src, weaponId, component, category?, cb?) -> bool
function S.addWeaponComponent(src, weaponId, component, category, cb)
    if cb == nil and callable(category) then cb, category = category, nil end
    ready()
    local t = category ~= nil and { [tostring(category)] = component } or { component }
    return done(cb, editComps('addWeaponComponent', 'addComponents', src, weaponId, t))
end

---subWeaponComponent(src, weaponId, component, category?, cb?) -> bool
function S.subWeaponComponent(src, weaponId, component, category, cb)
    if cb == nil and callable(category) then cb, category = category, nil end
    ready()
    local t = category ~= nil and { [tostring(category)] = component } or { component }
    return done(cb, editComps('subWeaponComponent', 'subComponents', src, weaponId, t))
end

local function setter(export, fname, src, weaponId, value, cb)
    ready()
    if not owned(export, src, weaponId) then return done(cb, false) end
    local found, ok = partCall(export, 'weapons', fname, tonumber(weaponId), value)
    return done(cb, okOf(found, ok))
end
function S.setWeaponCustomLabel(src, weaponId, label, cb)
    return setter('setWeaponCustomLabel', 'setCustomLabel', src, weaponId, label, cb)
end
function S.setWeaponCustomDesc(src, weaponId, desc, cb)
    return setter('setWeaponCustomDesc', 'setCustomDesc', src, weaponId, desc, cb)
end
function S.setWeaponSerialNumber(src, weaponId, serial, cb)
    return setter('setWeaponSerialNumber', 'setSerial', src, weaponId, serial, cb)
end

---subWeapon(src, weaponId, cb?) -> bool. Off the player; the row is kept (ownerless).
function S.subWeapon(src, weaponId, cb)
    local c0 = ctx('api')
    ready()
    if not owned('subWeapon', src, weaponId) then return done(cb, false) end
    local found, ok = partCall('subWeapon', 'weapons', 'detach', tonumber(weaponId), c0)
    return done(cb, okOf(found, ok))
end

---deleteWeapon(src, weaponId, cb?) -> bool. No ownership check: vorp_admin calls subWeapon
---first, after which the weapon is no longer the player's.
function S.deleteWeapon(src, weaponId, cb)
    local c0 = ctx('api')
    ready()
    local found, ok = partCall('deleteWeapon', 'weapons', 'delete', tonumber(weaponId), c0)
    return done(cb, okOf(found, ok))
end

---getUserAmmo(src, cb?) -> { [AMMO_TYPE] = n } (gunbelt)
function S.getUserAmmo(src, cb)
    ready()
    local cid = charOf('getUserAmmo', src)
    if not cid then return done(cb, {}) end
    local found, belt = partCall('getUserAmmo', 'ammo', 'get', cid)
    return done(cb, found and type(belt) == 'table' and Util.deepcopy(belt) or {})
end

---addBullets(src, bulletType, amount, cb?) -> bool (gunbelt)
function S.addBullets(src, bulletType, amount, cb)
    ready()
    local cid = charOf('addBullets', src)
    if not cid or type(bulletType) ~= 'string' then return done(cb, false) end
    local found, ok = partCall('addBullets', 'ammo', 'add', cid, bulletType:upper(), toCount(amount, 0))
    return done(cb, okOf(found, ok))
end

---subBullets(weaponId, bulletType, amount, cb?) -> bool (documented signature: weapon first).
---Taken from the gunbelt of the weapon's owner (rounds loaded in a weapon are managed by the
---weapons part on the ped; no caller on this server).
function S.subBullets(weaponId, bulletType, amount, cb)
    ready()
    local found, r = partCall('subBullets', 'weapons', 'get', tonumber(weaponId))
    if not found or not r or not r.owner or type(bulletType) ~= 'string' then return done(cb, false) end
    local f2, ok = partCall('subBullets', 'ammo', 'remove', r.owner, bulletType:upper(), toCount(amount, 0))
    return done(cb, okOf(f2, ok))
end

---getWeaponBullets(src, weaponId, cb?) -> number (rounds loaded in that weapon)
function S.getWeaponBullets(src, weaponId, cb)
    ready()
    if not owned('getWeaponBullets', src, weaponId) then return done(cb, 0) end
    local found, n = partCall('getWeaponBullets', 'weapons', 'getBullets', tonumber(weaponId))
    return done(cb, found and tonumber(n) or 0)
end

---removeAllUserAmmo(src) -> bool (vorp: void). Gunbelt + magazines of weapons on the ped.
function S.removeAllUserAmmo(src)
    local c0 = ctx('admin')
    ready()
    local cid = charOf('removeAllUserAmmo', src)
    if not cid then return false end
    local found, ok = partCall('removeAllUserAmmo', 'ammo', 'clear', cid, c0)
    return okOf(found, ok)
end

-- ---------------- custom / secondary inventories (SecondaryCompat.*) ----------------
local function sc(export, cb, failValue, ...)
    local found, a, b = partCall(export, 'secondary', export, ...)
    if not found then return done(cb, failValue) end
    return done(cb, a, b)
end

local function scBool(export, cb, ...)
    local found, ok, err = partCall(export, 'secondary', export, ...)
    if found and not ok then debugFail(export, err) end
    return done(cb, okOf(found, ok))
end

---registerInventory(data) -> bool. Idempotent ('exists' counts as success).
function S.registerInventory(data)
    caller()
    if type(data) ~= 'table' or data.id == nil or tostring(data.id) == '' then return false end
    local found, ok, err = partCall('registerInventory', 'secondary', 'registerInventory', data)
    return found and (ok == true or err == 'exists') or false
end

function S.isCustomInventoryRegistered(id, cb)
    local found, v = partCall('isCustomInventoryRegistered', 'secondary', 'isCustomInventoryRegistered', id)
    return done(cb, found and v == true or false)
end

---openInventory(src, invId?) -> bool (vorp: void). No id = the player's own inventory.
function S.openInventory(src, invId)
    caller()
    ready()
    if not tonumber(src) then return false end
    local found, ok, err = partCall('openInventory', 'secondary', 'openInventory', tonumber(src), invId)
    if found and not ok then debugFail('openInventory', err) end
    return okOf(found, ok)
end

---closeInventory(src, invId?) -> true (core)
function S.closeInventory(src, _invId)
    src = tonumber(src)
    if not src then return false end
    return State.close(src, true)
end

function S.deleteCustomInventory(invId) return scBool('deleteCustomInventory', nil, invId) end
function S.removeInventory(invId) return scBool('removeInventory', nil, invId) end
function S.updateCustomInventorySlots(invId, slots) return scBool('updateCustomInventorySlots', nil, invId, tonumber(slots)) end
function S.getCustomInventorySlots(invId, cb) return sc('getCustomInventorySlots', cb, nil, invId) end
function S.AddPermissionMoveToCustom(invId, job, grade) return scBool('AddPermissionMoveToCustom', nil, invId, job, grade) end
function S.AddPermissionTakeFromCustom(invId, job, grade) return scBool('AddPermissionTakeFromCustom', nil, invId, job, grade) end
function S.AddCharIdPermissionMoveToCustom(invId, charId, state) return scBool('AddCharIdPermissionMoveToCustom', nil, invId, charId, state) end
function S.AddCharIdPermissionTakeFromCustom(invId, charId, state) return scBool('AddCharIdPermissionTakeFromCustom', nil, invId, charId, state) end
function S.BlackListCustomAny(invId, name) return scBool('BlackListCustomAny', nil, invId, name) end
function S.setCustomInventoryItemLimit(invId, item, limit, cb) return scBool('setCustomInventoryItemLimit', cb, invId, item, limit) end
function S.setCustomInventoryWeaponLimit(invId, weapon, limit, cb) return scBool('setCustomInventoryWeaponLimit', cb, invId, weapon, limit) end

---getCustomInventoryItems(invId, cb?) -> { item table, ... }
function S.getCustomInventoryItems(invId, cb)
    ready()
    local found, list = partCall('getCustomInventoryItems', 'secondary', 'getCustomInventoryItems', invId)
    local out = {}
    if found and type(list) == 'table' then for _, t in ipairs(list) do out[#out + 1] = vItem(shallow(t)) end end
    return done(cb, out)
end

---getCustomInventoryItemCount(invId, name, cb?, metadata?) -> number
function S.getCustomInventoryItemCount(invId, name, cb, metadata)
    ready()
    local found, n = partCall('getCustomInventoryItemCount', 'secondary', 'getCustomInventoryItemCount', invId, name, metaFilter(metadata))
    return done(cb, found and tonumber(n) or 0)
end

---addItemsToCustomInventory(invId, { { name, amount, metadata? } }, charId?, cb?) -> bool (all or nothing)
function S.addItemsToCustomInventory(invId, items, charId, cb)
    if callable(charId) and cb == nil then cb, charId = charId, nil end
    ready()
    return scBool('addItemsToCustomInventory', cb, invId, items, tonumber(charId) or charId)
end

---removeItemFromCustomInventory(invId, name, amount, itemId?, cb?) -> bool
function S.removeItemFromCustomInventory(invId, name, amount, itemId, cb)
    if callable(itemId) and cb == nil then cb, itemId = itemId, nil end
    ready()
    return scBool('removeItemFromCustomInventory', cb, invId, name, toCount(amount, 1), tonumber(itemId))
end

---updateCustomInventoryItem(invId, itemId, metadata, amount?, cb?) -> bool
function S.updateCustomInventoryItem(invId, itemId, metadata, amount, cb)
    if callable(amount) and cb == nil then cb, amount = amount, nil end
    ready()
    return scBool('updateCustomInventoryItem', cb, invId, tonumber(itemId), Meta.normalize(metadata), amount ~= nil and toCount(amount) or nil)
end

---getCustomInventoryWeapons(invId, cb?) -> { weapon table, ... }
function S.getCustomInventoryWeapons(invId, cb)
    ready()
    local found, list = partCall('getCustomInventoryWeapons', 'secondary', 'getCustomInventoryWeapons', invId)
    return done(cb, found and type(list) == 'table' and list or {})
end

---getCustomInventoryWeaponCount(invId, weaponName, cb?) -> number
function S.getCustomInventoryWeaponCount(invId, weaponName, cb)
    ready()
    local found, n = partCall('getCustomInventoryWeaponCount', 'secondary', 'getCustomInventoryWeaponCount', invId, weaponName)
    return done(cb, found and tonumber(n) or 0)
end

---removeCustomInventoryWeaponById(invId, weaponId, cb?) -> bool
function S.removeCustomInventoryWeaponById(invId, weaponId, cb)
    ready()
    return scBool('removeCustomInventoryWeaponById', cb, invId, tonumber(weaponId))
end

---removeWeaponFromCustomInventory(invId, weaponName, cb?) -> bool (first of that name)
function S.removeWeaponFromCustomInventory(invId, weaponName, cb)
    ready()
    return scBool('removeWeaponFromCustomInventory', cb, invId, weaponName)
end

---addWeaponsToCustomInventory(invId, { { name, serial_number?, custom_label?, custom_desc?, components? } },
---charId?, cb?) -> bool
---A `components` MAP ({ [category] = component }) is the customisation set: RINGOhousingV2's
---handover passes loadout.comps under `components`. It is moved to `comps`; an array stays
---`components` (attachments).
function S.addWeaponsToCustomInventory(invId, weapons, charId, cb)
    if callable(charId) and cb == nil then cb, charId = charId, nil end
    ready()
    if type(weapons) ~= 'table' then return done(cb, false) end
    local list = {}
    for i, w in ipairs(weapons.name and { weapons } or weapons) do
        local x = shallow(w)
        local comp = x.components
        if type(comp) == 'table' and x.comps == nil and next(comp) ~= nil and comp[1] == nil then
            x.comps, x.components = comp, {}
        end
        list[i] = x
    end
    return scBool('addWeaponsToCustomInventory', cb, invId, list, tonumber(charId) or charId)
end

---openPlayerInventory({ source, target, title, blacklist?, itemsLimit?, timeout? }) -> bool
function S.openPlayerInventory(data)
    caller()
    if type(data) ~= 'table' then return false end
    local found, ok, err = partCall('openPlayerInventory', 'secondary', 'openPlayerInventory', data)
    if found and not ok then debugFail('openPlayerInventory', err) end
    return okOf(found, ok)
end

-- context-menu event allow list (documented; no caller today; the UI may read VorpCompat.contextEvents)
VC.contextEvents = VC.contextEvents or {}
local function eventList(e) return type(e) == 'table' and e or { e } end
function S.addAllowedContextMenuEvent(event, resource)
    for _, e in ipairs(eventList(event)) do VC.contextEvents[tostring(e)] = resource or caller() end
    return true
end
function S.removeAllowedContextMenuEvent(event, _resource)
    for _, e in ipairs(eventList(event)) do VC.contextEvents[tostring(e)] = nil end
    return true
end
function S.removeAllowedContextMenuEvents(events, resource)
    return S.removeAllowedContextMenuEvent(events, resource)
end

-- ============================================================
-- name lists + exports
-- ============================================================
VC.NAMES = {}
for name in pairs(S) do VC.NAMES[#VC.NAMES + 1] = name end
table.sort(VC.NAMES)

---The 33 exports used on this server (compatibility_matrix.csv).
VC.USED = {
    'addItem', 'subItem', 'getItem', 'getItemCount', 'registerUsableItem', 'canCarryItem', 'getUserInventoryItems',
    'closeInventory', 'subItemById', 'getItemDB', 'registerInventory', 'openInventory', 'createWeapon',
    'canCarryWeapons', 'isCustomInventoryRegistered', 'getItemByName', 'getWeaponComponents',
    'AddCharIdPermissionTakeFromCustom', 'getUserInventoryWeapons', 'addWeaponComponents', 'subWeaponComponents',
    'deleteCustomInventory', 'removeAllUserAmmo', 'canCarryItems', 'subWeapon', 'deleteWeapon',
    'setWeaponCustomLabel', 'setWeaponCustomDesc', 'setItemMetadata', 'removeCustomInventoryWeaponById',
    'addWeaponsToCustomInventory', 'BlackListCustomAny', 'updateCustomInventorySlots',
}

for name, fn in pairs(S) do
    exports('Compat_' .. name, function(...)
        CALLER = GetInvokingResource()
        return fn(...)
    end)
end

---In-resource call with the real calling resource (the vorp_inventory export aliases use it).
function VC.call(name, invoker, ...)
    local fn = S[name]
    if not fn then return nil end
    local prev = CALLER
    CALLER = (type(invoker) == 'string' and invoker ~= '') and invoker or prev
    local r = table.pack(pcall(fn, ...))
    CALLER = prev
    if not r[1] then
        print(('^1[MULTIinventory] vorp_inventory %s (called by %s) failed: %s^7'):format(name, tostring(invoker), tostring(r[2])))
        return nil
    end
    return table.unpack(r, 2, r.n)
end

exports('Compat__call', function(name, invoker, ...)
    local fn = S[name]
    if not fn then
        print(('^1[MULTIinventory] compat: unknown vorp_inventory export "%s" (called by %s)^7'):format(tostring(name), tostring(invoker)))
        return nil
    end
    CALLER = (type(invoker) == 'string' and invoker ~= '') and invoker or GetInvokingResource()
    return fn(...)
end)

-- ============================================================
-- compat events (server)
-- ============================================================
local function emitOn() return not (Config.Compat and Config.Compat.emitVorpEvents == false) end
VC.emitOn = emitOn

-- Compat-registered usables fired OnItemUse before their handler (registerUsableItem);
-- natively registered ones (RegisterUsable) get it here, after the use.
InvHooks.register('itemUsed', function(src, itemTable, _ctx)
    if not emitOn() or itemTable._vorpUseFired then return end
    TriggerEvent('vorp_inventory:Server:OnItemUse', { source = src, item = vItem(Util.deepcopy(itemTable)) })
end)

local DRAG = { move = true, split = true, merge = true, sort = true }

local function ownerSrcOf(c)
    return c.ownerCharId and State.srcOfChar(c.ownerCharId) or nil
end

InvHooks.register('itemAdded', function(c, item, count, meta, cx)
    if not emitOn() or c.kind ~= 'player' or (cx and (cx.noVorpEvent or DRAG[cx.reason])) then return end
    local src = ownerSrcOf(c)
    if src then TriggerEvent('vorp_inventory:Server:OnItemCreated', { count = count, name = item, metadata = meta or {} }, src) end
end)

InvHooks.register('itemRemoved', function(c, item, count, meta, cx)
    if not emitOn() or c.kind ~= 'player' or (cx and (cx.noVorpEvent or DRAG[cx.reason])) then return end
    local src = ownerSrcOf(c)
    if src then TriggerEvent('vorp_inventory:Server:OnItemRemoved', { count = count, name = item, metadata = meta or {} }, src) end
end)

-- secondary part local events -> vorp names (the secondary part does not emit vorp names itself)
local function customEvent(vorpName)
    return function(src, baseId, item, _containerId)
        if not emitOn() or type(item) ~= 'table' then return end
        TriggerEvent(vorpName, { amount = item.amount, name = item.name, id = item.id, metadata = item.metadata or {} }, baseId, src)
    end
end
AddEventHandler('MULTIinventory:secondaryDeposit', customEvent('vorp_inventory:Server:OnItemMovedToCustomInventory'))
AddEventHandler('MULTIinventory:secondaryWithdraw', customEvent('vorp_inventory:Server:OnItemTakenFromCustomInventory'))

-- client getServerItem(name) -> definition (client/exports.lua compat section)
Actions.register('compat_itemdef', function(_src, d)
    local name = type(d) == 'table' and d.name or nil
    if type(name) ~= 'string' then return false, 'unknown_item' end
    local def = S.getItemDB(name)
    if not def then return false, 'unknown_item' end
    return true, def
end)
