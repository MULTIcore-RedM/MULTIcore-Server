-- ============================================================
-- MULTIinventory :: client/multi/faces.lua
--
-- Client side of the MULTIinventory export API and of the rsg-inventory, vorp_inventory and
-- redemrp_inventory names this resource answers to:
--   exports.MULTIinventory:GetImagePaths() -> { 'nui://MULTIimages/images/', ... }
--   exports.MULTIinventory:GetItemCount(name) -> total of that item in the player's satchel
--   exports['rsg-inventory']:HasItem / GetItemCount / GetPlayerItems / IsOpen / OpenInventory /
--                            CloseInventory / ItemBox
--   exports.vorp_inventory:closeInventory / getInventoryItems / getInventoryItem / getServerItem
-- Commands: /inventory (open, MULTIradial uses it), /closeinv
-- Events: MULTIinventory:client:itembox (def, amount, 'add'|'remove'|'use') -> MULTIcore notification,
--   rsg-inventory client events, redemrp_inventory:OpenStash / OpenInventory.
-- ============================================================

local function alias(resource, name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB) setCB(fn) end)
end

-- ------------------------------------------------------------
-- satchel cache helpers
-- ------------------------------------------------------------

local function totals()
    local out = {}
    for _, it in ipairs(InvClient.getItems()) do
        if type(it) == 'table' and it.name then
            local n = tostring(it.name):lower()
            out[n] = (out[n] or 0) + (tonumber(it.count or it.amount) or 1)
        end
    end
    return out
end

local function itemCount(name)
    if type(name) ~= 'string' then return 0 end
    return totals()[name:lower()] or 0
end

---the satchel in rsg-core's shape { [slot] = { name, amount, info, label, slot, ... } }
local function playerItems()
    local out = {}
    for _, it in ipairs(InvClient.getItems()) do
        if type(it) == 'table' and it.slot then
            out[it.slot] = { name = tostring(it.name):lower(), amount = it.count or it.amount or 1, info = it.metadata or {},
                             label = it.label, description = it.description, weight = it.weight, image = it.image,
                             type = it.kind == 'weapon' and 'weapon' or 'item', slot = it.slot }
        end
    end
    return out
end

local function hasItem(items, amount)
    local have = totals()
    local function has(name, need) return (have[tostring(name):lower()] or 0) >= (tonumber(need) or 1) end
    if type(items) == 'string' then return has(items, amount) end
    if type(items) ~= 'table' or next(items) == nil then return false end
    if items[1] ~= nil then
        for _, name in ipairs(items) do if not has(name, amount) then return false end end
        return true
    end
    for name, need in pairs(items) do
        if not has(name, amount or need) then return false end
    end
    return true
end

-- ------------------------------------------------------------
-- item pop-ups (MULTIcore notifications)
-- ------------------------------------------------------------
local KINDS = { add = true, remove = true, use = true }

local function notify(text, kind, duration)
    if GetResourceState('MULTIcore') == 'started' then
        pcall(function() exports.MULTIcore:Notify({ text = text, type = kind or 'info', duration = duration }) end)
    else
        TriggerEvent('ox_lib:notify', { description = text, type = kind == 'info' and 'inform' or kind, duration = duration })
    end
end

local function itemBox(def, amount, kind)
    if Config.ItemBox and Config.ItemBox.enabled == false then return end
    if type(def) == 'string' then def = { name = def } end
    if type(def) ~= 'table' then return end
    -- rsg callers pass (def, kind, amount) as well as (def, amount, kind)
    if type(amount) == 'string' and KINDS[amount] then amount, kind = kind, amount end
    kind = KINDS[kind] and kind or 'add'
    local n = math.max(1, math.floor(tonumber(amount) or 1))
    local label = def.label or def.name or '?'
    notify(L('itembox_' .. kind, n, label), kind == 'remove' and 'info' or 'success',
        Config.ItemBox and Config.ItemBox.time or 3000)
end

RegisterNetEvent('MULTIinventory:client:itembox', function(def, amount, kind) itemBox(def, amount, kind) end)
RegisterNetEvent('rsg-inventory:client:ItemBox', function(def, kind, amount) itemBox(def, amount, kind) end)
RegisterNetEvent('inventory:client:ItemBox', function(def, kind, amount) itemBox(def, amount, kind) end)

-- engine messages while the screen is closed go to the MULTIcore notifications
AddEventHandler('MULTIinventory:client:notify', function(n)
    if InvClient.isOpen() or type(n) ~= 'table' or not n.text then return end
    local kind = ({ inform = 'info', warning = 'warning', error = 'error', success = 'success' })[n.type or 'inform'] or 'info'
    notify(n.text, kind)
end)

