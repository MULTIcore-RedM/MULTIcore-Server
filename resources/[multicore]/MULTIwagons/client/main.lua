-- ============================================================
-- MULTIwagons :: your wagon (client)
-- Calling, making and sending away your wagon, its blip, the wagon options
-- (storage at the back, send away, carcass / pelt storage) through MULTItarget
-- or hold-key prompts (@MULTIcore/lib/interact.lua), and asking an owner for
-- storage access. Based on Phil's wagon script (client.lua).
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local Core = exports['rsg-core']:GetCoreObject()

local wagonBlip, mywagon, wagonID, wagonNetId, wagonModel
local openMenu = false

MWC = MWC or {}

function MWC.Notify(text, kind)
    lib.notify({ title = _L('title'), description = text, type = kind or 'info', duration = 7000 })
end
local notify = MWC.Notify

local function myCitizenId()
    local pd = Core.Functions.GetPlayerData()
    return pd and pd.citizenid
end

--- Config.Wagons entry of a model.
function MWC.ModelCfg(model)
    for _, set in pairs(Config.Wagons) do
        if set[model] then return set[model] end
    end
end

local function maxAnimalsOf(model)
    local cfg = model and MWC.ModelCfg(model)
    return cfg and tonumber(cfg.maxAnimals) or 0
end

