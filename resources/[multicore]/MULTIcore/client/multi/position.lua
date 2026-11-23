-- ============================================================
-- MULTIcore :: last-location position sync
-- The server cannot reliably read a remote ped's coordinates at save time
-- (spawn uses client-side SetEntityCoords), so the owning client sends them.
-- No-save areas are still validated by the server.
-- Picked up by fxmanifest's client/multi/*.lua wildcard.
-- ============================================================

local SEND_MS = math.max(1000, tonumber(MULTIConfig.PositionSyncMs) or 5000)

local function send(force)
    if not force and not LocalPlayer.state.isLoggedIn then return end
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) then return end
    local c = GetEntityCoords(ped)
    if not c or (c.x == 0.0 and c.y == 0.0 and c.z == 0.0) then return end
    TriggerServerEvent('MULTIcore:server:updatePosition', {
        x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped)
    })
end

-- send again shortly after each spawn, once the world/collision has settled
local function afterSpawn()
    SetTimeout(300, function() send(true) end)
    SetTimeout(1500, function() send(true) end)
end

RegisterNetEvent('MULTIcharacter:client:spawned', afterSpawn)
RegisterNetEvent('MULTIcore:spawned', afterSpawn)
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', afterSpawn)

-- one last update before the server's logout save
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() send(true) end)

CreateThread(function()
    while true do
        Wait(SEND_MS)
        send(false)
    end
end)
