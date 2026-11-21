-- ============================================================
-- MULTIhorses :: stable hands, stable blips and the way into the stable menu
-- The stable menu opens through MULTItarget on the stable hand, or a
-- hold-key prompt when MULTItarget is not running (Config.Interact,
-- @MULTIcore/lib/interact.lua). Nothing is drawn in the world.
-- ============================================================
local spawnedPeds = {}
local stableBlips = {}
local interactMode = nil   -- 'target' or 'prompt' once MCI.Run has decided

local function stableOption(stableid)
    return {
        name = 'multihorses_stable',
        icon = Config.TargetIcon,
        label = _L('cl_menu'),
        distance = Config.TargetDistance,
        onSelect = function()
            TriggerEvent('MULTIhorses:client:stablemenu', stableid)
        end,
    }
end

-- blips
CreateThread(function()
    for _, v in pairs(Config.StableSettings) do
        if v.showblip == true then
            local blip = BlipAddForCoords(1664425300, v.coords)
            SetBlipSprite(blip, joaat(Config.Blip.blipSprite), true)
            SetBlipScale(blip, Config.Blip.blipScale)
            SetBlipName(blip, _L('cf_menu_horse_blip_name'))
            stableBlips[#stableBlips + 1] = blip
        end
    end
end)

-- MULTItarget on the stable hands, or prompts at the stables
MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    if mode == 'prompt' then
        for _, v in pairs(Config.StableSettings) do
            MCI.AddPrompt('multihorses_' .. v.stableid, v.coords, Config.KeyBind, _L('cl_menu'), {
                type = 'client',
                event = 'MULTIhorses:client:stablemenu',
                args = { v.stableid },
            }, Config.PromptDistance)
        end
    else
        for _, point in pairs(spawnedPeds) do
            if point.ped then MCI.AddEntity(point.ped, { stableOption(point.stableid) }) end
        end
    end
end, function()
    for _, point in pairs(spawnedPeds) do
        if point.ped then MCI.RemoveEntity(point.ped) end
    end
    for _, v in pairs(Config.StableSettings) do MCI.RemovePrompt('multihorses_' .. v.stableid) end
end)

local function NearNPC(npcmodel, npccoords, heading)
    local spawnedPed = CreatePed(npcmodel, npccoords.x, npccoords.y, npccoords.z - 1.0, heading, false, false, 0, 0)
    SetEntityAlpha(spawnedPed, 0, false)
    SetRandomOutfitVariation(spawnedPed, true)
    SetEntityCanBeDamaged(spawnedPed, false)
    SetEntityInvincible(spawnedPed, true)
    FreezeEntityPosition(spawnedPed, true)
    SetBlockingOfNonTemporaryEvents(spawnedPed, true)
    SetPedCanBeTargetted(spawnedPed, false)
    if Config.FadeIn then
        for i = 0, 255, 51 do
            Wait(50)
            SetEntityAlpha(spawnedPed, i, false)
        end
    end
    return spawnedPed
end

CreateThread(function()
    for k, v in pairs(Config.StableSettings) do
        local coords = v.npccoords
        local newpoint = lib.points.new({
            coords = coords,
            heading = coords.w,
            distance = Config.DistanceSpawn,
            model = v.npcmodel,
            ped = nil,
            stableid = v.stableid
        })

        newpoint.onEnter = function(self)
            if not self.ped then
                lib.requestModel(self.model, 10000)
                self.ped = NearNPC(self.model, self.coords, self.heading)
                if interactMode == 'target' then
                    MCI.AddEntity(self.ped, { stableOption(self.stableid) })
                end
            end
        end

        newpoint.onExit = function(self)
            if self.ped then MCI.RemoveEntity(self.ped) end
            if self.ped and DoesEntityExist(self.ped) then
                if Config.FadeIn then
                    for i = 255, 0, -51 do
                        Wait(50)
                        SetEntityAlpha(self.ped, i, false)
                    end
                end
                DeleteEntity(self.ped)
                self.ped = nil
            end
        end

        spawnedPeds[k] = newpoint
    end
end)

MCI.Counter('npcs', function()
    local n = 0
    for _, point in pairs(spawnedPeds) do
        if point.ped and DoesEntityExist(point.ped) then n = n + 1 end
    end
    return n
end)

-- cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for k, v in pairs(spawnedPeds) do
        if v.ped then MCI.RemoveEntity(v.ped) end
        if v.ped and DoesEntityExist(v.ped) then
            DeleteEntity(v.ped)
        end
        spawnedPeds[k] = nil
    end
    for _, blip in ipairs(stableBlips) do RemoveBlip(blip) end
end)
