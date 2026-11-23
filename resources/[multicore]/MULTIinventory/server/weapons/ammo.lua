-- ============================================================
-- MULTIinventory :: server/weapons/ammo.lua
--
-- Gunbelt: spare ammo per character and ammo type (multiinv_ammo, upserted inside the core's
-- flush transaction; migration_batch of imported rows is preserved). Rounds loaded in a weapon
-- live on the weapon row (server/weapons/weapons.lua). Ammo items (Config.Weapons.ammoItems)
-- are converted into gunbelt ammo on use.
--
--   Ammo.charOf(target) -> charId|nil         target = src | 'player:<charid>'
--   Ammo.get(charId) -> belt { [AMMO_X] = n }  (live table, do not mutate; loads + may yield)
--   Ammo.count(charId, type) -> n
--   Ammo.add(charId, type, n, opts) -> ok, newCount|err   ('unknown_ammo'|'bad_count'|'ammo_full')
--        opts.ignoreMax, opts.partial (add what fits), opts.noPush
--   Ammo.remove(charId, type, n, opts) -> ok, newCount|err ('not_enough')
--   Ammo.set(charId, type, n, opts) -> ok, n
--   Ammo.clear(charId, ctx) -> ok, removed { [type] = n }   (gunbelt + magazines of weapons on the ped)
--   Ammo.view(charId) -> { { type, label, count, max }, ... }  (NUI gunbelt strip, open payload `gunbelt`)
--   Ammo.useItem(src, itemTable) -> ok, err
--   internal: Ammo.adjust(charId, type, delta) (no max, no push), Ammo.setRaw, Ammo.push(charId, deltas),
--             Ammo.pushBelt(charId), Ammo.markOffline(charId)
-- Client: MULTIinventory:weapons:cl:ammo (deltas), :cl:belt (absolute belt), :cl:ammoclear
-- ============================================================

Ammo = Ammo or {}

local belts = {}       -- [charId] = { [type] = n }
local dirtyChars = {}  -- [charId] = { [type] = true }
local offlineAt = {}   -- [charId] = unix time the character went offline

-- upper case, and another developer's name for an ammo type turned into the game's type (AmmoDefs.canonical)
local function up(t) return type(t) == 'string' and AmmoDefs.canonical(t) or nil end

function Ammo.charOf(target)
    if type(target) == 'string' then
        local cid = target:match('^player:(%d+)$')
        if cid then return tonumber(cid) end
        if target:match('^%d+$') then target = tonumber(target) else return nil end
    end
    if type(target) == 'number' then
        local st = State.get(target)
        if st then return st.charId end
    end
    return nil
end

function Ammo.load(charId)
    charId = tonumber(charId)
    local belt = {}
    for _, r in ipairs(InvDB.query('SELECT `ammo_type`, `count` FROM `multiinv_ammo` WHERE `charid` = ?', { charId })) do
        local t, n = up(r.ammo_type), math.tointeger(math.floor(tonumber(r.count) or 0))
        if t and n and n > 0 then belt[t] = n end
    end
    if not belts[charId] then belts[charId] = belt end
    return belts[charId]
end

function Ammo.get(charId)
    charId = tonumber(charId)
    if not charId then return {} end
    if State.srcOfChar(charId) then offlineAt[charId] = nil end
    return belts[charId] or Ammo.load(charId)
end

function Ammo.count(charId, t) return Ammo.get(charId)[up(t) or ''] or 0 end

local function touch(charId, t)
    dirtyChars[charId] = dirtyChars[charId] or {}
    dirtyChars[charId][t] = true
end

function Ammo.setRaw(charId, t, n)
    charId, t = tonumber(charId), up(t)
    n = tonumber(n)
    if not n or n ~= n or n == math.huge or n == -math.huge then return end -- nan guard: never store a non-finite belt count
    local belt = Ammo.get(charId)
    n = math.max(0, math.floor(n))
    if (belt[t] or 0) == n then return end
    belt[t] = n > 0 and n or nil
    touch(charId, t)
end

function Ammo.adjust(charId, t, delta)
    local belt = Ammo.get(charId)
    Ammo.setRaw(charId, t, (belt[up(t)] or 0) + delta)
end

local function srcOf(charId) return State.srcOfChar(tonumber(charId)) end

function Ammo.push(charId, deltas)
    local src = srcOf(charId)
    if src and next(deltas) then TriggerClientEvent('MULTIinventory:weapons:cl:ammo', src, deltas) end
end

function Ammo.pushBelt(charId)
    local src = srcOf(charId)
    if src then TriggerClientEvent('MULTIinventory:weapons:cl:belt', src, Util.deepcopy(Ammo.get(charId))) end
end

