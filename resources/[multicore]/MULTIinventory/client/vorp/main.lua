-- ============================================================
-- MULTIinventory :: vorp_inventory face - client
-- Client exports and events VORP scripts use, written from VORP's
-- public API documentation. The satchel itself (NUI, equip, ammo on
-- the ped) belongs to client/core; this file translates.
--
-- Events the UI (client/core) fires for this face:
--   MULTIinventory:client:stateChange (open: boolean)
--   MULTIinventory:client:weaponEquipped (data: { id, name, components, comps, serie, isDual, defaults })
-- Events this face fires for the UI:
--   MULTIinventory:client:close   - close the satchel / secondary inventory
--   MULTIinventory:client:block (blocked: boolean) - no opening while true
-- ============================================================

local function exportAs(name, fn)
    AddEventHandler(('__cfx_export_vorp_inventory_%s'):format(name), function(setCB)
        setCB(fn)
    end)
end

local function await(name, ...)
    if not lib or not lib.callback then return nil end
    local ok, res = pcall(lib.callback.await, name, false, ...)
    if ok then return res end
    return nil
end

-- ------------------------------------------------------------
-- Exports
-- ------------------------------------------------------------

--- getInventoryItems() -> the player's items (VORP shape)
exportAs('getInventoryItems', function()
    return await('MULTIinventory:vorp:items') or {}
end)

--- getInventoryItem(name) -> the first stack of that item, or nil
exportAs('getInventoryItem', function(name)
    if type(name) ~= 'string' then return nil end
    local low = name:lower()
    for _, it in pairs(await('MULTIinventory:vorp:items') or {}) do
        if it.name == name or it.name == low then return it end
    end
    return nil
end)

--- getServerItem(name | { names }) -> item definition(s) (label, weight, desc, metadata, ...)
exportAs('getServerItem', function(item)
    if type(item) ~= 'string' and type(item) ~= 'table' then return nil end
    return await('MULTIinventory:vorp:itemDB', item)
end)

--- closeInventory()
exportAs('closeInventory', function()
    TriggerEvent('MULTIinventory:client:close')
end)

-- ------------------------------------------------------------
-- Events from VORP scripts
-- ------------------------------------------------------------
RegisterNetEvent('vorp_inventory:CloseInv', function()
    TriggerEvent('MULTIinventory:client:close')
end)

-- server: TriggerClientEvent('vorp_inventory:blockInventory', src, state); client: TriggerEvent(...)
RegisterNetEvent('vorp_inventory:blockInventory', function(state)
    state = state and true or false
    if type(MIC) == 'table' then MIC.Blocked = state end   -- read by the UI (client/core)
    TriggerEvent('MULTIinventory:client:block', state)
    if state then TriggerEvent('MULTIinventory:client:close') end
end)

-- ------------------------------------------------------------
-- Events to VORP scripts
-- ------------------------------------------------------------
local invOpen = false

local function setOpen(open)
    open = open and true or false
    if open == invOpen then return end
    invOpen = open
    LocalPlayer.state:set('IsInvActive', open, false)
    TriggerServerEvent('MULTIinventory:vorp:invState', open)
    TriggerEvent('vorp_inventory:Client:OnInvStateChange', open)
end

AddEventHandler('MULTIinventory:client:stateChange', setOpen)

-- the UI keeps MIC.IsOpen; follow it as well, in case it fires no event
CreateThread(function()
    while true do
        Wait(250)
        if type(MIC) == 'table' then setOpen(MIC.IsOpen) end
    end
end)

-- component changes made by server scripts (server/vorp/20_weapons.lua)
local COMPONENT_EVENTS = { ['vorp_inventory:componentAdded'] = true, ['vorp_inventory:componentRemoved'] = true }
RegisterNetEvent('MULTIinventory:vorp:component', function(eventName, weaponId, component, category)
    if not COMPONENT_EVENTS[eventName] then return end
    TriggerEvent(eventName, weaponId, component, category)
    TriggerEvent('MULTIinventory:client:componentsChanged', weaponId)
end)

AddEventHandler('MULTIinventory:client:weaponEquipped', function(data)
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return end
    local name = data.name:upper()
    local hash = joaat(name)
    local components = data.comps or data.components or {}
    LocalPlayer.state:set(('GetEquippedWeaponData_%d'):format(hash), {
        weaponId = data.id,
        serialNumber = data.serie,
    }, false)
    if data.id then TriggerServerEvent('MULTIinventory:vorp:equipped', data.id, hash) end
    TriggerEvent('vorp_inventory:onWeaponEquipped', components, data.id, name, data.isDual and true or false, data.defaults or {})
end)
