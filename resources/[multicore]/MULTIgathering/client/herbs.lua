-- ============================================================
-- MULTIgathering :: herb picking (client)
-- Puts the game's own herb plants into the world near the player (config/herb_spots.lua),
-- shows the game's pick-up prompt on the plant in reach and, when the player picks it,
-- plays the gathering scenario and tells the server which spot it was. The streaming and
-- pick-up detection are based on rsg-herbalist's client (RSG v2, GPL v3, see CREDITS.md).
-- ============================================================

local N = {   -- natives (femga natives.json)
    REQUEST_HERB_COMPOSITE_ASSET = 0x73F0D0327BFA0812,          -- _REQUEST_HERB_COMPOSITE_ASSET
    COMPOSITE_ASSETS_LOADED = 0x5E5D96BE25E9DF68,               -- ARE_COMPOSITE_LOOTABLE_ENTITY_DEF_ASSETS_LOADED
    DELETE_HERB_COMPOSITE = 0x5758B1EE0C3FD4AC,                 -- _DELETE_PATCH_OBJECTS_FROM_HERB_COMPOSITES
    DISABLE_LOOTING_COMPOSITE = 0x40D72189F46D2E15,             -- DISABLE_LOOTING_COMPOSITE_LOOTABLE_THIS_FRAME (as rsg-herbalist calls it)
    TASK_START_SCENARIO_IN_PLACE_HASH = 0x524B54361229154F,     -- TASK_START_SCENARIO_IN_PLACE_HASH
}

-- the game's pick-up controls (keyboard and pad), as rsg-herbalist reads them
local PICKUP_CONTROLS = { 0xCEFD9220, 0xE30CD707, 0xF6BB7378, 0xEB2AC491, 0xFF8109D8, 0x27D1C284, 0xBE8593AF, 0x41AC83D1 }

local H = Config.Herbs
local picked = {}       -- [key] = true while picked (from the server)
local nearby = {}       -- entries within a few metres, refreshed every second
local loaded = {}       -- [key] = { entry, handle } for plants in the world

local function pickupPressed()
    for _, c in ipairs(PICKUP_CONTROLS) do
        if IsDisabledControlJustPressed(0, c) then return true end
    end
    return false
end

local function unload(key)
    local l = loaded[key]
    if not l then return end
    if l.handle then Citizen.InvokeNative(N.DELETE_HERB_COMPOSITE, l.handle, 0) end
    loaded[key] = nil
end

local function loadPlant(entry)
    if loaded[entry.key] then return end
    loaded[entry.key] = { entry = entry, loading = true }
    CreateThread(function()
        local hash = joaat(entry.plant)
        if not Citizen.InvokeNative(N.COMPOSITE_ASSETS_LOADED, hash) then
            Citizen.InvokeNative(N.REQUEST_HERB_COMPOSITE_ASSET, hash)
            local deadline = GetGameTimer() + H.CompositeTimeoutMs
            while not Citizen.InvokeNative(N.COMPOSITE_ASSETS_LOADED, hash) do
                if GetGameTimer() > deadline then loaded[entry.key] = nil return end
                Wait(0)
            end
        end
        local l = loaded[entry.key]
        if not l or picked[entry.key] then loaded[entry.key] = nil return end
        local c = entry.coord
        local handle = exports[GetCurrentResourceName()]:CreateHerb(hash, c.x, c.y, c.z, false)
        if handle and handle ~= 0 then
            l.handle, l.loading = handle, false
        else
            loaded[entry.key] = nil
        end
    end)
end

local function unloadAll()
    for key in pairs(loaded) do unload(key) end
    nearby = {}
end

-- streaming: plants in range go in, far ones come out
CreateThread(function()
    while true do
        Wait(1000)
        if H.Enabled and MG.IsOn('herbs') then
            local pos = GetEntityCoords(PlayerPedId())
            local near = {}
            for _, e in ipairs(MG.HerbList) do
                local d = #(pos - e.coord)
                if d <= H.LoadRange and not picked[e.key] then
                    loadPlant(e)
                    if d <= 15.0 then near[#near + 1] = e end
                elseif d >= H.UnloadRange and loaded[e.key] then
                    unload(e.key)
                end
            end
            nearby = near
        elseif next(loaded) then
            unloadAll()
        end
    end
end)

local function pick(entry)
    MG.busy = true
    local ped = PlayerPedId()
    Citizen.InvokeNative(N.TASK_START_SCENARIO_IN_PLACE_HASH, ped, joaat(H.Scenario), -1, true, 0, GetEntityHeading(ped), false)
    Wait(H.PickDurationMs)
    ClearPedTasks(ped)
    lib.callback.await('MULTIgathering:herb:pick', false, entry.key)
    MG.busy = false
end

-- every frame near plants: the game's pick-up prompt on the one in reach
CreateThread(function()
    while true do
        local sleep = 500
        if #nearby > 0 and not MG.busy then
            sleep = 0
            local pos = GetEntityCoords(PlayerPedId())
            local best, bestD
            for _, e in ipairs(nearby) do
                local l = loaded[e.key]
                if l and l.handle and not picked[e.key] then
                    local d = #(pos - e.coord)
                    if d <= H.PickRange and (not bestD or d < bestD) then best, bestD = e, d end
                end
            end
            if best then
                Citizen.InvokeNative(N.DISABLE_LOOTING_COMPOSITE, loaded[best.key].handle, true)
                if pickupPressed() and MG.FreeHands() then pick(best) end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('MULTIgathering:client:herbPicked', function(key, isPicked)
    if type(key) ~= 'string' then return end
    if isPicked then
        picked[key] = true
        unload(key)
    else
        picked[key] = nil
    end
end)

local function syncPicked()
    local list = lib.callback.await('MULTIgathering:herb:picked', false)
    picked = {}
    for _, key in ipairs(type(list) == 'table' and list or {}) do picked[key] = true unload(key) end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() SetTimeout(2000, syncPicked) end)
CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do Wait(1000) end
    syncPicked()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then unloadAll() end
end)
