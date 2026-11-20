-- ============================================================
-- MULTIhorses :: the player's horse (client)
-- Whistle, walk to the player, follow, send away, care animations,
-- death, saving health and stamina, the saddlebag / care options on the
-- horse (MULTItarget or the game's prompts when you look at the horse).
-- Items, money and the fallen / revived state are decided by the server.
--
-- The spawn sequence (config flags, ownership, personality, companion
-- decorator, gender expression, care interactions) follows rsg-horses
-- client/client.lua (RSG v2 framework, GPL v3; see CREDITS.md).
-- GPL v3, part of MULTIcore.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local horse = 0            -- the spawned horse ped (0 = none)
local data = nil           -- what the server sent for it (horseid, name, model, tack ...)
local blip = nil
local dead, deadAt = false, 0
local lantern = false
local whistleAt = 0
local walking = false
local horsePrompts = nil   -- prompt mode: { group, list = { [action] = prompt } }

-- natives (femga natives.json)
local BLIP_ADD_FOR_ENTITY = 0x23F74C2FDA6E7C61
local SET_BLIP_NAME = 0x9CB1A1623062F402                 -- _SET_BLIP_NAME
local DECOR_SET_BOOL = 0xFE26E4609B1C3772
local SET_PLAYER_OWNS_MOUNT = 0xE6D4E435B56D5BD0         -- _SET_PLAYER_OWNS_MOUNT
local SET_PED_OWNS_ANIMAL = 0x931B241409216C1F
local SET_ANIMAL_IS_WILD = 0xAEB97D84CDF3C00B            -- _SET_ANIMAL_IS_WILD
local SET_PED_PERSONALITY = 0xB8B6430EAD2D2437           -- _SET_PED_PERSONALITY
local SET_PED_PROMPT_NAME = 0x4A48B6E03BABB4AC           -- _SET_PED_PROMPT_NAME
local SET_PED_CONFIG_FLAG = 0x1913FE4CBF41C463
local APPLY_SHOP_ITEM_TO_PED = 0xD3A7B003ED343FD9        -- _APPLY_SHOP_ITEM_TO_PED
local REMOVE_TAG_FROM_META_PED = 0xD710A5007C2AC539
local UPDATE_PED_VARIATION = 0xCC8CA3E88256E58F          -- _UPDATE_PED_VARIATION
local GET_ATTRIBUTE_CORE_VALUE = 0x36731AC041289BB1      -- _GET_ATTRIBUTE_CORE_VALUE
local SET_ATTRIBUTE_CORE_VALUE = 0xC6258F41D86676E0      -- _SET_ATTRIBUTE_CORE_VALUE
local TASK_ANIMAL_INTERACTION = 0xCD181A959CFDD7F4
local SET_PED_DIRT_CLEANED = 0xE3144B932DFDFF65          -- _SET_PED_DIRT_CLEANED
local SET_CHAR_EXPRESSION = 0x5653AB26C82938CF           -- _SET_CHAR_EXPRESSION
local TASK_GO_TO_ENTITY = 0x6A071245EB0D1882
local TASK_FOLLOW_TO_OFFSET_OF_ENTITY = 0x304AE42E357B8C7E
local TASK_ANIMAL_FLEE = 0xA899B61C66F09134
local TASK_START_SCENARIO_IN_PLACE_HASH = 0x524B54361229154F
local PROMPT_GET_GROUP_FOR_TARGET = 0xB796970BD125FCE8   -- _UI_PROMPT_GET_GROUP_ID_FOR_TARGET_ENTITY
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE

-- values taken from rsg-horses (working RSG v2 code)
local BLIP_HORSE_STYLE = -1230993421                     -- blip style rsg-horses gives the player's horse -- UNVERIFIED locally
local EXPRESSION_GENDER = 41611                          -- _SET_CHAR_EXPRESSION id rsg-horses uses for mare / stallion -- UNVERIFIED locally
local INTERACTION_FEED = -224471938                      -- TASK_ANIMAL_INTERACTION type rsg-horses uses for feeding -- UNVERIFIED locally
local INTERACTION_MEDICINE = -1355254781                 -- TASK_ANIMAL_INTERACTION type rsg-horses uses for the stimulant -- UNVERIFIED locally
local LANTERN_HASH = 0x635E387C                          -- HORSE_EQUIPMENT_SADDLE_LANTERN_BASIC (femga tack_catalog.lua)
local LANTERN_CATEGORY = 0x1530BE1C                      -- lantern meta category (femga tack_catalog.lua)
-- config flags rsg-horses sets on a player horse (flag = value)
local HORSE_FLAGS = {
    [6] = true, [113] = false, [136] = false, [208] = true, [209] = true, [211] = true,
    [277] = true, [297] = true, [300] = false, [301] = false, [312] = false, [319] = true,
    [400] = true, [412] = false, [419] = false, [438] = false, [439] = false, [440] = false,
    [561] = true, [24] = false, [25] = false, [48] = false,
}

local function notify(text, kind)
    exports.MULTIcore:Notify({ text = text, title = _L('title'), type = kind or 'info' })
end

local function exists() return horse ~= 0 and DoesEntityExist(horse) end
local function distance()
    if not exists() then return math.huge end
    return #(GetEntityCoords(cache.ped) - GetEntityCoords(horse))
end

local function act(action, args)
    return lib.callback.await('MULTIhorses:action', false, action, args)
end

local function playerDown()
    local pd = RSGCore.Functions.GetPlayerData()
    local meta = pd and pd.metadata or {}
    return meta.isdead or meta.ishandcuffed or LocalPlayer.state.isDead == true
end

local function getCore(i)
    return tonumber(Citizen.InvokeNative(GET_ATTRIBUTE_CORE_VALUE, horse, i, Citizen.ResultAsInteger())) or 0
end

local function setCore(i, v)
    Citizen.InvokeNative(SET_ATTRIBUTE_CORE_VALUE, horse, i, math.max(0, math.min(100, math.floor(v))))
end

local function saveState()
    if exists() and not dead then
        TriggerServerEvent('MULTIhorses:server:state', getCore(0), getCore(1))
    end
end

-- ---------------------------------------------------------------
-- tack
-- ---------------------------------------------------------------
local function applyTack(tack)
    if not exists() then return end
    for _, cat in ipairs(Config.Tack.Categories or {}) do
        local hash = tack and tack[cat.key]
        if hash then
            Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, horse, hash, true, true, true)
        else
            Citizen.InvokeNative(REMOVE_TAG_FROM_META_PED, horse, cat.metaCategory, 0)
        end
    end
    if lantern then Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, horse, LANTERN_HASH, true, true, true) end
    Citizen.InvokeNative(UPDATE_PED_VARIATION, horse, false, true, true, true, false)
