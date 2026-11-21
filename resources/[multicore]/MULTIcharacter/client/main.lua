-- ============================================================
-- MULTIcharacter :: client
-- Select scene, character cards, preview ped, new / delete, spawn
-- picker and first spawn. Talks to MULTIcore through its callbacks
-- (MULTIcore:chars:*) and client exports (ApplyLook, SetPlayerModel,
-- ReloadLook), and to MULTIcreator through exports.MULTIcreator:Open.
-- Natives checked against the RDR3 native list (femga); NUI and
-- loading-screen functions are CitizenFX runtime functions.
-- ============================================================

local S = Config.Scene

local inSelect = false   -- the select scene is up
local busy = false       -- a server call or transition is running
local chars = {}         -- from MULTIcore:chars:list
local slots = Config.MaxCharacters
local selected = 1
local previewPed = nil
local previewToken = 0
local cam = nil
local pendingSex = nil   -- model sex of the character being spawned
local pendingChar = nil  -- the character picked with Play
local loadingDone = false

-- ------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------

local function notify(text, kind)
    exports.MULTIcore:Notify(text, kind or Config.NotifyError)
end

local function fadeOut(ms)
    if IsScreenFadedOut() then return end
    DoScreenFadeOut(ms)
    local t = GetGameTimer() + ms + Config.Timing.fadeWaitExtra
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end
end

local function fadeIn(ms)
    DoScreenFadeIn(ms)
end

local function loadModel(name)
    local hash = joaat(name)
    RequestModel(hash)
    local t = GetGameTimer() + Config.Timing.modelTimeout
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function waitCollision(entity, x, y, z, timeout)
    local t = GetGameTimer() + (timeout or S.collisionTimeout)
    RequestCollisionAtCoord(x, y, z)
    while not HasCollisionLoadedAroundEntity(entity) and GetGameTimer() < t do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
end

local function shutdownLoading()
    if loadingDone then return end
    loadingDone = true
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()   -- CitizenFX: closes MULTIloading (loadscreen_manual_shutdown)
end

local function sexOf(c)
    if c and c.look and type(c.look.skin) == 'table' and c.look.skin.sex then return c.look.skin.sex end
    return (c and c.gender == 'female') and 'female' or 'male'
end

local function lookOf(c)
    local look = c and c.look
    if type(look) == 'table' and type(look.skin) == 'table' and next(look.skin) then
        return { skin = look.skin, comps = look.comps or {} }
    end
    return Config.DefaultLook[sexOf(c)]
end

-- ------------------------------------------------------------
-- player and camera
-- ------------------------------------------------------------

local function hidePlayer()
    -- a world of their own while they pick or create a character (the server only does this
    -- for a player with no character loaded)
    TriggerServerEvent('MULTIcharacter:server:privateScene', true)
    local ped = PlayerPedId()
    local p = S.hidePlayerAt
    SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false)
    SetEntityInvincible(ped, true)
    SetPlayerControl(PlayerId(), false, 0, false)
    DisplayHud(false)
    DisplayRadar(false)
    return ped
end

local function releasePlayer()
    TriggerServerEvent('MULTIcharacter:server:privateScene', false)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
    SetEntityInvincible(ped, false)
    SetPlayerControl(PlayerId(), true, 0, false)
    DisplayHud(true)
    DisplayRadar(true)
end

local function startCam()
    if cam and DoesCamExist(cam) then return end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, S.cam.x, S.cam.y, S.cam.z)
    SetCamRot(cam, S.camRot.x, S.camRot.y, S.camRot.z, S.camRotOrder)
    SetCamFov(cam, S.camFov)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true, 0)
end

local function stopCam()
    RenderScriptCams(false, false, 0, true, true, 0)
    if cam and DoesCamExist(cam) then
        SetCamActive(cam, false)
        DestroyCam(cam, false)
    end
    cam = nil
end

-- ------------------------------------------------------------
-- preview ped
-- ------------------------------------------------------------

local function deletePreview()
    previewToken = previewToken + 1
    if previewPed and DoesEntityExist(previewPed) then
        SetEntityAsMissionEntity(previewPed, true, true)
        DeleteEntity(previewPed)
    end
    previewPed = nil
end

