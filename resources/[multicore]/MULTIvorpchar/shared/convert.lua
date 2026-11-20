-- ============================================================
-- MULTIvorpchar :: shape translation (client and server)
-- vorp_character keeps clothes as { [Key] = { comp = hash, palette = hash,
-- tint0, tint1, tint2 } } with its own keys (Hat, Shirt, Pant ...); a comp
-- of -1 (or 0) means "nothing there". The shape is learnt from how VORP
-- scripts call it. MULTIcore keeps { [category] = { index, palette =
-- index, tint0.. } } where index points into MULTIData.Clothes[sex][category].
-- ============================================================

VC = VC or {}

local Clothes = (MULTIData and MULTIData.Clothes) or {}
local Palettes = (MULTIData and MULTIData.Palettes) or {}
local TINT_MAX = 254

-- categories that belong to the skin (face / body), never clothing
VC.SkinCategories = {
    heads = true, bodies_upper = true, bodies_lower = true, eyes = true, teeth = true,
    hair = true, beards_complete = true,
}

function VC.Debug(...)
    if Config.Debug then print('[MULTIvorpchar]', ...) end
end

-- category -> vorp key (first key wins)
VC.KeyOf = {}
for key, cat in pairs(Config.Keys) do
    if not VC.KeyOf[cat] then VC.KeyOf[cat] = key end
end

local function u32(h)
    h = tonumber(h)
    if not h or h ~= h then return nil end
    return math.floor(h) & 0xFFFFFFFF
end

local byHash = {} -- [sex][u32 hash] = { cat, i }
function VC.Lookup(sex, hash, onlyCat)
    local h = u32(hash)
    if not h or h == 0 then return nil end
    if onlyCat then
        for i, item in ipairs(Clothes[sex] and Clothes[sex][onlyCat] or {}) do
            if u32(item.h) == h then return { cat = onlyCat, i = i } end
        end
        return nil
    end
    local idx = byHash[sex]
    if not idx then
        idx = {}
        for cat, list in pairs(Clothes[sex] or {}) do
            for i, item in ipairs(list) do
                local k = u32(item.h)
                if k and not idx[k] then idx[k] = { cat = cat, i = i } end
            end
        end
        byHash[sex] = idx
    end
    return idx[h]
end

function VC.PieceHash(sex, cat, index)
    local list = Clothes[sex] and Clothes[sex][cat]
    local item = list and list[math.floor(tonumber(index) or 0)]
    return item and item.h or nil
end

function VC.PaletteIndex(p)
    p = tonumber(p)
    if not p or p ~= p or p == 0 then return nil end
    if p >= 1 and p <= #Palettes and p % 1 == 0 then return math.floor(p) end
    local want = u32(p)
    for i, h in ipairs(Palettes) do
        if u32(h) == want then return i end
    end
    return nil
end

local function tint(v)
    v = math.floor(tonumber(v) or 0)
    if v < 0 then return 0 end
    if v > TINT_MAX then return TINT_MAX end
    return v
end

--- a vorp key (Hat) or a MULTIcore category (hats) -> MULTIcore category
function VC.CategoryOf(key)
    if type(key) ~= 'string' then return nil end
    if Config.Keys[key] then return Config.Keys[key] end
    if VC.KeyOf[key] then return key end
    return nil
end

--- one MULTIcore piece -> vorp entry { comp, palette?, tint0?, tint1?, tint2? }
function VC.ToVorpEntry(piece, sex, cat)
    if type(piece) ~= 'table' then return nil end
    local h = VC.PieceHash(sex, cat, piece.index)
    if not h then return nil end
    local e = { comp = h }
    local pal = piece.palette and Palettes[math.floor(tonumber(piece.palette) or 0)]
    if pal then
        e.palette = pal
        e.tint0, e.tint1, e.tint2 = tint(piece.tint0), tint(piece.tint1), tint(piece.tint2)
    end
    return e
end

--- MULTIcore comps -> vorp components { [Key] = entry } (only categories that have a vorp key)
function VC.ToVorp(comps, sex)
    local out = {}
    for cat, piece in pairs(type(comps) == 'table' and comps or {}) do
        local key = VC.KeyOf[cat]
        if key then out[key] = VC.ToVorpEntry(piece, sex, cat) end
    end
    return out
end

--- Merges vorp components into MULTIcore comps (a copy). comp -1 / 0 takes that key's piece off.
--- Returns the new comps and a list of keys that could not be placed.
function VC.MergeVorp(comps, entries, sex)
    local out, skipped = {}, {}
    for cat, p in pairs(type(comps) == 'table' and comps or {}) do out[cat] = p end
    for key, v in pairs(type(entries) == 'table' and entries or {}) do
        local cat = VC.CategoryOf(key)
        if type(v) ~= 'table' then v = { comp = v } end
        local hash = tonumber(v.comp or v.hash)
        if not hash or hash == -1 or hash == 0 then
            if cat then out[cat] = nil end
        else
            local e = (cat and VC.Lookup(sex, hash, cat)) or VC.Lookup(sex, hash)
            if e and not VC.SkinCategories[e.cat] then
                if cat and cat ~= e.cat then out[cat] = nil end
                local p = { index = e.i }
                local pal = VC.PaletteIndex(v.palette)
                if pal then p.palette, p.tint0, p.tint1, p.tint2 = pal, tint(v.tint0), tint(v.tint1), tint(v.tint2) end
                out[e.cat] = p
            else
                skipped[#skipped + 1] = tostring(key)
            end
        end
    end
    return out, skipped
end

--- vorp skin keys (vorpcharacter:savenew) -> MULTIcore skin (a copy). Only what has a MULTIcore
--- meaning is used: Hair and Beard (piece hash, -1 = none). Returns the skin and the keys left out.
local SKIN_KEYS = { Hair = { field = 'hair', cat = 'hair' }, Beard = { field = 'beard', cat = 'beards_complete' } }
function VC.MergeSkin(skin, data, sex)
    local out, skipped = {}, {}
    for k, v in pairs(type(skin) == 'table' and skin or {}) do out[k] = v end
    for key, v in pairs(type(data) == 'table' and data or {}) do
        local s = SKIN_KEYS[key]
        local hash = tonumber(type(v) == 'table' and (v.comp or v.hash) or v)
        if s and hash then
            if hash == -1 or hash == 0 then
                out[s.field] = 0
            else
                local e = VC.Lookup(sex, hash, s.cat)
                if e then out[s.field] = e.i else skipped[#skipped + 1] = tostring(key) end
            end
        else
            skipped[#skipped + 1] = tostring(key)
        end
    end
    return out, skipped
end
