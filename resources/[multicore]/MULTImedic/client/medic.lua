-- ============================================================
-- MULTImedic :: client medic actions (revive / treat) and doctor calls
-- The server checks job, duty, distance, the patient's state and the
-- time the action took; this file only plays the animation.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local N = {   -- natives (femga natives.json)
    TASK_START_SCENARIO_IN_PLACE_HASH = 0x524B54361229154F, -- (ped, scenarioHash, duration, playEnterAnim, conditionalHash, heading, p6)
    TASK_TURN_PED_TO_FACE_ENTITY      = 0x5AD23D40115353AC, -- (ped, target, duration, p3, p4, p5)
    CLEAR_PED_TASKS                   = 0xE1EF3C1216AFF2CD, -- (ped, BOOL, BOOL)
    BLIP_ADD_FOR_COORDS               = 0x554D9D53F696D002, -- (style, x, y, z)
    SET_BLIP_SPRITE                   = 0x74F74D3207ED525C, -- (blip, hash, BOOL)
    SET_BLIP_SCALE                    = 0xD38744167B2FA257, -- (blip, scale)
    BLIP_ADD_MODIFIER                 = 0x662D364ABF16DE2F, -- (blip, modifierHash)
    _SET_BLIP_NAME                    = 0x9CB1A1623062F402, -- (blip, name)
    START_GPS_MULTI_ROUTE             = 0x3D3D15AF7BCAAF83, -- (colorHash, onFoot, inVehicle)
    ADD_POINT_TO_GPS_MULTI_ROUTE      = 0x64C59DD6834FA942, -- (x, y, z, BOOL)
    SET_GPS_MULTI_ROUTE_RENDER        = 0x4426D65E029A4DC0, -- (toggle)
    CLEAR_GPS_MULTI_ROUTE             = 0x9E0AB9AAEE87CE28, -- ()
    NETWORK_GET_PLAYER_INDEX_FROM_PED = 0x6C0E2E0125610278, -- (ped) -> player
}

local busy = false

local function notify(text, kind) exports.MULTIcore:Notify({ text = text, type = kind or 'medic' }) end

local function amMedic()
    local d = RSGCore.Functions.GetPlayerData()
    local job = d and d.job
    if not job or not Config.MedicJobs[job.name] then return false end
    return (not Config.RequireOnDuty) or job.onduty == true
end

local function serverIdOf(ped)
    if not ped or ped == 0 or not IsPedAPlayer(ped) then return nil end
    local player = Citizen.InvokeNative(N.NETWORK_GET_PLAYER_INDEX_FROM_PED, ped, Citizen.ResultAsInteger())
    if not player or player == -1 then return nil end
    return GetPlayerServerId(player)
end

local function isDownState(serverId)
    local st = Player(serverId).state
    return st and st.isDead == true
end

--- nearest other player within the revive distance; wantDown = true for downed ones only
local function nearestPlayer(wantDown)
    local me = PlayerPedId()
    local pos = GetEntityCoords(me)
    local best, bestDist
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            local d = #(GetEntityCoords(ped) - pos)
            if d <= Config.Revive.MaxDistance and (not bestDist or d < bestDist) then
                local sid = GetPlayerServerId(pid)
                if (wantDown == nil) or (isDownState(sid) == wantDown) then best, bestDist = { ped = ped, id = sid }, d end
            end
        end
    end
    return best
end

