-- ============================================================
-- MULTIcore :: VORP face - the client core object
-- exports.vorp_core:GetCore() on the client returns this. Written from
-- VORP's public docs (https://docs.vorp-core.com/api-reference/core);
-- no VORP code is used.
--
-- Character data: the server sets LocalPlayer.state.Character and
-- LocalPlayer.state.IsInSession (server/vorp/events.lua). Nothing to do here;
-- scripts read the state bag directly.
-- ============================================================

MULTI = MULTI or {}
MULTI.VorpClient = MULTI.VorpClient or {}
local VC = MULTI.VorpClient

-- Respawn points live in config_multi.lua (MULTIConfig.Vorp.RespawnPoints).
local RESPAWN_POINTS = MULTIConfig.Vorp.RespawnPoints

-- ------------------------------------------------------------
-- Natives (all present in femga natives.json)
-- ------------------------------------------------------------
local N = {
    NETWORK_RESURRECT_LOCAL_PLAYER = 0xEA23C49EAA83ACFB, -- (x, y, z, heading, int, BOOL, Any, BOOL)
    SET_ENTITY_HEALTH              = 0xAC2767ED8BDFAB15, -- (entity, amount, killedBy)
    GET_ENTITY_MAX_HEALTH          = 0x15D757606D170C3C, -- (entity, BOOL)
    CLEAR_PED_TASKS_IMMEDIATELY    = 0xAAA34F8A7CB32098, -- (ped, BOOL, resetCrouch)
    CLEAR_PED_BLOOD_DAMAGE         = 0x8FE22675A5A45817, -- (ped)
    SET_ATTRIBUTE_CORE_VALUE       = 0xC6258F41D86676E0, -- (ped, coreIndex 0 health / 1 stamina / 2 deadeye, value)
    RESTORE_PLAYER_STAMINA         = 0xC41F4B6E23FE6A4A, -- (player, float)
    REQUEST_COLLISION_AT_COORD     = 0x0A3720F162A033C9, -- (x, y, z)
    HAS_COLLISION_LOADED_AROUND_ENTITY = 0xBEB1600952B9CF5C, -- (entity)
    GET_PED_SOURCE_OF_DEATH        = 0x93C8B64DEB84728C, -- (ped) -> entity
    GET_PED_CAUSE_OF_DEATH         = 0x16FFE42AB2D2DC59, -- (ped) -> weapon hash
    IS_PED_A_PLAYER                = 0x12534C348C6CB68B, -- (ped)
    NETWORK_GET_PLAYER_INDEX_FROM_PED = 0x6C0E2E0125610278, -- (ped) -> player
}

local function fillHealth(ped)
    local max = Citizen.InvokeNative(N.GET_ENTITY_MAX_HEALTH, ped, false, Citizen.ResultAsInteger())
    Citizen.InvokeNative(N.SET_ENTITY_HEALTH, ped, (max and max > 0) and max or 600, 0)
    Citizen.InvokeNative(N.SET_ATTRIBUTE_CORE_VALUE, ped, 0, 100)
    Citizen.InvokeNative(N.SET_ATTRIBUTE_CORE_VALUE, ped, 1, 100)
    Citizen.InvokeNative(N.RESTORE_PLAYER_STAMINA, PlayerId(), 100.0)
    Citizen.InvokeNative(N.CLEAR_PED_BLOOD_DAMAGE, ped)
end

-- Brings the local player back to life at a point.
-- The last four arguments of NETWORK_RESURRECT_LOCAL_PLAYER are not named in
-- natives.json; the values follow the cfx spawnmanager call. UNVERIFIED meaning.
local function resurrectAt(x, y, z, heading)
    Citizen.InvokeNative(N.NETWORK_RESURRECT_LOCAL_PLAYER, x, y, z, heading, 1, true, 0, false)
    local ped = PlayerPedId()
    Citizen.InvokeNative(N.CLEAR_PED_TASKS_IMMEDIATELY, ped, false, true)
    return ped
end

local function heal()
    fillHealth(PlayerPedId())
    TriggerEvent('vorp_core:Client:OnPlayerHeal')
end

local function revive()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        ped = resurrectAt(c.x, c.y, c.z, GetEntityHeading(ped))
    end
    fillHealth(ped)
    TriggerEvent('vorp_core:Client:OnPlayerRevive')
end