function Ammo.add(charId, t, n, opts)
    opts = opts or {}
    charId, t = tonumber(charId), up(t)
    local def = AmmoDefs.get(t)
    if not def then return false, 'unknown_ammo' end
    n = Util.toInt(tonumber(n))
    if not n or n < 1 then return false, 'bad_count' end
    local cur = Ammo.get(charId)[t] or 0
    if not opts.ignoreMax and def.max and cur + n > def.max then
        if not opts.partial then return false, 'ammo_full' end
        n = def.max - cur
        if n < 1 then return false, 'ammo_full' end
    end
    Ammo.setRaw(charId, t, cur + n)
    if not opts.noPush then Ammo.push(charId, { [t] = n }) end
    return true, cur + n
end

function Ammo.remove(charId, t, n, opts)
    opts = opts or {}
    charId, t = tonumber(charId), up(t)
    if not AmmoDefs.get(t) then return false, 'unknown_ammo' end
    n = Util.toInt(tonumber(n))
    if not n or n < 1 then return false, 'bad_count' end
    local cur = Ammo.get(charId)[t] or 0
    if cur < n then return false, 'not_enough' end
    Ammo.setRaw(charId, t, cur - n)
    if not opts.noPush then Ammo.push(charId, { [t] = -n }) end
    return true, cur - n
end

function Ammo.set(charId, t, n, opts)
    opts = opts or {}
    charId, t = tonumber(charId), up(t)
    local def = AmmoDefs.get(t)
    if not def then return false, 'unknown_ammo' end
    n = Util.toInt(tonumber(n))
    if not n or n < 0 then return false, 'bad_count' end
    if not opts.ignoreMax and def.max and n > def.max then n = def.max end
    local cur = Ammo.get(charId)[t] or 0
    Ammo.setRaw(charId, t, n)
    if not opts.noPush and n ~= cur then Ammo.push(charId, { [t] = n - cur }) end
    return true, n
end

