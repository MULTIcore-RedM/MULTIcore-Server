-- ============================================================
-- MULTIinventory :: open / close / move (server)
-- Every item move a player makes goes through Inv.Move. The client only
-- names slots; the server checks access, distance, amounts and limits,
-- and re-reads every stack itself (anti-dupe). Move / split / stack / swap
-- with rollback follow rsg-inventory's 'rsg-inventory:server:SetInventoryData'.
-- ============================================================

local Inv = MULTIInv

local LOCKED_TYPES = { stash = true, glovebox = true, trunk = true, custom = true, drop = true, player = true }

local function setBusy(src, v)
    pcall(function() Player(src).state.inv_busy = v end)
end

--- Where an inventory is in the world (nil = anywhere).
function Inv.CoordsOf(inv, src)
    if inv.type == 'player' then
        if inv.ownerSrc and inv.ownerSrc ~= src then return Inv.PlayerCoords(inv.ownerSrc) end
        return nil
    end
    if inv.coords then
        local c = inv.coords
        return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    end
end

--- Is the player close enough to use that inventory? (admins always are)
function Inv.InReach(src, inv, dist)
    if inv.type == 'player' and inv.ownerSrc == src then return true end
    local c = Inv.CoordsOf(inv, src)
    if not c then return true end
    if Inv.IsAdmin(src) then return true end
    local p = Inv.PlayerCoords(src)
    if not p then return false end
    return #(p - c) <= (dist or inv.reach or Config.MaxDistance)
end

--- May src touch this inventory id right now? (own satchel or the one it has open)
function Inv.CanAccess(src, invId)
    if invId == Inv.PlayerInv(src) then return true end
    return Inv.Opened[src] ~= nil and Inv.Opened[src] == invId
end

