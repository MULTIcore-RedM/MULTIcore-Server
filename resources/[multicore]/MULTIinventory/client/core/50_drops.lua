-- ============================================================
-- MULTIinventory :: drops in the world
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
--
-- The engine keeps drops (memory only). Each client draws a local bag prop
-- where a drop lies and offers "open" through MULTItarget, or a key prompt
-- (MULTIcore's rsg-core createPrompt) when MULTItarget is off. The mode is
-- decided by MCI.Run (@MULTIcore/lib/interact.lua): it waits for MULTItarget
-- at start and switches when MULTItarget starts or stops later.
-- Opening a drop is a server request; the server checks the distance.
--
-- Server -> client:
--   MULTIinventory:client:drops ({ [dropId] = { x, y, z } | vector3 })   full list
--   MULTIinventory:client:dropAdded (dropId, coords)
--   MULTIinventory:client:dropRemoved (dropId)
-- Client -> server:
--   cb  MULTIinventory:server:getDrops () -> the full list (asked after login)
--   net MULTIinventory:server:openInventory (dropId)
-- ============================================================

local drops = {}   -- [id] = { coords = vector3, obj = entity|nil, target = bool, prompt = name|nil }

local function toVec(c)
    if type(c) == 'vector3' or type(c) == 'vector4' then return vector3(c.x, c.y, c.z) end
    if type(c) == 'table' then
        local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
        if x and y and z then return vector3(x, y, z) end
    end
    return nil
end

-- Drops.UseTarget: true = MULTItarget when it runs, else prompts; false = always prompts
local dropMode = nil   -- 'target' or 'prompt' once MCI.Run has decided
local function useTarget() return dropMode == 'target' end

local function openDrop(id)
    if not drops[id] or MIC.IsOpen or not MIC.CanUse() then return end
    TriggerServerEvent('MULTIinventory:server:openInventory', id)
end
AddEventHandler('MULTIinventory:client:openDrop', openDrop)

local function despawn(d)
    if d.obj and DoesEntityExist(d.obj) then
        if d.target then MCI.RemoveEntity(d.obj) end
        DeleteObject(d.obj)
    end
    d.obj, d.target = nil, false
end

local function targetDrop(id, d)
    if not useTarget() or not d.obj or d.target then return end
    d.target = MCI.AddEntity(d.obj, { {
        name = 'multiinv_drop_' .. tostring(id),
        icon = MIC.Cfg('Drops.TargetIcon', 'fas fa-box-open'),
        label = _L('drop_open'),
        distance = MIC.Cfg('Drops.OpenDistance', 2.0),
        onSelect = function() openDrop(id) end,
    } })
end

local function spawn(id, d)
    local model = joaat(MIC.Cfg('Drops.Model', 'p_bag01x')) -- objects.lua; rsg-inventory uses the same bag
    if not IsModelValid(model) then return end
    RequestModel(model, false)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(20) end
    if not HasModelLoaded(model) or not drops[id] then return end
    local obj = CreateObject(model, d.coords.x, d.coords.y, d.coords.z, false, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then return end
    PlaceObjectOnGroundProperly(obj, false)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    d.obj = obj
    targetDrop(id, d)
end

local function addPrompt(id, d)
    if dropMode ~= 'prompt' or d.prompt then return end
    local name = 'multiinv_drop_' .. tostring(id)
    MCI.AddPrompt(name, d.coords, MIC.Cfg('Drops.PromptKey', 0xCEFD9220), _L('drop_open'),
        { type = 'client', event = 'MULTIinventory:client:openDrop', args = { id } }, MIC.Cfg('Drops.OpenDistance', 2.0))
    d.prompt = name
end

local function removePrompt(d)
    if d.prompt then MCI.RemovePrompt(d.prompt) d.prompt = nil end
end

-- MULTItarget on the bag props, or a prompt at each drop; built again if MULTItarget starts or stops
if MIC.Cfg('Drops.Enabled', true) then
    MCI.Run(MIC.Cfg('Drops.UseTarget', true) == false and 'prompt' or 'auto', function(mode)
        dropMode = mode
        for id, d in pairs(drops) do
            if mode == 'target' then targetDrop(id, d) else addPrompt(id, d) end
        end
    end, function()
        for _, d in pairs(drops) do
            if d.target and d.obj then MCI.RemoveEntity(d.obj) end
            d.target = false
            removePrompt(d)
        end
        dropMode = nil
    end)
end

local function remove(id)
    local d = drops[id]
    if not d then return end
    despawn(d)
    removePrompt(d)
    drops[id] = nil
end

local function add(id, coords)
    local v = toVec(coords)
    if id == nil or not v then return end
    if drops[id] then remove(id) end
    drops[id] = { coords = v }
    addPrompt(id, drops[id])
end

RegisterNetEvent('MULTIinventory:client:drops', function(list)
    for id in pairs(drops) do remove(id) end
    if type(list) ~= 'table' then return end
    for id, c in pairs(list) do add(id, type(c) == 'table' and c.coords or c) end
end)
RegisterNetEvent('MULTIinventory:client:dropAdded', add)
RegisterNetEvent('MULTIinventory:client:dropRemoved', remove)

--- The drop id within open reach of the player, if any (opening the satchel next to a bag opens both).
function MIC.NearestDrop()
    if not MIC.Cfg('Drops.Enabled', true) then return nil end
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestDist = nil, MIC.Cfg('Drops.OpenDistance', 2.0)
    for id, d in pairs(drops) do
        local dist = #(d.coords - pos)
        if dist <= bestDist then best, bestDist = id, dist end
    end
    return best
end

-- stream the props in and out around the player
CreateThread(function()
    while true do
        local range = MIC.Cfg('Drops.DrawDistance', 40.0)
        local pos = GetEntityCoords(PlayerPedId())
        for id, d in pairs(drops) do
            local near = #(d.coords - pos) <= range
            if near and not d.obj then spawn(id, d)
            elseif not near and d.obj then despawn(d) end
        end
        Wait(1000)
    end
end)

local function fetch()
    CreateThread(function()
        Wait(2000)
        local list = lib.callback.await('MULTIinventory:server:getDrops', false)
        if type(list) == 'table' then TriggerEvent('MULTIinventory:client:drops', list) end
    end)
end
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', fetch)
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() and MIC.LoggedIn() then fetch() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(drops) do remove(id) end
end)
