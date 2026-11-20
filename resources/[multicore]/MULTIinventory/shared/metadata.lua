-- ============================================================
-- MULTIinventory :: metadata helpers (shared)
--
-- Contract (used by every part):
--   Meta.normalize(meta)  -> table      nil / '' / '[]' / '{}' become {}
--   Meta.canonical(meta)  -> string     stable JSON: keys sorted, ignored keys
--                                       (Config.Stacking.ignoreKeys) dropped,
--                                       numbers formatted the same way on every side
--   Meta.stackKey(item, meta) -> string item .. '|' .. canonical(meta)
--   Meta.equal(a, b)      -> boolean    canonical(a) == canonical(b)
--
-- Two stacks may merge only when stackKey is identical. The server stores
-- sha1(canonical) in multiinv_stacks.meta_hash for indexed look-ups.
--
-- Reserved metadata keys understood by the UI (compatible with what the
-- server's resources already send - see:
--   label, description, image, weight, tooltip, context, useExpired,
--   durability, quality, quality_label, maker, maker_cid, made_by, made_at,
--   batch, expires_at, bagId (tack), and the clothing contract (cv=1 ...).
-- ============================================================

Meta = {}

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function isArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    for i = 1, n do if t[i] == nil then return false end end
    return true
end

local function encode(v, ignore, depth)
    local tv = type(v)
    if tv == 'table' then
        if next(v) == nil then return '{}' end
        if isArray(v) then
            local parts = {}
            for i = 1, #v do parts[i] = encode(v[i], nil, depth + 1) end
            return '[' .. table.concat(parts, ',') .. ']'
        end
        local parts = {}
        for _, k in ipairs(sortedKeys(v)) do
            if not (depth == 0 and ignore and ignore[k]) then
                parts[#parts + 1] = json.encode(tostring(k)) .. ':' .. encode(v[k], nil, depth + 1)
            end
        end
        return '{' .. table.concat(parts, ',') .. '}'
    elseif tv == 'number' then
        if v == math.floor(v) and math.abs(v) < 2^53 then return string.format('%d', v) end
        return string.format('%.6g', v)
    elseif tv == 'string' then
        return json.encode(v)
    elseif tv == 'boolean' then
        return v and 'true' or 'false'
    end
    return 'null'
end

function Meta.normalize(meta)
    if meta == nil or meta == '' then return {} end
    if type(meta) == 'string' then
        local ok, t = pcall(json.decode, meta)
        meta = ok and t or {}
    end
    if type(meta) ~= 'table' then return {} end
    return meta
end

function Meta.canonical(meta)
    local ignore = Config and Config.Stacking and Config.Stacking.ignoreKeys or nil
    return encode(Meta.normalize(meta), ignore, 0)
end

function Meta.stackKey(item, meta)
    return tostring(item) .. '|' .. Meta.canonical(meta)
end

function Meta.equal(a, b)
    return Meta.canonical(a) == Meta.canonical(b)
end

-- sha1(canonical) - stored in multiinv_stacks.meta_hash (needs shared/util.lua).
function Meta.hash(meta)
    return Util.sha1(Meta.canonical(meta))
end

-- true when the metadata has no keys that matter for stacking
function Meta.isEmpty(meta)
    return Meta.canonical(meta) == '{}'
end
