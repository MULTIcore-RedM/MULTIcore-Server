-- ============================================================
-- MULTIinventory :: server/weapons/weapons.lua
--
-- Weapons are unique rows in multiinv_weapons and occupy one slot of a container as an
-- occupant entry:
--   { kind = 'weapon', id = 'w<id>', weaponId, item = WEAPON_NAME, count = 1, label, metadata, weight }
-- The core moves/swaps/sorts/gives/drops/picks up occupants and fires occupantMoved /
-- occupantRemoved; this module owns the rows and persists them (write-behind, inside the
-- core's flush transaction via Persistence.addExtra). All rows are cached in memory
-- (loaded once, on the first container load), so placing weapons never yields.
--
-- Lua API (in-resource; the vorp_inventory face builds the vorp_inventory names on it):
--   Weapons.ensureLoaded() -> bool
--   Weapons.create(target, name, opts, ctx) -> ok, rec|err
--       opts = { ammo = { AMMO_X = n } | n, components = {..}, comps = { [cat] = comp }, id, serial,
--                serialFallback, customLabel, customDesc, metadata, slot, owner, condition = { dirt, soot,
--                degradation, damage }, ignoreWeight }
--       ctx  = { src, reason, actor, resource, ignoreWeaponLimit }
--   Weapons.get(id) -> rec|nil   Weapons.bySerial(s) -> rec|nil   Weapons.toTable(rec) -> vorp-shaped table
--   Weapons.list(target) -> { weaponTable } (weapons in that container, by slot)
--   Weapons.ownedBy(src, id) -> rec|nil     (weapon in src's player grid)
--   Weapons.delete(id, ctx) -> ok, err      Weapons.detach(id, ctx) -> ok, err   (row kept, no container)
--   Weapons.moveTo(id, target, ctx, slot) -> ok, err
--   Weapons.setCustomLabel(id, text) / setCustomDesc(id, text) / setSerial(id, serial) -> ok, err
--   Weapons.getComponents(id) -> comps map  Weapons.addComponents(id, t) / subComponents(id, t) -> ok, err
--   Weapons.canCarry(target, amount, name) -> ok, err ('weapon_limit'|'slots'|'weight'|...)
--   Weapons.maxFor(charId) -> n             Weapons.countCarried(container) -> n
--   Weapons.equip(src, id, opts) / holster(src, id) / draw(src, id) -> ok, err
--   Weapons.equipped(src) -> { rec, ... }   Weapons.clean(src, id|nil, item|nil, stackId|nil) -> ok, err
--   Weapons.unload(src, id) -> ok, err      Weapons.getBullets(id, type|nil) -> n
--   Weapons.restore(actorSrc, logId, target|nil) -> ok, { restored, failed }
-- Events (server-local): MULTIinventory:weaponEquipped (src, weaponTable),
--   MULTIinventory:weaponHolstered (src, weaponId), MULTIinventory:weaponCreated (weaponId, containerId, weaponTable),
--   MULTIinventory:weaponDeleted (weaponId, snapshot), MULTIinventory:weaponComponentsChanged (weaponId, comps, components)
-- InvHooks emitted: weaponEquipped(src, rec), weaponCreated(c, rec, ctx), weaponDeleted(snapshot, ctx)
-- Client events: MULTIinventory:weapons:cl:equip / :holster / :remove / :draw / :loadout / :condition /
--   :components / :ammo / :belt / :ammoclear     Net in: MULTIinventory:weapons:sv:report
-- ============================================================

Weapons = Weapons or {}
Weapons.DETACHED = 'weapons:detached'

local W, bySerial, byContainer = {}, {}, {}
local dirty, deleted = {}, {}
local loaded, loadTriedAt, loadingP = false, nil, nil
local nextId, blockEnd = nil, nil
local sessions = {}      -- [src] = { onPed = { [id] = true }, held = id|nil, lastReport = s }
local COND = { 'dirt', 'soot', 'degradation', 'damage' }

local function cfg() return Config.Weapons end
local function now() return Util.now() end

local MSG = {
    weapon_limit = 'You cannot carry more weapons.',
    weapon_equipped = 'Holster that weapon first.',
    ammo_full = 'Your gunbelt cannot hold more of that.',
    weapon_cleaned = 'You cleaned your %s.',
    no_cleaning_item = 'You have nothing to clean it with.',
    no_weapon = 'No weapon to clean.',
    offhand_holster = 'You need an off-hand holster to carry a second sidearm.',
    thrown_empty = 'You have no %s left to throw.',
}
local function msg(key, ...)
    local s = L and L(key) or key
    if s == key then s = MSG[key] or key end
    if select('#', ...) > 0 then s = s:format(...) end
    return s
end
Weapons.msg = msg

local function nonEmpty(v)
    if v == nil then return nil end
    v = tostring(v)
    if v == '' then return nil end
    return v
end

local function clean(text, max)
    if text == nil then return nil end
    text = tostring(text):gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return nil end
    return text:sub(1, max)
end

local function normAmmo(a, def)
    local out = {}
    if type(a) == 'number' then
        local t = def and def.ammoTypes and def.ammoTypes[1]
        if t and a >= 1 then out[t] = math.floor(a) end
        return out
    end
    if type(a) == 'string' then a = Util.jsonDecode(a, {}) end
    if type(a) ~= 'table' then return out end
    for k, v in pairs(a) do
        local n = math.tointeger(math.floor(tonumber(v) or 0))
        if type(k) == 'string' and n and n > 0 then out[k:upper()] = n end
    end
    return out
end

local function sumAmmo(a)
    local n = 0
    for _, v in pairs(a or {}) do n = n + v end
    return n
end

-- ------------------------------------------------------------
-- index
-- ------------------------------------------------------------
local function indexAdd(r)
    byContainer[r.container] = byContainer[r.container] or {}
    byContainer[r.container][r.id] = true
    if r.serial then bySerial[r.serial] = r.id end
end

local function indexDel(r)
    local s = byContainer[r.container]
    if s then s[r.id] = nil; if next(s) == nil then byContainer[r.container] = nil end end
    if r.serial and bySerial[r.serial] == r.id then bySerial[r.serial] = nil end
end

local function relocate(r, cid, slot)
    local s = byContainer[r.container]
    if s then s[r.id] = nil; if next(s) == nil then byContainer[r.container] = nil end end
    r.container, r.slot = cid, slot or 0
    byContainer[cid] = byContainer[cid] or {}
    byContainer[cid][r.id] = true
end

local function markDirty(r)
    r.updatedAt = now()
    dirty[r.id] = true
end

-- ------------------------------------------------------------
-- view
-- ------------------------------------------------------------
function Weapons.displayLabel(r)
    local def = WeaponDefs.get(r.name)
    return r.customLabel or r.label or (def and def.label) or r.name
end

function Weapons.conditionPct(r)
    local worst = math.max(r.degradation or 0, r.damage or 0)
    return math.floor(Util.clamp((1 - worst) * 100, 0, 100) + 0.5)
end

local function countComps(r)
    local n = 0
    for _ in pairs(r.comps or {}) do n = n + 1 end
    return n + #(r.components or {})
end

local function viewMeta(r, def)
    local ammoType
    for t in pairs(r.ammo) do ammoType = t break end
    return {
        label = Weapons.displayLabel(r),
        description = r.customDesc or (def and def.desc ~= '' and def.desc) or nil,
        serial = r.serial,
        weaponGroup = def and def.group,
        sidearm = WeaponDefs.isHandgun(def),   -- [inv_sawnoff] hip holster (UI: not only revolver/pistol)
        ammo = sumAmmo(r.ammo),
        stack = WeaponDefs.isThrown(def) and sumAmmo(r.ammo) or nil,   -- [thrown] how many to throw (tile badge)
        ammoType = ammoType,
        clip = def and def.clip or 0,
        components = countComps(r),
        condition = Weapons.conditionPct(r),
        dirt = Util.round(r.dirt or 0, 2),
        equipped = r.equipped,
        image = r.name:lower() .. '.png',
    }
end

---Weight of the occupant: a throwable stack weighs def.weight per piece carried (at least one).
local function weightOf(r, def)
    local w = def and def.weight or 1.0
    if WeaponDefs.isThrown(def) then w = w * math.max(1, sumAmmo(r.ammo)) end
    return w
end

local function entryOf(r)
    local def = WeaponDefs.get(r.name)
    return { kind = 'weapon', id = 'w' .. r.id, weaponId = r.id, item = r.name, count = 1,
             label = Weapons.displayLabel(r), metadata = viewMeta(r, def), weight = weightOf(r, def) }
end

local function findEntry(c, id)
    if not c then return nil end
    for _, e in pairs(c.stacks) do
        if e.kind == 'weapon' and e.weaponId == id then return e end
    end
    return nil
end

---Push the occupant's new label/metadata to viewers (UI only - occupants are never in the stack rows,
---so the container is not marked dirty).
local function refresh(r)
    local c = Containers.peek(r.container)
    local e = findEntry(c, r.id)
    if not e then return end
    local def = WeaponDefs.get(r.name)
    e.label = Weapons.displayLabel(r)
    e.metadata = viewMeta(r, def)
    e.weight = def and weightOf(r, def) or e.weight
    c.changed = c.changed or {}
    c.changed[e.slot] = true
    Sync.queue(c, e.slot)
end
Weapons._refresh = refresh

function Weapons.snapshot(r)
    return { id = r.id, name = r.name, label = r.label, serial = r.serial, customLabel = r.customLabel,
             customDesc = r.customDesc, ammo = Util.deepcopy(r.ammo), components = Util.deepcopy(r.components),
             comps = Util.deepcopy(r.comps), dirt = r.dirt, soot = r.soot, degradation = r.degradation,
             damage = r.damage, metadata = Util.deepcopy(r.metadata), owner = r.owner, container = r.container, slot = r.slot }
end

function Weapons.toTable(r)
    if not r then return nil end
    local def = WeaponDefs.get(r.name) or {}
    local src = r.owner and State.srcOfChar(r.owner) or nil
    local inOwnerGrid = r.owner ~= nil and r.container == ('player:' .. r.owner)
    return {
        id = r.id, weaponId = r.id, name = r.name, hash = joaat(r.name),
        label = Weapons.displayLabel(r), default_label = r.label or def.label,
        custom_label = r.customLabel, custom_desc = r.customDesc,
        desc = r.customDesc or def.desc, description = r.customDesc or def.desc,
        serial_number = r.serial, serialNumber = r.serial,
        used = r.equipped ~= nil, used2 = r.equipped == 'left', equipped = r.equipped,
        group = 5, weaponGroup = def.group, sidearm = WeaponDefs.isHandgun(def),
        ammo = Util.deepcopy(r.ammo), components = Util.deepcopy(r.components), comps = Util.deepcopy(r.comps),
        charidentifier = r.owner, propietary = r.owner, source = src,
        currInv = inOwnerGrid and 'default' or r.container, container = r.container, slot = r.slot,
        dropped = tostring(r.container):match('^drop:') and 1 or 0,
        dirt = r.dirt, soot = r.soot, degradation = r.degradation, damage = r.damage,
        condition = Weapons.conditionPct(r), weight = def.weight, metadata = Util.deepcopy(r.metadata),
    }
end

-- ------------------------------------------------------------
-- load + ids
-- ------------------------------------------------------------
local function fromRow(row)
    local name = tostring(row.name or ''):upper()
    local def = WeaponDefs.get(name)
    local comps = Util.jsonDecode(row.comps, {})
    local components = Util.jsonDecode(row.components, {})
    local r = {
        id = math.tointeger(tonumber(row.id)),
        container = row.container_id or Weapons.DETACHED,
        slot = tonumber(row.slot) or 0,
        owner = tonumber(row.owner_charid),
        name = name,
        label = nonEmpty(row.label),
        serial = nonEmpty(row.serial),
        customLabel = nonEmpty(row.custom_label),
        customDesc = nonEmpty(row.custom_desc),
        ammo = normAmmo(row.ammo, def),
        components = type(components) == 'table' and components or {},
        comps = type(comps) == 'table' and comps or {},
        equipped = nonEmpty(row.equipped),
        metadata = Util.jsonDecode(row.metadata, {}) or {},
        legacy = tonumber(row.legacy_loadout_id),
        batch = tonumber(row.migration_batch),
        updatedAt = tonumber(row.updated_at) or now(),
    }
    for _, k in ipairs(COND) do r[k] = Util.clamp(tonumber(row[k]) or 0, 0, 1) end
    if type(r.metadata) ~= 'table' then r.metadata = {} end
    -- [thrown] rows saved before throwables had a count (ammo '{}') hold the default count (1)
    if WeaponDefs.isThrown(def) and next(r.ammo) == nil then
        local n, t = WeaponDefs.thrownDefault(def), def.ammoTypes and def.ammoTypes[1]
        if t and n > 0 then r.ammo = { [t] = n } end
    end
    return r
end

local function reserveBlock(from, await)
    local size = (Config.Persistence and Config.Persistence.idBlock) or 1000
    nextId = from
    blockEnd = from + size - 1
    local sql = ('ALTER TABLE `multiinv_weapons` AUTO_INCREMENT = %d'):format(blockEnd + 1)
    if await then InvDB.query(sql) else MySQL.query(sql, {}) end
end

local function allocId(preferred)
    preferred = Util.toInt(preferred)
    if preferred and preferred > 0 and not W[preferred] then return preferred end
    while true do
        if nextId > blockEnd then reserveBlock(blockEnd + 1, false) end
        local id = nextId
        nextId = nextId + 1
        if not W[id] then return id end
    end
end

local placeLoaded

function Weapons.ensureLoaded()
    if loaded then return true end
    if loadingP then Citizen.Await(loadingP) return loaded end
    local t = now()
    if loadTriedAt and t - loadTriedAt < 30 then return false end
    loadTriedAt = t
    loadingP = promise.new()
    local okQ, rows = pcall(MySQL.query.await, 'SELECT * FROM `multiinv_weapons`', {})
    local okA, ai = pcall(MySQL.scalar.await, "SELECT `AUTO_INCREMENT` FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'multiinv_weapons'", {})
    if not okQ or type(rows) ~= 'table' or not okA then
        print(('^1[MULTIinventory] weapons: could not load multiinv_weapons (%s) - retry in 30 s^7'):format(tostring(okQ and ai or rows)))
        local p = loadingP
        loadingP = nil
        p:resolve(false)
        return false
    end
    W, bySerial, byContainer = {}, {}, {}
    local maxId = 0
    for _, row in ipairs(rows) do
        local r = fromRow(row)
        if r.id and r.name ~= '' then
            if r.serial and bySerial[r.serial] then r.serial = nil end -- uq_serial makes this impossible; defensive
            W[r.id] = r
            indexAdd(r)
            if r.id > maxId then maxId = r.id end
        end
    end
    reserveBlock(math.tointeger(math.max(maxId + 1, tonumber(ai) or 1)), true)
    loaded = true
    local p = loadingP
    loadingP = nil
    p:resolve(true)
    -- containers cached before the weapons were available get their occupants now
    Containers.each(function(c) placeLoaded(c) end)
    return true
end

function Weapons.isLoaded() return loaded end

---Put the cached weapons of a loaded container into its slots (idempotent).
function placeLoaded(c)
    if not loaded or c.kind == 'equip' then return end
    local set = byContainer[c.id]
    if not set then return end
    local list = {}
    for id in pairs(set) do list[#list + 1] = W[id] end
    table.sort(list, function(a, b) if a.slot ~= b.slot then return a.slot < b.slot end return a.id < b.id end)
    for _, r in ipairs(list) do
        if not findEntry(c, r.id) then
            local slot = r.slot
            if not slot or slot < 1 or slot > c.slots or c.stacks[slot] then slot = Containers.freeSlot(c) end
            if not slot then
                c.slots = c.slots + 1
                slot = c.slots
                print(('^3[MULTIinventory] %s over capacity - grew to %d slots to keep weapon %d^7'):format(c.id, c.slots, r.id))
            end
            Containers.place(c, slot, entryOf(r))
            if slot ~= r.slot then r.slot = slot; markDirty(r) end
        end
    end
end

-- ------------------------------------------------------------
-- persistence (inside the core flush transaction)
-- ------------------------------------------------------------
local COLS = '(`id`,`container_id`,`slot`,`owner_charid`,`name`,`label`,`serial`,`custom_label`,`custom_desc`,`ammo`,`components`,`comps`,`dirt`,`soot`,`degradation`,`damage`,`equipped`,`metadata`,`updated_at`)'
local UPD = {}
for c in COLS:gmatch('`([%w_]+)`') do if c ~= 'id' then UPD[#UPD + 1] = ('`%s`=VALUES(`%s`)'):format(c, c) end end
local UPSERT_TAIL = ' ON DUPLICATE KEY UPDATE ' .. table.concat(UPD, ',')

local function upsert(r, t)
    local vals = {}
    local ph = InvDB.bind({ r.id, r.container, r.slot or 0, r.owner, r.name, r.label and r.label:sub(1, 50), r.serial,
        r.customLabel, r.customDesc, Util.jsonEncode(r.ammo), Util.jsonEncode(r.components), Util.jsonEncode(r.comps),
        r.dirt or 0, r.soot or 0, r.degradation or 0, r.damage or 0, r.equipped, Util.jsonEncode(r.metadata),
        r.updatedAt or t }, 19, vals)
    return { query = 'INSERT INTO `multiinv_weapons` ' .. COLS .. ' VALUES ' .. ph .. UPSERT_TAIL, values = vals }
end

local function persist(list, t)
    if next(dirty) == nil and next(deleted) == nil then return nil end
    local snapD, snapX = dirty, deleted
    dirty, deleted = {}, {}
    local ids = {}
    for id in pairs(snapX) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        list[#list + 1] = { query = 'DELETE FROM `multiinv_weapons` WHERE `id` = ?', values = { id } }
    end
    ids = {}
    for id in pairs(snapD) do if W[id] then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do list[#list + 1] = upsert(W[id], t) end
    return function()
        for id in pairs(snapX) do if not W[id] then deleted[id] = true end end
        for id in pairs(snapD) do if W[id] then dirty[id] = true end end
    end
end

function Weapons.registerPersistence() Persistence.addExtra(persist) end
Weapons.registerPersistence()

function Weapons.isDirty(id) return dirty[id] == true end

-- ------------------------------------------------------------
-- rules
-- ------------------------------------------------------------
local function jobOf(src)
    if not src then return nil end
    local ok, job = pcall(function()
        local u = MBridge.Core.getUser(src)
        local ch = u and u.getUsedCharacter
        if type(ch) == 'function' then ch = ch() end
        if not ch then return nil end
        local j = ch.job
        if j == nil and ch.PlayerData and ch.PlayerData.job then j = ch.PlayerData.job end
        if type(j) == 'table' then j = j.name end
        return j
    end)
    return ok and job or nil
end

function Weapons.maxFor(charId)
    local src = charId and State.srcOfChar(charId)
    local job = jobOf(src)
    local o = job and (cfg().jobOverrides or {})[job]
    return tonumber(o) or cfg().maxCarried or 6
end

function Weapons.countCarried(c)
    local n = 0
    for _, e in pairs(c.stacks) do
        if e.kind == 'weapon' and WeaponDefs.counts(WeaponDefs.get(e.item)) then n = n + 1 end
    end
    return n
end

-- ------------------------------------------------------------
-- [thrown] throwable stacks: the row's ammo { [AMMO_X] = n } is the number to throw
-- ------------------------------------------------------------
---Ammo type + count a new throwable gets from create opts.ammo (a number = count of the first type).
local function thrownSpec(def, a)
    local am = normAmmo(a, def)
    local t, n
    for _, x in ipairs(def.ammoTypes or {}) do if am[x] then t, n = x, am[x] break end end
    if not t then
        t = def.ammoTypes and def.ammoTypes[1]
        n = WeaponDefs.thrownDefault(def)
    end
    return t, math.max(0, n or 0)
end
Weapons._thrownSpec = thrownSpec

---The throwable stack of `name` (ammo type t only) in container cid that still has room. No yield.
local function findThrownStack(cid, name, t)
    local def = WeaponDefs.get(name)
    if not (def and t and WeaponDefs.isThrown(def)) then return nil end
    local max = WeaponDefs.thrownStackMax(def, t)
    local best
    for id in pairs(byContainer[cid] or {}) do
        local x = W[id]
        if x and x.name == def.name then
            local only = true
            for k in pairs(x.ammo) do if k ~= t then only = false end end
            local n = x.ammo[t] or 0
            if only and n < max and (not best or x.id < best.id) then best = x end
        end
    end
    return best, max
end

function Weapons.canCarry(target, amount, name)
    local c, err = Inv.resolve(target)
    if not c then return false, err end
    amount = Util.toInt(tonumber(amount)) or 1
    if amount < 1 then amount = 1 end
    local def = name and WeaponDefs.get(name)
    if name and not def then return false, 'unknown_weapon' end
    -- [thrown] one more of a throwable the player already carries joins that stack (no new slot / weapon)
    if def and WeaponDefs.isThrown(def) and findThrownStack(c.id, def.name, thrownSpec(def, nil)) then
        local _, cap, load = Weight.pool(c)
        if cap and load + def.weight * amount > cap + 1e-6 then return false, 'weight' end
        return true
    end
    if c.kind == 'player' and (not def or WeaponDefs.counts(def)) then
        if Weapons.countCarried(c) + amount > Weapons.maxFor(c.ownerCharId) then return false, 'weapon_limit' end
    end
    if c.slots - Containers.usedSlots(c) < amount then return false, 'slots' end
    if def then
        local _, cap, load = Weight.pool(c)
        if cap and load + def.weight * amount > cap + 1e-6 then return false, 'weight' end
    end
    return true
end

local function srcOwning(c)
    return c and c.kind == 'player' and c.ownerCharId and State.srcOfChar(c.ownerCharId) or nil
end

local function sess(src)
    local s = sessions[src]
    if not s then s = { onPed = {}, lastReport = -1e9 }; sessions[src] = s end
    return s
end
Weapons._sessions = sessions

-- ------------------------------------------------------------
-- extra (third) sidearm: a VIRTUAL slot - never on the ped, never in onPed / the ammo pool.
-- Published on the player's state bag 'rinvx' = { id, name } | false, so RINGOweaponpositions can show it.
-- ------------------------------------------------------------
local function isVirtual(key) return key ~= nil and WeaponDefs.isVirtualSlot(key) end

local function publishExtra(src)
    src = tonumber(src)
    if not src or type(Player) ~= 'function' then return end
    if type(GetPlayerPing) == 'function' and (GetPlayerPing(src) or 0) <= 0 then return end
    local cur = false
    for _, x in ipairs(Weapons.equipped(src)) do
        if isVirtual(x.equipped) then cur = { id = x.id, name = x.name } break end
    end
    local p = Player(src)
    local st = p and p.state
    if st then st:set('rinvx', cur, true) end
end
Weapons.publishExtra = publishExtra

---The weapon leaves its owner's ped without a holster report (moved/deleted by force).
local function forceOffPed(r, src)
    if isVirtual(r.equipped) then
        -- the extra sidearm was never on the ped: just forget it and update the body prop
        r.equipped = nil
        if src then publishExtra(src) end
        return
    end
    r.equipped = nil
    if src then
        local s = sessions[src]
        if s then s.onPed[r.id] = nil; if s.held == r.id then s.held = nil end end
        TriggerClientEvent('MULTIinventory:weapons:cl:remove', src, r.id)
    end
end

-- ------------------------------------------------------------
-- create / delete / detach / move
-- ------------------------------------------------------------
local function genSerial(id)
    local base = (cfg().serialFormat or '%s-%06d'):format(cfg().serialPrefix or 'RNG', id)
    local s, k = base, 1
    while bySerial[s] do k = k + 1; s = base .. '-' .. k end
    return s
end

local function ctxActor(ctx)
    return ctx.actor or (ctx.resource and ('resource:' .. tostring(ctx.resource))) or nil
end

---Checks for putting an occupant into c (slot nil = first free). No yield. -> slot | nil, err
local function canPlaceNew(c, slot, entry, ctx, opts)
    if c.kind == 'equip' then return nil, 'equip_slot' end
    if slot ~= nil then
        slot = Util.toInt(tonumber(slot))
        if not slot or slot < 1 or slot > c.slots then return nil, 'bad_slot' end
        if c.stacks[slot] then return nil, 'slot_taken' end
    else
        slot = Containers.freeSlot(c)
        if not slot then return nil, 'slots' end
    end
    local ok, err = Inv.checkPlace(c, slot, entry, ctx)
    if not ok then return nil, err end
    ok, err = InvHooks.check('canAdd', c, entry.item, 1, entry.metadata, ctx)
    if not ok then return nil, err end
    if not (opts and opts.ignoreWeight) then
        local _, cap, load = Weight.pool(c)
        if cap and load + (entry.weight or 0) > cap + 1e-6 then return nil, 'weight' end
    end
    return slot
end

function Weapons.create(target, name, opts, ctx)
    opts, ctx = opts or {}, ctx or { reason = 'api' }
    if not Weapons.ensureLoaded() then return false, 'not_ready' end
    local def = WeaponDefs.get(name)
    if not def then return false, 'unknown_weapon' end
    local c, err = Inv.resolve(target)
    if not c then return false, err or 'unknown_container' end
    -- ---- no yield below ----
    local thrownLeft
    if WeaponDefs.isThrown(def) then
        -- [thrown] one row per kind: the count joins the stack already in this container (up to its max);
        -- only what does not fit makes a new row. Restores (opts.id) / opts.noStack always make a new row.
        local t, n = thrownSpec(def, opts.ammo)
        if t and not opts.id and not opts.noStack and c.kind ~= 'equip' then
            local x, max = findThrownStack(c.id, def.name, t)
            if x and n > 0 then
                local add = math.min(n, max - (x.ammo[t] or 0))
                if not opts.ignoreWeight then
                    local _, cap, load = Weight.pool(c)
                    if cap and load + def.weight * add > cap + 1e-6 then return false, 'weight' end
                end
                x.ammo[t] = (x.ammo[t] or 0) + add
                markDirty(x)
                refresh(x)
                -- on the ped right now: the ped gets the extra ones too (conservation counts them in)
                local src = c.kind == 'player' and c.ownerCharId and State.srcOfChar(c.ownerCharId)
                local s = src and sessions[src]
                if s and s.onPed[x.id] then Ammo.push(c.ownerCharId, { [t] = add }) end
                InvLog.write('weapon_create', { actorSrc = ctx.src, actor = ctxActor(ctx), to = c.id, item = x.name, count = add,
                                                targetCharId = x.owner, data = { stackedInto = x.id, ammoType = t, reason = ctx.reason } })
                n = n - add
                if n <= 0 then return true, x end
            elseif x and n <= 0 then
                return true, x   -- nothing to add (e.g. an empty knife sheath): the stack is already here
            end
        end
        thrownLeft = (t and n > 0) and { [t] = n } or {}
    end
    local serial = nonEmpty(opts.serial)
    if serial then
        serial = serial:sub(1, 50)
        if bySerial[serial] then
            if not opts.serialFallback then return false, 'serial_taken' end
            serial = nil
        end
    end
    local r = {
        id = 0, container = c.id, slot = 0, owner = c.kind == 'player' and c.ownerCharId or tonumber(opts.owner),
        name = def.name, label = def.label,
        customLabel = clean(opts.customLabel, cfg().customLabelMax or 50),
        customDesc = clean(opts.customDesc, cfg().customDescMax or 255),
        ammo = thrownLeft or normAmmo(opts.ammo, def),
        components = type(opts.components) == 'table' and Util.deepcopy(opts.components) or {},
        comps = type(opts.comps) == 'table' and Util.deepcopy(opts.comps) or {},
        metadata = type(opts.metadata) == 'table' and Util.deepcopy(opts.metadata) or {},
        dirt = 0, soot = 0, degradation = 0, damage = 0,
    }
    for _, k in ipairs(COND) do
        local v = opts.condition and tonumber(opts.condition[k])
        if v then r[k] = Util.clamp(v, 0, 1) end
    end
    local slot
    slot, err = canPlaceNew(c, opts.slot, entryOf(r), ctx, opts)
    if not slot then return false, err end
    r.id = allocId(opts.id)
    r.serial = serial or genSerial(r.id)
    W[r.id] = r
    indexAdd(r)
    Containers.place(c, slot, entryOf(r))
    r.slot = slot
    markDirty(r)
    InvLog.write('weapon_create', { actorSrc = ctx.src, actor = ctxActor(ctx), to = c.id, item = r.name, count = 1,
                                    targetCharId = r.owner, data = { stacks = { { kind = 'weapon', weaponId = r.id, item = r.name, count = 1, weapon = Weapons.snapshot(r) } }, reason = ctx.reason } })
    InvHooks.emit('weaponCreated', c, r, ctx)
    TriggerEvent('MULTIinventory:weaponCreated', r.id, c.id, Weapons.toTable(r))
    return true, r
end

local function dropRecord(r, ctx, why)
    local snap = Weapons.snapshot(r)
    indexDel(r)
    W[r.id] = nil
    dirty[r.id] = nil
    deleted[r.id] = true
    for _, s in pairs(sessions) do s.onPed[r.id] = nil end
    InvLog.write('weapon_delete', { actorSrc = ctx.src, actor = ctxActor(ctx), from = snap.container, to = 'weapon:' .. r.id,
                                    item = r.name, count = 1, targetCharId = r.owner,
                                    data = { stacks = { { kind = 'weapon', weaponId = r.id, item = r.name, count = 1, weapon = snap } },
                                             reason = why or ctx.reason } })
    InvHooks.emit('weaponDeleted', snap, ctx)
    TriggerEvent('MULTIinventory:weaponDeleted', r.id, snap)
end

local function takeOccupant(r)
    local c = Containers.peek(r.container)
    local e = findEntry(c, r.id)
    if e then Containers.take(c, e.slot) end
    return c
end

function Weapons.delete(id, ctx)
    ctx = ctx or { reason = 'api' }
    if not Weapons.ensureLoaded() then return false, 'not_ready' end
    local r = W[Util.toInt(tonumber(id)) or -1]
    if not r then return false, 'no_weapon' end
    local c = takeOccupant(r)
    if r.equipped then forceOffPed(r, srcOwning(c) or (r.owner and State.srcOfChar(r.owner))) end
    dropRecord(r, ctx)
    return true
end

---vorp subWeapon: the weapon leaves the player but its row (serial, parts) is kept, ownerless.
function Weapons.detach(id, ctx)
    ctx = ctx or { reason = 'api' }
    if not Weapons.ensureLoaded() then return false, 'not_ready' end
    local r = W[Util.toInt(tonumber(id)) or -1]
    if not r then return false, 'no_weapon' end
    if r.container == Weapons.DETACHED then return true end
    local from = r.container
    local c = takeOccupant(r)
    if r.equipped then forceOffPed(r, srcOwning(c) or (r.owner and State.srcOfChar(r.owner))) end
    relocate(r, Weapons.DETACHED, 0)
    local prevOwner = r.owner
    r.owner = nil
    markDirty(r)
    InvLog.write('weapon_detach', { actorSrc = ctx.src, actor = ctxActor(ctx), from = from, to = Weapons.DETACHED, item = r.name,
                                    count = 1, targetCharId = prevOwner,
                                    data = { stacks = { { kind = 'weapon', weaponId = r.id, item = r.name, count = 1 } } } })
    return true
end

---Move a weapon to another container (core Inv.move when it sits in a container, else a checked placement).
function Weapons.moveTo(id, target, ctx, slot)
    ctx = ctx or { reason = 'api' }
    if not Weapons.ensureLoaded() then return false, 'not_ready' end
    local r = W[Util.toInt(tonumber(id)) or -1]
    if not r then return false, 'no_weapon' end
    local toC, err = Inv.resolve(target)
    if not toC then return false, err or 'unknown_container' end
    local fromC
    if r.container ~= Weapons.DETACHED then
        fromC = Containers.peek(r.container) or Containers.get(r.container, { create = true })
    end
    if W[r.id] ~= r then return false, 'no_weapon' end -- deleted while its container loaded
    local e = findEntry(fromC, r.id)
    if e then
        ctx.from, ctx.to = fromC.id, toC.id
        return Inv.move(fromC, e.slot, toC, slot, 1, ctx)
    end
    -- detached (or its container vanished): place it fresh
    local entry = entryOf(r)
    local s
    s, err = canPlaceNew(toC, slot, entry, ctx)
    if not s then return false, err end
    Containers.place(toC, s, entry)
    relocate(r, toC.id, s)
    if toC.kind == 'player' then r.owner = toC.ownerCharId end
    markDirty(r)
    return true
end

-- ------------------------------------------------------------
-- lookups
-- ------------------------------------------------------------
function Weapons.get(id)
    Weapons.ensureLoaded()
    return W[Util.toInt(tonumber(id)) or -1]
end

function Weapons.bySerial(serial)
    Weapons.ensureLoaded()
    local id = serial and bySerial[tostring(serial)]
    return id and W[id] or nil
end

function Weapons.recordsIn(cid)
    local out = {}
    for id in pairs(byContainer[cid] or {}) do out[#out + 1] = W[id] end
    table.sort(out, function(a, b) if a.slot ~= b.slot then return a.slot < b.slot end return a.id < b.id end)
    return out
end

function Weapons.list(target)
    if not Weapons.ensureLoaded() then return {} end
    local c = Inv.resolve(target)
    if not c then return {} end
    local out = {}
    for _, r in ipairs(Weapons.recordsIn(c.id)) do out[#out + 1] = Weapons.toTable(r) end
    return out
end

function Weapons.ownedBy(src, id)
    local st = State.get(tonumber(src))
    if not st then return nil end
    local r = Weapons.get(id)
    if r and r.container == 'player:' .. st.charId then return r end
    return nil
end

function Weapons.equipped(src)
    local st = State.get(tonumber(src))
    if not st then return {} end
    local out = {}
    for _, r in ipairs(Weapons.recordsIn('player:' .. st.charId)) do
        if r.equipped then out[#out + 1] = r end
    end
    return out
end

function Weapons.getBullets(id, ammoType)
    local r = Weapons.get(id)
    if not r then return 0 end
    if ammoType then return r.ammo[tostring(ammoType):upper()] or 0 end
    return sumAmmo(r.ammo)
end

-- ------------------------------------------------------------
-- label / desc / serial / components
-- ------------------------------------------------------------
function Weapons.setCustomLabel(id, text)
    local r = Weapons.get(id)
    if not r then return false, 'no_weapon' end
    r.customLabel = clean(text, cfg().customLabelMax or 50)
    markDirty(r); refresh(r)
    return true
end

function Weapons.setCustomDesc(id, text)
    local r = Weapons.get(id)
    if not r then return false, 'no_weapon' end
    r.customDesc = clean(text, cfg().customDescMax or 255)
    markDirty(r); refresh(r)
    return true
end

function Weapons.setSerial(id, serial)
    local r = Weapons.get(id)
    if not r then return false, 'no_weapon' end
    serial = clean(serial, 50)
    if not serial then return false, 'bad_serial' end
    if bySerial[serial] and bySerial[serial] ~= r.id then return false, 'serial_taken' end
    if r.serial and bySerial[r.serial] == r.id then bySerial[r.serial] = nil end
    r.serial = serial
    bySerial[serial] = r.id
    markDirty(r); refresh(r)
    return true
end

local function isArray(t)
    if type(t) ~= 'table' then return false end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    for i = 1, n do if t[i] == nil then return false end end
    return n > 0
end

local function pushComponents(r)
    refresh(r)
    if r.equipped and r.owner then
        local src = State.srcOfChar(r.owner)
        if src then TriggerClientEvent('MULTIinventory:weapons:cl:components', src, r.id, r.comps, r.components) end
    end
    TriggerEvent('MULTIinventory:weaponComponentsChanged', r.id, Util.deepcopy(r.comps), Util.deepcopy(r.components))
end

function Weapons.getComponents(id)
    local r = Weapons.get(id)
    if not r then return nil end
    return Util.deepcopy(r.comps)
end

---t = { [category] = component } (customisation, RINGOcustoms/RINGOgunsmith) or { 'COMPONENT_X', ... } (attachments).
function Weapons.addComponents(id, t)
    local r = Weapons.get(id)
    if not r then return false, 'no_weapon' end
    if type(t) ~= 'table' or next(t) == nil then return false, 'bad_components' end
    if isArray(t) then
        local have = {}
        for _, v in ipairs(r.components) do have[v] = true end
        for _, v in ipairs(t) do
            if (type(v) == 'string' or type(v) == 'number') and not have[v] then r.components[#r.components + 1] = v; have[v] = true end
        end
    else
        for k, v in pairs(t) do
            if (type(k) == 'string' or type(k) == 'number') and (type(v) == 'string' or type(v) == 'number') then r.comps[tostring(k)] = v end
        end
    end
    markDirty(r)
    pushComponents(r)
    return true
end

function Weapons.subComponents(id, t)
    local r = Weapons.get(id)
    if not r then return false, 'no_weapon' end
    if type(t) ~= 'table' then return false, 'bad_components' end
    local gone = {}
    if isArray(t) then
        for _, v in ipairs(t) do gone[v] = true end
        for k, v in pairs(r.comps) do if gone[v] then r.comps[k] = nil end end
    else
        for k, v in pairs(t) do
            local cur = r.comps[tostring(k)]
            if cur ~= nil and (v == true or v == cur or tostring(v) == tostring(cur)) then r.comps[tostring(k)] = nil end
            if type(v) == 'string' or type(v) == 'number' then gone[v] = true end
        end
    end
    local keep = {}
    for _, v in ipairs(r.components) do if not gone[v] then keep[#keep + 1] = v end end
    r.components = keep
    markDirty(r)
    pushComponents(r)
    return true
end

---Replace the whole customisation set: t = { [category] = component } (a VORP `loadout.comps` map).
function Weapons.setComps(id, t)
    local r = Weapons.get(id)
    if not r then return false, 'no_weapon' end
    if type(t) ~= 'table' then return false, 'bad_components' end
    local comps = {}
    for k, v in pairs(t) do
        if (type(k) == 'string' or type(k) == 'number') and (type(v) == 'string' or type(v) == 'number') then comps[tostring(k)] = v end
    end
    r.comps = comps
    markDirty(r)
    pushComponents(r)
    return true
end

-- ------------------------------------------------------------
-- equip / holster / draw
-- ------------------------------------------------------------
local function slotAttach(key)
    if tostring(key):sub(1, 4) == 'kit:' then return cfg().kitAttach or 0 end
    local s = (cfg().slots or {})[key]
    return s and s.attach or 0
end

local function pickAmmo(r, def, belt)
    local types = def.ammoTypes or {}
    if #types == 0 then return nil, 0 end
    local best, bestN
    for _, t in ipairs(types) do
        local n = r.ammo[t]
        if n and (not bestN or n > bestN) then best, bestN = t, n end
    end
    if not best then
        for _, t in ipairs(types) do if (belt[t] or 0) > 0 then best = t break end end
    end
    best = best or types[1]
    -- [thrown] the whole stack goes onto the ped (no magazine: the count is what can be thrown)
    if WeaponDefs.isThrown(def) then return best, r.ammo[best] or 0 end
    return best, math.min(r.ammo[best] or 0, def.clip or 0)
end

local function equipPayload(r, def, clip, ammoType, deltas, draw)
    return {
        id = r.id, name = r.name, slot = r.equipped, attach = slotAttach(r.equipped),
        isDual = r.equipped == 'left', clip = clip, ammoType = ammoType, ammoTypes = def.ammoTypes,
        deltas = deltas or {}, components = r.components, comps = r.comps,
        condition = { dirt = r.dirt, soot = r.soot, degradation = r.degradation, damage = r.damage },
        serial = r.serial, label = Weapons.displayLabel(r), group = def.group, draw = draw == true,
        defaults = def.defaults or {},
    }
end

---May this character use the left hip (off-hand holster)? Config.Weapons.dualWield = { enabled,
---requireItem }: requireItem must be in the player's grid or worn (equipment). No yield.
---@return boolean ok, string|nil err  ('dual_disabled'|'offhand_holster')
function Weapons.dualAllowed(charId)
    local enabled, item = WeaponDefs.dualWield()
    if not enabled then return false, 'dual_disabled' end
    if not item then return true end
    for _, cid in ipairs({ 'player:' .. tostring(charId), 'equip:' .. tostring(charId) }) do
        local c = Containers.peek(cid)
        if c and Stacking.count(c, item) > 0 then return true end
    end
    return false, 'offhand_holster'
end

---Does this character own the off-hand holster LEATHER (Config.Weapons.offhandHolster.leatherItem)?
---Without it a left-hip gun still works, the leather just is not drawn. nil item = always yes.
function Weapons.hasLeather(charId)
    local item = (cfg().offhandHolster or {}).leatherItem
    if not item then return true end
    for _, cid in ipairs({ 'player:' .. tostring(charId), 'equip:' .. tostring(charId) }) do
        local c = Containers.peek(cid)
        if c and Stacking.count(c, item) > 0 then return true end
    end
    return false
end

-- the leather item came or went: tell that player's client (draws / strips the leather)
local function leatherChanged(c, item)
    local li = (cfg().offhandHolster or {}).leatherItem
    if not li or item ~= li or not c or not c.ownerCharId then return end
    if c.kind ~= 'player' and c.kind ~= 'equip' then return end
    local src = State.srcOfChar(c.ownerCharId)
    if src then TriggerClientEvent('MULTIinventory:weapons:cl:leather', src, Weapons.hasLeather(c.ownerCharId)) end
end
InvHooks.register('itemAdded', function(c, item) leatherChanged(c, item) end)
InvHooks.register('itemRemoved', function(c, item) leatherChanged(c, item) end)

---Put a weapon of src's grid on the ped. opts = { hand = 'left'|'right', draw = bool }
---Handguns: right hip first, then the left hip (dual wield, Weapons.dualAllowed); a full pair
---swaps the right one. opts.hand picks the hip ('left' fails with 'offhand_holster' when gated).
function Weapons.equip(src, id, opts)
    opts = opts or {}
    src = tonumber(src)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local r = Weapons.ownedBy(src, id)
    if not r then return false, 'no_weapon' end
    local belt = Ammo.get(st.charId)   -- may yield on the first load; the checks follow
    if r.container ~= 'player:' .. st.charId then return false, 'no_weapon' end
    if r.equipped then
        if opts.draw and isVirtual(r.equipped) then return Weapons.swapExtra(src) end
        if opts.draw then TriggerClientEvent('MULTIinventory:weapons:cl:draw', src, r.id) end
        return true
    end
    local def = WeaponDefs.get(r.name)
    if WeaponDefs.isThrown(def) then
        -- [thrown] nothing left to throw (stack 0 and none of its ammo on the gunbelt): refuse
        local n = sumAmmo(r.ammo)
        for _, t in ipairs(def.ammoTypes or {}) do n = n + (belt[t] or 0) end
        if n <= 0 then
            Sync.notify(src, msg('thrown_empty', Weapons.displayLabel(r)), 'error')
            return false, 'thrown_empty'
        end
    end
    local slots = WeaponDefs.equipSlotsFor(def)
    local used = {}
    for _, x in ipairs(Weapons.equipped(src)) do used[x.equipped] = x end
    local key
    local dualOk, dualErr = Weapons.dualAllowed(st.charId)
    if WeaponDefs.isHandgun(def) and opts.hand == 'extra' and WeaponDefs.extraOn() then
        key = 'extra'
    elseif WeaponDefs.isHandgun(def) and (opts.hand == 'left' or opts.hand == 'right') then
        key = opts.hand
        if key == 'left' and not dualOk then
            if dualErr == 'offhand_holster' then
                Sync.notify(src, msg('offhand_holster'), 'error')
                return false, 'offhand_holster'
            end
            key = 'right'
        end
    else
        local skippedLeft = false
        for _, k in ipairs(slots) do
            if k == 'left' and not dualOk then skippedLeft = true
            elseif not used[k] then key = k break end
        end
        -- a second sidearm with no off-hand holster: say why instead of silently swapping the first one
        if not key and skippedLeft and dualErr == 'offhand_holster' and WeaponDefs.isHandgun(def) then
            Sync.notify(src, msg('offhand_holster'), 'error')
            return false, 'offhand_holster'
        end
        key = key or slots[1]
    end
    if isVirtual(key) then
        -- the extra sidearm: stored as equipped, shown on the body, never given to the ped (ammo stays in it)
        if used[key] then Weapons.holster(src, used[key].id) end
        r.equipped = key
        markDirty(r)
        refresh(r)
        publishExtra(src)
        InvHooks.emit('weaponEquipped', src, r)
        TriggerEvent('MULTIinventory:weaponEquipped', src, Weapons.toTable(r))
        if opts.draw then return Weapons.swapExtra(src) end
        return true
    end
    if used[key] then Weapons.holster(src, used[key].id) end
    -- another session still listing it (late report) loses it
    for osrc, s in pairs(sessions) do if osrc ~= src then s.onPed[r.id] = nil end end
    r.equipped = key
    local s = sess(src)
    s.onPed[r.id] = true
    -- ammo: the magazine stays in the weapon (<= clip size), the rest goes to the gunbelt.
    -- Everything the weapon carried enters the ped's ammo pool (deltas).
    local ammoType, clip = pickAmmo(r, def, belt)
    local deltas = {}
    for t, n in pairs(r.ammo) do
        deltas[t] = (deltas[t] or 0) + n
        local over = (t == ammoType) and (n - clip) or n
        if over > 0 then Ammo.adjust(st.charId, t, over) end
    end
    r.ammo = (ammoType and clip > 0) and { [ammoType] = clip } or {}
    markDirty(r)
    refresh(r)
    TriggerClientEvent('MULTIinventory:weapons:cl:equip', src, equipPayload(r, def, clip, ammoType, deltas, opts.draw))
    InvHooks.emit('weaponEquipped', src, r)
    TriggerEvent('MULTIinventory:weaponEquipped', src, Weapons.toTable(r))
    return true
end

---Take an equipped weapon off the ped; the client answers with a final report (ammo + condition).
function Weapons.holster(src, id)
    src = tonumber(src)
    local r = Weapons.ownedBy(src, id)
    if not r then return false, 'no_weapon' end
    if not r.equipped then return false, 'not_equipped' end
    if isVirtual(r.equipped) then
        -- the extra sidearm is not on the ped: no client holster / report, just the body prop goes
        r.equipped = nil
        markDirty(r)
        refresh(r)
        publishExtra(src)
        TriggerEvent('MULTIinventory:weaponHolstered', src, r.id)
        return true
    end
    r.equipped = nil
    markDirty(r)
    refresh(r)
    local s = sess(src)
    if s.held == r.id then s.held = nil end
    -- stays in onPed until the final report arrives
    TriggerClientEvent('MULTIinventory:weapons:cl:holster', src, r.id)
    TriggerEvent('MULTIinventory:weaponHolstered', src, r.id)
    return true
end

function Weapons.draw(src, id)
    local r = Weapons.ownedBy(src, id)
    if not r then return false, 'no_weapon' end
    if not r.equipped then return Weapons.equip(src, r.id, { draw = true }) end
    if isVirtual(r.equipped) then return Weapons.swapExtra(src) end   -- the extra sidearm: swap with the right hip
    TriggerClientEvent('MULTIinventory:weapons:cl:draw', src, r.id)
    return true
end

---Full loadout for the client (spawn / respawn / resource restart): gunbelt + equipped weapons.
function Weapons.sendLoadout(src)
    src = tonumber(src)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    if not Weapons.ensureLoaded() then return false, 'not_ready' end
    local belt = Ammo.get(st.charId)
    local s = sess(src)
    s.onPed = {}
    local list = {}
    local dualOk = Weapons.dualAllowed(st.charId)
    local eqd = Weapons.equipped(src)
    -- right hip before left hip: the client gives the main sidearm first, then the off-hand copy
    local ORDER = { right = 1, left = 2 }
    table.sort(eqd, function(a, b)
        local oa, ob = ORDER[a.equipped] or 0, ORDER[b.equipped] or 0
        if oa ~= ob then return oa < ob end
        return a.id < b.id
    end)
    -- [inv_sawnoff] a weapon saved in a slot its class no longer uses (sawed-off saved on 'back'
    -- before it became a sidearm) moves to its first free valid slot, else back to the grid
    local taken = {}
    for _, r in ipairs(eqd) do taken[r.equipped] = true end
    for _, r in ipairs(eqd) do
        local valid = WeaponDefs.equipSlotsFor(WeaponDefs.get(r.name))
        local okSlot = false
        for _, k in ipairs(valid) do if k == r.equipped then okSlot = true end end
        if not okSlot then
            taken[r.equipped] = nil
            local key
            for _, k in ipairs(valid) do
                if not taken[k] and not (k == 'left' and not dualOk) then key = k break end
            end
            r.equipped = key
            if key then taken[key] = true end
            markDirty(r); refresh(r)
        end
    end
    table.sort(eqd, function(a, b)
        local oa, ob = ORDER[a.equipped] or 0, ORDER[b.equipped] or 0
        if oa ~= ob then return oa < ob end
        return a.id < b.id
    end)
    for _, r in ipairs(eqd) do
        if not r.equipped then
            -- [inv_sawnoff] no valid free slot: already back in the grid above
        elseif r.equipped == 'left' and not dualOk then
            -- off-hand holster gone (item removed / dual wield turned off): back to the grid
            r.equipped = nil; markDirty(r); refresh(r)
        elseif isVirtual(r.equipped) then
            -- extra sidearm: stays equipped (shown on the body), never given to the ped
            if cfg().reequipOnSpawn == false then r.equipped = nil; markDirty(r); refresh(r) end
        elseif cfg().reequipOnSpawn ~= false then
            local def = WeaponDefs.get(r.name)
            local ammoType, clip = pickAmmo(r, def, belt)
            s.onPed[r.id] = true
            list[#list + 1] = equipPayload(r, def, clip, ammoType, nil, false)
        else
            r.equipped = nil; markDirty(r); refresh(r)
        end
    end
    -- offhand = may this character wear the off-hand holster at all (dualWield.requireItem owned);
    -- the client uses it to gate the cosmetic "always wear both holsters" choice too.
    -- leather = owns the off-hand holster leather item (offhandHolster.leatherItem); the left gun works either way
    TriggerClientEvent('MULTIinventory:weapons:cl:loadout', src, { belt = Util.deepcopy(belt), weapons = list, offhand = dualOk and true or false,
                                                                  leather = Weapons.hasLeather(st.charId) })
    publishExtra(src)
    return true
end

---Draw the extra (third) sidearm: it swaps with the right-hip gun. The right gun is holstered first and its
---final report (magazine) is awaited, then the extra gun is equipped on the right hip and drawn, and the old right
---gun becomes the extra one. Without a right-hip gun the extra one simply moves to the right hip.
local swapping = {}
function Weapons.swapExtra(src)
    src = tonumber(src)
    if not WeaponDefs.extraOn() then return false, 'extra_off' end
    if swapping[src] then return false, 'busy' end
    local extra, right
    for _, x in ipairs(Weapons.equipped(src)) do
        if isVirtual(x.equipped) then extra = x elseif x.equipped == 'right' then right = x end
    end
    if not extra then return false, 'no_extra' end
    swapping[src] = true
    local ok, a, b = pcall(function()
        local s = sess(src)
        extra.equipped = nil
        markDirty(extra)
        if right then
            Weapons.holster(src, right.id)
            -- wait for the right gun's final report (its magazine goes back into the record) - at most ~2 s
            for _ = 1, 40 do                                   -- 40 x 50 ms (counted, not clock based)
                if not s.onPed[right.id] then break end
                Wait(50)
            end
            s.onPed[right.id] = nil
        end
        local okEq, err = Weapons.equip(src, extra.id, { hand = 'right', draw = true })
        if not okEq then
            -- could not draw it: put both back where they were
            extra.equipped = 'extra'; markDirty(extra); refresh(extra)
            if right then Weapons.equip(src, right.id, { hand = 'right' }) end
            publishExtra(src)
            return false, err
        end
        if right and right.container == extra.container and not right.equipped then
            right.equipped = 'extra'
            markDirty(right)
            refresh(right)
        end
        publishExtra(src)
        return true
    end)
    swapping[src] = nil
    if not ok then print(('^1[MULTIinventory] extra sidearm swap failed: %s^7'):format(tostring(a))) return false, 'error' end
    return a, b
end

RegisterNetEvent('MULTIinventory:weapons:sv:swapExtra', function()
    local src = source
    local s = sess(src)
    local now = GetGameTimer()
    local cd = tonumber((cfg().extraSidearm or {}).cooldownMs) or 1500
    if now - (s.lastSwap or -1e9) < cd then return end
    s.lastSwap = now
    CreateThread(function() Weapons.swapExtra(src) end)
end)

-- ------------------------------------------------------------
-- client reports: ammo conservation + condition
--   data = { pools = { [AMMO_X] = pedAmmoByType }, weapons = { [id] = { clip, ammoType, dirt, soot,
--            degradation, damage } }, final = { [id] = true }, held = id|nil }
--   pools include the magazines of weapons still on the ped; a final (removed) weapon's magazine
--   is NOT in the pool any more (the client takes it out when it removes the weapon).
-- The server never accepts more rounds of a type than it handed out (gunbelt + magazines on the
-- ped); condition values can only go up (only cleaning lowers them).
-- ------------------------------------------------------------
function Weapons.handleReport(src, data)
    src = tonumber(src)
    local st = State.get(src)
    if not st or type(data) ~= 'table' then return false, 'bad_report' end
    local s = sess(src)
    local finals = type(data.final) == 'table' and data.final or {}
    local hasFinal = next(finals) ~= nil
    local t = GetGameTimer() / 1000
    if not hasFinal and t - (s.lastReport or -1e9) < 1.0 then return false, 'rate_limited' end
    s.lastReport = t
    local belt = Ammo.get(st.charId)
    local reported = {}   -- [id] = { r, def, type, clip, final }
    for k, w in pairs(type(data.weapons) == 'table' and data.weapons or {}) do
        local id = Util.toInt(tonumber(k))
        local r = id and W[id]
        if r and s.onPed[id] and type(w) == 'table' then
            local def = WeaponDefs.get(r.name)
            local at = type(w.ammoType) == 'string' and w.ammoType:upper() or nil
            if at and not WeaponDefs.usesAmmo(def, at) then at = nil end
            -- [thrown] a throwable's "clip" is the number left on the ped (conservation below caps it)
            local thrown = WeaponDefs.isThrown(def)
            local cv = tonumber(w.clip) or 0
            if cv ~= cv then cv = 0 end
            local clip = math.floor(Util.clamp(cv, 0, thrown and 1e6 or (def.clip or 0)))
            reported[id] = { r = r, def = def, type = at, clip = at and clip or 0, thrown = thrown, sent = at and clip or 0,
                             final = (finals[k] or finals[id] or finals[tostring(id)]) and true or false }
            if cfg().saveCondition then
                for _, ck in ipairs(COND) do
                    local v = tonumber(w[ck])
                    if v then r[ck] = math.max(r[ck] or 0, Util.clamp(v, 0, 1)) end
                end
            end
        end
    end
    local resync = false
    local seen = {}       -- ammo types settled by this report
    local pools = type(data.pools) == 'table' and data.pools or {}
    for tk, pv in pairs(pools) do
        local T = type(tk) == 'string' and tk:upper() or nil
        if T and AmmoDefs.isType(T) then
            seen[T] = true
            local pvn = tonumber(pv) or 0
            if pvn ~= pvn or pvn == math.huge or pvn == -math.huge then pvn = 0 end -- nan guard: inf turned the pool into NaN below
            local P = math.max(0, math.floor(pvn))
            -- what the server handed out for T: gunbelt + magazines of the weapons on the ped
            local oldTotal = belt[T] or 0
            for id in pairs(s.onPed) do local r = W[id]; if r then oldTotal = oldTotal + (r.ammo[T] or 0) end end
            local inPed, finalsN, onPedRep, finalRep = 0, 0, {}, {}
            for _, x in pairs(reported) do
                if x.type == T then
                    if x.final then finalsN = finalsN + x.clip; finalRep[#finalRep + 1] = x
                    else inPed = inPed + x.clip; onPedRep[#onPedRep + 1] = x end
                end
            end
            -- on-ped weapons that were not reported keep their magazine inside the pool
            for id in pairs(s.onPed) do
                local r = W[id]
                if r and not reported[id] then inPed = inPed + (r.ammo[T] or 0) end
            end
            local excess = P + finalsN - oldTotal
            if excess > 0 then
                resync = true
                local cut = math.min(excess, P); P = P - cut; excess = excess - cut
                for _, x in ipairs(finalRep) do
                    if excess <= 0 then break end
                    local c2 = math.min(excess, x.clip); x.clip = x.clip - c2; excess = excess - c2
                end
            end
            if inPed > P then
                resync = true
                local over = inPed - P
                for _, x in ipairs(onPedRep) do
                    if over <= 0 then break end
                    local c2 = math.min(over, x.clip); x.clip = x.clip - c2; over = over - c2; inPed = inPed - c2
                end
                if inPed > P then P = inPed end -- unreported magazines bigger than the pool: gunbelt 0
            end
            Ammo.setRaw(st.charId, T, P - inPed)
            for _, x in pairs(reported) do
                if x.type == T then x.r.ammo = x.clip > 0 and { [T] = x.clip } or {} end
            end
        end
    end
    local usedUp = {}
    for _, x in pairs(reported) do
        markDirty(x.r)
        refresh(x.r)
        if x.final then s.onPed[x.r.id] = nil end
        if x.thrown and x.type and seen[x.type] then
            local n = x.r.ammo[x.type] or 0
            if n <= 0 and next(x.r.ammo) == nil then
                -- [thrown] the last one was thrown: the stack is gone
                usedUp[#usedUp + 1] = x.r.id
            elseif not x.final and n ~= x.sent then
                -- [thrown] the ped claimed more than the stack holds: set the ped back to the real count
                TriggerClientEvent('MULTIinventory:weapons:cl:thrownCount', src, x.r.id, x.type, n + (belt[x.type] or 0))
            end
        end
    end
    for k in pairs(finals) do local id = Util.toInt(tonumber(k)); if id then s.onPed[id] = nil end end
    local held = Util.toInt(tonumber(data.held))
    s.held = (held and s.onPed[held]) and held or nil
    if resync then Ammo.pushBelt(st.charId) end
    for _, id in ipairs(usedUp) do
        if W[id] then Weapons.delete(id, { src = src, reason = 'thrown_used' }) end
    end
    return true, resync
end

RegisterNetEvent('MULTIinventory:weapons:sv:report', function(data)
    local src = source
    CreateThread(function()
        local ok, err = pcall(Weapons.handleReport, src, data)
        if not ok then print(('^1[MULTIinventory] weapon report from %s failed: %s^7'):format(tostring(src), tostring(err))) end
    end)
end)

-- ------------------------------------------------------------
-- cleaning / unload
-- ------------------------------------------------------------
local function wear(r) return (r.dirt or 0) + (r.soot or 0) + (r.degradation or 0) + (r.damage or 0) end

---Clean a weapon with one cleaning item. id nil = the weapon in hand, else the most worn equipped
---weapon, else the most worn weapon in the grid. stackId = the item stack used (usable callback).
function Weapons.clean(src, id, item, stackId)
    src = tonumber(src)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local pid = 'player:' .. st.charId
    local pc = Containers.peek(pid) or Inv.resolve(pid)
    if not pc then return false, 'player_not_loaded' end
    local r
    if id then
        r = Weapons.ownedBy(src, id)
    else
        local s = sessions[src]
        if s and s.held then r = Weapons.ownedBy(src, s.held) end
        if not r then
            for _, x in ipairs(Weapons.recordsIn(pid)) do
                if (not r) or (x.equipped and not r.equipped)
                    or ((x.equipped ~= nil) == (r.equipped ~= nil) and wear(x) > wear(r)) then r = x end
            end
        end
    end
    if not r then return false, 'no_weapon' end
    local items = (cfg().cleaning or {}).items or {}
    local stack
    if stackId then
        local sid = Util.toInt(tonumber(stackId))
        for _, e in pairs(pc.stacks) do if e.id == sid and e.kind ~= 'weapon' then stack = e break end end
    else
        local slots = {}
        for slot, e in pairs(pc.stacks) do
            if e.kind ~= 'weapon' and items[e.item] and (not item or e.item == item) then slots[#slots + 1] = slot end
        end
        table.sort(slots)
        stack = slots[1] and pc.stacks[slots[1]]
    end
    if not stack or not items[stack.item] then return false, 'no_cleaning_item' end
    local spec = items[stack.item]
    local ok, err = Inv.removeStack(pc, stack.id, 1, { src = src, reason = 'use' })
    if not ok then return false, err end
    if spec.dirt then r.dirt = math.min(r.dirt, spec.dirt) end
    if spec.soot then r.soot = math.min(r.soot, spec.soot) end
    r.degradation = math.max(0, r.degradation - (spec.degradationOff or 0))
    r.damage = math.max(0, r.damage - (spec.damageOff or 0))
    markDirty(r)
    refresh(r)
    TriggerClientEvent('MULTIinventory:weapons:cl:condition', src, r.id,
        { dirt = r.dirt, soot = r.soot, degradation = r.degradation, damage = r.damage }, true)
    InvLog.write('weapon_clean', { actorSrc = src, from = pid, item = stack.item, count = 1,
                                   data = { weaponId = r.id, serial = r.serial } })
    Sync.notify(src, msg('weapon_cleaned', Weapons.displayLabel(r)), 'success')
    return true, r.id
end

---Empty a holstered weapon's magazine into the gunbelt.
function Weapons.unload(src, id)
    local st = State.get(tonumber(src))
    if not st then return false, 'player_not_loaded' end
    local r = Weapons.ownedBy(src, id)
    if not r then return false, 'no_weapon' end
    if r.equipped then return false, 'weapon_equipped' end
    if WeaponDefs.isThrown(WeaponDefs.get(r.name)) then return false, 'thrown' end   -- [thrown] the count IS the item
    Ammo.get(st.charId)
    local deltas = {}
    for t, n in pairs(r.ammo) do Ammo.adjust(st.charId, t, n); deltas[t] = n end
    r.ammo = {}
    markDirty(r)
    refresh(r)
    Ammo.push(st.charId, deltas)
    return true, deltas
end

-- ------------------------------------------------------------
-- restore from the audit log (admin)
-- ------------------------------------------------------------
local function lookupSnapshot(id)
    InvLog.flush()
    local rows = InvDB.query('SELECT * FROM `multiinv_log` WHERE `action` = ? AND `container_to` = ? ORDER BY `id` DESC LIMIT 1',
        { 'weapon_delete', 'weapon:' .. tostring(id) })
    local d = rows[1] and Util.jsonDecode(rows[1].data, {}) or {}
    local s = d.stacks and d.stacks[1]
    return s and s.weapon or nil
end

---Re-create the weapons recorded in a log row (weapon_delete, drop_expired, admin_clear, death_clear...).
---Ids and serials are kept when still free. target nil = the row's source container (an expired
---drop pile falls back to its owner's grid).
function Weapons.restore(actor, logId, target)
    if not Weapons.ensureLoaded() then return false, 'not_ready' end
    local rows = InvLog.recent({ id = tonumber(logId) }, 1)
    local row = rows[1]
    if not row then return false, 'no_log_row' end
    local data = Util.jsonDecode(row.data, {}) or {}
    local list = data.stacks or data.removed or {}
    local tid
    if target ~= nil then tid = Admin.targetId(target) else tid = row.container_from end
    if tid and Containers.kindOf(tid) == 'drop' and not Drops.get(tonumber(tid:match('(%d+)$'))) then
        local owner = tonumber(data.ownerCharId) or tonumber(row.target_charid)
        tid = owner and ('player:' .. owner) or nil
    end
    if tid == Weapons.DETACHED then tid = nil end
    if not tid then return false, 'need_target' end
    local done, failed = 0, {}
    for _, s in ipairs(list) do
        if type(s) == 'table' and s.kind == 'weapon' then
            local wid = Util.toInt(tonumber(s.weaponId))
            if wid and W[wid] then
                failed[#failed + 1] = ('weapon %d still exists in %s'):format(wid, W[wid].container)
            else
                local snap = s.weapon or (wid and lookupSnapshot(wid))
                if not snap then
                    failed[#failed + 1] = ('weapon %s: no snapshot in the log'):format(tostring(wid))
                else
                    local ok, res = Weapons.create(tid, snap.name, {
                        id = snap.id, serial = snap.serial, serialFallback = true, customLabel = snap.customLabel,
                        customDesc = snap.customDesc, ammo = snap.ammo, components = snap.components, comps = snap.comps,
                        metadata = snap.metadata,
                        condition = { dirt = snap.dirt, soot = snap.soot, degradation = snap.degradation, damage = snap.damage },
                    }, { src = actor, reason = 'admin', ignoreWeaponLimit = true })
                    if ok then done = done + 1 else failed[#failed + 1] = ('weapon %s: %s'):format(tostring(wid), tostring(res)) end
                end
            end
        end
    end
    InvLog.write('admin_weapon_restore', { actorSrc = actor, to = tid, targetCharId = tonumber(tostring(tid):match('^player:(%d+)$')),
                                           data = { logId = tonumber(logId), restored = done, failed = failed } })
    return done > 0, { restored = done, failed = failed }
end

-- ------------------------------------------------------------
-- core hooks
-- ------------------------------------------------------------
InvHooks.register('containerLoaded', function(c)
    if c.kind == 'equip' then return end
    if Weapons.ensureLoaded() then placeLoaded(c) end
end)

InvHooks.register('occupantMoved', function(fromC, toC, entry)
    if entry.kind ~= 'weapon' then return end
    local r = W[entry.weaponId]
    if not r then return end
    relocate(r, toC.id, entry.slot)
    if toC.kind == 'player' then r.owner = toC.ownerCharId end
    if fromC ~= toC and r.equipped then
        forceOffPed(r, srcOwning(fromC))
        refresh(r)
    end
    markDirty(r)
end)

InvHooks.register('occupantRemoved', function(c, entry, ctx)
    if entry.kind ~= 'weapon' then return end
    local r = W[entry.weaponId]
    if not r then return end
    if r.equipped then forceOffPed(r, srcOwning(c)) end
    dropRecord(r, ctx or { reason = 'clear' })
end)

InvHooks.register('canAdd', function(c, item, count, _, ctx)
    if c.kind ~= 'player' or not Util.isWeaponName(item) then return true end
    if ctx and ctx.ignoreWeaponLimit then return true end
    if not WeaponDefs.counts(WeaponDefs.get(item)) then return true end
    if Weapons.countCarried(c) + (count or 1) > Weapons.maxFor(c.ownerCharId) then
        local src = srcOwning(c)
        if src then Sync.notify(src, msg('weapon_limit'), 'error') end
        return false, 'weapon_limit'
    end
    return true
end)

local PLAYER_MOVES = { move = true, give = true, drop = true, sort = true }
InvHooks.register('canRemove', function(c, entry, _, ctx)
    if entry.kind ~= 'weapon' or c.kind ~= 'player' then return true end
    local r = W[entry.weaponId]
    if not (r and r.equipped and ctx and ctx.src and PLAYER_MOVES[ctx.reason]) then return true end
    local st = State.get(ctx.src)
    if st and c.id == 'player:' .. st.charId then
        Sync.notify(ctx.src, msg('weapon_equipped'), 'error')
        return false, 'weapon_equipped'
    end
    return true
end)

InvHooks.register('hotbarWeapon', function(src, weaponId)
    CreateThread(function() Weapons.draw(src, weaponId) end)
end)

InvHooks.register('characterLoaded', function(src, charId)
    sessions[src] = nil
    Ammo.get(charId)
    Weapons.sendLoadout(src)
end)

InvHooks.register('characterUnloaded', function(src, charId)
    sessions[src] = nil
    Ammo.markOffline(charId)
end)

InvHooks.register('openPayload', function(src, payload)
    local st = State.get(src)
    if st then payload.gunbelt = Ammo.view(st.charId) end
end)

AddEventHandler('playerDropped', function() sessions[source] = nil end)

-- ------------------------------------------------------------
-- NUI / client actions (Actions.run: rate-limited, player must be loaded)
-- ------------------------------------------------------------
local function refOf(src, d)
    if d.weaponId then return Util.toInt(tonumber(d.weaponId)) end
    local st = State.get(src)
    local c = st and Containers.peek('player:' .. st.charId)
    local e = c and c.stacks[Util.toInt(tonumber(d.slot)) or -1]
    return e and e.kind == 'weapon' and e.weaponId or nil
end

Actions.register('weaponEquip', function(src, d)
    local id = refOf(src, d)
    if not id then return false, 'no_weapon' end
    return Weapons.equip(src, id, { hand = d.hand, draw = d.draw == true })
end)
Actions.register('weaponUnequip', function(src, d)
    local id = refOf(src, d)
    if not id then return false, 'no_weapon' end
    return Weapons.holster(src, id)
end)
Actions.register('weaponDraw', function(src, d)
    local id = refOf(src, d)
    if not id then return false, 'no_weapon' end
    return Weapons.draw(src, id)
end)
Actions.register('weaponClean', function(src, d)
    local ok, err = Weapons.clean(src, refOf(src, d), d.item)
    if not ok and (err == 'no_cleaning_item' or err == 'no_weapon') then Sync.notify(src, msg(err), 'error') end
    return ok, err
end)
Actions.register('weaponUnload', function(src, d)
    local id = refOf(src, d)
    if not id then return false, 'no_weapon' end
    return Weapons.unload(src, id)
end)
Actions.register('weaponRename', function(src, d)
    if not cfg().allowRename then return false, 'denied' end
    local id = refOf(src, d)
    if not id or not Weapons.ownedBy(src, id) then return false, 'no_weapon' end
    return Weapons.setCustomLabel(id, d.label)
end)
Actions.register('weaponInspect', function(src, d)
    local id = refOf(src, d)
    local r = id and Weapons.ownedBy(src, id)
    if not r then return false, 'no_weapon' end
    return true, Weapons.toTable(r)
end)
Actions.register('weaponLoadout', function(src) return Weapons.sendLoadout(src) end)
Actions.register('ammoBelt', function(src)
    local st = State.get(src)
    return true, Ammo.view(st.charId)
end)

-- ------------------------------------------------------------
-- admin commands (ace Config.Admin.ace or console)
-- ------------------------------------------------------------
local function allowed(src) return src == 0 or IsPlayerAceAllowed(src, Config.Admin.ace) end
local function reply(src, text) if src == 0 then print('[MULTIinventory] ' .. text) else Sync.notify(src, text, 'inform') end end

local function adminCmd(key, fn)
    local name = (cfg().adminCommands or {})[key]
    if not name then return end
    RegisterCommand(name, function(src, args)
        if not allowed(src) then reply(src, 'No permission.') return end
        CreateThread(function()
            local ok, err = pcall(fn, src, args)
            if not ok then reply(src, 'Error: ' .. tostring(err)) end
        end)
    end, false)
end

adminCmd('give', function(src, a)
    local tid = Admin.targetId(a[1])
    if not tid or not a[2] then reply(src, 'usage: <target> <WEAPON_NAME> [serial]') return end
    local ok, res = Weapons.create(tid, a[2], { serial = a[3] }, { src = src, reason = 'admin', ignoreWeaponLimit = true })
    if ok then
        InvLog.write('admin_weapon_give', { actorSrc = src, to = tid, item = res.name, count = 1, targetCharId = res.owner,
                                            data = { weaponId = res.id, serial = res.serial } })
        reply(src, ('gave %s #%d (%s) to %s'):format(res.name, res.id, res.serial, tid))
    else reply(src, 'give weapon failed: ' .. tostring(res)) end
end)

adminCmd('restore', function(src, a)
    local ok, res = Weapons.restore(src, a[1], a[2])
    if ok then reply(src, ('restored %d weapon(s); failed: %d %s'):format(res.restored, #res.failed, table.concat(res.failed, '; ')))
    else reply(src, 'restore failed: ' .. tostring(type(res) == 'table' and table.concat(res.failed, '; ') or res)) end
end)

adminCmd('ammo', function(src, a)
    local tid, cid = Admin.targetId(a[1])
    local n = Util.toInt(tonumber(a[3]))
    if not cid or not a[2] or not n then reply(src, 'usage: <target> <AMMO_TYPE> <count>') return end
    local ok, res = Ammo.set(cid, a[2], n, { ignoreMax = true })
    if ok then
        InvLog.write('admin_ammo', { actorSrc = src, to = tid, item = tostring(a[2]):upper(), count = n, targetCharId = cid })
        reply(src, ('gunbelt %s of %s = %d'):format(tostring(a[2]):upper(), tid, n))
    else reply(src, 'ammo failed: ' .. tostring(res)) end
end)

-- ------------------------------------------------------------
-- native exports (exports.MULTIinventory:<Name>) - wait for ready, may yield
-- ------------------------------------------------------------
local function ready() InvDB.awaitReady(); Weapons.ensureLoaded() end
local function xctx(reason) return { reason = reason or 'api', resource = GetInvokingResource() } end
local WAPI = {}

function WAPI.GiveWeapon(target, name, opts)
    ready()
    opts = opts or {}
    local ctx = xctx('api')
    ctx.ignoreWeaponLimit = opts.ignoreLimit == true
    local ok, r = Weapons.create(target, name, opts, ctx)
    if not ok then return false, r end
    return true, r.id
end
function WAPI.GetWeapon(id)                 ready() return Weapons.toTable(Weapons.get(id)) end
function WAPI.GetWeaponBySerial(serial)     ready() return Weapons.toTable(Weapons.bySerial(serial)) end
function WAPI.GetWeapons(target)            ready() return Weapons.list(target) end
function WAPI.GetEquipped(src)
    ready()
    local out = {}
    for _, r in ipairs(Weapons.equipped(src)) do out[#out + 1] = Weapons.toTable(r) end
    return out
end
function WAPI.RemoveWeapon(id, keepRow)     ready() if keepRow then return Weapons.detach(id, xctx('api')) end return Weapons.delete(id, xctx('api')) end
function WAPI.MoveWeapon(id, target, slot)  ready() return Weapons.moveTo(id, target, xctx('move'), slot) end
function WAPI.SetWeaponLabel(id, text)      ready() return Weapons.setCustomLabel(id, text) end
function WAPI.SetWeaponDesc(id, text)       ready() return Weapons.setCustomDesc(id, text) end
function WAPI.SetWeaponSerial(id, serial)   ready() return Weapons.setSerial(id, serial) end
function WAPI.GetWeaponComponents(id)       ready() return Weapons.getComponents(id) end
function WAPI.AddWeaponComponents(id, t)    ready() return Weapons.addComponents(id, t) end
function WAPI.RemoveWeaponComponents(id, t) ready() return Weapons.subComponents(id, t) end
function WAPI.CanCarryWeapons(target, amount, name) ready() return Weapons.canCarry(target, amount, name) end
function WAPI.EquipWeapon(src, id, opts)    ready() return Weapons.equip(tonumber(src), id, opts) end
function WAPI.HolsterWeapon(src, id)        ready() return Weapons.holster(tonumber(src), id) end
function WAPI.CleanWeapon(src, id)          ready() return Weapons.clean(tonumber(src), id) end
function WAPI.GetAmmo(target)               ready() local cid = Ammo.charOf(target) return cid and Util.deepcopy(Ammo.get(cid)) or {} end
function WAPI.AddAmmo(target, ammoType, n)  ready() local cid = Ammo.charOf(target) if not cid then return false, 'player_not_loaded' end return Ammo.add(cid, ammoType, n) end
function WAPI.RemoveAmmo(target, ammoType, n) ready() local cid = Ammo.charOf(target) if not cid then return false, 'player_not_loaded' end return Ammo.remove(cid, ammoType, n) end
function WAPI.ClearAmmo(target)             ready() local cid = Ammo.charOf(target) if not cid then return false, 'player_not_loaded' end return Ammo.clear(cid, xctx('api')) end
function WAPI.RestoreWeapons(logId, target) ready() return Weapons.restore(0, logId, target) end

for name, fn in pairs(WAPI) do exports(name, fn) end
WeaponsAPI = WAPI

-- tests only
function Weapons._reset()
    W, bySerial, byContainer, dirty, deleted = {}, {}, {}, {}, {}
    loaded, loadTriedAt, loadingP, nextId, blockEnd = false, nil, nil, nil, nil
    for k in pairs(sessions) do sessions[k] = nil end
end

-- [escrow] Weapon list for other resources (RINGOshopcreator etc.) so they don't
-- have to read this resource's Lua files - those are encrypted under Cfx escrow.
-- Returns { [WEAPON_NAME] = { label, weight, group } }.
exports('GetWeaponList', function()
    local out = {}
    if WeaponDefs and WeaponDefs.all then
        for name, d in pairs(WeaponDefs.all()) do
            out[name] = { label = d.label or name, weight = d.weight, group = d.group }
        end
    end
    return out
end)
