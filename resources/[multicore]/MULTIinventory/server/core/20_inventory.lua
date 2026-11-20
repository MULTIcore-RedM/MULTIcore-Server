-- ============================================================
-- MULTIinventory :: inventories, slots, weight, limits, stacking,
-- persistence and change events (server)
--
-- Stack shape (also what RSG's Player.PlayerData.items holds):
--   { name, amount, info = {}, label, description, weight (per unit), type, unique,
--     useable, image, shouldClose, slot, combinable }
-- Saved shape (players.inventory and inventories.items, RSG's):
--   [ { name, amount, info, type, slot }, ... ]
--
-- Add / remove rules, the stack shape, the saved shape, weapon serials and
-- item decay follow rsg-inventory (GPL v3, RSG / Rexshack-RedM team):
-- see Inventory.AddItem / RemoveItem / SaveInventory / CheckItemDecay there.
-- VORP's rules sit on top: per-item limit, total item count, white/black lists.
-- ============================================================

local Inv = MULTIInv

local STASH_TYPES = { stash = true, glovebox = true, trunk = true, custom = true }

-- ------------------------------------------------------------
-- ids
-- ------------------------------------------------------------

--- 'stash' for 'stash:abc' (the part before the first colon), 'stash' for anything without a prefix.
function Inv.TypeOf(id)
    local t = type(id) == 'string' and id:match('^(%a+):') or nil
    if t == 'player' or t == 'drop' or STASH_TYPES[t] then return t end
    return 'stash'
end

--- The `inventories.identifier` key for an inventory id. Stashes keep RSG's bare name,
--- so stashes saved by rsg-inventory load straight away.
function Inv.DbKey(id)
    return id:match('^stash:(.+)$') or id
end

function Inv.FromDbKey(key)
    local t = key:match('^(%a+):')
    if t and (STASH_TYPES[t] or t == 'player') then return key end
    return 'stash:' .. key
end

--- 'player:<citizenid>' for a logged-in source (nil if none).
function Inv.PlayerInv(src)
    src = tonumber(src)
    if not src then return nil end
    if Inv.BySrc[src] then return Inv.BySrc[src] end
    local P = Inv.GetPlayer(src)
    return P and ('player:' .. P.PlayerData.citizenid) or nil
end

-- ------------------------------------------------------------
-- create / find
-- ------------------------------------------------------------

local function defaultsFor(t)
    if t == 'player' then return Config.Player.Slots, Config.Player.MaxWeight end
    if t == 'drop' then return Config.Drop.Slots, Config.Drop.MaxWeight end
    return Config.Stash.Slots, Config.Stash.MaxWeight
end

--- Makes an empty inventory in memory (replaces nothing that exists).
--- data = { label, slots, maxWeight | maxweight, maxCount, coords, reach, itemLimits, whitelist, blacklist, acceptWeapons, ignoreItemLimits }
--- (reach = metres from coords within which items may be moved; default Config.MaxDistance)
function Inv.Create(id, data)
    if Inv.List[id] then return Inv.Configure(id, data) end
    data = data or {}
    local t = Inv.TypeOf(id)
    local slots, weight = defaultsFor(t)
    local inv = {
        id = id,
        type = t,
        label = data.label or id:gsub('^%a+:', ''),
        slots = tonumber(data.slots) or slots,
        maxWeight = tonumber(data.maxWeight or data.maxweight) or weight,
        maxCount = tonumber(data.maxCount),
        coords = data.coords,
        reach = tonumber(data.reach),
        items = {},
        isOpen = false,
        viewers = {},
        dirty = false,
        itemLimits = data.itemLimits or {},
        whitelist = data.whitelist,
        blacklist = data.blacklist,
        acceptWeapons = data.acceptWeapons,
        ignoreItemLimits = data.ignoreItemLimits,
        createdTime = os.time(),
    }
    Inv.List[id] = inv
    return inv
end

--- Updates the size / label of an inventory with the values given.
function Inv.Configure(id, data)
    local inv = Inv.List[id]
    if not inv or type(data) ~= 'table' then return inv end
    if data.label then inv.label = data.label end
    if tonumber(data.slots) then inv.slots = tonumber(data.slots) end
    local w = tonumber(data.maxWeight or data.maxweight)
    if w then inv.maxWeight = w end
    if data.maxCount ~= nil then inv.maxCount = tonumber(data.maxCount) end
    if data.coords then inv.coords = data.coords end
    if tonumber(data.reach) then inv.reach = tonumber(data.reach) end
    for _, k in ipairs({ 'itemLimits', 'whitelist', 'blacklist', 'acceptWeapons', 'ignoreItemLimits' }) do
        if data[k] ~= nil then inv[k] = data[k] end
    end
    return inv
end

--- Is this slot held by a pending trade offer? (server/core/70_trade.lua sets inv.tradeLocks)
--- A locked slot cannot be moved, swapped onto, used, given or dropped until the trade ends.
function Inv.SlotLocked(inv, slot)
    slot = tonumber(slot)
    return type(inv) == 'table' and inv.tradeLocks ~= nil and slot ~= nil and inv.tradeLocks[slot] ~= nil
end

--- An inventory that exists (nil otherwise). Never creates.
function Inv.Exists(id)
    if type(id) ~= 'string' then return nil end
    return Inv.List[id]
end

--- An inventory; a stash-type id that does not exist yet is created empty.
function Inv.Get(id)
    if type(id) ~= 'string' then return nil end
    local inv = Inv.List[id]
    if inv then return inv end
    if STASH_TYPES[Inv.TypeOf(id)] then return Inv.Create(id) end
    return nil
end

function Inv.Delete(id)
    local inv = Inv.List[id]
    if not inv or inv.type == 'player' then return false end
    for src in pairs(inv.viewers) do Inv.Close(src) end
    Inv.List[id] = nil
    if STASH_TYPES[inv.type] then
        MySQL.prepare('DELETE FROM inventories WHERE identifier = ?', { Inv.DbKey(id) })
    end
    return true
end

-- ------------------------------------------------------------
-- reading
-- ------------------------------------------------------------

function Inv.StackWeight(stack)
    local def = Inv.Items[stack.name]
    local w = tonumber(stack.weight) or (def and def.weight) or 0
    return w * (tonumber(stack.amount) or 0)
end

function Inv.Weight(inv)
    local w = 0
    for _, s in pairs(inv.items) do w = w + Inv.StackWeight(s) end
    return w
end

function Inv.TotalCount(inv)
    local n = 0
    for _, s in pairs(inv.items) do n = n + (s.amount or 0) end
    return n
end

--- Weapon or ammo item (not counted by VORP's invCapacity)?
function Inv.IsWeaponOrAmmo(def)
    if not def then return false end
    return def.type == 'weapon' or def.type == 'ammo'
        or (Inv.AmmoItems ~= nil and Inv.AmmoItems[def.name] ~= nil) or MULTIInvData.Weapons[def.name] ~= nil
end

function Inv.ItemCountIn(inv, skipWeapons, skipAmmo)
    local n = 0
    for _, s in pairs(inv.items) do
        local def = Inv.Items[s.name]
        local isWeapon = def ~= nil and (def.type == 'weapon' or MULTIInvData.Weapons[s.name] ~= nil)
        local isAmmo = def ~= nil and not isWeapon and Inv.IsWeaponOrAmmo(def)
        if not (skipWeapons and isWeapon) and not (skipAmmo and isAmmo) then n = n + (s.amount or 0) end
    end
    return n
end

--- Item count with options { skipWeapons = bool, skipAmmo = bool } (VORP invCapacity counts with both true).
function Inv.ItemCount(invId, opts)
    local inv = Inv.Get(invId)
    if not inv then return 0 end
    opts = type(opts) == 'table' and opts or {}
    return Inv.ItemCountIn(inv, opts.skipWeapons, opts.skipAmmo)
end

--- Sets the VORP item-count capacity of an inventory (player satchels: from metadata.vorp.invCapacity). 0/nil = none.
function Inv.SetCapacity(invId, n)
    local inv = Inv.Get(invId)
    if not inv then return false end
    inv.invCapacity = tonumber(n)
    return true
end

function Inv.UsedSlots(inv)
    local n = 0
    for _ in pairs(inv.items) do n = n + 1 end
    return n
end

local function sortedSlots(items)
    local list = {}
    for slot in pairs(items) do list[#list + 1] = slot end
    table.sort(list)
    return list
end

function Inv.FirstFreeSlot(inv, from)
    for i = from or 1, inv.slots do
        if inv.items[i] == nil then return i end
    end
    return nil
end

local function countIn(inv, name, infoMatch)
    local n = 0
    for _, s in pairs(inv.items) do
        if s.name == name and Inv.InfoMatches(s.info, infoMatch) then n = n + s.amount end
    end
    return n
end

-- ------------------------------------------------------------
-- decay (from rsg-inventory CheckItemDecay / CheckItemsDecay)
-- ------------------------------------------------------------

local function round1(x) return math.floor(x * 10 + 0.5) / 10 end

--- Returns updated, newQuality, shouldDelete for one stack.
function Inv.CheckItemDecay(stack, def, now, rate)
    def = def or Inv.Items[stack.name]
    if not def or not def.decay then return false, nil, false end
    now = now or os.time()
    if type(stack.info) ~= 'table' then stack.info = {} end
    if not stack.info.quality or not stack.info.lastUpdate then
        stack.info.quality = stack.info.quality or 100
        stack.info.lastUpdate = now
        return true, stack.info.quality, def.delete == true
    end
    rate = rate or 1
    local elapsed = now - stack.info.lastUpdate
    local perSecond = (100 / (def.decay * 60)) * rate
    stack.info.quality = round1(math.max(0, stack.info.quality - elapsed * perSecond))
    stack.info.lastUpdate = now
    return true, stack.info.quality, def.delete == true
end

--- Stash names may carry a decay modifier, e.g. 'fridge_decay25' (25 % speed). From rsg-inventory.
local function decayRateFor(inv)
    local num = inv.id:lower():match('decay(%d+)')
    return num and (tonumber(num) / 100) or 1
end

function Inv.CheckDecay(inv)
    if not Config.Decay.Enabled then return end
    local now, rate = os.time(), decayRateFor(inv)
    local removed = false
    for slot, s in pairs(inv.items) do
        local updated, q, del = Inv.CheckItemDecay(s, nil, now, rate)
        if updated and del and q <= 0 then
            inv.items[slot] = nil
            removed = true
            Inv.Changed(inv, { action = 'remove', name = s.name, amount = s.amount, slot = slot, reason = 'decay' })
        end
    end
    return removed
end

-- ------------------------------------------------------------
-- weapons
-- ------------------------------------------------------------

Inv.Weapon = Inv.Weapon or {}
local nextWeaponId = 0

function Inv.Weapon._SetCounter(n) nextWeaponId = math.max(nextWeaponId, tonumber(n) or 0) end

local function newWeaponId()
    nextWeaponId = nextWeaponId + 1
    MySQL.prepare("INSERT INTO multiinventory_kv (k, v) VALUES ('weapon_id', ?) ON DUPLICATE KEY UPDATE v = GREATEST(v, VALUES(v))",
        { tostring(nextWeaponId) })
    return nextWeaponId
end

-- serial in rsg-inventory's pattern: 2 digits, 3 letters, 1 digit, 2 letters, 3 digits, 4 letters
local L, D = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', '0123456789'
local function rnd(set, n)
    local t = {}
    for i = 1, n do
        local k = math.random(1, #set)
        t[i] = set:sub(k, k)
    end
    return table.concat(t)
end
function Inv.Weapon.NewSerial()
    return rnd(D, 2) .. rnd(L, 3) .. rnd(D, 1) .. rnd(L, 2) .. rnd(D, 3) .. rnd(L, 4)
end

--- Weapon item info with a fresh serial and id (info given is kept and filled in).
function Inv.Weapon.New(name, info)
    info = type(info) == 'table' and Inv.DeepCopy(info) or {}
    info.serie = info.serie or Inv.Weapon.NewSerial()
    info.quality = info.quality or Config.Weapons.DefaultQuality
    info.id = tonumber(info.id) or newWeaponId()
    info.components = type(info.components) == 'table' and info.components or {}
    return info
end

--- invId, slot, stack of the weapon with this id (any loaded inventory), or nil.
function Inv.Weapon.FindById(id)
    id = tonumber(id)
    if not id then return nil end
    for invId, inv in pairs(Inv.List) do
        for slot, s in pairs(inv.items) do
            if s.info and tonumber(s.info.id) == id and Inv.Items[s.name] and Inv.Items[s.name].type == 'weapon' then
                return invId, slot, s
            end
        end
    end
end

--- Same by serial.
function Inv.Weapon.FindBySerial(serial)
    if not serial then return nil end
    for invId, inv in pairs(Inv.List) do
        for slot, s in pairs(inv.items) do
            if s.info and s.info.serie == serial then return invId, slot, s end
        end
    end
end

local function isSerialWeapon(def)
    local w = MULTIInvData.Weapons[def.name]
    return def.type == 'weapon' and not (w and w.thrown)
end

-- ------------------------------------------------------------
-- stacks
-- ------------------------------------------------------------

function Inv.MakeStack(def, amount, info, slot)
    return {
        name = def.name,
        amount = amount,
        info = info,
        label = def.label,
        description = def.description or '',
        weight = def.weight,
        type = def.type,
        unique = def.unique,
        useable = def.useable,
        image = def.image,
        shouldClose = def.shouldClose,
        slot = slot,
        combinable = def.combinable,
    }
end

--- info as it will be stored for a new stack (copy, item defaults, decay fields).
local function prepareInfo(def, info)
    info = type(info) == 'table' and Inv.DeepCopy(info) or {}
    if type(def.info) == 'table' then
        for k, v in pairs(def.info) do if info[k] == nil then info[k] = Inv.DeepCopy(v) end end
    end
    if Config.Decay.Enabled and def.decay then
        info.quality = info.quality or 100
        info.lastUpdate = info.lastUpdate or os.time()
    end
    return info
end

-- ------------------------------------------------------------
-- limits
-- ------------------------------------------------------------

local function itemLimit(inv, def)
    if inv.ignoreItemLimits then return 0 end
    local l = inv.itemLimits and inv.itemLimits[def.name]
    if l then return tonumber(l) or 0 end
    if inv.type == 'player' and Config.Player.UseItemLimits then return def.limit or 0 end
    return 0
end

local function stackable(def) return not def.unique and not isSerialWeapon(def) end

local function findStack(inv, def, info)
    for _, slot in ipairs(sortedSlots(inv.items)) do
        local s = inv.items[slot]
        if s.name == def.name and Inv.InfoEqual(s.info, info) then return slot end
    end
end

--- Can `amount` of `name` (with `info`) go in? → true | false, err
--- err: 'unknown_item', 'bad_amount', 'too_heavy', 'limit', 'no_space', 'not_allowed', 'no_inventory'
function Inv.CanAddTo(inv, name, amount, info)
    if not inv then return false, 'no_inventory' end
    local def = Inv.GetItemDef(name)
    if not def then return false, 'unknown_item' end
    amount = Inv.Amount(amount, 1)
    if not amount then return false, 'bad_amount' end
    if inv.whitelist and not inv.whitelist[def.name] then return false, 'not_allowed' end
    if inv.blacklist and inv.blacklist[def.name] then return false, 'not_allowed' end
    if inv.acceptWeapons == false and def.type == 'weapon' then return false, 'not_allowed' end
    if Inv.Weight(inv) + def.weight * amount > inv.maxWeight then return false, 'too_heavy' end
    local limit = itemLimit(inv, def)
    if limit > 0 and countIn(inv, def.name) + amount > limit then return false, 'limit' end
    if inv.maxCount and inv.maxCount > 0 and Inv.TotalCount(inv) + amount > inv.maxCount then return false, 'no_space' end
    -- VORP invCapacity: total count of plain items (weapons and ammo not counted)
    if inv.invCapacity and inv.invCapacity > 0 and Config.Vorp.UseInvCapacity and not Inv.IsWeaponOrAmmo(def) then
        if Inv.ItemCountIn(inv, true, true) + amount > inv.invCapacity then return false, 'no_space' end
    end
    local free = inv.slots - Inv.UsedSlots(inv)
    if stackable(def) then
        if findStack(inv, def, prepareInfo(def, info)) then return true end
        if free < 1 then return false, 'no_space' end
    elseif free < amount then
        return false, 'no_space'
    end
    return true
end

function Inv.CanAdd(invId, name, amount, info)
    return Inv.CanAddTo(Inv.Get(invId), name, amount, info)
end

-- ------------------------------------------------------------
-- add / remove (the only two places items change)
-- ------------------------------------------------------------

--- Adds to an inventory table. → true, nil, firstSlot | false, err
function Inv.AddTo(inv, name, amount, info, slot, reason)
    if not inv then return false, 'no_inventory' end
    local def = Inv.GetItemDef(name)
    if not def then return false, 'unknown_item' end
    amount = Inv.Amount(amount, 1)
    if not amount then return false, 'bad_amount' end
    Inv.CheckDecay(inv)
    local ok, err = Inv.CanAddTo(inv, def.name, amount, info)
    if not ok then return false, err end

    slot = tonumber(slot)
    if slot and (slot < 1 or slot > inv.slots or slot ~= math.floor(slot)) then slot = nil end
    local placed

    if stackable(def) then
        info = prepareInfo(def, info)
        local target = slot
        local s = target and inv.items[target]
        if s and not (s.name == def.name and Inv.InfoEqual(s.info, info)) then target = nil; s = nil end
        if not target then
            target = findStack(inv, def, info)
            s = target and inv.items[target]
        end
        if s then
            s.amount = s.amount + amount
        else
            target = (slot and not inv.items[slot]) and slot or Inv.FirstFreeSlot(inv)
            inv.items[target] = Inv.MakeStack(def, amount, info, target)
        end
        placed = target
        Inv.Changed(inv, { action = 'add', name = def.name, amount = amount, slot = target, reason = reason })
    else
        -- unique: one per slot; weapons get a serial and id each
        for i = 1, amount do
            local unitInfo = prepareInfo(def, info)
            if isSerialWeapon(def) then
                if i > 1 then unitInfo.serie = nil; unitInfo.id = nil end
                unitInfo = Inv.Weapon.New(def.name, unitInfo)
            end
            local target = (i == 1 and slot and not inv.items[slot]) and slot or Inv.FirstFreeSlot(inv)
            inv.items[target] = Inv.MakeStack(def, 1, unitInfo, target)
            placed = placed or target
            Inv.Changed(inv, { action = 'add', name = def.name, amount = 1, slot = target, reason = reason })
        end
    end
    return true, nil, placed
end

--- Removes from an inventory table. → true, nil, removedInfo | false, err
function Inv.RemoveFrom(inv, name, amount, slot, infoMatch, reason)
    if not inv then return false, 'no_inventory' end
    if type(name) ~= 'string' then return false, 'unknown_item' end
    name = name:lower()
    amount = Inv.Amount(amount, 1)
    if not amount then return false, 'bad_amount' end
    Inv.CheckDecay(inv)
    slot = tonumber(slot)
    if slot then
        local s = inv.items[slot]
        if not s or s.name ~= name or s.amount < amount or not Inv.InfoMatches(s.info, infoMatch) then
            return false, 'not_enough'
        end
        local info = s.info
        s.amount = s.amount - amount
        if s.amount <= 0 then inv.items[slot] = nil end
        Inv.Changed(inv, { action = 'remove', name = name, amount = amount, slot = slot, info = info, reason = reason })
        return true, nil, info
    end
    if countIn(inv, name, infoMatch) < amount then return false, 'not_enough' end
    local left, info = amount, nil
    for _, sl in ipairs(sortedSlots(inv.items)) do
        local s = inv.items[sl]
        if s.name == name and Inv.InfoMatches(s.info, infoMatch) then
            local take = math.min(s.amount, left)
            s.amount = s.amount - take
            left = left - take
            info = s.info
            if s.amount <= 0 then inv.items[sl] = nil end
            Inv.Changed(inv, { action = 'remove', name = name, amount = take, slot = sl, info = info, reason = reason })
            if left <= 0 then break end
        end
    end
    return true, nil, info
end

-- engine API by id (INVENTORY.md)
function Inv.AddItem(invId, name, amount, info, slot, reason)
    return Inv.AddTo(Inv.Get(invId), name, amount, info, slot, reason)
end

function Inv.RemoveItem(invId, name, amount, slot, infoMatch, reason)
    return Inv.RemoveFrom(Inv.Get(invId), name, amount, slot, infoMatch, reason)
end

function Inv.Count(invId, name, infoMatch)
    local inv = Inv.Get(invId)
    if not inv or type(name) ~= 'string' then return 0 end
    Inv.CheckDecay(inv)
    return countIn(inv, name:lower(), infoMatch)
end

--- List of stacks of that item (sorted by slot).
function Inv.FindItems(invId, name, infoMatch)
    local inv = Inv.Get(invId)
    local out = {}
    if not inv or type(name) ~= 'string' then return out end
    Inv.CheckDecay(inv)
    name = name:lower()
    for _, sl in ipairs(sortedSlots(inv.items)) do
        local s = inv.items[sl]
        if s.name == name and Inv.InfoMatches(s.info, infoMatch) then out[#out + 1] = s end
    end
    return out
end
Inv.Find = Inv.FindItems

function Inv.GetSlot(invId, slot)
    local inv = Inv.Get(invId)
    if not inv then return nil end
    Inv.CheckDecay(inv)
    return inv.items[tonumber(slot)]
end

--- Merges keys into a stack's info.
function Inv.SetInfo(invId, slot, info)
    local inv = Inv.Get(invId)
    local s = inv and inv.items[tonumber(slot)]
    if not s or type(info) ~= 'table' then return false end
    for k, v in pairs(info) do s.info[k] = v end
    Inv.Changed(inv, { action = 'info', name = s.name, amount = 0, slot = s.slot })
    return true
end

--- Replaces a stack's info.
function Inv.ReplaceInfo(invId, slot, info)
    local inv = Inv.Get(invId)
    local s = inv and inv.items[tonumber(slot)]
    if not s or type(info) ~= 'table' then return false end
    s.info = Inv.DeepCopy(info)
    Inv.Changed(inv, { action = 'info', name = s.name, amount = 0, slot = s.slot })
    return true
end

--- Replaces all items (e.g. RSG SetInventory). Unknown items and bad amounts are dropped.
function Inv.SetItems(inv, items, reason)
    local clean = {}
    for slot, s in pairs(Inv.NormalizeItems(Inv.DeepCopy(items))) do
        local def = Inv.GetItemDef(s.name or '')
        local amount = Inv.Amount(s.amount, 1)
        if def and amount and slot >= 1 and slot <= math.max(inv.slots, slot) then
            local st = Inv.MakeStack(def, amount, s.info or {}, slot)
            clean[slot] = st
        end
    end
    inv.items = clean
    Inv.Changed(inv, { action = 'set', reason = reason })
end

function Inv.Clear(inv, keep, reason)
    local keepSet = {}
    if type(keep) == 'string' then keepSet[keep:lower()] = true
    elseif type(keep) == 'table' then for _, n in pairs(keep) do if type(n) == 'string' then keepSet[n:lower()] = true end end end
    for slot, s in pairs(inv.items) do
        if not keepSet[s.name] then inv.items[slot] = nil end
    end
    Inv.Changed(inv, { action = 'set', reason = reason or 'clear' })
end

-- ------------------------------------------------------------
-- change events, client pushes, player sync
-- ------------------------------------------------------------

local pushQueue = {}
local pushScheduled = false

function Inv.View(inv)
    return {
        id = inv.id, type = inv.type, label = inv.label, slots = inv.slots,
        maxWeight = inv.maxWeight, weight = Inv.Weight(inv), maxCount = inv.maxCount,
        items = inv.items,
    }
end

--- Item definitions for every item in the given inventories ({ [name] = def }).
function Inv.DefsFor(...)
    local out = {}
    for i = 1, select('#', ...) do
        local inv = select(i, ...)
        if inv then
            for _, s in pairs(inv.items) do
                local d = Inv.Items[s.name]
                if d and not out[s.name] then
                    -- the page shows "Use" only when a script really handles the item (many RSG
                    -- items are flagged useable for scripts that are not installed)
                    local c = {}
                    for k, v in pairs(d) do c[k] = v end
                    local u = Inv.IsUsable and Inv.IsUsable(s.name) or false
                    c.usable, c.useable = u, u
                    out[s.name] = c
                end
            end
        end
    end
    return out
end

--- Sends one inventory to one player: MULTIinventory:client:update (inv, defs).
function Inv.SendUpdate(src, inv)
    TriggerClientEvent('MULTIinventory:client:update', src, Inv.View(inv), Inv.DefsFor(inv))
end

--- Opens the screen on the client: MULTIinventory:client:open { player, other, defs }.
function Inv.SendOpen(src, own, other)
    TriggerClientEvent('MULTIinventory:client:open', src, {
        player = Inv.View(own), other = other and Inv.View(other) or nil,
        defs = Inv.DefsFor(own, other),
    })
end

local function flushPushes()
    pushScheduled = false
    local q = pushQueue
    pushQueue = {}
    for id in pairs(q) do
        local inv = Inv.List[id]
        if inv then
            local sent = {}
            local view, defs = Inv.View(inv), Inv.DefsFor(inv)
            if inv.ownerSrc then sent[inv.ownerSrc] = true; TriggerClientEvent('MULTIinventory:client:update', inv.ownerSrc, view, defs) end
            for src in pairs(inv.viewers) do
                if not sent[src] then sent[src] = true; TriggerClientEvent('MULTIinventory:client:update', src, view, defs) end
            end
        end
    end
end

--- Marks an inventory changed: event, player sync, client push (once per tick).
function Inv.Changed(inv, change)
    inv.dirty = true
    if inv.type == 'player' and Inv.SyncPlayer then Inv.SyncPlayer(inv) end
    TriggerEvent('MULTIinventory:changed', inv.id, { change })
    pushQueue[inv.id] = true
    if not pushScheduled then
        pushScheduled = true
        SetTimeout(0, flushPushes)
    end
end

--- Sends the item box pop-up to a player.
function Inv.ItemBox(src, name, amount, action)
    local def = Inv.Items[name]
    if src and def then TriggerClientEvent('MULTIinventory:client:itembox', src, def, amount, action) end
end

-- ------------------------------------------------------------
-- persistence
-- ------------------------------------------------------------

--- RSG's saved shape: a list of { name, amount, info, type, slot }.
function Inv.Compact(items)
    local out = {}
    for _, slot in ipairs(sortedSlots(items or {})) do
        local s = items[slot]
        if s then
            out[#out + 1] = { name = s.name, amount = s.amount, info = type(s.info) == 'table' and s.info or {}, type = s.type, slot = slot }
        end
    end
    return out
end

local function encodeItems(items)
    local list = Inv.Compact(items)
    if #list == 0 then return '[]' end
    return json.encode(list)
end

--- Writes one inventory. await = wait for the database.
function Inv.Save(inv, await)
    if type(inv) == 'string' then inv = Inv.List[inv] end
    if not inv then return false end
    local data = encodeItems(inv.items)
    if inv.type == 'player' then
        local q = 'UPDATE players SET inventory = ? WHERE citizenid = ?'
        if await then MySQL.prepare.await(q, { data, inv.citizenid }) else MySQL.prepare(q, { data, inv.citizenid }) end
    elseif STASH_TYPES[inv.type] then
        local q = 'INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)'
        if await then MySQL.prepare.await(q, { Inv.DbKey(inv.id), data }) else MySQL.prepare(q, { Inv.DbKey(inv.id), data }) end
    else
        return false
    end
    inv.dirty = false
    return true
end

function Inv.SaveAll(await)
    for _, inv in pairs(Inv.List) do
        if inv.dirty then Inv.Save(inv, await) end
    end
end

--- Turns saved items (JSON string or table) into stacks, dropping unknown items.
function Inv.LoadItems_(raw, decayRate)
    local list = raw
    if type(raw) == 'string' then list = json.decode(raw) end
    local out, missing = {}, {}
    local now = os.time()
    for slot, s in pairs(Inv.NormalizeItems(list)) do
        local def = Inv.GetItemDef(s.name)
        local amount = Inv.Amount(s.amount, 1)
        if def and amount then
            local st = Inv.MakeStack(def, amount, s.info or {}, slot)
            local keep = true
            if Config.Decay.Enabled and def.decay then
                local updated, q, del = Inv.CheckItemDecay(st, def, now, decayRate or 1)
                if updated and del and q <= 0 then keep = false end
            end
            if keep then out[slot] = st end
        else
            missing[#missing + 1] = tostring(s.name)
        end
    end
    return out, missing
end
