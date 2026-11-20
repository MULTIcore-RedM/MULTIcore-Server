-- ============================================================
-- MULTIinventory :: server/rsg/rsg_api.lua
--
-- RSG-Core support. Everything runs on the same core as VORP (Inv.*, State.*,
-- Containers.*, Usables.*); this file only adapts the RSG side:
--
--  1. Item source   : RSGCore.Shared.Items -> Registry (Registry.put), weights g -> kg,
--                     rsg `decay` (minutes) -> degradation, `unique` -> one unit per slot,
--                     `category` -> group key. Re-synced when rsg-core updates its items.
--  2. Lifecycle     : RSGCore:Server:PlayerLoaded (via bridge/) attaches, OnPlayerUnload
--                     detaches; capacity = PlayerData.weight (provider hook 'capacity').
--  3. Player data   : Player.PlayerData.items is kept as a read-only mirror of the
--                     RINGO player grid; Player.Functions gets AddItem/RemoveItem/... when
--                     rsg-core lacks them. Money/metadata come through the house bridge
--                     (bridge/server.lua, Core.getUser -> money/gold/charinfo).
--  4. Usable items  : items registered with RSGCore.Functions.CreateUseableItem are used
--                     from the RINGO UI/hotbar; net event rsg-inventory:server:useItem.
--  5. rsg-inventory-shaped API: exports.MULTIinventory:Rsg_<Name>(...) with rsg-inventory's
--                     public parameter order and return values, and
--                     exports.MULTIinventory:Rsg__call(name, invoker, ...) used by the aliases
--                     (the rsg-inventory export aliases in server/multi/faces.lua) so the REAL
--                     calling resource is known (audit log ctx.resource, usable owner).
--                     Return contract: every function RETURNS its result; a callable passed
--                     AFTER the documented parameters is also called once with the results
--                     (same rule as the vorp compat layer; rsg callers never pass one).
--  6. rsg events for listeners on RINGO's own UI uses/closes (rsg-inventory semantics):
--       net 'rsg-inventory:server:useItem' (item)        - RINGOplayercore, RINGOjobsandcrafting
--       net 'rsg-inventory:server:closeInventory' (id)   - RINGOitemplacer
--     A net event needs a real `source`, so the server asks the player's client to send it:
--     MULTIinventory:rsg:useEcho / :closedEcho -> client/multi/faces.lua -> TriggerServerEvent.
--     Echoed uses carry a one-time server token (`_multiEcho`) so this file does not use the
--     item a second time; any other useItem event (third-party client code) IS a use.
--
-- Clean room: API names and documented behaviour only (rsg-inventory is GPL v3; no code
-- copied; the API surface comes from how the RINGO scripts call it - compatibility_matrix.csv
-- rsg rows). Units: every weight that crosses this API is in rsg units (grams,
-- Config.Rsg.weightUnit per kg); metadata is called `info` on the rsg side.
--
-- Item table returned (rsg shape):
--   { name, amount, info, label, description, weight (per unit, g), type, unique, useable,
--     image, shouldClose, slot, combinable, id (RINGO stack id) }
--   decaying items carry info.quality (0-100, from RINGO's expiry) + info.lastUpdate.
-- ============================================================

RsgInv = RsgInv or {}

local API = {}
local RES = GetCurrentResourceName()
local USABLE_OWNER = RES .. ':rsg'

local DEFAULTS = {
    weightUnit = 1000, categoryGroups = {}, forceDropWhenFull = true, mirrorPlayerItems = true,
    playerMethods = true, bridgeUsables = true, blockUseWhenDown = true, netUseEvent = true,
    emitRemovedEvent = true, emitItemBox = false, stashDefaults = { slots = 100, maxweight = 2000000 },
    echoUseEvent = true, echoCloseEvent = true, silentNotUsable = true, mirrorSlots = true,
}

-- calling resource of the current export call (Rsg__call / Rsg_<name>); nil = internal
local CALLER = nil
local function caller() return CALLER or (GetInvokingResource and GetInvokingResource()) or RES end
RsgInv.caller = caller

local function C(k)
    local c = Config and Config.Rsg
    if c and c[k] ~= nil then return c[k] end
    return DEFAULTS[k]
end
RsgInv.cfg = C

local function isRsg() return MBridge ~= nil and MBridge.IsRsg == true end
RsgInv.isRsg = isRsg

local function unit() return tonumber(C('weightUnit')) or 1000 end
local function toKg(g) return (tonumber(g) or 0) / unit() end
local function toG(kg) return Util.round((tonumber(kg) or 0) * unit(), 3) end

local function ready() InvDB.awaitReady() end

local function ctxOf(reason, src)
    local who = caller()
    return { reason = 'api', src = src, note = type(reason) == 'string' and reason or nil,
             resource = who, actor = 'resource:' .. tostring(who) }
end

-- ------------------------------------------------------------
-- rsg-core access
-- ------------------------------------------------------------
local coreObj
function RsgInv.core()
    if coreObj then return coreObj end
    if not isRsg() then return nil end
    local ok, obj = pcall(function() return exports['rsg-core']:GetCoreObject() end)
    if ok and type(obj) == 'table' then coreObj = obj end
    return coreObj
end

local function getPlayer(src)
    src = tonumber(src)
    local core = RsgInv.core()
    if not src or not core or not core.Functions or not core.Functions.GetPlayer then return nil end
    local ok, p = pcall(core.Functions.GetPlayer, src)
    return ok and p or nil
end
RsgInv.getPlayer = getPlayer

---This resource answers as rsg-inventory itself (fxmanifest `provide 'rsg-inventory'`).
local function providesRsgInventory()
    local n = GetNumResourceMetadata and GetNumResourceMetadata(RES, 'provide') or 0
    for i = 0, n - 1 do
        if GetResourceMetadata(RES, 'provide', i) == 'rsg-inventory' then return true end
    end
    return false
end
local PROVIDES_RSG = providesRsgInventory()

---The real rsg-inventory is running next to MULTIinventory (never true while this resource
---provides the name: the runtime would not start both).
local function realRsgInventory()
    if PROVIDES_RSG then return false end
    local s = GetResourceState('rsg-inventory')
    if s ~= 'started' and s ~= 'starting' then return false end
    local author = GetResourceMetadata and GetResourceMetadata('rsg-inventory', 'author', 0) or nil
    return author ~= 'RINGO'
end
RsgInv.realRsgInventory = realRsgInventory

---rsg stash names live under 'stash:<name>' (the MULTIinventory id convention); ids that already
---carry a known prefix stay as they are. 'otherplayer-<id>' -> that player's server id.
local KNOWN_PREFIX = { player = true, equip = true, stash = true, trunk = true, glovebox = true, custom = true, drop = true }
function RsgInv.stashId(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return identifier end
    if identifier:match('^%d+$') then return identifier end
    local o = identifier:match('^otherplayer%-(%d+)$')
    if o then return tonumber(o) end
    local p = identifier:match('^(%a+):')
    if p and KNOWN_PREFIX[p] then return identifier end
    if Containers.isDefined(identifier) or Containers.peek(identifier) then return identifier end
    return 'stash:' .. identifier
end

-- ------------------------------------------------------------
-- 1. Item source: RSGCore.Shared.Items -> Registry
-- ------------------------------------------------------------
local rsgDefs = {}   -- [name] = raw rsg definition (as rsg-core holds it)

local function defOf(name)
    if type(name) ~= 'string' or name == '' then return nil, nil end
    local all = Registry.all()
    if all[name] then return all[name], name end
    local low = name:lower()
    if all[low] then return all[low], low end
    return nil, low
end
RsgInv.defOf = defOf

function RsgInv.syncItems()
    if not isRsg() then return 0 end
    local core = RsgInv.core()
    local items = core and core.Shared and core.Shared.Items
    if type(items) ~= 'table' then return 0 end
    local opts = { weightUnit = unit(), categoryGroups = C('categoryGroups') or {} }
    local all = Registry.all()
    local n = 0
    for key, raw in pairs(items) do
        local nd = RsgItems.normalize(key, raw, opts)   -- server/rsg/items_reader.lua
        if nd then
            local name = nd.name
            rsgDefs[name] = raw
            local cur = all[name]
            if not cur or cur._rsg then   -- never replace a definition from the `items` table
                local d = Registry.put(nd)
                d._rsg = true
                d.rsgType = nd.rsgType
                d.unique = nd.unique
                d.removeWhenExpired = nd.removeWhenExpired   -- per-item rsg `delete` (core CR)
                if nd.group then d.group = nd.group end
                n = n + 1
            end
        end
    end
    return n
end

---raw rsg-core definition of an item (as RSGCore.Shared.Items holds it) or nil
function RsgInv.rawDef(name) return rsgDefs[name] end

---Registers ONE rsg item definition in the registry right away (RegisterItem export).
function RsgInv.syncOne(key, raw)
    if not isRsg() or type(raw) ~= 'table' then return false end
    local nd = RsgItems.normalize(key, raw, { weightUnit = unit(), categoryGroups = C('categoryGroups') or {} })
    if not nd then return false end
    rsgDefs[nd.name] = raw
    local cur = Registry.all()[nd.name]
    if cur and not cur._rsg then return true end   -- the `items` table wins
    local d = Registry.put(nd)
    d._rsg = true
    d.rsgType = nd.rsgType
    d.unique = nd.unique
    d.removeWhenExpired = nd.removeWhenExpired
    if nd.group then d.group = nd.group end
    return true
end

-- ------------------------------------------------------------
-- conversions
-- ------------------------------------------------------------
local function sameName(a, b) return tostring(a):lower() == tostring(b):lower() end

---RINGO entry -> rsg item table.
local function rsgItem(e)
    if not e then return nil end
    if e.kind == 'weapon' then
        local name = tostring(e.item):lower()
        local raw = rsgDefs[name] or {}
        local info = Util.deepcopy(e.metadata or {})
        -- rsg keeps serial / labels / parts in the weapon item's info (the RINGO RSG bridge
        -- reads info.serie, info.custom_label, info.components)
        local r = Weapons and Weapons.get and e.weaponId and Weapons.get(e.weaponId) or nil
        if r then
            info.serie = r.serial
            info.custom_label = r.customLabel
            info.custom_desc = r.customDesc
            info.components = Util.deepcopy(r.comps or {})
            info.attachments = Util.deepcopy(r.components or {})
            info.ammo = Util.deepcopy(r.ammo or {})
            if Weapons.conditionPct then info.quality = Weapons.conditionPct(r) end
        end
        info.serie = info.serie or info.serial or e.serial
        return { name = name, amount = 1, info = info, label = e.label or raw.label or name,
                 description = raw.description or '', weight = toG(e.weight), type = raw.type or 'weapon',
                 unique = true, useable = true, image = raw.image or (name .. '.png'),
                 shouldClose = raw.shouldClose ~= false, slot = e.slot, combinable = raw.combinable,
                 id = e.id, weaponId = e.weaponId }
    end
    local d = Inv.def(e.item)
    local raw = rsgDefs[e.item] or {}
    local info = Util.deepcopy(e.metadata or {})
    local pct = Sync.percentage(e, d)
    if pct and (info.quality == nil or type(info.quality) == 'number') then
        info.quality = pct
        info.lastUpdate = Util.now()
    end
    return {
        name = e.item, amount = e.count, info = info,
        label = info.label or d.label or e.item,
        description = info.description or d.desc or raw.description or '',
        weight = toG(Weight.unit(d, e.metadata)),
        type = raw.type or 'item', unique = raw.unique == true,
        useable = raw.useable == true or Usables.isRegistered(e.item),
        image = info.image or raw.image or d.image or (e.item .. '.png'),
        shouldClose = raw.shouldClose, slot = e.slot, combinable = raw.combinable, id = e.id,
    }
end
RsgInv.rsgItem = rsgItem

local function itemsMap(c)
    local out = {}
    if not c then return out end
    for slot, e in pairs(c.stacks) do out[slot] = rsgItem(e) end
    return out
end
RsgInv.itemsMap = itemsMap

---rsg info -> RINGO metadata (+ decayAt from a numeric rsg quality on decaying items).
local function fromInfo(name, info)
    local meta = Util.deepcopy(Meta.normalize(info))
    local d = Registry.all()[name]
    local decayAt
    if d and (tonumber(d.degradation) or 0) > 0 and type(meta.quality) == 'number' then
        local q = Util.clamp(meta.quality, 0, 100)
        decayAt = Util.now() + math.floor(d.degradation * 60 * q / 100)
        meta.quality, meta.lastUpdate = nil, nil
    elseif type(meta.quality) == 'number' and meta.lastUpdate ~= nil then
        meta.lastUpdate = nil   -- rsg decay clock without decay: drop the clock, keep the value
    end
    return meta, decayAt
end
RsgInv.fromInfo = fromInfo

---A player rsg-core already knows but RINGO has not attached yet (RSGCore:Server:PlayerLoaded
---handlers run in the next tick; RINGOmulticharacterV2 gives starter items right after login):
---attach now so the call does not fail with player_not_loaded.
local function attachNow(src)
    if not isRsg() or State.get(src) or not getPlayer(src) then return end
    local ok, user = pcall(function() return MBridge.Core.getUser(src) end)
    local char = ok and user and user.getUsedCharacter
    if type(char) == 'function' then char = char() end
    if char and State._attachFromChar then State._attachFromChar(src, char) end
end
RsgInv.attachNow = attachNow

local function resolve(identifier)
    if identifier == nil then return nil, 'unknown_container' end
    local t = RsgInv.stashId(identifier)
    if type(t) == 'string' and t:match('^%d+$') then t = tonumber(t) end
    if type(t) == 'number' then
        t = math.tointeger(t) or t
        attachNow(t)
    end
    return Inv.resolve(t)
end

local function ownerSrc(c)
    return c and c.kind == 'player' and c.ownerCharId and State.srcOfChar(c.ownerCharId) or nil
end

local function firstEntry(c, name)
    if not c then return nil end
    for s = 1, c.slots do
        local e = c.stacks[s]
        if e and sameName(e.item, name) then return e end
    end
    return nil
end

local function entriesOf(c, name)
    local out = {}
    if not c then return out end
    for s = 1, c.slots do
        local e = c.stacks[s]
        if e and sameName(e.item, name) then out[#out + 1] = e end
    end
    return out
end

local function countAll(c, name)
    local n = 0
    for _, e in ipairs(entriesOf(c, name)) do n = n + (e.count or 1) end
    return n
end

local function validAmount(a)
    return type(a) == 'number' and a > 0 and a == math.floor(a) and a < 2 ^ 31
end

-- ------------------------------------------------------------
-- weapons: delegated to the weapons part (Weapons.* in server/weapons/weapons.lua)
-- ------------------------------------------------------------
local function part(fn)
    local f = Weapons and Weapons[fn]
    if type(f) ~= 'function' then
        print(('^1[MULTIinventory] rsg: weapons part function Weapons.%s is not available^7'):format(fn))
        return nil
    end
    return f
end

local function isMap(t) return type(t) == 'table' and next(t) ~= nil and t[1] == nil end

---rsg info -> Weapons.create opts. rsg keeps the customisation map in info.components
---({ [category] = component }) = RINGO `comps`; an array is attachments = RINGO `components`.
local function weaponOpts(info, slot)
    info = type(info) == 'table' and info or {}
    local comps, attachments = {}, {}
    if isMap(info.components) then comps = info.components
    elseif type(info.components) == 'table' then attachments = info.components end
    if type(info.attachments) == 'table' then attachments = info.attachments end
    local meta = {}
    for k, v in pairs(info) do
        if k ~= 'serie' and k ~= 'serial' and k ~= 'components' and k ~= 'attachments' and k ~= 'custom_label'
            and k ~= 'custom_desc' and k ~= 'ammo' and k ~= 'quality' then meta[k] = v end
    end
    return {
        serial = info.serie or info.serial, serialFallback = true,
        customLabel = info.custom_label, customDesc = info.custom_desc,
        components = attachments, comps = comps, ammo = type(info.ammo) == 'table' and info.ammo or nil,
        metadata = meta, slot = slot,
    }
end

local function giveWeapons(c, name, amount, slot, info, ctx)
    local create, delete = part('create'), part('delete')
    if not create then return false, 'no_weapons' end
    local made = {}
    for i = 1, amount do
        local ok, r = create(c, name:upper(), weaponOpts(info, i == 1 and slot or nil), ctx)
        if not ok and i == 1 and slot ~= nil and (r == 'slot_taken' or r == 'bad_slot') then
            ok, r = create(c, name:upper(), weaponOpts(info, nil), ctx)   -- preferred slot busy: auto
        end
        if not ok then
            for _, w in ipairs(made) do if delete then delete(w.id, { reason = 'api', note = 'rollback' }) end end
            return false, r
        end
        made[#made + 1] = r
    end
    return true, made
end

local function removeWeapons(c, name, amount, slot, ctx)
    local delete = part('delete')
    if not delete then return false, 'no_weapons' end
    local list = {}
    for s, e in pairs(c.stacks) do
        if e.kind == 'weapon' and sameName(e.item, name) and (not slot or s == slot) then list[#list + 1] = e end
    end
    if #list < amount then return false, 'not_enough' end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    for i = 1, amount do
        local ok, err = InvHooks.check('canRemove', c, list[i], 1, ctx)
        if not ok then return false, err end
    end
    for i = 1, amount do
        local ok, err = delete(list[i].weaponId, ctx)
        if not ok then return false, err end
    end
    return true
end

---rsg SetItemData(.., 'info', info) on a weapon: labels, serial and parts go to the weapons part.
local function setWeaponInfo(weaponId, info)
    if type(info) ~= 'table' then return false end
    local r = Weapons and Weapons.get and Weapons.get(weaponId)
    if not r then return false end
    if info.custom_label ~= r.customLabel and part('setCustomLabel') then Weapons.setCustomLabel(weaponId, info.custom_label) end
    if info.custom_desc ~= r.customDesc and part('setCustomDesc') then Weapons.setCustomDesc(weaponId, info.custom_desc) end
    local serial = info.serie or info.serial
    if serial and serial ~= r.serial and part('setSerial') then
        if not Weapons.setSerial(weaponId, serial) then return false end
    end
    if type(info.components) == 'table' and (isMap(info.components) or next(info.components) == nil) then
        local want, have = info.components, r.comps or {}
        local gone = {}
        for k, v in pairs(have) do if want[k] == nil or tostring(want[k]) ~= tostring(v) then gone[k] = v end end
        if next(gone) ~= nil and part('subComponents') then Weapons.subComponents(weaponId, gone) end
        local add = {}
        for k, v in pairs(want) do if tostring(have[k]) ~= tostring(v) then add[k] = v end end
        if next(add) ~= nil and part('addComponents') then Weapons.addComponents(weaponId, add) end
    end
    return true
end

-- ------------------------------------------------------------
-- add / remove core
-- ------------------------------------------------------------
local function addUnique(c, name, amount, meta, ctx, decayAt)
    local ok, err = Inv.canAdd(c, name, amount, meta, ctx)
    if not ok then return false, err end
    if c.slots - Containers.usedSlots(c) < amount then return false, 'slots' end
    local placed = {}
    for _ = 1, amount do
        local ok2, res = Inv.add(c, name, 1, meta, ctx, { slot = Containers.freeSlot(c), decayAt = decayAt })
        if not ok2 then
            for _, p in ipairs(placed) do Inv.removeStack(c, p.id, nil, { reason = 'api', note = 'rollback' }) end
            return false, res
        end
        placed[#placed + 1] = res[1]
    end
    return true, placed
end

local function addTo(c, _target, name, amount, slot, info, ctx)
    local d = Registry.all()[name]
    if Util.isWeaponName(name) then
        slot = tonumber(slot)
        return giveWeapons(c, name, amount, slot and math.tointeger(slot) or nil, info, ctx)
    end
    local meta, decayAt = fromInfo(name, info)
    if d and d.unique then return addUnique(c, name, amount, meta, ctx, decayAt) end
    slot = tonumber(slot)
    local ok, res
    if slot and slot >= 1 and slot <= c.slots and slot == math.floor(slot) then
        ok, res = Inv.add(c, name, amount, meta, ctx, { slot = math.tointeger(slot), decayAt = decayAt })
        if ok then return ok, res end
        if res == 'weight' or res == 'limit' then return ok, res end
        -- rsg: a preferred slot that cannot take the item falls back to auto placement
    end
    return Inv.add(c, name, amount, meta, ctx, { decayAt = decayAt })
end

-- shared with server/multi/api.lua (MULTIinventory export API)
RsgInv.addTo, RsgInv.giveWeapons, RsgInv.removeWeapons = addTo, giveWeapons, removeWeapons
RsgInv.setWeaponInfo, RsgInv.resolve = setWeaponInfo, resolve
RsgInv.toG, RsgInv.toKg = toG, toKg

-- ------------------------------------------------------------
-- 5. rsg-inventory-shaped API
-- ------------------------------------------------------------

---AddItem(identifier, item, amount?, slot?, info?, reason?, noForceDrop?) -> bool, 'dropped'|nil
function API.AddItem(identifier, item, amount, slot, info, reason, noForceDrop)
    ready()
    amount = tonumber(amount) or 1
    if type(item) ~= 'string' or not validAmount(amount) then return false end
    local d, name = defOf(item)
    if not d and Util.isWeaponName(item) then name = item:lower() end   -- weapons: WeaponDefs decide
    if not d and not Util.isWeaponName(item) then return false end
    local c = resolve(identifier)
    if not c then return false end
    local target = (c.kind == 'player' and ownerSrc(c)) or c.id
    local ok, err = addTo(c, target, name, amount, slot, info, ctxOf(reason, ownerSrc(c)))
    if ok then RsgInv.pushNow(c) return true end
    if c.kind == 'player' and not noForceDrop and C('forceDropWhenFull')
        and (err == 'weight' or err == 'slots' or err == 'limit') then
        local src = ownerSrc(c)
        if src and API.ForceDropItem(src, name, amount, info, reason or ('inventory full - ' .. err)) then
            return true, 'dropped'
        end
    end
    return false
end

---RemoveItem(identifier, item, amount?, slot?, reason?, isMove?) -> bool
function API.RemoveItem(identifier, item, amount, slot, reason, isMove)
    ready()
    amount = tonumber(amount) or 1
    if type(item) ~= 'string' or not validAmount(amount) then return false end
    local _, name = defOf(item)
    local c = resolve(identifier)
    if not c then return false end
    local ctx = ctxOf(reason, ownerSrc(c))
    ctx.isMove = isMove == true
    slot = tonumber(slot)
    local ok
    if Util.isWeaponName(name) then
        ok = removeWeapons(c, name, amount, slot, ctx)
    elseif slot then
        local e = c.stacks[slot]
        if not e or e.kind == 'weapon' or not sameName(e.item, name) or e.count < amount then return false end
        ctx.rsgSlot = slot
        ok = Inv.removeStack(c, e.id, amount, ctx)
    else
        local real = (firstEntry(c, name) or {}).item or name
        ctx.rsgSlot = 'Multiple'
        ok = Inv.remove(c, real, amount, nil, ctx)
    end
    if ok then RsgInv.pushNow(c) return true end
    return false
end

function API.GetItemCount(source, items)
    ready()
    local c = resolve(source)
    if not c then return nil end
    if type(items) == 'table' then
        local n = 0
        for _, name in pairs(items) do n = n + countAll(c, name) end
        return n
    end
    return countAll(c, items)
end

---HasItem(source, items, amount?) - items: name | { name, ... } | { name = amount, ... }
function API.HasItem(source, items, amount)
    ready()
    local c = resolve(source)
    if not c then return false end
    local function has(name, need) return countAll(c, name) >= (tonumber(need) or 1) end
    if type(items) == 'string' then return has(items, amount) end
    if type(items) ~= 'table' or next(items) == nil then return false end
    if items[1] ~= nil then
        for _, name in ipairs(items) do if not has(name, amount) then return false end end
        return true
    end
    for name, need in pairs(items) do
        if not has(name, amount or need) then return false end
    end
    return true
end

---CanAddItem(identifier, item, amount?) -> bool, 'weight'|'slots'|'limit'|...
function API.CanAddItem(identifier, item, amount)
    ready()
    amount = tonumber(amount) or 1
    if type(item) ~= 'string' or amount <= 0 then return false end
    local d, name = defOf(item)
    if not d and not Util.isWeaponName(item) then return false end
    local c, err = resolve(identifier)
    if not c then return false, err end
    local free = c.slots - Containers.usedSlots(c)
    if Util.isWeaponName(item) then
        local canCarry = part('canCarry')
        if canCarry then return canCarry(c, math.max(1, math.floor(amount)), item:upper()) end
        local _, cap, load = Weight.pool(c)
        if cap and load + ((d and d.weight) or 0) * amount > cap + 1e-6 then return false, 'weight' end
        if free < amount then return false, 'slots' end
        return true
    end
    local ok, e2 = Inv.canAdd(c, name, amount, {}, ctxOf('canAdd'))
    if not ok then return false, e2 end
    if d.unique and free < amount then return false, 'slots' end
    return true
end

function API.GetFreeWeight(source)
    ready()
    local c = resolve(source)
    if not c then return 0 end
    local _, cap, load = Weight.pool(c)
    if not cap then return 0 end
    return toG(math.max(0, cap - load))
end

function API.GetSlots(identifier)
    ready()
    local c = resolve(identifier)
    if not c then return 0, nil end
    local used = Containers.usedSlots(c)
    return used, c.slots - used
end

function API.GetItemBySlot(source, slot)
    ready()
    local c = resolve(source)
    slot = tonumber(slot)
    if not c or not slot then return nil end
    return rsgItem(c.stacks[slot])
end

function API.GetItemByName(source, item)
    ready()
    local c = resolve(source)
    return rsgItem(firstEntry(c, tostring(item)))
end

function API.GetItemsByName(source, item)
    ready()
    local c = resolve(source)
    if not c then return nil end
    local out = {}
    for _, e in ipairs(entriesOf(c, tostring(item))) do out[#out + 1] = rsgItem(e) end
    return out
end

function API.GetItemWeight(itemName)
    local d = defOf(tostring(itemName))
    return d and toG(d.weight) or nil
end

-- pure helpers on an rsg items table (same names/semantics as rsg-inventory)
function API.GetTotalWeight(items)
    local w = 0
    for _, it in pairs(items or {}) do
        if type(it) == 'table' then w = w + (tonumber(it.weight) or 0) * (tonumber(it.amount) or 0) end
    end
    return w
end

function API.GetSlotsByItem(items, itemName)
    local out = {}
    for slot, it in pairs(items or {}) do
        if type(it) == 'table' and it.name and sameName(it.name, itemName) then out[#out + 1] = slot end
    end
    table.sort(out, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    return out
end

function API.GetFirstSlotByItem(items, itemName)
    local list = API.GetSlotsByItem(items, itemName)
    return list[1] and tonumber(list[1]) or nil
end

---SetItemData(source, itemName, key, val) - key 'info' (replace metadata) or 'amount'.
function API.SetItemData(source, itemName, key, val)
    ready()
    if not itemName or not key then return false end
    local c = resolve(source)
    local e = firstEntry(c, tostring(itemName))
    if not e then return false end
    local ctx = ctxOf('SetItemData', ownerSrc(c))
    if key == 'info' or key == 'metadata' then
        local ok
        if e.kind == 'weapon' then
            ok = setWeaponInfo(e.weaponId, val)
        else
            local meta, decayAt = fromInfo(e.item, val)
            ok = Inv.setMetadata(c, e.id, meta, nil, ctx)
            if ok and decayAt then
                local ne = c.stacks[e.slot] or e
                ne.decayAt = decayAt
                Containers.touch(c, ne.slot)
            end
        end
        if ok then RsgInv.pushNow(c) end
        return ok and true or false
    elseif key == 'amount' then
        local n = Util.toInt(val)
        if not n or n < 0 or e.kind == 'weapon' then return false end
        if n == e.count then return true end
        local ok
        if n > e.count then
            ok = Inv.add(c, e.item, n - e.count, e.metadata, ctx, { slot = e.slot, decayAt = e.decayAt })
        else
            ok = Inv.removeStack(c, e.id, e.count - n, ctx)
        end
        if ok then RsgInv.pushNow(c) end
        return ok and true or false
    end
    return false
end

---ClearInventory(source, filterItems?) - filterItems: name | { name, ... } kept.
function API.ClearInventory(source, filterItems)
    ready()
    local c = resolve(source)
    if not c then return false end
    local keep = {}
    local list = type(filterItems) == 'string' and { filterItems } or (type(filterItems) == 'table' and filterItems or {})
    for _, n in ipairs(list) do keep[n] = true; keep[tostring(n):lower()] = true; keep[tostring(n):upper()] = true end
    local ok = Inv.clear(c, { keep = keep, occupants = true }, ctxOf('ClearInventory', ownerSrc(c)))
    if ok then RsgInv.pushNow(c) end
    return ok and true or false
end

---SetInventory(source, items) - make the grid equal to an rsg items table (slot-keyed or list).
---Applied as a DIFF so a caller that edits one entry of PlayerData.items and writes the table
---back (RINGOcustoms weapon parts) changes only that entry: stacks keep their ids, weapons are
---matched by weaponId / serial (never re-created), unchanged slots are not touched.
function API.SetInventory(source, items)
    ready()
    local c = resolve(source)
    if not c or type(items) ~= 'table' then return false end
    local ctx = ctxOf('SetInventory', ownerSrc(c))
    local want, wantWeapons = {}, {}
    for k, it in pairs(items) do
        if type(it) == 'table' and type(it.name) == 'string' then
            local slot = math.tointeger(tonumber(it.slot) or (type(k) == 'number' and k) or -1)
            if slot and slot >= 1 and slot <= c.slots then
                if Util.isWeaponName(it.name) then wantWeapons[#wantWeapons + 1] = { slot = slot, it = it }
                else want[slot] = it end
            end
        end
    end
    local failed = 0
    -- weapons: keep (and update) the ones still listed, delete the others, create new ones
    local keptW = {}
    for _, w in ipairs(wantWeapons) do
        local info = type(w.it.info) == 'table' and w.it.info or {}
        local id = tonumber(w.it.weaponId)
        if not id and type(w.it.id) == 'string' then id = tonumber(w.it.id:match('^w(%d+)$')) end
        local r = id and Weapons and Weapons.get and Weapons.get(id) or nil
        if not r and (info.serie or info.serial) and Weapons and Weapons.bySerial then r = Weapons.bySerial(info.serie or info.serial) end
        if r and r.container == c.id then
            keptW[r.id] = true
            if not setWeaponInfo(r.id, info) then failed = failed + 1 end
        else
            local ok, made = giveWeapons(c, w.it.name:lower(), 1, w.slot, info, ctx)
            if ok then keptW[made[1].id] = true else failed = failed + 1 end
        end
    end
    local gone = {}
    for _, e in pairs(c.stacks) do
        if e.kind == 'weapon' and not keptW[e.weaponId] then gone[#gone + 1] = e.weaponId end
    end
    for _, id in ipairs(gone) do
        local del = part('delete')
        if not (del and del(id, ctx)) then failed = failed + 1 end
    end
    -- stacks: same slot + same item -> adjust amount / info in place; otherwise replace
    local slots = {}
    for s, e in pairs(c.stacks) do if e.kind ~= 'weapon' then slots[#slots + 1] = s end end
    table.sort(slots)
    for _, s in ipairs(slots) do
        local e, it = c.stacks[s], want[s]
        if it and sameName(e.item, it.name) then
            local meta, decayAt = fromInfo(e.item, it.info)
            if Meta.canonical(meta) ~= Meta.canonical(e.metadata) then
                if Inv.setMetadata(c, e.id, meta, nil, ctx) and decayAt and c.stacks[s] then c.stacks[s].decayAt = decayAt end
            end
            e = c.stacks[s]
            local n = math.tointeger(tonumber(it.amount) or 1) or 1
            if e and n > e.count then
                if not Inv.add(c, e.item, n - e.count, e.metadata, ctx, { slot = s, decayAt = e.decayAt }) then failed = failed + 1 end
            elseif e and n < e.count then
                if n <= 0 then Inv.removeStack(c, e.id, nil, ctx) else Inv.removeStack(c, e.id, e.count - n, ctx) end
            end
            want[s] = nil
        else
            Inv.removeStack(c, e.id, nil, ctx)
        end
    end
    for s, it in pairs(want) do
        local d, name = defOf(it.name)
        local n = math.tointeger(tonumber(it.amount) or 1) or 1
        if n > 0 then
            local ok = d and addTo(c, ownerSrc(c) or c.id, name, n, s, it.info, ctx)
            if not ok then failed = failed + 1 end
        end
    end
    RsgInv.pushNow(c)
    if failed > 0 then print(('^3[MULTIinventory] SetInventory %s: %d item(s) could not be placed^7'):format(c.id, failed)) end
    return failed == 0
end

-- player lifecycle helpers for rsg-core -------------------------------------------------

---LoadInventory(source, citizenid) - rsg-core calls this while building PlayerData.
function API.LoadInventory(source, citizenid)
    ready()
    local st = State.get(tonumber(source))
    local c
    if st then
        c = Containers.get('player:' .. st.charId, { create = true })
    elseif citizenid and MBridge.CharIdOf then
        local ok, cid = pcall(MBridge.CharIdOf, citizenid)
        if ok and cid then c = Containers.get('player:' .. cid, { create = true }) end
    end
    return itemsMap(c)
end

---SaveInventory(source|PlayerData, offline) - MULTIinventory saves itself (write-behind).
function API.SaveInventory() return true end

-- UI ------------------------------------------------------------------------------------

---OpenInventory(source, identifier?, data?) - no id: own inventory; id: stash (created if new).
function API.OpenInventory(source, identifier, data)
    ready()
    local src = tonumber(source)
    if not src or not State.get(src) then return false end
    if identifier == nil then return State.open(src, nil) end
    if type(identifier) ~= 'string' or identifier == '' then return false end
    local id = RsgInv.stashId(identifier)
    if type(id) == 'number' then return API.OpenInventoryById(src, id) end
    RsgInv.defineStash(id, data)
    if MultiInv and MultiInv.Open then
        return (MultiInv.Open(src, id, { label = type(data) == 'table' and data.label or nil,
            coords = type(data) == 'table' and data.coords or nil })) and true or false
    end
    return State.open(src, id, { label = type(data) == 'table' and data.label or nil })
end

function API.OpenInventoryById(source, targetId)
    ready()
    local src, tgt = tonumber(source), tonumber(targetId)
    local st = tgt and State.get(tgt)
    if not st or not State.get(src) then return false end
    if State.isOpen(tgt) then State.close(tgt, true) end
    local label = (st.name and st.name ~= '') and st.name or GetPlayerName(tgt)
    -- a script decided (police search / robbery): the secondary part's search session, without
    -- its own pose/distance conditions (rsg-inventory semantics), audit-logged as search_open
    if SecondarySearch and SecondarySearch.openFor then
        return (SecondarySearch.openFor({ source = src, target = tgt, title = label })) and true or false
    end
    return (State.open(src, 'player:' .. st.charId, { label = label, admin = true })) and true or false
end

function API.CloseInventory(source)
    return State.close(tonumber(source), true)
end

-- stashes --------------------------------------------------------------------------------

---Define (or update) a stash from rsg data { label, slots, maxweight (g) }. Keeps what is
---already stored when a field is not given.
function RsgInv.defineStash(id, data)
    data = type(data) == 'table' and data or {}
    local def = {}
    if data.label then def.label = data.label end
    if tonumber(data.slots) then def.slots = tonumber(data.slots) end
    if tonumber(data.maxweight) then def.maxWeight = toKg(data.maxweight) end
    if not Containers.isDefined(id) then
        local existing = Containers.get(id)
        if existing then
            -- Containers.define replaces maxWeight with nil when omitted: carry the stored values
            def.label = def.label or existing.label
            def.slots = def.slots or existing.slots
            def.maxWeight = def.maxWeight or existing.maxWeight
            def.flags = existing.flags
            def.kind = existing.kind
        else
            local sd = C('stashDefaults') or {}
            def.kind = 'stash'
            def.label = def.label or id
            def.slots = def.slots or tonumber(sd.slots) or 100
            def.maxWeight = def.maxWeight or (tonumber(sd.maxweight) and toKg(sd.maxweight)) or nil
        end
    else
        local prev = Containers.getDefinition(id) or {}
        if def.maxWeight == nil then def.maxWeight = prev.maxWeight end
    end
    if next(def) == nil then return true end
    return Containers.define(id, def)
end

---CreateInventory(identifier, data). The older (source, identifier, data) form is accepted too
---(RINGOlawmansystem falls back to it).
function API.CreateInventory(identifier, data, data2)
    if type(identifier) == 'number' and type(data) == 'string' then identifier, data = data, data2 end
    if type(identifier) ~= 'string' or identifier == '' then return false end
    ready()
    return RsgInv.defineStash(RsgInv.stashId(identifier), data) and true or false
end
API.RegisterStash = API.CreateInventory

---DeleteInventory(identifier): the stash and everything in it are removed.
function API.DeleteInventory(identifier)
    if type(identifier) ~= 'string' then return false end
    ready()
    local id = RsgInv.stashId(identifier)
    if type(id) ~= 'string' then return false end
    if MultiInv and MultiInv.Delete then return MultiInv.Delete(id) and true or false end
    if Containers.isDefined(id) or Containers.peek(id) then
        Containers.undefine(id, true)
        Containers.forget(id)
        return true
    end
    return false
end
API.RemoveInventory = API.DeleteInventory

---GetStashItems(identifier) -> rsg items table (slot-keyed), {} when the stash does not exist
function API.GetStashItems(identifier)
    ready()
    if type(identifier) ~= 'string' then return {} end
    local id = RsgInv.stashId(identifier)
    local c = type(id) == 'string' and Containers.get(id) or nil
    return itemsMap(c)
end

function API.GetInventory(identifier)
    ready()
    if type(identifier) ~= 'string' then return nil end
    local c = resolve(identifier)
    if not c then return nil end
    local _, cap = Weight.pool(c)
    return { name = c.id, label = c.label, slots = c.slots, maxweight = cap and toG(cap) or nil,
             items = itemsMap(c), isOpen = next(State.viewersOf(c.id)) ~= nil }
end

function API.ClearStash(identifier)
    ready()
    if type(identifier) ~= 'string' then return false end
    local id = RsgInv.stashId(identifier)
    local c = type(id) == 'string' and Containers.get(id) or nil
    if not c then return false end
    return (Inv.clear(c, { occupants = true }, ctxOf('ClearStash'))) and true or false
end

function API.SaveStash() return true end

-- drops ------------------------------------------------------------------------------------

---ForceDropItem(source, item, amount, info?, reason?) -> drop id | false
function API.ForceDropItem(source, item, amount, info, reason)
    ready()
    local src = tonumber(source)
    local st = src and State.get(src)
    local d, name = defOf(item)
    if not st or not d or Util.isWeaponName(name) then return false end
    local coords = GetEntityCoords(GetPlayerPed(src))
    local meta = fromInfo(name, info)
    local ok, dropId = InvAPI.CreateDrop(coords, { { item = name, count = tonumber(amount) or 1, metadata = meta } }, st.charId)
    if not ok then return false end
    Sync.notify(src, 'Your pockets are full - it was dropped on the ground', 'warning')
    InvLog.write('drop', { actorSrc = src, to = 'drop:' .. tostring(dropId), item = name, count = tonumber(amount) or 1,
                           data = { reason = reason or 'force_drop',
                                    stacks = { { item = name, count = tonumber(amount) or 1, metadata = meta } } } })
    return dropId
end

-- usable items -----------------------------------------------------------------------------

local function invoke(data, ...)
    if type(data) == 'function' then return data(...) end
    if type(data) == 'table' then
        local mt = getmetatable(data)
        if rawget(data, '__cfx_functionReference') or (mt and mt.__call) then return data(...) end
        local f = data.cb or data.callback
        if f then return invoke(f, ...) end
    end
    return nil
end

local function rsgUsable(name)
    local core = RsgInv.core()
    if not core or not core.Functions or not core.Functions.CanUseItem then return nil end
    local ok, data = pcall(core.Functions.CanUseItem, name)
    return ok and data or nil
end

---Core usables ask here for an rsg-core usable (RSGCore.Functions.CreateUseableItem).
function Usables.rsgCallback(name)
    if not isRsg() or not C('bridgeUsables') or type(name) ~= 'string' then return nil end
    local data = rsgUsable(name)
    if not data then return nil end
    return function(src, item) return invoke(data, src, item) end
end

local function downOrCuffed(src)
    if not C('blockUseWhenDown') then return false end
    local p = getPlayer(src)
    local m = p and p.PlayerData and p.PlayerData.metadata
    return type(m) == 'table' and (m.isdead == true or m.ishandcuffed == true)
end

---UseItem(itemName, src, item) - run the rsg usable callback (rsg-inventory semantics);
---falls back to a RINGO-native usable when the item is in the player's grid.
function API.UseItem(itemName, src, item)
    if type(itemName) == 'number' or (type(itemName) == 'string' and itemName:match('^%d+$')) then
        -- RSGCore.Functions.UseItem(source, item): item = name or item table
        local s, it = tonumber(itemName), src
        local name = type(it) == 'table' and it.name or it
        if type(name) ~= 'string' then return false end
        return (Usables.useByName(s, name, type(it) == 'table' and it or nil, { src = s, reason = 'use', api = true, rsgApi = true })) and true or false
    end
    local cb = rsgUsable(itemName)
    if cb then invoke(cb, src, item) return true end
    src = tonumber(src)
    local st = src and State.get(src)
    if st and type(item) == 'table' and tonumber(item.slot) and Usables.isRegistered(itemName) then
        return Usables.use(src, 'player:' .. st.charId, tonumber(item.slot), { src = src, reason = 'use', rsgApi = true })
    end
    return false
end

---CreateUsableItem(name, cb(source, item)) / CreateUseableItem - some RINGO scripts also try
---these on rsg-inventory (RINGOjobsandcrafting licences). The callback goes into rsg-core's own
---usable table (RSGCore.Functions.CreateUseableItem), exactly where the primary call puts it;
---without rsg-core it becomes a RINGO usable owned by the calling resource.
function API.CreateUsableItem(name, cb)
    if type(name) ~= 'string' or name == '' or cb == nil then return false end
    local core = RsgInv.core()
    if core and core.Functions and core.Functions.CreateUseableItem then
        local ok = pcall(core.Functions.CreateUseableItem, name, cb)
        if ok then
            rsgDefs[name] = rsgDefs[name] or { name = name, useable = true }
            if C('bridgeUsables') and not Usables.isRegistered(name) then Usables.register(name, RsgInv.dispatchUsable, USABLE_OWNER) end
            return true
        end
    end
    return Usables.register(name, function(d)
        local c = d.item and d.item.container and Containers.peek(d.item.container)
        invoke(cb, d.source, (c and rsgItem(c.stacks[d.item.slot])) or d.item)
    end, caller())
end
API.CreateUseableItem = API.CreateUsableItem

---Handler RINGO's Usables call for rsg usable items (UI, hotbar, Rsg UseItem).
local function dispatchUsable(data)
    local src = data.source
    local it = data.item or {}
    local c = it.container and Containers.peek(it.container)
    local ri = (c and rsgItem(c.stacks[it.slot])) or
        { name = it.name, amount = it.count, info = it.metadata or {}, slot = it.slot, label = it.label }
    if downOrCuffed(src) then Sync.notify(src, 'You cannot do that right now', 'error') return end
    local cb = rsgUsable(it.name)
    if not cb then Sync.notify(src, 'This item cannot be used', 'error') return end
    invoke(cb, src, ri)
end
RsgInv.dispatchUsable = dispatchUsable

function RsgInv.registerUsables()
    if not isRsg() or not C('bridgeUsables') then return 0 end
    local owners = Usables.owners()
    local n = 0
    for name, raw in pairs(rsgDefs) do
        if raw.useable == true and not Util.isWeaponName(name) then
            local owner = owners[name]
            if owner == nil or owner == USABLE_OWNER then
                Usables.register(name, dispatchUsable, USABLE_OWNER)
                n = n + 1
            end
        end
    end
    return n
end

-- shops (registry only: MULTIinventory has no shop screen - see change_requests/rsg.md) -----
local shops = {}

local STORES = 'MULTIstores'
local warnedNoStores = {}
---rsg-inventory's shop exports are passed on to MULTIstores (the store screen of MULTIcore).
local function stores(fn)
    if GetResourceState(STORES) == 'started' then return exports[STORES] end
    if not warnedNoStores[fn] then
        warnedNoStores[fn] = true
        print(('^3[MULTIinventory] rsg-inventory %s was called by %s, but shops are in MULTIstores, which is not started (ensure MULTIstores after MULTIinventory)^7')
            :format(fn, tostring(caller())))
    end
    return nil
end

function API.CreateShop(shopData)
    local S = stores('CreateShop')
    if S then return S:CreateShop(shopData) end
    if type(shopData) ~= 'table' then return false end
    local function reg(name, data)
        if type(name) ~= 'string' or type(data) ~= 'table' then return end
        local items = {}
        for i, it in ipairs(data.items or {}) do
            items[i] = { name = it.name, price = it.price, amount = it.amount, defaultstock = it.amount, slot = i, info = it.info }
        end
        shops[name] = { name = name, label = data.label, coords = data.coords, items = items, persistentStock = data.persistentStock }
    end
    if shopData.name then reg(shopData.name, shopData) return true end
    for k, v in pairs(shopData) do
        if type(v) == 'table' and v.items then reg(type(k) == 'number' and v.name or k, v) end
    end
    return true
end

function API.DoesShopExist(name)
    local S = stores('DoesShopExist')
    if S then return S:DoesShopExist(name) end
    return type(name) == 'string' and shops[name] ~= nil
end

function API.RestockShop(name, percentage)
    local S = stores('RestockShop')
    if S then return S:RestockShop(name, percentage) end
    local s = shops[name]
    if not s then return false end
    local mult = (tonumber(percentage) or 100) / 100
    for _, it in ipairs(s.items) do
        if it.amount and it.defaultstock then
            it.amount = math.min(it.defaultstock, it.amount + math.floor(it.defaultstock * mult + 0.5))
        end
    end
    return true
end

---No built-in shop UI: fires 'MULTIinventory:rsg:openShop' (src, shop) for a shop resource.
function API.OpenShop(source, name)
    local S = stores('OpenShop')
    if S then return S:OpenShop(tonumber(source), name) end
    local s = shops[name]
    if not s then return false end
    TriggerEvent('MULTIinventory:rsg:openShop', tonumber(source), Util.deepcopy(s))
    return false
end

-- ------------------------------------------------------------
-- 2/3. lifecycle, capacity, PlayerData mirror, Player.Functions
-- ------------------------------------------------------------
local capCache = {}

InvHooks.register('capacity', function(charId)
    if not isRsg() then return nil end
    local src = State.srcOfChar(charId)
    if not src then return nil end
    local now = Util.now()
    local cc = capCache[charId]
    if cc and now - cc.at < 5 then return cc.kg end
    local p = getPlayer(src)
    local w = p and p.PlayerData and tonumber(p.PlayerData.weight)
    local kg = w and toKg(w) or nil
    capCache[charId] = { kg = kg, at = now }
    return kg
end)

function RsgInv.pushItems(src, c)
    if not isRsg() or not C('mirrorPlayerItems') then return false end
    local st = State.get(src)
    if not st then return false end
    c = c or Containers.peek('player:' .. st.charId)
    local p = getPlayer(src)
    if not c or not p or not p.Functions or not p.Functions.SetPlayerData then return false end
    local ok = pcall(p.Functions.SetPlayerData, 'items', itemsMap(c))
    -- scripts size their own checks with PlayerData.slots (RINGOjobsandcrafting craft simulation)
    if ok and C('mirrorSlots') and p.PlayerData and p.PlayerData.slots ~= c.slots then
        pcall(p.Functions.SetPlayerData, 'slots', c.slots)
    end
    return ok
end

---Synchronous mirror after a change of a player grid (no-op for other containers). rsg-inventory
---updates PlayerData.items before its export returns, and the RINGO RSG bridge reads that table
---right after AddItem/RemoveItem, so the mirror must not wait for the 100 ms delta flush.
function RsgInv.pushNow(c)
    if not c or c.kind ~= 'player' or not isRsg() then return false end
    local src = ownerSrc(c)
    return src and RsgInv.pushItems(src, c) or false
end

local METHODS = {
    AddItem        = function(src) return function(item, amount, slot, info, reason) return API.AddItem(src, item, amount, slot, info, reason) end end,
    RemoveItem     = function(src) return function(item, amount, slot, reason) return API.RemoveItem(src, item, amount, slot, reason) end end,
    GetItemByName  = function(src) return function(item) return API.GetItemByName(src, item) end end,
    GetItemsByName = function(src) return function(item) return API.GetItemsByName(src, item) end end,
    GetItemBySlot  = function(src) return function(slot) return API.GetItemBySlot(src, slot) end end,
    ClearInventory = function(src) return function(filter) return API.ClearInventory(src, filter) end end,
    SetInventory   = function(src) return function(items) return API.SetInventory(src, items) end end,
}

function RsgInv.addPlayerMethods(src)
    if not isRsg() or not C('playerMethods') then return 0 end
    local p = getPlayer(src)
    if not p or type(p.Functions) ~= 'table' or not p.Functions.AddMethod then return 0 end
    local n = 0
    for name, make in pairs(METHODS) do
        if p.Functions[name] == nil and pcall(p.Functions.AddMethod, name, make(src)) then n = n + 1 end
    end
    return n
end

InvHooks.register('characterLoaded', function(src, charId)
    if not isRsg() then return end
    capCache[charId] = nil
    RsgInv.addPlayerMethods(src)
    RsgInv.pushItems(src)
end)

InvHooks.register('characterUnloaded', function(_, charId) capCache[charId] = nil end)

InvHooks.register('containerChanged', function(c)
    if c.kind ~= 'player' or not isRsg() then return end
    local src = ownerSrc(c)
    if src then RsgInv.pushItems(src, c) end
end)

-- rsg events for third-party scripts -----------------------------------------------------
local function itemBox(src, name, kind, amount)
    if not C('emitItemBox') or not src then return end
    local raw = rsgDefs[name] or { name = name, label = name, image = tostring(name) .. '.png' }
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, raw, kind, amount)
end

InvHooks.register('itemAdded', function(c, item, count)
    if not isRsg() or c.kind ~= 'player' then return end
    RsgInv.pushNow(c)
    itemBox(ownerSrc(c), item, 'add', count)
end)

InvHooks.register('metadataChanged', function(c)
    if isRsg() and c.kind == 'player' then RsgInv.pushNow(c) end
end)

InvHooks.register('itemRemoved', function(c, item, count, meta, ctx)
    if not isRsg() or c.kind ~= 'player' then return end
    RsgInv.pushNow(c)
    local src = ownerSrc(c)
    if not src then return end
    if C('emitRemovedEvent') then
        ctx = ctx or {}
        local isMove = ctx.isMove == true or ctx.reason == 'move' or ctx.reason == 'give' or ctx.reason == 'drop'
        TriggerEvent('rsg-inventory:server:itemRemovedFromPlayerInventory', src, item,
            { amount = count, slot = ctx.rsgSlot, info = meta }, ctx.note or ctx.reason, isMove)
    end
    itemBox(src, item, 'remove', count)
end)

-- ---- use / close echo (header, point 6) ----
local echoTokens = {}   -- [src] = { [token] = expiresAt }
local echoSeq = 0

---Ask the player's client (client/multi/faces.lua) to send the rsg net event
---'rsg-inventory:server:useItem' for a use RINGO already performed (or for an item nobody
---registered - RINGOplayercore's labor tools / passive consumables listen to it).
function RsgInv.echoUse(src, e)
    if not isRsg() or not C('echoUseEvent') or realRsgInventory() or not src or not e then return false end
    echoSeq = echoSeq + 1
    local token = ('%d-%d-%d'):format(echoSeq, math.random(100000, 999999), Util.now())
    echoTokens[src] = echoTokens[src] or {}
    echoTokens[src][token] = Util.now() + 30
    local ri = rsgItem(e) or {}
    TriggerClientEvent('MULTIinventory:rsg:useEcho', src, {
        name = ri.name, slot = e.slot, amount = ri.amount, info = ri.info, label = ri.label,
        type = ri.type, _multiEcho = token,
    })
    return true
end

local function takeToken(src, token)
    local t = echoTokens[src]
    if not t or type(token) ~= 'string' or not t[token] then return false end
    local valid = t[token] >= Util.now()
    t[token] = nil
    return valid
end

AddEventHandler('playerDropped', function() echoTokens[source] = nil end)

-- uses from the RINGO UI / hotbar / native UseStack: echo after the use (the real rsg-inventory
-- runs the usable before other resources' useItem handlers too). Not for the rsg UseItem export
-- (rsgApi) nor for uses that came in through the net event itself (rsgNet).
InvHooks.register('itemUsed', function(src, itemTable, ctx)
    if not isRsg() then return end
    itemBox(src, itemTable and itemTable.name, 'use')
    ctx = ctx or {}
    if ctx.rsgApi or ctx.rsgNet or not itemTable then return end
    local slot = tonumber(itemTable.slot or itemTable.gridSlot)
    if not slot then return end
    RsgInv.echoUse(src, { item = itemTable.name, count = itemTable.count, metadata = itemTable.metadata or {},
                          slot = slot, id = itemTable.id, weight = itemTable.weight })
end)

---Use from the RINGO UI on RSG: like Usables.use, plus rsg-core usables created after the last
---sync, plus the echo for items no script registered (rsg listeners still get the event).
local function rsgUse(src, cid, slot)
    local c = Containers.peek(cid)
    local e = c and c.stacks[slot]
    if not e then return false, 'no_item' end
    if e.kind == 'weapon' then return false, 'not_usable' end
    if not Usables.isRegistered(e.item) and C('bridgeUsables') and rsgUsable(e.item) then
        Usables.register(e.item, dispatchUsable, USABLE_OWNER)
    end
    local ok, err = Usables.use(src, cid, slot, { src = src, reason = 'use' })
    if not ok and err == 'not_usable' and RsgInv.echoUse(src, e) and C('silentNotUsable') then
        return true
    end
    return ok, err
end
RsgInv.use = rsgUse

if isRsg() then
    Actions.register('use', function(src, d)
        local st = State.get(src)
        if not st then return false, 'player_not_loaded' end
        return rsgUse(src, 'player:' .. st.charId, Util.toInt(d.slot) or -1)
    end)
    Actions.register('hotbar', function(src, d)
        if d.op == 'assign' then return Hotbar.assign(src, d.n, d.slot) end
        if d.op == 'clear' then return Hotbar.clear(src, d.n) end
        if d.op ~= 'use' then return false, 'bad_op' end
        local st = State.get(src)
        if not st then return false, 'player_not_loaded' end
        local c, e = Hotbar.resolve(st.charId, Util.toInt(d.n))
        if e and e.kind ~= 'weapon' and c and not Usables.isRegistered(e.item) then
            return rsgUse(src, c.id, e.slot)
        end
        return Hotbar.use(src, d.n)
    end)
end

RegisterNetEvent('rsg-inventory:server:useItem', function(item)
    local src = tonumber(source)
    if not isRsg() or not C('netUseEvent') or realRsgInventory() or type(item) ~= 'table' then return end
    if item._multiEcho ~= nil and takeToken(src, item._multiEcho) then return end   -- our own echo
    local st = State.get(src)
    if not st then return end
    local cid = 'player:' .. st.charId
    local c = Containers.peek(cid)
    if not c then return end
    local slot = tonumber(item.slot)
    if not slot and item.name then
        local e = firstEntry(c, tostring(item.name))
        slot = e and e.slot
    end
    local e = slot and c.stacks[slot]
    if not e then return end
    if e.kind == 'weapon' then InvHooks.emit('hotbarWeapon', src, e.weaponId, e) return end
    if downOrCuffed(src) then Sync.notify(src, 'You cannot do that right now', 'error') return end
    if not Usables.isRegistered(e.item) and C('bridgeUsables') and rsgUsable(e.item) then
        Usables.register(e.item, dispatchUsable, USABLE_OWNER)
    end
    if not Usables.isRegistered(e.item) then return end   -- listeners-only item (no usable): silent
    local ok, err = Usables.use(src, cid, slot, { src = src, reason = 'use', rsgNet = true })
    if not ok then Sync.notify(src, tostring(err), 'error') end
end)

-- a secondary closes -> 'rsg-inventory:server:closeInventory' (id) from the player's client
AddEventHandler('MULTIinventory:containerClosed', function(src, id)
    if not isRsg() or not C('echoCloseEvent') or realRsgInventory() or not tonumber(src) or type(id) ~= 'string' then return end
    if id:match('^player:') or id:match('^equip:') then return end
    TriggerClientEvent('MULTIinventory:rsg:closedEcho', tonumber(src), id)
end)

-- logout without leaving the server (character switch)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(a)
    if not isRsg() then return end
    local src = tonumber(a) or tonumber(source)
    if not src then return end
    CreateThread(function() State.detach(src) end)
end)

-- re-sync when rsg-core changes its shared items (exports['rsg-core']:AddItem / UpdateItem ...)
local function resync()
    if not isRsg() then return end
    coreObj = nil
    RsgInv.syncItems()
    RsgInv.registerUsables()
end
AddEventHandler('RSGCore:Server:UpdateObject', resync)
AddEventHandler('onResourceStart', function(res) if res == 'rsg-core' then resync() end end)
-- a resource that had its own usable for an rsg item stopped: hand the item back to rsg
AddEventHandler('onResourceStop', function(res) if res ~= RES then RsgInv.registerUsables() end end)

AddEventHandler('MULTIinventory:ready', function()
    if not isRsg() then return end
    resync()
    if realRsgInventory() then
        print('^1[MULTIinventory] the real rsg-inventory is running next to MULTIinventory - remove it before going live^7')
    end
    local core = RsgInv.core()
    local money = core and core.Config and core.Config.Money
    if money and money.EnableMoneyItems then
        print('^3[MULTIinventory] rsg-core RSGConfig.Money.EnableMoneyItems is on - money items are kept by rsg-core in PlayerData.items, which MULTIinventory overwrites. Turn it off.^7')
    end
end)

-- first sync as soon as this file loads (rsg-core is ensured before MULTIinventory), so the
-- definitions exist before boot.lua attaches online players. Registry.reload keeps them.
if isRsg() then
    CreateThread(function()
        RsgInv.syncItems()
        RsgInv.registerUsables()
    end)
end

-- ------------------------------------------------------------
-- exports: exports.MULTIinventory:Rsg_<Name>  (server/multi/faces.lua answers exports[.rsg-inventory.] with these)
-- ------------------------------------------------------------
-- documented parameter count per name: a callable passed AFTER these is a callback
local PARAMS = {
    AddItem = 7, RemoveItem = 6, GetItemCount = 2, HasItem = 3, CanAddItem = 3, GetFreeWeight = 1,
    GetSlots = 1, GetItemBySlot = 2, GetItemByName = 2, GetItemsByName = 2, GetItemWeight = 1,
    SetItemData = 4, ClearInventory = 2, SetInventory = 2, UseItem = 3, ForceDropItem = 5,
    GetTotalWeight = 1, GetSlotsByItem = 2, GetFirstSlotByItem = 2, LoadInventory = 2, SaveInventory = 2,
    OpenInventory = 3, OpenInventoryById = 2, CloseInventory = 2, CreateInventory = 3, DeleteInventory = 1,
    GetInventory = 1, ClearStash = 1, SaveStash = 1, CreateShop = 1, OpenShop = 2, RestockShop = 2,
    DoesShopExist = 1, CreateUsableItem = 2, CreateUseableItem = 2,
    RegisterStash = 3, RemoveInventory = 1, GetStashItems = 1,
}
RsgInv.PARAMS = PARAMS

local function callable(f)
    if type(f) == 'function' then return true end
    local mt = type(f) == 'table' and getmetatable(f) or nil
    return type(mt) == 'table' and mt.__call ~= nil
end

local function run(name, invoker, ...)
    local fn = API[name]
    if not fn then
        print(('^1[MULTIinventory] rsg: unknown rsg-inventory export "%s" (called by %s)^7'):format(tostring(name), tostring(invoker)))
        return nil
    end
    local n = select('#', ...)
    local args = table.pack(...)
    local cb
    if n > (PARAMS[name] or 99) and callable(args[n]) then cb = args[n]; args[n] = nil; args.n = n - 1 end
    -- wait for boot BEFORE claiming CALLER, so a call parked in ready() cannot leak its name
    if InvDB and InvDB.ready and not InvDB.ready() then InvDB.awaitReady() end
    local prev = CALLER
    CALLER = (type(invoker) == 'string' and invoker ~= '') and invoker or prev
    local r = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
    CALLER = prev
    if not r[1] then
        print(('^1[MULTIinventory] rsg %s (called by %s) failed: %s^7'):format(name, tostring(invoker), tostring(r[2])))
        r = table.pack(true, false)
    end
    if cb then
        local ok, err = pcall(cb, table.unpack(r, 2, r.n))
        if not ok then print(('^1[MULTIinventory] rsg callback of %s failed: %s^7'):format(name, tostring(err))) end
    end
    return table.unpack(r, 2, r.n)
end
RsgInv.run = run

RsgInv.NAMES = {}
for name in pairs(API) do
    RsgInv.NAMES[#RsgInv.NAMES + 1] = name
    exports('Rsg_' .. name, function(...) return run(name, GetInvokingResource(), ...) end)
end
table.sort(RsgInv.NAMES)

---exports.MULTIinventory:Rsg__call(name, invoker, ...) - used by the rsg-inventory aliases
exports('Rsg__call', function(name, invoker, ...)
    return run(name, (type(invoker) == 'string' and invoker ~= '') and invoker or GetInvokingResource(), ...)
end)
RsgInv.API = API
