-- ============================================================
-- MULTIlaw :: client core
-- What happens to this player's own ped: handcuffs, being led, being
-- put in a wagon, law alerts on the map, hands-up reporting and the
-- badge. The server decides; this file only carries it out.
-- Handcuff controls, escort attach, alert blips and the badge follow
-- rsg-lawman (RSG v2, GPL v3); see CREDITS.md.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

LawC = {}
LawC.cuffed = false
LawC.hard = false
LawC.escortBy = nil
LawC.inVehicle = false

function LawC.Core() return RSGCore end

function LawC.notify(text, kind)
    if not text then return end
    exports.MULTIcore:Notify({ text = text, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end

--- shows a server answer table
function LawC.say(res)
    if type(res) == 'table' and res.msg then LawC.notify(res.msg, res.ok and 'success' or 'error') end
    return res
end

function LawC.pdata() return RSGCore.Functions.GetPlayerData() or {} end

--- may I use this law tool? (menus only; the server checks again)
function LawC.Can(action)
    local job = LawC.pdata().job
    if not job or not Config.LawTypes[job.type or ''] then return false end
    local allowed = Config.Permissions[action]
    if not allowed or not allowed[job.type] then return false end
    if Config.RequireOnDuty and not job.onduty then return false end
    return true
end

function LawC.IsLaw()
    local job = LawC.pdata().job
    return job ~= nil and Config.LawTypes[job.type or ''] == true
end

---------------------------------
-- handcuffs (controls from rsg-lawman)
---------------------------------
local blocked = {
    0x295175BF, 0x6E9734E8, 0xD8F73058, 0x4CC0E2FE, 0xDE794E3E, 0x06052D11, 0x5966D52A, 0xCEFD9220,
    0xC75C27B0, 0x41AC83D1, 0xADEAF48C, 0x9D2AEA88, 0xE474F150, 0xB2F377E8, 0xC1989F95, 0x07CE1E61,
    0xF84FA74F, 0xCEE12B50, 0x8FFC75D6, 0xD9D0E1C0, 0xF3830D8E, 0x80F28E95, 0xDB096B85, 0xE30CD707,
}

local function applyCuffs(on)
    local ped = PlayerPedId()
    if on then
        ClearPedTasksImmediately(ped)
        SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
        SetEnableHandcuffs(ped, true, false)
        SetPedCanPlayGestureAnims(ped, false, false)
        DisplayRadar(false)
        if LawC.hard then FreezeEntityPosition(ped, true) end
    else
        if not LawC.escortBy then DetachEntity(ped, true, false) end
        ClearPedTasksImmediately(ped)
        SetEnableHandcuffs(ped, false, false)
        SetPedCanPlayGestureAnims(ped, true, true)
        DisplayRadar(true)
        FreezeEntityPosition(ped, false)
    end
end

RegisterNetEvent('MULTIlaw:client:cuffed', function(on, hard)
    LawC.cuffed, LawC.hard = on == true, hard == true
    applyCuffs(LawC.cuffed)
    if not LawC.cuffed then
        LawC.escortBy = nil
        LawC.inVehicle = false
    end
    -- other scripts listen for this (rsg-lawman fired it on uncuff)
    TriggerEvent('hospital:client:isEscorted', LawC.escortBy ~= nil)
end)

CreateThread(function()
    while true do
        if LawC.cuffed or LawC.escortBy then
            Wait(0)
            for i = 1, #blocked do DisableControlAction(0, blocked[i], true) end
            if LawC.cuffed then
                local ped = PlayerPedId()
                DisablePlayerFiring(PlayerId(), true)
                if not IsPedCuffed(ped) and not LawC.inVehicle then SetEnableHandcuffs(ped, true, false) end
            end
        else
            Wait(500)
        end
    end
end)

---------------------------------
-- being led (rsg-lawman's attach)
---------------------------------
RegisterNetEvent('MULTIlaw:client:escort', function(officerSrc)
    local ped = PlayerPedId()
    if not officerSrc then
        LawC.escortBy = nil
        DetachEntity(ped, true, false)
        return
    end
    local player = GetPlayerFromServerId(officerSrc)
    if player == -1 then return end
    local officer = GetPlayerPed(player)
    if not DoesEntityExist(officer) then return end
    LawC.escortBy = officerSrc
    LawC.inVehicle = false
    local o = Config.Escort.Offset
    SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(officer, 0.0, o.y, 0.0))
    AttachEntityToEntity(ped, officer, Config.Escort.Bone, o.x, o.y, o.z, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
end)

---------------------------------
-- wagons and horses
---------------------------------
RegisterNetEvent('MULTIlaw:client:putIn', function(netId, kind)
    local ped = PlayerPedId()
    if not NetworkDoesNetworkIdExist(netId) then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(ent) then return end
    DetachEntity(ped, true, false)
    LawC.escortBy = nil
    ClearPedTasksImmediately(ped)
    if kind == 'mount' then
        SetPedOntoMount(ped, ent, Config.Vehicle.MountSeat, true)
        LawC.inVehicle = true
        return
    end
    local seats = GetVehicleMaxNumberOfPassengers(ent)
    for seat = seats - 1, 0, -1 do
        if IsVehicleSeatFree(ent, seat) then
            SetPedIntoVehicle(ped, ent, seat)
            LawC.inVehicle = true
            return
        end
    end
    LawC.notify(_L('no_seat'), 'error')
end)

RegisterNetEvent('MULTIlaw:client:takeOut', function(officerSrc)
    local ped = PlayerPedId()
    local player = GetPlayerFromServerId(officerSrc)
    local officer = player ~= -1 and GetPlayerPed(player) or 0
    ClearPedTasksImmediately(ped)
    if IsPedOnMount(ped) then Citizen.InvokeNative(0x5337B721C51883A9, ped, true, true) end -- _REMOVE_PED_FROM_MOUNT
    if officer ~= 0 and DoesEntityExist(officer) then
        SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(officer, 0.0, 1.0, 0.0))
    end
    LawC.inVehicle = false
    if LawC.cuffed then applyCuffs(true) end
end)

---------------------------------
-- hands up / hogtied / lassoed: this player's own client tells the server (for searches)
---------------------------------
CreateThread(function()
    local lastUp, lastTied
    while true do
        Wait(Config.Search.StateCheckMs)
        local ped = PlayerPedId()
        local up = IsEntityPlayingAnim(ped, Config.Search.HandsUpDict, Config.Search.HandsUpAnim, 3) == true
        local tied = (IsPedHogtied(ped) == 1 or IsPedHogtied(ped) == true) or (IsPedLassoed(ped) == 1 or IsPedLassoed(ped) == true)
        if up ~= lastUp then LocalPlayer.state:set('multilaw_handsup', up, true) lastUp = up end
        if tied ~= lastTied then LocalPlayer.state:set('multilaw_restrained', tied, true) lastTied = tied end
    end
end)

---------------------------------
-- law alerts (rsg-lawman's blips)
---------------------------------
local alerts = {}
local routeTo = nil

local function clearAlert(i)
    local a = alerts[i]
    if not a then return end
    if DoesBlipExist(a.blip) then RemoveBlip(a.blip) end
    if DoesBlipExist(a.ring) then RemoveBlip(a.ring) end
    if routeTo == a then
        ClearGpsMultiRoute()
        routeTo = nil
    end
    table.remove(alerts, i)
end

function LawC.ShowAlert(coords, text)
    if not LawC.Can('alerts') then return end
    coords = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    local A = Config.Alerts
    local blip = BlipAddForCoords(joaat(A.Style), coords.x, coords.y, coords.z)
    local ring = BlipAddForCoords(joaat(A.RingStyle), coords.x, coords.y, coords.z)
    SetBlipSprite(blip, joaat(A.Sprite), true)
    SetBlipSprite(ring, joaat(A.RingSprite), true)
    BlipAddModifier(blip, joaat(A.Modifier))
    BlipAddModifier(ring, joaat(A.Modifier))
    SetBlipScale(blip, A.Scale)
    SetBlipScale(ring, A.RingScale)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, text) -- _SET_BLIP_NAME
    Citizen.InvokeNative(0x9CB1A1623062F402, ring, text)
    local a = { blip = blip, ring = ring, coords = coords, untilT = GetGameTimer() + A.BlipSeconds * 1000 }
    alerts[#alerts + 1] = a
    if A.GPS then
        if routeTo then ClearGpsMultiRoute() end
        StartGpsMultiRoute(joaat('COLOR_GREEN'), true, true)
        AddPointToGpsMultiRoute(coords.x, coords.y, coords.z, false)
        SetGpsMultiRouteRender(true)
        routeTo = a
    end
    LawC.notify(_L('alert_in', text), 'police')
end

RegisterNetEvent('MULTIlaw:client:alert', function(coords, text) LawC.ShowAlert(coords, text) end)

CreateThread(function()
    while true do
        Wait(1000)
        if #alerts > 0 then
            local pos, now = GetEntityCoords(PlayerPedId()), GetGameTimer()
            for i = #alerts, 1, -1 do
                local a = alerts[i]
                if now > a.untilT or #(pos - a.coords) < Config.Alerts.RemoveWithin then clearAlert(i) end
            end
        end
    end
end)

--- client export: exports.MULTIlaw:Alert(coords, text) (the server checks the position and the cooldown)
exports('Alert', function(coords, text)
    coords = coords or GetEntityCoords(PlayerPedId())
    TriggerServerEvent('MULTIlaw:server:alert', { x = coords.x, y = coords.y, z = coords.z }, text)
    return true
end)
exports('IsCuffed', function() return LawC.cuffed end)

---------------------------------
-- badge (rsg-lawman's shop items)
---------------------------------
local badge = false
function LawC.ToggleBadge()
    if not Config.Badge.Enabled then return end
    if not LawC.IsLaw() then return LawC.notify(_L('not_law'), 'error') end
    if Config.RequireOnDuty and not (LawC.pdata().job or {}).onduty then return LawC.notify(_L('off_duty'), 'error') end
    local ped = PlayerPedId()
    local item = IsPedMale(ped) and Config.Badge.Male or Config.Badge.Female
    if not badge then
        Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, item, true, not IsPedMale(ped), true) -- ApplyShopItemToPed (as rsg-lawman)
        LawC.notify(_L('badge_on'), 'police')
    else
        Citizen.InvokeNative(0x0D7FFA1B2F69ED82, ped, item, 0, 0)                        -- RemoveShopItemFromPed
        LawC.notify(_L('badge_off'), 'police')
    end
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)                    -- UpdatePedVariation
    badge = not badge
end
if Config.Badge.Enabled and Config.Commands.Badge ~= '' then
    RegisterCommand(Config.Commands.Badge, LawC.ToggleBadge, false)
end

---------------------------------
-- after a resource restart: ask for the cuff and jail state again
---------------------------------
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() or not LocalPlayer.state.isLoggedIn then return end
    local md = LawC.pdata().metadata or {}
    if md.ishandcuffed then
        LawC.cuffed = true
        applyCuffs(true)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if LawC.cuffed then applyCuffs(false) end
    for i = #alerts, 1, -1 do clearAlert(i) end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    if LawC.cuffed then applyCuffs(false) end
    LawC.cuffed, LawC.escortBy, LawC.inVehicle = false, nil, false
end)
