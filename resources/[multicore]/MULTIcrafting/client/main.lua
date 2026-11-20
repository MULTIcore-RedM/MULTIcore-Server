-- ============================================================
-- MULTIcrafting :: client (stations)
-- Prompts or MULTItarget at fixed stations, at world campfires / anvils and at
-- placed campfires; the props of placed campfires; /craft; putting a campfire
-- down. The client never changes items: the server checks everything.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

CC = {
    fires = {},         -- [id] = { id, coords, heading, obj, target }
}

-- natives (femga natives.json)
local SET_BLIP_NAME = 0x9CB1A1623062F402        -- _SET_BLIP_NAME
local TASK_START_SCENARIO_IN_PLACE_HASH = 0x524B54361229154F

local zones, prompts, blips = {}, {}, {}
local targetModels = {}     -- [type] = { hashes } given to MULTItarget
local propPrompt = nil      -- { name, key } of the moving prompt at the nearest campfire / anvil

local function keyOf(name) -- cancel key and other non-interaction keys
    local keys = RSGCore.Shared and RSGCore.Shared.Keybinds or {}
    return keys[name]
end

function CC.Notify(text, kind)
    exports.MULTIcore:Notify({ text = text, title = _L('title'), type = kind or 'info' })
end

--- True when the stations use MULTItarget right now (Config.Interact, see @MULTIcore/lib/interact.lua).
function CC.UseTarget()
    return MCI.HasTarget() and Config.Interact ~= 'prompt'
end

function CC.Ped() return PlayerPedId() end

function CC.PlayScenario(ped, name)
    if not name or name == false then return false end
    Citizen.InvokeNative(TASK_START_SCENARIO_IN_PLACE_HASH, ped, joaat(name), -1, true, 0, -1.0, false)
    return true
end

function CC.CanAct()
    if IsPauseMenuActive() then return false end
    local ped = CC.Ped()
    if Config.Craft.BlockWhenDead and (IsEntityDead(ped) or IsPedDeadOrDying(ped, true)) then return false end
    if LocalPlayer.state.isLoggedIn == false then return false end
    return true
end

local function typeEnabled(t)
    local d = Config.StationTypes[t]
    return d and d.enabled ~= false
end

local function typeLabel(t)
    local d = Config.StationTypes[t]
    return d and _L(d.label or ('station_' .. t)) or t
end

-- ------------------------------------------------------------
-- world props (campfires, anvils): model hashes per station type
-- ------------------------------------------------------------
local propHashes = {}   -- list of { type, hash }
for t, d in pairs(Config.StationTypes) do
    if d.enabled ~= false and type(d.worldProps) == 'table' then
        for _, m in ipairs(d.worldProps) do propHashes[#propHashes + 1] = { type = t, hash = joaat(m) } end
    end
end

--- The nearest placed campfire within `radius`. → fire, distance
local function nearestFire(pos, radius)
    local best, bestD
    for _, f in pairs(CC.fires) do
        local d = #(pos - f.coords)
        if d <= radius and (not bestD or d < bestD) then best, bestD = f, d end
    end
    return best, bestD
end

--- The nearest world prop that is a station. → type, coords, distance
local function nearestProp(pos, radius)
    if not Config.AllowWorldProps then return nil end
    local bestT, bestC, bestD
    for _, p in ipairs(propHashes) do
        local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, radius, p.hash, false, false, false)
        if obj and obj ~= 0 and DoesEntityExist(obj) then
            local c = GetEntityCoords(obj)
            local d = #(pos - c)
            if not bestD or d < bestD then bestT, bestC, bestD = p.type, c, d end
        end
    end
    return bestT, bestC, bestD
end

--- The station the player stands at (fixed, placed fire, world prop), or hand crafting. → ref, coords
function CC.NearestStation()
    local pos = GetEntityCoords(CC.Ped())
    local bestRef, bestC, bestD
    for _, s in ipairs(Config.Stations or {}) do
        if s.enabled ~= false and typeEnabled(s.type) and s.coords then
            local d = #(pos - s.coords)
            local max = s.radius or Config.StationTypes[s.type].distance or 3.0
            if d <= max and (not bestD or d < bestD) then bestRef, bestC, bestD = { id = s.id }, s.coords, d end
        end
    end
    if typeEnabled('campfire') then
        local f, d = nearestFire(pos, Config.StationTypes.campfire.distance or 3.0)
        if f and (not bestD or d < bestD) then bestRef, bestC, bestD = { type = 'campfire', fire = f.id }, f.coords, d end
    end
    local t, c, d = nearestProp(pos, Config.ScanRadius)
    if t and (not bestD or d < bestD) then
        bestRef, bestC = { type = t, coords = { x = c.x, y = c.y, z = c.z } }, c
    end
    if bestRef then return bestRef, bestC end
    if typeEnabled('hand') then return { type = 'hand' }, nil end
    return nil
end

-- ------------------------------------------------------------
-- fixed stations: prompts or targets, blips
-- ------------------------------------------------------------
AddEventHandler('MULTIcrafting:client:openStation', function(id)
    for _, s in ipairs(Config.Stations or {}) do
        if s.id == id then return CC.OpenAt({ id = id }, s.coords) end
    end
end)

