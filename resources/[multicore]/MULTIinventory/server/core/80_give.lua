-- ============================================================
-- MULTIinventory :: give to a player, and data callbacks for the UI (server)
-- Give follows rsg-inventory's 'rsg-inventory:server:giveItem' callback:
-- server-side stack, distance, blocked states, remove then add with rollback.
-- ============================================================

local Inv = MULTIInv

local function blocked(P)
    local m = P and P.PlayerData.metadata or {}
    return m.isdead or m.inlaststand or m.ishandcuffed
end

--- Gives amount from src's satchel slot to player target. → true | false, err
function Inv.Give(src, target, slot, amount)
    src, target, slot = tonumber(src), tonumber(target), tonumber(slot)
    if not src or not target or src == target or not slot then return false, 'bad_target' end
    local P, T = Inv.GetPlayer(src), Inv.GetPlayer(target)
    if not P or not T or blocked(P) or blocked(T) then return false, 'blocked' end
    local a, b = Inv.PlayerCoords(src), Inv.PlayerCoords(target)
    if not a or not b or #(a - b) > Config.GiveDistance then return false, 'too_far' end
    local own = Inv.List[Inv.PlayerInv(src) or '']
    local other = Inv.List[Inv.PlayerInv(target) or '']
    if not own or not other then return false, 'no_player' end
    local stack = own.items[slot]
    if not stack then return false, 'no_item' end
    if Inv.SlotLocked(own, slot) then return false, 'locked' end
    local def = Inv.Items[stack.name]
    if not def then return false, 'unknown_item' end
    if def.canRemove == false then return false, 'not_allowed' end
    amount = tonumber(amount) or stack.amount
    if not Inv.IsPositiveInt(amount, stack.amount) then return false, 'bad_amount' end
    local ok, err = Inv.CanAddTo(other, stack.name, amount, stack.info)
    if not ok then
        Inv.Notify(src, 'target_cannot_carry', 'error')
        return false, err
    end
    local name, info = stack.name, stack.info
    if not Inv.HookAllows(own, 'canTake', src, name, amount, info) or not Inv.HookAllows(other, 'canPut', src, name, amount, info) then
        return false, 'not_allowed'
    end
    ok, err = Inv.Batch(function()
        local removed, rerr = Inv.RemoveFrom(own, name, amount, slot, nil, ('given to %s'):format(target))
        if not removed then return false, rerr end
        local added, aerr = Inv.AddTo(other, name, amount, info, nil, ('given by %s'):format(src))
        if not added then
            Inv.AddTo(own, name, amount, info, slot, 'rollback give')
            return false, aerr
        end
        return true
    end)
    if not ok then return false, err end
    if def.type == 'weapon' then TriggerClientEvent('MULTIinventory:client:weaponRemoved', src, name, info and info.serie) end
    Inv.ItemBox(src, name, amount, 'remove')
    Inv.ItemBox(target, name, amount, 'add')
    TriggerClientEvent('MULTIinventory:client:giveAnim', src)
    TriggerClientEvent('MULTIinventory:client:giveAnim', target)
    Inv.Notify(src, 'gave', 'success', amount, def.label)
    Inv.Notify(target, 'received', 'success', amount, def.label)
    TriggerEvent('MULTIinventory:given', src, target, name, amount)
    return true
end

lib.callback.register('MULTIinventory:give', function(src, target, slot, amount)
    if Inv.RateLimited(src, 'give') then return false end
    local ok = Inv.WithLock(src, Inv.Give, src, target, slot, amount)
    return ok == true
end)

--- The player's own satchel view (for the hotbar on join).
lib.callback.register('MULTIinventory:getSelf', function(src)
    local inv = Inv.List[Inv.PlayerInv(src) or '']
    return inv and Inv.View(inv) or nil
end)

--- Item definitions, weapon / ammo data and image folders for the UI.
lib.callback.register('MULTIinventory:getItems', function()
    return {
        items = Inv.Items,
        weapons = MULTIInvData.Weapons,
        ammo = MULTIInvData.Ammo,
        ammoItems = MULTIInvData.AmmoItems,
        ammoBoxes = MULTIInvData.AmmoBoxes,
        imagePaths = Config.ImagePaths,
    }
end)

--- Nearby players' names, for the give list. Only players within 10 m are answered.
lib.callback.register('MULTIinventory:getPlayerName', function(src, target)
    target = tonumber(target)
    local a, b = Inv.PlayerCoords(src), target and Inv.PlayerCoords(target)
    if not a or not b or #(a - b) > 10.0 then return nil end
    local T = Inv.GetPlayer(target)
    local ci = T and T.PlayerData.charinfo
    if ci and ci.firstname then return ci.firstname .. ' ' .. (ci.lastname or '') end
    return GetPlayerName(target)
end)
