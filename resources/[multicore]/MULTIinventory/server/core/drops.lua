-- ============================================================
-- MULTIinventory :: server/core/drops.lua
--
-- World drops (Config.Drop.mode = 'world' ). A pile is a
-- container 'drop:<id>' + a row in multiinv_drops (coords, expiry). The
-- server is the authority: it takes the coords from the player's ped, checks
-- pick-up distance, and moves stacks with Inv.move (metadata preserved).
-- Clients only draw local, non-networked props and ask to pick up.
--
--   Drops.init()                                  boot: load / expire / wipe (persistAcrossRestarts)
--   Drops.dropFromPlayer(src, slot, count) -> ok, err|dropId
--   Drops.destroyFromPlayer(src, slot, count) -> ok, err   (mode 'delete')
--   Drops.pickup(src, dropId, slot|nil, count|nil) -> ok, err|{ taken, left }
--   Drops.create(coords, ownerCharId) -> drop      Drops.remove(drop, reason)
--   Drops.sweep()                                  expire old piles (logged as drop_expired)
--   Drops.get(id)  Drops.all()  Drops.view(d)
-- Client events: MULTIinventory:drops:set (view), :drops:remove (id), :drops:all (list)
-- Net event in : MULTIinventory:drops:request (client asks for the full list after spawn)
-- ============================================================

Drops = Drops or {}

local drops = {}           -- [id] = drop
local nextId = nil
local rowDirty, rowDelete = {}, {}
local rate = {}            -- [src] = { minute, n }

local function cidOf(id) return 'drop:' .. id end

local function dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local v = GetEntityCoords(ped)
    return { x = v.x, y = v.y, z = v.z }
end

function Drops.get(id) return drops[tonumber(id)] end
function Drops.all() return drops end

function Drops.view(d)
    local c = Containers.peek(d.cid)
    local entries, first = 0, nil
    if c then
        for s = 1, c.slots do
            local e = c.stacks[s]
            if e then entries = entries + 1; first = first or e end
        end
    end
    local prop = Config.Drop.prop
    if entries == 1 and first and Config.Drop.propByItem[first.item] then prop = Config.Drop.propByItem[first.item] end
    local label = first and ((first.metadata and first.metadata.label) or Inv.def(first.item).label) or ''
    return { id = d.id, x = d.x, y = d.y, z = d.z, prop = prop, entries = entries,
             label = entries > 1 and (label .. ' +' .. (entries - 1)) or label, expiresAt = d.expiresAt }
end

local function broadcast(d)
    TriggerClientEvent('MULTIinventory:drops:set', -1, Drops.view(d))
end

function Drops.create(coords, ownerCharId)
    local id = nextId
    nextId = nextId + 1
    local now = Util.now()
    local d = { id = id, cid = cidOf(id), x = coords.x, y = coords.y, z = coords.z, ownerCharId = ownerCharId,
                createdAt = now, expiresAt = now + (Config.Drop.lifetimeSeconds or 1800) }
    drops[id] = d
    rowDirty[id] = true
    Containers.create(d.cid, { kind = 'drop', label = 'Ground', slots = Config.Drop.slots, flags = { acceptWeapons = true } })
    Persistence.markDirty(d.cid)
    return d
end

function Drops.remove(d, reason)
    drops[d.id] = nil
    rowDirty[d.id] = nil
    rowDelete[d.id] = true
    Persistence.purgeLater(d.cid)
    Containers.forget(d.cid)
    TriggerClientEvent('MULTIinventory:drops:remove', -1, d.id)
    TriggerEvent('MULTIinventory:dropRemoved', d.id, reason)
end

local function rateOk(src)
    local minute = math.floor(Util.now() / 60)
    local r = rate[src]
    if not r or r[1] ~= minute then r = { minute, 0 }; rate[src] = r end
    if r[2] >= (Config.Drop.maxDropsPerMinute or 20) then return false end
    r[2] = r[2] + 1
    return true
end

local function entryLog(e, count)
    if e.kind == 'weapon' then return { kind = 'weapon', weaponId = e.weaponId, item = e.item, count = 1 } end
    return { item = e.item, count = count, metadata = Util.deepcopy(e.metadata), decayAt = e.decayAt }
end

---Can this pile take the entry (free slot or an equal stack)?
local function pileAccepts(c, e)
    if Containers.freeSlot(c) then return true end
    if e.kind == 'weapon' then return false end
    for _, x in pairs(c.stacks) do
        if Stacking.compatible(x, e.key, e.decayAt) then return true end
    end
    return false
end

