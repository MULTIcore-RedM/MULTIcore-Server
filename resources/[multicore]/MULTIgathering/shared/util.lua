-- ============================================================
-- MULTIgathering :: shared helpers (server and client)
-- Lookups built once from the config files, used by both sides so they always agree.
-- ============================================================

MG = MG or {}

--- A model name or hash as an unsigned 32-bit number.
function MG.Hash(model)
    if type(model) == 'string' then
        if model:match('^%-?%d+$') then model = tonumber(model) else return joaat(model:lower()) & 0xFFFFFFFF end
    end
    if type(model) ~= 'number' then return nil end
    return math.tointeger(model) and (math.tointeger(model) & 0xFFFFFFFF) or nil
end

--- Flat (x/y) distance plus a height window: spot coords may sit a little above or below the ground.
function MG.Near(pos, coords, radius)
    if not pos or not coords then return false end
    local dx, dy = pos.x - coords.x, pos.y - coords.y
    if dx * dx + dy * dy > radius * radius then return false end
    return math.abs(pos.z - coords.z) <= Config.ZTolerance
end

---------------------------------
-- fish: hash -> { model, item, min, max }
---------------------------------
MG.FishByHash = {}
for model, def in pairs(Config.Fish or {}) do
    local d = { model = model, item = def.item, min = def.min, max = def.max }
    MG.FishByHash[MG.Hash(model)] = d
end

function MG.FishDef(model)
    local h = MG.Hash(model)
    return h and MG.FishByHash[h] or nil
end

-- bait -> set of fish hashes it attracts
MG.BaitSet = {}
for bait, list in pairs(Config.BaitFish or {}) do
    local set = {}
    for _, m in ipairs(list) do set[MG.Hash(m)] = true end
    MG.BaitSet[bait] = set
end

MG.IsBait = {}
for _, b in ipairs(Config.Fishing.Baits or {}) do MG.IsBait[b] = true end

---------------------------------
-- mining spots and lumber zones: id -> def
---------------------------------
MG.Spots = {}   -- [id] = { kind = 'mining'|'lumber', def = config entry }
for _, s in ipairs(Config.MiningSpots or {}) do MG.Spots[s.id] = { kind = 'mining', def = s } end
for _, z in ipairs(Config.LumberZones or {}) do MG.Spots[z.id] = { kind = 'lumber', def = z } end

---------------------------------
-- herb spots: key -> { coord, plant }  (the same keys as rsg-herbalist: "x_y_z" with one decimal)
---------------------------------
function MG.HerbKey(c)
    return ('%.1f_%.1f_%.1f'):format(c.x, c.y, c.z)
end

MG.HerbSpots = {}    -- [key] = { coord = vector3, plant = composite name }
MG.HerbList = {}     -- list of the same entries, for the client's streaming loop
for _, zone in pairs(Config.HerbSpots or {}) do
    local plants = zone.plants or {}
    if #plants > 0 then
        for i, c in ipairs(zone.coords or {}) do
            local key = MG.HerbKey(c)
            if not MG.HerbSpots[key] then
                local e = { key = key, coord = vector3(c.x, c.y, c.z), plant = plants[((i - 1) % #plants) + 1] }
                MG.HerbSpots[key] = e
                MG.HerbList[#MG.HerbList + 1] = e
            end
        end
    end
end
