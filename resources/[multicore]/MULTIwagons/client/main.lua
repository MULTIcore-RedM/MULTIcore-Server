-- ============================================================
-- MULTIwagons :: client
-- Dealers and call points (prompt or MULTItarget, blips, clerks), the ox_lib
-- menus, making the wagon when it is taken out, the storage prompt at a
-- wagon's back, health reports and the repair kit. The client never changes
-- money, items or ownership: it asks the server (lib.callback) and shows
-- the answer.
-- Spawn steps follow RSG v2's rsg-wagons client (GPL v3, Phil and mack /
-- Rexshack-RedM, see CREDITS.md).
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

-- natives (femga natives.json)
local SET_BLIP_NAME = 0x9CB1A1623062F402                -- _SET_BLIP_NAME
local BLIP_ADD_FOR_ENTITY = 0x23F74C2FDA6E7C61          -- BLIP_ADD_FOR_ENTITY
local SET_VEHICLE_HAS_BEEN_OWNED_BY_PLAYER = 0xBB5A3FA8ED3979C5
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE  -- _SET_RANDOM_OUTFIT_VARIATION
local OWN_BLIP_STYLE = -1230993421                      -- BlipAddForEntity style rsg-wagons uses for the own wagon

local FULL_HEALTH = 100
local NEAR_WAGON_SCAN = 12.0   -- metres around the player searched for wagons with storage
local SCAN_MS = 500            -- ms between those searches

local my = nil                 -- { id, entity, netId, plate, name, model, blip, lastHealth }
local points = {}              -- [name] = { def, dealer }
local blips, clerks, zones, prompts = {}, {}, {}, {}

for _, d in ipairs(Config.Dealers or {}) do points[d.name] = { def = d, dealer = true } end
for _, c in ipairs(Config.CallPoints or {}) do
    if not points[c.name] then points[c.name] = { def = c, dealer = false } end
end

local function notify(text, kind)
    exports.MULTIcore:Notify({ text = text, title = _L('title'), type = kind or 'info' })
end

local function money(n) return ('%s%.2f'):format(Config.CurrencySign, n) end
local function wagonLabel(model) return _L('wagon_' .. tostring(model)) end
local function placeLabel(name) return _L('place_' .. tostring(name)) end

local function cfgOf(model)
    for _, w in ipairs(Config.Wagons) do if w.model == model then return w end end
end

local function healthPct(veh)
    local max = GetEntityMaxHealth(veh)
    if not max or max <= 0 then return FULL_HEALTH end
    return math.max(0, math.min(FULL_HEALTH, math.floor(GetEntityHealth(veh) / max * FULL_HEALTH + 0.5)))
end

local function control(entity)
    NetworkRequestControlOfEntity(entity)
    local deadline = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
        Wait(100)
        NetworkRequestControlOfEntity(entity)
    end
end

-- ---------------------------------------------------------------
-- own wagon: make / remove
-- ---------------------------------------------------------------
local function clearMine()
    if not my then return end
    if my.blip and DoesBlipExist(my.blip) then RemoveBlip(my.blip) end
    local e = my.entity
    my = nil
    if e and DoesEntityExist(e) then
        control(e)
        SetEntityAsMissionEntity(e, true, true)
        DeleteVehicle(e)
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
end

local function spotTaken(pos)
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(veh) - pos) < Config.SpawnClearRadius then return true end
    end
    return false
end

--- where a called wagon appears: the road nearest a spot in front of the player
local function callSpot()
    local ped = cache.ped
    local fwd = GetOffsetFromEntityInWorldCoords(ped, 0.0, Config.CallSpawnDistance, 0.0)
    local found, node = GetClosestVehicleNode(fwd.x, fwd.y, fwd.z, 0, 3.0, 0.0)
    if found and node and #(node - GetEntityCoords(ped)) < Config.CallSpawnDistance * 3 then
        return vector4(node.x, node.y, node.z, GetEntityHeading(ped))
    end
    return vector4(fwd.x, fwd.y, fwd.z, GetEntityHeading(ped))
end