-- ------------------------------------------------------------
-- MULTIinventory client exports
-- ------------------------------------------------------------
local function imagePaths()
    local p = Config.Images and Config.Images.itemPath or 'nui://MULTIimages/images/%s.png'
    local folder = p:gsub('%%s%.png$', ''):gsub('%%s$', '')
    local list = { folder }
    for _, extra in ipairs(Config.Images and Config.Images.extraPaths or {}) do list[#list + 1] = extra end
    return list
end

exports('GetImagePaths', imagePaths)
exports('GetItemCount', itemCount)
exports('GetPlayerItems', playerItems)

-- ------------------------------------------------------------
-- rsg-inventory (client)
-- ------------------------------------------------------------
alias('rsg-inventory', 'HasItem', hasItem)
alias('rsg-inventory', 'GetItemCount', itemCount)
alias('rsg-inventory', 'GetPlayerItems', playerItems)
alias('rsg-inventory', 'IsOpen', function() return InvClient.isOpen() end)
alias('rsg-inventory', 'OpenInventory', function() InvClient.open() end)
alias('rsg-inventory', 'CloseInventory', function() if InvClient.isOpen() then InvClient.close() end end)
alias('rsg-inventory', 'ItemBox', function(def, kind, amount) itemBox(def, amount, kind) end)

-- a script asks to show the satchel (maybe with a second inventory); only the id is trusted,
-- the server decides
local function openFromRsg(a, b)
    if type(a) == 'string' or (type(b) == 'table' and (b.name or b.id)) then
        return   -- stashes are opened by the server (OpenInventory export), never from a client event
    end
    InvClient.open()
end
RegisterNetEvent('rsg-inventory:client:openInventory', openFromRsg)
RegisterNetEvent('rsg-inventory:client:OpenInventory', openFromRsg)
RegisterNetEvent('rsg-inventory:client:closeInv', function() if InvClient.isOpen() then InvClient.close() end end)
RegisterNetEvent('rsg-inventory:client:updateInventory', function() end)    -- the screen updates itself
RegisterNetEvent('rsg-inventory:client:refreshInventory', function() end)
RegisterNetEvent('rsg-inventory:client:hotbar', function() end)
RegisterNetEvent('rsg-inventory:client:updateHotbar', function() end)

RegisterNetEvent('rsg-inventory:client:giveAnim', function()
    local ped = PlayerPedId()
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return end
    local dict, anim = 'mech_butcher', 'small_fish_give_player'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 1500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    if not HasAnimDictLoaded(dict) then return end
    TaskPlayAnim(ped, dict, anim, 8.0, 1.0, -1, 16, 0, false, false, false)
    RemoveAnimDict(dict)
end)

if lib and lib.callback then
    lib.callback.register('rsg-inventory:client:isInMelee', function() return IsPedInMeleeCombat(PlayerPedId()) end)
end

-- the server asks this client to send the rsg net events other resources listen to
-- (a net event needs the player as source); the use echo carries a one-time token
RegisterNetEvent('MULTIinventory:rsg:useEcho', function(item)
    if type(item) == 'table' then TriggerServerEvent('rsg-inventory:server:useItem', item) end
end)
RegisterNetEvent('MULTIinventory:rsg:closedEcho', function(id)
    if type(id) == 'string' then TriggerServerEvent('rsg-inventory:server:closeInventory', id) end
end)

-- ------------------------------------------------------------
-- vorp_inventory (client)
-- ------------------------------------------------------------
for _, name in ipairs({ 'closeInventory', 'getInventoryItems', 'getInventoryItem', 'getServerItem' }) do
    alias('vorp_inventory', name, function(...)
        return exports[GetCurrentResourceName()]['Compat_' .. name](nil, ...)
    end)
end

-- ------------------------------------------------------------
-- redemrp_inventory (client)
-- ------------------------------------------------------------
RegisterNetEvent('redemrp_inventory:OpenStash', function(id, kg)
    TriggerServerEvent('MULTIinventory:redem:openStash', id, kg)
end)
RegisterNetEvent('redemrp_inventory:OpenInventory', function() InvClient.open() end)
alias('redemrp_inventory', 'GetItemCount', itemCount)

-- ------------------------------------------------------------
-- commands
-- ------------------------------------------------------------
local openCmd = Config.OpenCommand or 'inventory'
if openCmd and openCmd ~= '' then
    RegisterCommand(openCmd, function()
        if InvClient.isOpen() then return end
        if IsEntityDead(PlayerPedId()) or IsPauseMenuActive() then return end
        InvClient.open()
    end, false)
end
local closeCmd = Config.CloseCommand or 'closeinv'
if closeCmd and closeCmd ~= '' then
    RegisterCommand(closeCmd, function() if InvClient.isOpen() then InvClient.close() end end, false)
end
