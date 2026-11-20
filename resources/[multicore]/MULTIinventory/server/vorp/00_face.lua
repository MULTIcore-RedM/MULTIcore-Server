-- ============================================================
-- MULTIinventory :: vorp_inventory face - shared helpers
-- Written fresh from VORP's public API documentation
-- (https://docs.vorp-core.com/api-reference/inventory) and from how
-- scripts call vorp_inventory. No VORP code is used. GPL v3.
--
-- Everything here sits on the engine API (global MULTIInv, see
-- docs/INVENTORY.md). The face keeps no items of its own: a VORP item
-- is an engine stack, a VORP weapon is a weapon item, VORP ammo is
-- ammo items in the satchel.
-- ============================================================

MULTIVorp = MULTIVorp or {}
local V = MULTIVorp

-- ------------------------------------------------------------
-- Settings (config.lua, Config.Vorp). Read every time so a config
-- reload is picked up; every key has a default here.
-- ------------------------------------------------------------
function V.Cfg(key, default)
    local c = type(Config) == 'table' and type(Config.Vorp) == 'table' and Config.Vorp or nil
    local v = c and c[key]
    if v == nil then return default end
    return v
end

function V.Debug(fmt, ...)
    if V.Cfg('Debug', false) then print(('^5[MULTIinventory:vorp]^7 ' .. fmt):format(...)) end
end

function V.Warn(fmt, ...)
    print(('^3[MULTIinventory:vorp]^7 ' .. fmt):format(...))
end

-- Text from the locale files, with a fallback when the key is missing.
function V.T(key, fallback, ...)
    if type(_L) == 'function' then
        local ok, s = pcall(_L, key, ...)
        if ok and type(s) == 'string' and s ~= key and s ~= '' then return s end
    end
    if select('#', ...) > 0 then
        local ok, s = pcall(string.format, fallback, ...)
        if ok then return s end
    end
    return fallback
end

-- ------------------------------------------------------------
-- Export registration under the name 'vorp_inventory'.
-- exports.vorp_inventory:x() looks the export up through the event
-- __cfx_export_vorp_inventory_x, so answering that event is enough
-- (the same technique MULTIcore uses for vorp_core).
-- ------------------------------------------------------------
V.Exported = V.Exported or {}

function V.Export(name, fn)
    V.Exported[name] = fn
    AddEventHandler(('__cfx_export_vorp_inventory_%s'):format(name), function(setCB)
        setCB(fn)
    end)
end

-- ------------------------------------------------------------
-- Small helpers
-- ------------------------------------------------------------

--- true for Lua functions and for function references handed over
--- from another resource (tables with __call).
function V.IsCallable(v)
    if type(v) == 'function' then return true end
    if type(v) == 'table' then
        local mt = getmetatable(v)
        return mt ~= nil and mt.__call ~= nil
    end
    return false
end

--- VORP style: pass the answer to the callback (if any) and return it too.
function V.Done(cb, ...)
    if V.IsCallable(cb) then
        local ok, err = pcall(cb, ...)
        if not ok then V.Warn('a callback failed: %s', tostring(err)) end
    end
    return ...
end

--- A whole positive amount, or nil (nan / inf / negative / not a number).
function V.Amount(n, default)
    if n == nil then n = default end
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.floor(n)
    if n < 1 then return nil end
    return n
end

function V.Src(src)
    src = tonumber(src)
    if not src or src < 1 then return nil end
    return math.floor(src)
end

function V.Copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = V.Copy(v) end
    return out
end

function V.DeepEqual(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then
        -- 1 and 1.0, '1' stays a string
        if type(a) == 'number' and type(b) == 'number' then return a == b end
        return false
    end
    for k, v in pairs(a) do
        if not V.DeepEqual(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

--- every key of `part` is in `whole` with the same value
function V.Contains(whole, part)
    if type(part) ~= 'table' then return true end
    if type(whole) ~= 'table' then return next(part) == nil end
    for k, v in pairs(part) do
        if type(v) == 'table' then
            if not V.Contains(whole[k], v) then return false end
        elseif whole[k] ~= v then
            return false
        end
    end
    return true
end

function V.IsEmpty(t)
    return type(t) ~= 'table' or next(t) == nil
end

function V.Invoker()
    local r = GetInvokingResource and GetInvokingResource() or nil
    return r or GetCurrentResourceName()
end

-- ------------------------------------------------------------
-- RSGCore (MULTIcore) for character data: invCapacity, job, char id
-- ------------------------------------------------------------
local RSGObj
function V.Core()
    if not RSGObj then
        local ok, obj = pcall(function() return exports['rsg-core']:GetCoreObject() end)
        if ok then RSGObj = obj end
    end
    return RSGObj
end

function V.Player(src)
    local core = V.Core()
    if not core or not core.Functions or not core.Functions.GetPlayer then return nil end
    local ok, P = pcall(core.Functions.GetPlayer, src)
    if ok then return P end
    return nil
end

function V.CharId(src)
    local P = V.Player(src)
    return P and P.PlayerData and P.PlayerData.id or nil
end

function V.Job(src)
    local P = V.Player(src)
    local job = P and P.PlayerData and P.PlayerData.job or {}
    return job.name, job.grade and tonumber(job.grade.level) or 0
end

-- ------------------------------------------------------------
-- Engine access
-- ------------------------------------------------------------
function V.Engine()
    return MULTIInv
end

function V.InvOf(src)
    src = V.Src(src)
    if not src or not MULTIInv or not MULTIInv.PlayerInv then return nil end
    local ok, id = pcall(MULTIInv.PlayerInv, src)
    if ok and type(id) == 'string' then return id end
    return nil
end

function V.Get(invId)
    if not invId or not MULTIInv or not MULTIInv.Get then return nil end
    local ok, inv = pcall(MULTIInv.Get, invId)
    if ok and type(inv) == 'table' then return inv end
    return nil
end

--- the item definition from the engine's registry
function V.Def(name)
    if type(name) ~= 'string' then return nil end
    local E = MULTIInv
    if E then
        local items = E.Items
        if type(items) == 'table' and items[name] then return items[name] end
        for _, fn in ipairs({ 'GetItemDef', 'ItemDef', 'GetItem' }) do
            if type(E[fn]) == 'function' then
                local ok, d = pcall(E[fn], name)
                if ok and type(d) == 'table' and d.name then return d end
            end
        end
    end
    local core = V.Core()
    local shared = core and core.Shared and core.Shared.Items
    if type(shared) == 'table' then return shared[name] end
    return nil
end

--- The registry name for a name given by a VORP script ('WEAPON_X' and 'Bread' work too).
function V.Norm(name)
    if type(name) ~= 'string' or name == '' then return nil end
    if V.Def(name) then return name end
    local low = name:lower()
    if V.Def(low) then return low end
    return low
end

function V.IsWeaponDef(def, name)
    if type(def) == 'table' and def.type == 'weapon' then return true end
    return type(name) == 'string' and name:lower():find('^weapon_') ~= nil
end

--- stacks of an inventory as a sorted list of { slot, stack }
function V.Stacks(inv)
    local out = {}
    if type(inv) ~= 'table' or type(inv.items) ~= 'table' then return out end
    for key, st in pairs(inv.items) do
        if type(st) == 'table' and st.name then
            out[#out + 1] = { slot = tonumber(st.slot) or tonumber(key) or key, stack = st }
        end
    end
    table.sort(out, function(a, b) return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0) end)
    return out
end

function V.StackAmount(st)
    return math.max(0, math.floor(tonumber(st.amount) or tonumber(st.count) or 1))
end

-- ------------------------------------------------------------
-- VORP item ids
-- VORP gives every stack a number id that scripts keep for a while
-- (use an item, then subItemById / setItemMetadata on it). The face
-- hands out one id per engine stack and follows the stack by identity
-- while it moves between slots. Ids live for the session.
-- ------------------------------------------------------------
local ids = {}                                   -- id -> { invId, slot, name, ref = weak { s = stack } }
local byStack = setmetatable({}, { __mode = 'k' }) -- stack table -> id
local nextId = 0
local sinceSweep = 0

local function sweep()
    for id, r in pairs(ids) do
        if r.ref.s == nil then ids[id] = nil end
    end
end

function V.IdOf(invId, slot, st)
    local id = byStack[st]
    if id and ids[id] then
        local r = ids[id]
        r.invId, r.slot = invId, slot
        return id
    end
    nextId = nextId + 1
    id = nextId
    ids[id] = { invId = invId, slot = slot, name = st.name, ref = setmetatable({ s = st }, { __mode = 'v' }) }
    byStack[st] = id
    sinceSweep = sinceSweep + 1
    if sinceSweep >= 2000 then sinceSweep = 0; sweep() end
    return id
end

--- id -> invId, slot, stack (nil when the stack is gone). `hintInv` is
--- searched too (the stack may have moved into it).
function V.Resolve(id, hintInv)
    id = tonumber(id)
    local r = id and ids[id]
    if not r then return nil end
    local st = r.ref.s
    local function scan(invId)
        local inv = V.Get(invId)
        if not inv or type(inv.items) ~= 'table' then return nil end
        if st then
            local cur = inv.items[r.slot]
            if cur == st then return invId, r.slot, st end
            for _, e in ipairs(V.Stacks(inv)) do
                if e.stack == st then return invId, e.slot, st end
            end
        end
        return nil
    end
    local a, b, c = scan(r.invId)
    if a then r.invId, r.slot = a, b; return a, b, c end
    if hintInv and hintInv ~= r.invId then
        a, b, c = scan(hintInv)
        if a then r.invId, r.slot = a, b; return a, b, c end
    end
    -- the engine replaced the table (reload): same slot, same item
    local inv = V.Get(r.invId)
    local cur = inv and type(inv.items) == 'table' and inv.items[r.slot]
    if type(cur) == 'table' and cur.name == r.name then
        r.ref.s = cur
        byStack[cur] = id
        return r.invId, r.slot, cur
    end
    return nil
end

-- ------------------------------------------------------------
-- Metadata: engine info -> VORP metadata
-- Keys the engine uses for itself (decay clock) are not shown to VORP
-- scripts; quality is shown as VORP's `percentage`.
-- ------------------------------------------------------------
local DEFAULT_HIDDEN = { quality = true, lastUpdate = true }

function V.HiddenKeys()
    local h = V.Cfg('HiddenInfoKeys', nil)
    if type(h) ~= 'table' then return DEFAULT_HIDDEN end
    local out = {}
    for k, v in pairs(h) do
        if type(k) == 'number' then out[v] = true else out[k] = v and true or nil end
    end
    return out
end

function V.CleanMeta(info)
    if type(info) ~= 'table' then return {} end
    local hidden = V.HiddenKeys()
    local out = {}
    for k, v in pairs(info) do
        if not hidden[k] then out[k] = V.Copy(v) end
    end
    return out
end

--- the engine-only part of an info table (kept when VORP replaces metadata)
function V.HiddenPart(info)
    local out = {}
    if type(info) ~= 'table' then return out end
    for k in pairs(V.HiddenKeys()) do
        if info[k] ~= nil then out[k] = V.Copy(info[k]) end
    end
    return out
end

function V.Quality(info)
    local q = type(info) == 'table' and tonumber(info.quality) or nil
    if q == nil then return 100 end
    return q
end

--- VORP percentage filter: nil = any, 0 = spent ones only, > 0 = at least that
function V.PctMatches(info, pct)
    pct = tonumber(pct)
    if pct == nil then return true end
    local q = V.Quality(info)
    if pct <= 0 then return q <= 0 end
    return q >= pct
end

--- VORP metadata filter. nil or {} = any stack. mode 'exact' (default) or 'contains'.
function V.MetaMatches(info, meta, mode)
    if V.IsEmpty(meta) then return true end
    local clean = V.CleanMeta(info)
    if mode == 'contains' then return V.Contains(clean, meta) end
    return V.DeepEqual(clean, meta)
end

--- metadata a VORP script hands in -> engine info (nil for "no metadata")
function V.InfoFrom(meta)
    if type(meta) ~= 'table' or next(meta) == nil then return nil end
    return V.Copy(meta)
end

-- ------------------------------------------------------------
-- Engine stack -> VORP item
-- ------------------------------------------------------------
function V.ToItem(invId, slot, st)
    if type(st) ~= 'table' then return nil end
    local def = V.Def(st.name) or {}
    local info = type(st.info) == 'table' and st.info or {}
    local meta = V.CleanMeta(info)
    local id = V.IdOf(invId, slot, st)
    local amount = V.StackAmount(st)
    local weight = tonumber(meta.weight)                         -- VORP: metadata weight override (kg)
    if not weight then weight = (tonumber(def.weight) or 0) / 1000 -- engine grams -> VORP kg
    end
    local usable = def.usable
    if usable == nil then usable = def.useable end
    local desc = meta.description or def.description or def.desc or ''
    local q = V.Quality(info)
    return {
        id = id,
        mainid = id,
        slot = slot,
        name = st.name,
        item = st.name,
        label = meta.label or def.label or st.label or st.name,
        metadata = meta,
        count = amount,
        amount = amount,
        limit = tonumber(def.limit) or 0,
        weight = weight,
        desc = desc,
        description = desc,
        type = def.type == 'weapon' and 'item_weapon' or 'item_standard',
        group = tonumber(def.group) or 1,
        canUse = usable and true or false,
        canRemove = def.canRemove ~= false and def.can_remove ~= 0,
        percentage = q,
        isDegradable = info.quality ~= nil,
        image = meta.image or def.image,
    }
end

--- matching stacks of one item: list of { slot, stack }
function V.Find(invId, name, meta, pct, mode)
    local inv = V.Get(invId)
    local out = {}
    if not inv then return out end
    for _, e in ipairs(V.Stacks(inv)) do
        local st = e.stack
        if st.name == name and V.MetaMatches(st.info, meta, mode) and V.PctMatches(st.info, pct) then
            out[#out + 1] = e
        end
    end
    return out
end

function V.CountOf(invId, name, meta, pct, mode)
    local n = 0
    for _, e in ipairs(V.Find(invId, name, meta, pct, mode)) do n = n + V.StackAmount(e.stack) end
    return n
end

--- Removes `amount` of `name` from the listed stacks (in order). Checks first, so it is all or nothing.
function V.RemoveFrom(invId, name, amount, list, reason)
    local have = 0
    for _, e in ipairs(list) do have = have + V.StackAmount(e.stack) end
    if have < amount then return false, 'not_enough' end
    local left = amount
    for _, e in ipairs(list) do
        if left <= 0 then break end
        local take = math.min(left, V.StackAmount(e.stack))
        local ok, err = MULTIInv.RemoveItem(invId, name, take, e.slot, nil, reason)
        if not ok then return false, err end
        left = left - take
    end
    return true
end

-- ------------------------------------------------------------
-- invCapacity: VORP's per-character total item count for the satchel.
-- MULTIcore keeps it in metadata.vorp.invCapacity; updateInvCapacity
-- on the VORP character changes it. Weapons and ammo do not count
-- (they don't on VORP either). 0 or missing = no limit.
-- ------------------------------------------------------------
function V.Capacity(src)
    if not V.Cfg('UseInvCapacity', true) then return nil end
    local P = V.Player(src)
    local md = P and P.PlayerData and P.PlayerData.metadata
    local cap = md and type(md.vorp) == 'table' and tonumber(md.vorp.invCapacity) or nil
    if not cap or cap <= 0 then return nil end
    return math.floor(cap)
end

function V.CountsForCapacity(name)
    local def = V.Def(name)
    if V.IsWeaponDef(def, name) then return false end
    if def and def.type == 'ammo' then return false end
    if V.AmmoTypeOfItem and V.AmmoTypeOfItem(name) then return false end
    return true
end

function V.UsedCapacity(invId)
    local inv = V.Get(invId)
    local n = 0
    if not inv then return 0 end
    for _, e in ipairs(V.Stacks(inv)) do
        if V.CountsForCapacity(e.stack.name) then n = n + V.StackAmount(e.stack) end
    end
    return n
end

--- true when `amount` more of `name` fit under the character's invCapacity
function V.FitsCapacity(src, invId, name, amount)
    local cap = V.Capacity(src)
    if not cap then return true end
    if not V.CountsForCapacity(name) then return true end
    return V.UsedCapacity(invId) + amount <= cap
end

--- Tells the engine about the capacity (inventory field maxCount), so
--- adds made through the RSG face and the UI respect it too.
function V.SyncCapacity(src)
    if not V.Cfg('SyncCapacityToEngine', false) then return end
    local invId = V.InvOf(src)
    local inv = invId and V.Get(invId)
    if not inv then return end
    inv.maxCount = V.Capacity(src)
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(P)
    local src = P and P.PlayerData and P.PlayerData.source
    if src then SetTimeout(500, function() pcall(V.SyncCapacity, src) end) end
end)

AddEventHandler('RSGCore:Player:SetPlayerData', function(data)
    local src = type(data) == 'table' and data.source
    if src then pcall(V.SyncCapacity, src) end
end)
