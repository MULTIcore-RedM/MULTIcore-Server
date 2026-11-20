-- ============================================================
-- MULTIgathering :: client core
-- Which activities are on, the key prompt helper, blips, worked-out spots and the job
-- runner used by mining, lumber and panning: ask the server to start, play the work
-- animation with a progress bar, then ask the server to finish (it decides the reward).
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local TASK_START_SCENARIO_IN_PLACE_HASH = 0x524B54361229154F -- femga natives.json
local SET_BLIP_NAME = 0x9CB1A1623062F402                     -- _SET_BLIP_NAME (as MULTIstores)

MG.busy = false
MG.depleted = {}      -- [spotId] = true while worked out / cut out
local active = {}     -- [activity] = bool (from the server)
local blips = {}

function MG.Notify(text, kind)
    exports.MULTIcore:Notify({ text = text, type = kind or 'info', duration = Config.NotifyDuration })
end

--- Is this activity switched on (and is the player in game)?
function MG.IsOn(activity)
    return LocalPlayer.state.isLoggedIn == true and active[activity] == true
end

function MG.Ped() return PlayerPedId() end

--- Can the player start work right now (on foot, alive, not busy)?
function MG.FreeHands()
    local ped = MG.Ped()
    if MG.busy or IsEntityDead(ped) then return false end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return false end
    return true
end

---------------------------------
-- prompt helper (the game's own hold prompt, built like MULTIcore's prompts)
---------------------------------
local prompts = {}   -- [name] = prompt handle

local function promptKey()
    return RSGCore.Shared.Keybinds[Config.PromptKey] or RSGCore.Shared.Keybinds['J']
end

--- Shows the prompt `name` this frame. → true when the player completed the hold
function MG.ShowPrompt(name, text)
    local p = prompts[name]
    if not p then
        p = UiPromptRegisterBegin()
        UiPromptSetControlAction(p, promptKey())
        UiPromptSetText(p, CreateVarString(10, 'LITERAL_STRING', text))
        UiPromptSetEnabled(p, true)
        UiPromptSetVisible(p, true)
        UiPromptSetHoldMode(p, 1000)
        UiPromptRegisterEnd(p)
        prompts[name] = p
    end
    if UiPromptHasHoldModeCompleted(p) then
        MG.HidePrompt(name)
        return true
    end
    return false
end

function MG.HidePrompt(name)
    if prompts[name] then
        UiPromptDelete(prompts[name])
        prompts[name] = nil
    end
end

---------------------------------
-- job runner
---------------------------------
--- Runs one job. work = { label, scenario?, anim = { dict, clip, flag }?, prop = { model, bone, pos, rot }? } (ox_lib progress bar)
function MG.RunJob(activity, target, work)
    if not MG.FreeHands() then return end
    MG.busy = true
    local ok, dur = lib.callback.await('MULTIgathering:start', false, activity, target)
    if not ok then MG.busy = false return end

    local ped = MG.Ped()
    if work.scenario then
        Citizen.InvokeNative(TASK_START_SCENARIO_IN_PLACE_HASH, ped, joaat(work.scenario), -1, true, 0, GetEntityHeading(ped), false)
    end

    local done = lib.progressBar({
        duration = dur,
        label = work.label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = work.anim,
        prop = work.prop,
    })

    ClearPedTasks(ped)
    if done then
        lib.callback.await('MULTIgathering:finish', false)
    else
        TriggerServerEvent('MULTIgathering:cancel')
    end
    MG.busy = false
end

---------------------------------
-- state from the server
---------------------------------
local function refresh()
    local a = lib.callback.await('MULTIgathering:active', false)
    if type(a) == 'table' then active = a end
    local d = lib.callback.await('MULTIgathering:spots', false)
    MG.depleted = {}
    for _, id in ipairs(type(d) == 'table' and d or {}) do MG.depleted[id] = true end
    if MG.OnRefresh then MG.OnRefresh() end
end

RegisterNetEvent('MULTIgathering:client:spotState', function(id, depleted)
    if type(id) == 'string' then MG.depleted[id] = depleted == true or nil end
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() SetTimeout(1500, refresh) end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    refresh()
    while true do
        Wait(300000) -- stand-down can change when a resource starts or stops
        if LocalPlayer.state.isLoggedIn then refresh() end
    end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then SetTimeout(2000, refresh) end
end)

RegisterNetEvent('MULTIgathering:client:spotLine', function(line)
    print(('[MULTIgathering] %s'):format(tostring(line)))
    MG.Notify(_L('spot_line', tostring(line)), 'info')
end)

---------------------------------
-- blips: one per mine and one per lumber zone
---------------------------------
local function addBlip(coords, sprite, label)
    local blip = BlipAddForCoords(Config.BlipStyle, coords.x, coords.y, coords.z)
    SetBlipSprite(blip, type(sprite) == 'string' and joaat(sprite) or sprite, true)
    SetBlipScale(blip, Config.BlipScale)
    Citizen.InvokeNative(SET_BLIP_NAME, blip, label)
    blips[#blips + 1] = blip
end

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    Wait(2000)
    if Config.Mining.Enabled and Config.Mining.Blips and MG.IsOn('mining') then
        local seen = {}
        for _, s in ipairs(Config.MiningSpots or {}) do
            if not seen[s.mine] then
                seen[s.mine] = true
                addBlip(s.coords, Config.Mining.BlipSprite, _L('mine_' .. s.mine))
            end
        end
    end
    if Config.Lumber.Enabled and Config.Lumber.Blips and MG.IsOn('lumber') then
        for _, z in ipairs(Config.LumberZones or {}) do addBlip(z.coords, Config.Lumber.BlipSprite, _L('zone_' .. z.zone)) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    for name in pairs(prompts) do MG.HidePrompt(name) end
    if MG.busy then ClearPedTasks(MG.Ped()) end
end)