end

-- ---------------------------------------------------------------
-- interaction on the horse: MULTItarget or the game's prompts
-- ---------------------------------------------------------------
local TARGET_NAMES = { 'mh_saddlebag', 'mh_brush', 'mh_feed', 'mh_follow', 'mh_sendaway', 'mh_revive' }

-- 'target' or 'prompt', decided by MCI.Run (@MULTIcore/lib/interact.lua) once MULTItarget is up
local horseMode = nil

local function useTarget()
    if horseMode then return horseMode == 'target' end
    return Config.Interact ~= 'prompt' and MCI.HasTarget()
end

local sendAway, follow -- forward

local function runAction(action)
    CreateThread(function()
        if action == 'follow' then return follow() end
        if action == 'sendaway' then return sendAway() end
        act(action)
    end)
end

local function removeInteraction()
    if horse ~= 0 then MCI.RemoveEntity(horse) end
    if horsePrompts then
        for _, p in pairs(horsePrompts.list) do PromptDelete(p) end
        MCI.Count('prompts', -#TARGET_NAMES)
        horsePrompts = nil
    end
end

local function addInteraction()
    if horse == 0 or not DoesEntityExist(horse) then return end
    removeInteraction()
    if useTarget() then
        local d = Config.InteractDistance
        local alive = function() return not dead end
        MCI.AddEntity(horse, {
            { name = 'mh_saddlebag', icon = 'fas fa-bag-shopping', label = _L('opt_saddlebag'), distance = d, onSelect = function() runAction('saddlebag') end },
            { name = 'mh_brush', icon = 'fas fa-broom', label = _L('opt_brush'), distance = d, canInteract = alive, onSelect = function() runAction('brush') end },
            { name = 'mh_feed', icon = 'fas fa-carrot', label = _L('opt_feed'), distance = d, canInteract = alive, onSelect = function() runAction('feed') end },
            { name = 'mh_follow', icon = 'fas fa-person-walking', label = _L('opt_follow'), distance = d, canInteract = alive, onSelect = function() runAction('follow') end },
            { name = 'mh_sendaway', icon = 'fas fa-flag', label = _L('opt_sendaway'), distance = d, canInteract = alive, onSelect = function() runAction('sendaway') end },
            { name = 'mh_revive', icon = 'fas fa-syringe', label = _L('opt_revive'), distance = d, canInteract = function() return dead end, onSelect = function() runAction('revive') end },
        })
        return
    end
    -- prompts in the horse's own prompt group (shown when the player looks at the horse)
    local group = Citizen.InvokeNative(PROMPT_GET_GROUP_FOR_TARGET, horse, Citizen.ResultAsInteger())
    horsePrompts = { group = group, list = {} }
    MCI.Count('prompts', #TARGET_NAMES)
    local function add(action, control, label)
        local p = PromptRegisterBegin()
        PromptSetControlAction(p, control)
        PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', label))
        PromptSetEnabled(p, true)
        PromptSetVisible(p, true)
        PromptSetStandardMode(p, true)
        PromptSetGroup(p, group, 0)
        PromptRegisterEnd(p)
        horsePrompts.list[action] = p
    end
    local c = Config.HorsePrompts
    add('saddlebag', c.Saddlebag, _L('opt_saddlebag'))
    add('brush', c.Brush, _L('opt_brush'))
    add('feed', c.Feed, _L('opt_feed'))
    add('follow', c.Follow, _L('opt_follow'))
    add('sendaway', c.SendAway, _L('opt_sendaway'))
    add('revive', c.Revive, _L('opt_revive'))
end

-- options on the called horse; built again if MULTItarget starts or stops later
MCI.Run(Config.Interact, function(mode)
    horseMode = mode
    addInteraction()
end, function()
    removeInteraction()
    horseMode = nil
end)

CreateThread(function()
    while true do
        if horsePrompts and exists() then
            Wait(0)
            for action, p in pairs(horsePrompts.list) do
                local show = (action == 'revive') == dead or action == 'saddlebag'
                PromptSetEnabled(p, show)
                PromptSetVisible(p, show)
                if show and PromptHasStandardModeCompleted(p) then runAction(action) end
            end
        else
            Wait(500)
        end
    end
end)

-- ---------------------------------------------------------------
-- spawn / despawn
-- ---------------------------------------------------------------
local function despawn(tellServer)
    if horse ~= 0 then
        saveState()
        removeInteraction()
        if blip then RemoveBlip(blip) blip = nil end
        if DoesEntityExist(horse) then
            NetworkRequestControlOfEntity(horse)
            SetEntityAsMissionEntity(horse, true, true)
            DeleteEntity(horse)
        end
    end
    horse, data, dead, lantern, walking = 0, nil, false, false, false
    if tellServer ~= false then TriggerServerEvent('MULTIhorses:server:despawned') end
end
MHClient = MHClient or {}
MHClient.despawn = despawn

local function walkToPlayer()
    if walking or not exists() then return end
    walking = true
    CreateThread(function()
        Citizen.InvokeNative(TASK_GO_TO_ENTITY, horse, cache.ped, -1, Config.ArriveDistance, Config.WalkSpeed, 0, 0)
        local deadline = GetGameTimer() + 60000
        while walking and exists() and GetGameTimer() < deadline do
            if distance() < Config.ArriveDistance + 1.0 then ClearPedTasks(horse, true, true) break end
            Wait(500)
        end
        walking = false
    end)
end

--- Spawns the active horse behind the player (or at `at`), with the data the server sends.
local function spawn(at)
    local info, err, extra = lib.callback.await('MULTIhorses:callHorse', false)
    if not info then return notify(_L('err_' .. tostring(err), extra or ''), 'error') end
    local model = joaat(info.model)
    if not IsModelValid(model) then return notify(_L('err_error'), 'error') end
    RequestModel(model, false)
    local deadline = GetGameTimer() + Config.LoadTimeoutMs
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) then return notify(_L('err_error'), 'error') end

    despawn(false)
    local pos = at or GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, -Config.SpawnDistance, 0.0)
    local found, groundZ = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 10.0, false)
    local z = found and groundZ or pos.z
    horse = CreatePed(model, pos.x, pos.y, z, GetEntityHeading(cache.ped), true, true, false, false)
    local t = 0
    while not DoesEntityExist(horse) and t < 200 do Wait(10) t = t + 1 end
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(horse) then horse = 0 return end

    data = info
    dead = false
    SetEntityAsMissionEntity(horse, true, true)
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, horse, true)
    for flag, val in pairs(HORSE_FLAGS) do Citizen.InvokeNative(SET_PED_CONFIG_FLAG, horse, flag, val) end
    Citizen.InvokeNative(DECOR_SET_BOOL, horse, 'HorseCompanion', true)   -- vorp_stables-style marker other scripts look for
    Citizen.InvokeNative(SET_PED_OWNS_ANIMAL, cache.ped, horse, false)
    Citizen.InvokeNative(SET_PED_PERSONALITY, horse, joaat('PLAYER_HORSE'))
    Citizen.InvokeNative(SET_ANIMAL_IS_WILD, horse, false)
    if Config.OwnerOnlyRide then Citizen.InvokeNative(SET_PLAYER_OWNS_MOUNT, PlayerId(), horse) end
    Citizen.InvokeNative(SET_PED_PROMPT_NAME, horse, info.name)
    if Config.Genders then
        Citizen.InvokeNative(SET_CHAR_EXPRESSION, horse, EXPRESSION_GENDER, info.gender == 'female' and 1.0 or 0.0)
    end
    applyTack(info.tack)
    setCore(0, info.health or 100)
    setCore(1, info.stamina or 100)
    if Config.Blip then
        blip = Citizen.InvokeNative(BLIP_ADD_FOR_ENTITY, BLIP_HORSE_STYLE, horse)
        Citizen.InvokeNative(SET_BLIP_NAME, blip, info.name)
    end
    addInteraction()
    TriggerServerEvent('MULTIhorses:server:spawned', NetworkGetNetworkIdFromEntity(horse))
    walkToPlayer()