function Drops.dropFromPlayer(src, slot, count)
    if Config.Drop.mode ~= 'world' then return Drops.destroyFromPlayer(src, slot, count) end
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local pc = Containers.peek('player:' .. st.charId)
    local e = pc and pc.stacks[Util.toInt(slot) or -1]
    if not e then return false, 'no_item' end
    if e.kind ~= 'weapon' and Inv.def(e.item).canRemove == false then return false, 'cannot_drop' end
    count = count == nil and e.count or Util.toInt(count)
    if not count or count < 1 or count > e.count then return false, 'bad_count' end
    local coords = pedCoords(src)
    if not coords then return false, 'no_ped' end
    if not rateOk(src) then return false, 'rate_limited' end
    -- join a pile close by, else start a new one
    local pile, best = nil, Config.Drop.mergeRadius or 1.25
    for _, d in pairs(drops) do
        local c = Containers.peek(d.cid)
        local dd = dist(d, coords)
        if c and dd <= best and pileAccepts(c, e) then pile, best = d, dd end
    end
    local fresh = false
    if not pile then pile = Drops.create(coords, st.charId); fresh = true end
    local dc = Containers.peek(pile.cid)
    local logged = entryLog(e, count)
    local ok, err = Inv.move(pc, e.slot, dc, nil, count, { src = src, reason = 'drop', from = pc.id, to = dc.id })
    if not ok then
        if fresh and next(dc.stacks) == nil then Drops.remove(pile, 'failed') end
        return false, err
    end
    pile.expiresAt = Util.now() + (Config.Drop.lifetimeSeconds or 1800)
    rowDirty[pile.id] = true
    InvLog.write('drop', { actorSrc = src, from = pc.id, to = dc.id, item = logged.item, count = logged.count,
                           data = { stacks = { logged }, coords = coords, dropId = pile.id } })
    broadcast(pile)
    return true, pile.id
end

function Drops.destroyFromPlayer(src, slot, count)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local pc = Containers.peek('player:' .. st.charId)
    local e = pc and pc.stacks[Util.toInt(slot) or -1]
    if not e then return false, 'no_item' end
    if e.kind == 'weapon' then return false, 'is_weapon' end
    if Inv.def(e.item).canRemove == false then return false, 'cannot_drop' end
    local ok, removed = Inv.removeStack(pc, e.id, count, { src = src, reason = 'destroy' })
    if not ok then return false, removed end
    InvLog.write('destroy', { actorSrc = src, from = pc.id, item = e.item, count = removed[1].count, data = { stacks = removed } })
    return true
end

