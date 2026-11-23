-- ============================================================
-- MULTIbathing :: client
-- The game's own bathing scene at the bath houses: buy a bath at the
-- counter (MULTItarget, hold Left Alt, or a hold-key prompt), scrub,
-- order the luxury service, get out. In the tub the game's own prompts
-- are used. Nothing is drawn in the world.
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- ============================================================

local BathingPed = nil
local Prompts = {}      -- [id] = prompt handle
local Created = {}      -- { type, handle } cleaned up when the resource stops
local PromptsEnabled = false
local zoneIds, promptNames = {}, {}

local function dbg(...)
    if Config.Debug then print('[MULTIbathing]', ...) end
end

LocalPlayer.state.isBathingActive = false

exports('IsBathingActive', function() return LocalPlayer.state.isBathingActive end)

---------------------------------
-- helpers
---------------------------------
local function loadModel(model)
    RequestModel(model)
    local untilTime = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < untilTime do Wait(10) end
end

-- the game's move network with init params needs a struct, made in client/structs.js
local function moveNetwork(ped, network, clipset, clipsetVar, varName)
    TriggerEvent('MULTIbathing:moveNetwork', { ped, network, clipset, clipsetVar, varName })
end

local function loadStreamings()
    for _, d in ipairs({ 'REGULAR@ARTHUR', 'REGULAR@RAG', 'DELUXE@ARTHUR', 'DELUXE@MAID' }) do
        RequestAnimDict('MINI_GAMES@BATHING@' .. d)
        RequestClipSet('CLIPSET@MINI_GAMES@BATHING@' .. d)
    end
    Citizen.InvokeNative(0x2B6529C54D29037A, 'Script_Mini_Game_Bathing_Regular') -- _REQUEST_MOVE_NETWORK_DEF
    Citizen.InvokeNative(0x2B6529C54D29037A, 'Script_Mini_Game_Bathing_Deluxe')
end

local function unloadStreamings()
    for _, d in ipairs({ 'REGULAR@ARTHUR', 'REGULAR@RAG', 'DELUXE@ARTHUR', 'DELUXE@MAID' }) do
        RemoveAnimDict('MINI_GAMES@BATHING@' .. d)
        RemoveClipSet('CLIPSET@MINI_GAMES@BATHING@' .. d)
    end
    Citizen.InvokeNative(0x57A197AD83F66BBF, 'Script_Mini_Game_Bathing_Regular') -- _REMOVE_MOVE_NETWORK_DEF
    Citizen.InvokeNative(0x57A197AD83F66BBF, 'Script_Mini_Game_Bathing_Deluxe')
end

local function undress()
    SetPedAllWeaponsVisibility(cache.ped, false)
    pcall(function() exports.MULTIcore:ApplyComps(cache.ped, {}) end)
end

local function dress()
    local health = GetEntityHealth(cache.ped)
    local maxStamina = Citizen.InvokeNative(0xCB42AFE2B613EE55, cache.ped, Citizen.ResultAsFloat())
    local stamina = Citizen.InvokeNative(0x775A1CA7893AA8B5, cache.ped, Citizen.ResultAsFloat()) / maxStamina * 100
    -- MULTIcore puts the saved look back on; MULTItailor then puts the worn clothes back
    pcall(function() exports.MULTIcore:ReloadLook() end)
    Wait(1000)
    SetPedAllWeaponsVisibility(cache.ped, true)
    SetEntityHealth(cache.ped, health)
    Citizen.InvokeNative(0xC3D4B754C0E86B9E, cache.ped, stamina)
end

local function setCleanliness(rag, value)
    for _, e in ipairs({ cache.ped, rag, BathingPed }) do
        if e and DoesEntityExist(e) then
            for _, part in ipairs({ 'Right_Arm', 'Left_Arm', 'Left_Leg', 'Right_Leg', 'Head' }) do
                SetTaskMoveNetworkSignalFloat(e, 'Cleanliness_' .. part, value)
            end
        end
    end
end

local function newScene(town, name)
    local scene = Citizen.InvokeNative(0x1FCA98E33C1437B3, Config.BathingZones[town].dict, 0, name, false, true) -- _CREATE_ANIM_SCENE
    SetAnimSceneEntity(scene, 'ARTHUR', cache.ped, 0)
    SetAnimSceneEntity(scene, 'Door', GetEntityByDoorhash(Config.BathingZones[town].door, 0), 0)
    return scene
end

