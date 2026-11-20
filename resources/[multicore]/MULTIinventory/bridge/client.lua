-- ============================================================
-- RINGO framework bridge :: client
--
-- VORP mode : notifications / progress bar / core object are the
--             original vorp_* calls, untouched.
-- RSG mode  : the same helpers on ox_lib (rsg-core's UI layer).
--
-- Plain Lua 5.3 syntax on purpose (some resources lack lua54).
-- ============================================================

local RES = MBridge.Resource

-- ------------------------------------------------------------
-- Session: block (inside a thread) until the character is in the world.
--
-- VORP raises  LocalPlayer.state.IsInSession ; rsg-core raises
-- LocalPlayer.state.isLoggedIn . A script that waits on only one of them never
-- gets past its start-up on the other framework (nothing spawns, no prompts).
-- ------------------------------------------------------------
function MBridge.InSession()
    local st = LocalPlayer.state
    if MBridge.IsRsg then return st.isLoggedIn == true or st.IsInSession == true end
    return st.IsInSession == true or st.isLoggedIn == true
end

function MBridge.WaitForSession(intervalMs)
    intervalMs = intervalMs or 1000
    while not MBridge.InSession() do Wait(intervalMs) end
end

-- ------------------------------------------------------------
-- Interaction points
--
--   MULTItarget (VORP or RSG-Core): sphere zones, entity targets, global ped / player targets
--   without MULTItarget  : a key-press prompt (RedM prompt group) while you stand near
--
-- Scripts register a point once and never care which framework is running.
--
--   MBridge.Interact.AddZone(id, spec)          RemoveZone(id)
--   MBridge.Interact.AddEntity(entity, spec)    RemoveEntity(entity)
--   MBridge.Interact.AddGlobalPed(id, spec)     RemoveGlobalPed(id)
--   MBridge.Interact.AddGlobalPlayer(id, spec)  RemoveGlobalPlayer(id)
--
--   spec = {
--     coords   = vector3,        -- zones only
--     radius   = 1.5,            -- MULTItarget sphere size
--     distance = 2.5,            -- how close the player has to be (both)
--     label    = 'Open',         icon = 'fa-solid fa-hand',
--     key      = 0xCEFD9220,     -- VORP key (default E)
--     title    = 'Trapper',      -- VORP prompt heading (defaults to label)
--     canInteract = function(entity) return true end,
--     onSelect    = function(entity) end,
--     options  = { { label=, icon=, key=, canInteract=, onSelect= }, ... }   -- several actions at one point
--   }
--
-- Zone / entity ids are strings you choose; adding an id twice replaces it.
-- ------------------------------------------------------------
local Interact = {}
MBridge.Interact = Interact

local DEFAULT_KEY  = 0xCEFD9220 -- E
local DEFAULT_DIST = 2.5
local DEFAULT_ICON = 'fa-solid fa-hand'

local function optionsOf(spec)
    if spec.options and #spec.options > 0 then return spec.options end
    return { spec }
end

-- A label is a string, or function(entity) -> string (the entity is nil where the label
-- has to be fixed up front, i.e. MULTItarget).
local function labelOf(o, spec, entity)
    local l = o.label or spec.label or 'Interact'
    if type(l) == 'function' then l = l(entity) end
    return tostring(l or 'Interact')
end

local function passes(spec, entity)
    if spec.canInteract and not spec.canInteract(entity) then return false end
    return true
end

local function anyOption(spec, entity)
    for _, o in ipairs(optionsOf(spec)) do
        if (not o.canInteract or o.canInteract(entity)) and passes(spec, entity) then return true end
    end
    return false
end

-- ---------------- MULTItarget backend ----------------
local oxZones, oxEntities, oxGlobals = {}, {}, {}
local oxWarned = false

local function oxStarted()
    return GetResourceState('MULTItarget') == 'started'
end

-- MULTItarget may start after this resource; wait for it (bounded) before registering.
-- Returns via callback: ok = true (registered with ox) / false (MULTItarget never came up).
local function whenOx(fn)
    if oxStarted() then fn(true) return end
    CreateThread(function()
        local waited = 0
        while not oxStarted() and waited < 30000 do Wait(250) waited = waited + 250 end
        fn(oxStarted())
    end)
end

local function oxOptions(idBase, spec)
    local out = {}
    for i, o in ipairs(optionsOf(spec)) do
        out[#out + 1] = {
            name     = ('%s:%s:%d'):format(RES, idBase, i),
            icon     = o.icon or spec.icon or DEFAULT_ICON,
            label    = labelOf(o, spec, nil),
            distance = spec.distance or DEFAULT_DIST,
            canInteract = function(entity)
                if not passes(spec, entity) then return false end
                if o.canInteract and not o.canInteract(entity) then return false end
                return true
            end,
            onSelect = function(data)
                local fn = o.onSelect or spec.onSelect
                if fn then fn(data and data.entity) end
            end,
        }
    end
    return out
end

-- ---------------- key-press backend (MULTItarget not installed) ----------------
local kpZones, kpEntities, kpGlobals = {}, {}, {}
local kpGroup, kpPrompts, kpThread = nil, {}, false
local kpSig, kpActiveKeys = '', {}

local function vs(text) return CreateVarString(10, 'LITERAL_STRING', tostring(text or '')) end

local function kpPrompt(key)
    if kpPrompts[key] then return kpPrompts[key] end
    kpGroup = kpGroup or GetRandomIntInRange(0, 0xffffff)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, key)
    PromptSetText(p, vs('Use'))
    PromptSetEnabled(p, false)
    PromptSetVisible(p, false)
    PromptSetStandardMode(p, 1)
    PromptSetGroup(p, kpGroup)
    PromptRegisterEnd(p)
    kpPrompts[key] = p
    return p
