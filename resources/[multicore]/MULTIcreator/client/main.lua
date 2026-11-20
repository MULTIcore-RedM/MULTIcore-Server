-- ============================================================
-- MULTIcreator :: client
-- exports.MULTIcreator:Open(mode, cb)
--   'create' : full creator + identity form, cb(look, info) or cb(nil) on cancel
--   'barber' : hair, beard, eyebrows and make-up only, pays and saves, cb(true / false)
-- The ped is dressed through MULTIcore's look library (exports.MULTIcore:*).
-- ============================================================

local MC = exports.MULTIcore

local S = {
    open = false,
    mode = nil,
    cb = nil,
    cam = nil,
    base = nil,        -- { pos = vector3, heading = number } the camera is built from
    zone = 'body',
    zoom = 0.0,
    pending = nil,     -- latest apply request from the page
    original = nil,    -- barber: the look before any change
    shop = nil,        -- barber: shop entry (for the light and the server range check)
    returnTo = nil,    -- barber: where to put the player back
}

local function dbg(...)
    if Config.Debug then print('[MULTIcreator]', ...) end
end

local function notify(text, kind)
    MC:Notify(text, kind or 'info', Config.Timing.notifyMs)
end

local function fade(out, ms)
    if out then
        DoScreenFadeOut(ms)
        local t = GetGameTimer() + ms + Config.Timing.fadeGraceMs
        while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end
    else
        DoScreenFadeIn(ms)
    end
end

-- ---------------------------------------------------------------
-- camera
-- ---------------------------------------------------------------

local function camPoint(zone)
    local c = Config.Cameras[zone] or Config.Cameras.body
    local h = math.rad(S.base.heading)
    local fx, fy = -math.sin(h), math.cos(h)   -- the way the ped faced when the creator opened
    local rx, ry = math.cos(h), math.sin(h)
    local d = c.dist + S.zoom
    local p = S.base.pos
    local from = vector3(p.x + fx * d + rx * c.side, p.y + fy * d + ry * c.side, p.z + c.z)
    local at = vector3(p.x, p.y, p.z + c.lookZ)
    return from, at, c.fov
end

local function setCamera(zone, interp)
    S.zone = Config.Cameras[zone] and zone or 'body'
    local from, at, fov = camPoint(S.zone)
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true) -- UNVERIFIED cam name (not in natives.json; used across RedM scripts)
    SetCamCoord(cam, from.x, from.y, from.z)
    PointCamAtCoord(cam, at.x, at.y, at.z)
    SetCamFov(cam, fov)
    local old = S.cam
    if old and interp then
        SetCamActiveWithInterp(cam, old, Config.CameraInterpMs, 1, 1)
        local toDestroy = old
        SetTimeout(Config.CameraInterpMs + 100, function()
            if DoesCamExist(toDestroy) then DestroyCam(toDestroy, false) end
        end)
    else
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true, 0)
        if old and DoesCamExist(old) then DestroyCam(old, false) end
    end
    S.cam = cam
end

local function dropCamera()
    RenderScriptCams(false, false, 0, true, true, 0)
    if S.cam and DoesCamExist(S.cam) then DestroyCam(S.cam, false) end
    S.cam = nil
end

-- ---------------------------------------------------------------
-- ped placement
-- ---------------------------------------------------------------