---vorp removeAllUserAmmo: empty the gunbelt and the magazines of the weapons on the ped.
function Ammo.clear(charId, ctx)
    charId = tonumber(charId)
    ctx = ctx or { reason = 'api' }
    local belt = Ammo.get(charId)
    local removed = {}
    local types = {}
    for t, n in pairs(belt) do removed[t] = n; types[#types + 1] = t end
    for _, t in ipairs(types) do Ammo.setRaw(charId, t, 0) end
    local src = srcOf(charId)
    if src then
        local s = Weapons._sessions[src]
        for id in pairs(s and s.onPed or {}) do
            local r = Weapons.get(id)
            if r and next(r.ammo) then
                for t, n in pairs(r.ammo) do removed[t] = (removed[t] or 0) + n end
                r.ammo = {}
                Weapons._refresh(r)
            end
        end
        TriggerClientEvent('MULTIinventory:weapons:cl:ammoclear', src)
    end
    InvLog.write('ammo_clear', { actorSrc = ctx.src, actor = ctx.resource and ('resource:' .. tostring(ctx.resource)) or nil,
                                 from = 'player:' .. charId, targetCharId = charId, data = { removed = removed } })
    return true, removed
end

function Ammo.view(charId)
    local out = {}
    for t, n in pairs(Ammo.get(charId)) do
        local d = AmmoDefs.get(t)
        out[#out + 1] = { type = t, label = d and d.label or t, count = n, max = d and d.max }
    end
    table.sort(out, function(a, b) return a.type < b.type end)
    return out
end

function Ammo.markOffline(charId) offlineAt[tonumber(charId)] = Util.now() end

-- ------------------------------------------------------------
-- ammo items
-- ------------------------------------------------------------
function Ammo.useItem(src, item)
    local spec = (Config.Weapons.ammoItems or {})[item.name]
    if not spec then return false, 'not_usable' end
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local amount = Util.toInt(tonumber(spec.amount)) or 1
    local def = AmmoDefs.get(spec.type)
    if not def then return false, 'unknown_ammo' end
    local cur = Ammo.count(st.charId, spec.type)
    local units = 1
    if spec.wholeStack then
        -- loose rounds: the whole stack (as many as the gunbelt still holds)
        local have = Util.toInt(tonumber(item.count or item.amount)) or 1
        local room = def.max and math.floor((def.max - cur) / amount) or have
        units = math.min(have, room)
        if units < 1 then
            Sync.notify(src, Weapons.msg('ammo_full'), 'error')
            return false, 'ammo_full'
        end
    elseif def.max and cur + amount > def.max then
        Sync.notify(src, Weapons.msg('ammo_full'), 'error')
        return false, 'ammo_full'
    end
    local ok, err = Inv.removeStack('player:' .. st.charId, item.id, units, { src = src, reason = 'use' })
    if not ok then return false, err end
    return Ammo.add(st.charId, spec.type, amount * units, { ignoreMax = true })
end

---[thrown] Throwable item (Config.Weapons.thrownItems): one item -> `amount` more on the matching
---throwable stack (Weapons.create stacks it onto the one already carried, or makes the stack).
function Ammo.useThrownItem(src, item)
    local spec = (Config.Weapons.thrownItems or {})[item.name]
    if not spec then return false, 'not_usable' end
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local pid = 'player:' .. st.charId
    local amount = Util.toInt(tonumber(spec.amount)) or 1
    if amount < 1 then amount = 1 end
    local def = WeaponDefs.get(spec.weapon)
    if not WeaponDefs.isThrown(def) then return false, 'unknown_weapon' end
    local t = up(spec.type)
    if not WeaponDefs.usesAmmo(def, t) then t = def.ammoTypes[1] end
    local okC, errC = Weapons.canCarry(pid, 1, def.name)
    if not okC then
        Sync.notify(src, Weapons.msg(errC == 'weapon_limit' and 'weapon_limit' or errC), 'error')
        return false, errC
    end
    local ok, err = Inv.removeStack(pid, item.id, 1, { src = src, reason = 'use' })
    if not ok then return false, err end
    local okW, res = Weapons.create(pid, def.name, { ammo = { [t] = amount } }, { src = src, reason = 'use' })
    if not okW then
        Inv.add(pid, item.name, 1, item.metadata, { src = src, reason = 'refund' })
        Sync.notify(src, Weapons.msg(res), 'error')
        return false, res
    end
    return true, res.id
end

---Make ammo + cleaning items usable (skipped for items another resource already registered;
---a later registration by another resource replaces ours - core rule).
function Ammo.registerItems()
    local RES = GetCurrentResourceName()
    if Config.Weapons.registerAmmoUsables then
        for name in pairs(Config.Weapons.ammoItems or {}) do
            if not Usables.isRegistered(name) then
                Usables.register(name, function(data) Ammo.useItem(data.source, data.item) end, RES, { builtin = true })
            end
        end
        for name in pairs(Config.Weapons.thrownItems or {}) do
            if not Usables.isRegistered(name) and not (Config.Weapons.ammoItems or {})[name] then
                Usables.register(name, function(data) Ammo.useThrownItem(data.source, data.item) end, RES, { builtin = true })
            end
        end
    end
    local cl = Config.Weapons.cleaning or {}
    if cl.registerUsables then
        for name in pairs(cl.items or {}) do
            if not Usables.isRegistered(name) then
                Usables.register(name, function(data)
                    local ok, err = Weapons.clean(data.source, nil, data.item.name, data.item.id)
                    if not ok then Sync.notify(data.source, Weapons.msg(err), 'error') end
                end, RES)
            end
        end
    end
end
Ammo.registerItems()

-- ------------------------------------------------------------
-- persistence (inside the core flush transaction)
-- ------------------------------------------------------------
local function persist(list)
    if next(dirtyChars) == nil then return nil end
    local snap = dirtyChars
    dirtyChars = {}
    local chars = {}
    for cid in pairs(snap) do chars[#chars + 1] = cid end
    table.sort(chars)
    for _, cid in ipairs(chars) do
        local belt = belts[cid] or {}
        local types = {}
        for t in pairs(snap[cid]) do types[#types + 1] = t end
        table.sort(types)
        for _, t in ipairs(types) do
            list[#list + 1] = { query = 'INSERT INTO `multiinv_ammo` (`charid`,`ammo_type`,`count`) VALUES (?,?,?) ON DUPLICATE KEY UPDATE `count`=VALUES(`count`)',
                                values = { cid, t, belt[t] or 0 } }
        end
    end
    return function()
        for cid, types in pairs(snap) do
            dirtyChars[cid] = dirtyChars[cid] or {}
            for t in pairs(types) do dirtyChars[cid][t] = true end
        end
    end
end

function Ammo.registerPersistence() Persistence.addExtra(persist) end
Ammo.registerPersistence()

---Offline gunbelts leave the cache once saved.
function Ammo.evictIdle(maxAge)
    local cutoff = Util.now() - (maxAge or 600)
    for cid, at in pairs(offlineAt) do
        if at <= cutoff and not dirtyChars[cid] and not State.srcOfChar(cid) then
            belts[cid] = nil
            offlineAt[cid] = nil
        end
    end
end

CreateThread(function()
    while true do
        Wait(120000)
        pcall(Ammo.evictIdle, (Config.Persistence and Config.Persistence.unloadOfflineAfter) or 600)
    end
end)

-- tests only
function Ammo._reset() belts, dirtyChars, offlineAt = {}, {}, {} end
function Ammo._isCached(charId) return belts[tonumber(charId)] ~= nil end