end

local function kpCandidate(spec, entity, coords, me)
    if not coords then return nil end
    local d = #(me - coords)
    if d > (spec.distance or DEFAULT_DIST) then return nil end
    if not anyOption(spec, entity) then return nil end
    return d
end

local kpPedCache, kpPedAt = {}, 0

-- Peds near enough to matter, refreshed a couple of times a second (scanning the pool every
-- frame would be wasteful). playersOnly: real players; otherwise everything that is not a player.
local function kpScanPeds(playersOnly)
    local now = GetGameTimer()
    if now - kpPedAt >= 400 then
        kpPedCache = { players = {}, peds = {} }
        local myPed = PlayerPedId()
        for _, ped in ipairs(GetGamePool('CPed')) do
            if ped ~= myPed and DoesEntityExist(ped) then
                local list = IsPedAPlayer(ped) and kpPedCache.players or kpPedCache.peds
                list[#list + 1] = ped
            end
        end
        kpPedAt = now
    end
    return playersOnly and (kpPedCache.players or {}) or (kpPedCache.peds or {})
end

local function kpFind()
    local me = GetEntityCoords(PlayerPedId())
    local best, bestD

    for _, z in pairs(kpZones) do
        local d = kpCandidate(z, nil, z.coords, me)
        if d and (not bestD or d < bestD) then best, bestD = { spec = z }, d end
    end
    for e, z in pairs(kpEntities) do
        if DoesEntityExist(e) then
            local d = kpCandidate(z, e, GetEntityCoords(e), me)
            if d and (not bestD or d < bestD) then best, bestD = { spec = z, entity = e }, d end
        else
            kpEntities[e] = nil
        end
    end
    for _, g in pairs(kpGlobals) do
        for _, ped in ipairs(kpScanPeds(g.playersOnly)) do
            if DoesEntityExist(ped) then
                local d = kpCandidate(g, ped, GetEntityCoords(ped), me)
                if d and (not bestD or d < bestD) then best, bestD = { spec = g, entity = ped }, d end
            end
        end
    end
    return best
end

local function kpDrive(active)
    local spec, entity = active.spec, active.entity
    local opts = {}
    for _, o in ipairs(optionsOf(spec)) do
        if (not o.canInteract or o.canInteract(entity)) then opts[#opts + 1] = o end
    end
    if #opts == 0 then return end

    -- Refresh prompt text / visibility only when the set of options changes.
    local sig = {}
    for _, o in ipairs(opts) do sig[#sig + 1] = tostring(o.key or spec.key or DEFAULT_KEY) .. '=' .. labelOf(o, spec, entity) end
    sig = table.concat(sig, '|')
    if sig ~= kpSig then
        kpSig = sig
        for k, p in pairs(kpPrompts) do PromptSetEnabled(p, false); PromptSetVisible(p, false) end
        kpActiveKeys = {}
        for _, o in ipairs(opts) do
            local k = o.key or spec.key or DEFAULT_KEY
            local p = kpPrompt(k)
            PromptSetText(p, vs(labelOf(o, spec, entity)))
            PromptSetEnabled(p, true)
            PromptSetVisible(p, true)
            kpActiveKeys[k] = o
        end
    end

    local heading = spec.title or (type(spec.label) == 'string' and spec.label) or (spec.options and spec.options[1] and type(spec.options[1].label) == 'string' and spec.options[1].label) or ''
    PromptSetActiveGroupThisFrame(kpGroup, vs(heading))

    for k, o in pairs(kpActiveKeys) do
        local p = kpPrompts[k]
        if p and PromptHasStandardModeCompleted(p) then
            local fn = o.onSelect or spec.onSelect
            if fn then CreateThread(function() fn(entity) end) end
            return true -- caller pauses briefly so one press is one action
        end
    end
end

local function kpEnsureThread()
    if kpThread then return end
    kpThread = true
    CreateThread(function()
        MBridge.WaitForSession()
        while true do
            local sleep = 500
            local active = (next(kpZones) or next(kpEntities) or next(kpGlobals)) and kpFind() or nil
            if active then
                sleep = 0
                if kpDrive(active) then Wait(600) end
            else
                if kpSig ~= '' then
                    kpSig = ''
                    for _, p in pairs(kpPrompts) do PromptSetEnabled(p, false); PromptSetVisible(p, false) end
                end
            end
            Wait(sleep)
        end
    end)
end

-- ---------------- public API ----------------
local function useOx() return GetResourceState('MULTItarget') ~= 'missing' end

function Interact.AddZone(id, spec)
    id = tostring(id)
    Interact.RemoveZone(id)
    if useOx() then
        local tok = { pending = true }
        oxZones[id] = tok
        whenOx(function(ok)
            if oxZones[id] ~= tok then return end -- removed or replaced meanwhile
            if ok then
                local zid = exports.MULTItarget:addSphereZone({
                    name    = ('%s:%s'):format(RES, id),
                    coords  = spec.coords,
                    radius  = spec.radius or 1.5,
                    debug   = spec.debug or false,
                    options = oxOptions(id, spec),
                })
                oxZones[id] = { zid = zid }
            else
                if not oxWarned then oxWarned = true; MBridge.Log('^3MULTItarget is not running - using key-press prompts instead^7') end
                oxZones[id] = nil
                kpZones[id] = spec
                kpEnsureThread()
            end
        end)
    else
        kpZones[id] = spec
        kpEnsureThread()
    end
end

function Interact.RemoveZone(id)
    id = tostring(id)
    local z = oxZones[id]
    if z then
        if z.zid then pcall(function() exports.MULTItarget:removeZone(z.zid) end) end
        oxZones[id] = nil
    end
    kpZones[id] = nil
end

function Interact.AddEntity(entity, spec)
    if not entity or entity == 0 then return end
    Interact.RemoveEntity(entity)
    if useOx() then
        local tok = { pending = true }
        oxEntities[entity] = tok
        whenOx(function(ok)
            if oxEntities[entity] ~= tok then return end
            if not DoesEntityExist(entity) then oxEntities[entity] = nil return end
            if ok then
                local opts = oxOptions('e' .. tostring(entity), spec)
                exports.MULTItarget:addLocalEntity(entity, opts)
                oxEntities[entity] = { names = (function() local n = {} for _, o in ipairs(opts) do n[#n + 1] = o.name end return n end)() }
            else
                oxEntities[entity] = nil
                kpEntities[entity] = spec
                kpEnsureThread()
            end
        end)
    else
        kpEntities[entity] = spec
        kpEnsureThread()
    end
end

function Interact.RemoveEntity(entity)
    local e = oxEntities[entity]
    if e then
        if e.names and DoesEntityExist(entity) then pcall(function() exports.MULTItarget:removeLocalEntity(entity, e.names) end) end
        oxEntities[entity] = nil
    end
    kpEntities[entity] = nil
end

local function removeGlobal(kind, id)
    id = tostring(id)
    local g = oxGlobals[kind .. id]
    if g then
        if g.names then pcall(function() exports.MULTItarget['removeGlobal' .. kind](exports.MULTItarget, g.names) end) end
        oxGlobals[kind .. id] = nil
    end
    kpGlobals[kind .. id] = nil
end

local function addGlobal(kind, id, spec)
    id = tostring(id)
    removeGlobal(kind, id)
    if useOx() then
        local tok = { pending = true }
        oxGlobals[kind .. id] = tok
        whenOx(function(ok)
            if oxGlobals[kind .. id] ~= tok then return end
            if ok then
                local opts = oxOptions(kind .. id, spec)
                exports.MULTItarget['addGlobal' .. kind](exports.MULTItarget, opts)
                oxGlobals[kind .. id] = { names = (function() local n = {} for _, o in ipairs(opts) do n[#n + 1] = o.name end return n end)() }
            else
                oxGlobals[kind .. id] = nil
                spec.playersOnly = (kind == 'Player')
                kpGlobals[kind .. id] = spec
                kpEnsureThread()
            end
        end)
    else
        spec.playersOnly = (kind == 'Player')
        kpGlobals[kind .. id] = spec
        kpEnsureThread()
    end
end

function Interact.AddGlobalPed(id, spec)      addGlobal('Ped', id, spec) end
function Interact.RemoveGlobalPed(id)         removeGlobal('Ped', id) end
function Interact.AddGlobalPlayer(id, spec)   addGlobal('Player', id, spec) end
function Interact.RemoveGlobalPlayer(id)      removeGlobal('Player', id) end

-- Clean up on stop so a restart doesn't leave stale MULTItarget entries behind.
AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for id in pairs(oxZones) do Interact.RemoveZone(id) end
    for e in pairs(oxEntities) do Interact.RemoveEntity(e) end
    for k, g in pairs(oxGlobals) do
        if g.names then
            local kind = k:sub(1, 3) == 'Ped' and 'Ped' or 'Player'
            pcall(function() exports.MULTItarget['removeGlobal' .. kind](exports.MULTItarget, g.names) end)
        end
    end
end)

-- ------------------------------------------------------------
-- Callbacks (bridge-owned in RSG mode; see bridge/server.lua)
-- ------------------------------------------------------------
local Callback
if MBridge.IsRsg then
    local Callbacks, pending, nextReq = {}, {}, 0
    local EV_REQ_S, EV_RES_S = RES .. ':shb:sv:req', RES .. ':shb:sv:res'
    local EV_REQ_C, EV_RES_C = RES .. ':shb:cl:req', RES .. ':shb:cl:res'

    RegisterNetEvent(EV_RES_C, function(id, ...)
        local p = pending[id]
        if p then pending[id] = nil; p:resolve(table.pack(...)) end
    end)

    RegisterNetEvent(EV_REQ_C, function(id, name, ...)
        local fn = Callbacks[name]
        if not fn then
            TriggerServerEvent(EV_RES_S, id)
            return
        end
        fn(function(...) TriggerServerEvent(EV_RES_S, id, ...) end, ...)
    end)

    Callback = {}
    function Callback.Register(name, fn) Callbacks[name] = fn end

    function Callback.TriggerAwait(name, ...)
        nextReq = nextReq + 1
        local id = nextReq
        local p = promise.new()
        pending[id] = p
        SetTimeout(15000, function()
            if pending[id] then pending[id] = nil; p:resolve(table.pack()) end
        end)
        TriggerServerEvent(EV_REQ_S, id, name, ...)
        local res = Citizen.Await(p)
        return table.unpack(res, 1, res.n)
    end
end

-- ------------------------------------------------------------
-- VORP: passthrough
-- ------------------------------------------------------------
if MBridge.IsVorp then
    local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
    if ok and core then
        MBridge.Core = core
    else
        local cached
        MBridge.Core = setmetatable({}, { __index = function(_, k)
            if not cached then cached = exports.vorp_core:GetCore() end
            return cached[k]
        end })
    end

    ---Right-hand tip via vorp_core's export.
    function MBridge.Notify(text, ms)
        exports.vorp_core:DisplayTipRight(text, ms or 4000)
    end

    ---Right-hand tip via vorp_core's client event (what some scripts used).
    function MBridge.NotifyEvent(text, ms)
        TriggerEvent('vorp:TipRight', text, ms or 4000)
    end

    ---vorp_progressbar object: bar.start(text, ms, cb, style, color, width, ...)
    function MBridge.NewProgressBar()
        return exports.vorp_progressbar:initiate()
    end
    return
end

-- ------------------------------------------------------------
-- RSG
-- ------------------------------------------------------------
local function notify(text, ms, ntype)
    TriggerEvent('ox_lib:notify', {
        description = tostring(text or ''),
        type        = ntype or 'inform',
        duration    = ms or 4000,
        position    = 'top-right',
    })
end

function MBridge.Notify(text, ms) notify(text, ms) end
MBridge.NotifyEvent = MBridge.Notify

MBridge.Core = {
    Callback        = Callback,
    NotifyRightTip  = function(text, ms) notify(text, ms) end,
    NotifyTip       = function(text, ms) notify(text, ms) end,
    NotifyObjective = function(text, ms) notify(text, ms) end,
    NotifyAvanced   = function(text, _, _, _, ms) notify(text, ms) end,
}

---Same shape as vorp_progressbar's object. cb runs when the bar ends.
function MBridge.NewProgressBar()
    local bar = {}
    function bar.start(text, ms, cb)
        CreateThread(function()
            local finished = true
            local ok, res = pcall(function()
                return exports.ox_lib:progressBar({
                    duration     = ms or 3000,
                    label        = text or '',
                    useWhileDead = false,
                    canCancel    = false,
                })
            end)
            if ok then finished = res ~= false else Wait(ms or 3000) end
            if cb then cb(finished) end
        end)
    end
    return bar
end

---Text / number prompt. Returns the typed value, or nil if cancelled.
function MBridge.Input(header, placeholder, numeric)
    local res = exports.ox_lib:inputDialog(header or '', {
        { type = numeric and 'number' or 'input', label = placeholder or '', required = true },
    })
    if not res or res[1] == nil or res[1] == '' then return nil end
    return tostring(res[1])
end
