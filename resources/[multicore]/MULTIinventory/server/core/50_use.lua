-- ============================================================
-- MULTIinventory :: usable items, weapons, ammo boxes (server)
-- Use(src, slot) runs, for the item in that satchel slot:
--   * weapons: equip (rsg-weapons when it runs, else MULTIinventory's client)
--   * RSG usables  (RSGCore.Functions.CreateUseableItem, kept in MULTIcore)
--   * usables registered here (RegisterUsable, also used by the VORP face)
--   * built-in usables (ammo boxes) only when nothing else claims the item
-- The RSG callback lookup follows rsg-inventory's Inventory.UseItem.
-- ============================================================

local Inv = MULTIInv

--- fn(src, stack, invId). opts = { builtin = bool, face = 'rsg'|'vorp'|'multi' }.
--- A later registration from the same resource replaces the earlier one.
function Inv.RegisterUsable(name, fn, opts)
    if type(name) ~= 'string' or not fn then return false end
    name = name:lower()
    opts = type(opts) == 'table' and opts or {}
    local res = opts.resource or GetInvokingResource() or GetCurrentResourceName()
    local list = Inv.Usables[name] or {}
    for i = #list, 1, -1 do
        if list[i].resource == res and (list[i].builtin or false) == (opts.builtin or false) then table.remove(list, i) end
    end
    list[#list + 1] = { fn = fn, resource = res, builtin = opts.builtin or false, face = opts.face }
    Inv.Usables[name] = list
    return true
end

function Inv.UnregisterUsable(name, resource)
    local list = name and Inv.Usables[name:lower()]
    if not list then return end
    for i = #list, 1, -1 do
        if not resource or list[i].resource == resource then table.remove(list, i) end
    end
end

AddEventHandler('onResourceStop', function(res)
    for _, list in pairs(Inv.Usables) do
        for i = #list, 1, -1 do if list[i].resource == res then table.remove(list, i) end end
    end
end)

--- RSG's callback for an item (MULTIcore keeps RSGCore.UsableItems).
function Inv.RsgUsable(name)
    local ok, data = pcall(Inv.Core().Functions.CanUseItem, name)
    if not ok or not data then return nil end
    if type(data) == 'function' then return data end
    if type(data) == 'table' then
        if rawget(data, '__cfx_functionReference') then return data end
        return data.cb or data.callback
    end
end

--- Is anything listening for this item?
function Inv.IsUsable(name)
    name = name and name:lower()
    local def = Inv.Items[name]
    if not def then return false end
    if def.type == 'weapon' then return true end
    if Inv.RsgUsable(name) then return true end
    return Inv.Usables[name] ~= nil and #Inv.Usables[name] > 0
end

local function weaponHandler()
    local h = Config.Weapons.Handler
    if h == 'auto' then return GetResourceState('rsg-weapons') == 'started' and 'rsg' or 'multi' end
    return h
end

local function useWeapon(src, stack, P)
    local w = MULTIInvData.Weapons[stack.name]
    local serial = stack.info and stack.info.serie
    if serial and Config.Weapons.RegisterSerials and Inv.hasPlayerWeapons and P then
        local cid = P.PlayerData.citizenid
        local exists = MySQL.scalar.await('SELECT 1 FROM player_weapons WHERE serial = ? AND citizenid = ? LIMIT 1', { serial, cid })
        if not exists then MySQL.insert('INSERT INTO player_weapons (serial, citizenid) VALUES (?, ?)', { serial, cid }) end
    end
    if weaponHandler() == 'rsg' then
        if stack.type == 'weapon_thrown' then
            TriggerClientEvent('rsg-weapons:client:UseThrownWeapon', src, stack)
        elseif stack.type == 'equipment' then
            TriggerClientEvent('rsg-weapons:client:UseEquipment', src, stack)
        else
            TriggerClientEvent('rsg-weapons:client:UseWeapon', src, stack)
        end
    else
        TriggerClientEvent('MULTIinventory:client:useWeapon', src, stack, w)
    end
    return true
end

local function run(src, stack, invId)
    local name = stack.name
    local external, builtin = {}, {}
    for _, u in ipairs(Inv.Usables[name] or {}) do
        if u.builtin then builtin[#builtin + 1] = u else external[#external + 1] = u end
    end
    local rsgCb = Inv.RsgUsable(name)
    local list = (#external > 0 or rsgCb) and external or builtin
    if not rsgCb and #list == 0 then return false, 'not_usable' end
    local copy = Inv.DeepCopy(stack)
    if rsgCb then
        local ok, err = pcall(rsgCb, src, copy)
        if not ok then print(('^1[MULTIinventory] usable %s (RSG) failed: %s^7'):format(name, tostring(err))) end
    end
    for _, u in ipairs(list) do
        local ok, err = pcall(u.fn, src, copy, invId)
        if not ok then print(('^1[MULTIinventory] usable %s (%s) failed: %s^7'):format(name, u.resource, tostring(err))) end
    end
    return true
end

--- Uses the item in the player's satchel slot. → true | false, err
function Inv.Use(src, slot)
    src, slot = tonumber(src), tonumber(slot)
    if not src or not slot then return false, 'bad_slot' end
    local invId = Inv.PlayerInv(src)
    local inv = invId and Inv.List[invId]
    if not inv then return false, 'no_player' end
    local P = Inv.GetPlayer(src)
    local meta = P and P.PlayerData.metadata or {}
    if meta.isdead or meta.ishandcuffed then return false, 'blocked' end
    Inv.CheckDecay(inv)
    local stack = inv.items[slot]
    if not stack then return false, 'no_item' end
    if Inv.SlotLocked(inv, slot) then
        Inv.Notify(src, 'trade_locked', 'error')
        return false, 'locked'
    end
    local def = Inv.Items[stack.name]
    if not def then return false, 'unknown_item' end

    local ok, err
    if def.type == 'weapon' or stack.type == 'weapon_thrown' or stack.type == 'equipment' then
        ok = useWeapon(src, stack, P)
    else
        ok, err = run(src, stack, invId)
    end
    if ok then
        TriggerClientEvent('MULTIinventory:client:itembox', src, def, 1, 'use')
        TriggerEvent('MULTIinventory:used', src, stack.name, slot)
    end
    return ok, err
end

--- Runs the use callbacks for an item by name (RSG's UseItem(itemName, ...) style); data is passed through.
function Inv.UseByName(src, name, stack)
    if type(name) ~= 'string' then return false end
    stack = stack or { name = name, amount = 1, info = {} }
    return run(src, stack, Inv.PlayerInv(src))
end

RegisterNetEvent('MULTIinventory:server:use', function(slot)
    local src = source
    if Inv.RateLimited(src, 'use') then return end
    Inv.WithLock(src, Inv.Use, src, slot)
end)

-- ------------------------------------------------------------
-- built-in: ammo boxes give rounds (only when no other script handles the box)
-- ------------------------------------------------------------

local function openBox(src, stack, invId)
    local box = MULTIInvData.AmmoBoxes[stack.name]
    local inv = Inv.List[invId]
    if not box or not inv then return end
    local ammo = MULTIInvData.Ammo[box.ammo]
    Inv.Batch(function()
        if not Inv.RemoveFrom(inv, stack.name, 1, stack.slot, nil, 'ammo box opened') then return end
        local ok, err = Inv.AddTo(inv, ammo.item, box.rounds, nil, nil, 'ammo box opened')
        if not ok then
            Inv.AddTo(inv, stack.name, 1, stack.info, stack.slot, 'rollback')
            Inv.Notify(src, err == 'too_heavy' and 'too_heavy' or 'no_space', 'error')
            return
        end
        Inv.ItemBox(src, stack.name, 1, 'remove')
        Inv.ItemBox(src, ammo.item, box.rounds, 'add')
    end)
end

AddEventHandler('MULTIinventory:itemsLoaded', function()
    for box in pairs(MULTIInvData.AmmoBoxes) do
        Inv.RegisterUsable(box, openBox, { builtin = true, resource = GetCurrentResourceName(), face = 'multi' })
    end
end)