local interactMode = nil    -- 'target' or 'prompt' once MCI.Run has decided

local function stationOk(s)
    return s.enabled ~= false and typeEnabled(s.type) and s.coords
end

-- blips (do not depend on the interaction mode)
CreateThread(function()
    for _, s in ipairs(Config.Stations or {}) do
        if stationOk(s) and Config.Blips.Enabled and s.blip then
            local blip = BlipAddForCoords(Config.Blips.Style, s.coords.x, s.coords.y, s.coords.z)
            SetBlipSprite(blip, joaat(s.blipSprite or Config.Blips.Sprite), true)
            SetBlipScale(blip, Config.Blips.Scale)
            Citizen.InvokeNative(SET_BLIP_NAME, blip, s.label or typeLabel(s.type))
            blips[#blips + 1] = blip
        end
    end
end)

-- model hashes per station type for MULTItarget (world props, plus the placed campfire model)
local function modelsByType()
    local byType = {}
    for _, p in ipairs(propHashes) do
        byType[p.type] = byType[p.type] or {}
        table.insert(byType[p.type], p.hash)
    end
    if typeEnabled('campfire') then
        local h = joaat(Config.Campfire.Model)
        byType.campfire = byType.campfire or {}
        local have = false
        for _, x in ipairs(byType.campfire) do if x == h then have = true end end
        if not have then table.insert(byType.campfire, h) end
    end
    return byType
end

-- ------------------------------------------------------------
-- fixed stations, world campfires / anvils and placed fires
-- target mode: MULTItarget spheres on stations and MULTItarget on the prop models;
-- prompt mode: a prompt per station and one prompt that follows the nearest prop
-- (Config.Interact 'auto' / 'target' / 'prompt', see @MULTIcore/lib/interact.lua)
-- ------------------------------------------------------------
local propRef, propCoords = nil, nil
AddEventHandler('MULTIcrafting:client:openProp', function()
    if propRef then CC.OpenAt(propRef, propCoords) end
end)

local function clearPropPrompt()
    if propPrompt then
        MCI.RemovePrompt(propPrompt)
        propPrompt = nil
    end
    propRef, propCoords = nil, nil
end

MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    for _, s in ipairs(Config.Stations or {}) do
        if stationOk(s) then
            local label = _L('prompt_open', s.label or typeLabel(s.type))
            local name = 'multicrafting_' .. s.id
            if mode == 'target' then
                zones[#zones + 1] = MCI.AddZone({
                    coords = s.coords,
                    radius = Config.TargetRadius,
                    options = { {
                        name = name,
                        label = label,
                        icon = Config.TargetIcon,
                        distance = Config.TargetDistance,
                        onSelect = function() CC.OpenAt({ id = s.id }, s.coords) end,
                    } },
                })
            else
                MCI.AddPrompt(name, s.coords, Config.PromptKey, label,
                    { type = 'client', event = 'MULTIcrafting:client:openStation', args = { s.id } }, Config.PromptDistance)
                prompts[#prompts + 1] = name
            end
        end
    end
    if mode == 'target' then
        targetModels = modelsByType()
        for t, hashes in pairs(targetModels) do
            local ok = pcall(function()
                exports.MULTItarget:addModel(hashes, { {
                    name = 'multicrafting_prop_' .. t,
                    label = _L('prompt_open', typeLabel(t)),
                    icon = Config.TargetIcon,
                    distance = Config.TargetDistance,
                    onSelect = function(data)
                        local ent = type(data) == 'table' and data.entity
                        local c = ent and DoesEntityExist(ent) and GetEntityCoords(ent) or GetEntityCoords(CC.Ped())
                        CC.OpenAt({ type = t, coords = { x = c.x, y = c.y, z = c.z } }, c)
                    end,
                } })
            end)
            if ok then MCI.Count('targets', 1) end
        end
    end
end, function(mode)
    interactMode = nil
    for _, id in ipairs(zones) do MCI.RemoveZone(id) end
    zones = {}
    for _, name in ipairs(prompts) do MCI.RemovePrompt(name) end
    prompts = {}
    clearPropPrompt()
    if mode == 'target' then
        for t, hashes in pairs(targetModels) do
            if MCI.HasTarget() then pcall(function() exports.MULTItarget:removeModel(hashes, 'multicrafting_prop_' .. t) end) end
            MCI.Count('targets', -1)
        end
        targetModels = {}
    end
end)

