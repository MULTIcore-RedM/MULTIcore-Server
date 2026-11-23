-- ============================================================
-- MULTIfarming :: client core
-- The crop list from the server, the hold prompt helper and the job runner: ask the server
-- to begin, play the work scenario with a progress bar, then ask the server to finish (it
-- decides everything). Crops in the world: client/plants.lua. Using items: client/use.lua.
-- ============================================================

local Core = exports.MULTIcore:GetCoreObject()

local TASK_START_SCENARIO_IN_PLACE_HASH = 0x524B54361229154F -- femga natives.json

FM.busy = false
FM.Plants = {}          -- [id] = { id, crop, x, y, z, h, stage, dead, owner }
FM.OnPlant = nil        -- set by client/plants.lua: fn(id) after a crop was added or changed
FM.OnRemove = nil       -- set by client/plants.lua: fn(id) before a crop is taken away

function FM.Notify(text, kind)
    exports.MULTIcore:Notify({ text = text, type = kind or 'info', duration = Config.NotifyDuration })
end

function FM.Ped() return PlayerPedId() end

--- The character id of this player (to know which crops are ours).
function FM.MyCitizenId()
    local ok, data = pcall(function() return Core.Functions.GetPlayerData() end)
    return ok and type(data) == 'table' and data.citizenid or nil
end

function FM.IsMine(plant)
    local cid = FM.MyCitizenId()
    return cid ~= nil and plant ~= nil and plant.owner == cid
end

--- Can the player start work right now (logged in, on foot, alive, not busy)?
function FM.FreeHands()
    local ped = FM.Ped()
    if FM.busy or not LocalPlayer.state.isLoggedIn or IsEntityDead(ped) then return false end
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return false end
    return true
end

---------------------------------
-- hold prompt helper (the game's own hold prompt)
---------------------------------
local prompts = {}   -- [name] = prompt handle

local function promptKey()
    local binds = Core.Shared and Core.Shared.Keybinds or {}
    return binds[Config.PromptKey] or binds['J']
end

--- Shows the prompt `name` this frame. → true when the player completed the hold
function FM.ShowPrompt(name, text)
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
        FM.HidePrompt(name)
        return true
    end
    return false
end

function FM.HidePrompt(name)
    if prompts[name] then
        UiPromptDelete(prompts[name])
        prompts[name] = nil
    end
end

---------------------------------
-- job runner
---------------------------------
--- Runs one job. work = { label, scenario }; data() is called at the end for what the
--- finish needs (the planting spot). → true when the server finished it
function FM.RunJob(action, target, work, data)
    if not FM.FreeHands() then return false end
    FM.busy = true
    local ok, dur = lib.callback.await('MULTIfarming:begin', false, action, target)
    if not ok then FM.busy = false return false end

    local ped = FM.Ped()
    if work.heading then SetEntityHeading(ped, work.heading) end
    if work.scenario then
        Citizen.InvokeNative(TASK_START_SCENARIO_IN_PLACE_HASH, ped, joaat(work.scenario), -1, true, 0, GetEntityHeading(ped), false)
    end

    local done = lib.progressBar({
        duration = dur,
        label = work.label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    ClearPedTasks(ped)
    local finished = false
    if done then
        finished = lib.callback.await('MULTIfarming:finish', false, data and data() or nil) == true
    else
        TriggerServerEvent('MULTIfarming:cancel')
    end
    FM.busy = false
    return finished
end

---------------------------------
-- crops from the server
---------------------------------
local function valid(v)
    return type(v) == 'table' and v.id and type(v.crop) == 'string' and tonumber(v.x) and tonumber(v.y) and tonumber(v.z)
end

local function put(v)
    if not valid(v) then return end
    FM.Plants[v.id] = { id = v.id, crop = v.crop, x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0, h = (tonumber(v.h) or 0) + 0.0,
                        stage = tonumber(v.stage) or 1, dead = v.dead == true, owner = v.owner }
    FM.Plants[v.id].coords = vector3(FM.Plants[v.id].x, FM.Plants[v.id].y, FM.Plants[v.id].z)
    if FM.OnPlant then FM.OnPlant(v.id) end
end

local function take(id)
    if not FM.Plants[id] then return end
    if FM.OnRemove then FM.OnRemove(id) end
    FM.Plants[id] = nil
end

RegisterNetEvent('MULTIfarming:client:plants', function(list, first)
    if first then
        for id in pairs(FM.Plants) do take(id) end
    end
    for _, v in ipairs(type(list) == 'table' and list or {}) do put(v) end
end)

RegisterNetEvent('MULTIfarming:client:plant', function(v) put(v) end)

RegisterNetEvent('MULTIfarming:client:remove', function(ids)
    for _, id in ipairs(type(ids) == 'table' and ids or {}) do take(id) end
end)

-- ask for every crop once logged in, and again after each new login
CreateThread(function()
    local was = false
    while true do
        local now = LocalPlayer.state.isLoggedIn == true
        if now and not was then
            Wait(1500)
            TriggerServerEvent('MULTIfarming:server:sync')
        elseif was and not now then
            for id in pairs(FM.Plants) do take(id) end
        end
        was = now
        Wait(1000)
    end
end)

-- chat suggestion for the admin command
CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/farmclear', _L('cmd_farmclear'))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for name in pairs(prompts) do FM.HidePrompt(name) end
    if FM.busy then ClearPedTasks(FM.Ped()) end
end)
