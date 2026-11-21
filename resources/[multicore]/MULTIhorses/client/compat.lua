-- ============================================================
-- MULTIhorses :: client answers for scripts written for rsg-horses
-- MULTIhorses provides 'rsg-horses' (fxmanifest). Every client event of
-- MULTIhorses also answers under its rsg-horses name, and the exports
-- answer as exports['rsg-horses'].
-- Known callers: appearance scripts (rsg-horses:client:FleeHorse), radial
-- menus (rsg-horses:client:equipHorseLantern, inventoryHorse, gethorselocation),
-- wild horse / placer scripts (exports['rsg-horses']:CheckActiveHorse()).
-- ============================================================
local OLD = 'rsg-horses'

-- client events: the old name runs the MULTIhorses handler with the same arguments
local EVENTS = {
    'FleeHorse', 'SpawnHorse', 'equipHorseLantern', 'equipHorseHolster', 'inventoryHorse',
    'gethorselocation', 'stablemenu', 'storehorse', 'tradehorse', 'menu', 'MenuDel',
    'movehorse', 'breedhorse', 'custShop', 'OpenBuyHorse', 'OpenHorseShop',
    'playerfeedhorse', 'playerbrushhorse', 'revivehorse', 'horseXpUpdated',
    'equipRetrievedWeapon', 'horseWeaponInteract', 'shopPurchaseSuccess',
}
for _, name in ipairs(EVENTS) do
    RegisterNetEvent(OLD .. ':client:' .. name, function(...)
        TriggerEvent('MULTIhorses:client:' .. name, ...)
    end)
end

-- exports['rsg-horses']:CheckActiveHorse() / CheckHorseLevel() / CheckHorseBondingLevel()
local function exportAs(name, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(OLD, name), function(setCB) setCB(fn) end)
end
exportAs('CheckActiveHorse', function() return GetActiveHorsePed() end)
exportAs('CheckHorseLevel', function() return GetActiveHorseLevel() end)
exportAs('CheckHorseBondingLevel', function() return GetActiveHorseBondingLevel() end)
