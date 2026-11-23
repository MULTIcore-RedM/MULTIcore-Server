-- ============================================================
-- MULTIhotel :: client
-- The front desk and the room menu through MULTItarget (hold Left Alt),
-- or hold-key prompts when MULTItarget is not running (Config.Interact,
-- @MULTIcore/lib/interact.lua). Nothing is drawn in the world.
-- Part of MULTIcore by RINGO (RINGOscripting), GPL v3.
-- ============================================================

local isMenuOpen = false
local inRoom = nil            -- hotel id of the room we stand in
local pendingInput = nil      -- { type = 'addCredit' | 'removeCredit', credit = n }
local pendingConfirm = nil    -- { type = 'evict' }
local blips = {}
local zoneIds = {}
local promptNames = {}

local HotelCfg = {}
for _, h in ipairs(Config.Hotels) do HotelCfg[h.id] = h end

local function dbg(...)
    if Config.Debug then print('[MULTIhotel]', ...) end
end

local function hotelName(id)
    local h = HotelCfg[id]
    if not h then return tostring(id) end
    local label = h.label or id
    if label:sub(1, 6) == 'hotel_' then return _L(label) end
    return label
end

local function notify(ntype, key, ...)
    exports.MULTIcore:Notify({ title = _L('notify_title'), text = _L(key, ...), type = ntype })
end

local function cb(name, ...)
    return lib.callback.await('MULTIhotel:server:' .. name, false, ...)
end

-- MULTItelegram, or MULTIp_telegram when that one runs instead
local function telegramResource()
    for _, res in ipairs({ 'MULTItelegram', 'MULTIp_telegram' }) do
        if GetResourceState(res) == 'started' then return res end
    end
end

---------------------------------
-- NUI
---------------------------------
local function openUI(menu)
    if isMenuOpen then
        SendNUIMessage({ action = 'closeMenu' })
        Wait(50)
    end
    isMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openMenu',
        title = menu.title,
        subtitle = menu.subtitle,
        badge = menu.badge,
        options = menu.options,
        menuId = menu.menuId,
        showBack = menu.showBack or false,
        L = _LT(),
        lang = _LCode(),
    })
end

local function closeUI()
    isMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
end

---------------------------------
-- moving in and out
---------------------------------
local function teleport(c)
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    Wait(1000)
    -- 0x203BEFFDBE12E96A = _SET_ENTITY_COORDS_AND_HEADING
    Citizen.InvokeNative(0x203BEFFDBE12E96A, ped, c.x, c.y, c.z, c.w, false, false, false)
    Wait(1500)
    DoScreenFadeIn(1800)
end

RegisterNetEvent('MULTIhotel:client:enter', function(location)
    local h = HotelCfg[location]
    if not h then return end
    closeUI()
    inRoom = location
    teleport(h.spawn)
end)

RegisterNetEvent('MULTIhotel:client:exit', function(location, reason, ownerName, roomid)
    local h = HotelCfg[location]
    inRoom = nil
    closeUI()
    if reason == 'evicted' then
        notify('error', 'you_were_evicted', ownerName or '')
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.3)
    elseif reason == 'lost' then
        notify('error', 'room_lost', roomid or '')
    end
    if h then teleport(h.exit) end
end)

---------------------------------
-- desk menu
---------------------------------
local function openDesk(location)
    if isMenuOpen or inRoom then return end
    if GetResourceState('MULTIhorses') == 'started' then TriggerEvent('MULTIhorses:client:FleeHorse') end
    local d = cb('GetDesk', location)
    if not d then return end
    local options = {}
    if d.hasRoom then
        options[#options + 1] = {
            id = 'checkin', title = _L('menu_check_in'), description = _L('menu_check_in_desc', d.roomid, d.credit),
            action = 'checkIn', args = { location = location },
        }
    else
        options[#options + 1] = {
            id = 'rent', title = _L('menu_rent', d.price), description = _L('menu_rent_desc'),
            action = 'rent', args = { location = location },
        }
    end
    if d.isGuest then
        options[#options + 1] = {
            id = 'guestcheckin', title = _L('menu_guest_check_in'), description = _L('menu_guest_check_in_desc'),
            action = 'guestCheckIn', args = { location = location },
        }
    end
    openUI({ title = hotelName(location), menuId = 'desk', options = options })
end

