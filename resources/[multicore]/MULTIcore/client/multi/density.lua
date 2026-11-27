-- ============================================================
-- MULTIcore :: ambient traffic and crowd density
-- Part of MULTIcore by RINGO (RINGOscripting). GPL v3.
--
-- How many people, animals, wagons and coaches the game puts in the world around each
-- player, set in config_multi.lua (MULTIConfig.Density). 1.0 = the game's own amount,
-- 0.5 = half, 0.0 = none. While every value is 1.0 nothing runs.
--
-- The game forgets these each frame, so they are set every frame in MULTIcore's one frame
-- thread (client/prompts.lua).
--
-- Natives (femga natives.json):
--   _SET_AMBIENT_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME   0xBA0980B5C0A11924 (float)
--   _SET_SCENARIO_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME  0x28CB6391ACEDD9DB (float)
--   _SET_AMBIENT_ANIMAL_DENSITY_MULTIPLIER_THIS_FRAME  0xC0258742B034DFAF (float)
--   _SET_SCENARIO_ANIMAL_DENSITY_MULTIPLIER_THIS_FRAME 0xDB48E99F8E064E56 (float)
--   SET_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME          0x606374EBFC27B133 (float)
--   SET_RANDOM_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME   0x1F91D44490E1EA0C (float)
--   SET_PARKED_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME   0xFEDFA97638D61D4A (float)
--
-- Other scripts can change the values while the server runs (for this player only):
--   exports.MULTIcore:SetDensity('Peds', 0.3)      -- one value
--   exports.MULTIcore:SetDensity({ Vehicles = 0 }) -- several
--   exports.MULTIcore:ResetDensity()              -- back to config_multi.lua
--   exports.MULTIcore:GetDensity()                -- the values in use
-- ============================================================

local KEYS = { 'Peds', 'ScenarioPeds', 'Animals', 'Vehicles', 'RandomVehicles', 'ParkedVehicles' }

local cur = {}
local active = false

local function clamp(v)
    v = tonumber(v)
    if not v then return 1.0 end
    if v < 0.0 then return 0.0 end
    if v > 1.0 then return 1.0 end
    return v + 0.0
end

local function refresh()
    active = false
    for _, k in ipairs(KEYS) do
        if cur[k] ~= 1.0 then active = true end
    end
end

local function fromConfig()
    local cfg = (MULTIConfig and MULTIConfig.Density) or {}
    for _, k in ipairs(KEYS) do cur[k] = clamp(cfg[k] == nil and 1.0 or cfg[k]) end
    refresh()
end
fromConfig()

local InvokeNative = Citizen.InvokeNative
MULTIFrame.add(function()
    if not active then return end
    local p, a = cur.Peds, cur.Animals
    InvokeNative(0xBA0980B5C0A11924, p)               -- people walking about
    InvokeNative(0x28CB6391ACEDD9DB, cur.ScenarioPeds) -- people sitting, working, standing around
    InvokeNative(0xC0258742B034DFAF, a)               -- animals roaming
    InvokeNative(0xDB48E99F8E064E56, a)               -- animals at their spots (grazing, perching)
    InvokeNative(0x606374EBFC27B133, cur.Vehicles)     -- all wagon and coach traffic
    InvokeNative(0x1F91D44490E1EA0C, cur.RandomVehicles) -- wagons and coaches driving the roads
    InvokeNative(0xFEDFA97638D61D4A, cur.ParkedVehicles) -- wagons standing parked
end)

exports('SetDensity', function(key, value)
    if type(key) == 'table' then
        for k, v in pairs(key) do if cur[k] ~= nil then cur[k] = clamp(v) end end
    elseif cur[key] ~= nil then
        cur[key] = clamp(value)
    end
    refresh()
end)

exports('ResetDensity', fromConfig)

exports('GetDensity', function()
    local out = {}
    for _, k in ipairs(KEYS) do out[k] = cur[k] end
    return out
end)
