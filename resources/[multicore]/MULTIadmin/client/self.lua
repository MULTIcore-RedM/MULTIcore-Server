-- ============================================================
-- MULTIadmin :: client - self tools
-- Noclip, godmode, invisible, teleport to waypoint, coords, spawning.
-- Each tool asks the server first (permission + log), then runs here.
-- Natives checked against the RDR3 native list; underscore natives are
-- called by hash.
-- ============================================================

local state = { noclip = false, god = false, invisible = false, speed = Config.Noclip.StartSpeed }
local N = {
    SET_ATTRIBUTE_CORE_VALUE = 0xC6258F41D86676E0,   -- _SET_ATTRIBUTE_CORE_VALUE (ped, coreIndex, value)
    GET_WAYPOINT_COORDS = 0x29B30D07C3F7873B,        -- _GET_WAYPOINT_COORDS () -> vector3 (z is always 0)
    SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE, -- _SET_RANDOM_OUTFIT_VARIATION (ped, p1)
}
local CORE_HEALTH, CORE_STAMINA = 0, 1               -- eAttributeCore (game enum)
local TP = Config.Teleport

function Admin.SelfState()
    return {
        noclip = state.noclip, god = state.god, invisible = state.invisible,
        speed = Config.Noclip.Speeds[state.speed],
    }
end

local function allowed(action, data)
    return Admin.Run(action, data).ok == true
end

--- The entity the player controls: wagon, mount or the ped itself.
local function controlled()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    if IsPedOnMount(ped) then
        local mount = GetMount(ped)
        if mount ~= 0 then return mount end
    end
    return ped
end

-- ---------------------------------------------------------------
-- health (used by self heal and by the target events)
-- ---------------------------------------------------------------

function Admin.LocalHeal()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped, false), 0)
    Citizen.InvokeNative(N.SET_ATTRIBUTE_CORE_VALUE, ped, CORE_HEALTH, Config.HealCoreValue)
    Citizen.InvokeNative(N.SET_ATTRIBUTE_CORE_VALUE, ped, CORE_STAMINA, Config.HealCoreValue)
end

function Admin.LocalRevive()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), 0, false, 0, false)
        local giveUp = GetGameTimer() + Config.ReviveTimeoutMs
        while IsEntityDead(PlayerPedId()) and GetGameTimer() < giveUp do Wait(0) end
        ped = PlayerPedId()
        ClearPedTasksImmediately(ped, false, true)
    end
    Admin.LocalHeal()
    if state.god then SetEntityInvincible(ped, true) end
    if state.invisible then SetEntityVisible(ped, false) end
end

-- ---------------------------------------------------------------
-- noclip
-- ---------------------------------------------------------------

local noclipEnt
local vel = vector3(0.0, 0.0, 0.0)

local function speedText()
    lib.showTextUI(_L('noclip_text', tostring(Config.Noclip.Speeds[state.speed])))
end

local function setNoclipEntity(ent, on)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    SetEntityCollision(ent, not on, not on)
    FreezeEntityPosition(ent, on)
    SetEntityInvincible(ent, on or (ent == PlayerPedId() and state.god))
end

local function stopNoclip()
    state.noclip = false
    setNoclipEntity(noclipEnt, false)
    noclipEnt = nil
    lib.hideTextUI()
end