--- The MULTIwagons mark on a wagon entity (set by the server for everyone), or nil.
local function wagonState(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local st = Entity(veh).state.multiwagon
    return type(st) == 'table' and st or nil
end

local function isMine(st) return st ~= nil and st.owner == myCitizenId() end

-- ---------------------------------------------------------------
-- calling and making the wagon
-- ---------------------------------------------------------------

local function CallWagon()
    if mywagon and DoesEntityExist(mywagon) then
        return notify(_L('have_wagon'), 'error')
    end
    if wagonBlip and DoesBlipExist(wagonBlip) then
        RemoveBlip(wagonBlip)
        wagonBlip = nil
    end
    TriggerServerEvent('MULTIwagons:server:callWagon')
end
MWC.CallWagon = CallWagon

local function FindSafeSpawnCoords(baseCoords, attempts, radius, minDistance)
    attempts = attempts or 10
    radius = radius or Config.SpawnRadius or 10.0
    minDistance = minDistance or 5.0
    local players = GetActivePlayers()
    for i = 1, attempts do
        local angle = math.rad((360 / attempts) * i)
        local tryCoords = vec3(baseCoords.x + math.cos(angle) * radius, baseCoords.y + math.sin(angle) * radius, baseCoords.z)

        local isFar = true
        for _, playerId in ipairs(players) do
            if #(GetEntityCoords(GetPlayerPed(playerId)) - tryCoords) < minDistance then
                isFar = false
                break
            end
        end

        if isFar then
            local x, y, z = table.unpack(GetEntityCoords(cache.ped))
            local found, roadCoords = GetClosestVehicleNode(x - 15, y, z, 0, 3.0, 0.0)
            local _, _, nodeHeading = GetNthClosestVehicleNodeWithHeading(x - 15, y, z, 1, 1, 0, 0)
            if found then return found, roadCoords, nodeHeading end
        end
    end

    local pedCoords = GetEntityCoords(cache.ped)
    local fallbackDistance = Config.FallbackSpawnDistance or 10.0
    for i = 1, 8 do
        local angle = math.rad((360 / 8) * i)
        local tryCoords = vec3(pedCoords.x + math.cos(angle) * fallbackDistance, pedCoords.y + math.sin(angle) * fallbackDistance, pedCoords.z)

        local isFar = true
        for _, playerId in ipairs(players) do
            if #(GetEntityCoords(GetPlayerPed(playerId)) - tryCoords) < minDistance then
                isFar = false
                break
            end
        end

        if isFar then return true, tryCoords, GetEntityHeading(cache.ped) end
    end
    return nil
end

function getControlOfEntity(entity)
    NetworkRequestControlOfEntity(entity)
    SetEntityAsMissionEntity(entity, true, true)
    local timeout = 2000
    while timeout > 0 and not NetworkHasControlOfEntity(entity) do
        Wait(100)
        timeout -= 100
    end
    return NetworkHasControlOfEntity(entity)
end

local function UpdateHuntingTarp()
    if not mywagon or not wagonID then return end
    lib.callback('MULTIwagons:server:getAnimalStorage', false, function(menuData)
        if not mywagon or not DoesEntityExist(mywagon) then return end
        local count = 0
        for _, v in pairs(menuData or {}) do count += (v.infos.quantity or 1) end
        local maxAnimal = maxAnimalsOf(wagonModel)
        if maxAnimal <= 0 then maxAnimal = 20 end
        Citizen.InvokeNative(0x31F343383F19C987, mywagon, count / maxAnimal, 1)
    end, wagonID)
end

local function SpawnWagon(model, custom, myWagonID)
    custom = custom or {}
    local hash = joaat(model)
    if not lib.requestModel(hash, 10000) then
        return notify(_L('model_failed'), 'error')
    end

    if IsPedInAnyVehicle(cache.ped, false) then
        DeleteVehicle(cache.vehicle)
    end

    local found, safeCoords, nodeHeading = FindSafeSpawnCoords(GetEntityCoords(cache.ped))
    if not safeCoords or not found then
        return notify(_L('no_road'), 'error')
    end

    mywagon = CreateVehicle(hash, safeCoords.x, safeCoords.y, safeCoords.z, nodeHeading, true, false)
    SetVehicleDirtLevel(mywagon, 0.0)

    Wait(100)
    Citizen.InvokeNative(0x75F90E4051CC084C, mywagon, 0)
    Citizen.InvokeNative(0xE31C0CB1C3186D40, mywagon)

    if custom.props then
        Citizen.InvokeNative(0x75F90E4051CC084C, mywagon, GetHashKey(custom.props))
        Citizen.InvokeNative(0x31F343383F19C987, mywagon, 0.5, 1)
    end
    if custom.lantern then
        Citizen.InvokeNative(0xC0F0417A90402742, mywagon, GetHashKey(custom.lantern))
    end

    Citizen.InvokeNative(0x8268B098F6FCA4E2, mywagon, tonumber(custom.tint) or 0)
    Citizen.InvokeNative(0xF89D82A0582E46ED, mywagon, tonumber(custom.livery) or 0)

    Citizen.InvokeNative(0xAD738C3085FE7E11, mywagon, true, true)
    Citizen.InvokeNative(0x9617B6E5F65329A5, mywagon)

    for i = 0, 10 do
        if DoesExtraExist(mywagon, i) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, mywagon, i, true)
        end
    end
    -- several extras (extras list); a single `extra` value from older rows still works
    local extrasList = nil
    if type(custom.extras) == 'table' and #custom.extras > 0 then
        extrasList = custom.extras
    elseif custom.extra and tonumber(custom.extra) and tonumber(custom.extra) ~= -1 then
        extrasList = { tonumber(custom.extra) }
    end
    if extrasList then
        for _, extraId in ipairs(extrasList) do
            local eid = tonumber(extraId)
            if eid then Citizen.InvokeNative(0xBB6F89150BC9D16B, mywagon, eid, false) end
        end
    end

    if model == 'huntercart01' then
        Citizen.InvokeNative(0x75F90E4051CC084C, mywagon, joaat('pg_mp005_huntingWagonTarp01'))
        Citizen.InvokeNative(0xC0F0417A90402742, mywagon, joaat('pg_teamster_cart06_lightupgrade3'))
        Citizen.InvokeNative(0x31F343383F19C987, mywagon, 0.5, 1)
    end

    NetworkRegisterEntityAsNetworked(mywagon)
    SetVehicleIsConsideredByPlayer(mywagon, true)
    Citizen.InvokeNative(0xBB5A3FA8ED3979C5, mywagon, true)

    local networkId = NetworkGetNetworkIdFromEntity(mywagon)
    local tries = 0
    while not NetworkDoesEntityExistWithNetworkId(networkId) and tries < 100 do
        Wait(50)
        tries += 1
    end

    getControlOfEntity(mywagon)
    SetModelAsNoLongerNeeded(hash)

    wagonID, wagonNetId, wagonModel = myWagonID, networkId, model
    TriggerServerEvent('MULTIwagons:server:registerWagon', networkId, myWagonID, model)

    wagonBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, mywagon)
    SetBlipSprite(wagonBlip, GetHashKey(Config.Blip.ownWagonSprite or 'blip_player_coach'), true)
    Citizen.InvokeNative(0x9CB1A1623062F402, wagonBlip, CreateVarString(10, 'LITERAL_STRING', custom.name or _L('your_wagon')))

    if model == 'huntercart01' then UpdateHuntingTarp() end
