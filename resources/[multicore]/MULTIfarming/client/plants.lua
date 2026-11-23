-- ============================================================
-- MULTIfarming :: crops in the world (client)
-- Puts a crop's prop into the world as a local (not networked) object while the player is
-- within Config.Props.LoadRange and takes it out beyond UnloadRange. Each prop gets the
-- MULTItarget options Check / Water / Harvest / Dig up (Config.Interaction 'auto' or
-- 'target'); without MULTItarget a hold prompt next to the crop opens the same choices in a
-- menu. The server checks everything again.
-- ============================================================

local P = Config.Props
local spawned = {}      -- [id] = { obj, model }
local mode = nil        -- 'target' or 'prompt' once MCI.Run has decided
local near = {}         -- crops within a few metres, refreshed every second (prompt mode)

local function headingTo(plant)
    local pos = GetEntityCoords(FM.Ped())
    return GetHeadingFromVector_2d(plant.x - pos.x, plant.y - pos.y)
end

local function isRipe(plant)
    local c = Config.Crops[plant.crop]
    return c ~= nil and not plant.dead and plant.stage >= #c.stages
end

---------------------------------
-- actions
---------------------------------
function FM.Check(id)
    lib.callback.await('MULTIfarming:status', false, id)
end

function FM.Water(id)
    local plant = FM.Plants[id]
    if not plant then return end
    FM.RunJob('water', id, { label = _L('work_water'), scenario = Config.Watering.Scenario, heading = headingTo(plant) })
end

function FM.Harvest(id)
    local plant = FM.Plants[id]
    if not plant then return end
    FM.RunJob('harvest', id, { label = _L('work_harvest'), scenario = Config.Harvest.Scenario, heading = headingTo(plant) })
end

function FM.Remove(id)
    local plant = FM.Plants[id]
    if not plant then return end
    local answer = lib.alertDialog({ header = _L('remove_header'), content = _L('remove_confirm'), centered = true, cancel = true })
    if answer ~= 'confirm' then return end
    FM.RunJob('remove', id, { label = _L('work_remove'), scenario = Config.Harvest.RemoveScenario, heading = headingTo(plant) })
end

local function canHarvest(plant)
    return isRipe(plant) and (not Config.Harvest.OwnerOnly or FM.IsMine(plant))
end

---------------------------------
-- MULTItarget options on a crop
---------------------------------
local function options(id)
    local function plant() return FM.Plants[id] end
    local function free() return not FM.busy end
    local function go(fn) return function() CreateThread(function() fn(id) end) end end
    return {
        {
            name = 'multifarming_check', label = _L('target_check'), icon = 'fas fa-seedling', distance = Config.TargetDistance,
            canInteract = function() return plant() ~= nil and free() end,
            onSelect = go(FM.Check),
        },
        {
            name = 'multifarming_water', label = _L('target_water'), icon = 'fas fa-droplet', distance = Config.TargetDistance,
            canInteract = function() local p = plant() return p ~= nil and free() and not p.dead and not isRipe(p) end,
            onSelect = go(FM.Water),
        },
        {
            name = 'multifarming_harvest', label = _L('target_harvest'), icon = 'fas fa-wheat-awn', distance = Config.TargetDistance,
            canInteract = function() local p = plant() return p ~= nil and free() and canHarvest(p) end,
            onSelect = go(FM.Harvest),
        },
        {
            name = 'multifarming_remove', label = _L('target_remove'), icon = 'fas fa-trowel', distance = Config.TargetDistance,
            canInteract = function() local p = plant() return p ~= nil and free() and FM.IsMine(p) end,
            onSelect = go(FM.Remove),
        },
    }
end

---------------------------------
-- spawning
---------------------------------
local function despawn(id)
    local s = spawned[id]
    if not s then return end
    if mode == 'target' then MCI.RemoveEntity(s.obj) end
    if DoesEntityExist(s.obj) then DeleteObject(s.obj) end
    spawned[id] = nil
end

local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local deadline = GetGameTimer() + P.ModelTimeoutMs
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

local warned = {}

