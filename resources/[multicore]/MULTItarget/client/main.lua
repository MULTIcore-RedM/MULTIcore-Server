-- ============================================================
-- MULTItarget :: targeting (client)
-- Hold Left Alt: thin corner brackets show in the middle of the screen. Look at a person,
-- animal, wagon, object or counter and its options are listed beside them. Mouse wheel or
-- arrow keys move through the list, left mouse / E / Enter picks. Right mouse frees the
-- cursor to click an option instead (Esc or right mouse gives the camera back).
-- No marker dots are ever drawn in the world (RINGO's rule).
-- Written for MULTIcore (GPL v3).
-- ============================================================

local API = MT.API
local K = Config.Keys

local disabled = false      -- disableTargeting(true)
local active = false        -- targeting right now
local cursor = false        -- the mouse is free to click the list
local toggled = false       -- Config.Mode = 'toggle': Left Alt switches targeting on and off

local shown = {}            -- what the list shows now: { { option, zone } }
local shownKey = ''
local index = 1
local menu = nil            -- sub menu (openMenu / menuName) or nil
local hit = { entity = 0, coords = vector3(0, 0, 0), distance = 0.0 }

-- ------------------------------------------------------------
-- exports (MULTItarget, and ox_target's names for scripts written for ox_target)
-- ------------------------------------------------------------

function API.disableTargeting(state)
    disabled = state == true
    if disabled and active then MT.Stop() end
end

function API.isActive() return active end

local function Export(name, fn)
    exports(name, fn)
    AddEventHandler(('__cfx_export_ox_target_%s'):format(name), function(setCB) setCB(fn) end)
end

for name, fn in pairs(API) do Export(name, fn) end

-- ------------------------------------------------------------
-- may the player target now?
-- ------------------------------------------------------------
local function canTarget()
    if disabled or IsPauseMenuActive() or IsNuiFocused() then return false end
    if LocalPlayer.state.isLoggedIn == false then return false end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return false end
    local md = (MT.PlayerData() or {}).metadata or {}
    if md.isdead or md.ishandcuffed or md.inlaststand then return false end
    return true
end

-- ------------------------------------------------------------
-- the list on screen
-- ------------------------------------------------------------
local function iconOf(o)
    local i = tostring(o.icon or '')
    return i ~= '' and i or 'fa-solid fa-circle-dot'
end

local function send(title, sub)
    local items = {}
    for i, f in ipairs(shown) do
        local o = f.option
        items[i] = { label = tostring(o.label or o.name or '?'), icon = iconOf(o), description = o.description,
            iconColor = o.iconColor, sub = o.openMenu ~= nil }
    end
    if menu then items[#items + 1] = { label = _L('back'), icon = 'fa-solid fa-arrow-left', back = true } end
    SendNUIMessage({ action = 'list', items = items, index = index, title = title, sub = sub, found = #items > 0 })
end

local function listKey(list)
    local parts = {}
    for i, f in ipairs(list) do parts[i] = tostring(f.option) .. tostring(f.zone and f.zone.id or '') end
    return table.concat(parts, ',')
end

local function refresh(force)
    local list, title, sub = MT.Gather(hit.entity, hit.coords, hit.distance, menu)
    local key = listKey(list) .. '|' .. tostring(menu) .. '|' .. tostring(title)
    MT.HasOptions = #list > 0
    if not force and key == shownKey then return end
    shown, shownKey = list, key
    if #list == 0 and menu then menu = nil return refresh(true) end
    local total = #shown + (menu and 1 or 0)
    if index > total then index = math.max(1, total) end
    send(title, sub)
end

-- ------------------------------------------------------------
-- start / stop
-- ------------------------------------------------------------
local function askItemCounts()
    local names = {}
    for n in pairs(MT.ItemNames) do names[#names + 1] = n end
    if #names == 0 then return end
    CreateThread(function()
        local counts = lib.callback.await('MULTItarget:counts', false, names)
        if type(counts) == 'table' then MT.ItemCounts = counts end
    end)
end

function MT.Start()
    if active then return end
    active, cursor, menu, index = true, false, nil, 1
    shown, shownKey = {}, ''
    askItemCounts()
    SendNUIMessage({ action = 'on', scale = Config.Scale, text = _LT() })
end

function MT.Stop()
    if not active then return end
    active, toggled, menu = false, false, nil
    MT.HasOptions = false
    if cursor then SetNuiFocus(false, false) cursor = false end
    SendNUIMessage({ action = 'off' })
end

local function pick(i)
    if i == #shown + 1 and menu then
        menu, index = nil, 1
        return refresh(true)
    end
    local f = shown[i]
    if not f then return end
    local o = f.option
    if o.openMenu then
        menu, index = o.openMenu, 1
        return refresh(true)
    end
    local h = { entity = hit.entity, coords = hit.coords, distance = hit.distance, zone = f.zone }
    MT.Stop()
    local ok, err = pcall(MT.Run, o, h)
    if not ok then print(('^1[MULTItarget] option %s failed: %s^7'):format(tostring(o.name), tostring(err))) end
end

-- ------------------------------------------------------------
-- NUI (cursor mode)
-- ------------------------------------------------------------
RegisterNUICallback('pick', function(data, cb)
    cb('ok')
    local i = tonumber(data and data.index)
    if active and i then pick(i) end
end)

RegisterNUICallback('hover', function(data, cb)
    cb('ok')
    local i = tonumber(data and data.index)
    if active and i then index = i end
end)

RegisterNUICallback('release', function(_, cb)
    cb('ok')
    if cursor then
        cursor = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'cursor', on = false })
    end
end)

-- ------------------------------------------------------------
-- the loop
-- ------------------------------------------------------------
local function keyDown()
    if Config.Mode == 'toggle' then
        if IsControlJustPressed(0, K.Target) or IsDisabledControlJustPressed(0, K.Target) then toggled = not toggled end
        return toggled
    end
    return IsControlPressed(0, K.Target) or IsDisabledControlPressed(0, K.Target)
end

local function blockControls()
    for _, c in ipairs(K.Block) do DisableControlAction(0, c, true) end
    if cursor then
        DisableControlAction(0, K.LookLr, true)
        DisableControlAction(0, K.LookUd, true)
    end
end

local function pressed(list)
    for _, c in ipairs(list) do
        if IsDisabledControlJustPressed(0, c) or IsControlJustPressed(0, c) then return true end
    end
    return false
end

local function move(step)
    local total = #shown + (menu and 1 or 0)
    if total == 0 then return end
    index = ((index - 1 + step) % total) + 1
    SendNUIMessage({ action = 'index', index = index })
end

local nextRay = 0

CreateThread(function()
    while true do
        local held = keyDown()
        if not active then
            if held and canTarget() then MT.Start() else Wait(held and 100 or 0) end
        else
            if not cursor and (not held or not canTarget()) then
                MT.Stop()
            else
                blockControls()
                local now = GetGameTimer()
                if not cursor and now >= nextRay then
                    nextRay = now + Config.RayIntervalMs
                    local ok, entity, coords = lib.raycast.fromCamera(Config.RayFlags, 4, Config.RayDistance)
                    if ok and coords then
                        hit.entity = entity or 0
                        hit.coords = coords
                        hit.distance = #(GetEntityCoords(PlayerPedId()) - coords)
                    else
                        hit.entity, hit.distance = 0, 999.0
                    end
                    refresh(false)
                end
                if not cursor then
                    if pressed(K.Down) then move(1) elseif pressed(K.Up) then move(-1) end
                    if MT.HasOptions or menu then
                        if pressed(K.Select) then pick(index) end
                        if pressed(K.Cursor) then
                            cursor = true
                            SetNuiFocus(true, true)
                            SendNUIMessage({ action = 'cursor', on = true })
                        end
                    end
                end
            end
            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and cursor then SetNuiFocus(false, false) end
end)
