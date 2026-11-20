-- ============================================================
-- MULTImedic :: client death screen, respawn and revive handling
-- Death comes from MULTIcore's vorp_core:Client:OnPlayerDeath (the core
-- already watches for it) with a slow check of our own as a fallback.
-- The server owns the death state; this file only shows it.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

MedicC = MedicC or {}

local N = {   -- natives (femga natives.json)
    NETWORK_RESURRECT_LOCAL_PLAYER     = 0xEA23C49EAA83ACFB, -- (x, y, z, heading, int, BOOL, Any, BOOL)
    SET_ATTRIBUTE_CORE_VALUE           = 0xC6258F41D86676E0, -- (ped, coreIndex, value)
    GET_ENTITY_MAX_HEALTH              = 0x15D757606D170C3C, -- (entity, BOOL)
    CLEAR_PED_BLOOD_DAMAGE             = 0x8FE22675A5A45817, -- (ped)
    CLEAR_PED_TASKS_IMMEDIATELY        = 0xAAA34F8A7CB32098, -- (ped, BOOL, resetCrouch)
    REQUEST_COLLISION_AT_COORD         = 0x0A3720F162A033C9, -- (x, y, z)
    HAS_COLLISION_LOADED_AROUND_ENTITY = 0xBEB1600952B9CF5C, -- (entity)
    REMOVE_ALL_PED_WEAPONS             = 0xF25DF915FA38C5F3, -- (ped, BOOL, BOOL)
    PAUSE_DEATH_ARREST_RESTART         = 0x66AB6B6C7E72F393, -- (toggle)
}
local CORE_HEALTH = 0  -- eAttributeCore health

local S = {
    dead = false,
    diedAt = 0,          -- GetGameTimer() of the death
    medics = 0,
    callReadyAt = 0,     -- GetGameTimer() when the next doctor call is allowed
    respawnAsked = 0,    -- GetGameTimer() of the last respawn request
    extra = 0,           -- seconds other scripts added to this death's respawn timer (vorp_core:Client:AddTimeToRespawn)
    cursor = false,
    aliveAt = 0,         -- GetGameTimer() of the last revive / respawn (no new death is taken for a short while after)
    moving = false,      -- true while MULTImedic's own respawn moves and resurrects the player
}

-- After a revive or respawn the body can still read as dead for a moment (fade, resurrect, collision).
-- No new death is taken in that time, or the unconscious screen would come straight back.
local ALIVE_GRACE_MS = 8000

local function key(name) return RSGCore.Shared.Keybinds[name] end

local function dbg(...) if Config.Debug then print('[MULTImedic]', ...) end end
MedicC.dbg = dbg

function MedicC.IsDead() return S.dead end

--- Sets health to a percent of max and the health core to match.
function MedicC.SetHealthPercent(pct)
    pct = math.max(1, math.min(100, tonumber(pct) or 100))
    local ped = PlayerPedId()
    local max = Citizen.InvokeNative(N.GET_ENTITY_MAX_HEALTH, ped, false, Citizen.ResultAsInteger())
    if not max or max <= 0 then max = 600 end
    SetEntityHealth(ped, math.max(1, math.floor(max * pct / 100)), 0)
    Citizen.InvokeNative(N.SET_ATTRIBUTE_CORE_VALUE, ped, CORE_HEALTH, math.floor(pct))
end

local function stopAutoSpawn()
    if Config.DisableAutoSpawn and GetResourceState('spawnmanager') == 'started' then
        pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    end
    if Config.PauseDeathRestart then
        Citizen.InvokeNative(N.PAUSE_DEATH_ARREST_RESTART, true) -- UNVERIFIED effect in multiplayer
    end
end

-- ------------------------------------------------------------
-- NUI
-- ------------------------------------------------------------
local function remaining()
    local left = Config.RespawnTimer + S.extra - math.floor((GetGameTimer() - S.diedAt) / 1000)
    return math.max(0, left)
end

local function callLeft()
    return math.max(0, math.ceil((S.callReadyAt - GetGameTimer()) / 1000))
end

local function openScreen()
    S.cursor = Config.Screen.Cursor and Config.Call.Enabled
    SendNUIMessage({
        action = 'open',
        L = _LT(),
        lang = _LCode(),
        total = Config.RespawnTimer + S.extra,
        remaining = remaining(),
        hold = Config.HoldSeconds,
        fee = Config.Screen.ShowFee and Config.Respawn.Fee or 0,
        call = Config.Call.Enabled,
        showMedics = Config.Screen.ShowMedicCount,
        medics = S.medics,
        cursor = S.cursor,
        keys = { respawn = Config.RespawnKey, call = Config.CallKey },
    })
    if S.cursor then
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)   -- keep game keys (hold E) working with the cursor shown
    end
end

local function closeScreen()
    SendNUIMessage({ action = 'close' })
    if S.cursor then
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
        S.cursor = false
    end
end

-- ------------------------------------------------------------
-- doctor call and respawn requests
-- ------------------------------------------------------------
local function callDoctor()
    if not S.dead or not Config.Call.Enabled then return end
    if GetGameTimer() < S.callReadyAt then return end
    S.callReadyAt = GetGameTimer() + Config.Call.Cooldown * 1000
    SendNUIMessage({ action = 'call', state = 'sending' })
    TriggerServerEvent('MULTImedic:server:callDoctor')