end

-- ---------------------------------------------------------------
-- whistle, follow, send away
-- ---------------------------------------------------------------
local function whistle()
    if GetGameTimer() - whistleAt < Config.WhistleCooldownMs then return end
    whistleAt = GetGameTimer()
    if playerDown() or IsPedOnMount(cache.ped) then return end
    if exists() and dead then return notify(_L('err_horse_dead'), 'error') end
    if exists() and distance() <= Config.WalkDistance then
        walkToPlayer()
    else
        spawn()
    end
end

follow = function()
    if not exists() or dead then return end
    walking = false
    Citizen.InvokeNative(TASK_FOLLOW_TO_OFFSET_OF_ENTITY, horse, cache.ped, 0.0, -2.5, 0.0, Config.FollowSpeed, -1, 2.0, true)
    notify(_L('following', data and data.name or ''), 'info')
end

sendAway = function()
    if not exists() then return end
    local ped = horse
    saveState()
    removeInteraction()
    if blip then RemoveBlip(blip) blip = nil end
    walking = false
    Citizen.InvokeNative(TASK_ANIMAL_FLEE, ped, cache.ped, -1)
    horse, data = 0, nil
    TriggerServerEvent('MULTIhorses:server:despawned')
    SetTimeout(Config.FleeDespawnMs, function()
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end)
end