local function spawn(plant, model)
    local hash = joaat(model)
    if not loadModel(hash) then
        if not warned[model] then
            warned[model] = true
            print(('^3[MULTIfarming] model %s did not load^7'):format(model))
        end
        return
    end
    if FM.Plants[plant.id] ~= plant then return end   -- removed or changed while loading
    local obj = CreateObject(hash, plant.x, plant.y, plant.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return end
    SetEntityHeading(obj, plant.h)
    PlaceObjectOnGroundProperly(obj, false)
    FreezeEntityPosition(obj, true)
    spawned[plant.id] = { obj = obj, model = model }
    if mode == 'target' then MCI.AddEntity(obj, options(plant.id)) end
end

-- a crop changed (stage, withered) or was added: drop the old prop, the loop puts the new one in
FM.OnPlant = function(id)
    local s, plant = spawned[id], FM.Plants[id]
    if s and plant and s.model ~= FM.PropOf(plant.crop, plant.stage, plant.dead) then despawn(id) end
end

FM.OnRemove = function(id) despawn(id) end

-- streaming: crops in range go in, far ones come out
CreateThread(function()
    while true do
        Wait(1000)
        local pos = GetEntityCoords(FM.Ped())
        local close, list = {}, {}
        -- a copy: spawning waits for models, and the server may add crops meanwhile
        for _, plant in pairs(FM.Plants) do list[#list + 1] = plant end
        for _, plant in ipairs(list) do
            local id = plant.id
            local d = #(pos - plant.coords)
            if d <= P.LoadRange then
                local model = FM.PropOf(plant.crop, plant.stage, plant.dead)
                local s = spawned[id]
                if s and (s.model ~= model or not DoesEntityExist(s.obj)) then despawn(id) s = nil end
                if not s and model then spawn(plant, model) end
                if d <= 6.0 then close[#close + 1] = plant end
            elseif d >= P.UnloadRange and spawned[id] then
                despawn(id)
            end
        end
        for id in pairs(spawned) do
            if not FM.Plants[id] then despawn(id) end
        end
        near = close
    end
end)

---------------------------------
-- interaction mode: MULTItarget on the props, or a hold prompt and a menu
---------------------------------
MCI.Run(Config.Interaction, function(m)
    mode = m
    if m == 'target' then
        for id, s in pairs(spawned) do MCI.AddEntity(s.obj, options(id)) end
    else
        MCI.Count('prompts', 1)
    end
end, function(m)
    if m == 'target' then
        for _, s in pairs(spawned) do MCI.RemoveEntity(s.obj) end
    else
        FM.HidePrompt('tend')
        MCI.Count('prompts', -1)
    end
    mode = nil
end)
MCI.Counter('crops', function() local n = 0 for _ in pairs(spawned) do n = n + 1 end return n end)

local function openMenu(plant)
    local id = plant.id
    local opts = { { title = _L('target_check'), icon = 'fas fa-seedling', onSelect = function() FM.Check(id) end } }
    if not plant.dead and not isRipe(plant) then
        opts[#opts + 1] = { title = _L('target_water'), icon = 'fas fa-droplet', onSelect = function() FM.Water(id) end }
    end
    if canHarvest(plant) then
        opts[#opts + 1] = { title = _L('target_harvest'), icon = 'fas fa-wheat-awn', onSelect = function() FM.Harvest(id) end }
    end
    if FM.IsMine(plant) then
        opts[#opts + 1] = { title = _L('target_remove'), icon = 'fas fa-trowel', onSelect = function() FM.Remove(id) end }
    end
    lib.registerContext({ id = 'multifarming_crop', title = _L('menu_title'), options = opts })
    lib.showContext('multifarming_crop')
end

CreateThread(function()
    while true do
        local sleep = 500
        if mode == 'prompt' and #near > 0 and FM.FreeHands() then
            local pos = GetEntityCoords(FM.Ped())
            local best, bestD
            for _, plant in ipairs(near) do
                if FM.Plants[plant.id] then
                    local d = #(pos - plant.coords)
                    if d <= Config.TargetDistance and (not bestD or d < bestD) then best, bestD = plant, d end
                end
            end
            if best then
                sleep = 0
                if FM.ShowPrompt('tend', _L('prompt_tend')) then openMenu(best) end
            else
                FM.HidePrompt('tend')
            end
        else
            FM.HidePrompt('tend')
        end
        Wait(sleep)
    end
end)

--- The nearest crop within `range` metres, or nil (using the can, client/use.lua).
function FM.NearestPlant(range)
    local pos = GetEntityCoords(FM.Ped())
    local best, bestD
    for _, plant in pairs(FM.Plants) do
        local d = #(pos - plant.coords)
        if d <= range and (not bestD or d < bestD) then best, bestD = plant, d end
    end
    return best
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do despawn(id) end
end)
