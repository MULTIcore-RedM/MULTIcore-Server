-- ============================================================
-- MULTIgathering :: fishing (client)
-- Drives the game's own rod fishing (the fishing task the rod starts) with a bait from the
-- satchel. The minigame steps - setting the bait, drawing fish to the hook, hooking, reeling,
-- keep or throw back - are based on rsg-fishing's client (RSG v2, GPL v3, Rexshack-RedM and
-- contributors, originally from FRP_Framework; see CREDITS.md). Struggle particles and the
-- weight display are left out (basic version).
-- When the player keeps a fish, the model and weight go to the server, which decides the item.
-- ============================================================

local N = {   -- natives (femga natives.json; the unnamed ones as rsg-fishing uses them)
    SET_FISHING_BAIT = 0x9B0C7FA063E67629,          -- _SET_FISHING_BAIT
    TASK_SWAP_FISHING_BAIT = 0x2C28AC30A72722DA,    -- TASK_SWAP_FISHING_BAIT
    PED_FISHINGROD_HOOK_ENTITY = 0x1A52076D26E09004, -- _PED_FISHINGROD_HOOK_ENTITY
    GET_ENTITIES_NEAR_POINT = 0x59B57C4B06531E1E,   -- _GET_ENTITIES_NEAR_POINT
    GET_PED_CURRENT_HELD_WEAPON = 0x8425C5F057012DAB, -- _GET_PED_CURRENT_HELD_WEAPON
    GET_FIRST_ENTITY_CARRIED = 0xD806CD2A4F2C2996,  -- _GET_FIRST_ENTITY_PED_IS_CARRYING
    FISH_HOOKED_A = 0xF0FBF193F1F5C0EA,             -- unnamed, called on the fish when it is hooked (rsg-fishing)
    FISH_HOOKED_B = 0x1F298C7BD30D1240,             -- unnamed, called on the player when a fish is hooked (rsg-fishing)
    SET_ACTIVE_GROUP = 0xC65A45D4453C2627,          -- _UI_PROMPT_SET_ACTIVE_GROUP_THIS_FRAME
}

local CTRL = {   -- controls as rsg-fishing reads them
    attack = joaat('INPUT_ATTACK'),
    aim = joaat('INPUT_AIM'),
    duck = joaat('INPUT_DUCK'),
    reel = joaat('INPUT_GAME_MENU_OPTION'),
    holster = joaat('INPUT_TOGGLE_HOLSTER'),
    reset = 0x8FFC75D6,
    steer = 0x390948DC,
    cast = 0x07CE1E61,
    reelLure = 0xDB096B85,
    reelIn = 0xFBD7B3E6,
}

local ROD = joaat(Config.Fishing.Rod:upper())
local F = Config.Fishing

local fishing = false      -- a baited cast is running
local castOpen = false     -- the server opened a cast that no fish has used yet
local bait, ready = nil, false
local data = {}            -- the fishing task struct f_0 .. f_27
local minigameOn = false
local fishWeightKg = 0.0
local fishForce, struggling, nextChange, steer = 0.6, false, 0, 0.0
local lureCooldown = 0

---------------------------------
-- the fishing task struct
---------------------------------
-- field k sits at byte 8k: 32-bit index 2k (Lua index 2k + 1)
local INT_FIELDS = { [0] = true, [5] = true, [6] = true, [7] = true, [10] = true, [11] = true, [12] = true, [16] = true, [18] = true, [19] = true }

local function readData()
    local r = exports[GetCurrentResourceName()]:GetFishingData()
    minigameOn = r[1] == true or r[1] == 1
    local ints, floats = r[2], r[3]
    data = {}
    for k = 0, 27 do
        local i = 2 * k + 1
        data['f_' .. k] = INT_FIELDS[k] and ints[i] or floats[i]
    end
end

local function get(k) return data['f_' .. k] end
local function set(k, v)
    data['f_' .. k] = v
    if data.f_0 ~= nil then exports[GetCurrentResourceName()]:SetFishingData(data) end
end

local function state() return get(0) end
local function lineDistance() return get(2) or 99.0 end
local function fishHandle() return get(7) end
local function transition(v) set(6, v) end

