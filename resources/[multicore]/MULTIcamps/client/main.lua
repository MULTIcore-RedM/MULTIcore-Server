-- ============================================================
-- MULTIcamps :: client
-- The placement preview (see-through camp in front of the player: turn,
-- push / pull, snapped to the ground, confirm / cancel), the camp props
-- near the player (made and removed by distance; the server holds the
-- truth), the camp prompt and its ox_lib menu, and resting in the tent.
-- The client never changes items or camps: it asks the server
-- (lib.callback) and shows the answer.
-- The preview follows the idea of RSG v2's rsg-goldclaim prop placer
-- (GPL v3, see CREDITS.md); the code is MULTIcore's own.
-- GPL v3, part of MULTIcore.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

-- natives (femga natives.json)
local TASK_START_SCENARIO_IN_PLACE_HASH = 0x524B54361229154F
local SET_ATTRIBUTE_CORE_VALUE = 0xC6258F41D86676E0   -- _SET_ATTRIBUTE_CORE_VALUE (ped, core, value)
local GET_ATTRIBUTE_CORE_VALUE = 0x36731AC041289BB1   -- _GET_ATTRIBUTE_CORE_VALUE (ped, core)
local ADD_TO_CLOCK_TIME = 0xAB7C251C7701D336          -- ADD_TO_CLOCK_TIME (hours, minutes, seconds)
local PROMPT_SET_ACTIVE_GROUP = 0xC65A45D4453C2627    -- UiPromptSetActiveGroupThisFrame
local WEAPON_UNARMED = 0xA2719263                     -- Unarmed, redm-info Weapons.cs
local CORE_HEALTH, CORE_STAMINA = 0, 1
local CORE_MAX = 100
local DESPAWN_MARGIN = 10.0     -- metres beyond StreamDistance before props are removed (no flicker at the edge)
local GROUND_PROBE = 3.0        -- metres above a point the ground search starts

local camps = {}                -- [id] = { data = public camp, props = { [part] = entity }, fireLit }
local placing, busy = false, false
local interactMode = nil       -- 'target' or 'prompt' once MCI.Run has decided (@MULTIcore/lib/interact.lua)
local openMenu                  -- forward (the camp menu, further down)

local function notify(text, kind)
    exports.MULTIcore:Notify({ text = text, title = _L('title'), type = kind or 'info' })
end

local function ped() return PlayerPedId() end

local function canAct()
    if IsPauseMenuActive() then return false end
    local p = ped()
    if IsEntityDead(p) or IsPedDeadOrDying(p, true) then return false end
    if LocalPlayer.state.isLoggedIn == false then return false end
    return true
end

local function loadModel(name)
    local hash = joaat(name)
    if not IsModelValid(hash) then
        print(('^1[MULTIcamps] model %s is not valid^7'):format(name))
        return nil
    end
    RequestModel(hash, false)
    local deadline = GetGameTimer() + Config.ModelLoadTimeoutMs
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return nil end
        Wait(10)
    end
    return hash
end

local function groundZ(x, y, z)
    local found, gz = GetGroundZFor_3dCoord(x, y, z + GROUND_PROBE, false)
    if found then return gz end
    return z
end

-- same sums as the server's Camps.PartCoords
local function partCoords(base, heading, part)
    local def = Config.Props[part]
    local off = def and def.offset or vector3(0.0, 0.0, 0.0)
    local h = math.rad(heading)
    local fx, fy = -math.sin(h), math.cos(h)
    local rx, ry = math.cos(h), math.sin(h)
    return vector3(base.x + rx * off.x + fx * off.y, base.y + ry * off.x + fy * off.y, base.z + off.z),
        (heading + (def and def.heading or 0.0)) % 360.0
end

