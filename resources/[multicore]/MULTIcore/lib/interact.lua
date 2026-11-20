-- ============================================================
-- MULTIcore :: world interaction helper (client)
-- Every MULTI script that puts something to use in the world loads it:
--
--   client_scripts { '@MULTIcore/lib/interact.lua', 'client/main.lua' }
--
-- Owner rule: world interactions use MULTItarget. A script's setting
-- ('auto', 'target' or 'prompt') is turned into the mode used:
--   'auto'   MULTItarget when it runs (waits for it at start, it may start
--            later than the script), else MULTIcore's hold-key prompts
--   'target' the same, with a warning in F8 when MULTItarget is not running
--   'prompt' always hold-key prompts
-- MCI.Run(setting, build, teardown) builds the script's points once the
-- mode is known and builds them again when MULTItarget starts or stops
-- later. Everything made through MCI is counted, and the script answers
-- exports.<script>:GetInteractStats() for MULTIcore's /mcinteract.
-- GPL v3, part of MULTIcore.
-- ============================================================
if IsDuplicityVersion() then return end

MCI = MCI or {}

local WAIT_MS = 10000           -- longest wait at start for MULTItarget to come up (ms)
local POLL_MS = 250             -- how often the state is looked at while waiting (ms)

local counts = { targets = 0, prompts = 0, npcs = 0 }
local counters = {}             -- [kind] = { fn, ... } extra live counts (spawned NPCs, ...)
local runs = {}                 -- every MCI.Run of this script
local promptNames = {}          -- [name] = true, prompts made through MCI.AddPrompt
local zoneIds = {}              -- [id] = true, zones made through MCI.AddZone
local entityTargets = {}        -- [entity] = { option names }, entities given options through MCI.AddEntity

local function oxState() return GetResourceState('MULTItarget') end

--- True when MULTItarget answers calls right now.
function MCI.HasTarget() return oxState() == 'started' end

--- Turns a setting into 'target' or 'prompt'. Blocks (call from a thread)
--- for up to WAIT_MS while MULTItarget is still on its way up.
function MCI.Mode(setting)
    if setting == 'prompt' then return 'prompt' end
    local deadline = GetGameTimer() + WAIT_MS
    while not MCI.HasTarget() and GetGameTimer() < deadline do Wait(POLL_MS) end
    if MCI.HasTarget() then return 'target' end
    if setting == 'target' then
        print(('^3[%s] Config.Interact is \'target\' but MULTItarget is not running: hold-key prompts are used^7'):format(GetCurrentResourceName()))
    end
    return 'prompt'
end

local function safeTeardown(run)
    if run.teardown and run.mode then
        local ok, err = pcall(run.teardown, run.mode)
        if not ok then print(('^1[%s] interaction teardown: %s^7'):format(GetCurrentResourceName(), tostring(err))) end
    end
end

local function safeBuild(run, mode)
    run.mode = mode
    local ok, err = pcall(run.build, mode)
    if not ok then print(('^1[%s] interaction build (%s): %s^7'):format(GetCurrentResourceName(), mode, tostring(err))) end
end