end

RegisterNUICallback('callDoctor', function(_, cb)
    callDoctor()
    cb({ ok = true })
end)

RegisterNetEvent('MULTImedic:client:callResult', function(ok, reason)
    SendNUIMessage({ action = 'call', state = ok and 'sent' or reason or 'none', cooldown = callLeft() })
end)

local function askRespawn()
    if GetGameTimer() - S.respawnAsked < 5000 then return end
    S.respawnAsked = GetGameTimer()
    TriggerServerEvent('MULTImedic:server:respawn', GetEntityCoords(PlayerPedId()))
end

-- ------------------------------------------------------------
-- death
-- ------------------------------------------------------------
local function refreshMedics()
    if not Config.Screen.ShowMedicCount then return end
    local ok, n = pcall(function() return lib.callback.await('MULTImedic:medicCount', false) end)
    if ok and type(n) == 'number' then S.medics = n end
end

local function deadLoop()
    CreateThread(function()
        local lastTick, lastMedics, holdFrom, lastHoldSent = 0, 0, nil, 0
        local kRespawn, kCall = key(Config.RespawnKey), key(Config.CallKey)
        while S.dead do
            local now = GetGameTimer()
            local left = remaining()

            if now - lastMedics > 15000 then
                lastMedics = now
                CreateThread(refreshMedics)
            end
            if now - lastTick >= 1000 then
                lastTick = now
                SendNUIMessage({ action = 'tick', remaining = left, medics = S.medics, cooldown = callLeft() })
            end

            if kCall and (IsControlJustPressed(0, kCall) or IsDisabledControlJustPressed(0, kCall)) then
                callDoctor()
            end

            if left == 0 and kRespawn then
                if IsControlPressed(0, kRespawn) or IsDisabledControlPressed(0, kRespawn) then
                    holdFrom = holdFrom or now
                    local p = math.min(1.0, (now - holdFrom) / (Config.HoldSeconds * 1000))
                    if now - lastHoldSent > 50 then
                        lastHoldSent = now
                        SendNUIMessage({ action = 'hold', progress = p })
                    end
                    if p >= 1.0 then
                        holdFrom = nil
                        askRespawn()
                    end
                elseif holdFrom then
                    holdFrom = nil
                    SendNUIMessage({ action = 'hold', progress = 0 })
                end
            end
            Wait(0)
        end
    end)
end

local function onDeath(killerId, cause)
    if S.dead or not LocalPlayer.state.isLoggedIn then return end
    -- just revived / respawning: the body may not be up yet; a real death is picked up by the check below after the grace
    if S.moving or GetGameTimer() - S.aliveAt < ALIVE_GRACE_MS then return end
    S.dead = true
    S.diedAt = GetGameTimer()
    S.callReadyAt = 0
    S.respawnAsked = 0
    S.extra = 0
    stopAutoSpawn()
    TriggerServerEvent('MULTImedic:server:died', killerId or 0, cause)
    TriggerEvent('MULTImedic:client:onDeath', killerId or 0, cause)
    refreshMedics()
    openScreen()
    deadLoop()
    dbg('dead', killerId, cause)
end

-- MULTIcore's VORP face fires this once per death (killer server id, cause of death hash)
AddEventHandler('vorp_core:Client:OnPlayerDeath', function(killerId, cause) onDeath(killerId, cause) end)

--- Called when the server says the player is alive again (revive, respawn, admin).
local function closeDeath()
    S.aliveAt = GetGameTimer()
    if not S.dead then return end
    S.dead = false
    closeScreen()
    TriggerEvent('MULTImedic:client:onRevive')
    dbg('alive')
end

-- fallback check, in case the core event did not reach us;
-- and a safety net: the screen never stays up on a living player the server no longer counts as dead
CreateThread(function()
    stopAutoSpawn()
    local aliveSince = nil
    while true do
        Wait(Config.DeathCheckMs)
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            local bodyDead = IsEntityDead(ped) or GetEntityHealth(ped) <= 0
            if not S.dead then
                if bodyDead then onDeath(0, nil) end
            elseif not bodyDead and not S.moving then
                local data = RSGCore.Functions.GetPlayerData()
                local serverDead = data and data.metadata and data.metadata.isdead == true
                if serverDead then
                    aliveSince = nil
                else
                    aliveSince = aliveSince or GetGameTimer()
                    if GetGameTimer() - aliveSince > 3000 then
                        aliveSince = nil
                        dbg('alive and not dead on the server: closing the screen')
                        closeDeath()
                    end
                end
            else
                aliveSince = nil
            end
        end
    end
end)
MedicC.CloseDeath = closeDeath

