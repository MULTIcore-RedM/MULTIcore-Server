-- ============================================================
-- MULTIinventory :: server/multi/migrate.lua
--
-- One-time import from the old MULTIinventory (Config.MigrateOld, on by default).
-- Runs at start-up inside MultiInv.beforeReady (server/core/boot.lua): after the schema,
-- the item registry and the weapon cache are ready and BEFORE IsReady() turns true, so no
-- player is attached and no script reads an inventory while it runs.
--
-- Old storage (read only - never changed or deleted, so the import can run again):
--   players.inventory          satchel of the character (RSG's saved list
--                              [ { name, amount, info, type, slot }, ... ])
--   inventories(identifier, items)
--                              stashes, trunks, gloveboxes and custom inventories; the key
--                              is the inventory id with a leading 'stash:' removed
--                              ('stash:foo' was saved as 'foo', 'trunk:ABC' as 'trunk:ABC')
-- New ids:
--   players.inventory of players.id N      -> 'player:N'
--   identifier with a stash / trunk / glovebox / custom / player prefix -> kept as it is
--   any other identifier 'foo'             -> 'stash:foo'
-- Items keep slot (when free), amount and info (as metadata; info.quality of a decaying
-- item becomes its expiry time). Items the registry does not know (yet) are kept as they
-- are - the engine shows stored unknown items and scripts may register them later.
-- Weapons (weapon_*) become weapon rows: serial (info.serie), components, comps,
-- custom label / description, condition (info.quality) and loaded rounds (info.ammo,
-- info.ammoType). A weapon whose serial already exists here is not made twice.
-- Throwables (knives, dynamite, ...) become one throwable stack with the old count.
-- Loose rounds (ammo_revolver, ...) and ammo boxes (ammo_box_*) stay items; using them
-- puts them on the gunbelt.
--
-- Done marker: a row in multiinv_migration with step 'old_multiinventory' and status 'done'.
-- Delete that row to import again; an inventory that already holds items here is skipped.
-- ============================================================

MultiInv = MultiInv or {}
local M = MultiInv
local Migrate = {}
M.Migrate = Migrate