-- prompt mode: one prompt that follows the nearest campfire / anvil
CreateThread(function()
    local seq = 0
    while true do
        Wait(Config.ScanIntervalMs)
        if interactMode ~= 'prompt' then
            if propPrompt then clearPropPrompt() end
        else
            local pos = GetEntityCoords(CC.Ped())
            local ref, coords, label
            local f = typeEnabled('campfire') and nearestFire(pos, Config.ScanRadius) or nil
            if f then
                ref, coords, label = { type = 'campfire', fire = f.id }, f.coords, typeLabel('campfire')
            else
                local t, c = nearestProp(pos, Config.ScanRadius)
                if t then ref, coords, label = { type = t, coords = { x = c.x, y = c.y, z = c.z } }, c, typeLabel(t) end
            end
            if not ref then
                clearPropPrompt()
            elseif not propCoords or #(propCoords - coords) > 0.5 then
                clearPropPrompt()
                seq = seq + 1
                propPrompt = 'multicrafting_prop_' .. seq
                propRef, propCoords = ref, coords
                MCI.AddPrompt(propPrompt, coords, Config.PromptKey, _L('prompt_open', label),
                    { type = 'client', event = 'MULTIcrafting:client:openProp', args = {} }, Config.PromptDistance)
            end
        end
    end
end)

-- placed campfire props (each client draws them locally)
local function despawnFire(f)
    if f.obj and DoesEntityExist(f.obj) then DeleteObject(f.obj) end
    f.obj = nil
end

local function spawnFire(f)
    local model = joaat(Config.Campfire.Model)
    if not IsModelValid(model) then return end
    RequestModel(model, false)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(20) end
    if not HasModelLoaded(model) or not CC.fires[f.id] then return end
    local obj = CreateObject(model, f.coords.x, f.coords.y, f.coords.z, false, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then return end
    SetEntityHeading(obj, f.heading or 0.0)
    PlaceObjectOnGroundProperly(obj, false)
    FreezeEntityPosition(obj, true)
    f.obj = obj
end

RegisterNetEvent('MULTIcrafting:client:fires', function(list)
    local seen = {}
    for _, v in ipairs(type(list) == 'table' and list or {}) do
        local id = tonumber(v.id)
        if id then
            seen[id] = true
            if not CC.fires[id] then
                CC.fires[id] = { id = id, coords = vector3(v.x + 0.0, v.y + 0.0, v.z + 0.0), heading = tonumber(v.h) or 0.0 }
            end
        end
    end
    for id, f in pairs(CC.fires) do
        if not seen[id] then despawnFire(f) CC.fires[id] = nil end
    end
end)

CreateThread(function()
    Wait(2000)
    local list = lib.callback.await('MULTIcrafting:fires', false)
    TriggerEvent('MULTIcrafting:client:fires', list)
    while true do
        Wait(1500)
        local pos = GetEntityCoords(CC.Ped())
        for _, f in pairs(CC.fires) do
            local near = #(pos - f.coords) < Config.Campfire.StreamDistance
            if near and not f.obj then spawnFire(f)
            elseif not near and f.obj then despawnFire(f) end
        end
    end
end)

-- ------------------------------------------------------------
-- putting a campfire down (the server asks after the item was used)
-- ------------------------------------------------------------
RegisterNetEvent('MULTIcrafting:client:placeFire', function()
    if not CC.CanAct() or CC.IsBusy() then return TriggerServerEvent('MULTIcrafting:server:placeCancel') end
    local ped = CC.Ped()
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) or IsEntityInWater(ped) then
        CC.Notify(_L('err_place_here'), 'error')
        return TriggerServerEvent('MULTIcrafting:server:placeCancel')
    end
    local start = GetEntityCoords(ped)
    local pos = start + GetEntityForwardVector(ped) * Config.Campfire.PlaceAhead
    local found, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.5, false)
    local z = (found and gz) or (pos.z - 1.0)
    local heading = GetEntityHeading(ped)

    CC.SetBusy(true)
    if Config.Craft.Unarm then SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true) end
    CC.PlayScenario(ped, Config.Campfire.PlaceScenario)
    local cancelKey = keyOf(Config.Craft.CancelKey)
    local stopAt = GetGameTimer() + Config.Campfire.PlaceMs
    local cancelled = false
    while GetGameTimer() < stopAt do
        Wait(0)
        if cancelKey and (IsControlJustPressed(0, cancelKey) or IsDisabledControlJustPressed(0, cancelKey)) then cancelled = true break end
        if IsEntityDead(ped) or #(GetEntityCoords(ped) - start) > Config.Craft.CancelDistance then cancelled = true break end
    end
    ClearPedTasks(ped)
    CC.SetBusy(false)
    if cancelled then return TriggerServerEvent('MULTIcrafting:server:placeCancel') end
    lib.callback.await('MULTIcrafting:placeFire', false, { x = pos.x, y = pos.y, z = z }, heading)
end)

-- ------------------------------------------------------------
-- /craft: the nearest station, or hand crafting
-- ------------------------------------------------------------
if type(Config.Command) == 'string' and Config.Command ~= '' then
    RegisterCommand(Config.Command, function()
        local ref, coords = CC.NearestStation()
        if not ref then return CC.Notify(_L('err_no_station'), 'error') end
        CC.OpenAt(ref, coords)
    end, false)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, f in pairs(CC.fires) do despawnFire(f) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for _, name in ipairs(prompts) do MCI.RemovePrompt(name) end
    if propPrompt then MCI.RemovePrompt(propPrompt) end
    -- MULTItarget drops this script's zones and model options by itself when it stops
end)
