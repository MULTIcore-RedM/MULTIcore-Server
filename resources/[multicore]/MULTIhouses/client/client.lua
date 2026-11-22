-- ============================================================
-- MULTIhouses :: client
-- House points and doors through MULTItarget (hold Left Alt), or
-- hold-key prompts when MULTItarget is not running (Config.Interact,
-- @MULTIcore/lib/interact.lua). Nothing is drawn in the world.
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- ============================================================
local Core = exports.MULTIcore:GetCoreObject()

local Owned = {}        -- [houseid] = { owner, citizenid }
local Prices = {}       -- [houseid] = price
local Keys = {}         -- [houseid] = 'owner' | 'guest'
local DoorStates = {}   -- [doorid] = 1 locked / 0 open
local HouseBlips = {}
local isUIOpen = false
local robbing = nil     -- houseid of our running break-in
local picking = false
local zoneIds = {}
local promptNames = {}

local HouseCfg, DoorCfg = {}, {}
for _, h in ipairs(Config.Houses) do HouseCfg[h.houseid] = h end
for _, d in ipairs(Config.HouseDoors) do DoorCfg[d.doorid] = d end

local function dbg(...)
    if Config.Debug then print('[MULTIhouses]', ...) end
end

local function HouseName(houseid)
    local h = HouseCfg[houseid]
    if h and h.label and h.label ~= '' then return h.label end
    local n = tostring(houseid or ''):match('(%d+)$')
    return n and _L('house_name', n) or tostring(houseid)
end

local function notify(ntype, text)
    exports.MULTIcore:Notify({ title = _L('notify_title'), text = text, type = ntype })
end

local function cb(name, ...)
    return lib.callback.await('MULTIhouses:server:' .. name, false, ...)
end

---------------------------------
-- doors
-- 0xD99229FE93B46286 = _ADD_DOOR_TO_SYSTEM_NEW (door hash, ...)
-- 0x6BAB9442830C7F53 = DOOR_SYSTEM_SET_DOOR_STATE (door hash, 0 open / 1 locked)
---------------------------------
local function applyDoor(doorid, state)
    doorid = tonumber(doorid)
    state = tonumber(state) or 1
    if not doorid then return end
    DoorStates[doorid] = state
    Citizen.InvokeNative(0xD99229FE93B46286, doorid, 1, 1, 0, 0, 0, 0)
    Citizen.InvokeNative(0x6BAB9442830C7F53, doorid, state)
end

local function applyDoors(list)
    for _, d in ipairs(list or {}) do applyDoor(d.doorid, d.state) end
end