local STEP = 'old_multiinventory'
local SELFTEST = GetConvar('multicore_selftest', 'false') == 'true'
local STASH_SLOTS, STASH_GRAMS = 100, 2000000      -- same defaults as Create() in api.lua
local PAGE, SETTLE = 200, 50
local STASH_TYPES = { stash = true, glovebox = true, trunk = true, custom = true }
-- weapon info fields that become weapon columns (everything else stays in the weapon's metadata)
local WEAPON_KEYS = { serie = true, serial = true, ammo = true, ammoType = true, components = true, comps = true,
                      quality = true, id = true, custom_label = true, custom_desc = true, used = true, used2 = true,
                      equipped = true }

local running = false

local function log(fmt, ...) print(('[MULTIinventory] ' .. fmt):format(...)) end

local function nonEmpty(v)
    if v == nil then return nil end
    v = tostring(v)
    return v ~= '' and v or nil
end

---Inventory id for an old `inventories.identifier` (the old engine's rule, reversed).
function Migrate.idFromDbKey(key)
    key = nonEmpty(key)
    if not key then return nil end
    local t = key:match('^(%a+):')
    if t and (STASH_TYPES[t] or t == 'player') then return key end
    return 'stash:' .. key
end

local function tableExists(name)
    return (tonumber(InvDB.scalar('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { name })) or 0) > 0
end

local function columnExists(tbl, col)
    return (tonumber(InvDB.scalar('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?', { tbl, col })) or 0) > 0
end

function Migrate.isDone()
    return (tonumber(InvDB.scalar("SELECT COUNT(*) FROM `multiinv_migration` WHERE `step` = ? AND `status` = 'done'", { STEP })) or 0) > 0
end

---Old saved list (JSON array or slot map) -> { { name, amount, info, slot }, ... } in slot order.
local function decodeList(raw)
    local list = Util.jsonDecode(raw, nil)
    if type(list) ~= 'table' then return {} end
    local out = {}
    for k, s in pairs(list) do
        if type(s) == 'table' and type(s.name) == 'string' and s.name ~= '' then
            local amount = math.floor(tonumber(s.amount or s.count) or 1)
            local info = type(s.info) == 'table' and s.info or (type(s.metadata) == 'table' and s.metadata) or {}
            out[#out + 1] = { name = s.name, amount = amount, info = info, slot = Util.toInt(s.slot) or Util.toInt(k) }
        end
    end
    table.sort(out, function(a, b)
        local x, y = a.slot or math.huge, b.slot or math.huge
        if x ~= y then return x < y end
        return a.name < b.name
    end)
    return out
end

---The old slot when it is free, else the first free one; a full container grows by one slot.
local function pickSlot(c, want)
    if want and want >= 1 and want <= c.slots and not c.stacks[want] then return want end
    local s = Containers.freeSlot(c)
    if s then return s end
    c.slots = c.slots + 1
    if c.kind ~= 'player' then
        c.defDirty = true
        Persistence.markDirty(c)
    end
    return c.slots
end

local function hasItemsHere(id)
    local c = Containers.peek(id)
    if c and next(c.stacks) ~= nil then return true end
    if #Weapons.recordsIn(id) > 0 then return true end
    return (tonumber(InvDB.scalar('SELECT COUNT(*) FROM `multiinv_stacks` WHERE `container_id` = ?', { id })) or 0) > 0
end

local function putItem(c, s, sum, batch)
    local name, def = s.name, Registry.get(s.name)
    if not def and Registry.get(s.name:lower()) then name = s.name:lower(); def = Registry.get(name) end
    if not def then
        sum.unknown = sum.unknown + 1
        sum.unknownNames[name] = true
    end
    local meta = Util.deepcopy(s.info)
    local decayAt
    local full = def and Stacking.decayFor(def)
    if full then
        local now, q = Util.now(), tonumber(meta.quality)
        decayAt = q and (now + math.floor((full - now) * Util.clamp(q, 0, 100) / 100)) or full
        meta.quality, meta.lastUpdate = nil, nil
    end
    local e = Containers.newStack(name, s.amount, meta, nil, decayAt)
    e.batch = batch
    Containers.place(c, pickSlot(c, s.slot), e)
    sum.stacks = sum.stacks + 1
end

local function loadedAmmo(info, def)
    local a = info.ammo
    if type(a) == 'table' then return a end
    local n = math.floor(tonumber(a) or 0)
    if n < 1 then return nil end
    local t = nonEmpty(info.ammoType)
    if t then return { [t:upper()] = n } end
    return n
end

local function putWeapon(c, s, sum, ctx, made)
    local def = WeaponDefs.get(s.name)
    if not def then
        sum.skipped = sum.skipped + 1
        log('^3import: %s in %s skipped (not a weapon this server knows)^7', s.name, c.id)
        return
    end
    local info = s.info
    if WeaponDefs.isThrown(def) then
        local n = math.max(1, s.amount)
        if tonumber(info.ammo) and tonumber(info.ammo) > n then n = math.floor(tonumber(info.ammo)) end
        local ok, r = Weapons.create(c, def.name, { ammo = n, slot = pickSlot(c, s.slot), ignoreWeight = true }, ctx)
        if ok then
            sum.weapons = sum.weapons + 1
            if type(r) == 'table' and r.id then made[#made + 1] = r.id end
        else
            sum.skipped = sum.skipped + 1
            log('^3import: %s x%d in %s skipped (%s)^7', s.name, n, c.id, tostring(r))
        end
        return
    end
    local metadata = {}
    for k, v in pairs(info) do if not WEAPON_KEYS[k] then metadata[k] = v end end
    local q = tonumber(info.quality)
    local condition = q and { degradation = 1 - Util.clamp(q, 0, 100) / 100 } or nil
    for i = 1, math.max(1, s.amount) do
        local serial = i == 1 and nonEmpty(info.serie or info.serial) or nil
        if serial and Weapons.bySerial(serial:sub(1, 50)) then
            sum.weaponsKnown = sum.weaponsKnown + 1
        else
            local opts = {
                serial = serial, serialFallback = true,
                id = i == 1 and Util.toInt(info.id) or nil,
                ammo = loadedAmmo(info, def),
                components = type(info.components) == 'table' and info.components or nil,
                comps = type(info.comps) == 'table' and info.comps or nil,
                customLabel = nonEmpty(info.custom_label), customDesc = nonEmpty(info.custom_desc),
                metadata = metadata, condition = condition,
                slot = pickSlot(c, i == 1 and s.slot or nil), ignoreWeight = true,
            }
            local ok, r = Weapons.create(c, def.name, opts, ctx)
            if ok then
                sum.weapons = sum.weapons + 1
                if type(r) == 'table' and r.id then made[#made + 1] = r.id end
            else
                sum.skipped = sum.skipped + 1
                log('^3import: %s (%s) in %s skipped (%s)^7', s.name, tostring(serial), c.id, tostring(r))
            end
        end
    end
end

---Fills container c from an old list. -> number of entries placed
local function fill(c, list, sum, batch, ctx, made)
    local before = sum.stacks + sum.weapons
    for _, s in ipairs(list) do
        if s.amount < 1 then
            sum.skipped = sum.skipped + 1
        elseif Util.isWeaponName(s.name) then
            putWeapon(c, s, sum, ctx, made)
        else
            putItem(c, s, sum, batch)
        end
    end
    return sum.stacks + sum.weapons - before
end

local function listToSet(t)
    if type(t) ~= 'table' then return nil end
    local set = {}
    for _, v in pairs(t) do set[tostring(v)] = true end
    return set
end

---Runs the import. opts.force = ignore the done marker; opts.citizenids / opts.identifiers =
---only these (lists). -> summary | nil, reason
function Migrate.run(opts)
    opts = opts or {}
    if running then return nil, 'running' end
    if not opts.force and Migrate.isDone() then return nil, 'done' end
    if not Weapons.ensureLoaded() then
        log('^1import from the old inventory postponed: weapons table not readable^7')
        return nil, 'weapons_not_loaded'
    end
    running = true
    local okRun, res, why = pcall(function()
        local sum = { players = 0, stashes = 0, stacks = 0, weapons = 0, weaponsKnown = 0, skipped = 0,
                      unknown = 0, unknownNames = {}, present = 0, sources = 0 }
        local started = Util.now()
        local batch
        local okB, b = pcall(MySQL.insert.await, 'INSERT INTO `multiinv_migration` (`step`, `status`, `started_at`) VALUES (?, ?, ?)',
            { STEP, 'running', started })
        batch = okB and tonumber(b) or nil
        local ctx = { reason = 'migrate', actor = 'migration', ignoreWeaponLimit = true }
        local made, touched = {}, {}
        local onlyCids, onlyIds = listToSet(opts.citizenids), listToSet(opts.identifiers)

        local function settle(force)
            if #touched == 0 or (#touched < SETTLE and not force) then return end
            Persistence.flush()
            for _, t in ipairs(touched) do
                if not t.wasLoaded then Containers.unload(t.id) end
            end
            touched = {}
        end

        -- satchels
        if tableExists('players') and columnExists('players', 'inventory') and (not opts.identifiers or opts.citizenids) then
            local last = 0
            while true do
                local rows = InvDB.query("SELECT `id`, `citizenid`, `inventory` FROM `players` WHERE `id` > ? AND `inventory` IS NOT NULL AND `inventory` NOT IN ('', '[]', '{}', 'null') ORDER BY `id` LIMIT " .. PAGE, { last })
                if #rows == 0 then break end
                for _, row in ipairs(rows) do
                    last = tonumber(row.id) or last
                    if not onlyCids or onlyCids[tostring(row.citizenid)] then
                        local list = decodeList(row.inventory)
                        if #list > 0 then
                            sum.sources = sum.sources + 1
                            local id = 'player:' .. math.tointeger(tonumber(row.id))
                            if hasItemsHere(id) then
                                sum.present = sum.present + 1
                            else
                                local wasLoaded = Containers.isLoaded(id)
                                local c = Inv.resolve(id)
                                if c then
                                    if fill(c, list, sum, batch, ctx, made) > 0 then sum.players = sum.players + 1 end
                                    touched[#touched + 1] = { id = id, wasLoaded = wasLoaded }
                                    settle(false)
                                else
                                    sum.skipped = sum.skipped + #list
                                end
                            end
                        end
                    end
                end
                if #rows < PAGE then break end
            end
        end

        -- stashes, trunks, gloveboxes, custom inventories
        if tableExists('inventories') and (not opts.citizenids or opts.identifiers) then
            local last = ''
            while true do
                local rows = InvDB.query('SELECT `identifier`, `items` FROM `inventories` WHERE `identifier` > ? ORDER BY `identifier` LIMIT ' .. PAGE, { last })
                if #rows == 0 then break end
                for _, row in ipairs(rows) do
                    last = row.identifier
                    local id = Migrate.idFromDbKey(row.identifier)
                    if id and (not onlyIds or onlyIds[tostring(row.identifier)]) then
                        local list = decodeList(row.items)
                        if #list > 0 then
                            sum.sources = sum.sources + 1
                            if id:match('^player:') or #id > 100 then
                                sum.skipped = sum.skipped + #list
                                log('^3import: inventory %s skipped (id not usable here)^7', id)
                            elseif hasItemsHere(id) then
                                sum.present = sum.present + 1
                            else
                                local wasLoaded = Containers.isLoaded(id)
                                local c = Containers.get(id)
                                if not c and not Containers.isDefined(id) then
                                    local top = 0
                                    for _, s in ipairs(list) do if (s.slot or 0) > top then top = s.slot end end
                                    Containers.define(id, {
                                        kind = 'stash', label = (id:gsub('^%a+:', '')),
                                        slots = math.max(STASH_SLOTS, math.min(top, 1000)),
                                        maxWeight = RsgInv.toKg(STASH_GRAMS), flags = { acceptWeapons = true },
                                    })
                                end
                                c = c or Containers.get(id, { create = true })
                                if c then
                                    if fill(c, list, sum, batch, ctx, made) > 0 then sum.stashes = sum.stashes + 1 end
                                    touched[#touched + 1] = { id = id, wasLoaded = wasLoaded }
                                    settle(false)
                                else
                                    sum.skipped = sum.skipped + #list
                                end
                            end
                        end
                    end
                end
                if #rows < PAGE then break end
            end
        end

        settle(true)
        Persistence.flush()
        if batch then
            for i = 1, #made, 500 do
                local ids = {}
                for j = i, math.min(i + 499, #made) do ids[#ids + 1] = math.tointeger(made[j]) end
                InvDB.update(('UPDATE `multiinv_weapons` SET `migration_batch` = ? WHERE `id` IN (%s)'):format(table.concat(ids, ',')), { batch })
            end
        end

        local names = {}
        for n in pairs(sum.unknownNames) do names[#names + 1] = n end
        table.sort(names)
        sum.unknownNames = names
        local report = Util.jsonEncode(sum)
        if batch then
            InvDB.update("UPDATE `multiinv_migration` SET `status` = 'done', `source_rows` = ?, `target_rows` = ?, `report` = ?, `finished_at` = ? WHERE `batch` = ?",
                { sum.sources, sum.stacks + sum.weapons, report, Util.now(), batch })
        else
            InvDB.update("INSERT INTO `multiinv_migration` (`step`, `status`, `source_rows`, `target_rows`, `report`, `started_at`, `finished_at`) VALUES (?, 'done', ?, ?, ?, ?, ?)",
                { STEP, sum.sources, sum.stacks + sum.weapons, report, started, Util.now() })
        end
        sum.batch = batch
        return sum
    end)
    running = false
    if not okRun then
        log('^1import from the old inventory failed: %s - it runs again on the next start^7', tostring(res))
        return nil, 'error'
    end
    return res, why
end

local function summary(sum)
    local s = ('old inventory moved: %d satchels, %d stashes, %d items, %d weapons'):format(sum.players, sum.stashes, sum.stacks, sum.weapons)
    if sum.present > 0 then s = s .. (', %d already here'):format(sum.present) end
    if sum.weaponsKnown > 0 then s = s .. (', %d weapons already here'):format(sum.weaponsKnown) end
    s = s .. (', %d skipped'):format(sum.skipped)
    if sum.unknown > 0 then
        s = s .. (', %d unknown items kept (%s)'):format(sum.unknown, table.concat(sum.unknownNames, ' ', 1, math.min(#sum.unknownNames, 10)))
    end
    return s
end
Migrate.summary = summary

---Start-up run (Config.MigrateOld, once per database).
function Migrate.auto()
    if Config.MigrateOld == false then return end
    if Migrate.isDone() then return end
    local sum, why = Migrate.run()
    if sum then log(summary(sum)) elseif why ~= 'done' then log('^3import from the old inventory not finished (%s)^7', tostring(why)) end
end

-- runs inside boot.lua's start-up, after the hooks api.lua set
local before = M.beforeReady
function M.beforeReady()
    if before then
        local ok, err = pcall(before)
        if not ok then print('^1[MULTIinventory] start-up: ' .. tostring(err) .. '^7') end
    end
    Migrate.auto()
end

-- ---------------- test hook (setr multicore_selftest true only) ----------------
if SELFTEST then
    ---_TestMigrate({ force, citizenids = {..}, identifiers = {..} }) -> summary | { status = reason }
    exports('_TestMigrate', function(opts)
        if not SELFTEST then return { status = 'disabled' } end
        InvDB.awaitReady()
        local sum, why = Migrate.run(type(opts) == 'table' and opts or {})
        if not sum then return { status = why } end
        log('test: ' .. summary(sum))
        return sum
    end)
end
