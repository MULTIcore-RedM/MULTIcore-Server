-- ============================================================
-- MULTIemotes :: hands up and point keys
--   X  hands up  (hold; or press to raise / press again to lower, see Config.HandsUp.Hold)
--   B  point     (hold; or press to toggle, see Config.Point.Hold)
-- Both are upper-body animations, so the player can still walk.
-- While an emote plays, X stops the emote instead (Config.CancelKey).
-- By RINGO (RINGOscripting). GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local H, P = Config.HandsUp or {}, Config.Point or {}
local IS_PED_CUFFED = 0x74E559B3BC910685   -- femga natives.json
local IS_PED_HOGTIED = 0x3AA24CCC0D451379  -- femga natives.json
local ATTACK, AIM = 0x07CE1E61, 0xF84FA74F -- MOUSE1 / MOUSE2 (MULTIcore shared/keybinds.lua)
-- an animation started this frame isn't "playing" yet; without a short grace the
-- takeover check would reset the state at once
local GRACE_MS = 750

local function keyOf(name)
    if type(name) == 'number' then return name end
    return name and name ~= '' and RSGCore.Shared.Keybinds[name] or nil
end
local hKey, pKey = H.Enabled ~= false and keyOf(H.Key) or nil, P.Enabled ~= false and keyOf(P.Key) or nil
if not hKey and not pKey then return end

local handsUp, pointing = false, false
local handsUpAt, pointingAt = 0, 0
local suppress = false -- X stopped an emote: no hands up until X is let go

local function pressed(k) return IsControlJustPressed(0, k) or IsDisabledControlJustPressed(0, k) end
local function released(k) return IsControlJustReleased(0, k) or IsDisabledControlJustReleased(0, k) end
local function held(k) return IsControlPressed(0, k) or IsDisabledControlPressed(0, k) end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function play(def)
    if not loadDict(def.Dict) then return false end
    TaskPlayAnim(cache.ped, def.Dict, def.Anim, 4.0, -4.0, -1, def.Flag or 31, 0.0, false, false, false)
    return true
end

local function stop(def) StopAnimTask(cache.ped, def.Dict, def.Anim, 2.0) end

local function isTrue(v) return v == true or (type(v) == 'number' and v ~= 0) end

--- May the player use a gesture key now?
local function allowed()
    local ped = cache.ped
    if IsPauseMenuActive() or IsNuiFocused() then return false end
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedFalling(ped) then return false end
    if IsPedInAnyVehicle(ped, false) or IsPedOnMount(ped) or IsPedSwimming(ped) then return false end
    if IsPedUsingAnyScenario(ped) then return false end -- seated, lying, working
    if MEM.IsPlaying() or LocalPlayer.state.inv_busy then return false end -- in an emote, eating, crafting ...
    local okC, cuffed = pcall(Citizen.InvokeNative, IS_PED_CUFFED, ped, Citizen.ResultAsInteger())
    local okH, tied = pcall(Citizen.InvokeNative, IS_PED_HOGTIED, ped, Citizen.ResultAsInteger())
    if (okC and isTrue(cuffed)) or (okH and isTrue(tied)) then return false end
    return true
end

local function setHandsUp(on)
    if on then
        if pointing then stop(P); pointing = false end
        if H.Holster ~= false then SetCurrentPedWeapon(cache.ped, joaat('WEAPON_UNARMED'), true) end
        handsUp = play(H)
        handsUpAt = GetGameTimer()
    else
        stop(H)
        handsUp = false
    end
end

local function setPointing(on)
    if on then
        if handsUp then return end
        pointing = play(P)
        pointingAt = GetGameTimer()
    else
        stop(P)
        pointing = false
    end
end

--- Hold or toggle handling for one key.
local function drive(key, hold, active, set)
    if hold ~= false then
        if not active and held(key) and allowed() then set(true)
        elseif active and (released(key) or not held(key)) then set(false) end
    elseif pressed(key) and (active or allowed()) then
        set(not active)
    end
end

CreateThread(function()
    while true do
        Wait(0)
        local ped = cache.ped

        if hKey then
            -- X while an emote plays stops the emote (client/main.lua); don't also raise the hands
            -- (same for eating, crafting and other actions whose cancel key is X: they set inv_busy)
            if pressed(hKey) and (MEM.IsPlaying() or LocalPlayer.state.inv_busy
                or GetGameTimer() - (MEM.StoppedAt or 0) < 250) then suppress = true end
            if suppress and not held(hKey) then suppress = false end
            if not suppress then drive(hKey, H.Hold, handsUp, setHandsUp) end
        end
        if pKey then
            -- B is also the game's own satchel key: keep that shut so B only points
            if P.BlockGameKey ~= false then DisableControlAction(0, pKey, true) end
            drive(pKey, P.Hold, pointing, setPointing)
        end

        -- something else took over (an emote, a horse, death ...)
        local now = GetGameTimer()
        if handsUp and now - handsUpAt > GRACE_MS
            and (not IsEntityPlayingAnim(ped, H.Dict, H.Anim, 3) or IsPedOnMount(ped) or IsEntityDead(ped)) then
            handsUp = false
        end
        if pointing and now - pointingAt > GRACE_MS and not IsEntityPlayingAnim(ped, P.Dict, P.Anim, 3) then
            pointing = false
        end
        -- no shooting with the hands in the air
        if handsUp then
            DisableControlAction(0, ATTACK, true)
            DisableControlAction(0, AIM, true)
        end
    end
end)

--- Exports for other scripts.
exports('IsHandsUp', function() return handsUp end)
exports('IsPointing', function() return pointing end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if handsUp then stop(H) end
    if pointing then stop(P) end
end)
