-- ============================================================
-- MULTIconsumables :: animations and hand props (client)
-- Only plays what the server asked for: the item was already taken on the server.
-- The animation code follows RSG v2's rsg-consume (GPL v3, see CREDITS.md).
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local busy = false

-- natives called by hash (names and hashes from femga natives.json)
local N = {
    SET_MATERIAL_FILL_LEVEL = 0x669655FFB29EF1A9,     -- _SET_MATERIAL_FILL_LEVEL_FOR_ENTITY (rsg-consume)
    SET_OBJECT_INTERACTION_PRESET = 0xCAAF2BCCFEF37F77, -- _SET_OBJECT_INTERACTION_PRESET (rsg-consume)
    SET_ITEM_INTERACTION_STATE = 0xB35370D5353995CB,  -- _SET_ITEM_INTERACTION_STATE (rsg-consume)
    GET_ITEM_INTERACTION_STATE = 0x6AA3DCA2C6F5EB6D,  -- GET_ITEM_INTERACTION_STATE (rsg-consume)
    TASK_ITEM_INTERACTION_2 = 0x72F52AA2D2B172CC,     -- _TASK_ITEM_INTERACTION_2 (rsg-consume calls it TaskItemInteraction_2)
    START_TASK_ITEM_INTERACTION = 0xAE72E7DF013AAA61, -- START_TASK_ITEM_INTERACTION (rsg-consume calls it TaskItemInteraction)
}
local NO_INTERACTION = -1318807663                    -- rsg-consume: state when no item interaction runs

local function cancelKey()
    local keys = RSGCore.Shared and RSGCore.Shared.Keybinds or {}
    return keys[Config.Use.CancelKey]
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not hash or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

local function loadDict(dict)
    if not dict or not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function makeProp(ped, model)
    local hash = loadModel(model)
    if not hash then return nil end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false, false, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function attachProp(ped, model, a)
    local obj = makeProp(ped, model)
    if not obj then return nil end
    local p, r = a.pos or { 0.0, 0.0, 0.0 }, a.rot or { 0.0, 0.0, 0.0 }
    AttachEntityToEntity(obj, ped, GetEntityBoneIndexByName(ped, a.bone or 'PH_R_HAND'),
        p[1] + 0.0, p[2] + 0.0, p[3] + 0.0, r[1] + 0.0, r[2] + 0.0, r[3] + 0.0, true, true, false, true, 1, true)
    return obj
end

local function playAnim(ped, dict, clip, flag, ms)
    if not loadDict(dict) then return false end
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, ms or -1, flag or 31, 0, false, false, false)
    RemoveAnimDict(dict)
    return true
end

local function deleteProp(obj)
    if obj and DoesEntityExist(obj) then
        DetachEntity(obj, true, true)
        DeleteObject(obj)
    end
end