end

local function clearLocal()
    mywagon, wagonID, wagonNetId, wagonModel = nil, nil, nil, nil
    if wagonBlip and DoesBlipExist(wagonBlip) then
        RemoveBlip(wagonBlip)
        wagonBlip = nil
    end
end

--- Deletes the own wagon (or the wagon netId): takes control, retries, and always clears
--- the local state, so a sent-away wagon never stays in the world and doubles the next one.
function DeleteWagon(netId)
    local entity = nil
    if mywagon and DoesEntityExist(mywagon) then
        entity = mywagon
    elseif netId and tonumber(netId) and tonumber(netId) ~= 0 then
        local resolved = NetworkGetEntityFromNetworkId(tonumber(netId))
        if resolved and resolved ~= 0 and DoesEntityExist(resolved) then entity = resolved end
    end

    if entity then
        TriggerServerEvent('MULTIwagons:server:removeWagon', NetworkGetNetworkIdFromEntity(entity))
        getControlOfEntity(entity)
        SetEntityAsMissionEntity(entity, true, true)
        DeleteVehicle(entity)
        local attempts = 0
        while DoesEntityExist(entity) and attempts < 5 do
            Wait(150)
            getControlOfEntity(entity)
            SetEntityAsMissionEntity(entity, true, true)
            DeleteVehicle(entity)
            attempts = attempts + 1
        end
        if DoesEntityExist(entity) then
            -- could not free it: hide and move it so it never doubles
            SetEntityVisible(entity, false, false)
            SetEntityCollision(entity, false, false, false)
            FreezeEntityPosition(entity, true)
            SetEntityCoords(entity, 0.0, 0.0, -1000.0, false, false, false, false)
        end
    elseif netId and tonumber(netId) and tonumber(netId) ~= 0 then
        TriggerServerEvent('MULTIwagons:server:removeWagon', tonumber(netId))
    end
    clearLocal()
end
MWC.DeleteWagon = DeleteWagon

RegisterNetEvent('MULTIwagons:client:receiveWagonData', function(wModel, customData, _, myWagonID)
    if mywagon and DoesEntityExist(mywagon) then
        DeleteWagon()
        Wait(500)
    end
    clearLocal()
    if not wModel then return notify(_L('no_wagon'), 'error') end
    SpawnWagon(wModel, customData, myWagonID)
end)

-- the server removed a wagon of ours (sold, scrapped, a newer one called)
RegisterNetEvent('MULTIwagons:client:forgetWagon', function(netId)
    if wagonNetId and tonumber(netId) == wagonNetId then clearLocal() end
end)

-- the owner side of scrapping: we have control, so the delete holds
RegisterNetEvent('MULTIwagons:client:chopDeleteOwnedWagon', function(netId)
    MWC.ChopBusy = false
    DeleteWagon(netId)
end)

RegisterNetEvent('MULTIwagons:client:callWagon', function() CallWagon() end)
RegisterNetEvent('MULTIwagons:client:deleteWagon', function() DeleteWagon() end)

if Config.SpawnKey then
    CreateThread(function()
        local key = GetHashKey(Config.SpawnKey)
        while true do
            local sleep = 0
            if IsControlJustReleased(0, key) then CallWagon() end
            if mywagon and DoesEntityExist(mywagon) then sleep = 250 end
            Wait(sleep)
        end
    end)
end

if Config.CallCommand and Config.CallCommand ~= '' then
    RegisterCommand(Config.CallCommand, function() CallWagon() end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.CallCommand, _L('cmd_wagon'))
end

-- ---------------------------------------------------------------
-- carcasses and pelts
-- ---------------------------------------------------------------

