-- ============================================================
-- MULTIdoors :: shared helpers (client and server)
-- Door hashes, area names and the rule shape. GPL v3.
-- ============================================================

MDS = {}

--- A door hash as a positive whole number (scripts often write them signed).
function MDS.Hash(h)
    h = tonumber(h)
    if not h or h ~= h or h % 1 ~= 0 then return nil end
    if h < 0 then h = h + 4294967296 end
    if h <= 0 or h > 4294967295 then return nil end
    return math.floor(h)
end

--- Data of a door from data/doors.lua (nil when the hash is not listed).
function MDS.Door(h)
    h = MDS.Hash(h)
    return h and MULTIDoorData[h] or nil
end

--- Readable area for map x / y: the town it is in, "near <town>" or "wilderness".
function MDS.AreaOf(x, y)
    local inside, insideD, near, nearD
    for _, t in ipairs(Config.Towns or {}) do
        local d = math.sqrt((x - t.x) ^ 2 + (y - t.y) ^ 2)
        if d <= t.radius and (not insideD or d < insideD) then inside, insideD = t.name, d end
        local edge = d - t.radius
        if not nearD or edge < nearD then near, nearD = t.name, edge end
    end
    if inside then return inside end
    if near and nearD <= (Config.NearTownDistance or 0) then return _L('area_near', near) end
    return _L('area_wild')
end

-- area names are worked out once from config/towns.lua
CreateThread(function()
    for _, d in pairs(MULTIDoorData) do d.area = MDS.AreaOf(d.x, d.y) end
end)

--- Rule id rule: letters, digits, _ and -, at most 64 characters.
function MDS.ValidId(id)
    return type(id) == 'string' and #id >= 1 and #id <= 64 and id:match('^[%w_%-]+$') ~= nil
end

--- "key_valentine_jail" -> "Valentine Jail"
function MDS.Pretty(name)
    local s = tostring(name or ''):gsub('^key_', ''):gsub('_', ' ')
    return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end