--- Builds a script's interaction points: build(mode) now (once the mode is
--- known), teardown(mode) + build(newMode) when MULTItarget starts or stops later.
--- setting: 'auto' | 'target' | 'prompt' (nil = 'auto'). Returns the run.
function MCI.Run(setting, build, teardown)
    local run = { setting = setting or 'auto', build = build, teardown = teardown, mode = nil }
    runs[#runs + 1] = run
    CreateThread(function()
        safeBuild(run, MCI.Mode(run.setting))
    end)
    return run
end

-- MULTItarget started late or was restarted: its zones are gone, build again in target mode
AddEventHandler('onClientResourceStart', function(res)
    if res ~= 'MULTItarget' then return end
    for _, run in ipairs(runs) do
        if run.setting ~= 'prompt' and run.mode then
            CreateThread(function()
                safeTeardown(run)
                safeBuild(run, 'target')
            end)
        end
    end
end)

-- MULTItarget stopped: fall back to prompts so the points stay usable
AddEventHandler('onClientResourceStop', function(res)
    if res ~= 'MULTItarget' then return end
    for _, run in ipairs(runs) do
        if run.mode == 'target' then
            CreateThread(function()
                safeTeardown(run)
                table.wipe(zoneIds)
                table.wipe(entityTargets)
                counts.targets = 0
                safeBuild(run, 'prompt')
            end)
        end
    end
end)

-- ---------------------------------------------------------------
-- MULTItarget
-- ---------------------------------------------------------------

--- MULTItarget:addSphereZone with a count. data = { coords, radius, options, ... }.
--- Returns the zone id, or nil when MULTItarget refused it.
function MCI.AddZone(data)
    if not MCI.HasTarget() then return nil end
    data.coords = vector3(data.coords.x, data.coords.y, data.coords.z)
    -- no white marker dot on zones (MULTItarget draws one unless told not to)
    if data.drawSprite == nil then data.drawSprite = false end
    -- a zone option is hidden while the player aims at a clerk that offers the same option,
    -- so it is not listed twice
    for _, o in ipairs(data.options or {}) do
        local own, name = o.canInteract, o.name
        o.canInteract = function(entity, ...)
            local names = name and entity and entityTargets[entity]
            if names then
                for _, n in ipairs(names) do if n == name then return false end end
            end
            if own then return own(entity, ...) end
            return true
        end
    end
    local ok, id = pcall(function() return exports.MULTItarget:addSphereZone(data) end)
    if not ok or not id then
        print(('^1[%s] MULTItarget zone failed: %s^7'):format(GetCurrentResourceName(), tostring(id)))
        return nil
    end
    zoneIds[id] = true
    counts.targets = counts.targets + 1
    return id
end

function MCI.RemoveZone(id)
    if id == nil then return end
    if zoneIds[id] then
        zoneIds[id] = nil
        counts.targets = math.max(0, counts.targets - 1)
    end
    if MCI.HasTarget() then pcall(function() exports.MULTItarget:removeZone(id, true) end) end
end



--- MULTItarget:addLocalEntity (a ped or object this client made) with a count.
--- Used on clerks so looking at the clerk works as well as at the counter.
function MCI.AddEntity(entity, options)
    if not MCI.HasTarget() or not entity or not DoesEntityExist(entity) then return false end
    local ok, err = pcall(function() exports.MULTItarget:addLocalEntity(entity, options) end)
    if not ok then
        print(('^1[%s] MULTItarget entity failed: %s^7'):format(GetCurrentResourceName(), tostring(err)))
        return false
    end
    if not entityTargets[entity] then counts.targets = counts.targets + 1 end
    local names = {}
    for _, o in ipairs(options) do names[#names + 1] = o.name end
    entityTargets[entity] = names
    return true
end

function MCI.RemoveEntity(entity)
    local names = entity and entityTargets[entity]
    if not names then return end
    entityTargets[entity] = nil
    counts.targets = math.max(0, counts.targets - 1)
    if MCI.HasTarget() then pcall(function() exports.MULTItarget:removeLocalEntity(entity, names) end) end
end

--- Adds (+n) or removes (-n) from a count by hand, for targets made with
--- other MULTItarget calls (addLocalEntity, addModel, addGlobalPlayer ...).
function MCI.Count(kind, n)
    counts[kind] = math.max(0, (counts[kind] or 0) + (n or 1))
end

--- A live count, read each time the stats are asked for (e.g. spawned NPCs).
function MCI.Counter(kind, fn)
    counters[kind] = counters[kind] or {}
    counters[kind][#counters[kind] + 1] = fn
end

-- ---------------------------------------------------------------
-- hold-key prompts (MULTIcore / rsg-core createPrompt)
-- ---------------------------------------------------------------

--- A key name from MULTIcore's shared/keybinds.lua ('J') or a control hash.
function MCI.Key(key)
    if type(key) == 'number' then return key end
    local ok, core = pcall(function() return exports['rsg-core']:GetCoreObject() end)
    local binds = ok and core and core.Shared and core.Shared.Keybinds or {}
    return binds[key] or binds['J']
end

--- createPrompt with a count. distance = how close the player must be (m);
--- nil = MULTIcore's RSGConfig.PromptDistance.
function MCI.AddPrompt(name, coords, key, label, options, distance)
    options = options or {}
    options.distance = distance
    local ok, err = pcall(function()
        exports['rsg-core']:createPrompt(name, coords, MCI.Key(key), label, options)
    end)
    if not ok then
        print(('^1[%s] prompt %s failed: %s^7'):format(GetCurrentResourceName(), tostring(name), tostring(err)))
        return
    end
    if not promptNames[name] then
        promptNames[name] = true
        counts.prompts = counts.prompts + 1
    end
end

function MCI.RemovePrompt(name)
    if promptNames[name] then
        promptNames[name] = nil
        counts.prompts = math.max(0, counts.prompts - 1)
    end
    pcall(function() exports['rsg-core']:deletePrompt(name) end)
end

-- ---------------------------------------------------------------
-- stats for /mcinteract
-- ---------------------------------------------------------------
function MCI.Stats()
    local out = { targets = counts.targets, prompts = counts.prompts, npcs = counts.npcs }
    for kind, list in pairs(counters) do
        for _, fn in ipairs(list) do
            local ok, n = pcall(fn)
            if ok and tonumber(n) then out[kind] = (out[kind] or 0) + tonumber(n) end
        end
    end
    local mode
    for _, run in ipairs(runs) do
        if run.mode == 'target' then mode = 'target' break end
        mode = run.mode or mode or 'waiting'
    end
    out.mode = mode or 'none'
    out.oxTarget = oxState()
    return out
end

exports('GetInteractStats', MCI.Stats)