local function campParts(lit)
    local list = { 'tent', 'bedroll', lit and 'fire' or 'fireOut', 'chest' }
    if Config.HitchingPost then list[#list + 1] = 'hitch' end
    return list
end

local function deleteEntity(e)
    if e and DoesEntityExist(e) then
        SetEntityAsMissionEntity(e, true, true)
        DeleteObject(e)
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
end

-- ---------------------------------------------------------------
-- camp props (local objects on each client)
-- ---------------------------------------------------------------
local function makeProp(part, base, heading, alpha)
    local def = Config.Props[part]
    if not def then return nil end
    local hash = loadModel(def.model)
    if not hash then return nil end
    local pos, h = partCoords(base, heading, part)
    local obj = CreateObject(hash, pos.x, pos.y, groundZ(pos.x, pos.y, pos.z), false, false, false)
    SetEntityHeading(obj, h)
    PlaceObjectOnGroundProperly(obj, false)
    FreezeEntityPosition(obj, true)
    if alpha then
        SetEntityAlpha(obj, alpha, false)
        SetEntityCollision(obj, false, false)
    end
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local TARGET_PARTS = { 'tent', 'bedroll', 'fire', 'fireOut', 'chest' }

-- MULTItarget "Camp" on the tent, bedroll, fire and chest (target mode)
local function campOption(id)
    return {
        name = 'multicamps_camp',
        label = _L('prompt_camp'),
        icon = Config.TargetIcon,
        distance = Config.TargetDistance,
        canInteract = function() return not placing and not busy end,
        onSelect = function() if canAct() then CreateThread(function() openMenu(id) end) end end,
    }
end

local function untargetCamp(c)
    for part, e in pairs(c.targeted or {}) do MCI.RemoveEntity(e) end
    c.targeted = nil
end

local function targetCamp(c)
    if interactMode ~= 'target' or not c.props then return end
    c.targeted = c.targeted or {}
    for _, part in ipairs(TARGET_PARTS) do
        local e = c.props[part]
        if e and c.targeted[part] ~= e then
            if c.targeted[part] then MCI.RemoveEntity(c.targeted[part]) end
            c.targeted[part] = MCI.AddEntity(e, { campOption(c.data.id) }) and e or nil
        end
    end
end

local function despawnCamp(c)
    untargetCamp(c)
    for part, e in pairs(c.props or {}) do
        deleteEntity(e)
        c.props[part] = nil
    end
    c.props = nil
end

local function spawnCamp(c)
    c.props = {}
    local d = c.data
    local base = vector3(d.x, d.y, d.z)
    for _, part in ipairs(campParts(d.lit)) do
        c.props[part] = makeProp(part, base, d.heading)
    end
    c.fireLit = d.lit
    targetCamp(c)
end

-- swaps the burning and the cold fire
local function refreshFire(c)
    if not c.props or c.fireLit == c.data.lit then return end
    deleteEntity(c.props.fire)
    deleteEntity(c.props.fireOut)
    if c.targeted then
        MCI.RemoveEntity(c.targeted.fire) MCI.RemoveEntity(c.targeted.fireOut)
        c.targeted.fire, c.targeted.fireOut = nil, nil
    end
    c.props.fire, c.props.fireOut = nil, nil
    local part = c.data.lit and 'fire' or 'fireOut'
    c.props[part] = makeProp(part, vector3(c.data.x, c.data.y, c.data.z), c.data.heading)
    targetCamp(c)
    c.fireLit = c.data.lit
end

local function setCamp(data)
    if type(data) ~= 'table' or not data.id then return end
    local c = camps[data.id]
    if c then
        local moved = c.data.x ~= data.x or c.data.y ~= data.y or c.data.heading ~= data.heading
        c.data = data
        if moved and c.props then despawnCamp(c) else refreshFire(c) end
    else
        camps[data.id] = { data = data }
    end
end

local function loadAll()
    local list = lib.callback.await('MULTIcamps:list', false) or {}
    local seen = {}
    for _, d in ipairs(list) do
        setCamp(d)
        seen[d.id] = true
    end
    for id, c in pairs(camps) do
        if not seen[id] then
            despawnCamp(c)
            camps[id] = nil
        end
    end
end

RegisterNetEvent('MULTIcamps:client:upsert', function(data) setCamp(data) end)
RegisterNetEvent('MULTIcamps:client:remove', function(id)
    local c = camps[id]
    if c then
        despawnCamp(c)
        camps[id] = nil
    end
end)
RegisterNetEvent('MULTIcamps:client:reload', function() loadAll() end)
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() loadAll() end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end
    loadAll()
    while true do
        local pos = GetEntityCoords(ped())
        for _, c in pairs(camps) do
            local d = #(vector2(pos.x, pos.y) - vector2(c.data.x, c.data.y))
            if d <= Config.StreamDistance and not c.props then
                spawnCamp(c)
            elseif d > Config.StreamDistance + DESPAWN_MARGIN and c.props then
                despawnCamp(c)
            end
        end
        Wait(Config.StreamCheckMs)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, c in pairs(camps) do despawnCamp(c) end
end)

