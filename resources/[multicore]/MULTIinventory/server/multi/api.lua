-- ============================================================
-- MULTIinventory :: server/multi/api.lua
--
-- The MULTIinventory export API the MULTIcore scripts use: exports.MULTIinventory:<Name>(...).
-- Inventory ids:
--   'player:<charId>'                       a character's satchel (PlayerInv(src) hands it out;
--                                           charId is MULTIcore's numeric character id)
--   'stash:<name>', 'trunk:<plate>', 'custom:horse_<id>', 'custom:camp:<cid>',
--   'custom:safedeposit:<cid>:<bank>', ...  stashes (any other id works the same way)
-- A player server id is accepted wherever an inventory id is (its satchel).
-- Stack shape (also rsg-core's PlayerData.items):
--   { name, amount, info = {}, label, description, weight (per unit, grams), type, unique,
--     useable, image, shouldClose, slot, combinable, id }
--   weapons: name in lower case, amount 1, info.serie (serial), info.components, info.quality
-- Inventory view (Get / Exists / Create):
--   { id, type, kind, label, slots, maxWeight (grams, nil = no limit), weight (grams),
--     items = { [slot] = stack }, isOpen (server id of the player looking in, or false),
--     viewers = { [src] = true }, coords, reach, ownerSrc, charId }
--   Views are copies: change items only through the API.
-- Errors (second return value): unknown_item, bad_amount, too_heavy, no_space, limit,
--   not_allowed, no_inventory, not_enough, no_item, in_use, too_far, no_access, no_player
-- Server events: MULTIinventory:ready, MULTIinventory:opened (src, id), MULTIinventory:closed (src, id),
--   MULTIinventory:used (src, name, slot)
-- Ammo: the gunbelt holds spare ammo per type; GetAmmoData() describes the items that fill it.
-- ============================================================

MultiInv = MultiInv or {}
local M = MultiInv
local RES = GetCurrentResourceName()
local API = {}

local SELFTEST = GetConvar('multicore_selftest', 'false') == 'true'
local DEFAULT_REACH = 5.0          -- metres to a stash with coords while moving items
local STASH_SLOTS, STASH_GRAMS = 100, 2000000

local function ready() InvDB.awaitReady() end
local function G(kg) return RsgInv.toG(kg) end
local function KG(g) return RsgInv.toKg(g) end

local function sameName(a, b) return tostring(a):lower() == tostring(b):lower() end

local function validAmount(n)
    return type(n) == 'number' and n >= 1 and n == math.floor(n) and n < 2 ^ 31
end

local ERR = {
    weight = 'too_heavy', slots = 'no_space', stack_full = 'no_space', slot_taken = 'no_space',
    bad_count = 'bad_amount', bad_slot = 'bad_slot', unknown_container = 'no_inventory',
    player_not_loaded = 'no_inventory', denied = 'not_allowed', no_weapons = 'not_allowed',
    blacklisted = 'not_allowed', no_permission = 'not_allowed', weapon_limit = 'limit',
    locked = 'in_use', search_busy = 'in_use', is_weapon = 'unknown_item', unknown_weapon = 'unknown_item',
}
local function E(e) return ERR[e] or e end
M.err = E

local function ctxOf(reason, src)
    local who = GetInvokingResource() or RES
    return { reason = 'api', src = nil, actingSrc = src, note = type(reason) == 'string' and reason or nil,
             resource = who, actor = 'resource:' .. tostring(who) }
end

-- ------------------------------------------------------------
-- ids and containers
-- ------------------------------------------------------------

---satchel id of a logged-in player ('player:<charId>') or nil
function M.PlayerInv(src)
    src = tonumber(src)
    if not src then return nil end
    local st = State.get(src)
    if not st and InvDB.ready() then
        RsgInv.attachNow(src)
        st = State.get(src)
    end
    return st and ('player:' .. st.charId) or nil
end

local function idOf(inv)
    if type(inv) == 'table' then return inv.id end
    if type(inv) == 'number' or (type(inv) == 'string' and inv:match('^%d+$')) then return M.PlayerInv(inv) end
    return inv
end
M.idOf = idOf

local function isPlayerKind(id)
    local k = Containers.kindOf(id)
    return k == 'player' or k == 'equip'
end

---container for an id (players are loaded on demand; other ids only when they exist, or create)
function M.container(inv, create)
    local id = idOf(inv)
    if type(id) ~= 'string' or id == '' then return nil end
    if isPlayerKind(id) then return (Inv.resolve(id)) end
    return Containers.get(id, create and { create = true } or nil)
end

local TYPES = { player = true, stash = true, trunk = true, glovebox = true, custom = true, drop = true, equip = true }
local function typeOf(c)
    local p = tostring(c.id):match('^(%a+):')
    if p and TYPES[p] then return p end
    return 'stash'
end

-- ------------------------------------------------------------
-- stacks and views
-- ------------------------------------------------------------

local function stackOf(e)
    if not e then return nil end
    local s = RsgInv.rsgItem(e)
    if not s then return nil end
    s.info = type(s.info) == 'table' and s.info or {}
    s.amount = tonumber(s.amount) or 1
    if e.kind == 'weapon' then
        s.name = tostring(s.name):lower()
        s.type = 'weapon'
        s.info.id = s.info.id or e.weaponId
    end
    return s
end
M.stackOf = stackOf

---Core item table (Usables) -> export stack shape
function M.stackOfTable(t, c)
    local e = c and t.slot and c.stacks[t.slot]
    if e and sameName(e.item, t.name) then return stackOf(e) end
    return { name = t.name, amount = t.count or t.amount or 1, info = Util.deepcopy(t.metadata or {}), slot = t.slot,
             label = t.label, weight = t.weight and G(t.weight) or 0, type = t.type, id = t.id }
end

local function sortedSlots(c)
    local list = {}
    for slot in pairs(c.stacks) do list[#list + 1] = slot end
    table.sort(list)
    return list
end

local IGNORE_INFO = { quality = true, lastUpdate = true }

local function deepEqual(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do if not deepEqual(v, b[k]) then return false end end
    for k, v in pairs(b) do if a[k] == nil and v ~= nil then return false end end
    return true
end

---does the stack's info hold every key / value of match (nil = any stack)
local function infoMatches(e, match)
    if match == nil then return true end
    if type(match) ~= 'table' then return false end
    local info = e.kind == 'weapon' and (stackOf(e).info or {}) or (e.metadata or {})
    for k, v in pairs(match) do
        if not IGNORE_INFO[k] and not deepEqual(info[k], v) then return false end
    end
    return true
end

local function entries(c, name, match)
    local out = {}
    if not c or type(name) ~= 'string' then return out end
    for _, slot in ipairs(sortedSlots(c)) do
        local e = c.stacks[slot]
        if sameName(e.item, name) and infoMatches(e, match) then out[#out + 1] = e end
    end
    return out
end

local function unitsOf(e)
    if e.kind == 'weapon' then return 1 end
    return tonumber(e.count) or 0
end

local function viewersCopy(id)
    local out, first = {}, false
    for v in pairs(State.viewersOf(id)) do out[v] = true; first = first or v end
    return out, first
end

function M.view(c)
    if not c then return nil end
    local items = {}
    for slot, e in pairs(c.stacks) do items[slot] = stackOf(e) end
    local _, cap, load = Weight.pool(c)
    local viewers, holder = viewersCopy(c.id)
    local f = c.flags or {}
    local owner = (c.kind == 'player' or c.kind == 'equip') and c.ownerCharId and State.srcOfChar(c.ownerCharId) or nil
    local co = type(f.coords) == 'table' and f.coords.x and vector3(f.coords.x + 0.0, f.coords.y + 0.0, f.coords.z + 0.0) or nil
    return {
        id = c.id, type = typeOf(c), kind = c.kind, label = c.label, slots = c.slots,
        maxWeight = cap and G(cap) or nil, weight = G(load or 0),
        items = items, isOpen = holder, viewers = viewers,
        coords = co, reach = tonumber(f.reach), ownerSrc = owner, charId = c.ownerCharId,
    }
end

-- ------------------------------------------------------------
-- item definitions (grams, rsg-core keys)
-- ------------------------------------------------------------

local function weaponDefOld(name)
    local w = WeaponDefs.get(name)
    if not w then return nil end
    local lname = w.name:lower()
    local thrown = w.group == 'thrown'
    return {
        name = lname, label = w.label, weight = G(w.weight or 0), type = 'weapon', image = lname .. '.png',
        unique = not thrown, useable = true, usable = true, shouldClose = true, description = w.desc or '',
        desc = w.desc or '', limit = 0, canRemove = true, category = 'weapons',
        ammotype = w.ammoTypes and w.ammoTypes[1] or nil, group = w.group,
    }
end

---Item definition in the rsg-core shape (weight in grams) or nil.
function M.def(name)
    if type(name) ~= 'string' or name == '' then return nil end
    local d, key = RsgInv.defOf(name)
    if not d and Util.isWeaponName(name) then return weaponDefOld(name) end
    if not d then return nil end
    local raw = RsgInv.rawDef and RsgInv.rawDef(key) or {}
    local weapon = d.type == 'item_weapon' or raw.type == 'weapon' or Util.isWeaponName(key)
    local ammo = Config.Weapons.ammoItems and Config.Weapons.ammoItems[key]
    local out = {
        name = key, label = d.label or key, weight = G(d.weight or 0),
        type = weapon and 'weapon' or (raw.type or (ammo and 'ammo') or 'item'),
        image = d.image or raw.image or (key .. '.png'),
        unique = d.unique == true or raw.unique == true or weapon,
        useable = d.usable == true or raw.useable == true or Usables.isRegistered(key),
        shouldClose = raw.shouldClose ~= false,
        description = d.desc or raw.description or '', desc = d.desc or raw.description or '',
        limit = tonumber(d.limit) or 0, canRemove = d.canRemove ~= false,
        category = raw.category or d.category or d.group, combinable = raw.combinable,
        decay = (tonumber(d.degradation) or 0) > 0 and d.degradation or raw.decay, delete = raw.delete,
        ammotype = raw.ammotype or (ammo and ammo.type) or nil, ammoPer = ammo and ammo.amount or nil,
    }
    out.usable = out.useable
    if weapon then
        local w = WeaponDefs.get(key)
        if w then out.group = w.group; out.unique = w.group ~= 'thrown' end
    end
    return out
end

function M.items()
    local out = {}
    for name in pairs(Registry.all()) do
        local d = M.def(name)
        if d then out[d.name] = d end
    end
    for name in pairs(WeaponDefs.all()) do
        local lname = name:lower()
        if not out[lname] then out[lname] = weaponDefOld(name) end
    end
    return out
end

function M.weaponData(name)
    local function one(w)
        local lname = w.name:lower()
        local thrown = w.group == 'thrown'
        return {
            name = lname, hash = Util.joaat(w.name), group = w.group, type = w.group, label = w.label,
            ammoTypes = w.ammoTypes or {}, ammoType = w.ammoTypes and w.ammoTypes[1] or nil,
            thrown = thrown, melee = w.group == 'melee', noAmmo = not (w.ammoTypes and w.ammoTypes[1]),
            weight = G(w.weight or 0), clip = w.clip,
        }
    end
    if name then
        local w = WeaponDefs.get(name)
        return w and one(w) or nil
    end
    local out = {}
    for _, w in pairs(WeaponDefs.all()) do out[w.name:lower()] = one(w) end
    return out
end

---Gunbelt ammo data:
---{ gunbelt = true,
---  ammo  = { [AMMO_X] = { name, label, max, item = loose round item|nil, refill = rounds per box|nil } },
---  boxes = { [item] = { ammo = AMMO_X, rounds = n } }   items that put n rounds on the belt (one used),
---  rounds = { [item] = AMMO_X }                         loose rounds (the whole stack goes on the belt),
---  items = { [item] = AMMO_X } }                        every item that feeds the gunbelt
function M.ammoData()
    local out = { gunbelt = true, ammo = {}, boxes = {}, rounds = {}, items = {} }
    for t in pairs(AmmoDefs.all()) do
        local a = AmmoDefs.get(t)
        out.ammo[t] = { name = t, label = a.label, max = a.max }
    end
    for item, spec in pairs(Config.Weapons.ammoItems or {}) do
        local t = tostring(spec.type):upper()
        if out.ammo[t] and Registry.get(item) then
            out.items[item] = t
            if spec.wholeStack then
                out.rounds[item] = t
                out.ammo[t].item = out.ammo[t].item or item
            else
                out.boxes[item] = { ammo = t, rounds = tonumber(spec.amount) or 1 }
                local r = out.ammo[t].refill
                if not r or (tonumber(spec.amount) or 0) > r then out.ammo[t].refill = tonumber(spec.amount) end
            end
        end
    end
    return out
end

-- ------------------------------------------------------------
-- RegisterItem: the engine registry AND RSGCore.Shared.Items
-- ------------------------------------------------------------

local function rsgShape(def)
    local name = def.name:lower()
    return {
        name = name, label = def.label or name, weight = tonumber(def.weight) or 0,
        type = def.type or 'item', image = def.image or (name .. '.png'),
        unique = def.unique == true, useable = (def.useable == true or def.usable == true),
        shouldClose = def.shouldClose ~= false, description = def.description or def.desc or '',
        category = def.category, decay = def.decay, delete = def.delete, combinable = def.combinable,
        ammotype = def.ammotype, info = type(def.info) == 'table' and def.info or nil,
    }
end

function M.RegisterItem(def)
    if type(def) ~= 'table' or type(def.name) ~= 'string' or def.name == '' then return false end
    local item = rsgShape(def)
    local core = RsgInv.core()
    local known = core and core.Shared and core.Shared.Items and core.Shared.Items[item.name]
    local ok = pcall(function()
        if known then exports['rsg-core']:UpdateItem(item.name, item) else exports['rsg-core']:AddItem(item.name, item) end
    end)
    if not ok and core and core.Shared and core.Shared.Items then core.Shared.Items[item.name] = item end
    RsgInv.syncOne(item.name, item)
    return Registry.get(item.name) ~= nil
end

-- ------------------------------------------------------------
-- reach (stashes created with coords): checked on every player-driven move
-- ------------------------------------------------------------

local testCoords = {}

function M.PlayerCoords(src)
    if SELFTEST and testCoords[src] then return testCoords[src] end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

local function isAdmin(src)
    return src and src > 0 and (IsPlayerAceAllowed(src, 'command') or IsPlayerAceAllowed(src, Config.Admin.ace)) or false
end

local PLAYER_REASONS = { move = true, split = true, merge = true, sort = true, give = true, drop = true }

local function inReach(src, c)
    local f = c.flags or {}
    if type(f.coords) ~= 'table' or not f.coords.x then return true end
    if isAdmin(src) then return true end
    local p = M.PlayerCoords(src)
    if not p then return false end
    local d = #(vector3(p.x, p.y, p.z) - vector3(f.coords.x + 0.0, f.coords.y + 0.0, f.coords.z + 0.0))
    return d <= (tonumber(f.reach) or DEFAULT_REACH)
end
M.inReach = inReach

local function reachHook(c, ctx)
    if not ctx or not ctx.src or not PLAYER_REASONS[ctx.reason or ''] then return true end
    if c.kind == 'player' or c.kind == 'equip' then return true end
    if inReach(ctx.src, c) then return true end
    local src = ctx.src
    SetTimeout(0, function() State.close(src, true) end)
    return false, 'too_far'
end
InvHooks.register('canAdd', function(c, _item, _count, _meta, ctx) return reachHook(c, ctx) end)
InvHooks.register('canRemove', function(c, _entry, _count, ctx) return reachHook(c, ctx) end)

-- ------------------------------------------------------------
-- the export functions
-- ------------------------------------------------------------

function API.IsReady() return InvDB.ready() end
function API.PlayerInv(src) return M.PlayerInv(src) end

function API.Exists(inv)
    local id = idOf(inv)
    if type(id) ~= 'string' or id == '' then return nil end
    if not InvDB.ready() then return nil end
    if isPlayerKind(id) then return M.view(Containers.peek(id)) end
    return M.view(Containers.get(id))
end

function API.Get(inv)
    ready()
    local id = idOf(inv)
    if type(id) ~= 'string' or id == '' then return nil end
    if isPlayerKind(id) then return M.view(M.container(id)) end
    local c = Containers.get(id)
    if not c and Containers.kindOf(id) ~= 'drop' then
        API.Create(id, nil)
        c = Containers.get(id, { create = true })
    end
    return M.view(c)
end

local function defineFrom(id, data)
    data = type(data) == 'table' and data or {}
    local c = Containers.get(id)
    local prev = Containers.getDefinition(id) or {}
    local def = {}
    def.kind = (c and c.kind) or prev.kind or 'stash'
    def.label = data.label or (c and c.label) or prev.label or tostring(id):gsub('^%a+:', '')
    def.slots = tonumber(data.slots) or (c and c.slots) or tonumber(prev.slots) or STASH_SLOTS
    local g = tonumber(data.maxWeight or data.maxweight)
    if g then def.maxWeight = KG(g)
    elseif c then def.maxWeight = c.maxWeight
    elseif prev.maxWeight then def.maxWeight = prev.maxWeight
    else def.maxWeight = KG(STASH_GRAMS) end
    local flags = {}
    for k, v in pairs((c and c.flags) or prev.flags or { acceptWeapons = true }) do flags[k] = v end
    if data.coords then
        local co = data.coords
        flags.coords = { x = (co.x or co[1]) + 0.0, y = (co.y or co[2]) + 0.0, z = (co.z or co[3]) + 0.0 }
    end
    if tonumber(data.reach) then flags.reach = tonumber(data.reach) end
    if data.acceptWeapons ~= nil then flags.acceptWeapons = data.acceptWeapons ~= false end
    if data.shared ~= nil then flags.shared = data.shared == true end
    def.flags = flags
    if data.ownerCharId then def.ownerCharId = tonumber(data.ownerCharId) end
    Containers.define(id, def)
end

---Create(id, { label, slots, maxWeight (grams), coords, reach, acceptWeapons, shared }) -> view
function API.Create(id, data)
    ready()
    if type(id) ~= 'string' or id == '' then return nil end
    if isPlayerKind(id) then return API.Configure(id, data) end
    defineFrom(id, data)
    return M.view(Containers.get(id, { create = true }))
end

---Configure(id, data): updates the size / label / coords of an inventory that exists -> view|nil
function API.Configure(id, data)
    ready()
    id = idOf(id)
    if type(id) ~= 'string' or id == '' then return nil end
    if isPlayerKind(id) then
        local c = M.container(id)
        if c and type(data) == 'table' and tonumber(data.slots) then c.slots = math.floor(tonumber(data.slots)) end
        if c and type(data) == 'table' and tonumber(data.maxWeight or data.maxweight) and c.ownerCharId then
            M.capOverride[c.ownerCharId] = KG(tonumber(data.maxWeight or data.maxweight))
        end
        return M.view(c)
    end
    if not Containers.get(id) and not Containers.isDefined(id) then return nil end
    defineFrom(id, data)
    return M.view(Containers.get(id))
end

-- per-character carry weight set through Configure (kept until logout)
M.capOverride = M.capOverride or {}
InvHooks.register('characterUnloaded', function(_, charId) M.capOverride[tonumber(charId)] = nil end)

function M.Delete(id)
    id = idOf(id)
    if type(id) ~= 'string' or id == '' or isPlayerKind(id) then return false end
    local c = Containers.get(id)
    if not c and not Containers.isDefined(id) then return false end
    for v in pairs(State.viewersOf(id)) do State.close(v, true) end
    if c then
        local ctx = { reason = 'api', note = 'inventory deleted', resource = GetInvokingResource() or RES }
        for _, e in pairs(c.stacks) do
            if e.kind == 'weapon' and Weapons and Weapons.delete then pcall(Weapons.delete, e.weaponId, ctx) end
        end
    end
    Containers.undefine(id, true)
    Containers.forget(id)
    -- written now: a later load must not find the old rows
    Persistence.flush()
    return true
end
API.Delete = M.Delete

-- ---------------- items ----------------

---AddItem(inv, name, amount, info, slot, reason) -> true, nil, slot | false, err
function API.AddItem(inv, name, amount, info, slot, reason)
    ready()
    if type(name) ~= 'string' or name == '' then return false, 'unknown_item' end
    amount = amount == nil and 1 or tonumber(amount)
    if not validAmount(amount) then return false, 'bad_amount' end
    local c = M.container(inv, true)
    if not c then return false, 'no_inventory' end
    local weapon = Util.isWeaponName(name)
    local d, key = RsgInv.defOf(name)
    if weapon then key = name:lower()
    elseif not d then return false, 'unknown_item' end
    if slot == false then slot = nil end
    local ok, res = RsgInv.addTo(c, nil, key, amount, tonumber(slot), type(info) == 'table' and info or nil, ctxOf(reason))
    if not ok then return false, E(res) end
    RsgInv.pushNow(c)
    local p = type(res) == 'table' and res[1] or nil
    return true, nil, type(p) == 'table' and tonumber(p.slot) or nil
end

---RemoveItem(inv, name, amount, slot, infoMatch, reason) -> true, nil, removedInfo | false, err
function API.RemoveItem(inv, name, amount, slot, infoMatch, reason)
    ready()
    if type(name) ~= 'string' or name == '' then return false, 'unknown_item' end
    amount = amount == nil and 1 or tonumber(amount)
    if not validAmount(amount) then return false, 'bad_amount' end
    local c = M.container(inv)
    if not c then return false, 'no_inventory' end
    if slot == false then slot = nil end
    slot = tonumber(slot)
    local ctx = ctxOf(reason)
    local list = {}
    if slot then
        local e = c.stacks[slot]
        if e and sameName(e.item, name) and infoMatches(e, infoMatch) then list[1] = e end
    else
        list = entries(c, name, infoMatch)
    end
    local have = 0
    for _, e in ipairs(list) do have = have + unitsOf(e) end
    if have < amount then return false, 'not_enough' end
    -- plan, then check every veto before anything changes
    local plan, left = {}, amount
    for _, e in ipairs(list) do
        if left <= 0 then break end
        local take = math.min(left, unitsOf(e))
        if e.kind == 'weapon' and WeaponDefs.isThrown(WeaponDefs.get(e.item)) and take < 1 then take = 1 end
        plan[#plan + 1] = { e = e, n = take }
        left = left - take
    end
    for _, p in ipairs(plan) do
        local ok, er = InvHooks.check('canRemove', c, p.e, p.n, ctx)
        if not ok then return false, E(er) end
    end
    local info
    for _, p in ipairs(plan) do
        info = stackOf(p.e).info
        local ok, er
        if p.e.kind == 'weapon' then
            ok, er = Weapons.delete(p.e.weaponId, ctx)
        else
            ctx.rsgSlot = p.e.slot
            ok, er = Inv.removeStack(c, p.e.id, p.n, ctx)
        end
        if not ok then return false, E(er) end
    end
    RsgInv.pushNow(c)
    return true, nil, info
end

function API.Count(inv, name, infoMatch)
    if not InvDB.ready() then return 0 end
    local c = M.container(inv)
    local n = 0
    for _, e in ipairs(entries(c, name, infoMatch)) do n = n + unitsOf(e) end
    return n
end

function API.FindItems(inv, name, infoMatch)
    local out = {}
    if not InvDB.ready() then return out end
    for _, e in ipairs(entries(M.container(inv), name, infoMatch)) do out[#out + 1] = stackOf(e) end
    return out
end
API.Find = API.FindItems

function API.GetSlot(inv, slot)
    if not InvDB.ready() then return nil end
    local c = M.container(inv)
    return c and stackOf(c.stacks[tonumber(slot) or -1]) or nil
end

---CanAdd(inv, name, amount, info) -> true | false, err
function API.CanAdd(inv, name, amount, info)
    ready()
    if type(name) ~= 'string' or name == '' then return false, 'unknown_item' end
    amount = amount == nil and 1 or tonumber(amount)
    if not validAmount(amount) then return false, 'bad_amount' end
    local c = M.container(inv, true)
    if not c then return false, 'no_inventory' end
    if Util.isWeaponName(name) then
        local ok, er = Weapons.canCarry(c, amount, name:upper())
        if not ok then return false, E(er) end
        return true
    end
    local d, key = RsgInv.defOf(name)
    if not d then return false, 'unknown_item' end
    local meta = RsgInv.fromInfo(key, info)
    local ok, er = Inv.canAdd(c, key, amount, meta, ctxOf('canAdd'))
    if not ok then return false, E(er) end
    if d.unique and c.slots - Containers.usedSlots(c) < amount then return false, 'no_space' end
    return true
end

---ItemCount(inv, { skipWeapons, skipAmmo }) -> total units in the inventory
function API.ItemCount(inv, opts)
    if not InvDB.ready() then return 0 end
    local c = M.container(inv)
    if not c then return 0 end
    opts = type(opts) == 'table' and opts or {}
    local ammo = Config.Weapons.ammoItems or {}
    local n = 0
    for _, e in pairs(c.stacks) do
        local isW = e.kind == 'weapon'
        if not (opts.skipWeapons and isW) and not (opts.skipAmmo and not isW and ammo[e.item]) then n = n + unitsOf(e) end
    end
    return n
end

local function writeInfo(c, e, info)
    if e.kind == 'weapon' then return RsgInv.setWeaponInfo(e.weaponId, info) end
    local meta, decayAt = RsgInv.fromInfo(e.item, info)
    local ok = Inv.setMetadata(c, e.id, meta, nil, { reason = 'api', resource = GetInvokingResource() or RES })
    if ok and decayAt and c.stacks[e.slot] then c.stacks[e.slot].decayAt = decayAt; Containers.touch(c, e.slot) end
    if ok then RsgInv.pushNow(c) end
    return ok and true or false
end

---SetInfo(inv, slot, info): merges keys into a stack's info
function API.SetInfo(inv, slot, info)
    ready()
    local c = M.container(inv)
    local e = c and c.stacks[tonumber(slot) or -1]
    if not e or type(info) ~= 'table' then return false end
    local cur = stackOf(e).info or {}
    for k, v in pairs(info) do cur[k] = v end
    return writeInfo(c, e, cur)
end

---ReplaceInfo(inv, slot, info): replaces a stack's info
function API.ReplaceInfo(inv, slot, info)
    ready()
    local c = M.container(inv)
    local e = c and c.stacks[tonumber(slot) or -1]
    if not e or type(info) ~= 'table' then return false end
    return writeInfo(c, e, Util.deepcopy(info))
end

---Weight(inv) -> grams carried
function API.Weight(inv)
    if type(inv) == 'table' and inv.weight then return inv.weight end
    local c = M.container(inv)
    if not c then return 0 end
    local _, _, load = Weight.pool(c)
    return G(load or 0)
end

---Save(inv, await): MULTIinventory saves by itself; this writes everything waiting now.
function API.Save(_inv, await)
    if not InvDB.ready() then return false end
    if await then return Persistence.flush() end
    CreateThread(function() Persistence.flush() end)
    return true
end

-- ---------------- definitions ----------------

function API.GetItemDef(name) return M.def(name) end
function API.GetItems() return M.items() end
function API.RegisterItem(def) ready() return M.RegisterItem(def) end
function API.GetWeaponData(name) return M.weaponData(name) end
function API.GetAmmoData() return M.ammoData() end

-- ---------------- usables ----------------

---RegisterUsable(name, fn(src, stack, invId), { builtin = true }) - builtin runs only when nothing
---else handles the item. Removed when the registering resource stops.
function API.RegisterUsable(name, fn, opts)
    if type(name) ~= 'string' or name == '' or fn == nil then return false end
    opts = type(opts) == 'table' and opts or {}
    local owner = opts.resource or GetInvokingResource() or RES
    return Usables.register(name:lower(), fn, owner, { builtin = opts.builtin == true, style = 'multi' })
end

function API.UnregisterUsable(name, resource)
    if type(name) ~= 'string' then return false end
    return Usables.unregister(name:lower(), resource)
end

function API.IsUsable(name) return type(name) == 'string' and Usables.isRegistered(name:lower()) end

local function downOrCuffed(src)
    local p = RsgInv.getPlayer(src)
    local m = p and p.PlayerData and p.PlayerData.metadata
    return type(m) == 'table' and (m.isdead == true or m.ishandcuffed == true)
end

---Use(src, slot): uses the item in the player's satchel slot (weapons are equipped) -> ok, err
function M.Use(src, slot)
    ready()
    src, slot = tonumber(src), tonumber(slot)
    local st = src and State.get(src)
    if not st then return false, 'no_player' end
    local c = Containers.peek('player:' .. st.charId)
    local e = c and slot and c.stacks[slot]
    if not e then return false, 'no_item' end
    if downOrCuffed(src) then return false, 'blocked' end
    if e.kind == 'weapon' then
        local ok, er = Weapons.equip(src, e.weaponId)
        return ok and true or false, E(er)
    end
    local name = e.item
    local ok, er = Usables.use(src, c.id, slot, { src = src, reason = 'use', api = true })
    if ok then
        API.ItemBox(src, name, 1, 'use')
        TriggerEvent('MULTIinventory:used', src, name, slot)
    end
    return ok, E(er)
end
API.Use = M.Use

---UseByName(src, name, stack?) runs the use handlers of an item without a slot.
function API.UseByName(src, name, stack)
    ready()
    return Usables.useByName(tonumber(src), name, stack, { src = tonumber(src), reason = 'use', api = true })
end

-- ---------------- open / close ----------------

local function setBusy(src, v)
    pcall(function() Player(src).state:set('inv_busy', v, true) end)
end

---Open(src, id | { id, type, label, slots, maxWeight }, opts) -> true | false, err
function M.Open(src, target, opts)
    ready()
    src = tonumber(src)
    local st = src and State.get(src)
    if not st then return false, 'no_player' end
    local id, data = target, opts
    if type(target) == 'table' then
        data = target
        id = target.id
        if id and target.type and not tostring(id):find(':') then id = target.type .. ':' .. id end
    end
    if id == nil or id == 'player:' .. st.charId then
        if State.secondaryOf(src) then State.close(src, false) end
        return State.open(src, nil)
    end
    if type(id) == 'number' then return API.OpenPlayer(src, id) end
    if type(id) ~= 'string' or id == '' then return false, 'bad_id' end
    if isPlayerKind(id) then
        local other = Containers.peek(id)
        local tsrc = other and other.ownerCharId and State.srcOfChar(other.ownerCharId)
        if not tsrc then return false, 'no_inventory' end
        return API.OpenPlayer(src, tsrc)
    end
    if Containers.kindOf(id) == 'drop' then
        if not Containers.get(id) then return false, 'no_inventory' end
    elseif not Containers.get(id) and not Containers.isDefined(id) then
        defineFrom(id, data)
    elseif type(data) == 'table' and (data.label or data.slots or data.maxWeight or data.maxweight or data.coords) then
        defineFrom(id, data)
    end
    local ok, er = State.open(src, id, { label = type(data) == 'table' and data.label or nil })
    if not ok then
        er = E(er)
        if er == 'in_use' then Sync.notify(src, L('secondary_locked'), 'error') end
        return false, er
    end
    return true
end
API.Open = M.Open

function API.Close(src)
    src = tonumber(src)
    if not src then return end
    State.close(src, true)
    setBusy(src, false)
end

---OpenPlayer(officer, target): the officer looks into another player's satchel (the caller checks the rules)
function API.OpenPlayer(src, target)
    ready()
    src, target = tonumber(src), tonumber(target)
    local tst = target and State.get(target)
    if not tst or not State.get(src) or target == src then return false, 'no_player' end
    if State.isOpen(target) then State.close(target, true) end
    local label = (tst.name and tst.name ~= '') and tst.name or GetPlayerName(target)
    local ok, er = SecondarySearch.openFor({ source = src, target = target, title = label })
    if not ok then return false, E(er) end
    setBusy(target, true)
    return true
end

function API.CanAccess(src, id) return State.canAccess(tonumber(src), idOf(id)) end

---Move(src, fromId, fromSlot, toId, toSlot, amount): a move as the player makes it -> ok, err
function API.Move(src, fromId, fromSlot, toId, toSlot, amount)
    ready()
    src = tonumber(src)
    fromId, toId = idOf(fromId), idOf(toId)
    if not src or not State.get(src) then return false, 'no_player' end
    if not State.canAccess(src, fromId) or not State.canAccess(src, toId) then return false, 'no_access' end
    local fc, tc = M.container(fromId), M.container(toId)
    if not fc or not tc then return false, 'no_inventory' end
    if fc == tc and toSlot == nil then toSlot = Containers.freeSlot(fc) if not toSlot then return false, 'no_space' end end
    local ok, er = Inv.move(fc, tonumber(fromSlot), tc, tonumber(toSlot), tonumber(amount),
        { src = src, reason = 'move', from = fc.id, to = tc.id })
    if ok then RsgInv.pushNow(fc); RsgInv.pushNow(tc) end
    return ok and true or false, E(er)
end

-- ---------------- pop-ups ----------------

---ItemBox(src, name, amount, 'add'|'remove'|'use'): the small item pop-up on the player's screen
function API.ItemBox(src, name, amount, action)
    src = tonumber(src)
    if not src or src <= 0 or type(name) ~= 'string' then return end
    local d = M.def(name) or { name = name, label = name, image = name .. '.png' }
    TriggerClientEvent('MULTIinventory:client:itembox', src, { name = d.name, label = d.label, image = d.image }, amount, action)
end

-- ---------------- weapons ----------------

---WeaponNew(name, info) -> info for AddItem(inv, weaponName, 1, info); the serial is given when it is added
function API.WeaponNew(_name, info)
    info = type(info) == 'table' and Util.deepcopy(info) or {}
    info.quality = info.quality or 100
    info.components = type(info.components) == 'table' and info.components or {}
    return info
end

function API.WeaponFindById(id)
    local r = Weapons.get(tonumber(id))
    if not r then return nil end
    local c = Containers.peek(r.container)
    return r.container, r.slot, c and stackOf(c.stacks[r.slot]) or nil
end

function API.WeaponFindBySerial(serial)
    local r = serial and Weapons.bySerial(serial)
    if not r then return nil end
    local c = Containers.peek(r.container)
    return r.container, r.slot, c and stackOf(c.stacks[r.slot]) or nil
end

-- ---------------- test hooks (setr multicore_selftest true only) ----------------

function API._TestSetCoords(src, x, y, z)
    if not SELFTEST then return false end
    src = tonumber(src)
    if not src then return false end
    testCoords[src] = x and vector3(x + 0.0, y + 0.0, z + 0.0) or nil
    return true
end

-- ------------------------------------------------------------
-- events
-- ------------------------------------------------------------

AddEventHandler('MULTIinventory:containerOpened', function(src, id)
    local st = State.get(src)
    if not st or type(id) ~= 'string' then return end
    setBusy(src, true)
    if id ~= 'player:' .. st.charId then TriggerEvent('MULTIinventory:opened', src, id) end
end)

AddEventHandler('MULTIinventory:containerClosed', function(src, id)
    if type(id) == 'string' then TriggerEvent('MULTIinventory:closed', src, id) end
    -- a searched player's satchel is free again
    local c = Containers.peek(id)
    if c and c.kind == 'player' and c.ownerCharId then
        local t = State.srcOfChar(c.ownerCharId)
        if t and t ~= src then setBusy(t, false) end
    end
end)

-- the player closed the screen (State.close from the client action): satchel no longer busy
AddEventHandler('MULTIinventory:uiClosed', function(src) setBusy(src, false) end)

AddEventHandler('playerDropped', function() testCoords[source] = nil end)

-- carry weight set with Configure wins over the character's own (until logout)
InvHooks.prepend('capacity', function(charId) return M.capOverride[tonumber(charId)] end)

---Start-up (server/core/boot.lua, before IsReady turns true): item definitions the gunbelt needs.
function M.beforeReady()
    RsgInv.syncItems()
    for item, spec in pairs(Config.Weapons.ammoItems or {}) do
        if spec.wholeStack and not Registry.get(item) and AmmoDefs.get(spec.type) then
            local arrow = tostring(spec.type):find('ARROW', 1, true) ~= nil
            M.RegisterItem({
                name = item, label = spec.label or AmmoDefs.get(spec.type).label, weight = arrow and 30 or 5,
                type = 'item', image = item .. '.png', unique = false, useable = true, shouldClose = true,
                description = AmmoDefs.get(spec.type).label, category = 'ammo',
            })
        end
    end
end

M.API = API
for name, fn in pairs(API) do exports(name, fn) end
