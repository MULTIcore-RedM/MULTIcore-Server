-- ============================================================
-- MULTIinventory :: client/drops.lua
--
-- World drops (Config.Drop.mode = 'world'). The server owns the piles; this
-- file only draws LOCAL (non-networked) props within Config.Drop.renderDistance
-- and shows a hold-prompt on the nearest pile. Pick-up = server action
-- 'pickup' { dropId } (the server re-checks the distance and the weight).
-- Events in: MULTIinventory:drops:all (list), :drops:set (view), :drops:remove (id)
-- Event out: MULTIinventory:drops:request (after spawn / resource start)
-- ============================================================

local piles = {}       -- [id] = view + { obj }
local prompt, promptGroup = nil, nil
local current = nil

local function deleteObj(p)
    if p.obj and DoesEntityExist(p.obj) then DeleteObject(p.obj) end
    p.obj = nil
end

local function spawnObj(p)
    local model = joaat(p.prop or Config.Drop.prop)
    if not IsModelValid(model) then model = joaat(Config.Drop.prop) end
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return end
    local obj = CreateObject(model, p.x, p.y, p.z - 0.9, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetModelAsNoLongerNeeded(model)
    p.obj = obj
end

RegisterNetEvent('MULTIinventory:drops:all', function(list)
    for _, p in pairs(piles) do deleteObj(p) end
    piles = {}
    for _, v in ipairs(list or {}) do piles[v.id] = v end
end)

RegisterNetEvent('MULTIinventory:drops:set', function(v)
    local old = piles[v.id]
    if old then
        v.obj = old.obj
        if old.prop ~= v.prop then deleteObj(v) end
    end
    piles[v.id] = v
end)

RegisterNetEvent('MULTIinventory:drops:remove', function(id)
    local p = piles[id]
    if p then deleteObj(p) end
    piles[id] = nil
    if current == id then current = nil end
end)

local function ensurePrompt()
    if prompt then return end
    promptGroup = GetRandomIntInRange(0, 0xffffff)
    prompt = PromptRegisterBegin()
    PromptSetControlAction(prompt, 0xCEFD9220) -- E
    PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', L('drop_pickup')))
    PromptSetEnabled(prompt, true)
    PromptSetVisible(prompt, true)
    PromptSetHoldMode(prompt, true)
    PromptSetGroup(prompt, promptGroup)
    PromptRegisterEnd(prompt)
end

local function vdist(a, x, y, z)
    local dx, dy, dz = a.x - x, a.y - y, a.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- streaming: spawn / despawn props by distance
CreateThread(function()
    while true do
        Wait(1000)
        if Config.Drop.mode == 'world' then
            local c = GetEntityCoords(PlayerPedId())
            for _, p in pairs(piles) do
                local d = vdist(p, c.x, c.y, c.z)
                if d <= Config.Drop.renderDistance and not p.obj then spawnObj(p)
                elseif d > Config.Drop.renderDistance + 5.0 and p.obj then deleteObj(p) end
            end
        end
    end
end)

-- nearest pile + prompt
CreateThread(function()
    while true do
        local sleep = 500
        if Config.Drop.mode == 'world' and next(piles) ~= nil and not InvClient.isOpen() then
            local c = GetEntityCoords(PlayerPedId())
            local best, bestD = nil, (Config.Drop.pickupDistance or 2.5) - 0.3
            for id, p in pairs(piles) do
                local d = vdist(p, c.x, c.y, c.z)
                if d < bestD then best, bestD = id, d end
            end
            current = best
            if best then
                sleep = 0
                ensurePrompt()
                local p = piles[best]
                PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', p.label ~= '' and p.label or L('drop_ground')))
                if PromptHasHoldModeCompleted(prompt) then
                    local id = best
                    CreateThread(function() InvClient.request('pickup', { dropId = id }) end)
                    Wait(750)
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('MULTIinventory:drops:request')
end)
AddEventHandler('MULTIinventory:client:synced', function() TriggerServerEvent('MULTIinventory:drops:request') end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, p in pairs(piles) do deleteObj(p) end
    if prompt then PromptDelete(prompt) end
end)
