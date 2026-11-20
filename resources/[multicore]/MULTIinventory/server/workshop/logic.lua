-- ============================================================
-- MULTIinventory :: server/workshop/logic.lua
--
-- Pure workshop rules (no FiveM calls) so tests/workshop_harness.lua can drive them.
--
--   WorkshopLogic.num(v) -> finite number | nil
--   WorkshopLogic.durability(meta, def, max) -> current durability (missing = item default, else max)
--   WorkshopLogic.sharpenMeta(meta, toolCfg, max) -> new metadata | nil, 'already_sharp'
--   WorkshopLogic.chapterOf(category, chapters) -> chapter key
--   WorkshopLogic.dist(a, b) -> metres | nil (nil when a position is unknown)
--   WorkshopLogic.nearest(stations, pos, stype, radius) -> station | nil
--   WorkshopLogic.expiry(meta, now, lifetimeHours) -> unix seconds the station disappears
--   WorkshopLogic.validPlacement(p) -> { x, y, z, heading } | nil
--   WorkshopLogic.countOwned(stations, charId, stype) -> n
-- ============================================================

WorkshopLogic = WorkshopLogic or {}
local M = WorkshopLogic

local HUGE = math.huge

function M.num(v)
    v = tonumber(v)
    if v == nil or v ~= v or v == HUGE or v == -HUGE then return nil end
    return v
end

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end
M.copy = copy

function M.durability(meta, def, max)
    max = M.num(max) or 100
    local d = type(meta) == 'table' and M.num(meta.durability) or nil
    if d == nil and type(def) == 'table' then d = M.num(def.durability) end
    if d == nil then d = max end
    if d < 0 then d = 0 end
    if d > max then d = max end
    return d
end

---Metadata after a sharpen: durability back to max, the owning script's "broken" label removed,
---its description refreshed. Every other key is kept.
function M.sharpenMeta(meta, toolCfg, max, def)
    max = M.num(max) or 100
    toolCfg = type(toolCfg) == 'table' and toolCfg or {}
    if M.durability(meta, def, max) >= max then return nil, 'already_sharp' end
    local out = copy(type(meta) == 'table' and meta or {})
    out.durability = max
    if toolCfg.brokenLabel and out.label == toolCfg.brokenLabel then out.label = nil end
    if type(toolCfg.description) == 'string' then out.description = toolCfg.description end
    return out
end

function M.chapterOf(category, chapters)
    for _, ch in ipairs(chapters or {}) do
        for _, c in ipairs(ch.categories or {}) do
            if c == category then return ch.key end
        end
    end
    return 'other'
end

function M.dist(a, b)
    if not a or not b then return nil end
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function M.nearest(stations, pos, stype, radius)
    if not pos then return nil end
    local best, bestD
    for _, s in pairs(stations or {}) do
        if s.type == stype then
            local d = M.dist(pos, s)
            if d and d <= radius and (not bestD or d < bestD) then best, bestD = s, d end
        end
    end
    return best
end

---A station keeps the life it had when it was first put down: a picked-up one carries
---metadata.expiresAt and goes down again with what is left (a time in the past = worn out,
---the caller refuses to place it).
function M.expiry(meta, now, lifetimeHours)
    local e = type(meta) == 'table' and M.num(meta.expiresAt) or nil
    if e then return math.floor(e) end
    return math.floor(now + (M.num(lifetimeHours) or 48) * 3600)
end

function M.validPlacement(p)
    if type(p) ~= 'table' then return nil end
    local x, y, z = M.num(p.x), M.num(p.y), M.num(p.z)
    local h = M.num(p.heading) or 0.0
    if not x or not y or not z then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or z < -500 or z > 3000 then return nil end
    h = h % 360
    return { x = x, y = y, z = z, heading = h }
end

function M.countOwned(stations, charId, stype)
    local n = 0
    for _, s in pairs(stations or {}) do
        if s.owner == charId and s.type == stype then n = n + 1 end
    end
    return n
end

return M
