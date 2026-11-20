-- ============================================================
-- MULTIconsumables :: drunk and withdrawal effects, blackout (client)
-- The server owns the drunk level and the withdrawal state; this file only shows them.
-- Natives called by hash have their names and hashes from femga natives.json.
-- ============================================================

local N = {
    SET_PED_DRUNKNESS = 0x406CCF555B04FAD3,       -- _SET_PED_DRUNKNESS(ped, enabled, level) (also rsg-consume)
    RESTART_SHAKE = 0xC3E9E5D4F413B773,           -- _RESTART_GAMEPLAY_CAM_SHAKE_WITH_NAME(name, intensity)
    STOP_SHAKE = 0x4285804FD65D8066,              -- _STOP_GAMEPLAY_CAM_SHAKING_WITH_NAME(name, p1)
    SET_PLAYER_LOCKON = 0x462AA1973CBBA75E,       -- SET_PLAYER_LOCKON(player, toggle)
}

local drunk = 0.0
local level = nil          -- the Config.Drunk.Levels entry in use (nil = sober)
local shown = {}           -- what is on screen now: postfx, camShake, lockoff, drunkness, ped
local withdrawal = { shake = 0.0, postfx = false, active = false }
local wPostfx = false
local aimShaking = false
local blackingOut = false
local loggedIn = false

local function levelFor(v)
    local best
    for _, L in ipairs(Config.Drunk.Levels) do
        if v >= L.min then best = L end
    end
    return best
end

local function stopFx(name) if name and AnimpostfxIsRunning(name) then AnimpostfxStop(name) end end

--- Puts the effects of the current drunk level on the player (only what changed).
local function applyDrunk(force)
    local ped = PlayerPedId()
    local L = (loggedIn and not blackingOut) and level or nil
    local fx = L and L.postfx or false
    local cam = L and L.camShake or 0.0
    local dk = L and L.drunkness or 0.0
    local lockoff = L and L.noLockon or false

    if force or shown.ped ~= ped or shown.drunkness ~= dk then
        Citizen.InvokeNative(N.SET_PED_DRUNKNESS, ped, dk > 0, dk + 0.0)
        shown.drunkness, shown.ped = dk, ped
    end
    if force or shown.postfx ~= fx then
        if shown.postfx and shown.postfx ~= fx then stopFx(shown.postfx) end
        if fx and not AnimpostfxIsRunning(fx) then AnimpostfxPlay(fx) end
        shown.postfx = fx
    end
    if force or shown.camShake ~= cam then
        if cam > 0 then
            Citizen.InvokeNative(N.RESTART_SHAKE, Config.Drunk.CamShakeName, cam + 0.0)
        else
            Citizen.InvokeNative(N.STOP_SHAKE, Config.Drunk.CamShakeName, false)
        end
        shown.camShake = cam
    end
    if force or shown.lockoff ~= lockoff then
        Citizen.InvokeNative(N.SET_PLAYER_LOCKON, PlayerId(), not lockoff)
        shown.lockoff = lockoff
    end
end

local function applyWithdrawal()
    local fx = (loggedIn and withdrawal.active) and withdrawal.postfx or false
    if wPostfx ~= fx then
        if wPostfx and wPostfx ~= shown.postfx then stopFx(wPostfx) end
        if fx and not AnimpostfxIsRunning(fx) then AnimpostfxPlay(fx) end
        wPostfx = fx
    end
end

local function clearAll()
    level, drunk = nil, 0.0
    withdrawal = { shake = 0.0, postfx = false, active = false }
    applyDrunk(true)
    applyWithdrawal()
    if aimShaking then Citizen.InvokeNative(N.STOP_SHAKE, Config.Drunk.AimShakeName, false) aimShaking = false end
end

RegisterNetEvent('MULTIconsumables:client:drunk', function(v)
    if GetInvokingResource() then return end
    drunk = tonumber(v) or 0.0
    level = levelFor(drunk)
    loggedIn = true
    applyDrunk(false)
end)

