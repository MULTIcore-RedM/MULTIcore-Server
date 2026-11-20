--[[
    Public clothes stores (client): clerk peds + blips, and the try-on window (view 'store').

    The clerk is a local ped spawned while you are near (Config.Stores.list / multitailor_stores);
    target it (MULTItarget, or the key prompt) -> "Browse ready-made clothes". The camera turns to
    face you and every garment you pick is tried on your own character:
      MULTIinventory : exports.MULTIinventory:PreviewClothing(pieces) / ClearPreview()
      otherwise      : the piece is put on the ped directly; MULTIcore's saved look comes back on close
                       (exports.MULTIcore:ReloadLook).
    The clerk also opens the saved outfit list (Config.Stores.outfitsAtClerk, client/95_wardrobe.lua).
    NUI actions: preview { lineId, colour } · unpreview { cat } · view { view } · rotate { dir } · buy { lineId, colour }
]]
TStoreC = TStoreC or {}

local stores = {}        -- [id] = store
local clerks = {}        -- [id] = ped
local blips = {}
local S = { open = false, store = nil, payload = nil, cam = nil, view = 'full', fitting = {}, touched = false }

local SPAWN_DIST, DESPAWN_DIST = 60.0, 75.0

local function C() return Config.Stores end

-- ---------------------------------------------------------------- clerks / blips
local function loadModel(name)
    local list = { name }
    for _, m in ipairs(C().fallbackModels or {}) do list[#list + 1] = m end
    for _, m in ipairs(list) do
        local h = joaat(m)
        if IsModelValid(h) then
            RequestModel(h)
            local t = GetGameTimer() + 4000
            while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
            if HasModelLoaded(h) then return h end
        end
    end
    return nil
end

local function removeClerk(id)
    local ped = clerks[id]
    if ped then
        TT.removeEntity(ped)
        if DoesEntityExist(ped) then SetEntityAsMissionEntity(ped, true, true) DeleteEntity(ped) end
    end
    clerks[id] = nil
end

local function spawnClerk(s)
    local h = loadModel(s.model or C().defaultModel)
    if not h then return end
    local ped = CreatePed(h, s.clerk.x, s.clerk.y, s.clerk.z, s.clerk.w or 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(h)
    local t = GetGameTimer() + 2000
    while not DoesEntityExist(ped) and GetGameTimer() < t do Wait(0) end
    if not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    PlaceEntityOnGroundProperly(ped)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    TaskStandStill(ped, -1)
    clerks[s.id] = ped
    local options = {
        { label = L('opt_store'), icon = 'fa-solid fa-shirt', canInteract = function() return not TC.view end,
          onSelect = function() CreateThread(function() TStoreC.open(s.id) end) end },
    }
    if C().outfitsAtClerk ~= false then
        options[#options + 1] = { label = L('opt_outfits'), icon = 'fa-solid fa-box-archive', canInteract = function() return not TC.view end,
            onSelect = function() TriggerEvent('MULTItailor:client:openOutfits', { store = s.id }) end }
    end
    TT.addEntity(ped, { distance = C().interactDistance or 2.5, title = s.label, options = options })
end

local function removeBlip(id) if blips[id] then RemoveBlip(blips[id]) blips[id] = nil end end

local function addBlip(s)
    removeBlip(s.id)
    local cfg = C().blip or {}
    if cfg.enabled == false or s.blip == false then return end
    local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, s.clerk.x, s.clerk.y, s.clerk.z)
    SetBlipSprite(b, cfg.sprite or 1195729388, true)
    SetBlipScale(b, cfg.scale or 0.2)
    Citizen.InvokeNative(0x9CB1A1623062F402, b, s.label or cfg.name or 'Clothes Store')
    blips[s.id] = b
end

RegisterNetEvent('MULTItailor:stores', function(list)
    for id in pairs(stores) do removeClerk(id) removeBlip(id) end
    stores = {}
    for _, s in ipairs(type(list) == 'table' and list or {}) do
        if type(s) == 'table' and s.id and s.clerk then
            stores[s.id] = s
            addBlip(s)
        end
    end
end)

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        for id, s in pairs(stores) do
            local d = #(me - vector3(s.clerk.x, s.clerk.y, s.clerk.z))
            if d < SPAWN_DIST and not clerks[id] then spawnClerk(s)
            elseif d > DESPAWN_DIST and clerks[id] then removeClerk(id) end
        end
        Wait(1500)
    end
end)

-- ---------------------------------------------------------------- try-on
local function multiInv()
    return Config.Items.format ~= 'outfit' and GetResourceState(Config.Items.inventoryResource or 'MULTIinventory') == 'started'
end

local function lineOf(id)
    for _, l in ipairs(S.payload and S.payload.lines or {}) do if l.id == id then return l end end
    return nil
end

local function mySex() return IsPedMale(PlayerPedId()) and 'male' or 'female' end