CreateThread(function()
    local key = RSGCore.Shared.Keybinds[Config.WhistleKey]
    if not key then return print(('^1[MULTIhorses] Config.WhistleKey "%s" is not in MULTIcore keybinds^7'):format(tostring(Config.WhistleKey))) end
    while true do
        Wait(0)
        if IsControlJustPressed(0, key) then whistle() end
    end
end)

if Config.Commands.SendAway ~= '' then
    RegisterCommand(Config.Commands.SendAway, function() sendAway() end, false)
end

-- ---------------------------------------------------------------
-- death, lost horse, saving
-- ---------------------------------------------------------------
CreateThread(function()
    local lastSave = GetGameTimer()
    while true do
        Wait(Config.CheckIntervalMs)
        if horse ~= 0 then
            if not DoesEntityExist(horse) then
                despawn(true)
            elseif not dead and IsEntityDead(horse) then
                dead, deadAt = true, GetGameTimer()
                walking = false
                TriggerServerEvent('MULTIhorses:server:died')
            elseif dead and GetGameTimer() - deadAt > Config.Revive.BodySeconds * 1000 then
                despawn(true) -- the stable takes the body in; the horse waits there for the vet
            elseif not dead and GetGameTimer() - lastSave > Config.SaveStateSeconds * 1000 then
                lastSave = GetGameTimer()
                saveState()
            end
        end
    end
end)

