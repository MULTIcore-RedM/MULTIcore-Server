-- ============================================================
-- MULTIwagons :: rsg-wagons answers (client)
-- Client events other scripts (radial menus, keybind scripts) fire on
-- rsg-wagons, from RSG v2's rsg-wagons client (GPL v3, Phil and mack /
-- Rexshack-RedM, see CREDITS.md):
--   rsg-wagons:client:callwagon -> "my wagons" at the dealer / call point here
--                                  (or anywhere with Config.CallAnywhere)
--   rsg-wagons:client:dellwagon -> puts the own wagon away (server rules apply)
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

RegisterNetEvent('rsg-wagons:client:callwagon', function()
    local here = MWClient.PointHere()
    if here then return MWClient.OpenMine(here) end
    if Config.CallAnywhere then return MWClient.OpenMine(nil) end
    exports.MULTIcore:Notify({ text = _L('err_too_far'), title = _L('title'), type = 'error' })
end)

RegisterNetEvent('rsg-wagons:client:dellwagon', function()
    local m = MWClient.Mine()
    if m then MWClient.PutAway(m.id) end
end)
