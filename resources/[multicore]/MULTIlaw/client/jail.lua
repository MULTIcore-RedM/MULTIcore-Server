-- ============================================================
-- MULTIlaw :: serving time (this player's client)
-- Moves the prisoner in and out, shows the time left, keeps him in his
-- cell or on the Sisika grounds. The release time is the server's.
-- Sisika uniform from rsg-prison (RSG v2, GPL v3); see CREDITS.md.
-- ============================================================

local jail = nil   -- { center, radius, spot, untilT, prison }

local function fadeMove(spot)
    local ped = PlayerPedId()
    DoScreenFadeOut(Config.Jail.FadeMs)
    Wait(Config.Jail.FadeMs)
    DetachEntity(ped, true, false)
    ClearPedTasksImmediately(ped)
    SetEntityCoords(ped, spot.x, spot.y, spot.z - 0.9, false, false, false, false)
    if spot.w then SetEntityHeading(ped, spot.w) end
    Wait(500)
    DoScreenFadeIn(Config.Jail.FadeMs)
end

local function prisonOutfit()
    local ped = PlayerPedId()
    for _, cat in ipairs(Config.PrisonOutfit.remove) do
        RemoveShopItemFromPedByCategory(ped, cat, true, true, true)
    end
    for _, item in ipairs(IsPedMale(ped) and Config.PrisonOutfit.male or Config.PrisonOutfit.female) do
        ApplyShopItemToPed(ped, item, true, true, true)
    end
    RemoveAllPedWeapons(ped, true, true)
end

local function timerUi(seconds)
    SendNUIMessage({ action = 'timer', seconds = seconds, L = _LT(), lang = _LCode() })
end

function LawC.IsJailed() return jail ~= nil end
exports('IsJailed', function() return jail ~= nil end)

local function startJail(d)
    if type(d) ~= 'table' then return end
    jail = { center = vector3(d.center.x, d.center.y, d.center.z), radius = d.radius or 5.0, spot = d.spot, prison = d.prison,
        untilT = GetGameTimer() + (tonumber(d.seconds) or 0) * 1000 }
    LawC.cuffed, LawC.escortBy, LawC.inVehicle = false, nil, false
    if not d.keepPos or #(GetEntityCoords(PlayerPedId()) - jail.center) > jail.radius then fadeMove(d.spot) end
    if d.outfit then prisonOutfit() end
    timerUi(tonumber(d.seconds) or 0)
    TriggerEvent('MULTIlaw:client:jailStarted', d.prison and 'prison' or 'cell', tonumber(d.seconds) or 0)
end

RegisterNetEvent('MULTIlaw:client:jailed', function(d) CreateThread(function() startJail(d) end) end)

RegisterNetEvent('MULTIlaw:client:released', function(at, outfit)
    jail = nil
    SendNUIMessage({ action = 'timer', seconds = -1 })
    CreateThread(function()
        if at then fadeMove(at) end
        if outfit and GetResourceState('MULTIcore') == 'started' then pcall(function() exports.MULTIcore:ReloadLook() end) end
        TriggerEvent('MULTIlaw:client:jailEnded')
    end)
end)

-- keep the prisoner where he belongs (Config.Jail.AllowEscape = false)
CreateThread(function()
    while true do
        Wait(Config.Jail.EscapeCheckMs)
        if jail and not Config.Jail.AllowEscape then
            local pos = GetEntityCoords(PlayerPedId())
            if #(pos - jail.center) > jail.radius then
                LawC.notify(_L('no_escape'), 'police')
                fadeMove(jail.spot)
            end
        end
    end
end)

-- after a resource restart: ask the server for the sentence
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() or not LocalPlayer.state.isLoggedIn then return end
    CreateThread(function()
        Wait(1000)
        local d = lib.callback.await('MULTIlaw:jail:state', false)
        if d then startJail(d) end
    end)
end)

-- a respawn (hospital) must not let a prisoner out: ask again a moment later
AddEventHandler('MULTIcore:client:lookApplied', function(reason)
    if not jail or (reason ~= 'respawn' and reason ~= 'revive') then return end
    CreateThread(function()
        Wait(1500)
        local d = lib.callback.await('MULTIlaw:jail:state', false)
        if d then
            d.keepPos = true
            startJail(d)
        end
    end)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    jail = nil
    SendNUIMessage({ action = 'timer', seconds = -1 })
end)
