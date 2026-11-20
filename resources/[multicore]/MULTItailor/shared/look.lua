--[[
    TLook - clothing items <-> MULTIcore look (client + server, pure Lua, tested offline).

    MULTIinventory keeps a worn piece as item metadata { category = 'Hat', comp = <shop item hash>,
    palette = <palette hash>?, tint0..2 }, one per equipment slot (key 'Hat', 'Shirt' ...).
    MULTIcore's look keeps comps { [game category] = { index, palette, tint0, tint1, tint2 } } where
    index points into MULTIData.Clothes[sex][category] and palette into MULTIData.Palettes.

    TLook.SLOTS                          { { key, game }, ... } every equipment slot (35)
    TLook.byKey[key] / TLook.byGame[game] -> slot
    TLook.WardrobeNames[name]            -> { key, ... }   rsg-wardrobe clothing names
    TLook.keysFor(name)                  -> { key, ... }   (rsg-wardrobe name, slot key or game category)
    TLook.toComps(worn, sex)             -> comps (only the worn slots), skipped = { key, ... }
    TLook.merge(oldComps, wornComps)     -> comps: everything the inventory does not manage kept, slots replaced
    TLook.fromComps(comps, sex)          -> specs for CreateClothingItem: { { category, comp, gender, palette?, tint0..2 }, ... }
    TLook.same(a, b)                     -> true when both comps tables hold the same clothing
    Data: MULTIData.Clothes / MULTIData.Palettes (@MULTIcore/data/clothes.lua, @MULTIcore/data/appearance.lua).
]]
TLook = TLook or {}
local T = TLook

T.SLOTS = {
    { key = 'Hat', game = 'hats' },               { key = 'EyeWear', game = 'eyewear' },
    { key = 'Mask', game = 'masks' },             { key = 'NeckWear', game = 'neckwear' },
    { key = 'NeckTies', game = 'neckties' },      { key = 'Bow', game = 'hair_accessories' },
    { key = 'Shirt', game = 'shirts_full' },      { key = 'Vest', game = 'vests' },
    { key = 'Coat', game = 'coats' },             { key = 'CoatClosed', game = 'coats_closed' },
    { key = 'Poncho', game = 'ponchos' },         { key = 'Cloak', game = 'cloaks' },
    { key = 'Suspender', game = 'suspenders' },   { key = 'Dress', game = 'dresses' },
    { key = 'Armor', game = 'armor' },            { key = 'Badge', game = 'badges' },
    { key = 'Glove', game = 'gloves' },           { key = 'Gauntlets', game = 'gauntlets' },
    { key = 'RingRh', game = 'jewelry_rings_right' }, { key = 'RingLh', game = 'jewelry_rings_left' },
    { key = 'Bracelet', game = 'jewelry_bracelets' }, { key = 'Gunbelt', game = 'gunbelts' },
    { key = 'Holster', game = 'holsters_left' },  { key = 'GunbeltAccs', game = 'gunbelt_accs' },
    { key = 'Belt', game = 'belts' },             { key = 'Buckle', game = 'belt_buckles' },
    { key = 'Satchels', game = 'satchels' },      { key = 'Loadouts', game = 'loadouts' },
    { key = 'Pant', game = 'pants' },             { key = 'Skirt', game = 'skirts' },
    { key = 'Chap', game = 'chaps' },             { key = 'Boots', game = 'boots' },
    { key = 'Spats', game = 'spats' },            { key = 'Spurs', game = 'boot_accessories' },
    { key = 'Accessories', game = 'accessories' },
}
T.byKey, T.byGame = {}, {}
for _, s in ipairs(T.SLOTS) do T.byKey[s.key] = s; T.byGame[s.game] = s end

-- rsg-wardrobe clothing names (its Config.ClothingComponents 'name') -> equipment slots.
-- Names with no slot of their own (sleeve / collar variants) switch nothing.
T.WardrobeNames = {
    accessories = { 'Accessories' }, armor = { 'Armor' }, belts = { 'Belt' }, boots = { 'Boots' },
    buckles = { 'Buckle' }, chaps = { 'Chap' }, cloaks = { 'Cloak' }, closedcoats = { 'CoatClosed' },
    coats = { 'Coat', 'CoatClosed' }, eyewear = { 'EyeWear' }, gauntlets = { 'Gauntlets' }, glove = { 'Glove' },
    gloves = { 'Glove' }, gunbelts = { 'Gunbelt' }, hair_accessories = { 'Bow' }, hat = { 'Hat' }, hats = { 'Hat' },
    holster_left = { 'Holster' }, holster_right = {}, loadouts = { 'Loadouts' }, masks = { 'Mask' }, mask = { 'Mask' },
    neckties = { 'NeckTies' }, neckwear = { 'NeckWear' }, pants = { 'Pant' }, ponchos = { 'Poncho' },
    satchels = { 'Satchels' }, shirt = { 'Shirt' }, skirts = { 'Skirt' }, suspenders = { 'Suspender' },
    vest = { 'Vest' }, spurs = { 'Spurs' }, spats = { 'Spats' }, badges = { 'Badge' }, dress = { 'Dress' },
    jewelry_rings_left = { 'RingLh' }, jewelry_rings_right = { 'RingRh' }, jewelry_bracelets = { 'Bracelet' },
    sleeve = {}, collar1 = {}, collar2 = {},
}

