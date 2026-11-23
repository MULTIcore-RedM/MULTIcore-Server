-- ============================================================
-- MULTIhelpers :: QB-style progress bar (stands in for the 'progressbar'
-- resource that RSG v1 and qbr-core scripts call)
--
--   exports['progressbar']:Progress({
--       name = 'pick_herbs', duration = 5000, label = 'Picking herbs...',
--       useWhileDead = false, canCancel = true,
--       controlDisables = { disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true },
--       animation = { animDict = 'mech_pickup@plant@berries', anim = 'base', flags = 1 },   -- or { task = 'WORLD_HUMAN_...' }
--       prop = { model = 'p_bottle01x', bone = 'SKEL_R_Hand', coords = { x = 0, y = 0, z = 0 }, rotation = { x = 0, y = 0, z = 0 } },
--   }, function(cancelled) end)
--   exports['progressbar']:ProgressWithStartEvent(action, start, finish)
--   exports['progressbar']:ProgressWithTickEvent(action, tick, finish)
--   exports['progressbar']:ProgressWithStartAndTick(action, start, tick, finish)
--   TriggerEvent('progressbar:client:progress', action, finish)        (and the three other names)
--   TriggerEvent('progressbar:client:cancel')
--   TriggerEvent('progressbar:client:ToggleBusyness', true | false)
--
-- finish(cancelled) gets true when the bar was cancelled (key, event, death).
-- Shown with MULTIhelpers' own progress bar. Own code, written from the public
-- API description. GPL v3, part of MULTIcore.
-- ============================================================

local Cfg = Config.QBProgress
local RES = 'progressbar'

-- controls (Controls.cs names) blocked while a bar runs
local MOVE = { 0x4D8FB4C1, 0xFDA83190, 0x8FFC75D6, 0xD9D0E1C0, 0xDB096B85, 0xDE794E3E }   -- MoveLr, MoveUd, Sprint, Jump, Duck, Cover
local MOUNT = { 0x126796EB, 0x3BBDEFEF, 0x5AA007D7, 0xE4D2CE1D, 0xF1E2852C, 0x8A81C00C } -- HorseMoveLr/Ud, HorseSprint, HorseJump, VehMoveLr/Ud
local LOOK = { 0xA987235F, 0xD2047988 }                                                   -- LookLr, LookUd
local COMBAT = { 0x07CE1E61, 0xF84FA74F, 0xB2F377E8, 0x60C81CDE, 0x61470051, 0xE30CD707, 0xD0842EDF, 0xAC4BD4F1 }
-- Attack, Aim, MeleeAttack, HorseAttack, HorseAim, Reload, SelectNextWeapon, OpenWheelMenu

local current = nil     -- the running bar
local busy = false      -- ToggleBusyness(true) refuses new bars

local function call(fn, ...)
    if Helpers.Callable(fn) then Helpers.SafeCall(fn, ...) end
end

local function dead(ped)
    return IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local until_ = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < until_ do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

local function boneIndex(ped, bone)
    if type(bone) == 'string' then return GetEntityBoneIndexByName(ped, bone) end
    if type(bone) == 'number' then return GetPedBoneIndex(ped, bone) end   -- QB bone ids (UNVERIFIED in RedM)
    return GetEntityBoneIndexByName(ped, 'SKEL_R_Hand')
end

local function v3(t)
    t = type(t) == 'table' and t or {}
    return tonumber(t.x or t[1]) or 0.0, tonumber(t.y or t[2]) or 0.0, tonumber(t.z or t[3]) or 0.0
end

local function attachProp(ped, p)
    if type(p) ~= 'table' or not p.model then return nil end
    local hash = loadModel(p.model)
    if not hash then return nil end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return nil end
    local x, y, z = v3(p.coords)
    local rx, ry, rz = v3(p.rotation)
    AttachEntityToEntity(obj, ped, boneIndex(ped, p.bone), x, y, z, rx, ry, rz, true, true, false, true, 1, true)
    return obj
end

local function startAnim(ped, a)
    if type(a) ~= 'table' then return nil end
    if type(a.task) == 'string' and a.task ~= '' then
        TaskStartScenarioInPlace(ped, joaat(a.task), -1, true, false, false, false)
        return { task = true }
    end
    if type(a.animDict) ~= 'string' or type(a.anim) ~= 'string' then return nil end
    RequestAnimDict(a.animDict)
    local until_ = GetGameTimer() + 3000
    while not HasAnimDictLoaded(a.animDict) and GetGameTimer() < until_ do Wait(10) end
    if not HasAnimDictLoaded(a.animDict) then return nil end
    TaskPlayAnim(ped, a.animDict, a.anim, 3.0, -3.0, -1, tonumber(a.flags) or 1, 0, false, false, false)
    return { dict = a.animDict, anim = a.anim }
