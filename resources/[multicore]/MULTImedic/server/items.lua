-- ============================================================
-- MULTImedic :: medical items (server)
--   * medic supplies: Config.Revive.Item / Config.Treat.Item are checked and used up
--   * self-care: bandage, field bandage and first aid from the satchel (Config.SelfCare)
-- Items go through MULTIinventory. The self-care items are registered as built-in
-- usables, so a script that makes the same item usable (an RSG CreateUseableItem,
-- a VORP registerUsableItem ...) takes it over.
-- Health is added the way rsg-medic's bandage does it (percent of max health).
-- ============================================================

local MI = exports.MULTIinventory
local notify = Medic.notify

local function invReady()
    return GetResourceState('MULTIinventory') == 'started'
end

--- How many of an item the player carries.
function Medic.ItemCount(src, name)
    if not invReady() or not name then return 0 end
    local ok, n = pcall(function() return MI:Count(MI:PlayerInv(src), name) end)
    return ok and tonumber(n) or 0
end

--- Takes one of an item from the player. → true when it was taken.
function Medic.TakeItem(src, name, slot)
    if not invReady() or not name then return false end
    local ok, removed = pcall(function() return MI:RemoveItem(MI:PlayerInv(src), name, 1, slot, nil, 'MULTImedic') end)
    if ok and removed then
        TriggerClientEvent('MULTIinventory:client:itembox', src, MI:GetItemDef(name), 1, 'remove')
        return true
    end
    return false
end

function Medic.ItemLabel(name)
    local ok, d = pcall(function() return MI:GetItemDef(name) end)
    return ok and type(d) == 'table' and d.label or tostring(name)
end

--- Error code → text ('need_item' names the item the action needs).
function Medic.ErrText(err, kind)
    if err == 'need_item' then
        local item = kind == 'revive' and Config.Revive.Item or Config.Treat.Item
        return _L('need_item', Medic.ItemLabel(item))
    end
    return _L(err)
end

-- ------------------------------------------------------------
-- self-care: use a bandage on yourself
-- ------------------------------------------------------------
local using = {}   -- [src] = { name, slot, t }

local function onUse(src, stack)
    src = tonumber(src)
    if type(stack) ~= 'table' or not stack.name then return end
    local def = Config.SelfCare.Items[stack.name]
    if not def then return end
    if using[src] then return notify(src, _L('cannot_now'), 'error') end
    if Medic.IsDead(src) then return end
    local P = Medic.getP(src)
    if not P or P.PlayerData.metadata.ishandcuffed then return notify(src, _L('cannot_now'), 'error') end
    using[src] = { name = stack.name, slot = stack.slot, t = GetGameTimer() }
    TriggerClientEvent('MULTImedic:client:selfCare', src, stack.name, def.time)
end

-- the client finished (or stopped) the bandaging
RegisterNetEvent('MULTImedic:server:selfCareDone', function(completed)
    local src = source
    local u = using[src]
    using[src] = nil
    if not u or completed ~= true then return end
    local def = Config.SelfCare.Items[u.name]
    if not def or Medic.IsDead(src) then return end
    if GetGameTimer() - u.t < def.time * 0.8 then return end      -- finished too fast
    if not Medic.TakeItem(src, u.name, u.slot) and not Medic.TakeItem(src, u.name) then
        return notify(src, _L('need_item', Medic.ItemLabel(u.name)), 'error')
    end
    TriggerClientEvent('MULTImedic:client:treated', src, def.health or 0)
    local better = false
    if Config.Injuries.Enabled then
        for _ = 1, def.improve or 0 do
            if Medic.ImproveWorst(src) then better = true else break end
        end
    end
    notify(src, better and _L('injury_better') or _L('bandaged'), 'success')
end)

AddEventHandler('playerDropped', function() using[source] = nil end)

local function register()
    if not Config.SelfCare.Enabled then return end
    local n = 0
    for name in pairs(Config.SelfCare.Items) do
        if MI:GetItemDef(name) then
            MI:RegisterUsable(name, onUse, { builtin = true, face = 'multi' })
            n = n + 1
        else
            print(('^3[MULTImedic] item "%s" is not in the item registry; skipped^7'):format(name))
        end
    end
    print(('[MULTImedic] %d medical items usable'):format(n))
end

CreateThread(function()
    local t = 0
    while (not invReady() or not MI:IsReady()) and t < 1200 do Wait(250) t = t + 1 end
    if not invReady() then return print('^3[MULTImedic] MULTIinventory is not running; medical items are not usable^7') end
    register()
end)

-- MULTIinventory restarted: its usable list is empty again
AddEventHandler('onResourceStart', function(res)
    if res ~= 'MULTIinventory' then return end
    CreateThread(function()
        local t = 0
        while not MI:IsReady() and t < 1200 do Wait(250) t = t + 1 end
        register()
    end)
end)