-- ---------------------------------------------------------------
-- server answers: care animations, tack, name, despawn
-- ---------------------------------------------------------------
RegisterNetEvent('MULTIhorses:client:despawn', function() despawn(false) end)

RegisterNetEvent('MULTIhorses:client:feed', function(item, health, stamina, heal)
    if not exists() then return end
    walking = false
    if heal then
        Citizen.InvokeNative(TASK_ANIMAL_INTERACTION, cache.ped, horse, INTERACTION_MEDICINE, joaat('consumable_horse_stimulant'), 0)
        Wait(3500)
    else
        Citizen.InvokeNative(TASK_ANIMAL_INTERACTION, cache.ped, horse, INTERACTION_FEED, 0, 0)
        Wait(5000)
    end
    if not exists() then return end
    setCore(0, getCore(0) + (tonumber(health) or 0))
    setCore(1, getCore(1) + (tonumber(stamina) or 0))
    if heal then SetEntityHealth(horse, GetEntityMaxHealth(horse), 0) end
    notify(_L('fed', data and data.name or ''), 'success')
end)

RegisterNetEvent('MULTIhorses:client:brush', function(points)
    if not exists() then return end
    walking = false
    Citizen.InvokeNative(TASK_ANIMAL_INTERACTION, cache.ped, horse, joaat('INTERACTION_BRUSH'), 0, 0)
    Wait(8000)
    if not exists() then return end
    Citizen.InvokeNative(SET_PED_DIRT_CLEANED, horse, 0.0, -1, true, true)
    ClearPedEnvDirt(horse)
    ClearPedBloodDamage(horse)
    if (tonumber(points) or 0) > 0 then setCore(1, getCore(1) + points) end
    notify(_L('brushed', data and data.name or ''), 'success')
end)

RegisterNetEvent('MULTIhorses:client:revive', function(health)
    if not exists() then return end
    local at = GetEntityCoords(horse)
    Citizen.InvokeNative(TASK_START_SCENARIO_IN_PLACE_HASH, cache.ped, joaat('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, 0, -1.0, false)
    Wait(4000)
    ClearPedTasks(cache.ped, true, true)
    spawn(at) -- a fresh horse where the body lay, with the cores the server saved
    notify(_L('revived', data and data.name or ''), 'success')
end)

RegisterNetEvent('MULTIhorses:client:lantern', function()
    if not exists() then return end
    lantern = not lantern
    if lantern then
        Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, horse, LANTERN_HASH, true, true, true)
    else
        Citizen.InvokeNative(REMOVE_TAG_FROM_META_PED, horse, LANTERN_CATEGORY, 0)
    end
    Citizen.InvokeNative(UPDATE_PED_VARIATION, horse, false, true, true, true, false)
    notify(_L(lantern and 'lantern_on' or 'lantern_off'), 'info')
end)

RegisterNetEvent('MULTIhorses:client:tack', function(tack)
    if data then data.tack = tack end
    applyTack(tack)
end)

RegisterNetEvent('MULTIhorses:client:renamed', function(name)
    if not exists() or type(name) ~= 'string' then return end
    if data then data.name = name end
    Citizen.InvokeNative(SET_PED_PROMPT_NAME, horse, name)
    if blip then Citizen.InvokeNative(SET_BLIP_NAME, blip, name) end
end)

-- logout / character switch / resource stop
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() despawn(true) end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeInteraction()
    if blip then RemoveBlip(blip) end
    if horse ~= 0 and DoesEntityExist(horse) then DeleteEntity(horse) end
end)

-- ---------------------------------------------------------------
-- for client/compat.lua and other scripts
-- ---------------------------------------------------------------
MHClient.GetHorse = function() return exists() and horse or 0 end
MHClient.GetData = function() return data end
MHClient.IsDead = function() return dead end
MHClient.Spawn = spawn
MHClient.SendAway = sendAway
MHClient.Whistle = whistle

exports('GetHorse', MHClient.GetHorse)
exports('GetHorseData', function() return data end)
exports('CallHorse', function() CreateThread(whistle) end)
exports('SendAway', function() sendAway() end)