function T.keysFor(name)
    if type(name) ~= 'string' then return {} end
    local list = T.WardrobeNames[name] or T.WardrobeNames[name:lower()]
    if list then return list end
    if T.byKey[name] then return { name } end
    local s = T.byGame[name:lower()]
    if s then return { s.key } end
    return {}
end

-- ---------------------------------------------------------------- data helpers
local function clothes() return (MULTIData and MULTIData.Clothes) or {} end
local function palettes() return (MULTIData and MULTIData.Palettes) or {} end

local function u32(h)
    h = tonumber(h)
    if not h or h ~= h then return nil end
    return math.floor(h) & 0xFFFFFFFF
end

local function signed(h)
    h = u32(h)
    if not h then return nil end
    if h >= 0x80000000 then h = h - 0x100000000 end
    return h
end

local function tint(v)
    v = math.floor(tonumber(v) or 0)
    if v < 0 then return 0 end
    if v > 254 then return 254 end
    return v
end

-- [sex][game][u32 hash] = index ; [sex].any[u32 hash] = { game, index }
local index = {}
local function indexOf(sex)
    local idx = index[sex]
    if idx then return idx end
    idx = { any = {} }
    for game, list in pairs(clothes()[sex] or {}) do
        local m = {}
        for i, item in ipairs(list) do
            local h = u32(item.h)
            if h then
                if not m[h] then m[h] = i end
                if not idx.any[h] then idx.any[h] = { game = game, i = i } end
            end
        end
        idx[game] = m
    end
    index[sex] = idx
    return idx
end

---index of a piece in MULTIData for this sex: in its own category first, then anywhere (returns game, index)
function T.find(sex, game, hash)
    local h = u32(hash)
    if not h or h == 0 then return nil end
    local idx = indexOf(sex)
    local i = idx[game] and idx[game][h]
    if i then return game, i end
    local a = idx.any[h]
    if a and T.byGame[a.game] then return a.game, a.i end
    return nil
end

function T.hashAt(sex, game, i)
    local list = clothes()[sex] and clothes()[sex][game]
    local item = list and list[math.floor(tonumber(i) or 0)]
    return item and signed(item.h) or nil
end

function T.paletteIndex(p)
    p = tonumber(p)
    if not p or p == 0 then return nil end
    local want = u32(p)
    for i, h in ipairs(palettes()) do
        if u32(h) == want then return i end
    end
    return nil
end

function T.paletteHash(i)
    i = tonumber(i)
    if not i then return nil end
    local h = palettes()[math.floor(i)]
    return h and signed(h) or nil
end

-- ---------------------------------------------------------------- conversions
---worn = { [slot key] = item metadata } (MULTIinventory GetWorn / GetWornLocal)
function T.toComps(worn, sex)
    local comps, skipped = {}, {}
    for key, m in pairs(type(worn) == 'table' and worn or {}) do
        local slot = T.byKey[key]
        local comp = type(m) == 'table' and tonumber(m.comp) or nil
        if slot and comp then
            local game, i = T.find(sex, slot.game, comp)
            if game then
                local piece = { index = i }
                local pal = T.paletteIndex(m.palette)
                if pal then
                    piece.palette, piece.tint0, piece.tint1, piece.tint2 = pal, tint(m.tint0), tint(m.tint1), tint(m.tint2)
                end
                comps[game] = piece
            else
                skipped[#skipped + 1] = key
            end
        elseif slot then
            skipped[#skipped + 1] = key   -- a drawable-set piece (no shop item hash): only the inventory can show it
        end
    end
    table.sort(skipped)
    return comps, skipped
end

---Keep every category the inventory does not manage (hair, body pieces, anything unknown); the
---equipment slots' categories come from wornComps only.
function T.merge(oldComps, wornComps)
    local out = {}
    for game, piece in pairs(type(oldComps) == 'table' and oldComps or {}) do
        if not T.byGame[game] then out[game] = piece end
    end
    for game, piece in pairs(type(wornComps) == 'table' and wornComps or {}) do out[game] = piece end
    return out
end

---MULTIcore comps -> clothing item specs (only the equipment slots' categories)
function T.fromComps(comps, sex)
    local specs = {}
    for _, slot in ipairs(T.SLOTS) do
        local p = type(comps) == 'table' and comps[slot.game] or nil
        local hash = type(p) == 'table' and T.hashAt(sex, slot.game, p.index) or nil
        if hash and hash ~= 0 then
            local spec = { category = slot.key, comp = hash, gender = sex }
            local pal = p.palette and T.paletteHash(p.palette)
            if pal then
                spec.palette, spec.tint0, spec.tint1, spec.tint2 = pal, tint(p.tint0), tint(p.tint1), tint(p.tint2)
            end
            specs[#specs + 1] = spec
        end
    end
    return specs
end

local function sameColour(p, q)
    local a, b = tonumber(p.palette), tonumber(q.palette)
    if a ~= b then return false end
    if not a then return true end
    return tint(p.tint0) == tint(q.tint0) and tint(p.tint1) == tint(q.tint1) and tint(p.tint2) == tint(q.tint2)
end

function T.same(a, b)
    a, b = type(a) == 'table' and a or {}, type(b) == 'table' and b or {}
    for k, p in pairs(a) do
        local q = b[k]
        if type(p) ~= 'table' or type(q) ~= 'table' then return false end
        if tonumber(p.index) ~= tonumber(q.index) or not sameColour(p, q) then return false end
    end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