--- Adds seconds to the current death's respawn timer (only while down; the server keeps the same count).
function MedicC.AddRespawnTime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    if not S.dead or seconds <= 0 then return false end
    local max = tonumber(Config.Compat.MaxAddRespawnSeconds) or 0
    if max > 0 then seconds = math.min(seconds, math.max(0, max - S.extra)) end
    if seconds <= 0 then return false end
    S.extra = S.extra + seconds
    TriggerServerEvent('MULTImedic:server:addRespawnTime', seconds)
    SendNUIMessage({ action = 'tick', remaining = remaining(), medics = S.medics, cooldown = callLeft() })
    dbg('respawn timer +' .. seconds)
    return true
end

RegisterNetEvent('MULTImedic:client:closeDeath', closeDeath)
RegisterNetEvent('MULTIcore:vorp:revive', closeDeath)   -- the core's revive (also MULTIadmin)
RegisterNetEvent('MULTIcore:vorp:respawn', closeDeath)  -- the core's respawn

-- after a core revive / respawn: wait until the ped is up, then set the health percent
RegisterNetEvent('MULTImedic:client:afterRevive', function(pct)
    CreateThread(function()
        local t = GetGameTimer() + 10000
        while GetGameTimer() < t and (IsEntityDead(PlayerPedId()) or not IsScreenFadedIn()) do Wait(100) end
        Wait(300)
        local ped = PlayerPedId()
        if IsEntityDead(ped) then return end
        SetEntityInvincible(ped, false)
        MedicC.SetHealthPercent(pct)
    end)
end)

-- own respawn at the doctor (Config.Respawn.UseCoreRespawn = false)
RegisterNetEvent('MULTImedic:client:respawnAt', function(c, pct)
    if type(c) ~= 'vector4' then return end
    S.moving = true   -- no new death while the body is moved and brought back
    CreateThread(function()
        local R = Config.Respawn
        DoScreenFadeOut(R.FadeMs)
        local t = GetGameTimer() + 3000
        while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end

        Citizen.InvokeNative(N.REQUEST_COLLISION_AT_COORD, c.x, c.y, c.z)
        -- last four arguments: same values as MULTIcore's own respawn (meaning UNVERIFIED, not named in natives.json)
        Citizen.InvokeNative(N.NETWORK_RESURRECT_LOCAL_PLAYER, c.x, c.y, c.z, c.w, 1, true, 0, false)
        local ped = PlayerPedId()
        Citizen.InvokeNative(N.CLEAR_PED_TASKS_IMMEDIATELY, ped, false, true)
        SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
        SetEntityHeading(ped, c.w)
        t = GetGameTimer() + 5000
        while Citizen.InvokeNative(N.HAS_COLLISION_LOADED_AROUND_ENTITY, ped, Citizen.ResultAsInteger()) == 0
            and GetGameTimer() < t do
            Wait(0)
        end
        SetEntityInvincible(ped, false)
        Citizen.InvokeNative(N.CLEAR_PED_BLOOD_DAMAGE, ped)
        if R.LoseWeapons then Citizen.InvokeNative(N.REMOVE_ALL_PED_WEAPONS, ped, true, true) end
        MedicC.SetHealthPercent(pct)

        if R.ResetOutlawStatus then TriggerServerEvent('rsg-prison:server:resetoutlawstatus') end
        if R.ReloadLook then pcall(function() exports.MULTIcore:ReloadLook() end) end

        -- alive again: now the unconscious screen goes (behind the fade)
        S.moving = false
        closeDeath()
        DoScreenFadeIn(R.FadeMs * 2)
        -- the core's own respawn fires this; MULTImedic moved the player itself, so it fires it once here
        TriggerEvent('vorp_core:Client:OnPlayerRespawn')
    end)
end)

-- a medic treated our wounds: add health
RegisterNetEvent('MULTImedic:client:treated', function(pct)
    if S.dead then return end
    local ped = PlayerPedId()
    local max = Citizen.InvokeNative(N.GET_ENTITY_MAX_HEALTH, ped, false, Citizen.ResultAsInteger())
    if not max or max <= 0 then max = 600 end
    local now = GetEntityHealth(ped)
    local add = math.floor(max * (tonumber(pct) or 0) / 100)
    SetEntityHealth(ped, math.min(max, now + add), 0)
    Citizen.InvokeNative(N.CLEAR_PED_BLOOD_DAMAGE, ped)
end)

-- admin /kill and the export
RegisterNetEvent('MULTImedic:client:kill', function()
    local ped = PlayerPedId()
    SetEntityInvincible(ped, false)
    SetEntityHealth(ped, 0, 0)
end)

-- ------------------------------------------------------------
-- logout / relog while dead
-- ------------------------------------------------------------
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    S.dead = false
    closeScreen()
end)

RegisterNetEvent('MULTIcore:client:characterSelected', function()
    if not Config.KeepDeadOnRelog then return end
    CreateThread(function()
        Wait(Config.RelogDelayMs)
        local data = RSGCore.Functions.GetPlayerData()
        if data and data.metadata and data.metadata.isdead and not S.dead then
            local ped = PlayerPedId()
            SetEntityInvincible(ped, false)
            SetEntityHealth(ped, 0, 0)   -- the death check above takes it from here
            dbg('relogged while dead, put back down')
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if S.cursor then SetNuiFocusKeepInput(false) SetNuiFocus(false, false) end
end)

exports('IsDead', function() return S.dead end)
