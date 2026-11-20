-- ============================================================
-- MULTIinventory :: redemrp_inventory face (client)
-- RedEM:RP scripts open a stash with the client event
-- redemrp_inventory:OpenStash(id, kg); the server checks who may open it.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

RegisterNetEvent('redemrp_inventory:OpenStash', function(id, kg)
    TriggerServerEvent('MULTIinventory:redem:openStash', id, kg)
end)

-- RedEM:RP's "open my satchel" event
RegisterNetEvent('redemrp_inventory:OpenInventory', function()
    ExecuteCommand(Config.OpenCommand or 'inventory')
end)