local function noclipLoop()
    local cfg = Config.Noclip
    local c = cfg.Controls
    local moveControls = { c.Forward, c.Back, c.Left, c.Right, c.Up, c.Down, c.Fast, c.Slow, c.SpeedUp, c.SpeedDown }
    local up = vector3(0.0, 0.0, 1.0)
    vel = vector3(0.0, 0.0, 0.0)
    speedText()
    while state.noclip do
        local ent = controlled()
        if ent ~= noclipEnt then
            setNoclipEntity(noclipEnt, false)
            noclipEnt = ent
            setNoclipEntity(ent, true)
        end
        for i = 1, #moveControls do DisableControlAction(0, moveControls[i], true) end

        if IsDisabledControlJustPressed(0, c.SpeedUp) and state.speed < #cfg.Speeds then
            state.speed = state.speed + 1; speedText()
        elseif IsDisabledControlJustPressed(0, c.SpeedDown) and state.speed > 1 then
            state.speed = state.speed - 1; speedText()
        end

        -- direction from the gameplay camera (rotation order 2)
        local rot = GetGameplayCamRot(2)
        local yaw, pitch = math.rad(rot.z), math.rad(rot.x)
        local fwd = vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
        local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)

        local dir = vector3(0.0, 0.0, 0.0)
        if IsDisabledControlPressed(0, c.Forward) then dir = dir + fwd end
        if IsDisabledControlPressed(0, c.Back) then dir = dir - fwd end
        if IsDisabledControlPressed(0, c.Right) then dir = dir + right end
        if IsDisabledControlPressed(0, c.Left) then dir = dir - right end
        if IsDisabledControlPressed(0, c.Up) then dir = dir + up end
        if IsDisabledControlPressed(0, c.Down) then dir = dir - up end
        local len = #dir
        if len > 0 then dir = dir / len end

        local speed = cfg.Speeds[state.speed]
        if IsDisabledControlPressed(0, c.Fast) then speed = speed * cfg.FastMultiplier end
        if IsDisabledControlPressed(0, c.Slow) then speed = speed * cfg.SlowMultiplier end

        -- ease towards the wanted velocity so starts and stops are smooth
        local dt = GetFrameTime()
        vel = vel + (dir * speed - vel) * math.min(1.0, dt * cfg.Smoothing)
        local nxt = GetEntityCoords(ent) + vel * dt
        SetEntityCoordsNoOffset(ent, nxt.x, nxt.y, nxt.z, true, true, true)
        SetEntityHeading(ent, rot.z)
        Wait(0)
    end
end

local function toggleNoclip(force)
    local want = force
    if want == nil then want = not state.noclip end
    if want == state.noclip then return true end
    if not allowed('noclip', { on = want }) then return false end
    if want then
        state.noclip = true
        CreateThread(function()
            noclipLoop()
            stopNoclip()
        end)
    else
        state.noclip = false -- the loop ends and cleans up
    end
    return true
end

RegisterCommand(Config.NoclipCommand, function() toggleNoclip() end, false)
Admin.MapKey(Config.NoclipCommand, _L('key_noclip'), Config.NoclipKey)

-- ---------------------------------------------------------------
-- godmode / invisible (kept on through respawns while switched on)
-- ---------------------------------------------------------------

local function applyFlags()
    local ped = PlayerPedId()
    SetEntityInvincible(ped, state.god or (state.noclip and noclipEnt == ped))
    SetEntityVisible(ped, not state.invisible)
end

CreateThread(function()
    while true do
        if state.god or state.invisible then
            applyFlags()
            Wait(Config.StateRecheckMs)
        else
            Wait(Config.IdleRecheckMs)
        end
    end
end)

-- ---------------------------------------------------------------
-- teleport helpers
-- ---------------------------------------------------------------

local function fadeOut()
    DoScreenFadeOut(TP.FadeMs)
    while not IsScreenFadedOut() do Wait(0) end
end

--- Finds the ground at x, y by probing down from high up (collision has to stream in first).
local function groundAt(x, y)
    for z = TP.ProbeTop, 0.0, -TP.ProbeStep do
        RequestCollisionAtCoord(x, y, z)
        local found, gz = GetGroundZFor_3dCoord(x, y, z, false)
        if found then return gz end
        Wait(TP.ProbeWaitMs)
    end
    return nil
end

function Admin.Teleport(c, waitForWorld)
    local ent = controlled()
    fadeOut()
    FreezeEntityPosition(ent, true)
    SetEntityCoords(ent, c.x, c.y, c.z + TP.Lift, false, false, false, false)
    if waitForWorld then
        local timeout = GetGameTimer() + TP.CollisionTimeoutMs
        while not HasCollisionLoadedAroundEntity(ent) and GetGameTimer() < timeout do
            RequestCollisionAtCoord(c.x, c.y, c.z)
            Wait(0)
        end
    end
    SetEntityCoords(ent, c.x, c.y, c.z, false, false, false, false)
    if c.w then SetEntityHeading(ent, c.w) end
    if not (state.noclip and ent == noclipEnt) then FreezeEntityPosition(ent, false) end
    DoScreenFadeIn(TP.FadeMs)
end

local function toWaypoint()
    if not IsWaypointActive() then
        Admin.Notify(_L('waypoint_none'), 'error')
        return false
    end
    if not allowed('waypoint') then return false end
    local wp = Citizen.InvokeNative(N.GET_WAYPOINT_COORDS, Citizen.ResultAsVector())
    local ent = controlled()
    fadeOut()
    FreezeEntityPosition(ent, true)
    SetEntityCoords(ent, wp.x, wp.y, TP.ProbeTop, false, false, false, false)
    local z = groundAt(wp.x, wp.y)
    SetEntityCoords(ent, wp.x, wp.y, (z or TP.FallbackZ) + TP.Lift, false, false, false, false)
    if not (state.noclip and ent == noclipEnt) then FreezeEntityPosition(ent, false) end
    DoScreenFadeIn(TP.FadeMs)
    if not z then Admin.Notify(_L('waypoint_noground'), 'warning') end
    return true