-- ---------------------------------------------------------------
-- placement preview
-- ---------------------------------------------------------------

--- Why a camp may not stand here (client side; the server checks towns, other camps and distance again). → nil | key, arg
local function placeProblem(pos)
    for _, z in ipairs(Config.NoCampZones or {}) do
        local dx, dy = pos.x - z.x, pos.y - z.y
        if dx * dx + dy * dy <= z.radius * z.radius then return 'err_in_town', z.name end
    end
    for _, c in pairs(camps) do
        if #(vector2(pos.x, pos.y) - vector2(c.data.x, c.data.y)) < Config.MinCampDistance then return 'err_near_camp' end
    end
    if Config.MinRoadDistance > 0 then
        local found, node = GetClosestVehicleNode(pos.x, pos.y, pos.z, 1, 3.0, 0.0)
        if found and node and #(vector2(pos.x, pos.y) - vector2(node.x, node.y)) < Config.MinRoadDistance then
            return 'err_near_road'
        end
    end
    local ok, _, normal = GetGroundZAndNormalFor_3dCoord(pos.x, pos.y, pos.z + GROUND_PROBE)
    if ok and normal and normal.z < Config.MaxSlope then return 'err_slope' end
    if IsEntityInWater(ped()) then return 'err_water' end
    return nil
end

local function makePrompt(key, text, group, hold)
    local p = UiPromptRegisterBegin()
    UiPromptSetControlAction(p, key)
    UiPromptSetText(p, CreateVarString(10, 'LITERAL_STRING', text))
    UiPromptSetEnabled(p, true)
    UiPromptSetVisible(p, true)
    if hold then UiPromptSetHoldMode(p, hold) else UiPromptSetStandardMode(p, true) end
    UiPromptSetGroup(p, group, 0)
    UiPromptRegisterEnd(p)
    return p
end

local function playScenario(name)
    Citizen.InvokeNative(TASK_START_SCENARIO_IN_PLACE_HASH, ped(), joaat(name), -1, true, 0, -1.0, false)
end

--- Plays the pitching / packing scenario; false if the player moved away or died.
local function work(ms)
    local p = ped()
    local start = GetEntityCoords(p)
    playScenario(Config.PitchScenario)
    local stopAt = GetGameTimer() + ms
    local ok = true
    while GetGameTimer() < stopAt do
        Wait(200)
        if not canAct() or #(GetEntityCoords(ped()) - start) > 2.0 then ok = false break end
    end
    ClearPedTasks(ped())
    return ok
end

