-- ============================================================
-- MULTIfarming :: shared helpers (server and client)
-- Crop lookups built once from config/crops.lua, and the growth model both sides read.
-- ============================================================

FM = FM or {}

--- Flat (x/y) distance squared between two points.
function FM.Dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

---------------------------------
-- crops: seed item -> crop id, total growth minutes per crop
---------------------------------
FM.CropBySeed = {}   -- [seed item] = crop id
FM.GrowMinutes = {}  -- [crop id] = watered minutes from planting to ripe

for id, c in pairs(Config.Crops or {}) do
    FM.CropBySeed[c.seed] = id
    local total = 0
    for i = 1, #c.stages - 1 do total = total + (tonumber(c.stages[i].minutes) or 0) end
    FM.GrowMinutes[id] = total
end

--- The stage a crop is in after `progress` watered minutes: 1 .. #stages (the last is ripe).
function FM.StageOf(cropId, progress)
    local c = Config.Crops[cropId]
    if not c then return 1 end
    local acc = 0
    for i = 1, #c.stages - 1 do
        acc = acc + (tonumber(c.stages[i].minutes) or 0)
        if progress < acc then return i end
    end
    return #c.stages
end

--- The prop model name of a crop in a stage (dead = Config.Growth.DeadProp).
function FM.PropOf(cropId, stage, dead)
    if dead then return Config.Growth.DeadProp end
    local c = Config.Crops[cropId]
    local s = c and (c.stages[stage] or c.stages[#c.stages])
    return s and s.prop or nil
end

--- Is `pos` inside one of Config.FarmZones (or are there none)?
function FM.InFarmZone(pos)
    local zones = Config.FarmZones or {}
    if #zones == 0 then return true end
    for _, z in ipairs(zones) do
        if FM.Dist2(pos, z.coords) <= z.radius * z.radius then return true end
    end
    return false
end