local function GetFirstEntityPedIsCarrying(ped) return Citizen.InvokeNative(0xD806CD2A4F2C2996, ped) end
local function GetMetaPedAssetTint(ped, index)
    return Citizen.InvokeNative(0xE7998FEC53A33BBE, ped, index, Citizen.PointerValueInt(), Citizen.PointerValueInt(),
        Citizen.PointerValueInt(), Citizen.PointerValueInt())
end
local function GetMetaPedAssetGuids(ped, index)
    return Citizen.InvokeNative(0xA9C28516A6DC9D56, ped, index, Citizen.PointerValueInt(), Citizen.PointerValueInt(),
        Citizen.PointerValueInt(), Citizen.PointerValueInt())
end
local function GetNumComponentsInPed(ped) return Citizen.InvokeNative(0x90403E8107B60E81, ped, Citizen.ResultAsInteger()) end
local function GetIsCarriablePelt(entity) return Citizen.InvokeNative(0x255B6DB4E3AD3C3E, entity) end
local function GetCarriableFromEntity(entity) return Citizen.InvokeNative(0x31FEF6A20F00B963, entity) end
local function GetCarcassMetaTag(entity)
    local metatag, numComponents = {}, GetNumComponentsInPed(entity)
    for i = 0, numComponents - 1 do
        local drawable, albedo, normal, material = GetMetaPedAssetGuids(entity, i)
        local palette, tint0, tint1, tint2 = GetMetaPedAssetTint(entity, i)
        metatag[i] = {
            drawable = drawable, albedo = albedo, normal = normal, material = material,
            palette = palette, tint0 = tint0, tint1 = tint1, tint2 = tint2,
        }
    end
    return metatag
end
local function UpdatePedVariation(ped)
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end
local function SetMetaPedTag(ped, drawable, albedo, normal, material, palette, tint0, tint1, tint2)
    return Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, drawable, albedo, normal, material, palette, tint0, tint1, tint2)
end
local function GetPedMetaOutfitHash(ped) return Citizen.InvokeNative(0x30569F348D126A5A, ped, Citizen.ResultAsInteger()) end
local function IsEntityFullyLooted(entity) return Citizen.InvokeNative(0x8DE41E9902E85756, entity) end
local function GetPedDamageCleanliness(ped) return Citizen.InvokeNative(0x88EFFED5FE8B0B4A, ped, Citizen.ResultAsInteger()) end
local function EquipMetaPedOutfit(ped, hash) return Citizen.InvokeNative(0x1902C4CFCC5BE57C, ped, hash) end
local function ApplyCarcasMetaTag(entity, metatag)
    if type(metatag) ~= 'table' then return end
    for _, data in pairs(metatag) do
        if data then
            SetMetaPedTag(entity, data.drawable, data.albedo, data.normal, data.material, data.palette,
                data.tint0, data.tint1, data.tint2)
        end
    end
    UpdatePedVariation(entity)
end
local function SetPedDamageCleanliness(ped, damageCleanliness) return Citizen.InvokeNative(0x7528720101A807A5, ped, damageCleanliness) end
local function GetPedQuality(ped) return Citizen.InvokeNative(0x7BCC6087D130312A, ped) end
local function SetPedQuality(ped, quality) return Citizen.InvokeNative(0xCE6B874286D640BB, ped, quality) end
local function TaskStatus(task)
    local count = 0
    repeat
        count += 1
        Wait(0)
    until (GetScriptTaskStatus(cache.ped, task, true) == 8) or count > 100
end

local function isCarrying()
    local e = GetFirstEntityPedIsCarrying(cache.ped)
    return e and e ~= 0 and DoesEntityExist(e)
end