local function applyFitting()
    local list = {}
    for _, f in pairs(S.fitting) do list[#list + 1] = f end
    if multiInv() then
        local specs = {}
        for _, f in ipairs(list) do specs[#specs + 1] = { category = f.vorp, comp = f.hash, gender = f.sex, label = f.label } end
        if #specs == 0 then pcall(function() exports[Config.Items.inventoryResource or 'MULTIinventory']:ClearPreview() end) return end
        pcall(function() exports[Config.Items.inventoryResource or 'MULTIinventory']:PreviewClothing(specs) end)
        return
    end
    local ped = PlayerPedId()
    S.tried = S.tried or {}
    for _, f in ipairs(list) do
        TCN.applyHash(ped, f.hash, f.cat == 'boots')
        TCN.updateVariation(ped)
        S.tried[f.cat] = true
    end
    S.touched = true
end

local function restoreLook()
    if multiInv() then
        pcall(function() exports[Config.Items.inventoryResource or 'MULTIinventory']:ClearPreview() end)
        return
    end
    if not S.touched then return end
    S.touched = false
    S.tried = {}
    -- MULTIcore puts the saved look back on (MULTItailor then puts the worn items on again)
    if GetResourceState('MULTIcore') == 'started' then
        CreateThread(function() pcall(function() exports.MULTIcore:ReloadLook() end) end)
    end
end

local function aim()
    if not S.cam then return end
    local cam = C().camera or {}
    local v = (cam.views or {})[S.view] or { z = 0.0, fov = 45.0 }
    local ped = PlayerPedId()
    local root = GetEntityCoords(ped)
    local camPos = GetCamCoord(S.cam)
    local f = vector3(root.x - camPos.x, root.y - camPos.y, 0.0)
    local dist = #f
    local target = vector3(root.x, root.y, root.z + (v.z or 0.0))
    if dist > 0.01 then
        f = f / dist
        target = target + vector3(f.y, -f.x, 0.0) * ((cam.panelShift or 0.45) * dist / 2.2)
    end
    PointCamAtCoord(S.cam, target.x, target.y, target.z)
    SetCamFov(S.cam, v.fov or 45.0)
end

local function makeCam()
    local cam = C().camera or {}
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local c = pos + fwd * (cam.distance or 2.3) + vector3(0.0, 0.0, 0.25)
    S.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, 0.0, 0.0, 0.0, cam.fov or 40.0, false, 0)
    SetCamActive(S.cam, true)
    RenderScriptCams(true, true, 500, true, true, 0)
    aim()
end

local function destroyCam()
    if S.cam then
        RenderScriptCams(false, true, 500, true, true, 0)
        SetCamActive(S.cam, false)
        DestroyCam(S.cam, true)
    end
    S.cam = nil
end

local function cleanup()
    S.open = false
    destroyCam()
    restoreLook()
    FreezeEntityPosition(PlayerPedId(), false)
    S.fitting, S.payload, S.store = {}, nil, nil
end

TC.onClose('store', function() if S.open then cleanup() end end)

function TStoreC.open(id)
    if TC.view or S.open then return end
    local payload, err = lib.callback.await('multitailor:store:open', false, id)
    if not payload then return TC.notify(err or L('err_store_closed'), 'error') end
    S.open, S.store, S.payload, S.view, S.fitting = true, id, payload, 'full', {}
    payload.pedSex = mySex()
    payload.preview = multiInv() and 'multi' or 'ped'
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, true)
    makeCam()
    TC.open('store', payload)
    CreateThread(function()
        while S.open do
            Wait(500)
            if IsEntityDead(PlayerPedId()) then TC.close(true) end
        end
    end)
end

TC.on('store', 'preview', function(data)
    local l = lineOf(data.lineId)
    local n = TU.int(data.colour, 1, 1000)
    if not l or not n then return { ok = false } end
    if l.sex ~= mySex() then return { ok = false, error = L('err_preview_sex') } end
    local colour
    for _, c in ipairs(l.colours) do if c.n == n then colour = c break end end
    if not colour then return { ok = false } end
    S.fitting[l.cat] = { cat = l.cat, vorp = l.vorp, hash = colour.hash, sex = l.sex, label = l.label }
    applyFitting()
    return { ok = true }
end)

TC.on('store', 'unpreview', function(data)
    if type(data.cat) == 'string' then S.fitting[data.cat] = nil else S.fitting = {} end
    if multiInv() then applyFitting() else restoreLook() Wait(600) applyFitting() end
    return { ok = true }
end)

TC.on('store', 'view', function(data)
    if ((C().camera or {}).views or {})[data.view] then S.view = data.view end
    aim()
    return { ok = true, view = S.view }
end)

TC.on('store', 'rotate', function(data)
    local ped = PlayerPedId()
    local step = (C().camera or {}).rotateStep or 30.0
    SetEntityHeading(ped, (GetEntityHeading(ped) + step * ((tonumber(data.dir) or 1) >= 0 and 1 or -1)) % 360.0)
    aim()
    return { ok = true }
end)

TC.on('store', 'buy', function(data)
    if not S.store then return { ok = false } end
    return lib.callback.await('multitailor:store:buy', false, { storeId = S.store, lineId = data.lineId, colour = data.colour }) or { ok = false }
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if S.open then destroyCam() restoreLook() FreezeEntityPosition(PlayerPedId(), false) end
    for id in pairs(clerks) do removeClerk(id) end
    for id in pairs(blips) do removeBlip(id) end
end)
