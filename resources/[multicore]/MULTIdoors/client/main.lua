-- ============================================================
-- MULTIdoors :: client
-- Sets managed doors near the player to the server's state, offers the
-- lock / unlock prompt (or MULTItarget), plays the key animation, runs
-- the lockpick skill check and shows law alerts. Every decision is the
-- server's; this file only asks and shows.
-- Door natives as RSG v2 rsg-doorlock / MULTIbank use them (femga natives.json):
--   AddDoorToSystemNew (0xD99229FE93B46286), IsDoorRegisteredWithSystem (0xC153C43EA202C8C1),
--   DoorSystemSetDoorState (0x6BAB9442830C7F53), DoorSystemGetDoorState (0x160AA1B32F6139B8),
--   DoorSystemSetOpenRatio (0xB6E6FBA95C7324AC).
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local N = {
    DOOR_SYSTEM_GET_DOOR_STATE = 0x160AA1B32F6139B8, -- (doorHash) -> int
    DOOR_SYSTEM_SET_OPEN_RATIO = 0xB6E6FBA95C7324AC, -- (doorHash, ratio, BOOL)
    UI_PROMPT_SET_ACTIVE_GROUP_THIS_FRAME = 0xC65A45D4453C2627, -- (group, label, p2)
    BLIP_ADD_FOR_COORDS = 0x554D9D53F696D002,        -- (style, x, y, z) -> blip
    SET_BLIP_SPRITE = 0x74F74D3207ED525C,            -- (blip, hash, BOOL)
    SET_BLIP_SCALE = 0xD38744167B2FA257,             -- (blip, scale)
    _SET_BLIP_NAME = 0x9CB1A1623062F402,             -- (blip, name)
}
local STATE_PREFIX = 'multidoors:'

MDC = {
    Rules = {},     -- id -> public rule (coords as vector3)
    State = {},     -- id -> true when locked
    busy = false,
}
local applied = {}  -- door hash -> state we last wrote
local current       -- rule the player stands at (prompt mode)