--- Puts what the player carries into the wagon veh (anyone may load a wagon that takes carcasses).
local function StoreCarriedEntityInWagon(veh)
    local st = wagonState(veh)
    if not st then return end
    local maxAnimal = maxAnimalsOf(st.model)
    if maxAnimal <= 0 then return notify(_L('no_animal_storage'), 'error') end
    lib.callback('MULTIwagons:server:getAnimalStorage', false, function(menuData)
        local carriedEntity = GetFirstEntityPedIsCarrying(cache.ped)
        if not carriedEntity or carriedEntity == 0 or not DoesEntityExist(carriedEntity) then
            return notify(_L('carry_nothing'), 'error')
        end

        local totalStored = 0
        for _, v in pairs(menuData or {}) do totalStored += (v.infos.quantity or 1) end
        if totalStored >= maxAnimal then return notify(_L('wagon_full'), 'error') end

        local data = { model = GetEntityModel(carriedEntity) }
        if GetIsCarriablePelt(carriedEntity) then
            data.type = 'pelt'
            data.peltquality = GetCarriableFromEntity(carriedEntity)
        else
            if not Config.AnimalsStorage[data.model] then return notify(_L('carry_nothing'), 'error') end
            data.type = 'animal'
            data.metatag = GetCarcassMetaTag(carriedEntity)
            data.outfit = GetPedMetaOutfitHash(carriedEntity)
            data.skinned = IsEntityFullyLooted(carriedEntity) or false
            data.damage = GetPedDamageCleanliness(carriedEntity) or 0
            data.quality = GetPedQuality(carriedEntity) or 0
        end

        TriggerServerEvent('MULTIwagons:server:storeAnimal', NetworkGetNetworkIdFromEntity(veh), data)
        DeleteEntity(carriedEntity)
        if veh == mywagon and st.model == 'huntercart01' then
            Wait(500)
            UpdateHuntingTarp()
        end
    end, st.id)
end

--- The owner's list of carcasses / pelts in their wagon veh; picking one takes it out.
local function CarcassInWagon(veh)
    local st = wagonState(veh)
    if not st then return end
    if not isMine(st) then return notify(_L('no_permission'), 'error') end
    if maxAnimalsOf(st.model) <= 0 then return notify(_L('no_animal_storage'), 'error') end
    openMenu = true
    lib.callback('MULTIwagons:server:getAnimalStorage', false, function(menuData)
        if not menuData or #menuData == 0 then
            openMenu = false
            return notify(_L('no_animals'), 'error')
        end
        local options = {}
        for _, v in pairs(menuData) do
            options[#options + 1] = {
                title = v.label,
                description = _L('animal_count', v.infos.quantity or 1, v.label),
                onSelect = function()
                    TriggerServerEvent('MULTIwagons:server:takeAnimal', st.id, v.infos)
                    openMenu = false
                    if veh == mywagon and st.model == 'huntercart01' then
                        Wait(500)
                        UpdateHuntingTarp()
                    end
                end,
            }
        end
        lib.registerContext({
            id = 'multiwagons_carcass', title = _L('animals_title'), options = options,
            onExit = function() openMenu = false end,
        })
        lib.showContext('multiwagons_carcass')
    end, st.id)
end

RegisterNetEvent('MULTIwagons:client:spawnAnimal', function(data)
    local coords = GetEntityCoords(cache.ped)
    if not lib.requestModel(data.model, 10000) then return end

    local cargo
    if IsModelAPed(data.model) then
        cargo = CreatePed(data.model, coords.x, coords.y, coords.z, 0.0, true, true)
        SetEntityHealth(cargo, 0, cache.ped)
        SetPedQuality(cargo, data.quality or 0)
        SetPedDamageCleanliness(cargo, data.damage or 0)
        if data.skinned then
            Wait(1000)
            Citizen.InvokeNative(0x6BCF5F3D8FFE988D, cargo, true)
            ApplyCarcasMetaTag(cargo, data.metatag)
        else
            EquipMetaPedOutfit(cargo, data.outfit)
            UpdatePedVariation(cargo)
        end
    else
        cargo = CreateObject(data.model, coords.x, coords.y, coords.z, true, true, true)
        Citizen.InvokeNative(0x78B4567E18B54480, cargo)
        Citizen.InvokeNative(0xF0B4F759F35CC7F5, cargo, Citizen.InvokeNative(0x34F008A7E48C496B, cargo, 0), cache.ped, 7, 512)
        Citizen.InvokeNative(0x399657ED871B3A6C, cargo, data.peltquality or 0)
    end

    Citizen.InvokeNative(0x18FF3110CF47115D, cargo, 21, true)
    SetEntityVisible(cargo, false)
    FreezeEntityPosition(cargo, true)

    TaskPickupCarriableEntity(cache.ped, cargo)
    TaskStatus(joaat('SCRIPT_TASK_PICKUP_CARRIABLE_ENTITY'))
    Wait(500)

    FreezeEntityPosition(cargo, false)
    SetEntityVisible(cargo, true)
    Citizen.InvokeNative(0x18FF3110CF47115D, cargo, 21, false)

    SetModelAsNoLongerNeeded(data.model)
end)

