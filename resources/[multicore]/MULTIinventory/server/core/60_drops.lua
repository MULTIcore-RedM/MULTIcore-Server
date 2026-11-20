-- ============================================================
-- MULTIinventory :: items on the ground (server, memory only)
-- A drop is an inventory 'drop:<n>' with coords. The UI builder's client
-- shows the bag prop and the open prompt (docs/INVENTORY_CLIENT.md):
--   client MULTIinventory:client:drops ({ [dropId] = coords })   full list (sent on login)
--   client MULTIinventory:client:dropAdded (dropId, coords)
--   client MULTIinventory:client:dropRemoved (dropId)
--   cb     MULTIinventory:server:getDrops () -> { [dropId] = coords }
--   cb     MULTIinventory:server:drop (slot, amount) -> ok, err   (at the player's feet; joins a drop within 1.5 m)
--   net    MULTIinventory:server:openInventory (dropId)          (85_client.lua, distance-checked)
-- ============================================================

local Inv = MULTIInv
local nextDrop = 0
local JOIN_DISTANCE = 1.5

--- Makes an empty drop at coords. → inventory
function Inv.CreateDrop(coords, label)
    nextDrop = nextDrop + 1
    local id = 'drop:' .. nextDrop
    local inv = Inv.Create(id, {
        label = label or _L('drop_label'),
        slots = Config.Drop.Slots, maxWeight = Config.Drop.MaxWeight,
        coords = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0),
    })
    inv.model = Config.Drop.Model
    TriggerClientEvent('MULTIinventory:client:dropAdded', -1, id, inv.coords)
    TriggerEvent('MULTIinventory:dropCreated', id, inv.coords)
    return inv
end

function Inv.RemoveDrop(id)
    local inv = Inv.List[id]
    if not inv or inv.type ~= 'drop' then return false end
    for src in pairs(inv.viewers) do Inv.Close(src) end
    Inv.List[id] = nil
    TriggerClientEvent('MULTIinventory:client:dropRemoved', -1, id)
    TriggerEvent('MULTIinventory:dropRemoved', id)
    return true
end

--- Called when a viewer closes a drop: an empty drop goes away.
function Inv.OnDropClosed(inv)
    if next(inv.items) == nil and next(inv.viewers) == nil then Inv.RemoveDrop(inv.id) end
end

--- { [dropId] = coords }
function Inv.GetDrops()
    local out = {}
    for id, inv in pairs(Inv.List) do
        if inv.type == 'drop' then out[id] = inv.coords end
    end
    return out
end

--- The drop within reach of coords that still has room, or a new one.
local function dropNear(coords)
    for _, inv in pairs(Inv.List) do
        if inv.type == 'drop' and #(inv.coords - coords) <= JOIN_DISTANCE and Inv.UsedSlots(inv) < inv.slots then return inv, false end
    end
    return Inv.CreateDrop(coords), true
end

--- Drops amount from the player's satchel slot at the player's feet. → true, dropId | false, err
function Inv.DropFromSlot(src, slot, amount)
    local own = Inv.List[Inv.PlayerInv(src) or '']
    if not own then return false, 'no_player' end
    local stack = slot and own.items[slot]
    if not stack then return false, 'no_item' end
    if Inv.SlotLocked(own, slot) then return false, 'locked' end
    local def = Inv.Items[stack.name]
    if def and def.canRemove == false then return false, 'not_allowed' end
    amount = tonumber(amount)
    if not amount or amount <= 0 then amount = stack.amount end
    if not Inv.IsPositiveInt(amount, stack.amount) then return false, 'bad_amount' end
    local coords = Inv.PlayerCoords(src)
    if not coords then return false, 'no_coords' end
    local name, info = stack.name, stack.info
    local drop, isNew = dropNear(coords)
    local ok, err = Inv.CanAddTo(drop, name, amount, info)
    if not ok then if isNew then Inv.RemoveDrop(drop.id) end return false, err end
    ok, err = Inv.RemoveFrom(own, name, amount, slot, nil, 'dropped')
    if not ok then if isNew then Inv.RemoveDrop(drop.id) end return false, err end
    local added, aerr = Inv.AddTo(drop, name, amount, info, nil, 'dropped')
    if not added then
        Inv.AddTo(own, name, amount, info, slot, 'rollback')
        if isNew then Inv.RemoveDrop(drop.id) end
        return false, aerr
    end
    if stack.type == 'weapon' then
        TriggerClientEvent('MULTIinventory:client:weaponRemoved', src, name, info and info.serie)
    end
    Inv.ItemBox(src, name, amount, 'remove')
    return true, drop.id
end

--- Puts items on the ground at the player (RSG's ForceDropItem when the satchel is full). → dropId | false
function Inv.ForceDrop(src, name, amount, info, reason)
    local coords = Inv.PlayerCoords(src)
    if not coords then return false end
    local drop, isNew = dropNear(coords)
    if not Inv.AddTo(drop, name, amount, info, nil, reason or 'force drop') then
        if isNew then Inv.RemoveDrop(drop.id) end
        return false
    end
    Inv.Notify(src, 'dropped_full', 'warning')
    return drop.id
end

lib.callback.register('MULTIinventory:server:drop', function(src, slot, amount)
    if Inv.RateLimited(src, 'drop') then return false, 'busy' end
    return Inv.WithLock(src, function() return Inv.Batch(Inv.DropFromSlot, src, tonumber(slot), amount) end)
end)

lib.callback.register('MULTIinventory:server:getDrops', function()
    return Inv.GetDrops()
end)

AddEventHandler('MULTIinventory:playerLoaded', function(src)
    TriggerClientEvent('MULTIinventory:client:drops', src, Inv.GetDrops())
end)

-- unopened drops expire
CreateThread(function()
    while true do
        Wait(60000)
        local limit = os.time() - (Config.Drop.ExpireMinutes * 60)
        for id, inv in pairs(Inv.List) do
            if inv.type == 'drop' and not inv.isOpen and next(inv.viewers) == nil and inv.createdTime < limit then
                Inv.RemoveDrop(id)
            end
        end
    end
end)