local function showPreview(c)
    deletePreview()
    if not c then return end
    local token = previewToken
    local sex = sexOf(c)
    local hash = loadModel(sex == 'female' and 'mp_female' or 'mp_male')
    if not hash or token ~= previewToken then return end
    local p = S.ped
    local ped = CreatePed(hash, p.x, p.y, p.z, p.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    SetEntityVisible(ped, false)          -- shown once dressed
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    previewPed = ped
    local ok, err = pcall(function() exports.MULTIcore:ApplyLook(ped, lookOf(c)) end)
    if not ok then print(('[MULTIcharacter] ApplyLook failed: %s'):format(err)) end
    if token ~= previewToken or not DoesEntityExist(ped) then
        if DoesEntityExist(ped) then SetEntityAsMissionEntity(ped, true, true); DeleteEntity(ped) end
        return
    end
    SetEntityVisible(ped, true)
    if S.idleScenario then
        TaskStartScenarioInPlaceHash(ped, joaat(S.idleScenario), -1, true, 0, p.w, false)
    end
end

-- ------------------------------------------------------------
-- NUI
-- ------------------------------------------------------------

local function cardData()
    local out = {}
    for i, c in ipairs(chars) do
        out[i] = {
            index = i,
            name = ('%s %s'):format(c.firstname or '?', c.lastname or ''),
            job = c.jobLabel or c.job or _L("no_job"),
            cash = tonumber(c.cash) or 0,
            gold = tonumber(c.gold) or 0,
            bank = tonumber(c.bank) or 0,
            birthdate = c.birthdate,
            gender = c.gender,
        }
    end
    return out
end

local function sendList()
    SendNUIMessage({ action = 'list', characters = cardData(), slots = slots, selected = selected })
end

local function openUi()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "open", text = _LT(), lang = _LCode(), rotateThrottle = S.rotateThrottleMs })
    sendList()
end

local function closeUi()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function refresh()
    chars = lib.callback.await('MULTIcore:chars:list', false) or {}
    slots = tonumber(lib.callback.await('MULTIcharacter:slots', false)) or Config.MaxCharacters
    if slots > Config.MaxCharacters then slots = Config.MaxCharacters end
    if selected > #chars then selected = math.max(1, #chars) end
end

-- ------------------------------------------------------------
-- select scene
-- ------------------------------------------------------------

local function openSelect()
    if inSelect then return end
    inSelect = true
    busy = true
    fadeOut(Config.Timing.fadeOutSelect)
    closeUi()
    deletePreview()
    local ped = hidePlayer()
    SetFocusPosAndVel(S.ped.x, S.ped.y, S.ped.z, 0.0, 0.0, 0.0)
    waitCollision(ped, S.ped.x, S.ped.y, S.ped.z, S.collisionTimeout)
    startCam()
    refresh()
    selected = 1
    showPreview(chars[selected])
    shutdownLoading()
    openUi()
    fadeIn(Config.Timing.fadeInSelect)
    busy = false
end

local function leaveScene()
    closeUi()
    deletePreview()
    stopCam()
    ClearFocus()
    inSelect = false
end

local function spawnAt(coords, sex, isNew)
    fadeOut(Config.Timing.fadeOutSpawn)
    leaveScene()
    -- model, then the stored look of the logged-in character
    exports.MULTIcore:SetPlayerModel(sex)
    exports.MULTIcore:ReloadLook()
    local ped = PlayerPedId()
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
    FreezeEntityPosition(ped, true)
    waitCollision(ped, coords.x, coords.y, coords.z, Config.SpawnCollisionTimeout)
    ClearFocus()
    releasePlayer()
    shutdownLoading()
    fadeIn(Config.Timing.fadeInSpawn)
    TriggerEvent('MULTIcharacter:client:spawned', isNew == true)
end

-- last saved position of a character, as vector4, or nil
local function lastPos(c)
    local p = c and c.lastPosition
    if type(p) ~= 'table' then return nil end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not x or not y or not z then return nil end
    if x == 0.0 and y == 0.0 then return nil end
    -- a position saved inside the select scene (older saves) is not a place to spawn
    if #(vector3(x, y, z) - S.hidePlayerAt) < (Config.NoSaveRadius or 100.0) then return nil end
    return vector4(x, y, z, tonumber(p.w or p.h or p.heading) or 0.0)
