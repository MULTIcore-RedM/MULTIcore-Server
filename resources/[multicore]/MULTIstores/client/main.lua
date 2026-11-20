-- ============================================================
-- MULTIstores :: client
-- Prompts or MULTItarget at each counter, blips, clerks and the store
-- screen. The client never changes money or items: it asks the server
-- (lib.callback) and shows the answer.
-- GPL v3, part of MULTIcore.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local isOpen = false
local openName = nil
local openCoords, openDist = nil, nil
local staticSent = false
local blips, clerks, zones, prompts = {}, {}, {}, {}
local interactMode = nil  -- 'target' or 'prompt' once MCI.Run has decided

-- natives (femga natives.json)
local SET_BLIP_NAME = 0x9CB1A1623062F402                -- _SET_BLIP_NAME
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE  -- _SET_RANDOM_OUTFIT_VARIATION
local TASK_START_SCENARIO_IN_PLACE_HASH = 0x524B54361229154F

local function notify(text, kind)
    exports.MULTIcore:Notify({ text = text, title = _L('title'), type = kind or 'info' })
end

local function enabledStores()
    local out = {}
    for _, s in ipairs(Config.Stores or {}) do
        local t = Config.Types[s.type]
        if t and t.enabled ~= false and s.enabled ~= false and s.coords then out[#out + 1] = s end
    end
    return out
end

local function storeLabel(s)
    if type(s.label) == 'string' and s.label ~= '' then return s.label end
    local t = Config.Types[s.type] or {}
    return _L(t.label or 'type_general', _L('town_' .. tostring(s.town)))
end

local function hoursOf(s)
    if s.hours == false then return nil end
    if type(s.hours) == 'table' then return s.hours.open, s.hours.close end
    if Config.Hours.Enabled then return Config.Hours.Open, Config.Hours.Close end
    return nil
end

local function isOpenNow(s)
    local o, c = hoursOf(s)
    if not o then return true end
    local h = GetClockHours()
    if o < c then return h >= o and h < c end
    return h >= o or h < c -- hours that run past midnight
end

-- ---------------------------------------------------------------
-- the store screen
-- ---------------------------------------------------------------
local function imagePaths()
    if type(Config.ImagePaths) == 'table' then return Config.ImagePaths end
    if GetResourceState('MULTIinventory') == 'started' then
        local ok, list = pcall(function() return exports.MULTIinventory:GetImagePaths() end)
        if ok and type(list) == 'table' then return list end
    end
    return {}
end

local function sendStatic()
    if staticSent then return end
    staticSent = true
    SendNUIMessage({
        action = 'setup', locale = _LT(), lang = _LCode(), images = imagePaths(),
        sign = Config.CurrencySign, max = Config.MaxPerPurchase,
    })
end

local function closeStore(tellServer)
    if not isOpen then return end
    isOpen, openName, openCoords = false, nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if tellServer ~= false then TriggerServerEvent('MULTIstores:server:close') end
end

RegisterNetEvent('MULTIstores:client:open', function(state, coords, dist)
    if type(state) ~= 'table' then return end
    sendStatic()
    isOpen, openName = true, state.name
    openCoords = coords and vector3(coords.x, coords.y, coords.z) or nil
    openDist = (tonumber(dist) or Config.MaxUseDistance) + 1.0
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state })
end)

RegisterNetEvent('MULTIstores:client:state', function(state)
    if isOpen and type(state) == 'table' and state.name == openName then
        SendNUIMessage({ action = 'state', state = state })
    end
end)

RegisterNetEvent('MULTIstores:client:stock', function(index, stock)
    if isOpen then SendNUIMessage({ action = 'stock', i = index, stock = stock }) end
end)

RegisterNetEvent('MULTIstores:client:close', function() closeStore(false) end)

local function requestOpen(name)
    if isOpen or IsPauseMenuActive() then return end
    for _, s in ipairs(enabledStores()) do
        if s.name == name then
            if not isOpenNow(s) then
                local o, c = hoursOf(s)
                notify(_L('closed', o, c), 'error')
                return
            end
            break
        end
    end
    lib.callback('MULTIstores:open', false, function() end, name)
end
-- local event the counter prompt fires (MULTIcore createPrompt, type 'client', args = { storeName })
AddEventHandler('MULTIstores:client:request', requestOpen)

RegisterNUICallback('close', function(_, cb)
    closeStore(true)
    cb({})
end)

RegisterNUICallback('buy', function(data, cb)
    if not isOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    cb(lib.callback.await('MULTIstores:buy', false, openName, tonumber(data.i), tonumber(data.amount)) or { ok = false })
end)

