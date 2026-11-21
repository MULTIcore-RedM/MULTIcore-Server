-- ============================================================
-- MULTIcoroner :: client
-- Hold Left Alt (MULTItarget) on a dead person or animal: "Perform inquest".
-- Fill in the form, file it, and read it back from the ledger (/inquests) or a printed copy.
-- Based on phils-coroner by Phil. Part of MULTIcore (GPL v3).
-- No marker dots or sprites are ever drawn in the world.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local IsUIOpen = false
local IsAllowed = false
local CurrentCase = nil
local CorpseSeen = {}
local CorpseZones = {}
local LastDebugLog = {}
local PedTargetName = 'MULTIcoroner:inquest_ped'
local PlayerTargetName = 'MULTIcoroner:inquest_player'

local function Debug(message)
    if Config.Debug then print('[MULTIcoroner] ' .. message) end
end

-- RedM client Lua has no os library: use the network clock.
local function Now()
    local ok, value = pcall(GetCloudTimeAsInt)
    return ok and value or 0
end

local function FormatTimestamp(timestamp)
    if not timestamp or timestamp <= 0 then return '' end
    local minutes = math.floor(timestamp / 60) % 60
    local hours = math.floor(timestamp / 3600) % 24
    local days = math.floor(timestamp / 86400)
    local year, month = 1970, 1
    local monthDays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    while true do
        local leap = (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
        local daysInYear = leap and 366 or 365
        if days < daysInYear then break end
        days = days - daysInYear
        year = year + 1
    end
    if (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) then monthDays[2] = 29 end
    while days >= monthDays[month] do
        days = days - monthDays[month]
        month = month + 1
    end
    return ('%04d-%02d-%02d %02d:%02d'):format(year, month, days + 1, hours, minutes)
end

-- ------------------------------------------------------------
-- access (the server decides; the client only uses it to show the option)
-- ------------------------------------------------------------
local function HasAccess() return IsAllowed end

RegisterNetEvent('MULTIcoroner:client:access', function(allowed)
    IsAllowed = allowed == true
    Debug('access ' .. tostring(IsAllowed))
end)

local function AskAccess() TriggerServerEvent('MULTIcoroner:server:checkAccess') end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', AskAccess)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', AskAccess)
RegisterNetEvent('RSGCore:Client:SetDuty', function() Wait(250) AskAccess() end)

CreateThread(function()
    Wait(2500)
    AskAccess()
    while true do
        Wait(30000)  -- picks up ace changes made while connected
        AskAccess()
    end
end)

-- ------------------------------------------------------------
-- the page
-- ------------------------------------------------------------
local function Focus(on)
    IsUIOpen = on
    SetNuiFocus(on, on)
end

local function CloseUI()
    if not IsUIOpen then return end
    CurrentCase = nil
    Focus(false)
    SendNUIMessage({ action = 'close' })
end

local function manners()
    local list = {}
    for i, code in ipairs(Config.Manners or { 'UNDETERMINED' }) do list[i] = code end
    return list
end

local function OpenCaseUI(caseData)
    CurrentCase = caseData
    Focus(true)
    SendNUIMessage({ action = 'openCase', caseData = caseData, time = FormatTimestamp(Now()), manners = manners(), text = _LT(), lang = _LCode() })
end

RegisterNetEvent('MULTIcoroner:client:openReports', function(reports)
    CurrentCase = nil
    Focus(true)
    SendNUIMessage({ action = 'openReports', reports = reports or {}, text = _LT(), lang = _LCode() })
end)

RegisterNetEvent('MULTIcoroner:client:openReportDetail', function(report, canManage)
    CurrentCase = nil
    Focus(true)
    SendNUIMessage({ action = 'openReportDetail', report = report, canManage = canManage == true, fromItem = true, text = _LT(), lang = _LCode() })
end)

RegisterNetEvent('MULTIcoroner:client:toast', function(kind, label, message)
    SendNUIMessage({ action = 'toast', type = kind, label = label, message = message })
end)

RegisterNUICallback('close', function(_, cb)
    CloseUI()
    cb({ ok = true })
end)

RegisterNUICallback('submit', function(data, cb)
    if not CurrentCase or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('MULTIcoroner:server:fileReport', CurrentCase, {
        subjectName = data.subjectName,
        cause = data.cause,
        manner = data.manner,
        notes = data.notes,
        conclusion = data.conclusion,
    })
    CloseUI()
    cb({ ok = true })
end)

RegisterNUICallback('getReports', function(_, cb)
    TriggerServerEvent('MULTIcoroner:server:getReports')
    cb({ ok = true })
end)