local function startPlacement()
    if placing or busy or not canAct() then return end
    local p = ped()
    if IsPedOnMount(p) or IsPedInAnyVehicle(p, false) or IsEntityInWater(p) then
        return notify(_L('err_place_here'), 'error')
    end
    placing = true
    -- empty hands, so the confirm / cancel buttons (attack / aim) do not fire or aim a weapon
    SetCurrentPedWeapon(p, WEAPON_UNARMED, true)
    local K = Config.Preview.Keys
    local group = GetRandomIntInRange(0, 0xffffff)
    local prompts = {
        makePrompt(K.Confirm, _L('preview_confirm'), group, 1000),
        makePrompt(K.Cancel, _L('preview_cancel'), group, nil),
        makePrompt(K.RotateLeft, _L('preview_rotate_left'), group, nil),
        makePrompt(K.RotateRight, _L('preview_rotate_right'), group, nil),
        makePrompt(K.Further, _L('preview_further'), group, nil),
        makePrompt(K.Closer, _L('preview_closer'), group, nil),
    }
    local confirmPrompt = prompts[1]

    local ghosts = {}
    local heading = GetEntityHeading(p)
    local ahead = Config.Preview.StartAhead
    local origin = GetEntityCoords(p)
    for _, part in ipairs(campParts(true)) do ghosts[part] = makeProp(part, origin, heading, Config.Preview.Alpha) end

    local result, base = nil, nil
    local problem, problemArg, nextCheck = nil, nil, 0
    while placing do
        Wait(0)
        p = ped()
        if not canAct() or IsPedOnMount(p) or IsPedInAnyVehicle(p, false) then result = 'cancel' break end

        if IsControlPressed(0, K.RotateLeft) then heading = heading + Config.Preview.RotateStep end
        if IsControlPressed(0, K.RotateRight) then heading = heading - Config.Preview.RotateStep end
        if IsControlPressed(0, K.Further) then ahead = math.min(Config.Preview.MaxAhead, ahead + Config.Preview.MoveStep) end
        if IsControlPressed(0, K.Closer) then ahead = math.max(Config.Preview.MinAhead, ahead - Config.Preview.MoveStep) end
        heading = heading % 360.0

        local pp = GetEntityCoords(p)
        local spot = pp + GetEntityForwardVector(p) * ahead
        base = vector3(spot.x, spot.y, groundZ(spot.x, spot.y, spot.z))
        for part, e in pairs(ghosts) do
            if e and DoesEntityExist(e) then
                local c, h = partCoords(base, heading, part)
                SetEntityCoordsNoOffset(e, c.x, c.y, groundZ(c.x, c.y, c.z), false, false, false)
                SetEntityHeading(e, h)
                PlaceObjectOnGroundProperly(e, false)
            end
        end

        if GetGameTimer() >= nextCheck then
            nextCheck = GetGameTimer() + 250
            problem, problemArg = placeProblem(base)
            UiPromptSetEnabled(confirmPrompt, problem == nil)
        end
        local label = problem and _L(problem, problemArg) or _L('preview_title')
        Citizen.InvokeNative(PROMPT_SET_ACTIVE_GROUP, group, CreateVarString(10, 'LITERAL_STRING', label), 1)

        if IsControlJustPressed(0, K.Cancel) then result = 'cancel' break end
        if problem == nil and UiPromptHasHoldModeCompleted(confirmPrompt) then result = 'place' break end
    end

    for _, e in pairs(ghosts) do deleteEntity(e) end
    for _, pr in ipairs(prompts) do UiPromptDelete(pr) end
    placing = false
    if result ~= 'place' then return notify(_L('place_cancelled'), 'info') end

    busy = true
    local done = work(Config.PitchMs)
    if done then
        local res = lib.callback.await('MULTIcamps:place', false, { x = base.x, y = base.y, z = base.z }, heading)
        if res and res.ok then loadAll() end
    else
        notify(_L('place_cancelled'), 'info')
    end
    busy = false
end

RegisterNetEvent('MULTIcamps:client:startPlace', function() CreateThread(startPlacement) end)

-- ---------------------------------------------------------------
-- resting
-- ---------------------------------------------------------------
local function rest(id)
    local res = lib.callback.await('MULTIcamps:rest', false, id)
    if not res or not res.ok then return end
    busy = true
    DoScreenFadeOut(1000)
    Wait(1000)
    playScenario(Config.Sleep.Scenario)
    DoScreenFadeIn(1000)
    local stopAt = GetGameTimer() + Config.Sleep.Ms
    while GetGameTimer() < stopAt and canAct() do Wait(250) end
    local b = res.bonus
    if b then
        local p = ped()
        local hv = Citizen.InvokeNative(GET_ATTRIBUTE_CORE_VALUE, p, CORE_HEALTH) or 0
        local sv = Citizen.InvokeNative(GET_ATTRIBUTE_CORE_VALUE, p, CORE_STAMINA) or 0
        Citizen.InvokeNative(SET_ATTRIBUTE_CORE_VALUE, p, CORE_HEALTH, math.min(CORE_MAX, hv + (b.health or 0)))
        Citizen.InvokeNative(SET_ATTRIBUTE_CORE_VALUE, p, CORE_STAMINA, math.min(CORE_MAX, sv + (b.stamina or 0)))
        if (b.skipHours or 0) > 0 then Citizen.InvokeNative(ADD_TO_CLOCK_TIME, math.floor(b.skipHours), 0, 0) end
        notify(_L('rest_done'), 'success')
    end
    ClearPedTasks(ped())
    busy = false
end

