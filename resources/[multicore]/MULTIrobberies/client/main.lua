-- ============================================================
-- MULTIrobberies :: client
-- Draws the robbery steps; the server decides every one of them (server/main.lua).
--   Tills: MULTItarget on every cash register prop (or a hold prompt at the nearest one):
--          pick the lock (skill check), then empty the till.
--   Banks: the gate is picked with MULTIdoors. At the vault door: set a pipe charge, the
--          fuse burns, the blast swings the vault door open. Then each safe is cracked
--          (skill check) and emptied.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

-- natives (femga natives.json)
local N = {
    SCENARIO_IN_PLACE_HASH = 0x524B54361229154F, -- TASK_START_SCENARIO_IN_PLACE_HASH (ped, hash, duration, playEnter, conditional, heading, p6)
    DOOR_SET_OPEN_RATIO    = 0xB6E6FBA95C7324AC, -- DOOR_SYSTEM_SET_OPEN_RATIO (doorHash, ajar, forceUpdate)
    ADD_EXPLOSION          = 0x7D6F58F69DA92530, -- ADD_EXPLOSION (x, y, z, type, damageScale, isAudible, isInvisible, cameraShake)
    BLIP_ADD_FOR_COORDS    = 0x554D9D53F696D002, -- (style, x, y, z) -> blip
    SET_BLIP_SPRITE        = 0x74F74D3207ED525C, -- (blip, hash, BOOL)
    SET_BLIP_NAME          = 0x9CB1A1623062F402, -- _SET_BLIP_NAME (blip, name)
}
local CROUCH = 'WORLD_HUMAN_CROUCH_INSPECT'      -- redm-info Scenarios.lua

local Banks = {}            -- [id] = { id, label, safes, vault = { coords, doors }, gates, spots }
local built = {}            -- [bank id] = { zones = {}, prompts = {}, spots = { { coords, index? } } }
local busy = false
local mode = nil            -- 'target' | 'prompt'
local charges = {}          -- [bank id] = prop entity while the fuse burns
local alerts = {}

---------------------------------
-- helpers
---------------------------------
local function notify(text, kind)
    exports.MULTIcore:Notify({ text = text, type = kind or 'info', duration = Config.NotifyDuration })
end

local function errText(key) return _L(type(key) == 'string' and key or 'err_generic') end

local function vec(c) return vector3((c.x or c[1]) + 0.0, (c.y or c[2]) + 0.0, (c.z or c[3]) + 0.0) end

local function ped() return PlayerPedId() end

local function state(id)
    local s = GlobalState.multirobberies
    return type(s) == 'table' and s[id] or nil
end

local function looted(id, index)
    local s = state(id)
    for _, i in ipairs(s and s.looted or {}) do if i == index then return true end end
    return false
end

local function face(coords)
    local p = GetEntityCoords(ped())
    SetEntityHeading(ped(), GetHeadingFromVector_2d(coords.x - p.x, coords.y - p.y))
end

local function loadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

--- loops an animation (the till animation: script_common@jail_cell@unlock@key / action)
local function playAnim(a)
    if a and loadDict(a.dict) then
        TaskPlayAnim(ped(), a.dict, a.clip, 8.0, -8.0, -1, 1, 0, false, 0, false, 0, false)
    end
end

local function crouch()
    Citizen.InvokeNative(N.SCENARIO_IN_PLACE_HASH, ped(), joaat(CROUCH), -1, true, 0, GetEntityHeading(ped()), false)
end

local function canAct()
    local p = ped()
    return not busy and not IsEntityDead(p) and not IsPedOnMount(p) and not IsPedInAnyVehicle(p, false)
end

