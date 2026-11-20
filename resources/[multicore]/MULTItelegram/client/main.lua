-- ============================================================
-- MULTItelegram :: client
-- Prompt or MULTItarget at each post office counter, blips, the
-- optional clerk, and the telegram NUI. The client never changes
-- anything itself: it asks the server (lib.callback) and shows
-- the answer.
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

MTC = {}
local isOpen = false
local openedAtOffice = false
local blips = {}
local clerks = {}
local zones = {}
local interactMode = nil  -- 'target' or 'prompt' once MCI.Run has decided

local function notify(msg, kind)
    exports.MULTIcore:Notify({ text = msg, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end

local function nearestOffice()
    local pos = GetEntityCoords(cache.ped)
    local best, bestDist
    for i, o in ipairs(Config.Offices) do
        local d = #(pos - o.coords)
        if d <= Config.MaxUseDistance and (not bestDist or d < bestDist) then best, bestDist = i, d end
    end
    return best
end
MTC.NearestOffice = nearestOffice

---------------------------------
-- the page
---------------------------------
function MTC.Close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

--- Opens the telegram page on a tab: 'inbox' | 'compose' | 'contacts'. prefill = { to, subject } for compose.
function MTC.Open(mode, prefill)
    if isOpen then return end
    mode = (mode == 'compose' or mode == 'contacts') and mode or 'inbox'
    local ok, state = lib.callback.await('MULTItelegram:open', false, mode)
    if not ok then
        if state then notify(state, 'error') end
        return
    end
    isOpen = true
    openedAtOffice = state.atOffice == true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', mode = mode, prefill = prefill, state = state, L = _LT(), lang = _LCode() })
end

RegisterNetEvent('MULTItelegram:client:open', function(mode)
    MTC.Open(mode)
end)

RegisterNUICallback('close', function(_, cb)
    MTC.Close()
    cb({})
end)

RegisterNUICallback('action', function(data, cb)
    if not isOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    local res = lib.callback.await('MULTItelegram:action', false, data.action, data.data or {})
    if type(res) ~= 'table' then res = { ok = false, msg = _L('err_failed') } end
    cb(res)
    if res.close then
        if res.msg then notify(res.msg, 'error') end
        MTC.Close()
    end
end)

-- walking away from the counter closes a page that was opened there (unless reading works anywhere)
CreateThread(function()
    while true do
        Wait(Config.CheckIntervalMs)
        if isOpen and openedAtOffice and not Config.ReadAnywhere and not nearestOffice() then MTC.Close() end
    end
end)

---------------------------------
-- commands
---------------------------------
if Config.Commands.Inbox ~= '' then
    RegisterCommand(Config.Commands.Inbox, function() MTC.Open('inbox') end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Inbox, _L('cmd_inbox'), {})
end
if Config.Commands.Contacts ~= '' then
    RegisterCommand(Config.Commands.Contacts, function() MTC.Open('contacts') end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.Contacts, _L('cmd_contacts'), {})
end

---------------------------------
-- prompt / target, blips
---------------------------------
-- the "open post office" option for one office (counter zone and clerk use the same one)
local function officeOption(o)
    return {
        name = 'multitelegram_' .. o.id,
        label = _L('prompt_open'),
        icon = Config.TargetIcon,
        distance = Config.TargetDistance,
        onSelect = function() MTC.Open('inbox') end,
    }
end

-- MULTItarget (Config.Interact 'auto' / 'target') or hold-key prompts, see @MULTIcore/lib/interact.lua
MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    for i, o in ipairs(Config.Offices) do
        if mode == 'target' then
            zones[#zones + 1] = MCI.AddZone({ coords = o.coords, radius = Config.TargetRadius, options = { officeOption(o) } })
            if clerks[i] then MCI.AddEntity(clerks[i], { officeOption(o) }) end
        else
            MCI.AddPrompt('multitelegram_' .. o.id, o.coords, Config.PromptKey, _L('prompt_open'),
                { type = 'client', event = 'MULTItelegram:client:open', args = { 'inbox' } }, Config.PromptDistance)
        end
    end
end, function()
    for _, id in ipairs(zones) do MCI.RemoveZone(id) end
    zones = {}
    for _, ped in pairs(clerks) do MCI.RemoveEntity(ped) end
    for _, o in ipairs(Config.Offices) do MCI.RemovePrompt('multitelegram_' .. o.id) end
    interactMode = nil
end)

CreateThread(function()
    for _, o in ipairs(Config.Offices) do
        if Config.Blips.Enabled and o.blip then
            local blip = BlipAddForCoords(Config.Blips.Style, o.coords.x, o.coords.y, o.coords.z)
            SetBlipSprite(blip, joaat(Config.Blips.Sprite), true)
            SetBlipScale(blip, Config.Blips.Scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, _L(o.label)) -- _SET_BLIP_NAME
            blips[#blips + 1] = blip
        end
    end
end)

---------------------------------
-- clerks (only offices with an `npc` spot)
---------------------------------
local function spawnClerk(o)
    local model = joaat(Config.Npc.Model)
    RequestModel(model, false)
    local deadline = GetGameTimer() + Config.Npc.LoadTimeoutMs
    while not HasModelLoaded(model) and GetGameTimer() < deadline do
        Wait(0)
    end
    if not HasModelLoaded(model) then return nil end
    local ped = CreatePed(model, o.npc.x, o.npc.y, o.npc.z + Config.Npc.ZOffset, o.npc.w, false, false, false, false)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    return ped
end

CreateThread(function()
    if not Config.Npc.Enabled then return end
    local any = false
    for _, o in ipairs(Config.Offices) do if o.npc then any = true end end
    if not any then return end
    while true do
        Wait(Config.CheckIntervalMs)
        local pos = GetEntityCoords(cache.ped)
        for i, o in ipairs(Config.Offices) do
            if o.npc then
                local near = #(pos - o.npc.xyz) < Config.Npc.SpawnDistance
                if near and not clerks[i] then
                    clerks[i] = spawnClerk(o)
                    if clerks[i] and interactMode == 'target' then MCI.AddEntity(clerks[i], { officeOption(o) }) end
                elseif not near and clerks[i] then
                    MCI.RemoveEntity(clerks[i])
                    if DoesEntityExist(clerks[i]) then DeletePed(clerks[i]) end
                    clerks[i] = nil
                end
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
    for _, o in ipairs(Config.Offices) do MCI.RemovePrompt('multitelegram_' .. o.id) end
    -- MULTItarget drops this script's zones and entity options by itself when it stops
end)
