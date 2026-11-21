-- ============================================================
-- MULTIwagons :: dealer showroom (client)
-- The wagon shown at the dealer while the page is open, its camera and light.
-- Based on Phil's wagon script (store.lua).
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local showroomWagon, showroomCam
local isSpawningWagon = false
local showroomRenderActive = false

-- A plain DeleteEntity on a non-mission entity can fail silently and leave a
-- second preview wagon behind on every switch, so this one checks and retries.
local function DeleteShowroomWagon()
    if not showroomWagon then return end
    local wagon = showroomWagon
    showroomWagon = nil
    if not DoesEntityExist(wagon) then return end
    SetEntityAsMissionEntity(wagon, true, true)
    DeleteEntity(wagon)
    local t = 0
    while DoesEntityExist(wagon) and t < 2000 do
        Wait(10)
        t += 10
    end
    if DoesEntityExist(wagon) then
        DeleteEntity(wagon)
        Wait(100)
    end
    if DoesEntityExist(wagon) then
        SetEntityVisible(wagon, false, false)
        SetEntityCollision(wagon, false, false, false)
        SetEntityCoords(wagon, 0.0, 0.0, -1000.0, false, false, false, false)
    end
end

-- the light over the shown wagon and the camera kept on, every frame while the page is open
local function StartShowroomRenderThread()
    if showroomRenderActive then return end
    showroomRenderActive = true
    CreateThread(function()
        while showroomRenderActive and (showroomCam or showroomWagon) do
            Wait(0)
            if showroomCam then
                SetCamActive(showroomCam, true)
                RenderScriptCams(true, false, 0, true, true)
            end
            if showroomWagon and DoesEntityExist(showroomWagon) then
                local crds = GetEntityCoords(showroomWagon)
                DrawLightWithRange(crds.x, crds.y, crds.z + 2.0, 255, 255, 255, 15.0, 50.0)
            end
        end
        showroomRenderActive = false
    end)
end

function SetUpShowroomCamera(cameraPosition, targetEntity)
    FreezeEntityPosition(cache.ped, true)
    SetEntityInvincible(cache.ped, true)

    if not showroomCam then showroomCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true) end
    SetCamCoord(showroomCam, cameraPosition.x, cameraPosition.y, cameraPosition.z)
    PointCamAtEntity(showroomCam, targetEntity, 0, 0, 0, true)

    SetCamActive(showroomCam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetCamFov(showroomCam, 50.0)

    StartShowroomRenderThread()
end

function UpdateShowroomWagonVisuals(wagon, custom)
    if not DoesEntityExist(wagon) then return end
    custom = custom or {}

    Citizen.InvokeNative(0x75F90E4051CC084C, wagon, 0)
    if custom.props then
        Citizen.InvokeNative(0x75F90E4051CC084C, wagon, GetHashKey(custom.props))
        Citizen.InvokeNative(0x31F343383F19C987, wagon, 0.5, 1)
    end

    Citizen.InvokeNative(0xE31C0CB1C3186D40, wagon)
    Wait(50)

    if custom.lantern then
        Citizen.InvokeNative(0xC0F0417A90402742, wagon, GetHashKey(custom.lantern))
    end

    Wait(50)
    Citizen.InvokeNative(0xAD738C3085FE7E11, wagon, true, true)
    Citizen.InvokeNative(0x9617B6E5F65329A5, wagon)

    Citizen.InvokeNative(0x8268B098F6FCA4E2, wagon, tonumber(custom.tint) or 0)
    Citizen.InvokeNative(0xF89D82A0582E46ED, wagon, tonumber(custom.livery) or 0)

    for i = 0, 10 do
        if DoesExtraExist(wagon, i) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, i, true)
        end
    end
    -- several extras (custom.extras); a single custom.extra from older rows still works
    local extrasList = nil
    if type(custom.extras) == 'table' and #custom.extras > 0 then
        extrasList = custom.extras
    elseif custom.extra and tonumber(custom.extra) and tonumber(custom.extra) ~= -1 then
        extrasList = { tonumber(custom.extra) }
    end
    if extrasList then
        for _, extraId in ipairs(extrasList) do
            local eid = tonumber(extraId)
            if eid then Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, eid, false) end
        end
    end
end

local function storeSpot(store)
    local s = Config.Stores[store]
    if not s then return nil end
    return s.previewWagon, s.cameraPreviewWagon
end

function SpawnShowroomWagon(model, store)
    if isSpawningWagon then return end
    local coords, camCoords = storeSpot(store)
    if not coords then return end
    isSpawningWagon = true

    DeleteShowroomWagon()

    if not lib.requestModel(model, 5000) then
        isSpawningWagon = false
        return
    end

    showroomWagon = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, false, false)
    SetEntityAsMissionEntity(showroomWagon, true, true)
    Citizen.InvokeNative(0x75F90E4051CC084C, showroomWagon, 0)
    Citizen.InvokeNative(0x8268B098F6FCA4E2, showroomWagon, 0)
    Citizen.InvokeNative(0xF89D82A0582E46ED, showroomWagon, -1)

    for i = 0, 10 do
        if DoesExtraExist(showroomWagon, i) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, showroomWagon, i, true)
        end
    end

    SetEntityInvincible(showroomWagon, true)
    FreezeEntityPosition(showroomWagon, true)

    SetUpShowroomCamera(camCoords, showroomWagon)
    SetModelAsNoLongerNeeded(model)

    Wait(250)
    isSpawningWagon = false
end

function SpawnShowroomMyWagon(model, store, custom)
    if isSpawningWagon then return end
    local coords, camCoords = storeSpot(store)
    if not coords then return end
    isSpawningWagon = true

    if showroomWagon and DoesEntityExist(showroomWagon) and GetEntityModel(showroomWagon) == GetHashKey(model) then
        UpdateShowroomWagonVisuals(showroomWagon, custom)
        isSpawningWagon = false
        return
    end
    DeleteShowroomWagon()

    if not lib.requestModel(model, 5000) then
        isSpawningWagon = false
        return
    end

    showroomWagon = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, false, false)
    SetEntityAsMissionEntity(showroomWagon, true, true)
    UpdateShowroomWagonVisuals(showroomWagon, custom)

    SetEntityInvincible(showroomWagon, true)
    FreezeEntityPosition(showroomWagon, true)

    SetUpShowroomCamera(camCoords, showroomWagon)
    SetModelAsNoLongerNeeded(model)
    isSpawningWagon = false
end

function RotatePreviewWagon(direction)
    if not showroomWagon then return end
    SetEntityHeading(showroomWagon, GetEntityHeading(showroomWagon) + (direction == 'left' and -5 or 5))
end

function CloseShowroom()
    showroomRenderActive = false
    DeleteShowroomWagon()
    if showroomCam then
        DestroyCam(showroomCam, false)
        RenderScriptCams(false, false, 0, true, true)
        showroomCam = nil
    end
    FreezeEntityPosition(cache.ped, false)
    SetEntityInvincible(cache.ped, false)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and (showroomCam or showroomWagon) then CloseShowroom() end
end)
