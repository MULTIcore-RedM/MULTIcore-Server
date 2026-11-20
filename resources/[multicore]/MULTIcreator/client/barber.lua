-- ============================================================
-- MULTIcreator :: barber shops
-- Blips, the barber NPC and the MULTItarget option / prompt that opens
-- the creator in 'barber' mode. Shop positions: config.lua.
-- Interaction through @MULTIcore/lib/interact.lua (Config.Barber.interact).
-- ============================================================

local blips, prompts, zones, npcs = {}, {}, {}, {}
local interactMode = nil  -- 'target' or 'prompt' once MCI.Run has decided

local function openShop(index)
    local shop = Config.BarberShops[tonumber(index) or 0]
    if not shop then return end
    if exports.MULTIcreator:IsOpen() then
        exports.MULTIcore:Notify(_L('busy'), 'error', Config.Timing.notifyMs)
        return
    end
    exports.MULTIcreator:Open('barber', nil, shop)
end

AddEventHandler('MULTIcreator:client:openBarberLocal', function(index) openShop(index) end)

local function addBlip(shop)
    local c = shop.coords
    local blip = Citizen.InvokeNative(0x554D9D53F696D002, Config.Barber.blipStyle, c.x, c.y, c.z) -- BLIP_ADD_FOR_COORDS
    SetBlipSprite(blip, Config.Barber.blipSprite, true)
    SetBlipScale(blip, Config.Barber.blipScale)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, _L('blip_barber')) -- _SET_BLIP_NAME
    blips[#blips + 1] = blip
end

local function shopLabel(shop) return _L('prompt_barber', _L('shop_' .. shop.id)) end

-- the barber option for one shop (zone and barber NPC use the same one)
local function shopOption(i, shop)
    return {
        name = 'multicreator_barber_' .. i,
        label = shopLabel(shop),
        icon = Config.Barber.targetIcon,
        distance = Config.Barber.targetDistance,
        onSelect = function() openShop(i) end,
    }
end

-- MULTItarget ('auto' / 'target') or hold-key prompts
MCI.Run(Config.Barber.interact, function(mode)
    interactMode = mode
    for i, shop in ipairs(Config.BarberShops) do
        if mode == 'target' then
            zones[#zones + 1] = MCI.AddZone({ coords = shop.coords, radius = Config.Barber.targetRadius, options = { shopOption(i, shop) } })
            if npcs[i] then MCI.AddEntity(npcs[i], { shopOption(i, shop) }) end
        else
            local name = 'multicreator_barber_' .. i
            MCI.AddPrompt(name, shop.coords, Config.Barber.promptKey, shopLabel(shop),
                { type = 'client', event = 'MULTIcreator:client:openBarberLocal', args = { i } }, Config.Barber.promptDistance)
            prompts[#prompts + 1] = name
        end
    end
end, function()
    for _, z in ipairs(zones) do MCI.RemoveZone(z) end
    zones = {}
    for _, ped in pairs(npcs) do MCI.RemoveEntity(ped) end
    for _, n in ipairs(prompts) do MCI.RemovePrompt(n) end
    prompts = {}
    interactMode = nil
end)

-- for /mcinteract
MCI.Counter('npcs', function()
    local n = 0
    for _ in pairs(npcs) do n = n + 1 end
    return n
end)

-- blips, then barber NPCs: spawned locally while the player is near
CreateThread(function()
    for _, shop in ipairs(Config.BarberShops) do
        if Config.Barber.blips and shop.blip then addBlip(shop) end
    end
    local model = Config.Barber.npcModel
    while true do
        local p = GetEntityCoords(PlayerPedId())
        for i, shop in ipairs(Config.BarberShops) do
            local n = shop.npc
            local near = n and #(p - vector3(n.x, n.y, n.z)) < Config.Barber.npcDistance
            if near and not npcs[i] then
                RequestModel(model, false)
                local t = GetGameTimer() + Config.Timing.collisionWaitMs
                while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
                if HasModelLoaded(model) then
                    local ped = CreatePed(model, n.x, n.y, n.z + Config.Barber.npcZOffset, n.w, false, false, false, false)
                    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
                    FreezeEntityPosition(ped, true)
                    SetEntityInvincible(ped, true)
                    SetBlockingOfNonTemporaryEvents(ped, true)
                    SetModelAsNoLongerNeeded(model)
                    npcs[i] = ped
                    if interactMode == 'target' then MCI.AddEntity(ped, { shopOption(i, shop) }) end
                end
            elseif not near and npcs[i] then
                local ped = npcs[i]
                MCI.RemoveEntity(ped)
                DeleteEntity(ped)
                npcs[i] = nil
            end
        end
        Wait(Config.Barber.npcCheckMs)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    for _, n in ipairs(prompts) do MCI.RemovePrompt(n) end
    -- MULTItarget drops this script's zones and entity options by itself when it stops
    for _, ped in pairs(npcs) do DeleteEntity(ped) end
end)
