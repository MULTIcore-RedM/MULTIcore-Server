-- ============================================================
-- MULTIinventory :: client/workshop.lua
--
-- Crafting Journal (book NUI, html/js/book.js), placed work stations and the grinding wheel.
--
--   Book      : MULTIinventory:cl:bookOpen (BookData) -> NUI bookOpen; NUI callbacks bookList / bookClose.
--               handcraftStart (client/handcraft.lua) closes the book and re-opens it after the craft.
--   Stations  : server list (stationList) + stationAdd / stationRemove / stationsReset events.
--               Placed stations are local props spawned within streamDistance.
--               MULTItarget on the station MODELS, so map props and housing furniture work too
--               (without MULTItarget: a key prompt on the stations this script placed).
--   Placement : RINGOitemplacer's preview when it is running (Config.Stations.useItemPlacer),
--               otherwise a small built-in preview (arrows turn / move, Enter puts down, Backspace cancels).
--   Sharpen   : ox_lib context menu of worn tools -> progress (HandCraftClient.run) -> sharpenFinish.
-- Every decision is made on the server; this file only shows things and asks.
-- ============================================================

WorkshopClient = WorkshopClient or {}

local SC = Config.Stations or { enabled = false, types = {} }
local RES = GetCurrentResourceName()

local bookOpen = false
local stations = {}      -- [id] = view
local spawned = {}       -- [id] = entity
local extras = {}        -- [id] = { attached prop entities }
local entityStation = {} -- [entity] = id
local info = nil         -- stationList answer (types, distances)

-- ------------------------------------------------------------
-- notifications: bln_notify first, then ox_lib
-- ------------------------------------------------------------
local function notify(text, kind)
    kind = kind or 'inform'
    if GetResourceState('bln_notify') == 'started' then
        local tpl = kind == 'success' and 'SUCCESS' or ((kind == 'error' or kind == 'warning') and 'ERROR' or 'INFO')
        TriggerEvent('bln_notify:send', { title = 'Workshop', description = tostring(text), duration = 5000, placement = 'top-right' }, tpl)
    elseif lib and lib.notify then
        lib.notify({ title = 'Workshop', description = tostring(text), type = kind == 'inform' and 'info' or kind })
    else
        SendNUIMessage({ action = 'notify', data = { text = tostring(text), type = kind } })
    end
end
WorkshopClient.notify = notify

-- ------------------------------------------------------------
-- the book
-- ------------------------------------------------------------
local function showBook(data)
    if type(data) ~= 'table' then return end
    if InvClient and InvClient.isOpen and InvClient.isOpen() then InvClient.close() end
    bookOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'bookOpen', data = data })
end

function WorkshopClient.closeBook()
    if not bookOpen then return end
    bookOpen = false
    SendNUIMessage({ action = 'bookClose' })
    SetNuiFocus(false, false)
end

function WorkshopClient.openBook(chapter)
    CreateThread(function()
        local ok, data = InvClient.request('bookOpen', { chapter = chapter })
        if ok and type(data) == 'table' then showBook(data) end
    end)
end

function WorkshopClient.isBookOpen() return bookOpen end

RegisterNetEvent('MULTIinventory:cl:bookOpen', function(data) showBook(data) end)

RegisterNUICallback('bookList', function(_, cb)
    if not InvClient or not InvClient.nuiAction then cb({ ok = false, err = 'not_ready' }) return end
    InvClient.nuiAction('bookList', {}, cb)
end)

RegisterNUICallback('bookClose', function(_, cb)
    WorkshopClient.closeBook()
    cb({ ok = true })
end)