RegisterNetEvent('MULTIconsumables:client:withdrawal', function(flags)
    if GetInvokingResource() or type(flags) ~= 'table' then return end
    withdrawal = { shake = tonumber(flags.shake) or 0.0, postfx = flags.postfx or false, active = flags.active == true }
    applyWithdrawal()
end)

-- shaky aim, stumbling, keeping the effects on after a respawn
CreateThread(function()
    local nextStumble = 0
    while true do
        Wait(250)
        if loggedIn and not blackingOut then
            local ped = PlayerPedId()
            if shown.ped ~= ped then applyDrunk(true) end

            -- shaky hands while aiming (drunk or in withdrawal)
            local aim = math.max(level and level.aimShake or 0.0, withdrawal.active and withdrawal.shake or 0.0)
            if aim > 0 and IsPlayerFreeAiming(PlayerId()) then
                if not aimShaking then
                    Citizen.InvokeNative(N.RESTART_SHAKE, Config.Drunk.AimShakeName, aim + 0.0)
                    aimShaking = true
                end
            elseif aimShaking then
                Citizen.InvokeNative(N.STOP_SHAKE, Config.Drunk.AimShakeName, false)
                aimShaking = false
            end

            -- stumbles
            local now = GetGameTimer()
            if level and (level.stumble or 0) > 0 and now >= nextStumble then
                nextStumble = now + Config.Drunk.StumbleCheckSeconds * 1000
                if not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false) and not IsPedRagdoll(ped)
                    and not IsEntityDead(ped) and GetEntitySpeed(ped) >= Config.Drunk.StumbleMinSpeed
                    and math.random(100) <= level.stumble then
                    local r = Config.Drunk.StumbleRagdollMs
                    SetPedToRagdoll(ped, r[1], r[2], 0, false, false, false)
                end
            end
        end
    end
end)

---------------------------------
-- blackout
---------------------------------
local function playAnim(ped, dict, clip, flag, ms)
    if not dict or not DoesAnimDictExist(dict) then return end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, clip, 8.0, -8.0, ms or -1, flag or 1, 0, false, false, false)
        RemoveAnimDict(dict)
    end
end

RegisterNetEvent('MULTIconsumables:client:blackout', function()
    if GetInvokingResource() or blackingOut then return end
    blackingOut = true
    CreateThread(function()
        while blackingOut do               -- no moving about while passed out
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
    CreateThread(function()
        local B = Config.Drunk.Blackout
        local ped = PlayerPedId()
        applyDrunk(true)                   -- drunk effects off while out
        local onFoot = not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false)
        if B.Vomit and onFoot then
            ClearPedTasks(ped)
            playAnim(ped, B.VomitDict, B.VomitClip, 31, B.VomitMs)
            Wait(B.VomitMs)
        end
        AnimpostfxPlay(B.PassOutFx)
        DoScreenFadeOut(B.FadeOutMs)
        Wait(B.FadeOutMs)
        if onFoot then
            ClearPedTasksImmediately(ped)
            playAnim(ped, B.SleepDict, B.SleepClip, 1, -1)
        end
        Wait(B.BlackSeconds * 1000)
        AnimpostfxStop(B.PassOutFx)
        ClearPedTasks(ped)
        AnimpostfxPlay(B.WakeFx)
        DoScreenFadeIn(B.FadeInMs)
        blackingOut = false
        TriggerServerEvent('MULTIconsumables:server:wake')
        Wait(B.WakeFxMs)
        AnimpostfxStop(B.WakeFx)
        applyDrunk(true)
    end)
end)

---------------------------------
-- login / logout / restart
---------------------------------
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('MULTIconsumables:server:sync')
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    loggedIn = false
    clearAll()
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then
        TriggerServerEvent('MULTIconsumables:server:sync')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    loggedIn = false
    clearAll()
    if blackingOut then DoScreenFadeIn(500) end
end)