--- Starts the animation for an item. → ms to run, list of props, kind
local function start(ped, def, a)
    local mounted = IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false)
    local props = {}
    local kind = a.kind
    if mounted then
        if not Config.Use.AllowOnMount or a.mounted == false or a.mounted == nil then return 0, props, 'none' end
        if a.mounted == 'interaction' then kind = 'interaction' end
    end
    local propModel = def.prop
    if propModel == nil then propModel = a.prop end

    if kind == 'anim' then
        if propModel then props[#props + 1] = attachProp(ped, propModel, a) end
        if a.enter then
            playAnim(ped, a.dict, a.enter, a.flag, a.enterMs)
            Wait(a.enterMs or 500)
        end
        playAnim(ped, a.dict, a.clip, a.flag, -1)
        return a.ms, props, kind

    elseif kind == 'interaction' then
        local it = a.interaction or {}
        if propModel then props[#props + 1] = attachProp(ped, propModel, a) end
        if it.gxt then
            -- rsg-consume Drink on a mount
            Citizen.InvokeNative(N.TASK_ITEM_INTERACTION_2, ped, it.gxt, props[1] or 0, joaat(it.propId), joaat(it.state), 1, 0, 0.0)
        else
            -- rsg-consume Eatcanned on a mount
            Citizen.InvokeNative(N.START_TASK_ITEM_INTERACTION, ped, 0, joaat(it.anim), 1, 0, 0.0)
        end
        return it.ms or a.ms, props, kind

    elseif kind == 'scenario' then
        TaskStartScenarioInPlace(ped, joaat(a.scenario), -1, true)
        return a.ms, props, kind

    elseif kind == 'stew' then
        -- rsg-consume Stew: the interaction clips are bound to these models
        local bowl, spoon = makeProp(ped, a.bowl), makeProp(ped, a.spoon)
        if not bowl or not spoon then deleteProp(bowl) deleteProp(spoon) return 0, props, 'none' end
        props[1], props[2] = bowl, spoon
        Citizen.InvokeNative(N.SET_MATERIAL_FILL_LEVEL, bowl, 0, 'Stew_Fill', 1.0)
        Citizen.InvokeNative(N.SET_OBJECT_INTERACTION_PRESET, bowl, 20)
        Citizen.InvokeNative(N.SET_OBJECT_INTERACTION_PRESET, spoon, 82)
        Citizen.InvokeNative(N.TASK_ITEM_INTERACTION_2, ped, 599184882, bowl, joaat('p_bowl04x_stew_ph_l_hand'), -583731576, 1, 0, 0.0)
        Citizen.InvokeNative(N.TASK_ITEM_INTERACTION_2, ped, 599184882, spoon, joaat('p_spoon01x_ph_r_hand'), -583731576, 1, 0, 0.0)
        Citizen.InvokeNative(N.SET_ITEM_INTERACTION_STATE, ped, -583731576, 1.0)
        return a.ms, props, kind

    elseif kind == 'coffee' then
        -- rsg-consume Hotdrinks
        local mug = makeProp(ped, a.mug)
        if not mug then return 0, props, 'none' end
        props[1] = mug
        Citizen.InvokeNative(N.SET_MATERIAL_FILL_LEVEL, mug, 0, 'CTRL_cupFill', 1.0)
        Citizen.InvokeNative(N.TASK_ITEM_INTERACTION_2, ped, joaat('CONSUMABLE_COFFEE'), mug, joaat('P_MUGCOFFEE01X_PH_R_HAND'), joaat('DRINK_COFFEE_HOLD'), 1, 0, -1.0)
        return a.ms, props, kind
    end
    return 0, props, 'none'
end

local function run(name, token, animKey)
    local def = Config.Consumables[name]
    local a = def and Config.Anims[animKey or def.anim]
    if busy or not def or not a then
        TriggerServerEvent('MULTIconsumables:server:finished', token, not busy)
        return
    end
    busy = true
    LocalPlayer.state:set('inv_busy', true, true)

    local ped = PlayerPedId()
    if Config.Use.Unarm then SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true) end
    local ok, ms, props, kind = pcall(start, ped, def, a)
    if not ok then
        print(('^1[MULTIconsumables] animation for %s failed: %s^7'):format(name, tostring(ms)))
        ms, props, kind = 0, {}, 'none'
    end

    local key = cancelKey()
    local cancelled = false
    local stopAt = GetGameTimer() + (ms or 0)
    local checkStew = GetGameTimer() + 500
    while GetGameTimer() < stopAt do
        Wait(0)
        if key and (IsControlJustPressed(0, key) or IsDisabledControlJustPressed(0, key)) then cancelled = true break end
        if IsEntityDead(ped) then cancelled = true break end
        if kind == 'stew' and GetGameTimer() > checkStew then
            -- rsg-consume: wait for the interaction to end instead of a fixed time
            local state = Citizen.InvokeNative(N.GET_ITEM_INTERACTION_STATE, ped)
            if not state or state == 0 or state == NO_INTERACTION then break end
            checkStew = GetGameTimer() + 250
        end
    end

    if kind ~= 'none' then ClearPedTasks(ped) end
    for _, obj in ipairs(props or {}) do deleteProp(obj) end
    LocalPlayer.state:set('inv_busy', false, true)
    busy = false
    TriggerServerEvent('MULTIconsumables:server:finished', token, not cancelled)
end

RegisterNetEvent('MULTIconsumables:client:use', function(name, token, animKey)
    if GetInvokingResource() then return end   -- only the server may start a use
    if animKey ~= nil and type(animKey) ~= 'string' then animKey = nil end
    CreateThread(function() run(name, token, animKey) end)
end)

-- canteens: is the player standing in a river or lake (on foot)?
lib.callback.register('MULTIconsumables:inWater', function()
    local ped = PlayerPedId()
    return IsEntityInWater(ped) and not IsPedOnMount(ped) and not IsPedInAnyVehicle(ped, false)
end)

-- core / health / stamina changes from the server (food, medicine, withdrawal)
local CORE = { HEALTH = 0, STAMINA = 1 }   -- eAttributeCore (natives.json comment)
local SET_CORE, GET_CORE = 0xC6258F41D86676E0, 0x36731AC041289BB1  -- _SET / _GET_ATTRIBUTE_CORE_VALUE
local CHANGE_STAMINA = 0xC3D4B754C0E86B9E                          -- _CHANGE_PED_STAMINA

local function addCore(ped, core, delta)
    local cur = Citizen.InvokeNative(GET_CORE, ped, core, Citizen.ResultAsInteger()) or 0
    local v = math.floor(math.max(0, math.min(100, cur + delta)))
    Citizen.InvokeNative(SET_CORE, ped, core, v)
end

RegisterNetEvent('MULTIconsumables:client:effects', function(e)
    if GetInvokingResource() or type(e) ~= 'table' then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    if e.health and e.health ~= 0 then
        local max = GetEntityMaxHealth(ped, false)
        local v = math.floor(math.max(1, math.min(max, GetEntityHealth(ped) + e.health)))
        SetEntityHealth(ped, v, 0)
    end
    if e.healthCore and e.healthCore ~= 0 then addCore(ped, CORE.HEALTH, e.healthCore) end
    if e.staminaCore and e.staminaCore ~= 0 then addCore(ped, CORE.STAMINA, e.staminaCore) end
    if e.stamina and e.stamina ~= 0 then Citizen.InvokeNative(CHANGE_STAMINA, ped, e.stamina + 0.0) end
end)