-- keep the game still while reading (the NUI has keyboard + mouse focus)
CreateThread(function()
    while true do
        if bookOpen then
            DisableAllControlActions(0)
            if IsEntityDead(PlayerPedId()) then WorkshopClient.closeBook() end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNetEvent('MULTIinventory:cl:recipesLearned', function(d)
    if type(d) ~= 'table' then return end
    local lines = { ('You read **%s** and learned:'):format(tostring(d.book or 'the pages')) }
    for _, l in ipairs(d.recipes or {}) do lines[#lines + 1] = '- ' .. tostring(l) end
    lines[#lines + 1] = ''
    lines[#lines + 1] = '_Open your Crafting Journal to make them._'
    if lib and lib.alertDialog then
        CreateThread(function()
            lib.alertDialog({ header = 'Recipes learned', content = table.concat(lines, '  \n'), centered = true, size = 'lg' })
        end)
    else
        notify(table.concat(lines, ' '), 'success')
    end
end)

-- ------------------------------------------------------------
-- stations: props
-- ------------------------------------------------------------
local function typeOf(key) return info and info.types and info.types[key] or (SC.types or {})[key] end

local function loadModel(model)
    local h = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(h) then return nil end
    RequestModel(h)
    local deadline = GetGameTimer() + 3000
    while not HasModelLoaded(h) do
        if GetGameTimer() > deadline then return nil end
        Wait(20)
    end
    return h
end

local function despawn(id)
    local e = spawned[id]
    if e then
        if MBridge and MBridge.Interact and not (GetResourceState('MULTItarget') == 'started') then
            pcall(MBridge.Interact.RemoveEntity, e)
        end
        entityStation[e] = nil
        if DoesEntityExist(e) then DeleteObject(e) end
    end
    for _, x in ipairs(extras[id] or {}) do if DoesEntityExist(x) then DeleteObject(x) end end
    extras[id] = nil
    spawned[id] = nil
end

local addEntityFallback   -- set below

local function spawn(s)
    local t = typeOf(s.type)
    if not t then return end
    local h = loadModel(s.model or t.model)
    if not h then return end
    local e = CreateObject(h, s.x, s.y, s.z, false, false, false)
    SetModelAsNoLongerNeeded(h)
    if not e or e == 0 then return end
    SetEntityHeading(e, s.heading or 0.0)
    FreezeEntityPosition(e, true)
    spawned[s.id] = e
    entityStation[e] = s.id
    -- attached props (the cooking fire's flames and pot): local, no collision, follow the station's heading
    local cfgType = (SC.types or {})[s.type] or {}
    local list = {}
    for _, a in ipairs(cfgType.attach or {}) do
        local ah = loadModel(a.model)
        if ah then
            local off = a.offset or {}
            local p = GetOffsetFromEntityInWorldCoords(e, (off.x or 0.0) + 0.0, (off.y or 0.0) + 0.0, (off.z or 0.0) + 0.0)
            local x = CreateObject(ah, p.x, p.y, p.z, false, false, false)
            SetModelAsNoLongerNeeded(ah)
            if x and x ~= 0 then
                SetEntityHeading(x, (s.heading or 0.0) + (tonumber(a.h) or 0.0))
                SetEntityCollision(x, false, false)
                FreezeEntityPosition(x, true)
                list[#list + 1] = x
            end
        end
    end
    extras[s.id] = list
    if addEntityFallback then addEntityFallback(e, s) end
end

CreateThread(function()
    while true do
        local wait = 1500
        if info and info.enabled and next(stations) then
            local p = GetEntityCoords(PlayerPedId())
            local range = info.streamDistance or 120.0
            for id, s in pairs(stations) do
                local d = #(p - vector3(s.x, s.y, s.z))
                if d <= range and not spawned[id] then spawn(s)
                elseif d > range + 10.0 and spawned[id] then despawn(id) end
            end
            wait = 1000
        end
        Wait(wait)
    end
end)

local function reset(list)
    for id in pairs(spawned) do despawn(id) end
    stations = {}
    for _, s in ipairs(list or {}) do stations[s.id] = s end
end

RegisterNetEvent('MULTIinventory:cl:stationAdd', function(s)
    if type(s) == 'table' and s.id then
        if spawned[s.id] then despawn(s.id) end
        stations[s.id] = s
    end
end)
RegisterNetEvent('MULTIinventory:cl:stationRemove', function(id)
    despawn(id)
    stations[id] = nil
end)
RegisterNetEvent('MULTIinventory:cl:stationsReset', function(list) reset(list) end)

-- ------------------------------------------------------------
-- sharpening
-- ------------------------------------------------------------
local function sharpen(id)
    CreateThread(function()
        if HandCraftClient and HandCraftClient.isBusy() then return end
        local ok, job = InvClient.request('sharpenBegin', { id = id })
        if not ok or type(job) ~= 'table' then return end   -- the server said why
        HandCraftClient.run(job, { finish = 'sharpenFinish', cancel = 'sharpenCancel' })
    end)
end

local function sharpenMenu()
    CreateThread(function()
        local ok, res = InvClient.request('sharpenList', {})
        if not ok or type(res) ~= 'table' then return end
        local tools = res.tools or {}
        if #tools == 0 then
            notify('None of your tools need the wheel.', 'inform')
            return
        end
        local cost = res.cost
        local costLine = cost and ('Uses %d %s each (you have %d).'):format(cost.count, cost.label, cost.have) or 'Free to use.'
        local opts = {}
        for _, t in ipairs(tools) do
            local enough = not cost or cost.have >= cost.count
            opts[#opts + 1] = {
                title = t.label,
                description = ('Durability %d%%  ->  %d%%'):format(t.durability, res.max or 100),
                progress = t.durability,
                colorScheme = t.durability < 25 and 'red' or (t.durability < 60 and 'yellow' or 'green'),
                icon = 'fa-solid fa-gear',
                disabled = not enough,
                onSelect = function() sharpen(t.id) end,
            }
        end
        lib.registerContext({ id = 'multiinv_sharpen', title = 'Grinding Wheel', menu = nil,
                              options = { { title = costLine, icon = 'fa-solid fa-oil-can', readOnly = true }, table.unpack(opts) } })
        lib.showContext('multiinv_sharpen')
    end)
end

-- ------------------------------------------------------------
-- using a station (target)
-- ------------------------------------------------------------
local function faceEntity(entity)
    if entity and DoesEntityExist(entity) then
        TaskTurnPedToFaceEntity(PlayerPedId(), entity, 800)
        Wait(800)
    end
end

local function useStation(entity, stype)
    if HandCraftClient and HandCraftClient.isBusy() then
        notify('You are busy - finish what you are making first.', 'error')
        return
    end
    CreateThread(function()
        local id = entity and entityStation[entity]
        local req
        if id then req = { id = id }
        else
            local c = GetEntityCoords(entity)
            req = { type = stype, x = c.x, y = c.y, z = c.z }
        end
        local ok, res = InvClient.request('stationUse', req)
        if not ok or type(res) ~= 'table' then return end
        faceEntity(entity)
        if res.action == 'sharpen' then sharpenMenu()
        else WorkshopClient.openBook(res.chapter) end
    end)
end

local function pickup(entity)
    local id = entityStation[entity]
    if not id then return end
    CreateThread(function()
        local t = typeOf(stations[id] and stations[id].type)
        if lib and lib.alertDialog then
            local answer = lib.alertDialog({ header = 'Pick up', centered = true, cancel = true, size = 'md',
                content = ('Pick the %s up again? It keeps the time it has left.'):format((t and t.label or 'station'):lower()) })
            if answer ~= 'confirm' then return end
        end
        InvClient.request('stationPickup', { id = id })
    end)
end

local function ownsEntity(entity)
    local id = entityStation[entity]
    local s = id and stations[id]
    local me = InvClient.charId or (info and info.me)
    return s ~= nil and me ~= nil and tonumber(s.owner) == tonumber(me)
end

local targetsAdded = false

local function addTargets()
    if targetsAdded or not info or not info.enabled then return end
    if GetResourceState('MULTItarget') ~= 'started' then return end
    local dist = info.interactDistance or 2.5
    local failed = 0
    for key, t in pairs(info.types or {}) do
        local models = {}
        local seen = {}
        for _, m in ipairs(t.worldModels or {}) do if not seen[m] then seen[m] = true; models[#models + 1] = m end end
        if t.model and not seen[t.model] then models[#models + 1] = t.model end
        local options = {
            {
                name = 'multiinv_station_' .. key, label = t.targetLabel or t.label or key, icon = t.icon or 'fa-solid fa-hammer',
                distance = dist,
                canInteract = function(entity)
                    return entityStation[entity] ~= nil or info.worldProps ~= false
                end,
                onSelect = function(data) useStation(data.entity, key) end,
            },
        }
        if info.allowPickup then
            options[#options + 1] = {
                name = 'multiinv_station_pickup_' .. key, label = 'Pick up', icon = 'fa-solid fa-hand',
                distance = dist,
                canInteract = function(entity) return ownsEntity(entity) end,
                onSelect = function(data) pickup(data.entity) end,
            }
        end
        -- one type at a time: a failing registration never blocks the other stations
        local ok, err = pcall(function() exports.MULTItarget:addModel(models, options) end)
        if not ok then
            failed = failed + 1
            print(('^3[MULTIinventory] station target %s not added: %s^7'):format(key, tostring(err)))
        end
    end
    targetsAdded = failed == 0
end

-- without MULTItarget: a key prompt on the stations this script placed
addEntityFallback = function(e, s)
    if GetResourceState('MULTItarget') == 'started' then return end
    if not (MBridge and MBridge.Interact) then return end
    local t = typeOf(s.type) or {}
    local opts = { { label = t.targetLabel or t.label or 'Use', onSelect = function(ent) useStation(ent, s.type) end } }
    if info and info.allowPickup then
        opts[#opts + 1] = { label = 'Pick up', key = 0x760A9C6F, canInteract = function(ent) return ownsEntity(ent) end,   -- G
                            onSelect = function(ent) pickup(ent) end }
    end
    MBridge.Interact.AddEntity(e, { distance = info and info.interactDistance or 2.5, title = t.label, options = opts })
end

-- ------------------------------------------------------------
-- placement
-- ------------------------------------------------------------
local K = {
    accept = joaat('INPUT_FRONTEND_ACCEPT'), cancel = joaat('INPUT_FRONTEND_CANCEL'),
    left = joaat('INPUT_FRONTEND_LEFT'), right = joaat('INPUT_FRONTEND_RIGHT'),
    up = joaat('INPUT_FRONTEND_UP'), down = joaat('INPUT_FRONTEND_DOWN'),
}

local function builtinPlacement(model, maxDist, label)
    local h = loadModel(model)
    if not h then return nil, 'model_failed' end
    local ped = PlayerPedId()
    local ghost = CreateObject(h, GetEntityCoords(ped), false, false, false)
    SetModelAsNoLongerNeeded(h)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    local heading, dist = GetEntityHeading(ped), 1.6
    if lib and lib.showTextUI then
        lib.showTextUI(('[Arrows] turn / move  \n[Enter] put down the %s  \n[Backspace] cancel'):format((label or 'station'):lower()))
    end
    local result, reason
    local deadline = GetGameTimer() + 120000
    while true do
        Wait(0)
        ped = PlayerPedId()
        DisableControlAction(0, K.accept, true); DisableControlAction(0, K.cancel, true)
        if IsDisabledControlPressed(0, K.left) or IsControlPressed(0, K.left) then heading = heading + 1.5 end
        if IsDisabledControlPressed(0, K.right) or IsControlPressed(0, K.right) then heading = heading - 1.5 end
        if IsDisabledControlPressed(0, K.up) or IsControlPressed(0, K.up) then dist = math.min(maxDist, dist + 0.03) end
        if IsDisabledControlPressed(0, K.down) or IsControlPressed(0, K.down) then dist = math.max(0.8, dist - 0.03) end
        local fwd = GetEntityForwardVector(ped)
        local pos = GetEntityCoords(ped) + fwd * dist
        SetEntityCoordsNoOffset(ghost, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(ghost, heading)
        PlaceObjectOnGroundProperly(ghost, true)
        if IsDisabledControlJustPressed(0, K.accept) then
            local c = GetEntityCoords(ghost)
            result = { coords = c, heading = GetEntityHeading(ghost) }
            break
        end
        if IsDisabledControlJustPressed(0, K.cancel) or IsEntityDead(ped) or GetGameTimer() > deadline then
            reason = 'cancelled'
            break
        end
    end
    if lib and lib.hideTextUI then lib.hideTextUI() end
    DeleteObject(ghost)
    return result, reason
end

RegisterNetEvent('MULTIinventory:cl:stationPlace', function(d)
    if type(d) ~= 'table' then return end
    CreateThread(function()
        if InvClient.isOpen() then InvClient.close() end
        Wait(150)
        local res, reason
        if d.useItemPlacer and GetResourceState('RINGOitemplacer') == 'started' then
            local ok, r1, r2 = pcall(function()
                return exports.RINGOitemplacer:StartPlacement(d.model, {
                    label = d.label, helpText = 'Put down the ' .. tostring(d.label):lower(),
                    maxDistance = d.placeDistance, maxPlayerDistance = d.placeDistance, snapToGround = true,
                })
            end)
            if ok then res, reason = r1, r2 else res, reason = builtinPlacement(d.model, d.placeDistance or 5.0, d.label) end
        else
            res, reason = builtinPlacement(d.model, d.placeDistance or 5.0, d.label)
        end
        if not res or not res.coords then
            if reason ~= 'cancelled' then notify('You could not put it there.', 'error') end
            return
        end
        InvClient.request('stationPlace', { token = d.token, x = res.coords.x, y = res.coords.y, z = res.coords.z,
                                            heading = res.heading or 0.0 })
    end)
end)

-- ------------------------------------------------------------
-- start-up
-- ------------------------------------------------------------
-- The station list needs a loaded character: keep asking until the server answers (a player can sit in
-- character select for minutes after a restart), and ask again whenever the character (re)loads.
local fetching = false
local function fetchStations()
    if fetching or not SC.enabled then return end
    fetching = true
    CreateThread(function()
        while true do
            local ok, res = InvClient.request('stationList', {})
            if ok and type(res) == 'table' then
                info = res
                reset(res.stations)
                break
            end
            Wait(5000)
        end
        fetching = false
        -- MULTItarget may start after this resource
        for _ = 1, 120 do
            addTargets()
            if targetsAdded then break end
            Wait(1000)
        end
    end)
end

CreateThread(function()
    if not SC.enabled then return end
    if MBridge and MBridge.WaitForSession then MBridge.WaitForSession(1000) end
    Wait(2000)
    fetchStations()
end)
AddEventHandler('MULTIinventory:client:synced', function() if not info then fetchStations() end end)

-- /workshopdebug : what this client knows about stations (for support)
RegisterCommand('workshopdebug', function()
    local n, sp = 0, 0
    for _ in pairs(stations) do n = n + 1 end
    for _ in pairs(spawned) do sp = sp + 1 end
    local lines = {
        ('Station list loaded: **%s**'):format(info and 'yes' or 'NO'),
        ('MULTItarget: **%s**, targets added: **%s**'):format(GetResourceState('MULTItarget'), targetsAdded and 'yes' or 'NO'),
        ('Stations known: **%d**, spawned near you: **%d**'):format(n, sp),
        ('Busy crafting: **%s**'):format(HandCraftClient and HandCraftClient.isBusy() and 'YES' or 'no'),
    }
    if lib and lib.alertDialog then
        CreateThread(function() lib.alertDialog({ header = 'Workshop', content = table.concat(lines, '  \n'), centered = true, size = 'lg' }) end)
    else
        print(table.concat(lines, '\n'))
    end
    if not info then fetchStations() end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    for id in pairs(spawned) do despawn(id) end
    if bookOpen then SetNuiFocus(false, false) end
end)
