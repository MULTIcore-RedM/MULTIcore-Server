-- ============================================================
-- MULTImedic :: rsg-medic client compatibility
-- Event names follow how the RSG v2 framework (GPL v3) and its scripts
-- (rsg-adminmenu, rsg-radialmenu ...) call rsg-medic; no code was copied.
-- Anything that changes life or death goes to the server first.
-- ============================================================

local dbg = MedicC.dbg

local function ignored(name) dbg('ignored rsg-medic client event ' .. name) end

-- revive / heal requests other scripts fire at a player (rsg-adminmenu: server and self revive)
RegisterNetEvent('rsg-medic:client:adminRevive', function() TriggerServerEvent('MULTImedic:server:compatRevive', 'adminRevive') end)
RegisterNetEvent('rsg-medic:client:playerRevive', function() TriggerServerEvent('MULTImedic:server:compatRevive', 'playerRevive') end)
RegisterNetEvent('rsg-medic:client:adminHeal', function() TriggerServerEvent('MULTImedic:server:compatRevive', 'adminHeal') end)

-- rsg-medic's own "respawn after [E]" event: ask the server (it checks the timer)
AddEventHandler('rsg-medic:client:revive', function()
    if MedicC.IsDead() then TriggerServerEvent('MULTImedic:server:respawn', GetEntityCoords(PlayerPedId())) end
end)

-- admin kill
RegisterNetEvent('rsg-medic:client:KillPlayer', function()
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, 0, 0)
end)

-- a doctor call sent by another script: (coords, text)
RegisterNetEvent('rsg-medic:client:medicAlert', function(coords, text) MedicC.ShowAlert(coords, text) end)

-- rsg-radialmenu medic buttons (local events): act on the nearest player
AddEventHandler('rsg-medic:client:RevivePlayer', function() MedicC.ReviveNearest() end)
AddEventHandler('rsg-medic:client:TreatWounds', function() MedicC.TreatNearest() end)

-- duty toggle (local event)
AddEventHandler('rsg-medic:client:ToggleDuty', function() TriggerServerEvent('RSGCore:ToggleDuty') end)

-- medic treated the patient (rsg-medic sent this to the patient after TreatWounds). The server
-- already updates injuries and sends MULTImedic:client:treated; nothing else to do here.
RegisterNetEvent('rsg-medic:client:HealInjuries', function() ignored('HealInjuries') end)

-- accepted and ignored: no office menu, supplies shop, storage, skeleton screen or death cam here
-- bandages are used from the satchel (client/items.lua); these old rsg-medic events stay ignored
RegisterNetEvent('rsg-medic:client:usebandage', function() ignored('usebandage') end)
RegisterNetEvent('rsg-medic:client:usefieldbandage', function() ignored('usefieldbandage') end)
RegisterNetEvent('rsg-medic:client:openSkeletonNUI', function() ignored('openSkeletonNUI') end)
AddEventHandler('rsg-medic:client:mainmenu', function() ignored('mainmenu') end)
AddEventHandler('rsg-medic:client:OpenMedicSupplies', function() ignored('OpenMedicSupplies') end)
AddEventHandler('rsg-medic:client:storage', function() ignored('storage') end)
AddEventHandler('rsg-medic:client:DeathCam', function() ignored('DeathCam') end)
AddEventHandler('rsg-medic:client:GetMedicsOnDuty', function() ignored('GetMedicsOnDuty') end)

-- exports['rsg-medic']:IsDead() for scripts that look for it under the old name
AddEventHandler('__cfx_export_rsg-medic_IsDead', function(setCB) setCB(function() return MedicC.IsDead() end) end)

-- VORP: a server script adds seconds to a downed player's respawn timer (seconds). Only while down;
-- capped by Config.Compat.MaxAddRespawnSeconds. Documented meaning only: it never shortens the timer.
RegisterNetEvent('vorp_core:Client:AddTimeToRespawn', function(seconds) MedicC.AddRespawnTime(seconds) end)