local function placePed(ped, pos4)
    SetEntityCoordsNoOffset(ped, pos4.x, pos4.y, pos4.z, false, false, false)
    SetEntityHeading(ped, pos4.w)
    ClearPedTasksImmediately(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
end

-- the creator room: the game draws it only while its map pieces are loaded
-- natives (femga natives.json): IS_IPL_ACTIVE_HASH 0xD779B9B910BD3B7C, REQUEST_IPL_HASH 0x59767C5A7A9AE6DA, REMOVE_IPL_HASH 0x5A3E5CF7B4014B96
local roomLoadedByUs = {}
local function loadRoom()
    for _, h in ipairs(Config.Room.imaps or {}) do
        if not Citizen.InvokeNative(0xD779B9B910BD3B7C, h) then
            Citizen.InvokeNative(0x59767C5A7A9AE6DA, h)
            roomLoadedByUs[h] = true
        end
    end
end
local function unloadRoom()
    if Config.Room.keepLoaded then return end   -- RSG keeps the room loaded all the time; so do we by default
    for h in pairs(roomLoadedByUs) do Citizen.InvokeNative(0x5A3E5CF7B4014B96, h) end
    roomLoadedByUs = {}
end
local function roomReady()
    for _, h in ipairs(Config.Room.imaps or {}) do
        if not Citizen.InvokeNative(0xD779B9B910BD3B7C, h) then return false end
    end
    return true
end
-- load the room as soon as the resource starts (as rsg-appearance does), so it has streamed in
-- long before anyone opens the creator
CreateThread(function() loadRoom() end)

-- one-line state report to the server console (Config.DebugReport), so problems seen in game can be read there
local function report(stage)
    if not Config.DebugReport then return end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local imaps = {}
    for _, h in ipairs(Config.Room.imaps or {}) do imaps[#imaps + 1] = tostring(Citizen.InvokeNative(0xD779B9B910BD3B7C, h)) end
    local camPos = S.cam and DoesCamExist(S.cam) and GetCamCoord(S.cam) or vector3(0, 0, 0)
    TriggerServerEvent('MULTIcreator:debugReport', {
        stage = stage, model = GetEntityModel(ped), male = IsPedMale(ped),
        pos = ('%.2f %.2f %.2f h%.0f'):format(c.x, c.y, c.z, GetEntityHeading(ped)),
        visible = IsEntityVisible(ped), alpha = GetEntityAlpha(ped),
        ready = Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and true or false,   -- IS_PED_READY_TO_RENDER
        collision = HasCollisionLoadedAroundEntity(ped), imaps = table.concat(imaps, ','),
        cam = ('%.2f %.2f %.2f'):format(camPos.x, camPos.y, camPos.z),
        camActive = S.cam and IsCamActive(S.cam) or false, rendering = IsCamRendering and S.cam and IsCamRendering(S.cam) or 'n/a',
        faded = IsScreenFadedOut(),
    })
end

-- lets a placed ped drop onto the floor (placing freezes it in mid-air), then holds it; returns its z
local function settlePed(ped)
    FreezeEntityPosition(ped, false)
    local untilTime = GetGameTimer() + (Config.Timing.settleMs or 1500)
    Wait(200)
    while GetGameTimer() < untilTime and #(GetEntityVelocity(ped)) > 0.05 do Wait(50) end
    FreezeEntityPosition(ped, true)
    return GetEntityCoords(ped).z
end

local function releasePed(ped)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
end

local function leaveRoom()
    if S.mode == 'create' and Config.Room.timecycle and Config.Room.timecycle ~= '' then ClearTimecycleModifier() end
    unloadRoom()
end

-- light on the ped while the page is open (creator: rsg-appearance's DrawLightWithRange spot and values)
local function lightLoop()
    CreateThread(function()
        while S.open do
            local l = Config.Room.light
            if S.mode == 'barber' and S.shop and S.shop.light then
                local p, bl = S.shop.light, Config.Barber.light
                DrawLightWithRange(p.x, p.y, p.z, bl.color[1], bl.color[2], bl.color[3], bl.range, bl.intensity)
            elseif S.mode == 'create' and l.enabled and S.base then
                local x, y, z
                if l.pos then
                    x, y, z = l.pos.x, l.pos.y, l.pos.z
                else
                    local h = math.rad(S.base.heading)
                    local fx, fy, rx, ry = -math.sin(h), math.cos(h), math.cos(h), math.sin(h)
                    local p = S.base.pos
                    x, y, z = p.x + fx * l.offset.y + rx * l.offset.x, p.y + fy * l.offset.y + ry * l.offset.x, p.z + l.offset.z
                end
                DrawLightWithRange(x, y, z, l.color[1], l.color[2], l.color[3], l.range, l.intensity)
            end
            DisableAllControlActions(0)
            Wait(0)
        end
    end)
end

-- ---------------------------------------------------------------
-- applying (one request at a time, always the newest)
-- ---------------------------------------------------------------

local function applyNow(req)
    local ped = PlayerPedId()
    local look = req.look
    if type(look) ~= 'table' then return end
    local kind = req.kind
    if kind == 'features' then
        MC:ApplyFeatures(ped, look.skin)
    elseif kind == 'overlays' then
        MC:ApplyOverlays(ped, look.skin)
    elseif kind == 'comps' then
        MC:ApplyComps(ped, look.comps or {})
    else
        MC:ApplyLook(ped, look)
    end
end

local function applyLoop()
    CreateThread(function()
        while S.open do
            local req = S.pending
            if req then
                S.pending = nil
                applyNow(req)
            end
            Wait(0)
        end
    end)
end

-- ---------------------------------------------------------------
-- open / close
-- ---------------------------------------------------------------

local function sendOpen(look, extra)
    local msg = {
        action = 'open',
        mode = S.mode,
        look = look,
        data = CreatorData.Get(),
        locale = _LT(),
        lang = _LCode(),
        config = {
            height = Config.Height,
            applyDelay = Config.ApplyDelayMs,
            identity = Config.Identity,
            startingClothes = Config.StartingClothes,
            barberOverlays = Config.Barber.overlays,
            price = Config.Barber.price,
            rotateStep = Config.RotateStep,
            mouseRotate = Config.MouseRotateScale,
            bodySliders = Config.BodySliders,
            random = Config.Random,
            cancelConfirmMs = Config.CancelConfirmMs,
        },
    }
    for k, v in pairs(extra or {}) do msg[k] = v end
    SendNUIMessage(msg)
    SetNuiFocus(true, true)
end

local function closeUi()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function finish(...)
    local cb = S.cb
    S.open, S.cb, S.pending = false, nil, nil
    closeUi()
    if cb then
        local args = table.pack(...)
        CreateThread(function() cb(table.unpack(args, 1, args.n)) end)
    end
end

local function openCreate()
    fade(true, Config.Room.fadeMs)
    local sex = 'male'
    loadRoom()
    local rt = GetGameTimer() + Config.Timing.collisionWaitMs
    while not roomReady() and GetGameTimer() < rt do Wait(50) end
    local ped = MC:SetPlayerModel(sex)
    local r = Config.Room.ped
    RequestCollisionAtCoord(r.x, r.y, r.z)
    placePed(ped, r)
    SetEntityVisible(ped, true)   -- character select hides the player while it shows its preview
    local t = GetGameTimer() + Config.Timing.collisionWaitMs
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
    -- let the ped settle onto the floor (it was frozen in mid-air before), then hold it there
    -- and frame the camera on where it really stands
    local z = settlePed(ped)
    S.base = { pos = vector3(r.x, r.y, z), heading = r.w }
    S.zoom = 0.0
    if Config.Room.timecycle and Config.Room.timecycle ~= '' then SetTimecycleModifier(Config.Room.timecycle) end
    setCamera('body', false)
    DisplayRadar(false)
    S.open = true
    lightLoop()
    applyLoop()
    -- the page builds the starting look and sends it back through 'apply'
    sendOpen(nil, { sex = sex })
    fade(false, Config.Room.fadeMs)
    report('opened')
    SetTimeout(3000, function() if S.open then report('3s later') end end)
end

local function openBarber(shop)
    local look = MC:GetLook() or lib.callback.await('MULTIcore:look:get', false)
    if type(look) ~= 'table' or type(look.skin) ~= 'table' then return false end
    local ped = PlayerPedId()
    S.original = json.decode(json.encode(look))
    S.shop = shop
    local here = GetEntityCoords(ped)
    S.returnTo = vector4(here.x, here.y, here.z, GetEntityHeading(ped))
    if shop and Config.Barber.movePlayer and shop.seat then
        fade(true, Config.Timing.barberFadeMs)
        placePed(ped, shop.seat)
        fade(false, Config.Timing.barberFadeMs)
    else
        ClearPedTasksImmediately(ped, false, false)
        FreezeEntityPosition(ped, true)
    end
    local p = GetEntityCoords(ped)
    S.base = { pos = p, heading = GetEntityHeading(ped) }
    S.zoom = 0.0
    setCamera('face', false)
    S.open = true
    lightLoop()
    applyLoop()
    sendOpen(look)
    return true
end

local function Open(mode, cb, shop)
    if S.open then
        if cb then cb(mode == 'create' and nil or false) end
        return false
    end
    S.mode = mode == 'barber' and 'barber' or 'create'
    S.cb = cb
    local ok
    if S.mode == 'create' then
        openCreate()
        ok = true
    else
        ok = openBarber(shop)
        if not ok then
            S.cb = nil
            if cb then cb(false) end
        end
    end
    return ok
end
exports('Open', Open)
exports('IsOpen', function() return S.open end)

local function endBarber(saved)
    local ped = PlayerPedId()
    dropCamera()
    if not saved and S.original then MC:ApplyLook(ped, S.original) end
    if Config.Barber.movePlayer and S.returnTo and S.shop then
        placePed(ped, S.returnTo)
    end
    releasePed(ped)
    S.original, S.shop, S.returnTo = nil, nil, nil
end

-- ---------------------------------------------------------------
-- page callbacks
-- ---------------------------------------------------------------

RegisterNUICallback('apply', function(data, cb)
    cb('ok')
    if not S.open or type(data) ~= 'table' then return end
    S.pending = { kind = data.kind, look = data.look }
end)

RegisterNUICallback('sex', function(data, cb)
    if not S.open or S.mode ~= 'create' then cb(false) return end
    local sex = data.sex == 'female' and 'female' or 'male'
    CreateThread(function()
        S.pending = nil
        local ped = MC:SetPlayerModel(sex)
        placePed(ped, Config.Room.ped)
        SetEntityVisible(ped, true)
        settlePed(ped)
        if type(data.look) == 'table' then MC:ApplyLook(ped, data.look) end
        cb(true)
    end)
end)

RegisterNUICallback('camera', function(data, cb)
    cb('ok')
    if not S.open then return end
    S.zoom = 0.0
    setCamera(data.zone, true)
end)

RegisterNUICallback('zoom', function(data, cb)
    cb('ok')
    if not S.open then return end
    local dz = (tonumber(data.delta) or 0) > 0 and Config.ZoomStep or -Config.ZoomStep
    S.zoom = math.max(Config.ZoomMin, math.min(Config.ZoomMax, S.zoom + dz))
    setCamera(S.zone, false)
end)

RegisterNUICallback('rotate', function(data, cb)
    cb('ok')
    if not S.open then return end
    local ped = PlayerPedId()
    SetEntityHeading(ped, (GetEntityHeading(ped) + (tonumber(data.deg) or 0)) % 360.0)
end)

RegisterNUICallback('finish', function(data, cb)
    cb('ok')
    if not S.open or S.mode ~= 'create' or type(data) ~= 'table' then return end
    local look, info = data.look, data.info
    if type(look) ~= 'table' or type(info) ~= 'table' then return end
    CreateThread(function()
        fade(true, Config.Room.fadeMs)
        dropCamera()
        releasePed(PlayerPedId())
        leaveRoom()
        DisplayRadar(true)
        finish(look, info)
        -- the caller (MULTIcharacter) spawns the player and fades back in
    end)
end)

RegisterNUICallback('cancel', function(_, cb)
    cb('ok')
    if not S.open then return end
    if S.mode == 'barber' then
        endBarber(false)
        finish(false)
    else
        CreateThread(function()
            fade(true, Config.Room.fadeMs)
            dropCamera()
            releasePed(PlayerPedId())
            leaveRoom()
            DisplayRadar(true)
            finish(nil)
        end)
    end
end)

-- barber: only hair, beard and the allowed overlays are taken from the page; the rest stays as stored
local function barberSkin(newSkin)
    local skin = json.decode(json.encode(S.original.skin))
    skin.hair = tonumber(newSkin.hair) or skin.hair
    skin.beard = tonumber(newSkin.beard) or skin.beard
    skin.overlays = type(skin.overlays) == 'table' and skin.overlays or {}
    local given = type(newSkin.overlays) == 'table' and newSkin.overlays or {}
    for _, name in ipairs(Config.Barber.overlays) do
        skin.overlays[name] = given[name]
    end
    return skin
end

RegisterNUICallback('barberSave', function(data, cb)
    cb('ok')
    if not S.open or S.mode ~= 'barber' or type(data) ~= 'table' or type(data.look) ~= 'table' then return end
    CreateThread(function()
        local skin = barberSkin(type(data.look.skin) == 'table' and data.look.skin or {})
        local paid, reason = lib.callback.await('MULTIcreator:barber:pay', false, S.shop and S.shop.id or nil)
        if not paid then
            notify(reason == 'money' and _L('no_money') or reason == 'range' and _L('not_at_barber') or _L('save_failed'), 'error')
            SendNUIMessage({ action = 'busy', busy = false })
            return
        end
        local ok = lib.callback.await('MULTIcore:look:save', false, 'skin', skin)
        if not ok then
            lib.callback.await('MULTIcreator:barber:refund', false)
            notify(_L('save_failed'), 'error')
            SendNUIMessage({ action = 'busy', busy = false })
            return
        end
        if Config.Barber.price > 0 then notify(_L('paid', Config.Barber.price), 'success') end
        notify(_L('saved'), 'success')
        S.original = { skin = skin, comps = S.original.comps }
        endBarber(true)
        -- refresh MULTIcore's cached look and put the saved version on
        MC:ReloadLook()
        finish(true)
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() or not S.open then return end
    SetNuiFocus(false, false)
    dropCamera()
    releasePed(PlayerPedId())
    if S.mode == 'create' then ClearTimecycleModifier() end
    DisplayRadar(true)
end)

dbg('loaded')
