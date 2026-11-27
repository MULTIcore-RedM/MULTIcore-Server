local Prompts = {}
local PromptGroups = {}
local nearDirty = true   -- a prompt was added: rebuild the near list on the next tick

local function toVec3(c)
    return vector3(c.x or c[1], c.y or c[2], c.z or c[3])
end

local function safeDelete(prompt)
    if prompt then UiPromptDelete(prompt) end
end

local function createPrompt(name, coords, key, text, options)
    if (Prompts[name] == nil) then
        Prompts[name] = {}
        Prompts[name].name = name
        Prompts[name].coords = toVec3(coords)
        Prompts[name].key = key
        Prompts[name].text = text
        Prompts[name].options = options
        -- MULTI addition: options.distance (metres) for this prompt; RSG scripts leave it out
        Prompts[name].distance = type(options) == 'table' and tonumber(options.distance) or nil
        Prompts[name].prompt = nil
        nearDirty = true
    else
        print('[rsg-core]  Prompt with name ' .. name .. ' already exists!')
    end
end

local function createPromptGroup(group, label, coords, prompts)
    if (PromptGroups[group] == nil) then
        PromptGroups[group] = {}
        PromptGroups[group].coords = toVec3(coords)
        PromptGroups[group].label = label
        PromptGroups[group].group = group
        PromptGroups[group].created = false
        PromptGroups[group].prompts = prompts
        nearDirty = true
    else
        print('[rsg-core]  Prompt group ' .. tostring(group) .. ' already exists!')
    end
end

local function getPrompt()
    return Prompts
end

local function getPromptGroup()
    return PromptGroups
end


local function deletePrompt(name)
    if Prompts[name] then
        safeDelete(Prompts[name].prompt)
        Prompts[name] = nil
    end
end

local function deletePromptGroup(name)
    if PromptGroups[name] then
        for _, v in pairs(PromptGroups[name].prompts) do
            safeDelete(v.prompt)
        end
        PromptGroups[name] = nil
    end
end


local function executeOptions(options)
    if not options or not options.event then return end
    local args = options.args or {}
    if options.type == 'client' then
        TriggerEvent(options.event, table.unpack(args))
    else
        TriggerServerEvent(options.event, table.unpack(args))
    end
end

local function buildPrompt(key, text, group)
    local prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, key)
    UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', text))
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetHoldMode(prompt, 1000)
    if group then UiPromptSetGroup(prompt, group, 0) end
    UiPromptRegisterEnd(prompt)
    return prompt
end

local function setupPrompt(prompt)
    prompt.prompt = buildPrompt(prompt.key, prompt.text)
end

local function setupPromptGroup(pGroup)
    for _, v in pairs(pGroup.prompts) do
        v.prompt = buildPrompt(v.key, v.text, pGroup.group)
    end
    pGroup.created = true
end

-- briefly hides a prompt after it fires so the hold has to be restarted
local function resetPrompt(prompt)
    UiPromptSetEnabled(prompt, false)
    UiPromptSetVisible(prompt, false)
    Wait(0)
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, v in pairs(Prompts) do
        safeDelete(v.prompt)
    end
    for _, pGroup in pairs(PromptGroups) do
        for _, v in pairs(pGroup.prompts) do
            safeDelete(v.prompt)
        end
    end
    Prompts, PromptGroups = {}, {}
end)

-- single loop handles both prompts and prompt groups.
-- Every NEAR_MS the whole list is walked once and only the prompts / groups within their range
-- (plus NEAR_MARGIN metres) are kept; the per-frame part only looks at that short list. Anything
-- dropped from the near list is out of range, so its game prompt is removed right there.
local NEAR_MS, NEAR_MARGIN = 500, 10.0
local nearPrompts, nearGroups, nearAt = {}, {}, -1000000

local function dropPrompt(v)
    if v.prompt then
        UiPromptDelete(v.prompt)
        v.prompt = nil
    end
end

local function dropGroup(pGroup)
    if pGroup.created then
        for _, v in pairs(pGroup.prompts) do
            safeDelete(v.prompt)
            v.prompt = nil
        end
        pGroup.created = false
    end