---------------------------------
-- room menu
---------------------------------
local function openRoom()
    if isMenuOpen or not inRoom then return end
    local r = cb('GetRoom')
    if not r then notify('error', 'no_active_room') return end
    local options = {}
    if r.isOwner then
        options[#options + 1] = {
            id = 'addcredit', title = _L('menu_add_credit'), description = _L('menu_credit_now', r.credit),
            action = 'addCredit', args = { credit = r.credit },
        }
        options[#options + 1] = {
            id = 'removecredit', title = _L('menu_remove_credit'), description = _L('menu_remove_credit_desc'),
            action = 'removeCredit', args = { credit = r.credit },
        }
        options[#options + 1] = {
            id = 'guests', title = _L('menu_guests'), description = _L('menu_guests_desc'), arrow = true,
            action = 'guests',
        }
        options[#options + 1] = {
            id = 'evict', title = _L('menu_evict'), description = _L('menu_evict_desc'),
            action = 'evict',
        }
        options[#options + 1] = {
            id = 'locker', title = _L('menu_locker'), description = _L('menu_locker_desc'),
            action = 'locker',
        }
    else
        options[#options + 1] = {
            id = 'guestinfo', title = _L('menu_guest_access'), description = _L('menu_owner', r.owner), disabled = true,
        }
    end
    options[#options + 1] = { separator = true }
    options[#options + 1] = {
        id = 'leave', title = _L('menu_leave'), description = _L('menu_leave_desc'),
        action = 'leave',
    }
    if telegramResource() then
        options[#options + 1] = {
            id = 'mail', title = _L('menu_mail'), description = _L('menu_mail_desc'), arrow = true,
            action = 'mail',
        }
    end
    openUI({
        title = _L('room_title', r.roomid),
        subtitle = hotelName(r.location),
        badge = (not r.isOwner) and _L('badge_guest') or nil,
        menuId = 'room',
        options = options,
    })
end

local function openGuests()
    local guests = cb('GetGuests')
    if not guests then return end
    local options = {
        {
            id = 'addguest', title = _L('menu_add_guest'), description = _L('menu_add_guest_desc'), arrow = true,
            action = 'invite',
        },
        { separator = true, label = _L('menu_current_guests') },
    }
    if #guests == 0 then
        options[#options + 1] = { id = 'none', title = _L('menu_no_guests'), description = _L('menu_no_guests_desc'), disabled = true }
    end
    for _, g in ipairs(guests) do
        options[#options + 1] = {
            id = 'guest_' .. g.id, title = g.name, description = _L('menu_guest_row', g.added),
            action = 'removeGuest', args = { id = g.id },
        }
    end
    openUI({ title = _L('menu_guests'), menuId = 'guests', showBack = true, options = options })
end

local function openInvite()
    local players = cb('GetNearby') or {}
    if #players == 0 then notify('error', 'nobody_near') return end
    local options = {}
    for _, p in ipairs(players) do
        options[#options + 1] = {
            id = 'player_' .. p.id, title = p.name, description = _L('menu_invite_row', p.id),
            action = 'addGuest', args = { id = p.id },
        }
    end
    openUI({ title = _L('menu_invite'), menuId = 'invite', showBack = true, options = options })
end

local function openEvictConfirm()
    local count = cb('GuestCount') or 0
    if count == 0 then notify('info', 'no_guests_to_evict') return end
    pendingConfirm = { type = 'evict' }
    SendNUIMessage({
        action = 'openConfirmDialog',
        title = _L('menu_evict'),
        message = _L('evict_confirm', count),
        L = _LT(), lang = _LCode(),
    })
end

local function openAmount(kind, credit)
    pendingInput = { type = kind, credit = credit or 0 }
    local add = kind == 'addCredit'
    SendNUIMessage({
        action = 'openInputDialog',
        title = add and _L('menu_add_credit') or _L('menu_remove_credit'),
        label = _L(add and 'input_add_label' or 'input_remove_label', credit or 0),
        placeholder = '0',
        min = 1,
        max = add and math.max(1, Config.MaxCredit - (credit or 0)) or math.max(1, credit or 0),
        L = _LT(), lang = _LCode(),
    })
end

---------------------------------
-- NUI callbacks
---------------------------------
RegisterNUICallback('menuOptionSelected', function(data, done)
    done('ok')
    local action, args = data.action, data.args or {}
    if action == 'rent' then
        closeUI() TriggerServerEvent('MULTIhotel:server:rent', args.location)
    elseif action == 'checkIn' then
        closeUI() TriggerServerEvent('MULTIhotel:server:checkIn', args.location)
    elseif action == 'guestCheckIn' then
        closeUI() TriggerServerEvent('MULTIhotel:server:guestCheckIn', args.location)
    elseif action == 'addCredit' or action == 'removeCredit' then
        openAmount(action, tonumber(args.credit) or 0)
    elseif action == 'guests' then
        openGuests()
    elseif action == 'invite' then
        openInvite()
    elseif action == 'addGuest' then
        closeUI() TriggerServerEvent('MULTIhotel:server:addGuest', args.id)
    elseif action == 'removeGuest' then
        TriggerServerEvent('MULTIhotel:server:removeGuest', args.id)
        Wait(400)
        openGuests()
    elseif action == 'evict' then
        openEvictConfirm()
    elseif action == 'locker' then
        closeUI() Wait(100) TriggerServerEvent('MULTIhotel:server:storage')
    elseif action == 'leave' then
        closeUI() TriggerServerEvent('MULTIhotel:server:leave')
    elseif action == 'mail' then
        local res = telegramResource()
        closeUI() Wait(100)
        if res then TriggerEvent(res .. ':client:open', 'inbox') end
    end
end)

RegisterNUICallback('closeMenu', function(_, done)
    done('ok')
    isMenuOpen = false
    SetNuiFocus(false, false)
end)

RegisterNUICallback('goBack', function(data, done)
    done('ok')
    isMenuOpen = false
    if data.previousMenu == 'room' then openRoom()
    elseif data.previousMenu == 'guests' then openGuests() end
end)

RegisterNUICallback('inputSubmitted', function(data, done)
    done('ok')
    isMenuOpen = false
    SetNuiFocus(false, false)
    local p = pendingInput
    pendingInput = nil
    local amount = tonumber(data.value)
    if not p or not amount then return end
    if p.type == 'addCredit' then
        TriggerServerEvent('MULTIhotel:server:addCredit', amount)
    elseif p.type == 'removeCredit' then
        TriggerServerEvent('MULTIhotel:server:removeCredit', amount)
    end
end)

RegisterNUICallback('inputCancelled', function(_, done)
    done('ok')
    isMenuOpen = false
    SetNuiFocus(false, false)
    pendingInput = nil
end)

RegisterNUICallback('confirmAccepted', function(_, done)
    done('ok')
    isMenuOpen = false
    SetNuiFocus(false, false)
    if pendingConfirm and pendingConfirm.type == 'evict' then
        TriggerServerEvent('MULTIhotel:server:evict')
    end
    pendingConfirm = nil
end)

RegisterNUICallback('confirmCancelled', function(_, done)
    done('ok')
    isMenuOpen = false
    SetNuiFocus(false, false)
    pendingConfirm = nil
end)

---------------------------------
-- blips and doors
---------------------------------
CreateThread(function()
    for _, h in ipairs(Config.Hotels) do
        if h.blip then
            local blip = BlipAddForCoords(Config.Blip.style, h.desk.x, h.desk.y, h.desk.z)
            SetBlipSprite(blip, joaat(Config.Blip.sprite), true)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipName(blip, hotelName(h.id))
            blips[#blips + 1] = blip
        end
    end
    if Config.LockDoors then
        for _, door in ipairs(Config.HotelDoors) do
            -- 0xD99229FE93B46286 = _ADD_DOOR_TO_SYSTEM_NEW, 0x6BAB9442830C7F53 = DOOR_SYSTEM_SET_DOOR_STATE (1 = locked)
            Citizen.InvokeNative(0xD99229FE93B46286, door, 1, 1, 0, 0, 0, 0)
            Citizen.InvokeNative(0x6BAB9442830C7F53, door, 1)
        end
    end
end)

---------------------------------
-- desk and room points
---------------------------------
AddEventHandler('MULTIhotel:client:desk', function(location) openDesk(location) end)
AddEventHandler('MULTIhotel:client:room', function() openRoom() end)

MCI.Run(Config.Interact, function(mode)
    if mode == 'prompt' then
        for _, h in ipairs(Config.Hotels) do
            local desk = 'multihotel_desk_' .. h.id
            MCI.AddPrompt(desk, h.desk, Config.Key, _L('prompt_desk', hotelName(h.id)), {
                type = 'client', event = 'MULTIhotel:client:desk', args = { h.id },
            }, Config.PromptDistance)
            promptNames[#promptNames + 1] = desk
            local room = 'multihotel_room_' .. h.id
            MCI.AddPrompt(room, h.room, Config.Key, _L('prompt_room'), {
                type = 'client', event = 'MULTIhotel:client:room', args = {},
            }, Config.PromptDistance)
            promptNames[#promptNames + 1] = room
        end
        return
    end

    for _, h in ipairs(Config.Hotels) do
        local id = h.id
        zoneIds[#zoneIds + 1] = MCI.AddZone({
            coords = h.desk,
            radius = Config.TargetRadius,
            options = {
                {
                    name = 'multihotel_desk',
                    icon = 'fas fa-concierge-bell',
                    label = _L('target_desk'),
                    distance = Config.TargetDistance,
                    canInteract = function() return inRoom == nil end,
                    onSelect = function() openDesk(id) end,
                },
            },
        })
        zoneIds[#zoneIds + 1] = MCI.AddZone({
            coords = h.room,
            radius = Config.TargetRadius,
            options = {
                {
                    name = 'multihotel_room',
                    icon = 'fas fa-bed',
                    label = _L('target_room'),
                    distance = Config.TargetDistance,
                    canInteract = function() return inRoom == id end,
                    onSelect = function() openRoom() end,
                },
            },
        })
    end
    dbg(('%d MULTItarget points made'):format(#zoneIds))
end, function()
    for _, zid in ipairs(zoneIds) do MCI.RemoveZone(zid) end
    zoneIds = {}
    for _, name in ipairs(promptNames) do MCI.RemovePrompt(name) end
    promptNames = {}
end)

---------------------------------
-- commands
---------------------------------
local C = Config.Commands or {}
if C.fixNui and C.fixNui ~= '' then
    RegisterCommand(C.fixNui, function() closeUI() end, false)
end

---------------------------------
-- stop
---------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    if isMenuOpen then closeUI() end
    -- the server puts us back in the open world; walk out of the room too
    local h = inRoom and HotelCfg[inRoom]
    if h then
        SetEntityCoords(PlayerPedId(), h.exit.x, h.exit.y, h.exit.z, false, false, false, false)
        DoScreenFadeIn(0)
    end
end)