-- ---------------------------------------------------------------
-- the camp menu
-- ---------------------------------------------------------------
openMenu = function(id)
    local info = lib.callback.await('MULTIcamps:info', false, id)
    if not info or not info.ok then return notify(_L('err_' .. tostring(info and info.err or 'error')), 'error') end
    local opts = {}
    if info.canUse then
        opts[#opts + 1] = {
            title = _L('menu_storage'), icon = 'box-open',
            onSelect = function() lib.callback.await('MULTIcamps:storage', false, id) end,
        }
        if info.sleep then
            opts[#opts + 1] = { title = _L('menu_rest'), description = _L('menu_rest_desc'), icon = 'bed', onSelect = function() rest(id) end }
        end
        opts[#opts + 1] = {
            title = info.lit and _L('menu_fire_out') or _L('menu_fire_light'), icon = 'fire',
            onSelect = function()
                if work(Config.PitchMs // 4) then lib.callback.await('MULTIcamps:fire', false, id, not info.lit) end
            end,
        }
        if info.cook and info.lit then
            opts[#opts + 1] = { title = _L('menu_cook'), icon = 'utensils', onSelect = function() lib.callback.await('MULTIcamps:cook', false, id) end }
        end
    end
    if info.owner then
        if info.sharing then
            opts[#opts + 1] = {
                title = info.shared and _L('menu_share_off') or _L('menu_share_on'),
                description = _L('menu_share_desc'), icon = 'users',
                onSelect = function() lib.callback.await('MULTIcamps:share', false, id, not info.shared) end,
            }
        end
        opts[#opts + 1] = {
            title = _L('menu_pack'), description = _L('menu_pack_desc'), icon = 'campground',
            onSelect = function()
                local a = lib.alertDialog({ header = _L('menu_pack'), content = _L('pack_confirm'), centered = true, cancel = true,
                    labels = { confirm = _L('yes'), cancel = _L('no') } })
                if a ~= 'confirm' then return end
                busy = true
                if work(Config.PitchMs) then lib.callback.await('MULTIcamps:pack', false, id) end
                busy = false
            end,
        }
    end
    if #opts == 0 then
        opts[#opts + 1] = { title = _L('menu_not_yours'), disabled = true }
    end
    lib.registerContext({
        id = 'multicamps_menu',
        title = info.owner and _L('menu_title_own') or _L('menu_title_other', info.ownerName or ''),
        options = opts,
    })
    lib.showContext('multicamps_menu')
end

-- MULTItarget on the camp props, or the hold-key camp prompt below; built again if MULTItarget starts or stops
MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    if mode == 'target' then
        for _, c in pairs(camps) do targetCamp(c) end
    else
        MCI.Count('prompts', 1)
    end
end, function(mode)
    for _, c in pairs(camps) do untargetCamp(c) end
    if mode == 'prompt' then MCI.Count('prompts', -1) end
    interactMode = nil
end)

-- the camp a player stands at: within UseDistance of its tent, bedroll, fire or chest
local function campHere(pos)
    local best, bestD
    for id, c in pairs(camps) do
        if c.props then
            local base = vector3(c.data.x, c.data.y, c.data.z)
            for _, part in ipairs({ 'tent', 'bedroll', 'fire', 'chest' }) do
                local pc = partCoords(base, c.data.heading, part)
                local d = #(vector2(pos.x, pos.y) - vector2(pc.x, pc.y))
                if d <= Config.UseDistance and math.abs(pos.z - pc.z) < Config.UseDistance + GROUND_PROBE and (not bestD or d < bestD) then
                    best, bestD = id, d
                end
            end
        end
    end
    return best
end

CreateThread(function()
    local prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, MCI.Key(Config.PromptKey))
    UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', _L('prompt_camp')))
    UiPromptSetEnabled(prompt, false)
    UiPromptSetVisible(prompt, false)
    UiPromptSetHoldMode(prompt, 1000)
    UiPromptRegisterEnd(prompt)
    AddEventHandler('onResourceStop', function(name)
        if name == GetCurrentResourceName() then UiPromptDelete(prompt) end
    end)

    local here, nextScan = nil, 0
    while true do
        local now = GetGameTimer()
        if now >= nextScan then
            nextScan = now + 500
            local p = ped()
            here = nil
            if not placing and not busy and not IsPedOnMount(p) and not IsPedInAnyVehicle(p, false) then
                if interactMode == 'prompt' then here = campHere(GetEntityCoords(p)) end
            end
            UiPromptSetEnabled(prompt, here ~= nil)
            UiPromptSetVisible(prompt, here ~= nil)
        end
        if here then
            if UiPromptHasHoldModeCompleted(prompt) and canAct() then
                local id = here
                UiPromptSetEnabled(prompt, false)
                openMenu(id)
                Wait(1000)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