RegisterNUICallback('sell', function(data, cb)
    if not isOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    cb(lib.callback.await('MULTIstores:sell', false, openName, tonumber(data.slot), tonumber(data.amount)) or { ok = false })
end)

-- walking away closes the store
CreateThread(function()
    while true do
        Wait(Config.CheckIntervalMs)
        if isOpen and openCoords and #(GetEntityCoords(cache.ped) - openCoords) > openDist then closeStore(true) end
    end
end)

-- ---------------------------------------------------------------
-- prompts / targets and blips
-- ---------------------------------------------------------------
-- the "Open <store>" option for one store (counter zone and clerk use the same one)
local function storeOption(s)
    return {
        name = 'multistores_' .. s.name,
        label = _L('prompt_open', storeLabel(s)),
        icon = Config.TargetIcon,
        distance = Config.TargetDistance,
        onSelect = function() requestOpen(s.name) end,
    }
end

-- MULTItarget (Config.Interact 'auto' / 'target') or hold-key prompts, see @MULTIcore/lib/interact.lua
MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    for _, s in ipairs(enabledStores()) do
        if mode == 'target' then
            zones[#zones + 1] = MCI.AddZone({ coords = s.coords, radius = Config.TargetRadius, options = { storeOption(s) } })
            if clerks[s.name] then MCI.AddEntity(clerks[s.name], { storeOption(s) }) end
        else
            MCI.AddPrompt('multistores_' .. s.name, s.coords, Config.PromptKey, _L('prompt_open', storeLabel(s)),
                { type = 'client', event = 'MULTIstores:client:request', args = { s.name } }, Config.PromptDistance)
            prompts[#prompts + 1] = 'multistores_' .. s.name
        end
    end
end, function()
    for _, id in ipairs(zones) do MCI.RemoveZone(id) end
    zones = {}
    for _, ped in pairs(clerks) do MCI.RemoveEntity(ped) end
    for _, name in ipairs(prompts) do MCI.RemovePrompt(name) end
    prompts = {}
    interactMode = nil
end)

CreateThread(function()
    for _, s in ipairs(enabledStores()) do
        local t = Config.Types[s.type]
        local label = storeLabel(s)
        if Config.Blips.Enabled and s.blip ~= false and t.blip then
            local blip = BlipAddForCoords(Config.Blips.Style, s.coords.x, s.coords.y, s.coords.z)
            SetBlipSprite(blip, joaat(t.blip), true)
            SetBlipScale(blip, Config.Blips.Scale)
            Citizen.InvokeNative(SET_BLIP_NAME, blip, label)
            blips[#blips + 1] = blip
        end
    end
end)

-- ---------------------------------------------------------------
-- clerks
-- ---------------------------------------------------------------
local function spawnClerk(s)
    local t = Config.Types[s.type] or {}
    local model = joaat(s.model or t.model)
    RequestModel(model, false)
    local deadline = GetGameTimer() + Config.Npc.LoadTimeoutMs
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) then return nil end
    local ped = CreatePed(model, s.npc.x, s.npc.y, s.npc.z + Config.Npc.ZOffset, s.npc.w, false, false, false, false)
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    if Config.Npc.Scenarios and t.scenario then
        Citizen.InvokeNative(TASK_START_SCENARIO_IN_PLACE_HASH, ped, joaat(t.scenario), -1, true, 0, -1.0, false)
    end
    return ped
end

CreateThread(function()
    if not Config.Npc.Enabled then return end
    local list = {}
    for _, s in ipairs(enabledStores()) do if s.npc then list[#list + 1] = s end end
    while true do
        Wait(Config.CheckIntervalMs)
        local pos = GetEntityCoords(cache.ped)
        for _, s in ipairs(list) do
            local near = #(pos - s.npc.xyz) < Config.Npc.SpawnDistance
            if near and not clerks[s.name] then
                clerks[s.name] = spawnClerk(s)
                if clerks[s.name] and interactMode == 'target' then MCI.AddEntity(clerks[s.name], { storeOption(s) }) end
            elseif not near and clerks[s.name] then
                MCI.RemoveEntity(clerks[s.name])
                if DoesEntityExist(clerks[s.name]) then DeletePed(clerks[s.name]) end
                clerks[s.name] = nil
            end
        end
    end
end)

-- for /mcinteract
MCI.Counter('npcs', function()
    local n = 0
    for _ in pairs(clerks) do n = n + 1 end
    return n
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for _, ped in pairs(clerks) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
    for _, name in ipairs(prompts) do MCI.RemovePrompt(name) end
    -- MULTItarget drops this script's zones and entity options by itself when it stops
end)

exports('IsOpen', function() return isOpen end)
exports('Close', function() closeStore(true) end)