end

-- ---------------------------------------------------------------
-- coords
-- ---------------------------------------------------------------

local function coordsNow()
    local ent = controlled()
    local c = GetEntityCoords(ent)
    return { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ent) }
end

local FORMATS = {   -- code formats for the copy buttons (not player text)
    vector3 = 'vector3(%.2f, %.2f, %.2f)',
    vector4 = 'vector4(%.2f, %.2f, %.2f, %.2f)',
    table = '{ x = %.2f, y = %.2f, z = %.2f, w = %.2f }',
}

-- ---------------------------------------------------------------
-- spawn horse / wagon
-- ---------------------------------------------------------------

local function spawn(kind, model)
    model = tostring(model or ''):lower():gsub('%s', '')
    if not model:match('^[%w_]+$') then
        Admin.Notify(_L('model_empty'), 'error')
        return false
    end
    local hash = joaat(model)
    if not IsModelValid(hash) or not IsModelInCdimage(hash) then
        Admin.Notify(_L('model_invalid', model), 'error')
        return false
    end
    if kind == 'wagon' and not IsModelAVehicle(hash) then
        Admin.Notify(_L('model_not_wagon', model), 'error')
        return false
    elseif kind == 'horse' and not IsModelAPed(hash) then
        Admin.Notify(_L('model_not_horse', model), 'error')
        return false
    end
    if not allowed('spawn', { kind = kind, model = model }) then return false end
    if not pcall(lib.requestModel, hash, Config.Spawn.ModelTimeoutMs) then
        Admin.Notify(_L('model_load'), 'error')
        return false
    end
    local ped = PlayerPedId()
    local h = GetEntityHeading(ped)
    local at = GetEntityCoords(ped) + GetEntityForwardVector(ped) * Config.Spawn.Distance
    if kind == 'horse' then
        local horse = CreatePed(hash, at.x, at.y, at.z, h, true, false, false, false)
        Citizen.InvokeNative(N.SET_RANDOM_OUTFIT_VARIATION, horse, true) -- without an outfit the horse is invisible
        SetPedOntoMount(ped, horse, -1, true)
    else
        local veh = CreateVehicle(hash, at.x, at.y, at.z, h, true, false, false, false)
        SetPedIntoVehicle(ped, veh, -1)
    end
    SetModelAsNoLongerNeeded(hash)
    return true
end

-- ---------------------------------------------------------------
-- tool table used by the NUI 'self' callback (client/main.lua)
-- each returns ok, closeMenu
-- ---------------------------------------------------------------

Admin.SelfTools = {
    noclip = function(d)
        local ok = toggleNoclip(d.on == true)
        return ok, ok and state.noclip
    end,
    god = function(d)
        local want = d.on == true
        if not allowed('god', { on = want }) then return false end
        state.god = want
        applyFlags()
        return true
    end,
    invisible = function(d)
        local want = d.on == true
        if not allowed('invisible', { on = want }) then return false end
        state.invisible = want
        applyFlags()
        return true
    end,
    waypoint = function()
        local ok = toWaypoint()
        return ok, ok
    end,
    coords = function()
        if not Admin.allowed.coords then return false end
        Admin.Send('coords', coordsNow())
        return true
    end,
    copy = function(d)
        if not Admin.allowed.coords then return false end
        local c = coordsNow()
        local text = (FORMATS[d.kind] or FORMATS.vector3):format(c.x, c.y, c.z, c.w)
        lib.setClipboard(text)
        Admin.Notify(_L('copied', text), 'success')
        return true
    end,
    heal = function() return allowed('selfheal', { revive = false }) end,
    revive = function() return allowed('selfheal', { revive = true }) end,
    spawn = function(d)
        local ok = spawn(d.kind == 'wagon' and 'wagon' or 'horse', d.model)
        return ok, ok
    end,
}

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if state.noclip then stopNoclip() end
    if state.god or state.invisible then
        local ped = PlayerPedId()
        SetEntityInvincible(ped, false)
        SetEntityVisible(ped, true)
    end
end)
