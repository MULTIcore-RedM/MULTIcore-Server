-- ============================================================
-- MULTIcreator :: menu data
-- Groups MULTIcore's clothes data into what the creator shows.
--
-- Skin tone vs head shape: heads are named CLOTHING_ITEM_<M|F>_HEAD_<shape>_V_<tone>.
-- Every shape comes in tones V_001 .. V_006, and the bodies follow the same rule
-- (BODIES_UPPER_<build>_V_<tone>, BODIES_LOWER_<build>_V_<tone>). So the creator
-- offers "skin tone" (1..6) and "head" (the shape); the look stores the matching
-- head / bodyUpper / bodyLower indexes. Entries without a name in the data
-- (a few at the start of the heads, bodies and eyes lists) are NOT offered: they
-- draw white eyes and odd heads (rsg-appearance skips them too, GPL v3).
-- Skin tones are shown light to dark in MULTIData.ToneOrder (rsg-appearance order).
-- Hair and beards are named <STYLE>_<COLOUR> (17 colours per style): the menu
-- shows a style stepper and colour swatches; unnamed hair pieces come last.
-- ============================================================

CreatorData = {}

local cache

local function nameOf(item) return item and item.n or nil end

-- pieces named <prefix>_<number>_V_<tone> -> { {name, tones = {idx1..idx6}} } (unnamed pieces left out)
local function groupTones(list, word)
    local groups, byName = {}, {}
    for i, item in ipairs(list or {}) do
        local n = nameOf(item)
        local num, tone
        if n then num, tone = n:match('_' .. word .. '_(%d+)_V_(%d+)$') end
        if num then
            local g = byName[num]
            if not g then
                g = { name = num, tones = {} }
                byName[num] = g
                groups[#groups + 1] = g
            end
            g.tones[tonumber(tone)] = i
        end
    end
    -- dense arrays for JSON (0 = this tone does not exist for that shape)
    local maxTone = 0
    for _, g in ipairs(groups) do
        for t in pairs(g.tones) do if t > maxTone then maxTone = t end end
    end
    for _, g in ipairs(groups) do
        local dense = {}
        for t = 1, maxTone do dense[t] = g.tones[t] or 0 end
        g.tones = dense
    end
    return { groups = groups, extras = {}, tones = maxTone }
end

-- pieces named <prefix>_<number>_<COLOUR> -> { {name, items = {{i, c}}} }
local function groupColours(list, word)
    local groups, byName, unnamed = {}, {}, {}
    for i, item in ipairs(list or {}) do
        local n = nameOf(item)
        local num, colour
        if n then num, colour = n:match('_' .. word .. '_(%d+)_([%u_]+)$') end
        if num then
            local g = byName[num]
            if not g then
                g = { name = num, items = {} }
                byName[num] = g
                groups[#groups + 1] = g
            end
            g.items[#g.items + 1] = { i = i, c = colour }
        else
            unnamed[#unnamed + 1] = { name = 'x' .. i, items = { { i = i, c = '' } } }
        end
    end
    -- named styles first (style 1 is a real haircut), the unnamed game pieces after them
    for _, g in ipairs(unnamed) do groups[#groups + 1] = g end
    return groups
end

-- indexes of the named pieces of a list (eyes, teeth)
local function namedIndexes(list)
    local out = {}
    for i, item in ipairs(list or {}) do
        if nameOf(item) then out[#out + 1] = i end
    end
    return out
end

local function forSex(sex)
    local C = MULTIData.Clothes[sex] or {}
    local out = {
        heads = groupTones(C.heads, 'HEAD'),
        bodiesUpper = groupTones(C.bodies_upper, 'BODIES_UPPER'),
        bodiesLower = groupTones(C.bodies_lower, 'BODIES_LOWER'),
        eyes = namedIndexes(C.eyes),
        teeth = namedIndexes(C.teeth),
        hair = groupColours(C.hair, 'HAIR'),
        beards = C.beards_complete and groupColours(C.beards_complete, 'BEARD') or {},
        clothes = {},
    }
    for _, c in ipairs(Config.CreatorClothing) do
        local list = C[c.key]
        if list and #list > 0 then
            out.clothes[#out.clothes + 1] = { key = c.key, tint = c.tint and true or false, count = #list }
        end
    end
    return out
end

--- Everything the page needs, built once.
function CreatorData.Get()
    if cache then return cache end
    local overlays = {}
    for _, name in ipairs(Config.Overlays) do
        local list = MULTIData.Overlays[name]
        if list then
            overlays[#overlays + 1] = {
                name = name,
                count = #list,
                variants = Config.OverlayVariants[name] or 1,
            }
        end
    end
    local body = {}
    for _, f in ipairs(MULTIData.BodyFeatures or {}) do
        body[#body + 1] = { key = tostring(f.id), name = f.name, female = f.female and true or false }
    end
    local features = {}
    for _, f in ipairs(MULTIData.FaceFeatures) do
        features[#features + 1] = { key = ('0x%04X'):format(f.id), name = f.name }
    end
    cache = {
        male = forSex('male'),
        female = forSex('female'),
        overlays = overlays,
        features = features,
        body = body,
        bodySizes = #(MULTIData.BodySizes or {}),
        waists = #(MULTIData.Waists or {}),
        toneOrder = MULTIData.ToneOrder or {},
        palettes = #MULTIData.Palettes,
    }
    return cache
end
