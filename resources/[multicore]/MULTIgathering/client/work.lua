-- ============================================================
-- MULTIgathering :: mining, lumber and gold panning (client)
-- Mining: MULTItarget "Mine" at each rock face (or a hold prompt within the spot's radius).
-- Lumber: MULTItarget "Chop wood" on trees (or a prompt anywhere inside a lumber zone).
-- Which one: Config.Mining.Interaction / Config.Lumber.Interaction ('auto' = MULTItarget when
-- it runs), decided by MCI.Run (@MULTIcore/lib/interact.lua).
-- Panning: using the gold pan while standing in water.
-- The server checks everything again; this side only finds the place and plays the work.
-- ============================================================

local GET_WATER_MAP_ZONE_AT_COORDS = 0x5BA7A68A346A5A91 -- _GET_WATER_MAP_ZONE_AT_COORDS (femga natives.json)

local function flatInside(pos, coords, radius)
    local dx, dy = pos.x - coords.x, pos.y - coords.y
    return dx * dx + dy * dy <= radius * radius
end

---------------------------------
-- mining
---------------------------------
local mineWork = { scenario = Config.Mining.Scenario, label = _L('work_mining') }
local mineMode = nil     -- 'target' or 'prompt' once MCI.Run has decided
local mineZones = {}

if Config.Mining.Enabled then
    MCI.Run(Config.Mining.Interaction, function(mode)
        mineMode = mode
        if mode == 'target' then
            for _, s in ipairs(Config.MiningSpots or {}) do
                mineZones[#mineZones + 1] = MCI.AddZone({
                    coords = s.coords,
                    radius = s.radius,
                    options = { {
                        name = 'multigathering_mine_' .. s.id,
                        label = _L('prompt_mine'),
                        icon = Config.Mining.TargetIcon,
                        distance = Config.Mining.TargetDistance,
                        canInteract = function()
                            return MG.IsOn('mining') and not MG.depleted[s.id] and MG.FreeHands()
                                and MG.Near(GetEntityCoords(MG.Ped()), s.coords, s.radius)
                        end,
                        onSelect = function() CreateThread(function() MG.RunJob('mining', s.id, mineWork) end) end,
                    } },
                })
            end
        else
            MCI.Count('prompts', 1)
        end
    end, function(mode)
        for _, id in ipairs(mineZones) do MCI.RemoveZone(id) end
        mineZones = {}
        if mode == 'prompt' then MCI.Count('prompts', -1) end
        mineMode = nil
    end)
end

CreateThread(function()
    while true do
        local sleep = 1000
        if Config.Mining.Enabled and mineMode == 'prompt' and MG.IsOn('mining') and not MG.busy then
            local pos = GetEntityCoords(MG.Ped())
            local here
            for _, s in ipairs(Config.MiningSpots or {}) do
                if MG.Near(pos, s.coords, s.radius) then here = s break end
            end
            if here and not MG.depleted[here.id] and MG.FreeHands() then
                sleep = 0
                if MG.ShowPrompt('mine', _L('prompt_mine')) then
                    MG.RunJob('mining', here.id, mineWork)
                end
            else
                MG.HidePrompt('mine')
                if here and MG.depleted[here.id] then sleep = 500 end
            end
        else
            MG.HidePrompt('mine')
        end
        Wait(sleep)
    end
end)

---------------------------------
-- lumber
---------------------------------
local chopWork = { label = _L('work_lumber'), anim = Config.Lumber.Anim, prop = Config.Lumber.Prop }
local chopMode = nil     -- 'target' or 'prompt' once MCI.Run has decided
local treeHashes = {}
for _, m in ipairs(Config.TreeModels or {}) do treeHashes[#treeHashes + 1] = joaat(m) end

local function zoneAt(pos)
    for _, z in ipairs(Config.LumberZones or {}) do
        if flatInside(pos, z.coords, z.radius) then return z end
    end
    return nil
end

if Config.Lumber.Enabled then
    MCI.Run(Config.Lumber.Interaction, function(mode)
        chopMode = mode
        if mode == 'target' then
            exports.MULTItarget:addModel(treeHashes, { {
                name = 'multigathering_chop',
                label = _L('target_chop'),
                icon = Config.Lumber.TargetIcon,
                distance = Config.Lumber.TargetDistance,
                canInteract = function() return MG.IsOn('lumber') and not MG.busy end,
                onSelect = function() CreateThread(function() MG.RunJob('lumber', nil, chopWork) end) end,
            } })
            MCI.Count('targets', 1)
        else
            MCI.Count('prompts', 1)
        end
    end, function(mode)
        if mode == 'target' then
            if MCI.HasTarget() then pcall(function() exports.MULTItarget:removeModel(treeHashes, 'multigathering_chop') end) end
            MCI.Count('targets', -1)
        else
            MG.HidePrompt('chop')
            MCI.Count('prompts', -1)
        end
        chopMode = nil
    end)
end

-- prompt mode: chop anywhere inside a zone that is not cut out
CreateThread(function()
    if not Config.Lumber.Enabled then return end
    while true do
        local sleep = 1000
        if chopMode == 'prompt' and MG.IsOn('lumber') and not MG.busy then
            local z = zoneAt(GetEntityCoords(MG.Ped()))
            if z and not MG.depleted[z.id] and MG.FreeHands() then
                sleep = 0
                if MG.ShowPrompt('chop', _L('prompt_chop')) then MG.RunJob('lumber', nil, chopWork) end
            else
                MG.HidePrompt('chop')
            end
        else
            MG.HidePrompt('chop')
        end
        Wait(sleep)
    end
end)

---------------------------------
-- gold panning (the server sends this when the gold pan is used)
---------------------------------
local function panWork()
    local w = { scenario = Config.Panning.Scenario, label = _L('work_panning') }
    if Config.Panning.Prop then
        w.prop = { model = Config.Panning.Prop, bone = Config.Panning.PropBone, pos = Config.Panning.PropPos, rot = Config.Panning.PropRot }
    end
    return w
end

--- Is the player standing in river, creek, lake, pond or swamp water?
function MG.InPanningWater()
    local ped = MG.Ped()
    if not IsEntityInWater(ped) then return false end
    if Config.Panning.NoSwimming and IsPedSwimming(ped) then return false end
    local c = GetEntityCoords(ped)
    local zone = Citizen.InvokeNative(GET_WATER_MAP_ZONE_AT_COORDS, c.x, c.y, c.z, Citizen.ResultAsInteger())
    return zone ~= nil and zone ~= 0
end

RegisterNetEvent('MULTIgathering:client:pan', function()
    if not Config.Panning.Enabled or not MG.IsOn('panning') or MG.busy then return end
    if not MG.FreeHands() then return MG.Notify(_L('on_foot'), 'error') end
    if not MG.InPanningWater() then return MG.Notify(_L('need_water'), 'error') end
    MG.RunJob('panning', nil, panWork())
end)
