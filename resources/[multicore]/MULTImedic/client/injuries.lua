-- ============================================================
-- MULTImedic :: simple injuries (Config.Injuries.Enabled, default off)
-- A big health drop counts as a hit on a random body part (the server
-- decides whether it gets worse). A hurt leg means walking only; a
-- bleeding part costs health now and then. Treatment and revives heal.
-- ============================================================

if not Config.Injuries.Enabled then return end

local RSGCore = exports['rsg-core']:GetCoreObject()
local I = Config.Injuries

local N = {   -- natives (femga natives.json)
    SET_PED_MAX_MOVE_BLEND_RATIO = 0x433083750C5E064A, -- (ped, value); per frame
    _FAKE_SET_PED_LOCO_INJURED   = 0x8B3CB08158E98481, -- (ped, enabled) -- name verified, visible effect UNVERIFIED
}

local injuries = nil   -- latest table from the server
local limp, bleeding = false, false

local function apply(inj)
    injuries = type(inj) == 'table' and inj or nil
    limp, bleeding = false, false
    if injuries then
        for part, state in pairs(injuries) do
            if state == 'bleeding' then bleeding = true end
            if I.LimpOnLegs and (part == 'left_leg' or part == 'right_leg') and state ~= 'healthy' then limp = true end
        end
    end
    LocalPlayer.state:set('isInjured', limp or bleeding, true)
    Citizen.InvokeNative(N._FAKE_SET_PED_LOCO_INJURED, PlayerPedId(), limp)
end

-- the server sends this (same event rsg-medic uses): (targetSrc, injuries, patientName)
RegisterNetEvent('rsg-medic:client:updateInjuries', function(targetSrc, inj)
    if tonumber(targetSrc) == GetPlayerServerId(PlayerId()) then apply(inj) end
end)

RegisterNetEvent('MULTIcore:client:characterSelected', function()
    local d = RSGCore.Functions.GetPlayerData()
    apply(d and d.metadata and d.metadata.injuries)
end)

-- hits
CreateThread(function()
    local last, lastPed = nil, nil
    local parts = I.Parts
    while true do
        Wait(250)
        local ped = PlayerPedId()
        if LocalPlayer.state.isLoggedIn and not MedicC.IsDead() then
            local h = GetEntityHealth(ped)
            if ped ~= lastPed then lastPed, last = ped, h end
            if h > 0 and last and last - h >= I.DamageThreshold then
                TriggerServerEvent('MULTImedic:server:bodyHit', parts[math.random(#parts)])
            end
            last = h
        else
            last = nil
        end
    end
end)

-- limp: cap the move speed every frame while a leg is hurt
CreateThread(function()
    while true do
        if limp and not MedicC.IsDead() then
            Citizen.InvokeNative(N.SET_PED_MAX_MOVE_BLEND_RATIO, PlayerPedId(), I.LimpMaxMoveBlend + 0.0)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- bleeding
CreateThread(function()
    while true do
        Wait(I.BleedInterval * 1000)
        if bleeding and not MedicC.IsDead() and LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            local h = GetEntityHealth(ped)
            if h > 0 then
                SetEntityHealth(ped, math.max(0, h - I.BleedDamage), 0)
                exports.MULTIcore:Notify({ text = _L('bleeding'), type = 'warning', duration = 3000 })
            end
        end
    end
end)
