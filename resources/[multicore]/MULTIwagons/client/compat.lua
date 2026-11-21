-- ============================================================
-- MULTIwagons :: answers under the old wagon script's names (client)
-- Client events other scripts (radial menus, keybind scripts) fire:
--   rsg-wagons:client:callwagon  -> calls your selected wagon
--   rsg-wagons:client:dellwagon  -> sends your wagon away
--   rsg-wagons:client:openStore (storeId) -> opens that dealer's page
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local OLD = 'rsg-wagons'

RegisterNetEvent(OLD .. ':client:callwagon', function() MWC.CallWagon() end)
RegisterNetEvent(OLD .. ':client:dellwagon', function() MWC.DeleteWagon() end)
AddEventHandler(OLD .. ':client:openStore', function(storeId)
    if type(storeId) == 'table' then storeId = storeId[1] end
    if Config.Stores[storeId] then MWC.OpenStore(storeId) end
end)