---------------------------------
-- prompts (display only: the controls are read directly, as in the game's minigame)
---------------------------------
local groups = {}

local function buildGroup(name, list)
    local g = GetRandomIntInRange(0, 0xffffff)
    local made = {}
    for _, p in ipairs(list) do
        local pr = UiPromptRegisterBegin()
        UiPromptSetControlAction(pr, p[1])
        UiPromptSetText(pr, CreateVarString(10, 'LITERAL_STRING', p[2]))
        UiPromptSetEnabled(pr, true)
        UiPromptSetVisible(pr, true)
        UiPromptSetGroup(pr, g, 0)
        UiPromptRegisterEnd(pr)
        made[#made + 1] = pr
    end
    groups[name] = { id = g, prompts = made }
end

local function showGroup(name, title)
    local g = groups[name]
    if g then Citizen.InvokeNative(N.SET_ACTIVE_GROUP, g.id, CreateVarString(10, 'LITERAL_STRING', title), 1) end
end

CreateThread(function()
    buildGroup('ready', { { CTRL.aim, _L('fish_prepare') }, { CTRL.cast, _L('fish_cast') } })
    buildGroup('waiting', { { CTRL.attack, _L('fish_hook') }, { CTRL.reset, _L('fish_reset') }, { CTRL.reelLure, _L('fish_reel_lure') } })
    buildGroup('hooked', { { CTRL.reelIn, _L('fish_reel_in') }, { CTRL.reset, _L('fish_reset') } })
    buildGroup('caught', { { CTRL.attack, _L('fish_keep') }, { CTRL.aim, _L('fish_throw') } })
end)

---------------------------------
-- fish near the hook
---------------------------------
local function nearbyFish(coords, radius)
    local out = {}
    local set_ = CreateItemset(true)
    local n = Citizen.InvokeNative(N.GET_ENTITIES_NEAR_POINT, coords.x, coords.y, coords.z, radius, set_, 1, Citizen.ResultAsInteger())
    for i = 0, (n or 0) - 1 do
        local e = GetIndexedItemInItemset(i, set_)
        -- population type 6 = ambient fish (rsg-fishing)
        if GetEntityPopulationType(e) == 6 and not IsPedDeadOrDying(e, false) then out[#out + 1] = e end
    end
    if IsItemsetValid(set_) then DestroyItemset(set_) end
    return out
end

local function interested(model)
    local set_ = MG.BaitSet[bait]
    return set_ ~= nil and set_[model & 0xFFFFFFFF] == true
end

local function randomWeightKg(model)
    local def = MG.FishDef(model)
    if not def then return 0.0 end
    return def.min + math.random() * (def.max - def.min)
end

local function setHooked(fish)
    set(7, fish)
    fishWeightKg = randomWeightKg(GetEntityModel(fish))
    set(8, fishWeightKg / F.WeightMultiplier)
    set(18, 2) -- rod weight
end

local function removeEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    NetworkRequestControlOfEntity(ent)
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
end

local function stopFishing()
    fishing = false
    Citizen.InvokeNative(N.SET_FISHING_BAIT, PlayerPedId(), '', 0, 1)
end

--- Reports a kept fish to the server (once per cast).
local function keepFish(model, kg)
    if not castOpen then return end
    castOpen = false
    lib.callback.await('MULTIgathering:fish:keep', false, model, kg)
end

---------------------------------
-- one cast
---------------------------------
local function fishLoop()
    local ped = PlayerPedId()
    while fishing do
        local sleep = 1000
        readData()
        local st = state()
        if st == 1 and not ready then
            ready = true
            Citizen.InvokeNative(N.TASK_SWAP_FISHING_BAIT, ped, bait, 0)
            Citizen.InvokeNative(N.SET_FISHING_BAIT, ped, bait, 0, 1)
        end
        if st == 1 then sleep = 0 showGroup('ready', _L('fish_ready')) end

        if minigameOn then
            sleep = 0
            if st == 2 then set(1, math.random(25, 30) + 0.0) end

            if st == 6 then
                showGroup('waiting', _L('fish_waiting'))
                if IsControlJustPressed(0, CTRL.reset) then transition(128) end
                local hook = get(12)
                local hookPos = GetEntityCoords(hook)
                if IsControlPressed(0, CTRL.duck) then
                    local p = GetEntityCoords(ped)
                    local to = hookPos + (p - hookPos) * F.ReelSpeed
                    SetEntityCoords(hook, to.x, to.y, to.z, false, false, false, false)
                end
                set(14, lineDistance() < 4.0 and 1.0 or 0.4)
                if lureCooldown <= GetGameTimer() then
                    local bobber = get(11)
                    local biter
                    for _, f in ipairs(nearbyFish(hookPos, F.LureRange)) do
                        if #(hookPos - GetEntityCoords(f)) <= F.HookRange then
                            biter = f
                        elseif interested(GetEntityModel(f)) then
                            TaskGoToEntity(f, bobber, 100, 1, 1.0, 2.0, 0)
                        end
                    end
                    lureCooldown = GetGameTimer() + 1000
                    if biter and interested(GetEntityModel(biter)) then
                        local r = math.random()
                        if (r > 0.9 or r < 0.2) and get(5) == 1 then
                            Citizen.InvokeNative(N.FISH_HOOKED_A, biter)
                            SetPedConfigFlag(biter, 17, true)
                            Citizen.InvokeNative(N.FISH_HOOKED_B, ped)
                            ClearPedTasksImmediately(biter, false, true)
                            TaskSetBlockingOfNonTemporaryEvents(biter, true)
                            Citizen.InvokeNative(N.PED_FISHINGROD_HOOK_ENTITY, ped, biter)
                            setHooked(biter)
                            fishForce = 0.6
                            transition(4)
                        end
                    end
                end
            end

            if st == 7 then
                showGroup('hooked', _L('fish_hooked'))
                if IsControlJustPressed(0, CTRL.reset) then transition(11) end
                local fish = fishHandle()
                local s = GetControlNormal(0, CTRL.steer)
                steer = math.max(0.0, math.min(1.0, steer - 0.05 * s))
                set(22, steer)
                if lineDistance() < 4.0 then transition(12) end
                set(14, 1.0)
                if GetGameTimer() >= nextChange then
                    if math.random() < F.StruggleChance then
                        struggling, fishForce = true, 0.6
                        nextChange = GetGameTimer() + math.random(1, 3) * 1000
                    else
                        struggling, fishForce = false, 0.0
                        nextChange = GetGameTimer() + math.random(2, 5) * 1000
                    end
                end
                if struggling then
                    if IsControlPressed(0, CTRL.reel) then set(18, 4) fishForce = fishForce + 0.005
                    else fishForce = fishForce - 0.005 end
                    if IsControlJustReleased(0, CTRL.reel) then set(18, 2) end
                    if fishForce >= 1.0 then transition(11) elseif fishForce < 0.6 then fishForce = 0.6 end
                    TaskSmartFleeCoord(fish, GetEntityCoords(ped), 40.0, 50, 8, 1077936128)
                else
                    if IsControlJustPressed(0, CTRL.reel) or (IsControlPressed(0, CTRL.reel) and GetGameTimer() % 25 == 0) then
                        set(18, 4)
                        TaskGoToEntity(fish, ped, F.Difficulty, 1.0, 1.5, 0.0, 0)
                    end
                    if IsControlJustReleased(0, CTRL.reel) then set(18, 2) end
                end
                if get(6) ~= 11 and get(6) ~= 12 then set(13, fishForce) set(21, fishForce) end
                if IsControlJustPressed(0, CTRL.attack) then set(23, 0.6) end
                if IsControlJustReleased(0, CTRL.attack) then set(23, 0.0) end
            end

            if st == 12 then
                local fish = fishHandle()
                local model = fish and fish ~= 0 and GetEntityModel(fish) or 0
                if MG.FishDef(model) then showGroup('caught', _L('fish_caught', fishWeightKg)) end
                if IsControlJustPressed(0, CTRL.attack) then
                    transition(32)
                    stopFishing()
                    keepFish(model, fishWeightKg)
                    SetTimeout(3000, function() removeEntity(fish) end)
                elseif IsControlJustPressed(0, CTRL.aim) then
                    transition(64)
                    stopFishing()
                    SetTimeout(3000, function() removeEntity(fish) end)
                elseif get(5) == 96 and get(6) == 0 then
                    stopFishing()
                    SetTimeout(3000, function() removeEntity(fish) end)
                end
            end

            if IsControlJustPressed(0, CTRL.holster) then
                transition(8)
                stopFishing()
            end
        end
        if fishing and Citizen.InvokeNative(N.GET_PED_CURRENT_HELD_WEAPON, ped, Citizen.ResultAsInteger()) & 0xFFFFFFFF ~= ROD & 0xFFFFFFFF and not minigameOn then
            stopFishing() -- the rod was put away
        end
        Wait(sleep)
    end
end

---------------------------------
-- bait used from the satchel
---------------------------------
RegisterNetEvent('MULTIgathering:client:bait', function(item)
    if not F.Enabled or not MG.IsOn('fishing') or type(item) ~= 'string' or not MG.IsBait[item] then return end
    if fishing then return MG.Notify(_L('already_fishing'), 'error') end
    local held = Citizen.InvokeNative(N.GET_PED_CURRENT_HELD_WEAPON, PlayerPedId(), Citizen.ResultAsInteger())
    if (held or 0) & 0xFFFFFFFF ~= ROD & 0xFFFFFFFF then return MG.Notify(_L('need_rod'), 'error') end
    local ok = lib.callback.await('MULTIgathering:fish:cast', false, item)
    if not ok then return end
    castOpen, bait, ready, fishing = true, item, false, true
    fishWeightKg, steer, nextChange = 0.0, 0.0, 0
    CreateThread(fishLoop)
end)

---------------------------------
-- a fish the game put in the player's hands
---------------------------------
CreateThread(function()
    while true do
        Wait(1000)
        if F.Enabled and MG.IsOn('fishing') then
            local ped = PlayerPedId()
            local held = Citizen.InvokeNative(N.GET_FIRST_ENTITY_CARRIED, ped, Citizen.ResultAsInteger())
            if held and held ~= 0 and DoesEntityExist(held) then
                local model = GetEntityModel(held)
                local def = MG.FishDef(model)
                if def then
                    -- a kept fish the minigame did not report yet still counts for the open cast
                    if castOpen then keepFish(model, def.min) end
                    if F.RemoveHeldFish then removeEntity(held) end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if fishing then stopFishing() end
    for _, g in pairs(groups) do for _, p in ipairs(g.prompts) do UiPromptDelete(p) end end
end)
