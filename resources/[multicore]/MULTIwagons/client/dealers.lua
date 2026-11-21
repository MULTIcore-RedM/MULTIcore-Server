-- ============================================================
-- MULTIwagons :: wagon dealers (client)
-- Blips, clerks, and the dealer counter: MULTItarget on the counter and the
-- clerk, or a hold-key prompt (@MULTIcore/lib/interact.lua).
-- Based on Phil's wagon script (npcs.lua, store.lua).
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local spawnedPeds = {}   -- [storeId] = ped
local blips = {}
local zones, prompts = {}, {}
local interactMode = nil

local function storeOption(storeId)
    return {
        name = 'multiwagons_store_' .. storeId, label = _L('dealer'), icon = Config.TargetIcon,
        distance = Config.TargetDistance,
        onSelect = function() MWC.OpenStore(storeId) end,
    }
end

-- the prompt calls this (createPrompt passes args as given)
AddEventHandler('MULTIwagons:client:openStore', function(storeId)
    if type(storeId) == 'table' then storeId = storeId[1] end
    if Config.Stores[storeId] then MWC.OpenStore(storeId) end
end)

-- ---------------------------------------------------------------
-- clerks
-- ---------------------------------------------------------------

local function fadeOutAndDeletePed(ped)
    if not ped or not DoesEntityExist(ped) then return end
    CreateThread(function()
        for i = 255, 0, -51 do
            Wait(50)
            SetEntityAlpha(ped, i, false)
        end
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
    end)
end

local function spawnStorePed(npcModel, coords, storeId)
    if not lib.requestModel(npcModel, 5000) then return nil end
    local ped = CreatePed(npcModel, coords.x, coords.y, coords.z - 1.0, coords.w, false, false, 0, 0)
    SetEntityAlpha(ped, 0, false)
    SetRandomOutfitVariation(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)

    CreateThread(function()
        for i = 0, 255, 51 do
            Wait(50)
            SetEntityAlpha(ped, i, false)
        end
    end)

    if interactMode == 'target' then MCI.AddEntity(ped, { storeOption(storeId) }) end
    SetModelAsNoLongerNeeded(npcModel)
    return ped
end

for storeId, store in pairs(Config.Stores) do
    if store.npcmodel and store.npccoords then
        lib.points.new({
            coords = store.npccoords.xyz,
            distance = 50.0,
            onEnter = function()
                if not spawnedPeds[storeId] then
                    spawnedPeds[storeId] = spawnStorePed(store.npcmodel, store.npccoords, storeId)
                end
            end,
            onExit = function()
                local ped = spawnedPeds[storeId]
                if ped then
                    MCI.RemoveEntity(ped)
                    fadeOutAndDeletePed(ped)
                    spawnedPeds[storeId] = nil
                end
            end,
        })
    end
end

MCI.Counter('npcs', function()
    local n = 0
    for _ in pairs(spawnedPeds) do n = n + 1 end
    return n
end)

-- ---------------------------------------------------------------
-- blips
-- ---------------------------------------------------------------

CreateThread(function()
    if not Config.Blip.showBlip then return end
    for _, v in pairs(Config.Stores) do
        local blip = BlipAddForCoords(Config.Blip.style or 1664425300, v.coords.x, v.coords.y, v.coords.z)
        SetBlipSprite(blip, Config.Blip.sprite or -1747775003, true)
        SetBlipScale(blip, Config.Blip.scale or 0.2)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, CreateVarString(10, 'LITERAL_STRING', _L('dealer')))
        blips[#blips + 1] = blip
    end
end)

-- ---------------------------------------------------------------
-- the counter: MULTItarget or a hold-key prompt
-- ---------------------------------------------------------------

MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    for storeId, store in pairs(Config.Stores) do
        if mode == 'target' then
            zones[#zones + 1] = MCI.AddZone({ coords = store.coords, radius = Config.TargetRadius, options = { storeOption(storeId) } })
            if spawnedPeds[storeId] then MCI.AddEntity(spawnedPeds[storeId], { storeOption(storeId) }) end
        else
            MCI.AddPrompt('multiwagons_store_' .. storeId, store.coords, Config.PromptKey, _L('dealer'),
                { type = 'client', event = 'MULTIwagons:client:openStore', args = { storeId } }, Config.PromptDistance)
            prompts[#prompts + 1] = 'multiwagons_store_' .. storeId
        end
    end
end, function()
    for _, id in ipairs(zones) do MCI.RemoveZone(id) end
    zones = {}
    for _, ped in pairs(spawnedPeds) do MCI.RemoveEntity(ped) end
    for _, name in ipairs(prompts) do MCI.RemovePrompt(name) end
    prompts = {}
    interactMode = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    for _, name in ipairs(prompts) do MCI.RemovePrompt(name) end
end)
