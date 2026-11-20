-- ============================================================
-- MULTIinventory :: clothing categories (equipment slots)
--
-- One equipment slot per worn-clothing category. `key` matches the keys
-- this server already stores per character (characters.compPlayer, observed
-- in the owner's database), so migration and the vorp_character mirror are a
-- 1:1 mapping. `game` is the MP ped category name; its hash is joaat(game)
-- (computed at runtime - no hash constants are hard coded here).
--
-- `item` is the generic inventory item that carries a piece of this
-- category (one item per category; the look lives in metadata).
-- `panel` groups slots in the equipment panel (UI). `order` = slot index
-- inside the equipment container (do not renumber after go-live).
--
-- Phase 2: every `game` name was verified against the generated
-- catalogue (tools/build_clothing_catalog.lua): all 35 have multiplayer pieces.
-- ============================================================

ClothingCategories = {
    -- head
    { order = 1,  key = 'Hat',         game = 'hats',               item = 'clothing_hat',         panel = 'head',  label = 'Hat' },
    { order = 2,  key = 'EyeWear',     game = 'eyewear',            item = 'clothing_eyewear',     panel = 'head',  label = 'Eyewear' },
    { order = 3,  key = 'Mask',        game = 'masks',              item = 'clothing_mask',        panel = 'head',  label = 'Mask' },
    { order = 4,  key = 'NeckWear',    game = 'neckwear',           item = 'clothing_neckwear',    panel = 'head',  label = 'Neckwear' },
    { order = 5,  key = 'NeckTies',    game = 'neckties',           item = 'clothing_necktie',     panel = 'head',  label = 'Necktie' },
    { order = 6,  key = 'Bow',         game = 'hair_accessories',   item = 'clothing_hair_accessory', panel = 'head', label = 'Hair accessory' },
    -- torso
    { order = 7,  key = 'Shirt',       game = 'shirts_full',        item = 'clothing_shirt',       panel = 'torso', label = 'Shirt' },
    { order = 8,  key = 'Vest',        game = 'vests',              item = 'clothing_vest',        panel = 'torso', label = 'Vest' },
    { order = 9,  key = 'Coat',        game = 'coats',              item = 'clothing_coat',        panel = 'torso', label = 'Coat (open)' },
    { order = 10, key = 'CoatClosed',  game = 'coats_closed',       item = 'clothing_coat_closed', panel = 'torso', label = 'Coat (closed)' },
    { order = 11, key = 'Poncho',      game = 'ponchos',            item = 'clothing_poncho',      panel = 'torso', label = 'Poncho' },
    { order = 12, key = 'Cloak',       game = 'cloaks',             item = 'clothing_cloak',       panel = 'torso', label = 'Cloak' },
    { order = 13, key = 'Suspender',   game = 'suspenders',         item = 'clothing_suspenders',  panel = 'torso', label = 'Suspenders' },
    { order = 14, key = 'Dress',       game = 'dresses',            item = 'clothing_dress',       panel = 'torso', label = 'Dress' },
    { order = 15, key = 'Armor',       game = 'armor',              item = 'clothing_armor',       panel = 'torso', label = 'Armour' },
    { order = 16, key = 'Badge',       game = 'badges',             item = 'clothing_badge',       panel = 'torso', label = 'Badge' },
    -- hands
    { order = 17, key = 'Glove',       game = 'gloves',             item = 'clothing_gloves',      panel = 'hands', label = 'Gloves' },
    { order = 18, key = 'Gauntlets',   game = 'gauntlets',          item = 'clothing_gauntlets',   panel = 'hands', label = 'Gauntlets' },
    { order = 19, key = 'RingRh',      game = 'jewelry_rings_right',item = 'clothing_ring_right',  panel = 'hands', label = 'Ring (right)' },
    { order = 20, key = 'RingLh',      game = 'jewelry_rings_left', item = 'clothing_ring_left',   panel = 'hands', label = 'Ring (left)' },
    { order = 21, key = 'Bracelet',    game = 'jewelry_bracelets',  item = 'clothing_bracelet',    panel = 'hands', label = 'Bracelet' },
    -- waist
    { order = 22, key = 'Gunbelt',     game = 'gunbelts',           item = 'clothing_gunbelt',     panel = 'waist', label = 'Gunbelt' },
    { order = 23, key = 'Holster',     game = 'holsters_left',      item = 'clothing_holster',     panel = 'waist', label = 'Holster' },
    { order = 24, key = 'GunbeltAccs', game = 'gunbelt_accs',       item = 'clothing_gunbelt_accessory', panel = 'waist', label = 'Gunbelt accessory' },
    { order = 25, key = 'Belt',        game = 'belts',              item = 'clothing_belt',        panel = 'waist', label = 'Belt' },
    { order = 26, key = 'Buckle',      game = 'belt_buckles',       item = 'clothing_buckle',      panel = 'waist', label = 'Buckle' },
    { order = 27, key = 'Satchels',    game = 'satchels',           item = 'clothing_satchel',     panel = 'waist', label = 'Satchel' },
    { order = 28, key = 'Loadouts',    game = 'loadouts',           item = 'clothing_loadout',     panel = 'waist', label = 'Loadout (bandolier)' },
    -- legs / feet
    { order = 29, key = 'Pant',        game = 'pants',              item = 'clothing_pants',       panel = 'legs',  label = 'Trousers' },
    { order = 30, key = 'Skirt',       game = 'skirts',             item = 'clothing_skirt',       panel = 'legs',  label = 'Skirt' },
    { order = 31, key = 'Chap',        game = 'chaps',              item = 'clothing_chaps',       panel = 'legs',  label = 'Chaps' },
    { order = 32, key = 'Boots',       game = 'boots',              item = 'clothing_boots',       panel = 'feet',  label = 'Boots' },
    { order = 33, key = 'Spats',       game = 'spats',              item = 'clothing_spats',       panel = 'feet',  label = 'Spats' },
    { order = 34, key = 'Spurs',       game = 'boot_accessories',   item = 'clothing_spurs',       panel = 'feet',  label = 'Spurs' },
    -- other
    { order = 35, key = 'Accessories', game = 'accessories',        item = 'clothing_accessory',   panel = 'other', label = 'Accessory' },
}

-- Body parts present in compPlayer that are NOT clothing (never items):
-- owned by vorp_character / RINGOcosmetologyjob.
ClothingCategoriesExcluded = { Teeth = true }

-- The outfit bundle item (a set of pieces carried as one item; using it unpacks).
ClothingOutfitItem = 'clothing_outfit'

ClothingCategoriesByKey, ClothingCategoriesByItem, ClothingCategoriesByGame = {}, {}, {}
for _, c in ipairs(ClothingCategories) do
    ClothingCategoriesByKey[c.key] = c
    ClothingCategoriesByItem[c.item] = c
    ClothingCategoriesByGame[c.game] = c
end

-- ============================================================
-- ClothingCat - catalogue access (data: shared/clothing_catalog.lua, generated)
--   ClothingCat.list(key, gender) -> { { comp, label }, ... }   (gender 'male'|'female'|'unisex'|nil = both)
--   ClothingCat.lookup(comp) -> { key, gender, label } | nil     (first match)
--   ClothingCat.has(key, gender, comp) -> bool                  ('unisex'/nil = either gender)
--   ClothingCat.label(comp) -> label|nil                         (config/clothing_labels.lua wins)
--   ClothingCat.count() -> n
-- ClothingCatalog[key][gender] gives the same lists (lazy) - shape promised by the Phase 1 stub.
-- Everything is built lazily on first use (the data file is ~16k numbers + labels).
-- ============================================================
ClothingCat = ClothingCat or {}

local lists, index, sets = {}, nil, {}

local function data() return ClothingCatalogData or {} end
local function overrides() return ClothingLabels or {} end

local function buildIndex()
    if index then return end
    index = {}
    for key, g in pairs(data()) do
        for _, gender in ipairs({ 'male', 'female' }) do
            local flat = g[gender] or {}
            local set = {}
            for i = 1, #flat, 2 do
                local h = flat[i]
                set[h] = true
                if not index[h] then index[h] = { key = key, gender = gender, label = flat[i + 1] } end
            end
            sets[key .. '|' .. gender] = set
        end
    end
end

function ClothingCat.label(comp)
    comp = math.tointeger(tonumber(comp))
    if not comp then return nil end
    local o = overrides()[comp]
    if o then return o end
    buildIndex()
    local e = index[comp]
    return e and e.label or nil
end

function ClothingCat.lookup(comp)
    comp = math.tointeger(tonumber(comp))
    if not comp then return nil end
    buildIndex()
    local e = index[comp]
    if not e then return nil end
    return { key = e.key, gender = e.gender, label = ClothingCat.label(comp) }
end

function ClothingCat.has(key, gender, comp)
    comp = math.tointeger(tonumber(comp))
    if not comp then return false end
    buildIndex()
    if gender == 'male' or gender == 'female' then
        local s = sets[key .. '|' .. gender]
        return s ~= nil and s[comp] == true
    end
    local m, f = sets[key .. '|male'], sets[key .. '|female']
    return (m ~= nil and m[comp] == true) or (f ~= nil and f[comp] == true)
end

function ClothingCat.list(key, gender)
    if not ClothingCategoriesByKey[key] then return {} end
    local genders = (gender == 'male' or gender == 'female') and { gender } or { 'male', 'female' }
    local out = {}
    for _, g in ipairs(genders) do
        local ck = key .. '|' .. g
        local l = lists[ck]
        if not l then
            l = {}
            local flat = (data()[key] or {})[g] or {}
            local ov = overrides()
            for i = 1, #flat, 2 do l[#l + 1] = { comp = flat[i], label = ov[flat[i]] or flat[i + 1], gender = g } end
            lists[ck] = l
        end
        for _, e in ipairs(l) do out[#out + 1] = e end
    end
    return out
end

function ClothingCat.count()
    local n = 0
    for _, g in pairs(data()) do n = n + #(g.male or {}) / 2 + #(g.female or {}) / 2 end
    return math.tointeger(n) or n
end

ClothingCatalog = setmetatable({}, { __index = function(t, key)
    if not ClothingCategoriesByKey[key] then return nil end
    local v = { male = ClothingCat.list(key, 'male'), female = ClothingCat.list(key, 'female') }
    rawset(t, key, v)
    return v
end })
ClothingCatalogIndex = setmetatable({}, { __index = function(_, comp) return ClothingCat.lookup(comp) end })

-- ============================================================
-- ClothingMeta - the clothing metadata contract v1. Shared so the
-- client preview and the server use the same rules; the server is authoritative.
--
--   ClothingMeta.build(spec, opts) -> meta | nil, err
--       opts.trusted  = true : migration / import / admin - comp need not be in the
--                              catalogue, any palette hash allowed
--   ClothingMeta.check(meta, catKey) -> true | false, err    structural check of a stored piece
--   ClothingMeta.signed(n) -> signed 32-bit int (unsigned hashes are converted)
--   ClothingMeta.palettes() -> { [hash] = name }
--   ClothingMeta.normGender(v) -> 'male'|'female'|nil   (VORP 'Male'/'Female', RSG 0/1, ped flags)
-- Errors: bad_spec, bad_cv, bad_category, bad_gender, bad_comp, unknown_comp, wrong_gender,
--         bad_drawable, bad_tint, bad_palette, label_required, label_too_long, description_too_long,
--         bad_image, bad_field
-- ============================================================
ClothingMeta = ClothingMeta or {}

local INT32_MIN, INT32_MAX = -2147483648, 2147483647

local function toInt(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge or v ~= math.floor(v) then return nil end
    return math.tointeger(v)
end

function ClothingMeta.signed(n)
    n = toInt(n)
    if not n then return nil end
    if n > INT32_MAX and n <= 0xFFFFFFFF then n = n - 0x100000000 end
    if n < INT32_MIN or n > INT32_MAX then return nil end
    return n
end

local function hashName(s)
    if Util and Util.joaat then return Util.joaat(s) end
    return joaat(s)
end

local paletteCache
function ClothingMeta.palettes()
    if paletteCache then return paletteCache end
    paletteCache = {}
    local cfg = Config and Config.Clothing or {}
    for _, name in ipairs(cfg.palettes or {}) do paletteCache[hashName(name)] = name end
    for _, h in ipairs(cfg.extraPaletteHashes or {}) do
        local s = ClothingMeta.signed(h)
        if s then paletteCache[s] = paletteCache[s] or ('#' .. s) end
    end
    return paletteCache
end

function ClothingMeta.normGender(v)
    if v == nil then return nil end
    if v == true then return 'male' end
    if v == false then return 'female' end
    local s = tostring(v):lower()
    if s == 'male' or s == 'm' or s == '0' or s == 'mp_male' then return 'male' end
    if s == 'female' or s == 'f' or s == '1' or s == 'mp_female' then return 'female' end
    return nil
end

local function cleanText(s, max)
    if s == nil then return nil end
    if type(s) ~= 'string' and type(s) ~= 'number' then return false end
    s = tostring(s):gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then return nil end
    if #s > max then return false end
    return s
end

-- optional crafted-piece fields: name -> { kind, max }
local OPTIONAL = {
    quality = { 'text', 32 }, quality_label = { 'text', 32 }, maker = { 'text', 50 }, maker_cid = { 'int' },
    made_by = { 'text', 64 }, made_at = { 'int' }, batch = { 'text', 32 }, durability = { 'pct' },
    palette_index = { 'int' }, color_index = { 'int' },
}

local function categoryOf(v)
    if type(v) ~= 'string' then return nil end
    return ClothingCategoriesByKey[v] or ClothingCategoriesByItem[v] or ClothingCategoriesByGame[v]
end

---Validate a spec and build the stored metadata (unknown keys are dropped).
function ClothingMeta.build(spec, opts)
    opts = opts or {}
    if type(spec) ~= 'table' then return nil, 'bad_spec' end
    if spec.cv ~= nil and toInt(spec.cv) ~= 1 then return nil, 'bad_cv' end
    local cat = categoryOf(spec.category)
    if not cat then return nil, 'bad_category' end
    local m = { cv = 1, category = cat.key }

    -- look: route A (shop item hash) or route B (metaped drawable set)
    local hasB = spec.drawable ~= nil or spec.albedo ~= nil or spec.normal ~= nil or spec.material ~= nil
    local entry
    if spec.comp ~= nil then
        local comp = ClothingMeta.signed(spec.comp)
        if not comp or comp == 0 or comp == -1 then return nil, 'bad_comp' end
        m.comp = comp
        entry = ClothingCat.lookup(comp)
        if not opts.trusted then
            local cfg = Config and Config.Clothing or {}
            if cfg.requireCatalogue ~= false and not ClothingCat.has(cat.key, nil, comp) then return nil, 'unknown_comp' end
        end
    elseif hasB then
        for _, k in ipairs({ 'drawable', 'albedo', 'normal', 'material' }) do
            local v = ClothingMeta.signed(spec[k])
            if not v then return nil, 'bad_drawable' end
            m[k] = v
        end
    else
        return nil, 'bad_comp'
    end
    -- story (non-multiplayer) shop items: the game only draws them when applied with isMp = false
    if m.comp and spec.mp == false then m.mp = false end

    -- gender (inferred from the catalogue when the spec has none)
    local g = spec.gender
    if g == nil and entry and entry.key == cat.key then g = entry.gender end
    if g ~= 'unisex' then g = ClothingMeta.normGender(g) end
    if not g then return nil, 'bad_gender' end
    m.gender = g
    if m.comp and not opts.trusted and g ~= 'unisex' and ClothingCat.has(cat.key, nil, m.comp)
        and not ClothingCat.has(cat.key, g, m.comp) then
        return nil, 'wrong_gender'
    end

    -- tints
    local anyTint = spec.palette ~= nil or spec.tint0 ~= nil or spec.tint1 ~= nil or spec.tint2 ~= nil
    if anyTint then
        for _, k in ipairs({ 'tint0', 'tint1', 'tint2' }) do
            local v = spec[k] == nil and 0 or toInt(spec[k])
            if not v or v < 0 or v > 254 then return nil, 'bad_tint' end
            m[k] = v
        end
        if spec.palette ~= nil and spec.palette ~= 0 then
            local p = type(spec.palette) == 'string' and not tonumber(spec.palette) and hashName(spec.palette)
                or ClothingMeta.signed(spec.palette)
            if not p then return nil, 'bad_palette' end
            if not opts.trusted and not ClothingMeta.palettes()[p] then return nil, 'bad_palette' end
            m.palette = p
        end
    end

    -- texts
    local label = cleanText(spec.label, 50)
    if label == false then return nil, 'label_too_long' end
    if not label then
        label = (m.comp and ClothingCat.label(m.comp)) or (opts.defaultLabel)
        if not label then
            if opts.requireLabel then return nil, 'label_required' end
            label = cat.label
        end
    end
    m.label = label
    local desc = cleanText(spec.description, 255)
    if desc == false then return nil, 'description_too_long' end
    m.description = desc
    if spec.image ~= nil then
        if type(spec.image) ~= 'string' or not spec.image:match('^[%w_%-]+%.png$') or #spec.image > 100 then return nil, 'bad_image' end
        m.image = spec.image
    end

    -- crafted-piece fields
    for k, rule in pairs(OPTIONAL) do
        local v = spec[k]
        if v ~= nil then
            if rule[1] == 'text' then
                local t = cleanText(v, rule[2])
                if t == false then return nil, 'bad_field' end
                m[k] = t
            elseif rule[1] == 'int' then
                local n = toInt(v)
                if not n then return nil, 'bad_field' end
                m[k] = n
            elseif rule[1] == 'pct' then
                local n = tonumber(v)
                if not n or n < 0 or n > 100 then return nil, 'bad_field' end
                m[k] = n
            end
        end
    end
    return m
end

---Structural check of a stored piece (used at equip time; catalogue membership is
---checked when the piece is created, so imported pieces with off-catalogue hashes stay wearable).
function ClothingMeta.check(meta, catKey)
    if type(meta) ~= 'table' then return false, 'bad_spec' end
    local built, err = ClothingMeta.build(meta, { trusted = true })
    if not built then return false, err end
    if catKey and built.category ~= catKey then return false, 'bad_category' end
    return true
end

---Gender rule for wearing: piece gender vs ped gender (nil ped gender = unknown -> allowed).
function ClothingMeta.genderOk(pieceGender, pedGender)
    if Config and Config.Clothing and Config.Clothing.allowCrossGender then return true end
    if pieceGender == nil or pieceGender == 'unisex' or pedGender == nil then return true end
    return pieceGender == pedGender
end
