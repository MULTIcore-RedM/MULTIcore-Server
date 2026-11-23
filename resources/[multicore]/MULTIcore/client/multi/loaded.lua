-- ============================================================
-- MULTIcore :: "player is in the world" for RSG scripts
-- On an RSG server rsg-spawn fires RSGCore:Client:OnPlayerLoaded (client)
-- and RSGCore:Server:OnPlayerLoaded (server) once the character stands in
-- the world. MULTIcore fires them itself, so RSG scripts (and everything
-- that checks LocalPlayer.state.isLoggedIn) work whichever spawn flow runs.
--
-- Fired once per login, at the first of:
--   * MULTIcharacter:client:spawned   (MULTIcharacter finished the spawn)
--   * MULTIcore:spawned               (any other spawn script can fire this)
--   * a fallback timer after the character was selected, when no spawn
--     script is running at all
-- ============================================================

local firedForLogin = false
local loginToken = 0

local function fireLoaded()
    if firedForLogin then return end
    firedForLogin = true
    TriggerEvent('RSGCore:Client:OnPlayerLoaded')
    TriggerServerEvent('RSGCore:Server:OnPlayerLoaded')
    -- cfx spawnmanager's 'playerSpawned', which older RedEM:RP and standalone scripts wait for
    -- (redemrp_propplacer); spawnmanager fires it itself when it runs
    if GetResourceState('spawnmanager') ~= 'started' then
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        TriggerEvent('playerSpawned', { x = c.x, y = c.y, z = c.z, heading = GetEntityHeading(ped) })
    end
end

-- a new character was selected: arm for one firing
RegisterNetEvent('MULTIcore:client:characterSelected', function()
    firedForLogin = false
    loginToken = loginToken + 1
    local token = loginToken
    -- no spawn script running: fire after a short wait so the core's player data has arrived
    if GetResourceState('MULTIcharacter') ~= 'started' then
        SetTimeout(MULTIConfig.SpawnFallbackMs or 2000, function()
            if token == loginToken then fireLoaded() end
        end)
    end
end)

AddEventHandler('MULTIcharacter:client:spawned', fireLoaded)
AddEventHandler('MULTIcore:spawned', fireLoaded)

-- back to character select: the next login fires again
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    firedForLogin = false
end)