RegisterNUICallback('printReport', function(data, cb)
    TriggerServerEvent('MULTIcoroner:server:printReport', data and data.reportId)
    cb({ ok = true })
end)

RegisterNUICallback('deleteReport', function(data, cb)
    TriggerServerEvent('MULTIcoroner:server:deleteReport', data and data.reportId)
    cb({ ok = true })
end)

-- ------------------------------------------------------------
-- where the body lies
-- ------------------------------------------------------------
local function GetLocationLabel(coords)
    if not coords then return _L('location_unknown') end
    local nearest, nearestDistance = nil, math.huge
    for _, town in ipairs(Config.LocationTowns or {}) do
        if town and town.coords then
            local distance = #(coords - town.coords)
            if distance <= (town.radius or Config.LocationTownRadius or 300.0) and distance < nearestDistance then
                nearest, nearestDistance = town, distance
            end
        end
    end
    local label = nearest and nearest.label or _L('wilderness')
    if not Config.IncludeCoordsInLocation then return label end
    return ('%s  (X %.1f  Y %.1f)'):format(label, coords.x, coords.y)
end

-- ------------------------------------------------------------
-- bodies
-- ------------------------------------------------------------
local function IsDeadPed(entity)
    if not DoesEntityExist(entity) or not IsEntityAPed(entity) then return false end
    if IsEntityDead(entity) then return true end
    local ok, dying = pcall(IsPedDeadOrDying, entity, true)
    if ok and dying then return true end
    local hok, health = pcall(GetEntityHealth, entity)
    return hok and health <= 0
end

local function IsAnimalPed(entity)
    local ok, pedType = pcall(GetPedType, entity)
    return ok and pedType == 28
end

local function CorpseStillValid(entity)
    if not DoesEntityExist(entity) then
        CorpseSeen[entity] = nil
        return false
    end
    if (Config.CorpseLifetime or 0) > 0 then
        CorpseSeen[entity] = CorpseSeen[entity] or Now()
        if Now() - CorpseSeen[entity] > Config.CorpseLifetime then return false end
    end
    return true
end

local function DebugTarget(entity, reason)
    if not Config.Debug then return end
    local now = GetGameTimer()
    if LastDebugLog[entity] and now - LastDebugLog[entity] < 1000 then return end
    LastDebugLog[entity] = now
    Debug(('target %d player=%s => %s'):format(entity, tostring(IsPedAPlayer(entity)), reason))
end

local function OpenCaseForEntity(entity)
    if not entity or not DoesEntityExist(entity) then return end

    local case = { type = IsAnimalPed(entity) and 'ANIMAL' or 'NPC', id = 0, name = '', identifiedName = nil }

    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
    if IsPedAPlayer(entity) and playerIndex and playerIndex ~= -1 then
        local serverId = GetPlayerServerId(playerIndex)
        if serverId and serverId > 0 then
            case.type, case.id = 'PLAYER', serverId
            case.name = GetPlayerName(playerIndex) or ('#' .. serverId)
            local ok, charName = pcall(lib.callback.await, 'MULTIcoroner:server:charName', 500, serverId)
            case.identifiedName = (ok and charName and charName ~= '') and charName or case.name
        end
    end

    case.location = GetLocationLabel(GetEntityCoords(entity))
    Debug('location ' .. case.location)
    OpenCaseUI(case)
end

-- ------------------------------------------------------------
-- target options (MULTItarget answers ox_target calls)
-- Dead players: a global player option. Dead NPCs and animals: a small zone on
-- each body near you, because the ray does not always hit a body on the ground.
-- ------------------------------------------------------------
local function RemoveCorpseZone(entity)
    local data = CorpseZones[entity]
    if not data then return end
    pcall(function() exports.ox_target:removeZone(data.id) end)
    CorpseZones[entity] = nil
end

local function CanInspectPed(entity, source)
    if not entity or entity == PlayerPedId() then return false end
    if not HasAccess() then return false end
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 1 then return false end
    local isPlayer = IsPedAPlayer(entity)
    -- one option per body: players through the player option, nearby NPCs through their zone
    if source == 'PED' and (isPlayer or CorpseZones[entity]) then return false end
    if not IsDeadPed(entity) then DebugTarget(entity, source .. ' not dead') return false end
    if not isPlayer and IsAnimalPed(entity) then return false end
    if not CorpseStillValid(entity) then return false end
    DebugTarget(entity, source .. ' ok')
    return true
end

