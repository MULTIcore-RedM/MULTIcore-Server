-- ============================================================
-- MULTIappearance :: shape translation (client and server)
-- rsg-appearance keeps clothes as { [category] = { hash = n, palette = hash,
-- tint0, tint1, tint2 } } (or { model, texture } before conversion).
-- MULTIcore keeps { [category] = { index = n, palette = index, tint0.. } }
-- where index points into MULTIData.Clothes[sex][category].
-- RSG's category names are the game's own (hats, shirts_full ...), the
-- same names MULTIData uses, so a piece's hash is looked up across all
-- categories and lands in the category the game data says it belongs to.
-- ============================================================

local Clothes = (MULTIData and MULTIData.Clothes) or {}
local Palettes = (MULTIData and MULTIData.Palettes) or {}

-- categories that are part of the skin (face / body), never clothing
MA.SkinCategories = {
    heads = true, bodies_upper = true, bodies_lower = true, eyes = true, teeth = true,
    hair = true, beards_complete = true,
}

local TINT_MAX = 254 -- highest tint the MULTIcore look format accepts

local function u32(h)
    h = tonumber(h)
    if not h or h ~= h then return nil end
    return math.floor(h) & 0xFFFFFFFF
end
MA.U32 = u32

local function callable(f)
    if type(f) == 'function' then return true end
    local mt = type(f) == 'table' and getmetatable(f)
    return mt and mt.__call ~= nil or false
end
MA.Callable = callable

-- [sex][u32 hash] = { cat = category, i = index } (built on first use, first index wins)
local byHash = {}

local function hashIndex(sex)
    local idx = byHash[sex]
    if idx then return idx end
    idx = {}
    for cat, list in pairs(Clothes[sex] or {}) do
        for i, item in ipairs(list) do
            local h = u32(item.h)
            if h and not idx[h] then idx[h] = { cat = cat, i = i } end
        end
    end
    byHash[sex] = idx
    return idx
end

function MA.Lookup(sex, hash)
    local h = u32(hash)
    if not h or h == 0 then return nil end
    return hashIndex(sex)[h]
end

function MA.PieceHash(sex, cat, index)
    local list = Clothes[sex] and Clothes[sex][cat]
    local item = list and list[math.floor(tonumber(index) or 0)]
    return item and item.h or nil
end

function MA.Count(sex, cat)
    local list = Clothes[sex] and Clothes[sex][cat]
    return list and #list or 0
end

--- palette as an index into MULTIData.Palettes; accepts an index or a palette hash
function MA.PaletteIndex(p)
    p = tonumber(p)
    if not p or p ~= p then return nil end
    if p >= 1 and p <= #Palettes and p % 1 == 0 then return math.floor(p) end
    local want = u32(p)
    for i, h in ipairs(Palettes) do
        if u32(h) == want then return i end
    end
    return nil
end

function MA.PaletteHash(i)
    i = tonumber(i)
    if not i then return nil end
    return Palettes[math.floor(i)]
end

local function tint(v)
    v = math.floor(tonumber(v) or 0)
    if v < 0 then return 0 end
    if v > TINT_MAX then return TINT_MAX end
    return v
end

--- sex from a MULTIcore skin, an RSG skin (sex 1 = male, 2 = female) or a fallback
function MA.SexOf(skin, fallback)
    if type(skin) == 'table' then
        if skin.sex == 'male' or skin.sex == 'female' then return skin.sex end
        local n = tonumber(skin.sex)
        if n == 1 then return 'male' end
        if n == 2 then return 'female' end
    end
    return fallback == 'female' and 'female' or 'male'
end

--- true when a skin table is already in MULTIcore's own format
function MA.IsMultiSkin(skin)
    return type(skin) == 'table' and (skin.sex == 'male' or skin.sex == 'female') and tonumber(skin.head) ~= nil
end

--- MULTIcore comps -> RSG clothes cache { [category] = { hash, palette, tint0, tint1, tint2 } }
function MA.ToRsgClothes(comps, sex)
    local out = {}
    if type(comps) ~= 'table' then return out end
    for cat, piece in pairs(comps) do
        if type(piece) == 'table' and not MA.SkinCategories[cat] then
            local h = MA.PieceHash(sex, cat, piece.index)
            if h then
                local e = { hash = h }
                local pal = piece.palette and MA.PaletteHash(piece.palette)
                if pal then
                    e.palette = pal
                    e.tint0, e.tint1, e.tint2 = tint(piece.tint0), tint(piece.tint1), tint(piece.tint2)
                end
                out[cat] = e
            end
        end
    end
    return out
end

--- RSG clothes (or MULTIcore comps) -> MULTIcore comps. Returns comps and a list of keys that had no mapping.
function MA.FromRsgClothes(clothes, sex)
    local comps, skipped = {}, {}
    if type(clothes) ~= 'table' then return comps, skipped end
    for key, v in pairs(clothes) do
        if type(v) == 'number' then v = { hash = v } end
        local done = false
        if type(v) == 'table' then
            if tonumber(v.index) and type(key) == 'string' and not MA.SkinCategories[key]
                and MA.PieceHash(sex, key, v.index) then
                -- already MULTIcore format
                local p = { index = math.floor(tonumber(v.index)) }
                local pal = MA.PaletteIndex(v.palette)
                if pal then p.palette, p.tint0, p.tint1, p.tint2 = pal, tint(v.tint0), tint(v.tint1), tint(v.tint2) end
                comps[key] = p
                done = true
            elseif v.hash and tonumber(v.hash) and tonumber(v.hash) ~= 0 then
                local e = MA.Lookup(sex, v.hash)
                if e and not MA.SkinCategories[e.cat] then
                    local p = { index = e.i }
                    local pal = MA.PaletteIndex(v.palette)
                    if pal then p.palette, p.tint0, p.tint1, p.tint2 = pal, tint(v.tint0), tint(v.tint1), tint(v.tint2) end
                    comps[e.cat] = p
                    done = true
                end
            end
        end
        -- hash 0 / model 0 means "nothing in this category": not a gap
        if not done and type(v) == 'table' and (tonumber(v.hash) == 0 or tonumber(v.model) == 0) then done = true end
        if not done and v ~= 0 and v ~= false then skipped[#skipped + 1] = tostring(key) end
    end
    return comps, skipped
end

--- same clothing? (compares by piece hash, palette and tints)
function MA.SameComps(sex, a, b)
    a, b = a or {}, b or {}
    local function check(x, y)
        for cat, p in pairs(x) do
            if not MA.SkinCategories[cat] then
                local q = y[cat]
                if type(p) ~= 'table' or type(q) ~= 'table' then return false end
                if MA.PieceHash(sex, cat, p.index) ~= MA.PieceHash(sex, cat, q.index) then return false end
                if MA.PaletteIndex(p.palette) ~= MA.PaletteIndex(q.palette) then return false end
                if p.palette and (tint(p.tint0) ~= tint(q.tint0) or tint(p.tint1) ~= tint(q.tint1) or tint(p.tint2) ~= tint(q.tint2)) then
                    return false
                end
            end
        end
        return true
    end
    return check(a, b) and check(b, a)
end
