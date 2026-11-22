-- ============================================================
-- MULTIinventory :: server/exports.lua
--
-- Native MULTIinventory API. exports.MULTIinventory:<Name>(...)
-- All calls wait until the inventory is ready, may yield, and return  ok, errOrValue
-- unless stated otherwise. target = player source | 'player:<charid>' (offline OK) | container id.
--
-- The vorp_inventory face adds Compat_<name> exports in server/compat/vorp_api.lua on top of these
-- (it can call the same Lua functions directly: Inv.*, Usables.*, State.*, Containers.*).
-- ============================================================

local function ready() InvDB.awaitReady() end
local function ctx(reason) return { reason = reason or 'api', resource = GetInvokingResource() } end

local API = {}

-- items ------------------------------------------------------------------------------
function API.AddItem(target, item, count, meta)        ready() return Inv.add(target, item, count, meta, ctx()) end
function API.RemoveItem(target, item, count, meta)     ready() return Inv.remove(target, item, count, meta, ctx()) end
function API.RemoveStack(target, stackId, count)       ready() return Inv.removeStack(target, stackId, count, ctx()) end
function API.Count(target, item, meta)                 ready() return Inv.count(target, item, meta) end
function API.CanCarry(target, item, count, meta)       ready() return Inv.canAdd(target, item, count, meta, ctx()) end
function API.GetStacks(target, filter)                 ready() return Inv.getStacks(target, filter) end
function API.GetStack(stackId)                         ready() return Inv.getStack(stackId) end
function API.SetMetadata(target, stackId, meta, count) ready() return Inv.setMetadata(target, stackId, meta, count, ctx()) end
function API.GetWeight(target)                         ready() return Inv.weight(target) end
function API.WearItem(target, stackId, amount)         ready() return Degradation.wear(target, stackId, amount, ctx()) end

function API.MoveStack(stackId, toTarget, toSlot, count)
    ready()
    -- a weapon's stack id is 'w<weaponId>' (weapons have their own lane): move the weapon itself
    local wid = type(stackId) == 'string' and stackId:match('^w(%d+)$')
    if wid then
        if count ~= nil and tonumber(count) ~= 1 then return false, 'bad_count' end
        local wc, werr = Inv.resolve(toTarget, { create = true })
        if not wc then return false, werr end
        return Weapons.moveTo(tonumber(wid), wc, ctx('move'), toSlot)
    end
    local fc, e = Containers.locateStack(stackId)
    if not e then return false, 'no_item' end
    local tc, err = Inv.resolve(toTarget, { create = true })
    if not tc then return false, err end
    return Inv.move(fc, e.slot, tc, toSlot, count, ctx('move'))
end

function API.ClearContainer(target, keep)
    ready()
    local ok, removed = Inv.clear(target, { keep = keep }, ctx('clear'))
    if ok then InvLog.write('admin_clear', { actor = 'resource:' .. tostring(GetInvokingResource()), from = tostring(target), data = { stacks = removed } }) end
    return ok, removed
end

-- definitions -------------------------------------------------------------------------
function API.GetItemDef(name)   ready() return Registry.get(name) end
function API.GetItemGroups()    ready() return Registry.groups() end
function API.ReloadItems()      ready() return true, Registry.reload() end
-- Live item definitions written to `items` by another resource (e.g. RINGOjobtools' item creator).
-- Named *ItemDef because RemoveItem already means "take items from a target".
function API.RegisterItemDef(name) ready() local d = Registry.refresh(name) return d ~= nil, d end
function API.UpdateItemDef(name)   ready() local d = Registry.refresh(name) return d ~= nil, d end
function API.RemoveItemDef(name)   ready() Registry.refresh(name) Registry.forget(name) return Registry.get(name) == nil end
---Live picture for one item without a restart: src = absolute https:// (or nui://) URL, nil clears.
---In memory only (a restart reads html/img/items/<name>.png again); stacks synced after the call
---carry the new picture (Sync uses def.image).
function API.SetItemImage(name, src) return Registry.setImage(name, src) end
function API.GetItemImageOverrides()  return Registry.imageOverrides() end

-- usables -------------------------------------------------------------------------------
function API.RegisterUsable(item, fn) return Usables.register(item, fn, GetInvokingResource() or GetCurrentResourceName()) end
function API.UnregisterUsable(item)   return Usables.unregister(item) end
function API.IsUsable(item)           return Usables.isRegistered(item) end
function API.UseStack(src, stackId)
    ready()
    local c, e = Containers.findStack(stackId)
    if not e then return false, 'no_item' end
    return Usables.use(tonumber(src), c.id, e.slot, ctx('use'))
end

-- containers / UI ------------------------------------------------------------------------
function API.RegisterContainer(id, def)       return Containers.define(id, def) end
function API.UnregisterContainer(id, purge)   return Containers.undefine(id, purge) end
function API.ContainerExists(id)              ready() return Containers.isDefined(id) or Containers.get(id) ~= nil end
function API.GetContainer(id)
    ready()
    local c = Inv.resolve(id)
    if not c then return nil end
    local _, cap, load = Weight.pool(c)
    return { id = c.id, kind = c.kind, label = c.label, slots = c.slots, used = Containers.usedSlots(c),
             weight = load, maxWeight = cap, ownerCharId = c.ownerCharId, flags = c.flags, perms = c.perms }
end
function API.OpenContainer(src, id, opts) ready() return State.open(tonumber(src), id, opts) end
function API.OpenInventory(src)           ready() return State.open(tonumber(src), nil) end
function API.CloseUI(src)                 return State.close(tonumber(src), true) end
function API.IsOpen(src)                  return State.isOpen(tonumber(src)) end
function API.GetCharId(src)               local st = State.get(tonumber(src)) return st and st.charId or nil end

-- hotbar ---------------------------------------------------------------------------------
function API.GetHotbar(src)
    local st = State.get(tonumber(src))
    return st and Hotbar.view(st.charId) or {}
end

-- world drops ------------------------------------------------------------------------------
---Create a ground pile from a script (loot, death bags). items = { { item, count, metadata }, ... }
function API.CreateDrop(coords, items, ownerCharId)
    ready()
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return false, 'bad_coords' end
    local d = Drops.create({ x = coords.x, y = coords.y, z = coords.z }, ownerCharId)
    local added = 0
    for _, it in ipairs(items or {}) do
        local ok = Inv.add(d.cid, it.item or it.name, it.count or it.amount or 1, it.metadata, ctx('drop'))
        if ok then added = added + 1 end
    end
    if added == 0 then Drops.remove(d, 'empty') return false, 'nothing_added' end
    TriggerClientEvent('MULTIinventory:drops:set', -1, Drops.view(d))
    return true, d.id
end
function API.GetDrops()
    local out = {}
    for _, d in pairs(Drops.all()) do out[#out + 1] = Drops.view(d) end
    return out
end

-- names the MULTIinventory export API (server/multi/api.lua) answers with its own shapes
local MULTI_NAMES = { AddItem = true, RemoveItem = true, Count = true, GetItemDef = true,
                      RegisterUsable = true, UnregisterUsable = true, IsUsable = true }
for name, fn in pairs(API) do
    if MULTI_NAMES[name] then exports(name .. 'Native', fn) else exports(name, fn) end
end
InvAPI = API