local function progress(ms, text)
    return lib.progressBar({
        duration = ms, label = text, useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
end

---------------------------------
-- tills
---------------------------------
local function robTill(entity)
    if not canAct() or not entity or not DoesEntityExist(entity) then return end
    local R = Config.Registers
    local coords = GetEntityCoords(entity)
    busy = true
    local ok, token = lib.callback.await('multirobberies:till:start', false, coords)
    if not ok then notify(errText(token), 'error') busy = false return end
    face(coords)
    playAnim(R.Anim)
    local passed = MGLockpick(R.Lockpick, _L('till_label'))
    local opened, err = lib.callback.await('multirobberies:till:pick', false, token, passed == true)
    if not opened then
        ClearPedTasks(ped())
        notify(errText(err), 'error')
        busy = false
        return
    end
    if progress(R.EmptyMs, _L('till_progress')) then
        lib.callback.await('multirobberies:till:finish', false, token)
    else
        TriggerServerEvent('MULTIrobberies:server:cancel')
    end
    ClearPedTasks(ped())
    busy = false
end

local tillTargets = false
local tillPrompt = nil      -- entity the prompt is on

local function tillOption()
    return {
        name = 'multirobberies_till', label = _L('till_label'), icon = 'fa-solid fa-cash-register',
        distance = Config.Registers.Distance,
        canInteract = function() return canAct() end,
        onSelect = function(data) robTill(data and data.entity) end,
    }
end

local function addTills()
    if not Config.Registers.Enabled then return end
    if mode == 'target' then
        local ok = pcall(function() exports.MULTItarget:addModel(Config.Registers.Models, { tillOption() }) end)
        if ok then tillTargets = true MCI.Count('targets', 1) end
    end
end

local function removeTills()
    if tillTargets then
        pcall(function() exports.MULTItarget:removeModel(Config.Registers.Models, { 'multirobberies_till' }) end)
        MCI.Count('targets', -1)
        tillTargets = false
    end
    if tillPrompt then MCI.RemovePrompt('multirobberies_till') tillPrompt = nil end
end

local tillHashes = {}
for _, m in ipairs(Config.Registers.Models or {}) do tillHashes[#tillHashes + 1] = joaat(m) end

-- prompt mode: one hold prompt on the nearest till
CreateThread(function()
    while true do
        Wait(1000)
        if mode == 'prompt' and Config.Registers.Enabled then
            local pos = GetEntityCoords(ped())
            local found
            for _, h in ipairs(tillHashes) do
                local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, 3.0, h, false, false, false)
                if obj and obj ~= 0 then found = obj break end
            end
            if found ~= tillPrompt then
                if tillPrompt then MCI.RemovePrompt('multirobberies_till') end
                tillPrompt = found
                if found then
                    MCI.AddPrompt('multirobberies_till', GetEntityCoords(found), Config.PromptKey, _L('till_label'),
                        { type = 'client', event = 'MULTIrobberies:client:tillPrompt', args = { found } }, Config.Registers.Distance)
                end
            end
        end
    end
end)

AddEventHandler('MULTIrobberies:client:tillPrompt', function(entity) robTill(entity) end)

---------------------------------
-- banks: the vault door
---------------------------------
local function doorList(b)
    local d = b and b.vault and b.vault.doors
    if type(d) == 'number' then return { d } end
    return type(d) == 'table' and d or {}
end

local function swingVault(id, open)
    local b = Banks[id]
    for _, h in ipairs(doorList(b)) do
        pcall(function() Citizen.InvokeNative(N.DOOR_SET_OPEN_RATIO, h, open and 1.0 or 0.0, true) end)
    end
end

RegisterNetEvent('MULTIrobberies:client:vault', function(id, open)
    swingVault(id, open)
    if not open then
        local c = charges[id]
        if c and DoesEntityExist(c) then DeleteEntity(c) end
        charges[id] = nil
    end
end)

local function plant(id)
    local b = Banks[id]
    if not b or not canAct() then return end
    busy = true
    local ok, token = lib.callback.await('multirobberies:bank:plantStart', false, id)
    if not ok then notify(errText(token), 'error') busy = false return end
    face(b.vault.coords)
    crouch()
    local done = progress(Config.Bank.PlantMs, _L('bank_planting'))
    ClearPedTasks(ped())
    local set, fuse = lib.callback.await('multirobberies:bank:plantEnd', false, token, done == true)
    if set then notify(_L('bank_planted', fuse), 'success')
    elseif fuse then notify(errText(fuse), 'error') end
    busy = false
end

RegisterNetEvent('MULTIrobberies:client:fuse', function(id, seconds, owner)
    local b = Banks[id]
    if not b then return end
    local c = b.vault.coords
    local me = GetPlayerServerId(PlayerId())
    -- the charge sits at the foot of the vault door while the fuse burns
    local model = joaat(Config.Bank.ChargeProp)
    if IsModelValid(model) then
        RequestModel(model)
        local t = GetGameTimer() + 3000
        while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
        if HasModelLoaded(model) then
            local obj = CreateObject(model, c.x, c.y, c.z - 0.9, false, false, false)
            PlaceObjectOnGroundProperly(obj)
            FreezeEntityPosition(obj, true)
            charges[id] = obj
            SetModelAsNoLongerNeeded(model)
        end
    end
    if #(GetEntityCoords(ped()) - c) < 40.0 then notify(_L('bank_fuse', seconds), 'error') end
    SetTimeout(seconds * 1000, function()
        local obj = charges[id]
        local at = (obj and DoesEntityExist(obj)) and GetEntityCoords(obj) or c
        if owner == me then
            Citizen.InvokeNative(N.ADD_EXPLOSION, at.x, at.y, at.z, Config.Bank.ExplosionType, Config.Bank.ExplosionDamage + 0.0,
                true, false, Config.Bank.CameraShake + 0.0)
        end
        if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
        charges[id] = nil
    end)
end)

---------------------------------
-- banks: the safes
---------------------------------
local safeModels = {}
for _, m in ipairs(Config.Bank.SafeModels or {}) do safeModels[#safeModels + 1] = joaat(m) end

--- Safe props the game placed around the vault door.
local function scanSafes(b)
    local out, seen = {}, {}
    local c = b.vault.coords
    local r = Config.Bank.SafeScanRadius or 9.0
    local function add(obj)
        if not obj or obj == 0 or seen[obj] then return end
        seen[obj] = true
        local p = GetEntityCoords(obj)
        if #(p - c) <= r then
            -- a prop's position is its foot: the point goes to the middle of the safe's front
            local mn, mx = GetModelDimensions(GetEntityModel(obj))
            local mid = GetOffsetFromEntityInWorldCoords(obj, (mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
            out[#out + 1] = mid
        end
    end
    local ok, pool = pcall(GetGamePool, 'CObject')
    if ok and type(pool) == 'table' then
        local want = {}
        for _, h in ipairs(safeModels) do want[h] = true end
        for _, obj in ipairs(pool) do
            if want[GetEntityModel(obj)] then add(obj) end
        end
    end
    for _, h in ipairs(safeModels) do add(GetClosestObjectOfType(c.x, c.y, c.z, r, h, false, false, false)) end
    table.sort(out, function(a, b2) return #(a - c) < #(b2 - c) end)
    return out
end

--- Where the safes of bank `b` are: spots set with /robsafe, else props by the vault, else
--- one spot just inside the vault door (each search there empties the next safe).
local function safeSpots(b)
    local list = {}
    if #(b.spots or {}) > 0 then
        for i, s in ipairs(b.spots) do list[#list + 1] = { coords = vec(s), index = i } end
        return list
    end
    local found = scanSafes(b)
    for i = 1, math.min(#found, b.safes or 4) do list[#list + 1] = { coords = found[i], index = i } end
    if #list > 0 then return list end
    local c = b.vault.coords
    local dir = vector3(0.0, 0.0, 0.0)
    if b.gates then
        local g = vec(b.gates)
        dir = vector3(c.x - g.x, c.y - g.y, 0.0)
        local len = #dir
        dir = len > 0.1 and dir / len or vector3(0.0, 0.0, 0.0)
    end
    -- the door's position is its foot: chest height, inside the vault
    list[1] = { coords = c + dir * 2.0 + vector3(0.0, 0.0, Config.Bank.SpotHeight or 1.0), index = nil }   -- nil: the next safe not yet emptied
    return list
end

local function nextSafe(b)
    for i = 1, b.safes or 4 do if not looted(b.id, i) then return i end end
    return nil
end

local function lootSafe(id, spot)
    local b = Banks[id]
    if not b or not canAct() then return end
    local index = spot.index or nextSafe(b)
    if not index then return notify(_L('safe_empty'), 'error') end
    busy = true
    local ok, token = lib.callback.await('multirobberies:bank:lootStart', false, id, index, spot.coords)
    if not ok then notify(errText(token), 'error') busy = false return end
    face(spot.coords)
    playAnim(Config.Bank.Anim)
    local cracked = MGSafeCrack(Config.Bank.Safe, b.label)
    if not cracked then
        ClearPedTasks(ped())
        lib.callback.await('multirobberies:bank:lootEnd', false, token, false)
        notify(_L('safe_failed'), 'error')
        busy = false
        return
    end
    if progress(Config.Bank.LootMs, _L('safe_progress')) then
        local _, err = lib.callback.await('multirobberies:bank:lootEnd', false, token, true)
        if err then notify(errText(err), 'error') end
    else
        TriggerServerEvent('MULTIrobberies:server:cancel')
    end
    ClearPedTasks(ped())
    busy = false
end

local function safeOpen(id, spot)
    local s = state(id)
    if not s or s.stage ~= 'blown' then return false end
    if spot.index then return not looted(id, spot.index) end
    return nextSafe(Banks[id]) ~= nil
end

local function clearSafes(id)
    local B = built[id]
    if not B then return end
    for _, z in ipairs(B.zones) do MCI.RemoveZone(z) end
    for _, name in ipairs(B.prompts) do MCI.RemovePrompt(name) end
    built[id] = nil
end

local function buildSafes(id)
    local b = Banks[id]
    if not b or built[id] or not mode then return end
    local B = { zones = {}, prompts = {}, spots = safeSpots(b) }
    for n, spot in ipairs(B.spots) do
        if mode == 'target' then
            local z = MCI.AddZone({
                coords = spot.coords, radius = Config.Bank.SafeRadius,
                options = { {
                    name = 'multirobberies_safe', label = _L('safe_label'), icon = 'fa-solid fa-vault', distance = 2.5,
                    canInteract = function() return canAct() and safeOpen(id, spot) end,
                    onSelect = function() lootSafe(id, spot) end,
                } },
            })
            if z then B.zones[#B.zones + 1] = z end
        else
            local name = ('multirobberies_safe_%s_%d'):format(id, n)
            MCI.AddPrompt(name, spot.coords, Config.PromptKey, _L('safe_label'),
                { type = 'client', event = 'MULTIrobberies:client:safePrompt', args = { id, n } }, 1.8)
            B.prompts[#B.prompts + 1] = name
        end
    end
    built[id] = B
end

AddEventHandler('MULTIrobberies:client:safePrompt', function(id, n)
    local B = built[id]
    local spot = B and B.spots[n]
    if spot and safeOpen(id, spot) then lootSafe(id, spot) end
end)

-- safes appear while a vault stands blown open and the player is close (props stream in near)
CreateThread(function()
    while true do
        Wait(2000)
        local pos = GetEntityCoords(ped())
        for id, b in pairs(Banks) do
            local s = state(id)
            local blown = s and s.stage == 'blown'
            if blown and not built[id] and #(pos - b.vault.coords) < 35.0 then
                buildSafes(id)
            elseif built[id] and not blown then
                clearSafes(id)
            end
        end
    end
end)

---------------------------------
-- banks: the vault door point
---------------------------------
local vaultZones, vaultPrompts = {}, {}

local function chargeOk(id)
    local s = state(id)
    return canAct() and (not s or s.stage == 'open' or s.stage == 'closed')
end

local function addVaults()
    for id, b in pairs(Banks) do
        if mode == 'target' then
            local z = MCI.AddZone({
                coords = b.vault.coords, radius = 1.4,
                options = { {
                    name = 'multirobberies_charge', label = _L('bank_charge_label'), icon = 'fa-solid fa-bomb',
                    distance = Config.Bank.PlantDistance,
                    canInteract = function() return chargeOk(id) end,
                    onSelect = function() plant(id) end,
                } },
            })
            if z then vaultZones[#vaultZones + 1] = z end
        else
            local name = 'multirobberies_charge_' .. id
            MCI.AddPrompt(name, b.vault.coords, Config.PromptKey, _L('bank_charge_label'),
                { type = 'client', event = 'MULTIrobberies:client:chargePrompt', args = { id } }, Config.Bank.PlantDistance)
            vaultPrompts[#vaultPrompts + 1] = name
        end
    end
end

local function removeVaults()
    for _, z in ipairs(vaultZones) do MCI.RemoveZone(z) end
    for _, n in ipairs(vaultPrompts) do MCI.RemovePrompt(n) end
    vaultZones, vaultPrompts = {}, {}
end

AddEventHandler('MULTIrobberies:client:chargePrompt', function(id) if chargeOk(id) then plant(id) end end)

---------------------------------
-- building everything
---------------------------------
local function setBanks(list)
    for id in pairs(built) do clearSafes(id) end
    if mode then removeVaults() end
    Banks = {}
    for _, b in ipairs(list or {}) do
        b.vault.coords = vec(b.vault.coords)
        Banks[b.id] = b
    end
    if mode then addVaults() end
    for id in pairs(Banks) do
        local s = state(id)
        if s and s.stage == 'blown' then swingVault(id, true) end
    end
end

RegisterNetEvent('MULTIrobberies:client:banks', function(list) setBanks(list) end)

MCI.Run(Config.Interaction, function(m)
    mode = m
    addTills()
    addVaults()
end, function()
    removeTills()
    removeVaults()
    for id in pairs(built) do clearSafes(id) end
    mode = nil
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    local list = lib.callback.await('multirobberies:banks', false)
    while not mode do Wait(250) end
    setBanks(list)
end)

---------------------------------
-- law alert (when MULTIlaw does not run)
---------------------------------
RegisterNetEvent('MULTIrobberies:client:alert', function(coords, text)
    if type(coords) ~= 'vector3' then return end
    notify(tostring(text), 'error')
    local L = Config.Law
    local blip = Citizen.InvokeNative(N.BLIP_ADD_FOR_COORDS, L.BlipStyle, coords.x, coords.y, coords.z, Citizen.ResultAsInteger())
    if blip and blip ~= 0 then
        Citizen.InvokeNative(N.SET_BLIP_SPRITE, blip, L.BlipSprite, true)
        Citizen.InvokeNative(N.SET_BLIP_NAME, blip, _L('alert_blip'))
        alerts[#alerts + 1] = blip
        SetTimeout(L.BlipSeconds * 1000, function() RemoveBlip(blip) end)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(alerts) do RemoveBlip(b) end
    for _, o in pairs(charges) do if DoesEntityExist(o) then DeleteEntity(o) end end
    if busy then ClearPedTasks(ped()) end
end)