local function notify(text, kind)
    exports.MULTIcore:Notify({ text = text, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end
MDC.Notify = notify

function MDC.ErrText(err) return _L('err_' .. tostring(err or 'unknown')) end

---------------------------------
-- rules and state
---------------------------------
local function setRules(list)
    local rules = {}
    for _, r in ipairs(list or {}) do
        r.coords = vector3(r.coords.x, r.coords.y, r.coords.z)
        rules[r.id] = r
        MDC.State[r.id] = GlobalState[STATE_PREFIX .. r.id]
    end
    -- doors that are no longer managed go back to the game's own state
    for h in pairs(applied) do
        local still = false
        for _, r in pairs(rules) do for _, d in ipairs(r.doors) do if d == h then still = true end end end
        if not still then DoorSystemSetDoorState(h, 0); applied[h] = nil end
    end
    MDC.Rules = rules
    if MDC.OnRules then MDC.OnRules() end
end

local function wantState(id)
    return MDC.State[id] and Config.LockedState or 0
end

local function applyRule(r, force)
    local want = wantState(r.id)
    for _, h in ipairs(r.doors) do
        if not IsDoorRegisteredWithSystem(h) then
            AddDoorToSystemNew(h, 1, 1, 0, 0, 0, 0)
        end
        local now = Citizen.InvokeNative(N.DOOR_SYSTEM_GET_DOOR_STATE, h, Citizen.ResultAsInteger())
        if force or now ~= want then
            DoorSystemSetDoorState(h, want)
            if want ~= 0 and Config.CloseOnLock then
                Citizen.InvokeNative(N.DOOR_SYSTEM_SET_OPEN_RATIO, h, 0.0, true)
            end
        end
        applied[h] = want
    end
end

AddStateBagChangeHandler(nil, 'global', function(_, key, value)
    if type(key) ~= 'string' or key:sub(1, #STATE_PREFIX) ~= STATE_PREFIX then return end
    local id = key:sub(#STATE_PREFIX + 1)
    MDC.State[id] = value
    local r = MDC.Rules[id]
    if r and #(GetEntityCoords(cache.ped) - r.coords) < Config.ApplyDistance then
        CreateThread(function() Wait(0) applyRule(r, true) end)
    end
end)

RegisterNetEvent('MULTIdoors:client:rules', function(list) setRules(list) end)

CreateThread(function()
    setRules(lib.callback.await('MULTIdoors:getRules', false))
    while true do
        local pos = GetEntityCoords(cache.ped)
        for _, r in pairs(MDC.Rules) do
            if #(pos - r.coords) < Config.ApplyDistance then applyRule(r) end
        end
        Wait(Config.ApplyIntervalMs)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for h in pairs(applied) do DoorSystemSetDoorState(h, 0) end
end)

---------------------------------
-- animation
---------------------------------
local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 100 do Wait(50) t = t + 1 end
    return HasAnimDictLoaded(dict)
end

local function faceCoords(c)
    local p = GetEntityCoords(cache.ped)
    SetPedDesiredHeading(cache.ped, GetHeadingFromVector_2d(c.x - p.x, c.y - p.y))
end

local function keyProp()
    local A = Config.Anim
    if not A.Prop or A.Prop == '' then return nil end
    local model = joaat(A.Prop)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 50 do Wait(50) t = t + 1 end
    if not HasModelLoaded(model) then return nil end
    local p = GetEntityCoords(cache.ped)
    local prop = CreateObject(model, p.x, p.y, p.z + 0.2, true, true, true)
    SetModelAsNoLongerNeeded(model)
    local bone = GetEntityBoneIndexByName(cache.ped, A.PropBone)
    -- offsets from rsg-doorlock
    AttachEntityToEntity(prop, cache.ped, bone, 0.02, 0.0120, -0.00850, 0.024, -160.0, 200.0, true, true, false, true, 1, true)
    return prop
end

--- Plays the key animation at a door; fn runs at Config.Anim.ChangeAtMs.
function MDC.KeyAnim(coords, fn)
    local A = Config.Anim
    faceCoords(coords)
    if not A.Enabled or not loadDict(A.Dict) then fn() return end
    TaskPlayAnim(cache.ped, A.Dict, A.Clip, 8.0, -8.0, A.DurationMs, A.Flag, 0, true, 0, false, 0, false)
    RemoveAnimDict(A.Dict)
    local prop = keyProp()
    Wait(A.ChangeAtMs)
    fn()
    Wait(math.max(0, A.DurationMs - A.ChangeAtMs))
    ClearPedSecondaryTask(cache.ped)
    if prop and DoesEntityExist(prop) then DeleteObject(prop) end
end

---------------------------------
-- lock / unlock and lockpick
---------------------------------
function MDC.Use(id)
    local r = MDC.Rules[id]
    if not r or MDC.busy then return end
    MDC.busy = true
    local res = lib.callback.await('MULTIdoors:check', false, id)
    if not res or not res.ok then
        notify(MDC.ErrText(res and res.err), 'error')
        MDC.busy = false
        return
    end
    local want = not res.locked
    MDC.KeyAnim(r.coords, function()
        local done = lib.callback.await('MULTIdoors:use', false, id, want)
        if done and done.ok then
            notify(done.locked and _L('door_locked', r.label) or _L('door_unlocked', r.label), 'success')
        else
            notify(MDC.ErrText(done and done.err), 'error')
        end
    end)
    MDC.busy = false
end

function MDC.Pick(id)
    local r = MDC.Rules[id]
    local L = Config.Lockpick
    if not r or MDC.busy or not L.Enabled then return end
    MDC.busy = true
    local res = lib.callback.await('MULTIdoors:pickStart', false, id)
    if not res or not res.ok then
        notify(MDC.ErrText(res and res.err), 'error')
        MDC.busy = false
        return
    end
    local t0 = GetGameTimer()
    faceCoords(r.coords)
    local A = Config.Anim
    if A.Enabled and loadDict(A.Dict) then
        TaskPlayAnim(cache.ped, A.Dict, A.Clip, 8.0, -8.0, -1, L.AnimLoopFlag, 0, true, 0, false, 0, false)
    end
    -- MULTIrobberies' pin lock when it runs (Config.Lockpick.Minigame), else the ox_lib skill check
    local ok
    if L.Minigame ~= 'skillcheck' and GetResourceState('MULTIrobberies') == 'started' then
        ok = exports.MULTIrobberies:Lockpick(L.MinigameLevel or 'medium', r.label)
    else
        ok = lib.skillCheck(L.Difficulty, L.Inputs)
    end
    local wait = L.MinMs - (GetGameTimer() - t0)
    if ok and wait > 0 then Wait(wait) end
    ClearPedTasks(cache.ped)
    local done = lib.callback.await('MULTIdoors:pickEnd', false, res.token, ok == true)
    if done and done.ok and done.unlocked then
        notify(_L('pick_success', r.label), 'success')
    elseif done and done.ok then
        notify(done.broke and _L('pick_broke') or _L('pick_failed'), 'error')
    else
        notify(MDC.ErrText(done and done.err), 'error')
    end
    MDC.busy = false
end

---------------------------------
-- prompt mode
---------------------------------
local function blocked()
    return IsEntityDead(cache.ped) or IsPedCuffed(cache.ped)
end

local function nearestRule()
    local pos = GetEntityCoords(cache.ped)
    local best, bd
    for _, r in pairs(MDC.Rules) do
        local d = #(pos - r.coords)
        for _, h in ipairs(r.doors) do
            local dd = MULTIDoorData[h]
            if dd then d = math.min(d, #(pos - vector3(dd.x, dd.y, dd.z))) end
        end
        if d <= r.distance and (not bd or d < bd) then best, bd = r, d end
    end
    return best
end

-- Config.Interact 'auto' / 'target' / 'prompt' (see @MULTIcore/lib/interact.lua):
-- MULTItarget spheres on the doors, or the hold-key prompt group at the nearest door.
local interactMode = nil    -- 'target' or 'prompt' once MCI.Run has decided

-- prompt mode: one prompt group (lock / unlock + pick) shown at the nearest door
local group = GetRandomIntInRange(0, 0xffffff)
local useP, pickP
local function makePrompt(key, text)
    local p = UiPromptRegisterBegin()
    UiPromptSetControlAction(p, key)
    UiPromptSetText(p, CreateVarString(10, 'LITERAL_STRING', text))
    UiPromptSetEnabled(p, true)
    UiPromptSetVisible(p, true)
    UiPromptSetHoldMode(p, Config.PromptHoldMs)
    UiPromptSetGroup(p, group, 0)
    UiPromptRegisterEnd(p)
    return p
end

local function makePrompts()
    if useP then return end
    useP = makePrompt(MCI.Key(Config.PromptKey), _L('prompt_unlock'))
    pickP = makePrompt(MCI.Key(Config.Lockpick.Key), _L('prompt_pick'))
    MCI.Count('prompts', 2)
end

local function deletePrompts()
    if useP then UiPromptDelete(useP) MCI.Count('prompts', -1) end
    if pickP then UiPromptDelete(pickP) MCI.Count('prompts', -1) end
    useP, pickP = nil, nil
end

CreateThread(function()
    while true do
        current = (interactMode == 'prompt' and not blocked() and not MDC.busy) and nearestRule() or nil
        Wait(current and 250 or 750)
    end
end)

CreateThread(function()
    local shownLocked, shownPick
    while true do
        local r = current
        if r and useP and interactMode == 'prompt' then
            local locked = MDC.State[r.id] == true
            if shownLocked ~= locked then
                UiPromptSetText(useP, CreateVarString(10, 'LITERAL_STRING', locked and _L('prompt_unlock') or _L('prompt_lock')))
                shownLocked = locked
            end
            local pick = locked and r.lockpickable and Config.Lockpick.Enabled
            if shownPick ~= pick then
                UiPromptSetEnabled(pickP, pick)
                UiPromptSetVisible(pickP, pick)
                shownPick = pick
            end
            local label = ('%s - %s'):format(r.label, locked and _L('state_locked') or _L('state_unlocked'))
            Citizen.InvokeNative(N.UI_PROMPT_SET_ACTIVE_GROUP_THIS_FRAME, group, CreateVarString(10, 'LITERAL_STRING', label), 1)
            if UiPromptHasHoldModeCompleted(useP) then
                current = nil
                MDC.Use(r.id)
            elseif pick and UiPromptHasHoldModeCompleted(pickP) then
                current = nil
                MDC.Pick(r.id)
            end
            Wait(0)
        else
            shownLocked, shownPick = nil, nil
            Wait(250)
        end
    end
end)

-- target mode: one MULTItarget sphere per door rule, rebuilt when the rules change
local zones = {}
local function clearZones()
    for _, z in ipairs(zones) do MCI.RemoveZone(z) end
    zones = {}
end

local function buildZones()
    clearZones()
    for id, r in pairs(MDC.Rules) do
        zones[#zones + 1] = MCI.AddZone({
            coords = r.coords,
            radius = Config.TargetRadius,
            options = {
                {
                    name = 'multidoors_use_' .. id,
                    label = _L('target_use'),
                    icon = Config.TargetIcon,
                    distance = r.distance,
                    canInteract = function() return not MDC.busy end,
                    onSelect = function() MDC.Use(id) end,
                },
                {
                    name = 'multidoors_pick_' .. id,
                    label = _L('prompt_pick'),
                    icon = Config.TargetPickIcon,
                    distance = r.distance,
                    canInteract = function()
                        return not MDC.busy and Config.Lockpick.Enabled and r.lockpickable and MDC.State[id] == true
                    end,
                    onSelect = function() MDC.Pick(id) end,
                },
            },
        })
    end
end

MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    if mode == 'target' then
        MDC.OnRules = buildZones
        buildZones()
    else
        MDC.OnRules = nil
        makePrompts()
    end
end, function(mode)
    interactMode = nil
    current = nil
    MDC.OnRules = nil
    clearZones()
    deletePrompts()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deletePrompts()
    -- MULTItarget drops this script's zones by itself when it stops
end)

---------------------------------
-- law alert
---------------------------------
local alerts = {}
RegisterNetEvent('MULTIdoors:client:alert', function(coords, text)
    if type(coords) ~= 'vector3' then return end
    local C = Config.Alert
    notify(tostring(text or _L('alert_default')), 'police')
    local blip = Citizen.InvokeNative(N.BLIP_ADD_FOR_COORDS, C.BlipStyle, coords.x, coords.y, coords.z, Citizen.ResultAsInteger())
    if blip and blip ~= 0 then
        Citizen.InvokeNative(N.SET_BLIP_SPRITE, blip, C.BlipSprite, true)
        Citizen.InvokeNative(N.SET_BLIP_SCALE, blip, C.BlipScale + 0.0)
        Citizen.InvokeNative(N._SET_BLIP_NAME, blip, _L('alert_blip'))
        alerts[#alerts + 1] = blip
        SetTimeout(C.BlipSeconds * 1000, function()
            RemoveBlip(blip)
            for i = #alerts, 1, -1 do if alerts[i] == blip then table.remove(alerts, i) end end
        end)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(alerts) do RemoveBlip(b) end
end)

---------------------------------
-- rsg-doorlock (RSG v2): the server sends changedoor after its key check;
-- play the animation and answer with updateState, as rsg-doorlock's client does
---------------------------------
RegisterNetEvent('rsg-doorlock:changedoor', function(doorID, state)
    doorID = tonumber(doorID)
    local target
    for _, r in pairs(MDC.Rules) do
        for _, k in ipairs(r.rsg or {}) do if k == doorID then target = r end end
    end
    if not target then return end
    MDC.KeyAnim(target.coords, function()
        TriggerServerEvent('rsg-doorlock:updateState', doorID, state)
    end)
end)
