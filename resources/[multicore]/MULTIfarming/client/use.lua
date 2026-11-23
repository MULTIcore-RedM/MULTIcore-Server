-- ============================================================
-- MULTIfarming :: using seeds and the watering can (client)
-- Seeds: the server sends the crop when a seed is used from the satchel. This side finds the
-- spot in front of the player and refuses towns, interiors, water, roads and spots next to
-- another crop, then runs the planting work. The server checks seed, hoe, limit, distance,
-- farm zones and spacing again.
-- Watering can: standing in a river or lake fills it; next to a crop it waters the crop.
-- ============================================================

local N = {   -- natives (femga natives.json)
    GET_MAP_ZONE_AT_COORDS = 0x43AD8FC02B429D33,        -- _GET_MAP_ZONE_AT_COORDS (type 1 = TOWN)
    GET_WATER_MAP_ZONE_AT_COORDS = 0x5BA7A68A346A5A91,  -- _GET_WATER_MAP_ZONE_AT_COORDS
    IS_POINT_ON_ROAD = 0x125BF4ABFC536B09,              -- IS_POINT_ON_ROAD
}
local MAP_ZONE_TOWN = 1
local PL = Config.Planting

local function truthy(v) return v == true or (type(v) == 'number' and v ~= 0) end

--- Where the seed would go, or nil, err.
local function plantSpot()
    local ped = FM.Ped()
    if PL.NoWater and (IsEntityInWater(ped) or IsPedSwimming(ped)) then return nil, 'in_water' end
    if PL.NoInteriors and GetInteriorFromEntity(ped) ~= 0 then return nil, 'indoors' end
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local x, y = pos.x + fwd.x * PL.Forward, pos.y + fwd.y * PL.Forward
    if PL.NoTowns then
        local town = Citizen.InvokeNative(N.GET_MAP_ZONE_AT_COORDS, x, y, pos.z, MAP_ZONE_TOWN, Citizen.ResultAsInteger())
        if town and town ~= 0 then return nil, 'in_town' end
    end
    local found, gz = GetGroundZFor_3dCoord(x, y, pos.z + 1.0, false)
    if not found or not gz or gz == 0.0 then return nil, 'bad_ground' end
    local feet = pos.z - 1.0   -- a standing ped's coords are about a metre above its feet
    if math.abs(gz - feet) > PL.MaxGroundStep then return nil, 'bad_ground' end
    if PL.NoWater then
        local w = Citizen.InvokeNative(N.GET_WATER_MAP_ZONE_AT_COORDS, x, y, gz, Citizen.ResultAsInteger())
        if w and w ~= 0 and IsEntityInWater(ped) then return nil, 'in_water' end
    end
    if PL.NoRoads and truthy(Citizen.InvokeNative(N.IS_POINT_ON_ROAD, x, y, gz, 0)) then return nil, 'on_road' end
    local spot = vector3(x, y, gz)
    if not FM.InFarmZone(spot) then return nil, 'no_zone' end
    local s2 = PL.MinSpacing * PL.MinSpacing
    for _, plant in pairs(FM.Plants) do
        if FM.Dist2(spot, plant) < s2 and math.abs(gz - plant.z) < 3.0 then return nil, 'too_close' end
    end
    return { x = x, y = y, z = gz, h = GetEntityHeading(ped) }
end

RegisterNetEvent('MULTIfarming:client:plant', function(crop)
    if type(crop) ~= 'string' or not Config.Crops[crop] then return end
    if FM.busy then return FM.Notify(_L('busy'), 'error') end
    if not FM.FreeHands() then return FM.Notify(_L('on_foot'), 'error') end
    local spot, err = plantSpot()
    if not spot then return FM.Notify(_L(err), 'error') end
    FM.RunJob('plant', crop, { label = _L('work_plant'), scenario = PL.Scenario }, function() return spot end)
end)

---------------------------------
-- watering can
---------------------------------
--- Is the player standing in river, creek, lake, pond or swamp water?
local function inFillWater()
    local ped = FM.Ped()
    if not IsEntityInWater(ped) then return false end
    if Config.Watering.FillNoSwimming and IsPedSwimming(ped) then return false end
    local c = GetEntityCoords(ped)
    local zone = Citizen.InvokeNative(N.GET_WATER_MAP_ZONE_AT_COORDS, c.x, c.y, c.z, Citizen.ResultAsInteger())
    return zone ~= nil and zone ~= 0
end

RegisterNetEvent('MULTIfarming:client:useCan', function()
    if FM.busy then return FM.Notify(_L('busy'), 'error') end
    if not FM.FreeHands() then return FM.Notify(_L('on_foot'), 'error') end
    if inFillWater() then
        FM.RunJob('fill', nil, { label = _L('work_fill'), scenario = Config.Watering.FillScenario })
        return
    end
    local plant = FM.NearestPlant(Config.Watering.UseRange)
    if plant then return FM.Water(plant.id) end
    FM.Notify(_L('no_crop_near'), 'error')
end)