function Drops.pickup(src, dropId, slot, count)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local d = drops[tonumber(dropId)]
    if not d then return false, 'no_drop' end
    local coords = pedCoords(src)
    if not coords or dist(d, coords) > (Config.Drop.pickupDistance or 2.5) then return false, 'too_far' end
    local dc = Containers.peek(d.cid)
    local pc = Containers.peek('player:' .. st.charId)
    if not dc or not pc then return false, 'no_drop' end
    local ctx = { src = src, reason = 'pickup', from = dc.id, to = pc.id }
    local slots = {}
    if slot then slots[1] = Util.toInt(slot) else
        for s in pairs(dc.stacks) do slots[#slots + 1] = s end
        table.sort(slots)
    end
    local taken, lastErr = {}, nil
    for _, s in ipairs(slots) do
        local e = dc.stacks[s or -1]
        if e then
            local n
            if e.kind == 'weapon' then n = 1 else
                local want = (slot and count) and math.min(Util.toInt(count) or e.count, e.count) or e.count
                n = math.min(want, Weight.maxAddable(pc, Inv.def(e.item), e.metadata))
            end
            if n and n >= 1 then
                local logged = entryLog(e, n)
                local ok, err = Inv.move(dc, s, pc, nil, n, ctx)
                if ok then taken[#taken + 1] = logged else lastErr = err end
            else
                lastErr = 'weight'
            end
        end
    end
    if #taken == 0 then return false, lastErr or 'no_item' end
    InvLog.write('pickup', { actorSrc = src, from = dc.id, to = pc.id, item = taken[1].item, count = taken[1].count,
                             data = { stacks = taken, dropId = d.id, ownerCharId = d.ownerCharId } })
    if next(dc.stacks) == nil then Drops.remove(d, 'empty') else broadcast(d) end
    local left = 0
    for _ in pairs(dc.stacks) do left = left + 1 end
    return true, { taken = taken, left = left }
end

function Drops.sweep()
    local now = Util.now()
    for _, d in pairs(drops) do
        if d.expiresAt <= now then
            local ok, removed = Inv.clear(d.cid, { occupants = true }, { reason = 'expire' })
            if ok and #removed > 0 then
                InvLog.write('drop_expired', { from = d.cid, item = removed[1].item, count = removed[1].count,
                                               actor = 'system', data = { stacks = removed, dropId = d.id,
                                               coords = { x = d.x, y = d.y, z = d.z }, ownerCharId = d.ownerCharId } })
            end
            Drops.remove(d, 'expired')
        end
    end
end

-- persistence of the drop rows (added to every full flush; returns an undo for a failed flush)
local function persistRows(list, now)
    local delSnap, dirtySnap = rowDelete, rowDirty
    for id in pairs(rowDelete) do
        list[#list + 1] = { query = 'DELETE FROM `multiinv_drops` WHERE `id` = ?', values = { id } }
    end
    rowDelete = {}
    for id in pairs(rowDirty) do
        local d = drops[id]
        if d then
            local vals = {}
            local ph = InvDB.bind({ d.id, d.cid, d.x, d.y, d.z, d.ownerCharId, d.createdAt, d.expiresAt }, 8, vals)
            list[#list + 1] = { query = 'INSERT INTO `multiinv_drops` (`id`,`container_id`,`x`,`y`,`z`,`owner_charid`,`created_at`,`expires_at`) VALUES ' .. ph .. ' ON DUPLICATE KEY UPDATE `x`=VALUES(`x`),`y`=VALUES(`y`),`z`=VALUES(`z`),`expires_at`=VALUES(`expires_at`)', values = vals }
        end
    end
    rowDirty = {}
    return function()
        for id in pairs(delSnap) do rowDelete[id] = true end
        for id in pairs(dirtySnap) do if drops[id] then rowDirty[id] = true end end
    end
end

function Drops.init()
    Persistence.addExtra(persistRows)
    if not Config.Drop.persistAcrossRestarts then
        InvDB.transaction({
            { query = "DELETE FROM `multiinv_stacks` WHERE `container_id` LIKE 'drop:%'", values = {} },
            { query = "DELETE FROM `multiinv_containers` WHERE `kind` = 'drop'", values = {} },
            { query = 'DELETE FROM `multiinv_drops`', values = {} },
        })
    end
    local maxId = tonumber(InvDB.scalar('SELECT COALESCE(MAX(`id`), 0) FROM `multiinv_drops`')) or 0
    local ai = tonumber(InvDB.scalar("SELECT `AUTO_INCREMENT` FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'multiinv_drops'")) or 1
    nextId = math.tointeger(math.max(maxId + 1, ai))
    local known = {}
    for _, r in ipairs(InvDB.query('SELECT * FROM `multiinv_drops`')) do
        local id = math.tointeger(tonumber(r.id))
        local d = { id = id, cid = r.container_id or cidOf(id), x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z),
                    ownerCharId = tonumber(r.owner_charid), createdAt = tonumber(r.created_at) or 0,
                    expiresAt = tonumber(r.expires_at) or 0 }
        drops[id] = d
        known[d.cid] = true
        Containers.get(d.cid, { create = true })
    end
    -- piles whose row is missing (crash between writes): expire them through the log
    for _, r in ipairs(InvDB.query("SELECT DISTINCT `container_id` FROM `multiinv_stacks` WHERE `container_id` LIKE 'drop:%'")) do
        if not known[r.container_id] then
            local id = math.tointeger(tonumber(r.container_id:match('^drop:(%d+)$')))
            if id then
                drops[id] = { id = id, cid = r.container_id, x = 0.0, y = 0.0, z = 0.0, createdAt = 0, expiresAt = 0 }
                Containers.get(r.container_id, { create = true })
                if id >= nextId then nextId = id + 1 end
            end
        end
    end
    Drops.sweep()
    local n = 0
    for _ in pairs(drops) do n = n + 1 end
    print(('[MULTIinventory] world drops: %d active (mode %s)'):format(n, Config.Drop.mode))
end

RegisterNetEvent('MULTIinventory:drops:request', function()
    local src = source
    local list = {}
    for _, d in pairs(drops) do list[#list + 1] = Drops.view(d) end
    TriggerClientEvent('MULTIinventory:drops:all', src, list)
end)

AddEventHandler('playerDropped', function() rate[source] = nil end)

-- tests only
function Drops._reset() drops, nextId, rowDirty, rowDelete, rate = {}, nil, {}, {}, {} end
function Drops._setNextId(n) nextId = n end