local function playScene(scene)
    LoadAnimScene(scene)
    while not Citizen.InvokeNative(0x477122B8D05E7968, scene, 1, 0) do Wait(10) end -- _IS_ANIM_SCENE_LOADED
end

local function sceneDone(scene) return Citizen.InvokeNative(0xD8254CB2C586412B, scene, true) end -- _IS_ANIM_SCENE_FINISHED
local function sceneTime(scene) return Citizen.InvokeNative(0x3FBC3F51BF12DFBF, scene, Citizen.ResultAsFloat()) end
local function sceneExists(scene) return Citizen.InvokeNative(0x25557E324489393C, scene) end
local function deleteScene(scene) Citizen.InvokeNative(0x84EEDB2C6E650000, scene) end -- _DELETE_ANIM_SCENE

---------------------------------
-- prompts in the tub (the game's own prompts)
---------------------------------
local function registerPrompts()
    local list = {
        { id = 'SCRUB', label = _L('prompt_scrub'), control = `INPUT_CONTEXT_X`, time = 2000 },
        { id = 'REQUEST_DELUXE_BATHING', label = _L('prompt_luxury_bath', Config.DeluxeBathPrice) },
        { id = 'STOP_BATHING', label = _L('prompt_leave'), control = `INPUT_INTERACT_NEG` },
    }
    for _, p in ipairs(list) do
        local prompt = Citizen.InvokeNative(0x04F97DE45A519419, Citizen.ResultAsInteger()) -- _UI_PROMPT_REGISTER_BEGIN
        Citizen.InvokeNative(0x5DD02A8318420DD7, prompt, CreateVarString(10, 'LITERAL_STRING', p.label))
        Citizen.InvokeNative(0xB5352B7494A08258, prompt, p.control or 0xDFF812F9)
        Citizen.InvokeNative(0x94073D5CA3F16B7B, prompt, p.time or 1000) -- hold mode
        Citizen.InvokeNative(0xF7AA2696A22AD8B9, prompt) -- _UI_PROMPT_REGISTER_END
        Citizen.InvokeNative(0x8A0FB4D03A630D21, prompt, false)
        Citizen.InvokeNative(0x71215ACCFDE075EE, prompt, false)
        Created[#Created + 1] = { type = 'PROMPT', handle = prompt }
        Prompts[p.id] = prompt
    end
end

local function togglePrompts(ids, on)
    if ids == 'ALL' then
        ids = {}
        for id in pairs(Prompts) do ids[#ids + 1] = id end
    end
    for _, id in ipairs(ids) do
        local p = Prompts[id]
        if p then
            Citizen.InvokeNative(0x8A0FB4D03A630D21, p, on) -- _UI_PROMPT_SET_ENABLED
            Citizen.InvokeNative(0x71215ACCFDE075EE, p, on) -- _UI_PROMPT_SET_VISIBLE
        end
    end
    PromptsEnabled = on
end

local function promptDone(id) return Prompts[id] and Citizen.InvokeNative(0xE0F65F0640EF0617, Prompts[id]) end
local function promptOn(id) return Prompts[id] and PromptIsEnabled(Prompts[id]) end

---------------------------------
-- leaving the tub
---------------------------------
local exitPremium

local function exitBathing(animscene, town, cam)
    if DoesEntityExist(BathingPed) then
        exitPremium(animscene, town, cam)
        return
    end
    if sceneExists(animscene) then deleteScene(animscene) end

    local scene = newScene(town, 's_regular_outro')
    playScene(scene)
    StartAnimScene(scene)

    if DoesCamExist(cam) then
        RenderScriptCams(false, false, 0, true, false, 0)
        DestroyCam(cam)
    end

    while sceneTime(scene) <= 0.35 do Wait(1) end
    while not sceneDone(scene) do Wait(10) end

    LocalPlayer.state.invincible = false
    dress()
    unloadStreamings()
    N_0x69d65e89ffd72313(false, false)
    TriggerMusicEvent('MG_BATHING_STOP')
    Citizen.InvokeNative(0x704C908E9C405136, cache.ped)
    TriggerServerEvent('MULTIbathing:server:finish', town)

    local female = Citizen.InvokeNative(0xE5822422197BBBA3, scene, 'Female', false)
    if DoesEntityExist(female) then DeletePed(female) end

    SetPedCanLegIk(cache.ped, true)
    SetPedLegIkMode(cache.ped, 2)
    LocalPlayer.state.isBathingActive = false
end

exitPremium = function(animscene, town, cam, disableScrub)
    local scene = newScene(town, 's_deluxe_outro')
    SetAnimSceneEntity(scene, 'Female', BathingPed, 0)
    playScene(scene)
    StartAnimScene(scene)
    RenderScriptCams(false, false, 0, true, false, 0)
    while not sceneDone(scene) do Wait(10) end

    moveNetwork(cache.ped, 'Script_Mini_Game_Bathing_Regular', `CLIPSET@MINI_GAMES@BATHING@REGULAR@ARTHUR`, `DEFAULT`, 'BATHING')

    togglePrompts({ 'STOP_BATHING', 'SCRUB' }, true)
    if promptOn('SCRUB') and disableScrub then togglePrompts({ 'SCRUB' }, false) end

    RenderScriptCams(true, true, 0, true, false, 0)
    if DoesEntityExist(BathingPed) then DeletePed(BathingPed) end
    BathingPed = nil
end

---------------------------------
-- in the tub
---------------------------------
local bath = nil   -- { town, animscene, cam } while bathing

RegisterNetEvent('MULTIbathing:client:start', function(town)
    local zone = Config.BathingZones[town]
    if not zone or LocalPlayer.state.isBathingActive then return end
    LocalPlayer.state.isBathingActive = true
    LocalPlayer.state.invincible = true

    SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true, 0, true, true)
    Citizen.InvokeNative(0x4820A6939D7CEF28, cache.ped, true) -- long arms on the shoulder
    HolsterPedWeapons(cache.ped, false, false, false, true)

    loadStreamings()
    loadModel(`P_CS_RAG02X`)
    local rag = CreateObject(`P_CS_RAG02X`, GetEntityCoords(cache.ped), false, false, false, false, true)
    Created[#Created + 1] = { type = 'PED', handle = rag }
    SetModelAsNoLongerNeeded(`P_CS_RAG02X`)

    SetPedCanLegIk(cache.ped, false)
    SetPedLegIkMode(cache.ped, 0)
    ClearPedTasksImmediately(cache.ped, true, true)

    local animscene = newScene(town, 's_regular_intro')
    playScene(animscene)
    TriggerMusicEvent('MG_BATHING_START')
    StartAnimScene(animscene)

    while sceneTime(animscene) <= 0.3 do Wait(0) end
    undress()
    while not sceneDone(animscene) do Wait(0) end

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', 1)
    Created[#Created + 1] = { type = 'CAM', handle = cam }
    N_0x69d65e89ffd72313(true, true)
    SetCamCoord(cam, GetFinalRenderedCamCoord(), 0.0, 0.4, 0.5)
    SetCamRot(cam, GetFinalRenderedCamRot(1), 1)
    SetCamFov(cam, GetFinalRenderedCamFov())
    RenderScriptCams(true, true, 0, true, false, 0)

    bath = { town = town, animscene = animscene, cam = cam }
    togglePrompts({ 'STOP_BATHING', 'REQUEST_DELUXE_BATHING', 'SCRUB' }, true)

    moveNetwork(cache.ped, 'Script_Mini_Game_Bathing_Regular', `CLIPSET@MINI_GAMES@BATHING@REGULAR@ARTHUR`, `DEFAULT`, 'BATHING')
    moveNetwork(rag, 'Script_Mini_Game_Bathing_Regular', `CLIPSET@MINI_GAMES@BATHING@REGULAR@RAG`, `DEFAULT`, 'BATHING')
    ForceEntityAiAndAnimationUpdate(rag, true)
    Citizen.InvokeNative(0x55546004A244302A, cache.ped)

    local function partner() return (DoesEntityExist(BathingPed) and BathingPed) or rag end
    local holdTime, mode = 0, 1
    local last = #Config.BathingModes + 1

    while DoesCamExist(cam) do
        while not IsTaskMoveNetworkReadyForTransition(cache.ped) do Wait(100) end

        if promptOn('SCRUB') and mode == last then togglePrompts({ 'SCRUB' }, false) end
        if IsControlPressed(0, `INPUT_CONTEXT_X`) and promptOn('SCRUB') then
            if promptOn('REQUEST_DELUXE_BATHING') then togglePrompts({ 'REQUEST_DELUXE_BATHING' }, false) end

            while GetTaskMoveNetworkState(cache.ped) ~= 'Scrub_Idle' do
                RequestTaskMoveNetworkStateTransition(cache.ped, 'Scrub_Idle')
                RequestTaskMoveNetworkStateTransition(partner(), 'Scrub_Idle')
                Wait(200)
            end

            while IsControlPressed(0, `INPUT_CONTEXT_X`) do
                if promptDone('SCRUB') then
                    if DoesEntityExist(BathingPed) and not Config.BathingModes[mode].deluxe then mode = mode + 1 end
                    local m = Config.BathingModes[mode]
                    holdTime = holdTime + (m.hold_power or 0.05)

                    if GetTaskMoveNetworkState(cache.ped) ~= m.transition then
                        setCleanliness(rag, 0.0)
                        RequestTaskMoveNetworkStateTransition(cache.ped, m.transition)
                        RequestTaskMoveNetworkStateTransition(partner(), m.transition)
                    end
                    SetTaskMoveNetworkSignalFloat(cache.ped, 'scrub_freq', m.scrub_freq)
                    SetTaskMoveNetworkSignalFloat(partner(), 'scrub_freq', m.scrub_freq)
                    setCleanliness(rag, holdTime)

                    if holdTime >= 1.0 then
                        holdTime = 0.0
                        if mode + 1 > #Config.BathingModes then
                            togglePrompts({ 'REQUEST_DELUXE_BATHING', 'SCRUB' }, false)
                            ClearPedEnvDirt(cache.ped)
                            ClearPedBloodDamage(cache.ped)
                            N_0xe3144b932dfdff65(cache.ped, 0.0, -1, 1, 1)
                            ClearPedDamageDecalByZone(cache.ped, 10, 'ALL')
                            Citizen.InvokeNative(0x7F5D88333EE8A86F, cache.ped, 1)
                            mode = last
                            if DoesEntityExist(BathingPed) then
                                Wait(750)
                                exitPremium(bath.animscene, town, cam, true)
                            end
                        else
                            mode = mode + 1
                        end
                        break
                    end
                end
                Wait(100)
            end
            while not IsTaskMoveNetworkReadyForTransition(cache.ped) do Wait(10) end

            local resetTo = ((mode == last) or DoesEntityExist(BathingPed)) and 'Bathing' or 'Scrub_Idle'
            while GetTaskMoveNetworkState(cache.ped) ~= resetTo do
                setCleanliness(rag, 1.0)
                while GetTaskMoveNetworkState(cache.ped) ~= 'Scrub_Idle' do
                    RequestTaskMoveNetworkStateTransition(cache.ped, 'Scrub_Idle')
                    RequestTaskMoveNetworkStateTransition(partner(), 'Scrub_Idle')
                    Wait(200)
                end
                if resetTo ~= 'Scrub_Idle' and (DoesEntityExist(BathingPed) and not IsControlPressed(0, `INPUT_CONTEXT_X`) or not DoesEntityExist(BathingPed)) then
                    RequestTaskMoveNetworkStateTransition(cache.ped, 'Bathing')
                    RequestTaskMoveNetworkStateTransition(partner(), 'Bathing')
                elseif resetTo ~= 'Scrub_Idle' and DoesEntityExist(BathingPed) and IsControlPressed(0, `INPUT_CONTEXT_X`) then
                    resetTo = 'Scrub_Idle'
                end
                Wait(500)
            end
        end

        if promptDone('REQUEST_DELUXE_BATHING') then
            togglePrompts('ALL', false)
            TriggerServerEvent('MULTIbathing:server:deluxe', town)
            Wait(500)
        end

        if promptDone('STOP_BATHING') then
            togglePrompts('ALL', false)
            exitBathing(bath.animscene, town, cam)
            Wait(500)
        end
        Wait(10)
    end
    bath = nil
end)

RegisterNetEvent('MULTIbathing:client:deluxe', function(town)
    if not bath or bath.town ~= town then return end
    local zone = Config.BathingZones[town]
    if sceneExists(bath.animscene) then deleteScene(bath.animscene) end

    local scene = newScene(town, 's_deluxe_intro')
    local model = IsPedMale(cache.ped) and zone.lady or zone.guy
    loadModel(model)
    BathingPed = CreatePed(model, GetEntityCoords(cache.ped) - vector3(0.0, 0.0, -5.0), 0.0, false, false, true, true)
    Created[#Created + 1] = { type = 'PED', handle = BathingPed }
    Citizen.InvokeNative(0x283978A15512B2FE, BathingPed, true) -- _SET_RANDOM_OUTFIT_VARIATION
    SetAnimSceneEntity(scene, 'Female', BathingPed, 0)
    SetModelAsNoLongerNeeded(model)

    playScene(scene)
    PlaySoundFrontend('BATHING_DOOR_KNOCK_MASTER', 0, true, 0)
    Wait(1000)
    StartAnimScene(scene)
    RenderScriptCams(false, false, 0, true, false, 0)
    while not sceneDone(scene) do Wait(10) end
    deleteScene(scene)
    bath.animscene = scene

    moveNetwork(cache.ped, 'Script_Mini_Game_Bathing_Deluxe', `CLIPSET@MINI_GAMES@BATHING@DELUXE@ARTHUR`, `DEFAULT`, 'BATHING')
    moveNetwork(BathingPed, 'Script_Mini_Game_Bathing_Deluxe', `CLIPSET@MINI_GAMES@BATHING@DELUXE@MAID`, `DEFAULT`, 'BATHING')

    togglePrompts({ 'STOP_BATHING', 'SCRUB' }, true)
    RenderScriptCams(true, true, 0, true, false, 0)
end)

RegisterNetEvent('MULTIbathing:client:deluxeRefused', function()
    togglePrompts({ 'REQUEST_DELUXE_BATHING' }, false)
    togglePrompts({ 'STOP_BATHING', 'SCRUB' }, true)
end)

---------------------------------
-- the counter, blips and doors
---------------------------------
local function buyBath(town)
    if LocalPlayer.state.isBathingActive then return end
    TriggerServerEvent('MULTIbathing:server:start', town)
end

AddEventHandler('MULTIbathing:client:counter', function(town) buyBath(town) end)

CreateThread(function()
    registerPrompts()
    for _, zone in pairs(Config.BathingZones) do
        if Config.ShowBlips then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 0xB04092F8, zone.consumer) -- BLIP_ADD_FOR_COORDS
            SetBlipSprite(blip, `blip_bath_house`, true)
            SetBlipName(blip, _L('blip_name'))
            Created[#Created + 1] = { type = 'BLIP', handle = blip }
        end
        if Config.LockDoors and zone.door and not IsDoorRegisteredWithSystem(zone.door) then
            Citizen.InvokeNative(0xD99229FE93B46286, zone.door, 1, 1, 0, 0, 0, 0) -- _ADD_DOOR_TO_SYSTEM_NEW
            DoorSystemSetDoorState(zone.door, 1)
        end
    end
end)

MCI.Run(Config.Interact, function(mode)
    for town, zone in pairs(Config.BathingZones) do
        if mode == 'prompt' then
            local name = 'multibathing_' .. town
            MCI.AddPrompt(name, zone.consumer, Config.Key, _L('prompt_bath', Config.NormalBathPrice), {
                type = 'client', event = 'MULTIbathing:client:counter', args = { town },
            }, Config.PromptDistance)
            promptNames[#promptNames + 1] = name
        else
            zoneIds[#zoneIds + 1] = MCI.AddZone({
                coords = zone.consumer,
                radius = Config.TargetRadius,
                options = {
                    {
                        name = 'multibathing_bath',
                        icon = 'fas fa-bath',
                        label = _L('prompt_bath', Config.NormalBathPrice),
                        distance = Config.TargetDistance,
                        canInteract = function() return not LocalPlayer.state.isBathingActive end,
                        onSelect = function() buyBath(town) end,
                    },
                },
            })
        end
    end
    dbg(('%d points made'):format(#zoneIds + #promptNames))
end, function()
    for _, id in ipairs(zoneIds) do MCI.RemoveZone(id) end
    zoneIds = {}
    for _, name in ipairs(promptNames) do MCI.RemovePrompt(name) end
    promptNames = {}
end)

---------------------------------
-- stop
---------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local wasBathing = LocalPlayer.state.isBathingActive
    LocalPlayer.state.isBathingActive = false
    LocalPlayer.state.invincible = false
    for _, e in ipairs(Created) do
        if e.type == 'PED' then
            if DoesEntityExist(e.handle) then DeleteEntity(e.handle) end
        elseif e.type == 'BLIP' then
            RemoveBlip(e.handle)
        elseif e.type == 'PROMPT' then
            Citizen.InvokeNative(0x00EDE88D4D13CF59, e.handle) -- _UI_PROMPT_DELETE
        elseif e.type == 'CAM' then
            if DoesCamExist(e.handle) then RenderScriptCams(false, false, 0, false, false, false) DestroyCam(e.handle) end
        end
    end
    if wasBathing then
        ClearPedTasksImmediately(cache.ped, true, true)
        pcall(function() exports.MULTIcore:ReloadLook() end)
    end
end)
