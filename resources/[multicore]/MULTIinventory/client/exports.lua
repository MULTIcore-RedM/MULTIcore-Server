-- ============================================================
-- MULTIinventory :: client/exports.lua
--
-- Native part: exports.MULTIinventory:<Name>()
--   IsOpen() -> bool     Close()     Open()
--   GetItems() -> player grid item views     GetItem(name) -> first view of that item | nil
--   GetHotbar() -> hotbar view list
-- Compat part: getInventoryItems, getInventoryItem, getServerItem, closeInventory
-- go below, built on the same InvClient cache.
-- Clothing part adds PreviewClothing / ClearPreview in client/clothing.lua.
-- ============================================================

exports('IsOpen', function() return InvClient.isOpen() end)
exports('Close', function() if InvClient.isOpen() then InvClient.close() end end)
exports('Open', function() InvClient.open() end)
exports('GetItems', function() return InvClient.getItems() end)
exports('GetItem', function(name)
    for _, it in ipairs(InvClient.getItems()) do
        if it.name == name then return it end
    end
    return nil
end)
exports('GetHotbar', function() return InvClient.hotbar end)

-- ---- vorp_inventory face below ----
-- vorp_inventory-shaped client API + events, vorp_inventory face). Forwarded by the
-- vorp_inventory aliases (client/multi/faces.lua) as closeInventory,
-- getInventoryItems, getInventoryItem, getServerItem.
--   events emitted : vorp_inventory:Client:OnInvStateChange (bool)
--   events handled : vorp_inventory:blockInventory (bool)
-- Item views drop `slot` (kept as gridSlot): VORP-era callers read `item.slot or item.id` as the id.

local CompatC = {}

local function compatItem(it)
    if not it then return nil end
    local t = {}
    for k, v in pairs(it) do t[k] = v end
    t.mainid = t.id
    t.amount = t.count
    t.description = t.description or t.desc
    if t.slot ~= nil then t.gridSlot, t.slot = t.slot, nil end
    return t
end

exports('Compat_closeInventory', function()
    if InvClient.isOpen() then InvClient.close() end
    return true
end)

exports('Compat_getInventoryItems', function()
    local out = {}
    for _, it in ipairs(InvClient.getItems()) do
        if it.kind ~= 'weapon' then out[#out + 1] = compatItem(it) end
    end
    return out
end)

exports('Compat_getInventoryItem', function(name)
    for _, it in ipairs(InvClient.getItems()) do
        if it.name == name and it.kind ~= 'weapon' then return compatItem(it) end
    end
    return nil
end)

-- definitions asked from the server once, then cached (server action 'compat_itemdef')
local defCache = {}
exports('Compat_getServerItem', function(data)
    local name = type(data) == 'table' and (data.item or data.name) or data
    if type(name) ~= 'string' then return nil end
    if defCache[name] ~= nil then return defCache[name] or nil end
    local ok, def = InvClient.request('compat_itemdef', { name = name })
    defCache[name] = ok and def or false
    return ok and def or nil
end)

local function emitOn() return not (Config.Compat and Config.Compat.emitVorpEvents == false) end

-- open/close state for scripts listening to the vorp event
AddEventHandler('MULTIinventory:client:opened', function()
    if CompatC.blocked then InvClient.close() return end
    if emitOn() then TriggerEvent('vorp_inventory:Client:OnInvStateChange', true) end
end)
AddEventHandler('MULTIinventory:client:closed', function()
    if emitOn() then TriggerEvent('vorp_inventory:Client:OnInvStateChange', false) end
end)

-- block / unblock the inventory (local TriggerEvent or from the server)
RegisterNetEvent('vorp_inventory:blockInventory', function(state)
    CompatC.blocked = state == true
    if CompatC.blocked and InvClient.isOpen() then InvClient.close() end
end)

-- Not here on purpose (owned by other parts, firing them here would duplicate):
--   vorp_inventory:onWeaponEquipped + state bag GetEquippedWeaponData_<hash> -> client/weapons.lua
--   vorp_inventory:Server:SaddleOpen (horse netId)                         -> client/secondary.lua
--                                                                             (InvClient.saddlebag, UI button)
--   vorp_inventory:CloseInv                                                -> client/main.lua

InvCompatClient = CompatC