end

local function stopAnim(ped, played)
    if not played then return end
    if played.task then
        ClearPedTasks(ped)
    else
        StopAnimTask(ped, played.dict, played.anim, 1.0)
        RemoveAnimDict(played.dict)
    end
end

local function cleanup(c)
    local ped = PlayerPedId()
    stopAnim(ped, c.anim)
    for _, obj in ipairs(c.props) do
        if DoesEntityExist(obj) then
            DetachEntity(obj, true, true)
            DeleteObject(obj)
        end
    end
end

local function stop(c, cancelled)
    if current ~= c then return end
    current = nil
    if cancelled then Helpers.ProgressCancel(c.bar) end
    cleanup(c)
    call(c.finish, cancelled and true or false)
end

local function disable(list)
    for _, k in ipairs(list) do DisableControlAction(0, k, true) end
end

local function run(action, start, tick, finish)
    action = type(action) == 'table' and action or {}
    local ped = PlayerPedId()
    if current or busy then
        if Cfg.BusyMessage then Helpers.Notify({ text = _L('progress_busy'), type = 'error' }) end
        call(finish, true)
        return
    end
    if dead(ped) and not action.useWhileDead then
        Helpers.Notify({ text = _L('progress_dead'), type = 'error' })
        call(finish, true)
        return
    end

    local c = { action = action, finish = finish, tick = tick, props = {}, owner = GetInvokingResource() }
    current = c
    c.anim = startAnim(ped, action.animation)
    c.props[#c.props + 1] = attachProp(ped, action.prop)
    c.props[#c.props + 1] = attachProp(ped, action.propTwo)
    c.bar = Helpers.ProgressStart(action.label or '', tonumber(action.duration) or 0, function() stop(c, false) end,
        nil, nil, nil, false)
    call(start)

    local cd = type(action.controlDisables) == 'table' and action.controlDisables or {}
    CreateThread(function()
        while current == c do
            local p = PlayerPedId()
            if cd.disableMovement then disable(MOVE) end
            if cd.disableCarMovement then disable(MOUNT) end
            if cd.disableMouse then disable(LOOK) end
            if cd.disableCombat then
                disable(COMBAT)
                DisablePlayerFiring(PlayerId(), true)
            end
            if action.canCancel then
                for _, k in ipairs(Cfg.CancelKeys or {}) do
                    DisableControlAction(0, k, true)
                    if IsDisabledControlJustPressed(0, k) then stop(c, true) break end
                end
            end
            if current == c and not action.useWhileDead and dead(p) then stop(c, true) end
            if current == c then call(c.tick) end
            Wait(0)
        end
    end)
end

local function cancel()
    if current then stop(current, true) end
end

-- the calling script stopped: end its bar without calling back into it
AddEventHandler('onClientResourceStop', function(res)
    if current and current.owner == res then
        local c = current
        current = nil
        Helpers.ProgressCancel(c.bar)
        cleanup(c)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and current then cleanup(current) end
end)

-- ------------------------------------------------------------ exports and events
local function progress(action, finish) run(action, nil, nil, finish) end
local function withStart(action, start, finish) run(action, start, nil, finish) end
local function withTick(action, tick, finish) run(action, nil, tick, finish) end
local function withBoth(action, start, tick, finish) run(action, start, tick, finish) end

Helpers.ExportAs('Progress', progress, { RES })
Helpers.ExportAs('ProgressWithStartEvent', withStart, { RES })
Helpers.ExportAs('ProgressWithTickEvent', withTick, { RES })
Helpers.ExportAs('ProgressWithStartAndTick', withBoth, { RES })

Helpers.On(RES, 'progressbar:client:progress', progress)
Helpers.On(RES, 'progressbar:client:ProgressWithStartEvent', withStart)
Helpers.On(RES, 'progressbar:client:ProgressWithTickEvent', withTick)
Helpers.On(RES, 'progressbar:client:ProgressWithStartAndTick', withBoth)
Helpers.On(RES, 'progressbar:client:cancel', cancel, true)
Helpers.On(RES, 'progressbar:client:ToggleBusyness', function(b) busy = b and true or false end, true)

-- MULTIhelpers' own name for the QB form (Progress alone would be too vague)
exports('QBProgress', progress)