end

local function refreshNear(coords, maxDist)
    nearAt, nearDirty = GetGameTimer(), false
    local np, ng = {}, {}
    for _, v in pairs(Prompts) do
        if #(coords - v.coords) < (v.distance or maxDist) + NEAR_MARGIN then np[#np + 1] = v
        else dropPrompt(v) end
    end
    for _, pGroup in pairs(PromptGroups) do
        if #(coords - pGroup.coords) < maxDist + NEAR_MARGIN then ng[#ng + 1] = pGroup
        else dropGroup(pGroup) end
    end
    nearPrompts, nearGroups = np, ng
end

CreateThread(function()
    while true do
        local sleep = 500
        if next(Prompts) or next(PromptGroups) or #nearPrompts > 0 or #nearGroups > 0 then
            local coords = GetEntityCoords(cache.ped)
            local maxDist = RSGConfig.PromptDistance
            if nearDirty or GetGameTimer() - nearAt >= NEAR_MS then refreshNear(coords, maxDist) end
            if #nearPrompts > 0 or #nearGroups > 0 then sleep = 100 end

            for i = 1, #nearPrompts do
                local v = nearPrompts[i]
                if Prompts[v.name] == v then   -- still registered (not deleted since the last refresh)
                    if #(coords - v.coords) < (v.distance or maxDist) then
                        sleep = 0
                        if not v.prompt then setupPrompt(v) end
                        if UiPromptHasHoldModeCompleted(v.prompt) then
                            executeOptions(v.options)
                            resetPrompt(v.prompt)
                            break
                        end
                    else
                        dropPrompt(v)
                    end
                end
            end

            for i = 1, #nearGroups do
                local pGroup = nearGroups[i]
                if PromptGroups[pGroup.group] == pGroup then
                    if #(coords - pGroup.coords) < maxDist then
                        sleep = 0
                        if not pGroup.created then setupPromptGroup(pGroup) end
                        Citizen.InvokeNative(0xC65A45D4453C2627, pGroup.group, CreateVarString(10, 'LITERAL_STRING', pGroup.label), 1) -- UiPromptSetActiveGroupThisFrame
                        for _, v in pairs(pGroup.prompts) do
                            if UiPromptHasHoldModeCompleted(v.prompt) then
                                executeOptions(v.options)
                                resetPrompt(v.prompt)
                                break
                            end
                        end
                    else
                        dropGroup(pGroup)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ------------------------------------------------------------
-- MULTIcore's one frame thread: cheap things that must run every frame (hide the default prompt
-- types here; client/multi/*.lua and pvp.lua add theirs with MULTIFrame.add) share one loop
-- instead of a thread each.
-- ------------------------------------------------------------
MULTIFrame = MULTIFrame or { tasks = {} }
function MULTIFrame.add(fn) MULTIFrame.tasks[#MULTIFrame.tasks + 1] = fn end

-- https://github.com/femga/rdr3_discoveries/tree/master/graphics/HUD/prompts/prompt_types
-- hides the default prompt types every frame (must run each frame)
MULTIFrame.add(function()
    Citizen.InvokeNative(0xFC094EF26DD153FA, 1) -- UiPromptDisablePromptTypeThisFrame
    Citizen.InvokeNative(0xFC094EF26DD153FA, 2)
end)

CreateThread(function()
    local tasks = MULTIFrame.tasks
    while true do
        local t = GetGameTimer()
        for i = 1, #tasks do
            local ok, err = pcall(tasks[i], t)
            if not ok then
                print('[MULTIcore] frame task stopped: ' .. tostring(err))
                tasks[i] = function() end
            end
        end
        Wait(0)
    end
end)

exports('createPrompt', createPrompt)
exports('createPromptGroup', createPromptGroup)
exports('getPrompt', getPrompt)
exports('getPromptGroup',getPromptGroup)
exports('deletePrompt', deletePrompt)
exports('deletePromptGroup',deletePromptGroup)