local function spawnWagon(data)
    if type(data) ~= 'table' or not data.id then return end
    if my then clearMine() end
    local s = data.spawn and vector4(data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w) or callSpot()
    local hash = joaat(data.model)
    if spotTaken(s.xyz) then
        notify(_L('err_spawn_blocked'), 'error')
        return TriggerServerEvent('MULTIwagons:server:spawnFailed', data.id)
    end
    if not IsModelValid(hash) or not pcall(lib.requestModel, hash, Config.ModelLoadTimeoutMs) then
        notify(_L('err_error'), 'error')
        return TriggerServerEvent('MULTIwagons:server:spawnFailed', data.id)
    end
    local veh = CreateVehicle(hash, s.x, s.y, s.z, s.w, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not veh or veh == 0 then
        notify(_L('err_error'), 'error')
        return TriggerServerEvent('MULTIwagons:server:spawnFailed', data.id)
    end
    SetVehicleOnGroundProperly(veh, true)
    SetEntityAsMissionEntity(veh, true, true)
    Citizen.InvokeNative(SET_VEHICLE_HAS_BEEN_OWNED_BY_PLAYER, veh, true)
    SetVehicleDirtLevel(veh, 0.0)
    local h = tonumber(data.health) or FULL_HEALTH
    if h < FULL_HEALTH then
        SetEntityHealth(veh, math.max(1, math.floor(GetEntityMaxHealth(veh) * h / FULL_HEALTH)), 0)
    end
    NetworkRegisterEntityAsNetworked(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local deadline = GetGameTimer() + 5000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do Wait(50) end
    SetNetworkIdExistsOnAllMachines(netId, true)

    my = { id = data.id, entity = veh, netId = netId, plate = data.plate, name = data.name, model = data.model, lastHealth = h }
    if Config.Blips.OwnWagon then
        my.blip = Citizen.InvokeNative(BLIP_ADD_FOR_ENTITY, OWN_BLIP_STYLE, veh)
        SetBlipSprite(my.blip, joaat(Config.Blips.OwnWagonSprite), true)
        Citizen.InvokeNative(SET_BLIP_NAME, my.blip, data.name ~= '' and data.name or wagonLabel(data.model))
    end
    TriggerServerEvent('MULTIwagons:server:spawned', data.id, netId)
end

RegisterNetEvent('MULTIwagons:client:spawn', spawnWagon)

RegisterNetEvent('MULTIwagons:client:gone', function(id)
    if my and my.id == id then clearMine() end
end)

RegisterNetEvent('MULTIwagons:client:repaired', function(id)
    if not my or my.id ~= id or not DoesEntityExist(my.entity) then return end
    control(my.entity)
    SetVehicleFixed(my.entity)
    SetEntityHealth(my.entity, GetEntityMaxHealth(my.entity), 0)
    my.lastHealth = FULL_HEALTH
end)

-- health reports while the wagon is out
CreateThread(function()
    while true do
        Wait(math.max(5, Config.Health.ReportSeconds) * 1000)
        if my and DoesEntityExist(my.entity) then
            local h = healthPct(my.entity)
            if h < (my.lastHealth or FULL_HEALTH) then
                my.lastHealth = h
                TriggerServerEvent('MULTIwagons:server:health', my.id, h)
            end
        end
    end
end)

-- ---------------------------------------------------------------
-- menus
-- ---------------------------------------------------------------
local openPoint, openMine

local function takeOut(point, id)
    local res = lib.callback.await('MULTIwagons:takeOut', false, point, id)
    if res and res.ok then spawnWagon(res.wagon) end
end

local function putAway(id)
    local h = (my and my.id == id and DoesEntityExist(my.entity)) and healthPct(my.entity) or nil
    lib.callback.await('MULTIwagons:store', false, id, h)
end

local function askName(title, default)
    local input = lib.inputDialog(title, {
        { type = 'input', label = _L('name_label'), description = _L('name_hint', Config.NameMinLength, Config.NameMaxLength),
          required = true, min = Config.NameMinLength, max = Config.NameMaxLength, default = default },
    })
    return input and input[1] or nil
end

local function openWagon(point, w)
    local p = point and points[point]
    local dealer = p and p.dealer
    local options = {}
    if not w.out then
        options[#options + 1] = {
            title = point and _L('menu_take_out') or _L('menu_call'), icon = 'arrow-right',
            disabled = w.health < Config.Health.MinToTakeOut,
            description = w.health < Config.Health.MinToTakeOut and _L('err_broken') or nil,
            onSelect = function() takeOut(point, w.id) end,
        }
    else
        options[#options + 1] = { title = _L('menu_put_away'), icon = 'warehouse', onSelect = function() putAway(w.id) end }
    end
    if dealer and (w.repairFee or 0) > 0 then
        options[#options + 1] = {
            title = _L('menu_repair', money(w.repairFee)), icon = 'hammer',
            onSelect = function()
                lib.callback.await('MULTIwagons:repair', false, point, w.id)
                openMine(point)
            end,
        }
    end
    if point then
        options[#options + 1] = {
            title = _L('menu_rename'), icon = 'pen',
            onSelect = function()
                local name = askName(_L('menu_rename'), w.name)
                if name then lib.callback.await('MULTIwagons:rename', false, point, w.id, name) end
                openMine(point)
            end,
        }
    end
    if dealer and not w.out then
        options[#options + 1] = {
            title = _L('menu_sell', money(w.sellPrice or 0)), icon = 'hand-holding-dollar',
            onSelect = function()
                local answer = lib.alertDialog({
                    header = _L('menu_sell', money(w.sellPrice or 0)),
                    content = _L('sell_confirm', w.name, money(w.sellPrice or 0)),
                    centered = true, cancel = true,
                })
                if answer == 'confirm' then lib.callback.await('MULTIwagons:sell', false, point, w.id) end
                openMine(point)
            end,
        }
    end
    lib.registerContext({ id = 'multiwagons_wagon', title = w.name, menu = 'multiwagons_mine', options = options })
    lib.showContext('multiwagons_wagon')
end

openMine = function(point)
    local list = lib.callback.await('MULTIwagons:mine', false) or {}
    local options = {}
    for _, w in ipairs(list) do
        options[#options + 1] = {
            title = w.name, arrow = true,
            description = _L('wagon_line', wagonLabel(w.model), w.plate or '-', w.health, w.out and _L('state_out') or _L('state_stored')),
            progress = w.health,
            onSelect = function() openWagon(point, w) end,
        }
    end
    if #options == 0 then options[1] = { title = _L('none_owned'), disabled = true } end
    lib.registerContext({
        id = 'multiwagons_mine', title = _L('menu_mine', #list, Config.MaxWagonsPerCharacter),
        menu = point and 'multiwagons_point' or nil, options = options,
    })
    lib.showContext('multiwagons_mine')
end

local function openCategory(point, cat)
    local options = {}
    for _, w in ipairs(Config.Wagons) do
        if w.category == cat and w.enabled ~= false then
            options[#options + 1] = {
                title = ('%s - %s'):format(wagonLabel(w.model), money(w.price)),
                description = _L('wagon_space', w.slots, w.weight),
                onSelect = function()
                    local name = askName(_L('buy_title', wagonLabel(w.model), money(w.price)), wagonLabel(w.model))
                    if not name then return openCategory(point, cat) end
                    local res = lib.callback.await('MULTIwagons:buy', false, point, w.model, name)
                    if res and res.ok then openMine(point) end
                end,
            }
        end
    end
    lib.registerContext({ id = 'multiwagons_cat', title = _L('cat_' .. cat), menu = 'multiwagons_buy', options = options })
    lib.showContext('multiwagons_cat')
end

local function openBuy(point)
    local options = {}
    for _, cat in ipairs(Config.Categories) do
        options[#options + 1] = { title = _L('cat_' .. cat), arrow = true, onSelect = function() openCategory(point, cat) end }
    end
    lib.registerContext({ id = 'multiwagons_buy', title = _L('menu_buy'), menu = 'multiwagons_point', options = options })
    lib.showContext('multiwagons_buy')
end

openPoint = function(name)
    local p = points[name]
    if not p then return end
    local options = {}
    if p.dealer then
        options[#options + 1] = { title = _L('menu_buy'), icon = 'cart-shopping', arrow = true, onSelect = function() openBuy(name) end }
    end
    options[#options + 1] = { title = _L('menu_my_wagons'), icon = 'horse', arrow = true, onSelect = function() openMine(name) end }
    lib.registerContext({ id = 'multiwagons_point', title = placeLabel(name), options = options })
    lib.showContext('multiwagons_point')
end
AddEventHandler('MULTIwagons:client:point', function(name) openPoint(name) end)

local function pointHere()
    local pos = GetEntityCoords(cache.ped)
    for name, p in pairs(points) do
        if #(pos - p.def.coords) <= Config.MaxUseDistance then return name end
    end
end

if Config.CallCommand and Config.CallCommand ~= '' then
    RegisterCommand(Config.CallCommand, function()
        local here = pointHere()
        if here then return openPoint(here) end
        if Config.CallAnywhere then return openMine(nil) end
        notify(_L('err_too_far'), 'error')
    end, false)
end

-- ---------------------------------------------------------------
-- repair kit
-- ---------------------------------------------------------------
RegisterNetEvent('MULTIwagons:client:useRepairKit', function()
    if not my or not DoesEntityExist(my.entity) then return notify(_L('err_not_out'), 'error') end
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(my.entity)) > Config.Repair.ItemDistance then
        return notify(_L('err_too_far_wagon'), 'error')
    end
    if healthPct(my.entity) >= FULL_HEALTH and (my.lastHealth or FULL_HEALTH) >= FULL_HEALTH then
        return notify(_L('err_not_damaged'), 'error')
    end
    if lib.progressBar({
        duration = Config.Repair.ProgressMs, label = _L('repairing'), canCancel = true,
        disable = { move = true, car = true, combat = true },
    }) then
        lib.callback.await('MULTIwagons:repairKit', false)
    end
end)

-- ---------------------------------------------------------------
-- storage at a wagon's back
-- ---------------------------------------------------------------
local function myCitizenId()
    local pd = RSGCore.Functions.GetPlayerData()
    return pd and pd.citizenid
end

local function backPoint(veh)
    local min = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - Config.StorageBackOffset, 0.0)
end

local function mayOpen(veh)
    local st = Entity(veh).state.multiwagon
    if type(st) ~= 'table' then return false end
    if Config.StorageOpenTo ~= 'anyone' and st.owner ~= myCitizenId() then return false end
    return true
end

local function openStorage(veh)
    TriggerServerEvent('MULTIwagons:server:openStorage', NetworkGetNetworkIdFromEntity(veh))
end

-- storage: MULTItarget "Open storage" on every wagon (shown only at the back of one the
-- player may open), or one hold-key prompt that follows the nearest such wagon.
local storageLoop = 0          -- bumped to end a running prompt loop
local storageTarget = false

MCI.Run(Config.Interact, function(mode)
    if mode == 'target' then
        exports.MULTItarget:addGlobalVehicle({
            {
                name = 'multiwagons_storage', label = _L('prompt_storage'), icon = Config.TargetStorageIcon,
                distance = Config.TargetDistance,
                canInteract = function(entity)
                    if not mayOpen(entity) then return false end
                    return #(GetEntityCoords(cache.ped) - backPoint(entity)) <= Config.StorageDistance
                end,
                onSelect = function(data) openStorage(data.entity) end,
            },
        })
        storageTarget = true
        MCI.Count('targets', 1)
        return
    end
    storageLoop = storageLoop + 1
    local myLoop = storageLoop
    CreateThread(function()
        local prompt = UiPromptRegisterBegin()
        UiPromptSetControlAction(prompt, MCI.Key(Config.StorageKey))
        UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', _L('prompt_storage')))
        UiPromptSetEnabled(prompt, false)
        UiPromptSetVisible(prompt, false)
        UiPromptSetHoldMode(prompt, 1000)
        UiPromptRegisterEnd(prompt)
        prompts[#prompts + 1] = { native = prompt }
        MCI.Count('prompts', 1)

        local target, nextScan = nil, 0
        while myLoop == storageLoop do
            local now = GetGameTimer()
            if now >= nextScan then
                nextScan = now + SCAN_MS
                target = nil
                local pos = GetEntityCoords(cache.ped)
                local best = Config.StorageDistance
                if not IsPedInAnyVehicle(cache.ped, false) then
                    for _, veh in ipairs(GetGamePool('CVehicle')) do
                        if #(GetEntityCoords(veh) - pos) < NEAR_WAGON_SCAN and mayOpen(veh) then
                            local d = #(pos - backPoint(veh))
                            if d <= best then best, target = d, veh end
                        end
                    end
                end
                UiPromptSetEnabled(prompt, target ~= nil)
                UiPromptSetVisible(prompt, target ~= nil)
            end
            if target then
                if UiPromptHasHoldModeCompleted(prompt) then
                    openStorage(target)
                    UiPromptSetEnabled(prompt, false)
                    Wait(1000)
                    UiPromptSetEnabled(prompt, true)
                end
                Wait(0)
            else
                Wait(SCAN_MS)
            end
        end
        UiPromptDelete(prompt)
        for i = #prompts, 1, -1 do if prompts[i].native == prompt then table.remove(prompts, i) end end
        MCI.Count('prompts', -1)
    end)
end, function(mode)
    if mode == 'target' then
        if storageTarget and MCI.HasTarget() then
            pcall(function() exports.MULTItarget:removeGlobalVehicle('multiwagons_storage') end)
        end
        if storageTarget then MCI.Count('targets', -1) end
        storageTarget = false
    else
        storageLoop = storageLoop + 1   -- the prompt loop ends and deletes its prompt
    end
end)

-- ---------------------------------------------------------------
-- dealers / call points: prompts or targets, blips, clerks
-- ---------------------------------------------------------------
local interactMode = nil       -- 'target' or 'prompt' once MCI.Run has decided

local function pointText(name, p)
    local label = placeLabel(name)
    return p.dealer and _L('prompt_dealer', label) or _L('prompt_call', label)
end

-- the dealer / call point option (zone and clerk use the same one)
local function pointOption(name, p)
    return {
        name = 'multiwagons_' .. name, label = pointText(name, p), icon = Config.TargetIcon,
        distance = Config.TargetDistance, onSelect = function() openPoint(name) end,
    }
end

-- MULTItarget (Config.Interact 'auto' / 'target') or hold-key prompts, see @MULTIcore/lib/interact.lua
MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    for name, p in pairs(points) do
        if mode == 'target' then
            zones[#zones + 1] = MCI.AddZone({ coords = p.def.coords, radius = Config.TargetRadius, options = { pointOption(name, p) } })
            if clerks[name] then MCI.AddEntity(clerks[name], { pointOption(name, p) }) end
        else
            MCI.AddPrompt('multiwagons_' .. name, p.def.coords, Config.PromptKey, pointText(name, p),
                { type = 'client', event = 'MULTIwagons:client:point', args = { name } }, Config.PromptDistance)
            prompts[#prompts + 1] = { name = 'multiwagons_' .. name }
        end
    end
end, function()
    for _, id in ipairs(zones) do MCI.RemoveZone(id) end
    zones = {}
    for _, ped in pairs(clerks) do MCI.RemoveEntity(ped) end
    for i = #prompts, 1, -1 do
        if prompts[i].name then MCI.RemovePrompt(prompts[i].name) table.remove(prompts, i) end
    end
    interactMode = nil
end)

CreateThread(function()
    for name, p in pairs(points) do
        local label = placeLabel(name)
        if Config.Blips.Enabled and p.dealer and p.def.blip ~= false then
            local blip = BlipAddForCoords(Config.Blips.Style, p.def.coords.x, p.def.coords.y, p.def.coords.z)
            SetBlipSprite(blip, Config.Blips.Sprite, true)
            SetBlipScale(blip, Config.Blips.Scale)
            Citizen.InvokeNative(SET_BLIP_NAME, blip, label)
            blips[#blips + 1] = blip
        end
    end
end)

local function spawnClerk(npc)
    local model = joaat(Config.Npc.Model)
    RequestModel(model, false)
    local deadline = GetGameTimer() + Config.Npc.LoadTimeoutMs
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) then return nil end
    local ped = CreatePed(model, npc.x, npc.y, npc.z + Config.Npc.ZOffset, npc.w, false, false, false, false)
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)
    return ped
end

CreateThread(function()
    if not Config.Npc.Enabled then return end
    while true do
        Wait(Config.CheckIntervalMs)
        local pos = GetEntityCoords(cache.ped)
        for name, p in pairs(points) do
            if p.def.npc then
                local near = #(pos - p.def.npc.xyz) < Config.Npc.SpawnDistance
                if near and not clerks[name] then
                    clerks[name] = spawnClerk(p.def.npc)
                    if clerks[name] and interactMode == 'target' then MCI.AddEntity(clerks[name], { pointOption(name, p) }) end
                elseif not near and clerks[name] then
                    MCI.RemoveEntity(clerks[name])
                    if DoesEntityExist(clerks[name]) then DeletePed(clerks[name]) end
                    clerks[name] = nil
                end
            end
        end
    end
end)

-- for /mcinteract
MCI.Counter('npcs', function()
    local n = 0
    for _ in pairs(clerks) do n = n + 1 end
    return n
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearMine()
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for _, ped in pairs(clerks) do if DoesEntityExist(ped) then DeletePed(ped) end end
    for _, pr in ipairs(prompts) do
        if pr.name then MCI.RemovePrompt(pr.name) end
        if pr.native then UiPromptDelete(pr.native) end
    end
    -- MULTItarget drops this script's zones, entity options and the storage option by itself when it stops
end)

-- for client/compat.lua and other scripts
MWClient = {
    OpenPoint = openPoint, OpenMine = openMine, PointHere = pointHere, PutAway = putAway,
    Mine = function() return my end, CfgOf = cfgOf,
}
exports('GetMyWagon', function() return my and { id = my.id, entity = my.entity, netId = my.netId, plate = my.plate, name = my.name, model = my.model } or nil end)
exports('OpenMenu', function() local here = pointHere() if here then openPoint(here) elseif Config.CallAnywhere then openMine(nil) end end)