-- ---------------------------------------------------------------
-- storage and send away
-- ---------------------------------------------------------------

local function backPoint(veh)
    local min = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - Config.StorageBackOffset, 0.0)
end

local function openStash(veh)
    TriggerServerEvent('MULTIwagons:server:openStash', NetworkGetNetworkIdFromEntity(veh))
end

local function sendAway(veh)
    local st = wagonState(veh)
    if not isMine(st) then return notify(_L('no_permission'), 'error') end
    if veh == mywagon then DeleteWagon() else DeleteWagon(NetworkGetNetworkIdFromEntity(veh)) end
end

-- the owner is asked whether another player may open the storage
RegisterNetEvent('MULTIwagons:client:askOwnerPermission', function(data)
    if type(data) ~= 'table' then return end
    local answer = lib.alertDialog({
        header = _L('ask_title'),
        content = _L('ask_text', (data.name and data.name ~= '') and data.name or _L('someone')),
        centered = true,
        cancel = true,
        labels = { confirm = _L('yes'), cancel = _L('no') },
    })
    TriggerServerEvent('MULTIwagons:server:answerPermission', data.netId, data.requester, answer == 'confirm')
end)

-- ---------------------------------------------------------------
-- wagon options: MULTItarget on every marked wagon, or hold-key prompts
-- ---------------------------------------------------------------

local TARGET_NAMES = { 'multiwagons_storage', 'multiwagons_flee', 'multiwagons_stock', 'multiwagons_carcass' }
local promptLoop = 0
local targetsAdded = false

local function near(entity, dist)
    return #(GetEntityCoords(cache.ped) - GetEntityCoords(entity)) <= dist
end

local function buildTargets()
    exports.MULTItarget:addGlobalVehicle({
        {
            name = 'multiwagons_storage', label = _L('storage'), icon = 'fa-solid fa-box-open',
            distance = Config.TargetDistance,
            canInteract = function(entity)
                if not wagonState(entity) then return false end
                return #(GetEntityCoords(cache.ped) - backPoint(entity)) <= Config.StorageDistance
            end,
            onSelect = function(data) openStash(data.entity) end,
        },
        {
            name = 'multiwagons_flee', label = _L('send_away'), icon = 'fa-solid fa-warehouse',
            distance = Config.TargetDistance,
            canInteract = function(entity) return isMine(wagonState(entity)) and near(entity, Config.WagonInteractDistance + 3.0) end,
            onSelect = function(data) sendAway(data.entity) end,
        },
        {
            name = 'multiwagons_stock', label = _L('stock_carcass'), icon = 'fa-solid fa-paw',
            distance = Config.TargetDistance,
            canInteract = function(entity)
                local st = wagonState(entity)
                return st ~= nil and maxAnimalsOf(st.model) > 0 and isCarrying()
            end,
            onSelect = function(data) StoreCarriedEntityInWagon(data.entity) end,
        },
        {
            name = 'multiwagons_carcass', label = _L('see_carcass'), icon = 'fa-solid fa-boxes-stacked',
            distance = Config.TargetDistance,
            canInteract = function(entity)
                local st = wagonState(entity)
                return isMine(st) and maxAnimalsOf(st.model) > 0
            end,
            onSelect = function(data) CarcassInWagon(data.entity) end,
        },
    })
    targetsAdded = true
    MCI.Count('targets', 1)
end

local function createPrompt(labelKey, control, group)
    local prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, GetHashKey(control))
    UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', _L(labelKey)))
    UiPromptSetEnabled(prompt, false)
    UiPromptSetVisible(prompt, false)
    UiPromptSetHoldMode(prompt, 1000)
    UiPromptSetGroup(prompt, group, 0)
    UiPromptRegisterEnd(prompt)
    return prompt
