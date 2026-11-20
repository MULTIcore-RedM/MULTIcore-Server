-- ============================================================
-- MULTIcrafting :: client (crafting screen and progress)
-- The screen shows what the server sent; crafting asks the server to start,
-- plays the station's animation with a progress bar, then asks the server to
-- finish. Stopping early (cancel key, moving away, death) costs nothing:
-- inputs are only taken by the server when crafting finishes.
-- GPL v3, part of MULTIcore.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local isOpen = false
local busy = false
local staticSent = false
local current = nil         -- { ref, coords } of the open station

function CC.IsBusy() return busy end
function CC.SetBusy(v)
    busy = v and true or false
    LocalPlayer.state:set('inv_busy', busy, true)
end

local function keyOf(name)
    local keys = RSGCore.Shared and RSGCore.Shared.Keybinds or {}
    return keys[name]
end

local function imagePaths()
    if type(Config.ImagePaths) == 'table' then return Config.ImagePaths end
    if GetResourceState('MULTIinventory') == 'started' then
        local ok, list = pcall(function() return exports.MULTIinventory:GetImagePaths() end)
        if ok and type(list) == 'table' then return list end
    end
    return {}
end

local function sendStatic()
    if staticSent then return end
    staticSent = true
    SendNUIMessage({ action = 'setup', locale = _LT(), lang = _LCode(), images = imagePaths(), cancelKey = Config.Craft.CancelKey })
end

local function closeMenu(tellServer)
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if tellServer ~= false then TriggerServerEvent('MULTIcrafting:server:close') end
end

local function showState(state)
    sendStatic()
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = state })
end

--- Opens the crafting screen at a station (ref as the server expects it).
function CC.OpenAt(ref, coords)
    if isOpen or busy or not ref or not CC.CanAct() then return end
    local res = lib.callback.await('MULTIcrafting:open', false, ref)
    if type(res) ~= 'table' or not res.ok then
        return CC.Notify(res and res.err or _L('err_no_station'), 'error')
    end
    current = { ref = ref, coords = coords or GetEntityCoords(CC.Ped()) }
    showState(res.state)
end

-- a server script opened the screen (exports.MULTIcrafting:OpenMenu)
RegisterNetEvent('MULTIcrafting:client:openState', function(state, ref)
    if isOpen or busy or type(state) ~= 'table' then return end
    current = { ref = ref, coords = GetEntityCoords(CC.Ped()) }
    showState(state)
end)

-- ------------------------------------------------------------
-- crafting with a progress bar
-- ------------------------------------------------------------
local function runCraft(info)
    local ped = CC.Ped()
    local start = GetEntityCoords(ped)
    CC.SetBusy(true)
    if Config.Craft.Unarm then SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true) end
    local st = Config.StationTypes[info.station] or {}
    local played = CC.PlayScenario(ped, st.scenario)
    SendNUIMessage({ action = 'progress', label = info.label, duration = info.duration })

    local key = keyOf(Config.Craft.CancelKey)
    local stopAt = GetGameTimer() + info.duration
    local cancelled = false
    while GetGameTimer() < stopAt do
        Wait(0)
        if key and (IsControlJustPressed(0, key) or IsDisabledControlJustPressed(0, key)) then cancelled = true break end
        if IsEntityDead(ped) or #(GetEntityCoords(ped) - start) > Config.Craft.CancelDistance then cancelled = true break end
    end
    if played then ClearPedTasks(ped) end
    SendNUIMessage({ action = 'progressEnd' })

    if cancelled then
        TriggerServerEvent('MULTIcrafting:server:cancel')
        CC.SetBusy(false)
        return false
    end
    local res
    for _ = 1, 4 do
        res = lib.callback.await('MULTIcrafting:finish', false)
        if not (type(res) == 'table' and res.err == 'err_too_early') then break end
        Wait(500)
    end
    CC.SetBusy(false)
    return type(res) == 'table' and res.ok
end

RegisterNUICallback('close', function(_, cb)
    closeMenu(true)
    cb({})
end)

RegisterNUICallback('craft', function(data, cb)
    if not isOpen or busy or type(data) ~= 'table' then return cb({ ok = false }) end
    local res = lib.callback.await('MULTIcrafting:start', false, tostring(data.id), tonumber(data.amount) or 1)
    if type(res) ~= 'table' or not res.ok then return cb({ ok = false, err = res and res.err }) end
    cb({ ok = true })
    closeMenu(false)
    local station = current
    CreateThread(function()
        local done = runCraft(res)
        if done and Config.Craft.ReopenMenu and station then
            Wait(250)
            CC.OpenAt(station.ref, station.coords)
        end
    end)
end)

RegisterNUICallback('putOut', function(data, cb)
    if not isOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    local ok = lib.callback.await('MULTIcrafting:putOut', false, tonumber(data.id))
    cb({ ok = ok == true })
    if ok then closeMenu(false) end
end)

-- walking away closes the screen
CreateThread(function()
    while true do
        Wait(500)
        if isOpen and current and current.coords and current.ref and current.ref.type ~= 'hand'
            and #(GetEntityCoords(CC.Ped()) - current.coords) > Config.CloseDistance then
            closeMenu(true)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) end
    if busy then ClearPedTasks(CC.Ped()) LocalPlayer.state:set('inv_busy', false, true) end
end)

exports('IsOpen', function() return isOpen end)
exports('IsCrafting', function() return busy end)
exports('Close', function() closeMenu(true) end)
--- Opens the crafting screen at the nearest station (or hand crafting).
exports('OpenNearest', function()
    local ref, coords = CC.NearestStation()
    if ref then CC.OpenAt(ref, coords) end
end)
--- Opens hand crafting (from the satchel).
exports('OpenHand', function() CC.OpenAt({ type = 'hand' }) end)
