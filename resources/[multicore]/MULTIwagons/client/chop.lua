-- ============================================================
-- MULTIwagons :: chop shop (client)
-- Bring a wagon to the chop shop and scrap it for parts. The place is used
-- through MULTItarget or a hold-key prompt (@MULTIcore/lib/interact.lua).
-- Based on Phil's wagon script (chop.lua).
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================
if not (Config.Chop and Config.Chop.Enabled ~= false) then return end

MWC = MWC or {}
MWC.ChopBusy = false

local chopBlips = {}
local zones, prompts = {}, {}

local function ChopDebug(...)
    if Config.Chop.Debug then print('[MULTIwagons:chop]', ...) end
end

local function chopNotify(ntype, title, message)
    lib.notify({ title = title, description = message, type = ntype, duration = Config.Chop.NotifyDuration })
end

local function GetChopLocations()
    local out = {}
    for _, loc in ipairs(Config.Chop.Locations or {}) do
        if loc and loc.coords then out[#out + 1] = loc end
    end
    return out
end

local function CreateChopBlips()
    for _, blip in pairs(chopBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    chopBlips = {}
    if not Config.Chop.ChopBlip or not Config.Chop.ChopBlip.show then return end
    for _, loc in ipairs(GetChopLocations()) do
        if loc.blip ~= false then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, loc.coords.x, loc.coords.y, loc.coords.z)
            if blip and blip ~= 0 then
                SetBlipSprite(blip, Config.Chop.ChopBlip.sprite, true)
                Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', _L('chop_blip')))
                SetBlipScale(blip, Config.Chop.ChopBlip.scale or 0.8)
                chopBlips[#chopBlips + 1] = blip
            end
        end
    end
end

local function IsWagonModel(modelHash)
    for _, wagonType in pairs(Config.Wagons) do
        for wagonModel in pairs(wagonType) do
            if GetHashKey(wagonModel) == modelHash then return wagonModel end
        end
    end
    return nil
end

local function GetNearbyChopWagon(coords, radius)
    local closest, closestDist, closestModel = nil, radius, nil
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
            local modelName = IsWagonModel(GetEntityModel(vehicle))
            if modelName or Config.Chop.AllowUnknownWagons then
                local dist = #(coords - GetEntityCoords(vehicle))
                if dist < closestDist then
                    closest, closestDist, closestModel = vehicle, dist, (modelName or 'unknown_wagon')
                end
            end
        end
    end
    return closest, closestModel
end

local function GetDrivenChopWagon()
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    if vehicle and vehicle ~= 0 and IsEntityAVehicle(vehicle) then
        local modelName = IsWagonModel(GetEntityModel(vehicle))
        if modelName or Config.Chop.AllowUnknownWagons then return vehicle, (modelName or 'unknown_wagon') end
    end
    return nil, nil
end

local function GetClosestChopLocation(playerCoords)
    local bestIndex, bestDist = nil, math.huge
    for i, loc in ipairs(GetChopLocations()) do
        local dist = #(playerCoords - loc.coords)
        if dist < bestDist then bestIndex, bestDist = i, dist end
    end
    return bestIndex, bestDist
end

local function DeleteChopDraftAnimals(wagon)
    if not wagon or wagon == 0 or not DoesEntityExist(wagon) then return end
    local count = tonumber(Citizen.InvokeNative(0x635423D55CA84FC8, wagon)) or 0
    for i = count, 1, -1 do
        local animal = Citizen.InvokeNative(0x0A794A2989F18F3C, wagon, i)
        if animal and animal ~= 0 and DoesEntityExist(animal) then
            SetEntityAsMissionEntity(animal, true, true)
            DetachEntity(animal, true, true)
            ClearPedTasksImmediately(animal)
            DeletePed(animal)
            DeleteEntity(animal)
        end
    end
end

local function TryGetChopControl(entity, timeoutMs)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if not NetworkGetEntityIsNetworked(entity) then return true end
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local timeout = GetGameTimer() + (timeoutMs or 1500)
    while DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end
    return NetworkHasControlOfEntity(entity)
end

local function ForceDeleteChopVehicle(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return true end
    TryGetChopControl(entity, 1500)
    SetEntityAsMissionEntity(entity, true, true)
    DeleteVehicle(entity)
    local attempts = 0
    while DoesEntityExist(entity) and attempts < 5 do
        Wait(150)
        TryGetChopControl(entity, 300)
        SetEntityAsMissionEntity(entity, true, true)
        DeleteVehicle(entity)
        attempts = attempts + 1
    end
    if DoesEntityExist(entity) then
        SetEntityVisible(entity, false, false)
        SetEntityCollision(entity, false, false, false)
        FreezeEntityPosition(entity, true)
        SetEntityCoords(entity, 0.0, 0.0, -1000.0, false, false, false, false)
        return false
    end
    return true
end

RegisterNetEvent('MULTIwagons:client:chopForceDelete', function(netId)
    local entity = nil
    local numericNetId = tonumber(netId)
    if numericNetId and numericNetId ~= 0 then entity = NetworkGetEntityFromNetworkId(numericNetId) end
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        entity = GetNearbyChopWagon(GetEntityCoords(cache.ped), Config.Chop.WagonSearchDistance)
    end
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteChopDraftAnimals(entity)
        ForceDeleteChopVehicle(entity)
    end
    if numericNetId and numericNetId ~= 0 then
        TriggerServerEvent('MULTIwagons:server:chopDeleteFallback', numericNetId)
    end
    MWC.ChopBusy = false
end)

local function OpenChopUI(netId, modelName, info)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openChop',
        netId = netId,
        modelName = modelName,
        displayName = info.displayName or modelName,
        rewards = info.rewardList or {},
        isRegistered = info.isRegistered or false,
        text = _LT(),
        lang = _LCode(),
    })
end

RegisterNUICallback('confirmChop', function(data, cb)
    cb('ok')
    SetNuiFocus(false, false)
    if data and data.netId ~= nil then
        MWC.ChopBusy = true
        TriggerServerEvent('MULTIwagons:server:processChop', tonumber(data.netId) or 0)
        SetTimeout(10000, function() MWC.ChopBusy = false end)
    end
end)

local function TryOpenChopUI(wagon, modelName)
    if not wagon or wagon == 0 or not DoesEntityExist(wagon) then return end
    local netId = NetworkGetEntityIsNetworked(wagon) and NetworkGetNetworkIdFromEntity(wagon) or 0
    lib.callback('MULTIwagons:server:getChopInfo', false, function(result)
        if not result then return end
        if result.error then
            return chopNotify('error', _L('chop_title'), result.message)
        end
        OpenChopUI(netId, result.modelName or modelName, result)
    end, netId, modelName)
end

RegisterNetEvent('MULTIwagons:client:chopNotify', function(ntype, title, message)
    if ntype == 'error' then MWC.ChopBusy = false end
    chopNotify(ntype, title, message)
end)

--- Scrap the wagon near the player (or the one they sit on).
local function useChopShop()
    if MWC.ChopBusy or IsNuiFocused() then return end
    local playerCoords = GetEntityCoords(cache.ped)
    local wagon, modelName = GetNearbyChopWagon(playerCoords, Config.Chop.WagonSearchDistance)
    if not wagon then wagon, modelName = GetDrivenChopWagon() end
    if wagon and modelName then
        ChopDebug('wagon=' .. tostring(wagon) .. ' model=' .. tostring(modelName))
        TryOpenChopUI(wagon, modelName)
    else
        chopNotify('error', _L('chop_title'), _L('chop_no_wagon'))
    end
end

AddEventHandler('MULTIwagons:client:useChop', useChopShop)

if Config.Chop.Debug then
    RegisterCommand('chopdebug', function()
        local coords = GetEntityCoords(cache.ped)
        print(('[chop] coords: vector3(%.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z))
        local idx, dist = GetClosestChopLocation(coords)
        if idx then
            print(('[chop] nearest place %.2f m away (prompt within %.2f m)'):format(dist, Config.Chop.InteractDistance))
        else
            print('[chop] no chop places set - check Config.Chop.Locations.')
        end
        local wagon, model = GetNearbyChopWagon(coords, Config.Chop.WagonSearchDistance)
        print('[chop] nearby wagon: ' .. tostring(wagon) .. ' model: ' .. tostring(model))
    end, false)
end

CreateThread(CreateChopBlips)

MCI.Run(Config.Interact, function(mode)
    for i, loc in ipairs(GetChopLocations()) do
        local name = 'multiwagons_chop_' .. i
        if mode == 'target' then
            zones[#zones + 1] = MCI.AddZone({
                coords = loc.coords, radius = Config.Chop.TargetRadius or 2.0,
                options = { {
                    name = name, label = _L('chop_prompt'), icon = 'fa-solid fa-hammer',
                    distance = Config.TargetDistance + 1.0,
                    canInteract = function() return not MWC.ChopBusy end,
                    onSelect = useChopShop,
                } },
            })
        else
            MCI.AddPrompt(name, loc.coords, Config.PromptKey, _L('chop_prompt'),
                { type = 'client', event = 'MULTIwagons:client:useChop', args = {} }, Config.Chop.InteractDistance)
            prompts[#prompts + 1] = name
        end
    end
end, function()
    for _, id in ipairs(zones) do MCI.RemoveZone(id) end
    zones = {}
    for _, name in ipairs(prompts) do MCI.RemovePrompt(name) end
    prompts = {}
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, blip in pairs(chopBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    chopBlips = {}
end)