end

local function show(prompt, on)
    UiPromptSetEnabled(prompt, on)
    UiPromptSetVisible(prompt, on)
end

--- The nearest marked wagon within Config.WagonInteractDistance (nil when none).
local function closestWagon()
    if IsPedInAnyVehicle(cache.ped, false) then return nil end
    local pos = GetEntityCoords(cache.ped)
    local best, bestDist = nil, Config.WagonInteractDistance + 3.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if wagonState(veh) then
            local d = math.min(#(pos - GetEntityCoords(veh)), #(pos - backPoint(veh)))
            if d <= bestDist then best, bestDist = veh, d end
        end
    end
    return best
end

local function buildPrompts()
    promptLoop = promptLoop + 1
    local myLoop = promptLoop
    CreateThread(function()
        local group = GetRandomIntInRange(0, 0xffffff)
        local stash = createPrompt('storage', Config.Keys.OpenWagonStash, group)
        local flee = createPrompt('send_away', Config.Keys.FleeWagon, group)
        local carcass = createPrompt('see_carcass', Config.Keys.CarcassMenu, group)
        local stock = createPrompt('stock_carcass', Config.Keys.SeeCarcass, group)
        MCI.Count('prompts', 4)

        local target, st, nextScan = nil, nil, 0
        while myLoop == promptLoop do
            local now = GetGameTimer()
            if now >= nextScan then
                nextScan = now + 500
                target = closestWagon()
                st = target and wagonState(target)
            end
            if target and st and not openMenu and not IsNuiFocused() then
                local mine = isMine(st)
                local animals = maxAnimalsOf(st.model) > 0
                show(stash, true)
                show(flee, mine)
                show(carcass, mine and animals)
                show(stock, animals)
                Citizen.InvokeNative(0xC65A45D4453C2627, group, CreateVarString(10, 'LITERAL_STRING', st.name or _L('your_wagon')), 1) -- UiPromptSetActiveGroupThisFrame

                if UiPromptHasHoldModeCompleted(stash) then
                    show(stash, false)
                    openStash(target)
                    Wait(1000)
                elseif mine and UiPromptHasHoldModeCompleted(flee) then
                    show(flee, false)
                    sendAway(target)
                    target = nil
                    Wait(1000)
                elseif mine and animals and UiPromptHasHoldModeCompleted(carcass) then
                    show(carcass, false)
                    CarcassInWagon(target)
                    Wait(1000)
                elseif animals and UiPromptHasHoldModeCompleted(stock) then
                    show(stock, false)
                    StoreCarriedEntityInWagon(target)
                    Wait(1000)
                end
                Wait(0)
            else
                Wait(250)
            end
        end
        for _, p in ipairs({ stash, flee, carcass, stock }) do UiPromptDelete(p) end
        MCI.Count('prompts', -4)
    end)
end

MCI.Run(Config.Interact, function(mode)
    if mode == 'target' then buildTargets() else buildPrompts() end
end, function(mode)
    if mode == 'target' then
        if targetsAdded and MCI.HasTarget() then
            pcall(function() exports.MULTItarget:removeGlobalVehicle(TARGET_NAMES) end)
        end
        if targetsAdded then MCI.Count('targets', -1) end
        targetsAdded = false
    else
        promptLoop = promptLoop + 1   -- the prompt loop ends and deletes its prompts
    end
end)

-- ---------------------------------------------------------------
-- exports and stop
-- ---------------------------------------------------------------

--- Your wagon that is out: entity, wagon id, model (nil when none).
exports('GetMyWagon', function()
    if mywagon and DoesEntityExist(mywagon) then return mywagon, wagonID, wagonModel end
    return nil
end)
exports('CallWagon', CallWagon)
exports('SendAway', function() DeleteWagon() end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if mywagon and DoesEntityExist(mywagon) then
        TriggerServerEvent('MULTIwagons:server:removeWagon', NetworkGetNetworkIdFromEntity(mywagon))
    end
    clearLocal()
end)