--- Revive (kind 'revive') or treat (kind 'treat') the player with this server id and ped.
local function doAction(kind, targetId, targetPed)
    if busy or MedicC.IsDead() then return end
    if not amMedic() then return notify(_L('not_medic'), 'error') end
    if not targetId then return notify(_L('no_player'), 'error') end
    -- the server checks everything and remembers when we started
    if not lib.callback.await('MULTImedic:startAction', false, targetId, kind) then return end

    busy = true
    local ped = PlayerPedId()
    local time = kind == 'revive' and Config.Revive.Time or Config.Treat.Time
    if targetPed and targetPed ~= 0 then
        Citizen.InvokeNative(N.TASK_TURN_PED_TO_FACE_ENTITY, ped, targetPed, 1000, 0.0, 0.0, 0.0)
        Wait(800)
    end
    -- scenario from redm-info Scenarios.lua
    Citizen.InvokeNative(N.TASK_START_SCENARIO_IN_PLACE_HASH, ped, joaat(Config.Revive.Scenario), -1, true, 0, GetEntityHeading(ped), false)

    local done = lib.progressBar({
        duration = time,
        label = kind == 'revive' and _L('reviving') or _L('treating'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    Citizen.InvokeNative(N.CLEAR_PED_TASKS, ped, true, false)
    busy = false
    if done then
        TriggerServerEvent('MULTImedic:server:finishAction', targetId)
    else
        TriggerServerEvent('MULTImedic:server:cancelAction')
    end
end

function MedicC.ReviveNearest()
    local t = nearestPlayer(true)
    if not t then return notify(_L('nobody_down'), 'error') end
    doAction('revive', t.id, t.ped)
end

function MedicC.TreatNearest()
    local t = nearestPlayer(false)
    if not t then return notify(_L('no_player'), 'error') end
    doAction('treat', t.id, t.ped)
end

if Config.Revive.Command and Config.Revive.Command ~= '' then
    RegisterCommand(Config.Revive.Command, function() MedicC.ReviveNearest() end, false)
end
if Config.Treat.Command and Config.Treat.Command ~= '' then
    RegisterCommand(Config.Treat.Command, function() MedicC.TreatNearest() end, false)
end

-- MULTItarget on every player (only shown to medics). Waits for MULTItarget and
-- adds the options again when MULTItarget restarts (@MULTIcore/lib/interact.lua).
local playerTargetOn = false
if Config.Target.Enabled then
    MCI.Run('auto', function(mode)
        if mode ~= 'target' then return end
        exports.MULTItarget:addGlobalPlayer({
            {
                name = 'multimedic_revive',
                label = _L('target_revive'),
                icon = Config.Target.ReviveIcon,
                distance = Config.Target.Distance,
                canInteract = function(entity)
                    local sid = serverIdOf(entity)
                    return sid ~= nil and amMedic() and isDownState(sid)
                end,
                onSelect = function(data) CreateThread(function() doAction('revive', serverIdOf(data.entity), data.entity) end) end,
            },
            {
                name = 'multimedic_treat',
                label = _L('target_treat'),
                icon = Config.Target.TreatIcon,
                distance = Config.Target.Distance,
                canInteract = function(entity)
                    local sid = serverIdOf(entity)
                    return sid ~= nil and amMedic() and not isDownState(sid)
                end,
                onSelect = function(data) CreateThread(function() doAction('treat', serverIdOf(data.entity), data.entity) end) end,
            },
        })
        playerTargetOn = true
        MCI.Count('targets', 2)
    end, function(mode)
        if not playerTargetOn then return end
        playerTargetOn = false
        MCI.Count('targets', -2)
        if MCI.HasTarget() then
            pcall(function() exports.MULTItarget:removeGlobalPlayer({ 'multimedic_revive', 'multimedic_treat' }) end)
        end
    end)
end

-- ------------------------------------------------------------
-- doctor call blips
-- ------------------------------------------------------------
local alerts = {}   -- { blip, coords, untilT }
local routeOn = false

local function clearAlert(i)
    local a = alerts[i]
    if not a then return end
    if a.blip then RemoveBlip(a.blip) end
    table.remove(alerts, i)
    if routeOn and #alerts == 0 then
        Citizen.InvokeNative(N.CLEAR_GPS_MULTI_ROUTE)
        routeOn = false
    end
end

function MedicC.ShowAlert(coords, text)
    if type(coords) ~= 'vector3' then return end
    text = tostring(text or _L('alert_default'))
    local C = Config.Call
    notify(text, 'medic')
    local blip = Citizen.InvokeNative(N.BLIP_ADD_FOR_COORDS, C.BlipStyle, coords.x, coords.y, coords.z, Citizen.ResultAsInteger())
    if blip and blip ~= 0 then
        Citizen.InvokeNative(N.SET_BLIP_SPRITE, blip, C.BlipSprite, true)
        Citizen.InvokeNative(N.SET_BLIP_SCALE, blip, C.BlipScale + 0.0)
        if C.BlipModifier and C.BlipModifier ~= '' then Citizen.InvokeNative(N.BLIP_ADD_MODIFIER, blip, joaat(C.BlipModifier)) end
        Citizen.InvokeNative(N._SET_BLIP_NAME, blip, text)
    end
    if C.GpsRoute then
        Citizen.InvokeNative(N.START_GPS_MULTI_ROUTE, joaat(C.GpsColor), true, true)
        Citizen.InvokeNative(N.ADD_POINT_TO_GPS_MULTI_ROUTE, coords.x, coords.y, coords.z, false)
        Citizen.InvokeNative(N.SET_GPS_MULTI_ROUTE_RENDER, true)
        routeOn = true
    end
    alerts[#alerts + 1] = { blip = blip, coords = coords, untilT = GetGameTimer() + C.BlipSeconds * 1000 }
end

RegisterNetEvent('MULTImedic:client:alert', function(coords, text) MedicC.ShowAlert(coords, text) end)

CreateThread(function()
    while true do
        Wait(1000)
        if #alerts > 0 then
            local pos = GetEntityCoords(PlayerPedId())
            for i = #alerts, 1, -1 do
                local a = alerts[i]
                if GetGameTimer() > a.untilT or #(pos - a.coords) < Config.Call.ArriveDistance then clearAlert(i) end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i = #alerts, 1, -1 do clearAlert(i) end
end)
