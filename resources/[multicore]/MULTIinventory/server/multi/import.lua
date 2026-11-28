-- ============================================================
-- MULTIinventory :: server/multi/import.lua
--
-- Server exports for the switch-over import (MULTIcore's  mcimport vorp | rsg ).
-- MULTIcore reads the old framework's tables and hands the items here in one plain shape;
-- they are placed with the same rules as the old-inventory import (server/multi/migrate.lua):
-- slot kept when free, metadata kept, weapons become weapon rows (serial, components,
-- custom label), unknown items kept by name.
--
--   ImportInventory(id, list, opts) -> { status, stacks, weapons, weaponsKnown, skipped,
--                                         unknownNames = {..}, renamed = { [old] = new } }
--       id   = 'player:<charId>' or any storage id ('custom:horse_ABC123', 'trunk:K7RW2M' ...)
--       list = { { name, amount, info = {..}, slot? }, ... }
--       opts = { label?, slots?, merge? }   merge = add even when the inventory already holds items
--       status: 'done' | 'present' (already holds items, nothing added) | an error word
--   ImportAmmo(charId, { [AMMO_TYPE] = count }) -> { added = {..}, unknown = {..} }
--   ImportTarget(inventoryType, charId, shared) -> the storage id a framework's custom
--       inventory has here (a registered per-character inventory gets its character instance)
--   ImportResolve(name) -> name this server uses, known (bool), weapon (bool)
--   ImportHasItems(id) -> bool
--   ImportStashId(oldKey) -> storage id for an rsg-inventory `inventories.identifier`
-- Nothing here runs unless called; old tables are never read or changed by this file.
-- ============================================================

MultiInv = MultiInv or {}
local M = MultiInv

local function ready()
    InvDB.awaitReady()
    return M.Migrate ~= nil and Weapons.ensureLoaded()
end

local function toList(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

local function cleanList(list, renamed)
    local out = {}
    for _, s in ipairs(type(list) == 'table' and list or {}) do
        if type(s) == 'table' and type(s.name) == 'string' and s.name ~= '' then
            local name = s.name
            if not Util.isWeaponName(name) then
                local r = Registry.resolve(name)
                if r ~= name then renamed[name] = r; name = r end
            end
            out[#out + 1] = {
                name = name,
                amount = math.floor(tonumber(s.amount or s.count) or 1),
                info = type(s.info) == 'table' and s.info or {},
                slot = Util.toInt(s.slot),
            }
        end
    end
    return out
end

local function importInventory(id, list, opts)
    opts = type(opts) == 'table' and opts or {}
    if type(id) ~= 'string' or id == '' or #id > 100 then return { status = 'bad_id' } end
    if not ready() then return { status = 'not_ready' } end
    local Migrate = M.Migrate
    local renamed = {}
    local items = cleanList(list, renamed)
    if #items == 0 then return { status = 'done', stacks = 0, weapons = 0, weaponsKnown = 0, skipped = 0, unknownNames = {}, renamed = renamed } end
    if not opts.merge and Migrate.hasItemsHere(id) then return { status = 'present' } end

    local wasLoaded = Containers.isLoaded(id)
    local c
    if id:match('^player:%d+$') then
        c = Inv.resolve(id)
    else
        c = Containers.get(id)
        if not c and not Containers.isDefined(id) then
            local top = 0
            for _, s in ipairs(items) do if (s.slot or 0) > top then top = s.slot end end
            Containers.define(id, {
                kind = 'stash', label = opts.label or (id:gsub('^%a+:', '')),
                slots = math.max(tonumber(opts.slots) or Migrate.STASH_SLOTS, math.min(top, 1000)),
                maxWeight = RsgInv.toKg(Migrate.STASH_GRAMS), flags = { acceptWeapons = true },
            })
        end
        c = c or Containers.get(id, { create = true })
    end
    if not c then return { status = 'no_inventory' } end

    local sum = { stacks = 0, weapons = 0, weaponsKnown = 0, skipped = 0, unknown = 0, unknownNames = {} }
    local ctx = { reason = 'migrate', actor = 'switch-over import', ignoreWeaponLimit = true }
    local ok, err = pcall(Migrate.fill, c, items, sum, nil, ctx, {})
    Persistence.flush()
    if not wasLoaded then Containers.unload(id) end
    if not ok then
        print(('^1[MULTIinventory] import into %s failed: %s^7'):format(id, tostring(err)))
        return { status = 'error' }
    end
    sum.unknownNames = toList(sum.unknownNames)
    sum.unknown = nil
    sum.renamed = renamed
    sum.status = 'done'
    return sum
end

local function importAmmo(charId, ammo)
    local out = { added = {}, unknown = {} }
    charId = math.tointeger(tonumber(charId))
    if not charId or type(ammo) ~= 'table' or not ready() then return out end
    for t, n in pairs(ammo) do
        n = math.floor(tonumber(n) or 0)
        if n > 0 then
            local ok = Ammo.add(charId, t, n, { ignoreMax = true, noPush = true })
            if ok then out.added[tostring(t)] = n else out.unknown[#out.unknown + 1] = tostring(t) end
        end
    end
    Persistence.flush()
    return out
end

local function importTarget(invType, charId, shared)
    invType = tostring(invType or '')
    if invType == '' then return nil end
    local n = math.tointeger(tonumber(charId))
    if Secondary and Secondary.isRegistered and Secondary.isRegistered(invType) then
        return Secondary.target(invType, n)
    end
    if shared or not n then return invType end
    return Secondary.instanceId(invType, n)
end

exports('ImportInventory', importInventory)
exports('ImportAmmo', importAmmo)
exports('ImportTarget', importTarget)
exports('ImportResolve', function(name)
    if type(name) ~= 'string' or name == '' then return name, false, false end
    if Util.isWeaponName(name) then
        local def = WeaponDefs.get(name)
        return def and def.name or name, def ~= nil, true
    end
    local r = Registry.resolve(name)
    return r, Registry.get(r) ~= nil, false
end)
exports('ImportHasItems', function(id)
    if type(id) ~= 'string' or not ready() then return false end
    return M.Migrate.hasItemsHere(id)
end)
exports('ImportStashId', function(key)
    return M.Migrate and M.Migrate.idFromDbKey(key) or nil
end)