--- Stash access rules (Config.RestrictedStashes, from rsg-inventory's HasStashAccess).
function Inv.HasStashAccess(src, invId)
    local name = Inv.DbKey(invId):lower()
    for prefix, rule in pairs(Config.RestrictedStashes) do
        if name:sub(1, #prefix) == prefix then
            if rule.admin then return Inv.IsAdmin(src) end
            local P = Inv.GetPlayer(src)
            if not P then return false end
            if rule.gang then
                local gang = name:match('^' .. prefix:gsub('%-', '%%-') .. '(.-)%-')
                return P.PlayerData.gang ~= nil and P.PlayerData.gang.name == gang
            end
            if rule.jobs then
                local job = P.PlayerData.job and P.PlayerData.job.name
                for _, j in ipairs(rule.jobs) do if j == job then return true end end
                return Inv.IsAdmin(src)
            end
        end
    end
    return true
end

-- ------------------------------------------------------------
-- open / close
-- ------------------------------------------------------------

--- Opens the player's satchel, alone or next to a second inventory.
--- target = nil (satchel only) | id | spec { id, label, slots, maxWeight, type = 'stash'|'custom'... }
--- (stores are their own resource, MULTIstores)
--- opts   = { coords, label, slots, maxWeight, ... } (used when the inventory is made)
--- → true | false, err
function Inv.Open(src, target, opts)
    src = tonumber(src)
    local ownId = src and Inv.PlayerInv(src)
    local own = ownId and Inv.List[ownId]
    if not own then return false, 'no_player' end
    -- opening any inventory screen ends a trade in progress (70_trade.lua)
    if Inv.InTrade and Inv.InTrade(src) then Inv.TradeCancel(src, 'trade_cancelled') end

    local id, data = target, opts
    if type(target) == 'table' then
        data = target
        id = target.id
        if id and target.type and not id:find(':') then id = target.type .. ':' .. id end
    end

    if Inv.Opened[src] then Inv.Close(src, true) end

    if not id then
        setBusy(src, true)
        Inv.CheckDecay(own)
        Inv.SendOpen(src, own)
        return true
    end
    if type(id) ~= 'string' then return false, 'bad_id' end

    local inv = Inv.List[id]
    if not inv then
        if Inv.TypeOf(id) == 'player' or Inv.TypeOf(id) == 'drop' then return false, 'no_inventory' end
        inv = Inv.Create(id, data)
    elseif data then
        Inv.Configure(id, data)
    end
    if inv == own then return Inv.Open(src) end

    if LOCKED_TYPES[inv.type] and inv.isOpen and inv.isOpen ~= src then
        Inv.Notify(src, 'inventory_in_use', 'error')
        return false, 'in_use'
    end

    inv.isOpen = src
    inv.viewers[src] = true
    Inv.Opened[src] = id
    setBusy(src, true)
    Inv.CheckDecay(own)
    Inv.CheckDecay(inv)
    Inv.SendOpen(src, own, inv)
    TriggerEvent('MULTIinventory:opened', src, id)
    return true
end

--- Closes the player's inventory screen and frees the second inventory.
function Inv.Close(src, keepUi)
    src = tonumber(src)
    if not src then return end
    local id = Inv.Opened[src]
    Inv.Opened[src] = nil
    if id then
        local inv = Inv.List[id]
        if inv then
            inv.viewers[src] = nil
            if inv.isOpen == src then inv.isOpen = false end
            if inv.type == 'player' and inv.ownerSrc and inv.ownerSrc ~= src then setBusy(inv.ownerSrc, false) end
            if inv.dirty and inv.type ~= 'player' then Inv.Save(inv) end
            if inv.type == 'drop' and Inv.OnDropClosed then Inv.OnDropClosed(inv) end
        end
        TriggerEvent('MULTIinventory:closed', src, id)
    end
    if not keepUi then
        setBusy(src, false)
        TriggerClientEvent('MULTIinventory:client:close', src)
    end
end

--- Opens another player's satchel for src (search / rob). Server-trusted: callers check the rules.
function Inv.OpenPlayer(src, targetSrc)
    targetSrc = tonumber(targetSrc)
    local targetId = targetSrc and Inv.BySrc[targetSrc]
    if not targetId or targetSrc == src then return false, 'no_player' end
    -- a searched player's trade ends (their offered items are unlocked first)
    if Inv.InTrade and Inv.InTrade(targetSrc) then Inv.TradeCancel(targetSrc, 'trade_cancelled') end
    -- close the target's own screen so they cannot move items while searched
    if Inv.Opened[targetSrc] then Inv.Close(targetSrc) end
    TriggerClientEvent('MULTIinventory:client:close', targetSrc)
    local ok, err = Inv.Open(src, targetId)
    if ok then setBusy(targetSrc, true) end
    return ok, err
end

-- ------------------------------------------------------------
-- move
-- ------------------------------------------------------------

local function stackable(def)
    local w = MULTIInvData.Weapons[def.name]
    return not def.unique and not (def.type == 'weapon' and not (w and w.thrown))
end

local function weaponLeft(src, fromInv, stack, toInv)
    if fromInv.type == 'player' and fromInv.ownerSrc and fromInv ~= toInv and stack.type == 'weapon' then
        TriggerClientEvent('MULTIinventory:client:weaponRemoved', fromInv.ownerSrc, stack.name, stack.info and stack.info.serie)
    end
end

-- Move hooks an inventory table may carry (the VORP face sets them on custom inventories):
--   inv.canPut(src, name, amount, info) / inv.canTake(src, name, amount, info) -> false refuses
--   inv.onPut(src, name, amount, info)  / inv.onTake(src, name, amount, info)   after the move
function Inv.HookAllows(inv, hook, src, name, amount, info)
    local fn = inv[hook]
    if not fn then return true end
    local ok, res = pcall(fn, src, name, amount, info)
    if not ok then print(('^1[MULTIinventory] %s.%s failed: %s^7'):format(inv.id, hook, tostring(res))) return false end
    return res ~= false
end

function Inv.HookAfter(inv, hook, src, name, amount, info)
    local fn = inv[hook]
    if not fn then return end
    local ok, err = pcall(fn, src, name, amount, info)
    if not ok then print(('^1[MULTIinventory] %s.%s failed: %s^7'):format(inv.id, hook, tostring(err))) end
end

local function doMove(src, fromId, fromSlot, toId, toSlot, amount)
    if type(fromId) ~= 'string' or type(toId) ~= 'string' then return false, 'bad_id' end
    if toId == 'drop:new' then return Inv.DropFromSlot(src, tonumber(fromSlot), amount) end
    if not Inv.CanAccess(src, fromId) or not Inv.CanAccess(src, toId) then return false, 'no_access' end

    local from, to = Inv.List[fromId], Inv.List[toId]
    if not from or not to then return false, 'no_inventory' end

    for _, inv in ipairs({ from, to }) do
        if inv.type ~= 'player' and inv.type ~= 'drop' and not Inv.HasStashAccess(src, inv.id) then
            Inv.Close(src)
            return false, 'no_permission'
        end
        if not Inv.InReach(src, inv) then
            Inv.Close(src)
            return false, 'too_far'
        end
    end

    fromSlot, toSlot = tonumber(fromSlot), tonumber(toSlot)
    if not Inv.IsPositiveInt(fromSlot, from.slots) then return false, 'bad_slot' end
    -- no target slot: same inventory = split into the first free slot, else wherever it fits
    if toSlot == nil and from == to then
        toSlot = Inv.FirstFreeSlot(to)
        if not toSlot then return false, 'no_space' end
    end
    if toSlot ~= nil and not Inv.IsPositiveInt(toSlot, to.slots) then return false, 'bad_slot' end
    if from == to and fromSlot == toSlot then return true end

    local fromItem = from.items[fromSlot]
    if not fromItem then return false, 'no_item' end
    -- items offered in a trade stay where they are (anti-dupe)
    if Inv.SlotLocked(from, fromSlot) or (toSlot and to.items[toSlot] and Inv.SlotLocked(to, toSlot)) then return false, 'locked' end
    local def = Inv.Items[fromItem.name]
    if not def then return false, 'unknown_item' end
    local cross = from ~= to
    if cross and def.canRemove == false and from.type == 'player' then return false, 'not_allowed' end

    local toItem = toSlot and to.items[toSlot]
    local canStack = toItem and toItem.name == fromItem.name and stackable(def) and Inv.InfoEqual(toItem.info, fromItem.info)
    local isSwap = toItem and not canStack
    local name, info = fromItem.name, fromItem.info
    local reason = 'moved item'

    if not isSwap then
        amount = tonumber(amount) or fromItem.amount
        if not Inv.IsPositiveInt(amount, fromItem.amount) then return false, 'bad_amount' end
        if cross then
            local ok, err = Inv.CanAddTo(to, name, amount, info)
            if not ok then return false, err end
            if not Inv.HookAllows(from, 'canTake', src, name, amount, info)
                or not Inv.HookAllows(to, 'canPut', src, name, amount, info) then return false, 'not_allowed' end
        end
        local ok, err = Inv.RemoveFrom(from, name, amount, fromSlot, nil, reason)
        if not ok then return false, err end
        local added, aerr = Inv.AddTo(to, name, amount, info, toSlot, reason)
        if not added then
            Inv.AddTo(from, name, amount, info, fromSlot, 'rollback')
            return false, aerr
        end
        if cross then
            weaponLeft(src, from, fromItem, to)
            Inv.HookAfter(from, 'onTake', src, name, amount, info)
            Inv.HookAfter(to, 'onPut', src, name, amount, info)
        end
        return true
    end

    -- swap two different stacks (both whole)
    local aAmt, bName, bAmt, bInfo = fromItem.amount, toItem.name, toItem.amount, toItem.info
    local bDef = Inv.Items[bName]
    if cross and bDef and bDef.canRemove == false and to.type == 'player' then return false, 'not_allowed' end
    if cross and not (Inv.HookAllows(from, 'canTake', src, name, aAmt, info) and Inv.HookAllows(to, 'canPut', src, name, aAmt, info)
        and Inv.HookAllows(to, 'canTake', src, bName, bAmt, bInfo) and Inv.HookAllows(from, 'canPut', src, bName, bAmt, bInfo)) then
        return false, 'not_allowed'
    end
    if not Inv.RemoveFrom(from, name, aAmt, fromSlot, nil, 'swapped item') then return false, 'no_item' end
    if not Inv.RemoveFrom(to, bName, bAmt, toSlot, nil, 'swapped item') then
        Inv.AddTo(from, name, aAmt, info, fromSlot, 'rollback')
        return false, 'no_item'
    end
    local okA, errA = Inv.AddTo(to, name, aAmt, info, toSlot, 'swapped item')
    local okB, errB = false, nil
    if okA then okB, errB = Inv.AddTo(from, bName, bAmt, bInfo, fromSlot, 'swapped item') end
    if not (okA and okB) then
        if okA then Inv.RemoveFrom(to, name, aAmt, toSlot, nil, 'rollback') end
        Inv.AddTo(from, name, aAmt, info, fromSlot, 'rollback')
        Inv.AddTo(to, bName, bAmt, bInfo, toSlot, 'rollback')
        return false, errA or errB or 'no_space'
    end
    if cross then
        weaponLeft(src, from, fromItem, to)
        weaponLeft(src, to, toItem, from)
        Inv.HookAfter(from, 'onTake', src, name, aAmt, info)
        Inv.HookAfter(to, 'onPut', src, name, aAmt, info)
        Inv.HookAfter(to, 'onTake', src, bName, bAmt, bInfo)
        Inv.HookAfter(from, 'onPut', src, bName, bAmt, bInfo)
    end
    return true
end

--- Moves `amount` from fromInv/fromSlot to toInv/toSlot for player src.
--- toInv = 'drop:new' drops on the ground.
--- → true | false, err
function Inv.Move(src, fromId, fromSlot, toId, toSlot, amount)
    src = tonumber(src)
    if not src then return false, 'no_player' end
    local ok, err = Inv.WithLock(src, function()
        return Inv.Batch(doMove, src, fromId, fromSlot, toId, toSlot, amount)
    end)
    if not ok then
        local key = ({ too_heavy = 'too_heavy', no_space = 'no_space', limit = 'limit', too_far = 'too_far',
            no_permission = 'no_permission', not_allowed = 'not_allowed', locked = 'trade_locked' })[err]
        if key then Inv.Notify(src, key, 'error') end
        -- resend the true state so the screen drops what the player dragged
        local own = Inv.List[Inv.PlayerInv(src) or '']
        if own then Inv.SendUpdate(src, own) end
        local other = Inv.Opened[src] and Inv.List[Inv.Opened[src]]
        if other then Inv.SendUpdate(src, other) end
    end
    return ok, err
end

-- the UI's net events and callbacks are in 85_client.lua

AddEventHandler('playerDropped', function()
    local src = source
    for _, inv in pairs(Inv.List) do
        inv.viewers[src] = nil
        if inv.isOpen == src then inv.isOpen = false end
    end
    Inv.Opened[src] = nil
end)