local function RegisterTargets()
    if GetResourceState('ox_target') ~= 'started' then return false end
    pcall(function()
        exports.ox_target:removeGlobalPed(PedTargetName)
        exports.ox_target:removeGlobalPlayer(PlayerTargetName)
    end)
    local function option(name, source)
        return {
            name = name,
            label = _L('target_label'),
            icon = 'fa-solid fa-file-medical',
            distance = Config.TargetDistance or 2.5,
            canInteract = function(entity) return CanInspectPed(entity, source) end,
            onSelect = function(data) OpenCaseForEntity(data and data.entity) end,
        }
    end
    local ok, err = pcall(function()
        exports.ox_target:addGlobalPed({ option(PedTargetName, 'PED') })
        exports.ox_target:addGlobalPlayer({ option(PlayerTargetName, 'PLAYER') })
    end)
    if not ok then
        print(('[MULTIcoroner] could not add target options: %s'):format(tostring(err)))
        return false
    end
    Debug('target options added')
    return true
end

CreateThread(function()
    while not RegisterTargets() do Wait(500) end
end)

-- MULTItarget restarted: its options are gone, add them again
AddEventHandler('onClientResourceStart', function(res)
    if res == 'MULTItarget' then
        CorpseZones = {}
        CreateThread(function()
            Wait(500)
            while not RegisterTargets() do Wait(500) end
        end)
    end
end)

local function AddCorpseZone(entity)
    if CorpseZones[entity] then return end
    local coords = GetEntityCoords(entity)
    local animal = IsAnimalPed(entity)
    local ok, zoneId = pcall(function()
        return exports.ox_target:addSphereZone({
            coords = coords,
            radius = Config.CorpseZoneRadius or 1.8,
            debug = false,
            options = {
                {
                    name = 'MULTIcoroner:inquest_' .. tostring(entity),
                    label = _L('target_label'),
                    icon = animal and 'fa-solid fa-paw' or 'fa-solid fa-file-medical',
                    distance = Config.TargetDistance or 2.5,
                    canInteract = function()
                        return HasAccess() and DoesEntityExist(entity) and IsDeadPed(entity) and CorpseStillValid(entity)
                    end,
                    onSelect = function() OpenCaseForEntity(entity) end,
                },
            },
        })
    end)
    if ok and zoneId then CorpseZones[entity] = { id = zoneId, coords = coords } end
end

CreateThread(function()
    while true do
        Wait(750)
        if not HasAccess() then
            for entity in pairs(CorpseZones) do RemoveCorpseZone(entity) end
        else
            local me = PlayerPedId()
            local myCoords = GetEntityCoords(me)
            local seen = {}
            local poolOk, pool = pcall(GetGamePool, 'CPed')
            if poolOk and pool then
                for _, ped in ipairs(pool) do
                    if ped ~= me and DoesEntityExist(ped) and not IsPedAPlayer(ped) and IsDeadPed(ped) then
                        local coords = GetEntityCoords(ped)
                        if #(coords - myCoords) <= (Config.CorpseScanDistance or 30.0) then
                            seen[ped] = true
                            local data = CorpseZones[ped]
                            if data and #(data.coords - coords) > 0.75 then RemoveCorpseZone(ped) end
                            if not CorpseZones[ped] then AddCorpseZone(ped) end
                        end
                    end
                end
            end
            for entity in pairs(CorpseZones) do
                if not seen[entity] then RemoveCorpseZone(entity) end
            end
        end
    end
end)

-- /coronerdebug (admins): what this client sees
RegisterNetEvent('MULTIcoroner:client:debugDump', function()
    local zones = 0
    for _ in pairs(CorpseZones) do zones = zones + 1 end
    local poolOk, pool = pcall(GetGamePool, 'CPed')
    local dead, near = 0, 0
    local myCoords = GetEntityCoords(PlayerPedId())
    if poolOk and pool then
        for _, ped in ipairs(pool) do
            if IsDeadPed(ped) then
                dead = dead + 1
                if #(GetEntityCoords(ped) - myCoords) <= (Config.CorpseScanDistance or 30.0) then near = near + 1 end
            end
        end
    end
    print(('[MULTIcoroner] client: allowed=%s ui=%s zones=%d peds=%d dead=%d near=%d'):format(
        tostring(IsAllowed), tostring(IsUIOpen), zones, poolOk and pool and #pool or -1, dead, near))
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for entity in pairs(CorpseZones) do RemoveCorpseZone(entity) end
    pcall(function()
        exports.ox_target:removeGlobalPed(PedTargetName)
        exports.ox_target:removeGlobalPlayer(PlayerTargetName)
    end)
    if IsUIOpen then SetNuiFocus(false, false) end
end)
