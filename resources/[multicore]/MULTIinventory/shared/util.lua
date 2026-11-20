-- ============================================================
-- MULTIinventory :: shared/util.lua
--
--   Util.round(n, dp)          Util.clamp(n, lo, hi)
--   Util.deepcopy(t)           Util.tbool(v)
--   Util.isWeaponName(name)    WEAPON_* (case-insensitive prefix)
--   Util.now()                 unix seconds
--   Util.sha1(str)             40 hex chars (pure Lua 5.4)
--   Util.jsonEncode(t)         json, empty table -> '{}'
--   Util.jsonDecode(s, def)    safe decode, def on failure
--   Util.toInt(v)              integer or nil
--   Util.joaat(s)              Jenkins one-at-a-time (signed 32-bit like GetHashKey)
-- ============================================================

Util = Util or {}

function Util.round(n, dp)
    local m = 10 ^ (dp or 0)
    return math.floor((tonumber(n) or 0) * m + 0.5) / m
end

function Util.clamp(n, lo, hi)
    n = tonumber(n) or lo
    if n ~= n then return lo end -- nan guard
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function Util.deepcopy(t, seen)
    if type(t) ~= 'table' then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local out = {}
    seen[t] = out
    for k, v in pairs(t) do out[Util.deepcopy(k, seen)] = Util.deepcopy(v, seen) end
    return out
end

function Util.tbool(v)
    return v == true or v == 1 or v == '1' or v == 'true'
end

-- Weapon names start with WEAPON_, but some plain items do too (weapon_order, weapon_repair_kit).
-- A name the weapon table knows is always a weapon; otherwise a cached item definition that is
-- not a weapon type wins (server only, no DB look-up); otherwise the prefix decides.
local WEAPON_TYPES = { item_weapon = true, weapon = true }
function Util.isWeaponName(name)
    if type(name) ~= 'string' or name:upper():sub(1, 7) ~= 'WEAPON_' then return false end
    if WeaponDefs and WeaponDefs.isKnown and WeaponDefs.isKnown(name) then return true end
    local all = Registry and Registry.all and Registry.all()
    local d = all and (all[name] or all[name:lower()])
    if d and not WEAPON_TYPES[tostring(d.type)] then return false end
    return true
end

function Util.now()
    return os.time()
end

function Util.toInt(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    if v ~= math.floor(v) then return nil end
    return math.tointeger(v)
end

function Util.jsonEncode(t)
    if type(t) ~= 'table' or next(t) == nil then return '{}' end
    local ok, s = pcall(json.encode, t)
    return ok and s or '{}'
end

function Util.jsonDecode(s, default)
    if type(s) == 'table' then return s end
    if type(s) ~= 'string' or s == '' then return default end
    local ok, t = pcall(json.decode, s)
    if ok and t ~= nil then return t end
    return default
end

function Util.joaat(s)
    s = tostring(s):lower()
    local h = 0
    for i = 1, #s do
        h = (h + s:byte(i)) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h = h ~ (h >> 6)
    end
    h = (h + (h << 3)) & 0xFFFFFFFF
    h = h ~ (h >> 11)
    h = (h + (h << 15)) & 0xFFFFFFFF
    if h >= 0x80000000 then h = h - 0x100000000 end
    return h
end

-- ------------------------------------------------------------
-- SHA-1 (FIPS 180-1), 32-bit arithmetic on Lua 5.4 integers.
-- ------------------------------------------------------------
local function rol(x, n)
    return ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF
end

function Util.sha1(msg)
    msg = tostring(msg)
    local h0, h1, h2, h3, h4 = 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0
    local ml = #msg * 8
    msg = msg .. '\128' .. string.rep('\0', (55 - #msg) % 64) .. string.pack('>I8', ml)
    local w = {}
    for chunk = 1, #msg, 64 do
        for i = 0, 15 do
            w[i] = string.unpack('>I4', msg, chunk + i * 4)
        end
        for i = 16, 79 do
            w[i] = rol(w[i - 3] ~ w[i - 8] ~ w[i - 14] ~ w[i - 16], 1)
        end
        local a, b, c, d, e = h0, h1, h2, h3, h4
        for i = 0, 79 do
            local f, k
            if i < 20 then
                f = (b & c) | ((~b) & d); k = 0x5A827999
            elseif i < 40 then
                f = b ~ c ~ d; k = 0x6ED9EBA1
            elseif i < 60 then
                f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC
            else
                f = b ~ c ~ d; k = 0xCA62C1D6
            end
            local temp = (rol(a, 5) + (f & 0xFFFFFFFF) + e + k + w[i]) & 0xFFFFFFFF
            e = d; d = c; c = rol(b, 30); b = a; a = temp
        end
        h0 = (h0 + a) & 0xFFFFFFFF
        h1 = (h1 + b) & 0xFFFFFFFF
        h2 = (h2 + c) & 0xFFFFFFFF
        h3 = (h3 + d) & 0xFFFFFFFF
        h4 = (h4 + e) & 0xFFFFFFFF
    end
    return string.format('%08x%08x%08x%08x%08x', h0, h1, h2, h3, h4)
end