local respawning = false
local function respawn(coords)
    if respawning then return end
    respawning = true
    CreateThread(function()
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local best, bestDist = RESPAWN_POINTS[1], math.huge
        if type(coords) == 'table' or type(coords) == 'vector4' or type(coords) == 'vector3' then
            best = vector4(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, (coords.w or coords.h or 0.0) + 0.0)  -- the caller chose the spot
        else
            for _, p in ipairs(RESPAWN_POINTS) do
                local d = #(pos - vector3(p.x, p.y, p.z))
                if d < bestDist then best, bestDist = p, d end
            end
        end

        DoScreenFadeOut(500)
        local t = GetGameTimer() + 2000
        while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end

        Citizen.InvokeNative(N.REQUEST_COLLISION_AT_COORD, best.x, best.y, best.z)
        ped = resurrectAt(best.x, best.y, best.z, best.w)
        SetEntityCoords(ped, best.x, best.y, best.z, false, false, false, false)
        SetEntityHeading(ped, best.w)
        t = GetGameTimer() + 5000
        while Citizen.InvokeNative(N.HAS_COLLISION_LOADED_AROUND_ENTITY, ped, Citizen.ResultAsInteger()) == 0
            and GetGameTimer() < t do
            Wait(0)
        end
        fillHealth(ped)

        DoScreenFadeIn(1000)
        respawning = false
        TriggerEvent('vorp_core:Client:OnPlayerRespawn')
        TriggerEvent('vorp:PlayerForceRespawn')          -- listened to by RINGOplayercore
        TriggerEvent('vorp_core:Client:OnPlayerSpawned')
    end)
end

-- Sent by server/vorp/core.lua (Core.Player.Heal / Revive / Respawn)
RegisterNetEvent('MULTIcore:vorp:heal', heal)
RegisterNetEvent('MULTIcore:vorp:revive', revive)
RegisterNetEvent('MULTIcore:vorp:respawn', respawn)

-- ------------------------------------------------------------
-- VORP client events from the docs
-- ------------------------------------------------------------
-- vorp_core:Client:OnPlayerSpawned once a character is in
RegisterNetEvent('vorp:SelectedCharacter', function()
    TriggerEvent('vorp_core:Client:OnPlayerSpawned')
end)

-- vorp_core:Client:OnPlayerDeath (killerServerId, causeOfDeath)
CreateThread(function()
    local wasDead = false
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local dead = IsEntityDead(ped)
        if dead and not wasDead then
            local killerId = 0
            local killer = Citizen.InvokeNative(N.GET_PED_SOURCE_OF_DEATH, ped, Citizen.ResultAsInteger())
            if killer and killer ~= 0 and killer ~= ped
                and Citizen.InvokeNative(N.IS_PED_A_PLAYER, killer, Citizen.ResultAsInteger()) ~= 0 then
                local player = Citizen.InvokeNative(N.NETWORK_GET_PLAYER_INDEX_FROM_PED, killer, Citizen.ResultAsInteger())
                killerId = GetPlayerServerId(player)
            end
            local cause = Citizen.InvokeNative(N.GET_PED_CAUSE_OF_DEATH, ped, Citizen.ResultAsInteger())
            TriggerEvent('vorp_core:Client:OnPlayerDeath', killerId, cause)
            TriggerServerEvent('MULTIcore:vorp:died', killerId, cause)  -- server fires vorp_core:Server:OnPlayerDeath
        end
        wasDead = dead
    end
end)

-- ------------------------------------------------------------
-- The core object
-- ------------------------------------------------------------
local Core

local function build()
    Core = {}
    for name, fn in pairs(VC.Notify or {}) do Core[name] = fn end
    Core.Callback = VC.Callback

    --- Puts the local player in an instance (VORP docs: own server id plus a
    --- number to be alone, a shared number to group players, 0 to leave).
    --- Needs the server handler for 'MULTIcore:vorp:instance' (not in the server face yet).
    function Core.instancePlayers(number)
        TriggerServerEvent('MULTIcore:vorp:instance', tonumber(number) or 0)
    end

    -- Local versions of the server's Core.Player (no source argument on the client).
    Core.Player = { Heal = heal, Revive = revive, Respawn = respawn }

    VC.Core = Core
    return Core
end

-- Built on first use: the Notify table comes from notify.lua, which loads after this file.
local function getCore()
    return Core or build()
end

MULTI.ExportAs('vorp_core', 'GetCore', getCore)
AddEventHandler('getCore', function(cb) if cb then cb(getCore()) end end) -- old form, mirrors the server face