---------------------------------
-- blips
---------------------------------
local function updateBlips()
    for _, blip in pairs(HouseBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    HouseBlips = {}
    if not Config.ShowBlips then return end
    for _, h in ipairs(Config.Houses) do
        local show = h.showblip ~= false and h.blipcoords ~= nil
        if show and Config.OwnedHouseBlips and not Keys[h.houseid] then show = false end
        if show then
            local blip = BlipAddForCoords(Config.BlipStyle, h.blipcoords.x, h.blipcoords.y, h.blipcoords.z)
            if blip then
                local owner = Owned[h.houseid]
                if owner then
                    SetBlipSprite(blip, joaat(Config.BlipOwned), true)
                    SetBlipScale(blip, Config.BlipScaleOwned)
                    BlipAddModifier(blip, joaat('BLIP_MODIFIER_MP_COLOR_8'))
                    SetBlipName(blip, _L('blip_owned', owner.owner ~= '' and owner.owner or _L('blip_unknown_owner')))
                else
                    SetBlipSprite(blip, joaat(Config.BlipForSale), true)
                    SetBlipScale(blip, Config.BlipScaleForSale)
                    BlipAddModifier(blip, joaat('BLIP_MODIFIER_MP_COLOR_1'))
                    SetBlipName(blip, _L('blip_for_sale', HouseName(h.houseid)))
                end
                HouseBlips[h.houseid] = blip
            end
        end
    end
end

---------------------------------
-- state from the server
---------------------------------
local function refreshAll()
    local s = cb('GetState')
    if not s then return end
    Owned = s.owned or {}
    Prices = s.prices or {}
    Keys = s.keys or {}
    applyDoors(s.doors)
    if s.robbing and not robbing then robbing = s.robbing end
    updateBlips()
end

local function refreshKeys()
    Keys = cb('GetKeys') or {}
    updateBlips()
end

RegisterNetEvent('MULTIhouses:client:owned', function(owned)
    Owned = owned or {}
    updateBlips()
end)

RegisterNetEvent('MULTIhouses:client:door', function(doorid, state) applyDoor(doorid, state) end)
RegisterNetEvent('MULTIhouses:client:doors', function(list) applyDoors(list) end)
RegisterNetEvent('MULTIhouses:client:keysChanged', function() refreshKeys() end)

-- logged in (MULTIcore sets LocalPlayer.state.isLoggedIn) and every few seconds the door states again
CreateThread(function()
    local wasIn = false
    local nextDoors = 0
    while true do
        local isIn = LocalPlayer.state.isLoggedIn == true
        if isIn and not wasIn then
            Wait(1000)
            refreshAll()
            nextDoors = GetGameTimer() + Config.DoorRefreshSeconds * 1000
        elseif not isIn and wasIn then
            Keys = {}
            robbing = nil
            updateBlips()
        elseif isIn and GetGameTimer() > nextDoors then
            applyDoors(cb('GetDoors'))
            nextDoors = GetGameTimer() + Config.DoorRefreshSeconds * 1000
        end
        wasIn = isIn
        Wait(1000)
    end
end)

---------------------------------
-- animations
---------------------------------
local KEY_DICT = 'script_common@jail_cell@unlock@key'

local function loadDict()
    local ok = pcall(lib.requestAnimDict, KEY_DICT, 2000)
    return ok and HasAnimDictLoaded(KEY_DICT)
end

local function keyAnimation()
    local ped = PlayerPedId()
    if not loadDict() then return end
    local prop = CreateObject(joaat('P_KEY02X'), GetEntityCoords(ped) + vector3(0.0, 0.0, 0.2), true, true, true)
    TaskPlayAnim(ped, KEY_DICT, 'action', 8.0, -8.0, 2500, 31, 0, true, 0, false, 0, false)
    Wait(750)
    AttachEntityToEntity(prop, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_Finger12'), 0.02, 0.0120, -0.00850, 0.024, -160.0, 200.0, true, true, false, true, 1, true)
    while IsEntityPlayingAnim(ped, KEY_DICT, 'action', 3) do Wait(100) end
    DeleteObject(prop)
end

local function pickAnimation()
    if loadDict() then
        TaskPlayAnim(PlayerPedId(), KEY_DICT, 'action', 8.0, -8.0, -1, 1, 0, true, 0, false, 0, false)
    end
end

---------------------------------
-- NUI
---------------------------------
local function sendLocale()
    SendNUIMessage({ action = 'setLocale', locale = _LT(), lang = _LCode() })
end

local function openNui(menu, data)
    sendLocale()
    SendNUIMessage({ action = 'openMenu', menu = menu, data = data })
    SetNuiFocus(true, true)
    isUIOpen = true
end

local function closeNui()
    isUIOpen = false
    SendNUIMessage({ action = 'closeMenu' })
    SetNuiFocus(false, false)
end

local function openBuy(houseid)
    if Owned[houseid] then notify('error', _L('already_owned')) return end
    local info = cb('GetBuyInfo', houseid)
    if not info or (info.price or 0) <= 0 then notify('error', _L('not_for_sale')) return end
    info.houseId = houseid
    info.houseName = HouseName(houseid)
    openNui('buyAtHouse', info)
end

local function openHouseMenu(houseid)
    local m, err = cb('GetMenu', houseid)
    if not m then notify('error', _L(err or 'no_key')) return end
    openNui('houseMenu', {
        houseId = houseid,
        houseName = HouseName(houseid),
        isGuest = m.isGuest,
        isAdmin = m.isAdmin,
        hasBalance = m.hasBalance,
    })
end

RegisterNUICallback('closeUI', function(_, done)
    isUIOpen = false
    SetNuiFocus(false, false)
    done('ok')
end)

RegisterNUICallback('buyHouse', function(data, done)
    closeNui()
    done('ok')
    TriggerServerEvent('MULTIhouses:server:buy', data.house)
end)

RegisterNUICallback('sellHouse', function(data, done)
    closeNui()
    done('ok')
    TriggerServerEvent('MULTIhouses:server:sell', data.house)
end)

RegisterNUICallback('getSellInfo', function(data, done)
    done('ok')
    local info = cb('GetSellInfo', data.house)
    if not info then return end
    SendNUIMessage({
        action = 'showSellConfirm',
        houseId = data.house,
        houseName = HouseName(data.house),
        sellprice = info.sellprice,
        balance = info.balance,
        payout = info.payout,
    })
end)

RegisterNUICallback('openStorage', function(data, done)
    closeNui()
    done('ok')
    TriggerServerEvent('MULTIhouses:server:openStorage', data.house)
end)

RegisterNUICallback('openOutfits', function(data, done)
    closeNui()
    done('ok')
    TriggerServerEvent('MULTIhouses:server:outfits', data.house)
end)

RegisterNUICallback('openMail', function(_, done)
    closeNui()
    done('ok')
    Wait(100)
    TriggerEvent('MULTItelegram:client:open', 'inbox')
end)

-- kept for pages that add a tax office button: opens MULTIjobs' boss menu
RegisterNUICallback('openTaxOffice', function(_, done)
    closeNui()
    done('ok')
    Wait(100)
    TriggerEvent('MULTIjobs:client:openBoss')
end)

local function sendGuests(houseid)
    SendNUIMessage({ action = 'updateGuests', guests = cb('GetGuests', houseid) or {}, houseId = houseid })
end

RegisterNUICallback('addGuest', function(data, done)
    done('ok')
    local ok = cb('AddGuest', data.houseid, data.citizenid)
    if ok then sendGuests(data.houseid) end
end)

RegisterNUICallback('removeGuest', function(data, done)
    done('ok')
    cb('RemoveGuest', data.houseid, data.citizenid)
    sendGuests(data.houseid)
end)

RegisterNUICallback('getGuests', function(data, done)
    done('ok')
    sendGuests(data.houseid)
end)

RegisterNUICallback('getCredit', function(data, done)
    done('ok')
    local info = cb('GetMoneyInfo', data.houseid)
    if not info then return end
    SendNUIMessage({ action = 'updateCredit', houseId = data.houseid, houseName = HouseName(data.houseid), credit = info.credit })
end)

RegisterNUICallback('getBalance', function(data, done)
    done('ok')
    local info = cb('GetMoneyInfo', data.houseid)
    if not info then return end
    SendNUIMessage({ action = 'updateBalance', houseId = data.houseid, houseName = HouseName(data.houseid), balance = info.balance })
end)

RegisterNUICallback('addCredit', function(data, done)
    closeNui()
    done('ok')
    TriggerServerEvent('MULTIhouses:server:addCredit', data.houseid, tonumber(data.amount))
end)

RegisterNUICallback('removeCredit', function(data, done)
    closeNui()
    done('ok')
    TriggerServerEvent('MULTIhouses:server:removeCredit', data.houseid, tonumber(data.amount))
end)

RegisterNUICallback('payBalance', function(data, done)
    closeNui()
    done('ok')
    TriggerServerEvent('MULTIhouses:server:payBalance', data.houseid, tonumber(data.amount))
end)

RegisterNUICallback('releaseHouse', function(data, done)
    closeNui()
    done('ok')
    TriggerServerEvent('MULTIhouses:server:release', data.houseid)
end)

---------------------------------
-- doors: lock / unlock
---------------------------------
local function toggleDoor(doorid)
    local d = DoorCfg[doorid]
    if not d or not Keys[d.houseid] then notify('error', _L('no_key')) return end
    keyAnimation()
    TriggerServerEvent('MULTIhouses:server:toggleDoor', doorid)
end

---------------------------------
-- break-ins
---------------------------------
local function houseCoords(houseid)
    local h = HouseCfg[houseid]
    return h and h.menucoords
end

local function endRobbery(silent)
    if not robbing then return end
    local houseid = robbing
    robbing = nil
    TriggerServerEvent('MULTIhouses:server:endRobbery', houseid)
    if not silent then notify('info', _L('robbery_ended')) end
end

RegisterNetEvent('MULTIhouses:client:robberyEnded', function(houseid)
    if robbing == houseid then
        robbing = nil
        notify('info', _L('robbery_relocked'))
    end
end)

RegisterNetEvent('MULTIhouses:client:robberyStarted', function(houseid)
    if not HouseCfg[houseid] then return end
    robbing = houseid
    notify('info', _L('robbery_search'))
    CreateThread(function()
        local started = GetGameTimer()
        local limit = (Config.Robbery.RobberyMinutes or 5) * 60 * 1000
        local warned = false
        while robbing == houseid do
            Wait(1000)
            local elapsed = GetGameTimer() - started
            if not warned and elapsed > limit - 60000 then
                warned = true
                notify('warning', _L('robbery_one_minute'))
            end
            local c = houseCoords(houseid)
            if c and #(GetEntityCoords(PlayerPedId()) - c) > (Config.Robbery.LeaveDistance or 50.0) then
                endRobbery(true)
                notify('info', _L('robbery_left'))
                break
            end
            if elapsed > limit then
                endRobbery(true)
                notify('error', _L('robbery_time_up'))
                break
            end
        end
    end)
end)

local function attemptLockpick(houseid, doorid)
    if picking or robbing then return end
    local ok, msg = cb('CanLockpick', houseid, doorid)
    if not ok then notify('error', msg or _L('cannot_pick')) return end
    if not cb('StartPick', houseid, doorid) then return end
    picking = true
    pickAnimation()
    local done = lib.progressBar({
        duration = (Config.Robbery.PickSeconds or 30) * 1000,
        label = _L('picking_lock'),
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
    })
    local success = false
    if done then
        success = lib.skillCheck(Config.Robbery.SkillCheck or { 'easy' }, Config.Robbery.SkillKeys or { 'w' }) == true
    else
        notify('error', _L('pick_cancelled'))
    end
    ClearPedTasks(PlayerPedId())
    TriggerServerEvent('MULTIhouses:server:finishPick', success)
    picking = false
end

---------------------------------
-- the house point and the doors: MULTItarget zones or prompts
---------------------------------
local function usePoint(houseid)
    if robbing == houseid then
        TriggerServerEvent('MULTIhouses:server:robberyLoot', houseid)
    elseif Keys[houseid] then
        openHouseMenu(houseid)
    elseif not Owned[houseid] then
        openBuy(houseid)
    else
        notify('error', _L('owned_by_other'))
    end
end

local function useDoor(doorid)
    local d = DoorCfg[doorid]
    if not d then return end
    if Keys[d.houseid] and Owned[d.houseid] then
        toggleDoor(doorid)
    elseif Config.Robbery.Enabled and (DoorStates[doorid] or 1) == 1 then
        attemptLockpick(d.houseid, doorid)
    end
end

AddEventHandler('MULTIhouses:client:housePoint', usePoint)
AddEventHandler('MULTIhouses:client:doorPoint', useDoor)

MCI.Run(Config.Interact, function(mode)
    if mode == 'prompt' then
        for _, h in ipairs(Config.Houses) do
            local name = 'multihouses_house_' .. h.houseid
            MCI.AddPrompt(name, h.menucoords, Config.HouseKey, _L('prompt_house', HouseName(h.houseid)), {
                type = 'client', event = 'MULTIhouses:client:housePoint', args = { h.houseid },
            }, Config.PromptDistance)
            promptNames[#promptNames + 1] = name
        end
        for _, d in ipairs(Config.HouseDoors) do
            local name = 'multihouses_door_' .. d.doorid
            MCI.AddPrompt(name, d.doorcoords, Config.DoorKey, _L('prompt_door'), {
                type = 'client', event = 'MULTIhouses:client:doorPoint', args = { d.doorid },
            }, Config.PromptDistance)
            promptNames[#promptNames + 1] = name
        end
        return
    end

    for _, h in ipairs(Config.Houses) do
        local houseid = h.houseid
        zoneIds[#zoneIds + 1] = MCI.AddZone({
            coords = h.menucoords,
            radius = Config.TargetRadius,
            options = {
                {
                    name = 'multihouses_buy',
                    icon = 'fas fa-house',
                    label = _L('target_buy'),
                    distance = Config.TargetDistance,
                    canInteract = function() return not Owned[houseid] and (Prices[houseid] or 0) > 0 and not Keys[houseid] end,
                    onSelect = function() openBuy(houseid) end,
                },
                {
                    name = 'multihouses_menu',
                    icon = 'fas fa-house-user',
                    label = _L('target_menu'),
                    distance = Config.TargetDistance,
                    canInteract = function() return Keys[houseid] ~= nil end,
                    onSelect = function() openHouseMenu(houseid) end,
                },
                {
                    name = 'multihouses_loot',
                    icon = 'fas fa-box-open',
                    label = _L('target_loot'),
                    distance = Config.TargetDistance,
                    canInteract = function() return robbing == houseid end,
                    onSelect = function() TriggerServerEvent('MULTIhouses:server:robberyLoot', houseid) end,
                },
            },
        })
    end

    for _, d in ipairs(Config.HouseDoors) do
        local doorid, houseid = d.doorid, d.houseid
        zoneIds[#zoneIds + 1] = MCI.AddZone({
            coords = d.doorcoords,
            radius = Config.TargetRadius,
            options = {
                {
                    name = 'multihouses_door',
                    icon = 'fas fa-key',
                    label = _L('target_door'),
                    distance = Config.TargetDistance,
                    canInteract = function() return Keys[houseid] ~= nil and Owned[houseid] ~= nil end,
                    onSelect = function() toggleDoor(doorid) end,
                },
                {
                    name = 'multihouses_pick',
                    icon = 'fas fa-unlock',
                    label = _L('target_pick'),
                    distance = Config.TargetDistance,
                    canInteract = function()
                        if not Config.Robbery.Enabled or picking or robbing or Keys[houseid] then return false end
                        if Config.Robbery.OnlyRobOwnedHouses and not Owned[houseid] then return false end
                        return (DoorStates[doorid] or 1) == 1
                    end,
                    onSelect = function() attemptLockpick(houseid, doorid) end,
                },
            },
        })
    end
    dbg(('%d MULTItarget points made'):format(#zoneIds))
end, function()
    for _, id in ipairs(zoneIds) do MCI.RemoveZone(id) end
    zoneIds = {}
    for _, name in ipairs(promptNames) do MCI.RemovePrompt(name) end
    promptNames = {}
end)

---------------------------------
-- commands
---------------------------------
local C = Config.Commands or {}

if C.endRobbery and C.endRobbery ~= '' then
    RegisterCommand(C.endRobbery, function() endRobbery(false) end, false)
end

if C.fixNui and C.fixNui ~= '' then
    RegisterCommand(C.fixNui, function() closeNui() end, false)
end

if C.releaseHouse and C.releaseHouse ~= '' then
    RegisterCommand(C.releaseHouse, function(_, args)
        local arg = args[1] == 'house' and args[2] or args[1]
        local n = arg and tostring(arg):match('(%d+)$')
        if not n then notify('error', _L('release_usage', C.releaseHouse)) return end
        TriggerServerEvent('MULTIhouses:server:release', 'house' .. n)
    end, false)
end

if C.removeHouse and C.removeHouse ~= '' then
    RegisterCommand(C.removeHouse, function(_, args)
        local houseid = args[1]
        if not houseid then
            local input = lib.inputDialog(_L('admin_remove_title'), {
                { type = 'input', label = _L('admin_remove_label'), placeholder = 'house10', required = true },
            })
            houseid = input and input[1]
        end
        if houseid and houseid ~= '' then
            if tostring(houseid):match('^%d+$') then houseid = 'house' .. houseid end
            TriggerServerEvent('MULTIhouses:server:adminRemove', houseid)
        end
    end, false)
end

---------------------------------
-- start / stop
---------------------------------
AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    sendLocale()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in pairs(HouseBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    if isUIOpen then closeNui() end
end)
