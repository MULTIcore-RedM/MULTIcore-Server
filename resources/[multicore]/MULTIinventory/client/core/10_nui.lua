-- ============================================================
-- MULTIinventory :: satchel NUI
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
--
-- Opens / updates / closes the page and turns what the player does on it
-- into requests to the server. Nothing moves until the server says so:
-- every move, split, give and drop is a server call, and the page
-- only redraws from what the server pushes back.
--
-- Client -> server (handled by server/core):
--   net   MULTIinventory:server:openSelf ()                      open my satchel (alone)
--   net   MULTIinventory:server:openInventory (invId)           open my satchel + invId (drop / other); server checks access
--   net   MULTIinventory:server:refresh ()                       push my satchel again (MULTIinventory:client:update)
--   net   MULTIinventory:server:close (otherInvId|nil)           I closed the page
--   cb    MULTIinventory:server:move (fromInv, fromSlot, toInv, toSlot|nil, amount) -> ok, err
--         (split = same inventory, empty slot; stores are MULTIstores' own screen)
--   cb    MULTIinventory:server:give (targetServerId, slot, amount) -> ok, err
--   cb    MULTIinventory:server:drop (slot, amount) -> ok, err   (server makes / extends a drop at my feet)
--   net   rsg-inventory:server:useItem ({ name, slot })          use an item (RSG's own name; RSG scripts listen to it)
-- Server -> client:
--   MULTIinventory:client:open (data)  data = { player = inv, other = inv|nil, defs = { [name] = def } }
--   MULTIinventory:client:update (inv, defs?)   (contract)
--   MULTIinventory:client:close ()
-- ============================================================

local useCooldownUntil = 0

local function myInvId()
    local c = MIC.Core()
    local ok, data = pcall(function() return c and c.Functions.GetPlayerData() end)
    local cid = ok and type(data) == 'table' and data.citizenid
    return cid and ('player:' .. cid) or nil
end
MIC.MyInvId = myInvId

--- inventory kind from its id: player / stash / drop / custom / glovebox / trunk
function MIC.InvKind(inv)
    if type(inv) ~= 'table' then return nil end
    if inv.type then return inv.type end
    local id = tostring(inv.id or '')
    return id:match('^(%a+):') or id:match('^(%a+)%-') or 'stash'
end

-- one item made ready for the page (definition merged in; the page never sees raw defs)
local function itemForNui(it)
    local d = MIC.Def(it.name) or {}
    local info = it.info or {}
    return {
        slot = it.slot,
        name = it.name,
        amount = it.amount,
        info = info,
        label = info.label or it.label or d.label or it.name,
        description = info.description or it.description or d.description or d.desc or '',
        weight = tonumber(it.weight or d.weight) or 0,
        image = info.image or it.image or d.image or (it.name .. '.png'),
        unique = d.unique == true,
        usable = (d.usable or d.useable) == true,
        type = d.type or it.type or 'item',
        equipped = MIC.IsEquipped and MIC.IsEquipped(it) or false,
    }
end
MIC.ItemForNui = itemForNui

local function invForNui(inv)
    if type(inv) ~= 'table' then return nil end
    local items = {}
    for _, it in pairs(inv.items or {}) do items[#items + 1] = itemForNui(it) end
    return {
        id = inv.id,
        label = inv.label or inv.id,
        slots = inv.slots,
        maxWeight = inv.maxWeight,
        maxCount = tonumber(inv.maxCount),
        kind = MIC.InvKind(inv),
        items = items,
    }
end
MIC.InvForNui = invForNui

-- item picture folders for other MULTI pages (MULTIstores)
exports('GetImagePaths', function() return MIC.Cfg('ImagePaths', {}) end)

local function staticData()
    return {
        locale = _LT(),
        lang = _LCode(),
        images = MIC.Cfg('ImagePaths', {}),
        hotbarSize = MIC.Cfg('Hotbar.Size', 5),
        giveEnabled = MIC.Cfg('Give.Enabled', true),
        dropEnabled = MIC.Cfg('Drops.Enabled', true),
        tradeButton = MIC.Cfg('Trade.Enabled', true) and MIC.Cfg('Trade.SatchelButton', true),
    }
end

local staticSent = false
local function sendStatic()
    if staticSent then return end
    staticSent = true
    local d = staticData()
    d.action = 'setup'
    SendNUIMessage(d)
end
MIC.SendStatic = sendStatic

-- ---------------------------------------------------------------
-- open / update / close
-- ---------------------------------------------------------------

function MIC.RequestOpen()
    if MIC.IsOpen or not MIC.CanUse() then return end
    if IsPauseMenuActive() then return end
    local dropId = MIC.NearestDrop and MIC.NearestDrop()
    if dropId then
        TriggerServerEvent('MULTIinventory:server:openInventory', dropId)
    else
        TriggerServerEvent('MULTIinventory:server:openSelf')
    end
end

local function pushPage(action)
    SendNUIMessage({
        action = action,
        player = invForNui(MIC.Inv),
        other = invForNui(MIC.Other),
        trade = MIC.TradeForNui and MIC.TradeForNui(MIC.Trade) or nil,
    })
end
MIC.PushPage = function() if MIC.IsOpen then pushPage('update') end end

RegisterNetEvent('MULTIinventory:client:open', function(data)
    if type(data) ~= 'table' then return end
    MIC.MergeDefs(data.defs)
    MIC.SetInv(data.player, true)
    if data.other then MIC.SetInv(data.other, false) else MIC.Other = nil end
    MIC.FireInvChange()
    sendStatic()
    MIC.IsOpen = true
    SetNuiFocus(true, true)
    TriggerEvent('MULTIinventory:client:stateChange', true)
    pushPage('open')
end)

RegisterNetEvent('MULTIinventory:client:update', function(inv, defs)
    if type(inv) ~= 'table' then return end
    MIC.MergeDefs(defs)
    local id = inv.id or inv.name
    local mine = (MIC.Inv and MIC.Inv.id == id) or id == myInvId()
    if mine then
        MIC.SetInv(inv, true)
        MIC.FireInvChange()
    elseif MIC.Other and MIC.Other.id == id then
        MIC.SetInv(inv, false)
    else
        return
    end
    if MIC.IsOpen then pushPage('update') end
end)

function MIC.Close(tellServer)
    if not MIC.IsOpen then return end
    MIC.IsOpen = false
    SetNuiFocus(false, false)
    TriggerEvent('MULTIinventory:client:stateChange', false)
    SendNUIMessage({ action = 'close' })
    local otherId = MIC.Other and MIC.Other.id or nil
    MIC.Other = nil
    -- closing the page during a trade cancels it (60_trade.lua)
    local trading = MIC.Trade ~= nil
    MIC.Trade = nil
    if trading and tellServer ~= false then TriggerServerEvent('MULTIinventory:server:tradeCancel') end
    if tellServer ~= false then
        TriggerServerEvent('MULTIinventory:server:close', otherId)
        -- RSG scripts listen to this one (e.g. robbery stashes); harmless for the engine
        if otherId then TriggerServerEvent('rsg-inventory:server:closeInventory', otherId) end
    end
end

RegisterNetEvent('MULTIinventory:client:close', function() MIC.Close(false) end)

-- ---------------------------------------------------------------
-- use
-- ---------------------------------------------------------------

--- Use the item in my satchel slot (hotbar, double-click, Use button).
local function trace(slot, why, name)   -- TEMPORARY (Config.DebugUse)
    if MIC.Cfg('DebugUse', false) then TriggerServerEvent('MULTIinventory:server:useTrace', slot, why, name) end
end

function MIC.UseSlot(slot)
    slot = tonumber(slot)
    if not slot then return trace(slot, 'no slot') end
    if not MIC.CanUse(MIC.IsOpen) then
        return trace(slot, ('cannot use now (loggedIn=%s busy=%s blocked=%s open=%s)'):format(tostring(MIC.LoggedIn()),
            tostring(LocalPlayer.state.inv_busy), tostring(MIC.Blocked), tostring(MIC.IsOpen)))
    end
    local now = GetGameTimer()
    if now < useCooldownUntil then return trace(slot, 'cooldown') end
    useCooldownUntil = now + MIC.Cfg('UseCooldown', 500)

    local it = MIC.PlayerItems()[slot]
    if not it then return trace(slot, 'no item in that slot') end
    local d = MIC.Def(it.name) or {}

    -- weapons and ammo are handled on the ped here (client/core/40_weapons.lua)
    if MIC.HandleWeaponUse and MIC.HandleWeaponUse(it, d) then
        trace(slot, 'weapon / ammo handled on the client', it.name)
        if MIC.IsOpen and MIC.Cfg('CloseOnWeaponUse', false) then MIC.Close(true) end
        return
    end

    if IsPedInMeleeCombat(PlayerPedId()) then return trace(slot, 'in melee combat', it.name) end
    trace(slot, 'sent to server', it.name)
    TriggerServerEvent('rsg-inventory:server:useItem', { name = it.name, slot = slot })
    if MIC.IsOpen and d.shouldClose ~= false and MIC.Cfg('CloseOnUse', true) then MIC.Close(true) end
end

-- ---------------------------------------------------------------
-- give: nearest player in reach
-- ---------------------------------------------------------------

local function nearestPlayer(maxDist)
    local me = PlayerId()
    local myPos = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, maxDist + 0.001
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local ped = GetPlayerPed(pid)
            if DoesEntityExist(ped) then
                local d = #(GetEntityCoords(ped) - myPos)
                if d < bestDist then best, bestDist = pid, d end
            end
        end
    end
    return best
end
MIC.NearestPlayer = nearestPlayer

-- ---------------------------------------------------------------
-- NUI callbacks (the page posts these)
-- ---------------------------------------------------------------

local function amountOf(data, it)
    local a = math.floor(tonumber(data and data.amount) or 0)
    local have = it and tonumber(it.amount) or 0
    if a <= 0 or a > have then a = have end
    return a
end

RegisterNUICallback('close', function(_, cb)
    MIC.Close(true)
    cb({})
end)

RegisterNUICallback('move', function(data, cb)
    if type(data) ~= 'table' or not data.fromInv or not data.toInv then return cb({ ok = false }) end
    if data.toInv == 'ground' then
        -- dragged onto the empty ground pane: that is a drop
        local ok, err = lib.callback.await('MULTIinventory:server:drop', false, tonumber(data.fromSlot), tonumber(data.amount) or 0)
        if not ok then MIC.Error(err) end
        return cb({ ok = ok == true })
    end
    local ok, err = lib.callback.await('MULTIinventory:server:move', false,
        tostring(data.fromInv), tonumber(data.fromSlot), tostring(data.toInv), tonumber(data.toSlot), tonumber(data.amount) or 0)
    if not ok then MIC.Error(err) end
    cb({ ok = ok == true })
end)

RegisterNUICallback('use', function(data, cb)
    cb({})
    MIC.UseSlot(data and data.slot)
end)

RegisterNUICallback('give', function(data, cb)
    local it = MIC.PlayerItems()[tonumber(data and data.slot) or -1]
    if not it or not MIC.Cfg('Give.Enabled', true) then return cb({ ok = false }) end
    local pid = nearestPlayer(MIC.Cfg('Give.Distance', 3.0))
    if not pid then
        MIC.Notify(_L('no_player_near'), 'error')
        return cb({ ok = false })
    end
    local ok, err = lib.callback.await('MULTIinventory:server:give', false, GetPlayerServerId(pid), it.slot, amountOf(data, it))
    if ok then TriggerEvent('rsg-inventory:client:giveAnim') else MIC.Error(err) end
    cb({ ok = ok == true })
end)

RegisterNUICallback('drop', function(data, cb)
    local it = MIC.PlayerItems()[tonumber(data and data.slot) or -1]
    if not it or not MIC.Cfg('Drops.Enabled', true) then return cb({ ok = false }) end
    if MIC.Cfg('Drops.NotOnMount', true) and (IsPedOnMount(PlayerPedId()) or IsPedInAnyVehicle(PlayerPedId(), false)) then
        MIC.Notify(_L('err_not_here'), 'error')
        return cb({ ok = false })
    end
    local ok, err = lib.callback.await('MULTIinventory:server:drop', false, it.slot, amountOf(data, it))
    if not ok then MIC.Error(err) end
    cb({ ok = ok == true })
end)

RegisterNUICallback('ammo', function(data, cb)
    cb({})
    local it = MIC.PlayerItems()[tonumber(data and data.slot) or -1]
    if it and MIC.SelectAmmo then MIC.SelectAmmo(it) end
end)

RegisterNUICallback('unequip', function(data, cb)
    cb({})
    local it = MIC.PlayerItems()[tonumber(data and data.slot) or -1]
    if it and MIC.Unequip then MIC.Unequip(it) end
end)

-- ---------------------------------------------------------------
-- open key and command
-- ---------------------------------------------------------------

RegisterCommand(MIC.Cfg('OpenCommand', 'inventory'), function()
    MIC.RequestOpen()
end, false)

RegisterCommand(MIC.Cfg('CloseCommand', 'closeinv'), function()
    MIC.Close(true)
end, false)

CreateThread(function()
    local openKey = MIC.Cfg('OpenKey', 0xC1989F95) -- I (INPUT_QUICK_USE_ITEM in Controls.cs; the game's own use is kept shut)
    while true do
        local sleep = 250
        if MIC.LoggedIn() and not MIC.IsOpen then
            sleep = 0
            if openKey and openKey ~= 0 then
                -- the game's own satchel would open on the same key: keep it shut, open ours
                DisableControlAction(0, openKey, true)
                if IsDisabledControlJustPressed(0, openKey) and not IsPauseMenuActive() then
                    MIC.RequestOpen()
                end
            end
        end
        Wait(sleep)
    end
end)

-- first data after login / restart so the hotbar, HasItem and weapons know the satchel
local function askRefresh()
    CreateThread(function()
        Wait(MIC.Cfg('RefreshDelay', 1500))
        if MIC.LoggedIn() then TriggerServerEvent('MULTIinventory:server:refresh') end
    end)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', askRefresh)
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() and MIC.LoggedIn() then askRefresh() end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    MIC.Close(true)
    MIC.Inv, MIC.Other = nil, nil
    MIC.FireInvChange()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if MIC.IsOpen then SetNuiFocus(false, false) end
end)