end

local function spawnChoices(c)
    local list = {}
    if Config.AllowLastLocation and lastPos(c) then
        list[#list + 1] = { id = '__last', label = _L("last_location"), desc = _L("last_location_desc") }
    end
    for _, l in ipairs(Config.SpawnLocations) do
        list[#list + 1] = { id = l.id, label = _L("loc_" .. l.id), desc = _L("loc_" .. l.id .. "_desc") }
    end
    return list
end

-- ------------------------------------------------------------
-- NUI callbacks
-- ------------------------------------------------------------

RegisterNUICallback('select', function(data, cb)
    cb('ok')
    local i = tonumber(data.index)
    if not inSelect or busy or not i or not chars[i] or i == selected and previewPed then return end
    selected = i
    sendList()
    CreateThread(function() showPreview(chars[i]) end)
end)

RegisterNUICallback('rotate', function(data, cb)
    cb('ok')
    local dx = tonumber(data.dx)
    if previewPed and DoesEntityExist(previewPed) and dx then
        SetEntityHeading(previewPed, GetEntityHeading(previewPed) + dx * S.rotateSpeed)
    end
end)

RegisterNUICallback('play', function(data, cb)
    cb('ok')
    local c = chars[tonumber(data.index) or selected]
    if not inSelect or busy or not c then return end
    busy = true
    CreateThread(function()
        local ok = lib.callback.await('MULTIcore:chars:select', false, c.citizenid)
        busy = false
        if not ok then
            notify(_L("select_failed"))
            SendNUIMessage({ action = 'unbusy' })
            return
        end
        pendingChar, pendingSex = c, sexOf(c)
        SendNUIMessage({ action = 'spawn', locations = spawnChoices(c) })
    end)
end)

RegisterNUICallback('spawn', function(data, cb)
    cb('ok')
    if not inSelect or busy or not pendingChar then return end
    local coords
    if data.id == '__last' then
        coords = lastPos(pendingChar)
    else
        for _, l in ipairs(Config.SpawnLocations) do
            if l.id == data.id then coords = l.coords break end
        end
    end
    if not coords then return end
    busy = true
    local sex = pendingSex
    pendingChar, pendingSex = nil, nil
    CreateThread(function()
        spawnAt(coords, sex, false)
        busy = false
    end)
end)

RegisterNUICallback('new', function(_, cb)
    cb('ok')
    if not inSelect or busy then return end
    if #chars >= slots then notify(_L("no_slots")) return end
    if GetResourceState('MULTIcreator') ~= 'started' then notify(_L("no_creator")) return end
    busy = true
    CreateThread(function()
        fadeOut(Config.Timing.fadeOutCreator)
        leaveScene()
        -- The creator owns the player ped and its own scene while it is open.
        exports.MULTIcreator:Open('create', function(look, info)
            CreateThread(function()
                if not look then
                    busy = false
                    openSelect()
                    return
                end
                info = type(info) == 'table' and info or {}
                if info.gender ~= 'male' and info.gender ~= 'female' then
                    info.gender = (type(look.skin) == 'table' and look.skin.sex == 'female') and 'female' or 'male'
                end
                local citizenid, reason = lib.callback.await('MULTIcore:chars:create', false, info, look)
                if not citizenid then
                    notify(reason == "no_slots" and _L("no_slots") or _L("create_failed"))
                    busy = false
                    openSelect()
                    return
                end
                spawnAt(Config.NewPlayerSpawn, info.gender, true)
                busy = false
            end)
        end)
        fadeIn(Config.Timing.fadeInCreator)
    end)
end)

RegisterNUICallback('delete', function(data, cb)
    cb('ok')
    local i = tonumber(data.index)
    local c = i and chars[i]
    if not inSelect or busy or not c then return end
    local want = (('%s %s'):format(c.firstname or '', c.lastname or '')):lower():gsub('%s+', ' ')
    local typed = tostring(data.typed or ''):lower():gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    if typed ~= want then return end
    busy = true
    CreateThread(function()
        local ok = lib.callback.await('MULTIcore:chars:delete', false, c.citizenid)
        if ok then notify(_L("deleted"), Config.NotifySuccess) else notify(_L("delete_failed")) end
        refresh()
        selected = math.min(selected, math.max(1, #chars))
        sendList()
        showPreview(chars[selected])
        busy = false
    end)
end)

-- ------------------------------------------------------------
-- entry points
-- ------------------------------------------------------------

-- first spawn
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(Config.Timing.pollInterval) end
    while GetResourceState('MULTIcore') ~= 'started' do Wait(Config.Timing.pollInterval) end
    Wait(Config.Timing.startDelay)
    if LocalPlayer.state.isLoggedIn then return end   -- resource restarted while playing
    openSelect()
end)

-- /logout (MULTIcore:LogoutCharacter) and any other way back to select
RegisterNetEvent('MULTIcore:client:loggedOut', function()
    CreateThread(openSelect)
end)

-- ------------------------------------------------------------
-- RSG v2 compatibility (fxmanifest: provide 'rsg-multicharacter', 'rsg-spawn')
-- Same meaning as in RSG v2; our own handlers.
-- ------------------------------------------------------------

local function loggedInData()
    local ok, core = pcall(function() return exports['rsg-core']:GetCoreObject() end)
    if not ok or not core then return nil end
    local pd = core.Functions.GetPlayerData()
    if type(pd) ~= 'table' or not pd.citizenid then return nil end
    return pd
end

-- spawn picker for a character that is already logged in (no select scene)
local function pickerForLoggedIn(isNew)
    local pd = loggedInData()
    if not pd or busy then return end
    local female = pd.charinfo and (pd.charinfo.gender == 1 or pd.charinfo.gender == '1')
    local sex = female and 'female' or 'male'
    if isNew and not Config.NewPlayerPicker then
        busy = true
        spawnAt(Config.NewPlayerSpawn, sex, true)
        busy = false
        return
    end
    local fresh = not inSelect
    if fresh then
        inSelect = true
        fadeOut(Config.Timing.fadeOutSelect)
        local ped = hidePlayer()
        SetFocusPosAndVel(S.ped.x, S.ped.y, S.ped.z, 0.0, 0.0, 0.0)
        waitCollision(ped, S.ped.x, S.ped.y, S.ped.z, S.collisionTimeout)
        startCam()
    end
    pendingChar = { lastPosition = (not isNew) and pd.position or nil }
    pendingSex = sex
    shutdownLoading()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "open", text = _LT(), lang = _LCode(), rotateThrottle = S.rotateThrottleMs })
    SendNUIMessage({ action = 'spawn', locations = spawnChoices(pendingChar) })
    if fresh then fadeIn(Config.Timing.fadeInSelect) end
end

-- RSG v2: "show character select" (rsg-multicharacter's /logout fires it after logging out).
-- No arguments. If the character is still logged in we log it out first; the
-- server then sends MULTIcore:client:loggedOut, which opens select.
RegisterNetEvent('rsg-multicharacter:client:chooseChar', function()
    if LocalPlayer.state.isLoggedIn then
        TriggerServerEvent('MULTIcharacter:server:logout')
    else
        CreateThread(openSelect)
    end
end)

-- RSG v2: rsg-multicharacter's "close the select NUI". Only the panel closes; the
-- scene stays until a spawn follows (setupSpawnUI / newplayer), as in RSG v2.
RegisterNetEvent('rsg-multicharacter:client:closeNUI', function()
    if inSelect then SetNuiFocus(false, false); SendNUIMessage({ action = 'close' }) end
end)

-- RSG v2: first spawn of a just-created, already logged-in character. No arguments.
RegisterNetEvent('rsg-spawn:client:newplayer', function()
    CreateThread(function() pickerForLoggedIn(true) end)
end)

-- RSG v2: rsg-spawn's entry point (cData, new). new == false: existing character
-- picks a spawn; otherwise the new-player spawn.
RegisterNetEvent('rsg-spawn:client:setupSpawnUI', function(_, new)
    CreateThread(function() pickerForLoggedIn(new ~= false) end)
end)

-- other client scripts can ask for a logout (the server checks cooldown and permissions)
AddEventHandler('MULTIcharacter:client:logout', function()
    TriggerServerEvent('MULTIcharacter:server:logout')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    deletePreview()
    if inSelect then
        stopCam()
        ClearFocus()
        releasePlayer()
        DoScreenFadeIn(0)
    end
end)
