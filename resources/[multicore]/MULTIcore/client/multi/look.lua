-- ============================================================
-- MULTIcore :: look apply library (client)
-- Puts a 'multi' format look (docs/BASE_SET.md) on an mp_male /
-- mp_female ped: body pieces, build, face and body sliders, overlays
-- (texture layers), hair, beard and clothing with tints.
--
-- The drawing method is ported from RSG v2's rsg-appearance
-- (client/functions.lua, client/creator.lua, client/clothes.lua),
-- GPL v3, see CREDITS.md:
--   * a fresh mp ped gets the base outfit preset 7, then every clothing
--     tag the preset wears is taken off (REMOVE_TAG_FROM_META_PED) and the
--     body, head, eyes and teeth go on (FixIssues / LoadModel)
--   * head, upper and lower body always share one skin tone (LoadBoody)
--   * every piece is applied with _APPLY_SHOP_ITEM_TO_PED (immediately
--     false, mp true) followed by RSG's full variation update and a wait
--     until the ped is ready to render (NativeUpdatePedVariation)
--   * build and waist are meta ped outfits (LoadBodyFeature)
--   * face overlays are drawn on the WORN head's own albedo / normal /
--     material (read with GET_META_PED_ASSET_GUIDS), with the overlay id,
--     no normal / material, RSG's colour type per overlay and its layer
--     order (ApplyOverlays / overlay_all_layers)
--   * clothing: _REFRESH_META_PED_SHOP_ITEMS before each piece, tints
--     with _SET_TEXTURE_OUTFIT_TINTS, and the body piece put back under
--     any body part no clothing covers (ApplyClothes / BODY_CATEGORY_MAP)
-- Body proportions follow VORP's idea of body sliders, done with
-- _SET_CHAR_EXPRESSION and femga's MetaPedExpression ids
-- (MULTIData.BodyFeatures); expressions are always set last.
-- Natives checked against femga's natives.json.
-- ============================================================

local InvokeNative = Citizen.InvokeNative
local AsInt = Citizen.ResultAsInteger

-- natives (hashes from femga natives.json)
local N = {
    APPLY_SHOP_ITEM          = 0xD3A7B003ED343FD9, -- _APPLY_SHOP_ITEM_TO_PED (ped, hash, immediately, isMp, p4)
    REMOVE_TAG               = 0xD710A5007C2AC539, -- REMOVE_TAG_FROM_META_PED (ped, category, p2)
    REFRESH_SHOP_ITEMS       = 0x59BD177A1A48600A, -- _REFRESH_META_PED_SHOP_ITEMS (ped, category)
    SHOP_ITEM_CATEGORY       = 0x5FF9A878C3D115B8, -- _GET_SHOP_ITEM_COMPONENT_CATEGORY (hash, metapedType, isMp)
    UPDATE_VARIATION         = 0xCC8CA3E88256E58F, -- _UPDATE_PED_VARIATION (ped, p1..p5)
    VARIATION_CLEAR          = 0x704C908E9C405136, -- _0x704C908E9C405136 (ped) "_CLEAR*", paired with the update
    COMPONENTS_UPDATED       = 0xAAB86462966168CE, -- _SET_ACTIVE_META_PED_COMPONENTS_UPDATED (ped, true)
    READY_TO_RENDER          = 0xA0BC8FAED8CFEB3C, -- IS_PED_READY_TO_RENDER (ped)
    EQUIP_OUTFIT             = 0x1902C4CFCC5BE57C, -- _EQUIP_META_PED_OUTFIT (ped, hash)
    OUTFIT_PRESET            = 0x77FF8D35EEC6BBC4, -- _EQUIP_META_PED_OUTFIT_PRESET (ped, presetId, p2)
    CHAR_EXPRESSION          = 0x5653AB26C82938CF, -- _SET_CHAR_EXPRESSION (ped, index, value)
    PED_SCALE                = 0x25ACFC650B65C538, -- _SET_PED_SCALE (ped, scale)
    NUM_COMPONENTS           = 0x90403E8107B60E81, -- _GET_NUM_COMPONENTS_IN_PED (ped)
    CATEGORY_AT_INDEX        = 0x9B90842304C938A7, -- _GET_CATEGORY_OF_COMPONENT_AT_INDEX (ped, index, p2)
    META_PED_ASSET_GUIDS     = 0xA9C28516A6DC9D56, -- GET_META_PED_ASSET_GUIDS (ped, index, *drawable, *albedo, *normal, *material)
    REQUEST_TEXTURE          = 0xC5E7204F322E49EB, -- _REQUEST_TEXTURE (albedo, normal, material) -> textureId
    ADD_TEXTURE_LAYER        = 0x86BB5FF45F193A02, -- _ADD_TEXTURE_LAYER (tex, albedo, normal, material, blendType, alpha, sheetGrid) -> layer
    LAYER_PALETTE            = 0x1ED8588524AC9BE1, -- _SET_TEXTURE_LAYER_PALLETE (tex, layer, palette)
    LAYER_TINT               = 0x2DF59FFE6FFD6044, -- _SET_TEXTURE_LAYER_TINT (tex, layer, t0, t1, t2)
    LAYER_SHEET_GRID         = 0x3329AAE2882FC8E4, -- _SET_TEXTURE_LAYER_SHEET_GRID_INDEX (tex, layer, index)
    LAYER_ALPHA              = 0x6C76BC24F8BB709A, -- _SET_TEXTURE_LAYER_ALPHA (tex, layer, alpha)
    TEXTURE_VALID            = 0x31DC8D3F216D8509, -- _IS_TEXTURE_VALID (tex)
    APPLY_TEXTURE            = 0x0B46E25761519058, -- _APPLY_TEXTURE_ON_PED (ped, component, tex)
    UPDATE_TEXTURE           = 0x92DAABA2C1C10B0E, -- _UPDATE_PED_TEXTURE (tex)
    RESET_TEXTURE            = 0x8472A1789478F82F, -- _RESET_PED_TEXTURE (tex)
    CLEAR_TEXTURE            = 0xB63B9178D0F58D82, -- _CLEAR_PED_TEXTURE (tex)
    RELEASE_TEXTURE          = 0x6BEFAA907B076859, -- _RELEASE_TEXTURE (tex)
    OUTFIT_TINTS             = 0x4EFC1F8FF1AD94DE, -- _SET_TEXTURE_OUTFIT_TINTS (ped, category, palette, t0, t1, t2)
}

-- timings: MULTIConfig.Look may override any of these (owner settings live in MULTIcore's config_multi.lua)
local LC = (MULTIConfig and MULTIConfig.Look) or {}
local T = {
    readyMs = LC.ReadyTimeoutMs or 3000,         -- longest wait for pieces to stream in
    compReadyMs = LC.CompReadyTimeoutMs or 2000, -- same, after one clothing piece
    textureMs = LC.TextureTimeoutMs or 3000,     -- longest wait for an overlay texture
    modelMs = LC.ModelTimeoutMs or 10000,        -- longest wait for mp_male / mp_female to load
    respawnMs = LC.RespawnDelayMs or 1500,       -- wait after a respawn / revive before checking the look
    cleanupMs = LC.TextureCleanupMs or 10000,    -- how often textures of deleted peds are given back
}

local MODELS = { male = `mp_male`, female = `mp_female` }
local BASE_PRESET = 7 -- base outfit preset every mp ped is drawn from (rsg-appearance LoadModel / FixIssues)

-- categories that belong to the skin, not to clothing
local SKIN_CATEGORIES = {
    heads = true, bodies_upper = true, bodies_lower = true, eyes = true, teeth = true,
    hair = true, beards_complete = true,
}
-- skin categories where only named game pieces are real choices (the unnamed ones at the start of the
-- lists draw white eyes, odd heads and bodies; rsg-appearance skips them too: hashname ~= "")
local NAMED_ONLY = { heads = true, bodies_upper = true, bodies_lower = true, eyes = true, teeth = true }

-- clothing category -> body pieces it covers (rsg-appearance client/clothes.lua BODY_CATEGORY_MAP;
-- dresses added here: they cover both)
local UP, LOW = { 'bodies_upper' }, { 'bodies_lower' }
local BODY_PART_OF = {
    shirts_full = UP, coats = UP, coats_closed = UP, vests = UP, ponchos = UP, cloaks = UP, suspenders = UP,
    loadouts = UP, armor = UP,
    pants = LOW, chaps = LOW, skirts = LOW, boots = LOW, spats = LOW, boot_accessories = LOW,
    dresses = { 'bodies_upper', 'bodies_lower' },
}

-- overlay layer order, bottom first: rsg-appearance overlay_all_layers order, then the overlays RSG
-- leaves out (UNVERIFIED in game: acne, complex, disc, grime, foundation, hair, paintedmasks)
local OVERLAY_ORDER = {
    'eyebrows', 'scars', 'eyeliners', 'lipsticks', 'shadows', 'beardstabble', 'ageing', 'blush',
    'freckles', 'moles', 'spots',
    'acne', 'complex', 'disc', 'grime', 'foundation', 'hair', 'paintedmasks',
}
-- colour type per overlay (0 = coloured with palette + tints, 1 = keeps the texture's own colour), as
-- rsg-appearance LoadOverlays sets them; the RSG-less ones follow the same rule (marks 1, make-up 0)
local COLOR_TYPE = {
    eyebrows = 0, eyeliners = 0, lipsticks = 0, shadows = 0, blush = 0, beardstabble = 0,
    scars = 1, ageing = 1, freckles = 1, moles = 1, spots = 1,
    acne = 1, complex = 1, disc = 1, grime = 1, foundation = 0, hair = 0, paintedmasks = 0,
}

local state = {
    look = nil,        -- logged-in character's look (cached copy)
    peds = {},         -- [ped] = { skin = table, tex = textureId, init = bool }
    lastPed = nil,
}

-- ---------------------------------------------------------------
-- helpers
-- ---------------------------------------------------------------

local function u32(h)
    h = tonumber(h) or 0
    return h & 0xFFFFFFFF
end

local function sexOf(ped, skin)
    if skin and (skin.sex == 'female' or skin.sex == 'male') then return skin.sex end
    local rec = state.peds[ped]
    if rec and rec.skin and rec.skin.sex then return rec.skin.sex end
    return IsPedMale(ped) and 'male' or 'female'
end

local function record(ped)
    local r = state.peds[ped]
    if not r then
        r = {}
        state.peds[ped] = r
    end
    return r
end

local function clamp(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function listOf(sex, category)
    return MULTIData.Clothes[sex] and MULTIData.Clothes[sex][category]
end

-- per sex and category: first named index and name -> index (built once)
local catInfo = {}
local function infoOf(sex, category)
    local key = sex .. '/' .. category
    local info = catInfo[key]
    if info then return info end
    info = { first = nil, byName = {} }
    for i, item in ipairs(listOf(sex, category) or {}) do
        if item.n then
            info.byName[item.n] = i
            if not info.first then info.first = i end
        end
    end
    catInfo[key] = info
    return info
end

--- index of a skin piece, with unnamed entries replaced by the first named piece (older looks may point at them)
local function skinIndex(sex, category, index)
    local list = listOf(sex, category)
    if not list then return nil end
    index = math.floor(tonumber(index) or 1)
    local item = list[index]
    if NAMED_ONLY[category] and not (item and item.n) then return infoOf(sex, category).first end
    if not item then return infoOf(sex, category).first end
    return index
end

local function toneOf(sex, category, index)
    local list = listOf(sex, category)
    local item = list and list[index]
    return item and item.n and item.n:match('_V_(%d+)$') or nil
end

--- same piece in another skin tone (CLOTHING_ITEM_M_BODIES_UPPER_001_V_003 -> ..._V_<tone>), else unchanged
local function inTone(sex, category, index, tone)
    if not (index and tone) then return index end
    local list = listOf(sex, category)
    local item = list and list[index]
    if not (item and item.n) then return index end
    local want = item.n:gsub('_V_%d+$', '_V_' .. tone)
    return infoOf(sex, category).byName[want] or index
end

local function pieceHash(sex, category, index)
    local list = listOf(sex, category)
    local item = list and list[tonumber(index) or 0]
    return item and item.h or nil
end

local function waitReady(ped, ms)
    local untilTime = GetGameTimer() + (ms or T.readyMs)
    while DoesEntityExist(ped) and not InvokeNative(N.READY_TO_RENDER, ped) and GetGameTimer() < untilTime do
        Wait(0)
    end
end

-- rsg-appearance NativeUpdatePedVariation (with a time limit on the wait)
local function updateVariation(ped, waitMs)
    InvokeNative(N.VARIATION_CLEAR, ped)
    InvokeNative(N.UPDATE_VARIATION, ped, false, true, true, true, false)
    InvokeNative(N.COMPONENTS_UPDATED, ped, true)
    if waitMs ~= false then waitReady(ped, waitMs) end
end

-- rsg-appearance NativeSetPedComponentEnabled: apply, then update
local function applyItem(ped, hash, waitMs)
    InvokeNative(N.APPLY_SHOP_ITEM, ped, hash, false, true, true)
    updateVariation(ped, waitMs)
end

local function removeTag(ped, category)
    InvokeNative(N.REMOVE_TAG, ped, type(category) == 'string' and joaat(category) or category, 0)
end

local function paletteHash(p)
    p = tonumber(p)
    if not p then return nil end
    if p >= 1 and p <= #MULTIData.Palettes and p % 1 == 0 then return MULTIData.Palettes[p] end
    return p -- a raw palette hash
end

-- ---------------------------------------------------------------
-- body pieces
-- ---------------------------------------------------------------

--- the head, upper and lower body indexes of a skin, with one skin tone (the head's) for all three
local function bodyIndexes(sex, skin)
    local head = skinIndex(sex, 'heads', skin.head or 1)
    local tone = toneOf(sex, 'heads', head)
    local up = inTone(sex, 'bodies_upper', skinIndex(sex, 'bodies_upper', skin.bodyUpper or 1), tone)
    local low = inTone(sex, 'bodies_lower', skinIndex(sex, 'bodies_lower', skin.bodyLower or 1), tone)
    return head, up, low
end

local function applyBodyPart(ped, sex, skin, part)
    local _, up, low = bodyIndexes(sex, skin or {})
    local h = pieceHash(sex, part, part == 'bodies_upper' and up or low)
    if h then applyItem(ped, h, T.compReadyMs) end
end

--- a fresh mp ped: base preset, every clothing tag off, plain body / head / eyes / teeth on
--- (rsg-appearance FixIssues)
local function prepare(ped, sex)
    InvokeNative(N.OUTFIT_PRESET, ped, BASE_PRESET, false)
    updateVariation(ped)
    for category in pairs(MULTIData.Clothes[sex] or {}) do
        if not SKIN_CATEGORIES[category] then removeTag(ped, category) end
    end
    for _, category in ipairs(MULTIData.ExtraClothingTags or {}) do removeTag(ped, category) end
    for _, category in ipairs({ 'bodies_upper', 'bodies_lower', 'heads', 'eyes', 'teeth' }) do
        local h = pieceHash(sex, category, infoOf(sex, category).first)
        if h then InvokeNative(N.APPLY_SHOP_ITEM, ped, h, false, true, true) end
    end
    updateVariation(ped)
    record(ped).init = true
end

local function applyBodyShape(ped, skin)
    local sizes = MULTIData.BodySizes
    local bt = math.floor(tonumber(skin.bodyType) or 0)
    if bt < 1 then bt = MULTIData.BodySizeDefault end
    if bt > #sizes then bt = #sizes end
    InvokeNative(N.EQUIP_OUTFIT, ped, sizes[bt])
    updateVariation(ped, false)
    local w = math.floor(tonumber(skin.waist) or 0)
    InvokeNative(N.EQUIP_OUTFIT, ped, MULTIData.Waists[w] or MULTIData.WaistDefault)
    updateVariation(ped)
end

--- Face sliders, body sliders and height. Every known slider is set (missing = 0.0), so old values never stick.
--- Called last whenever pieces or outfits change, because equipping them can reset expressions.
local function ApplyFeatures(ped, skin)
    if not DoesEntityExist(ped) or type(skin) ~= 'table' then return false end
    local sex = sexOf(ped, skin)
    local function given(t)
        local out = {}
        if type(t) == 'table' then
            for k, v in pairs(t) do
                local id = tonumber(k)
                if id then out[id] = clamp(v, -1.0, 1.0, 0.0) end
            end
        end
        return out
    end
    local face, body = given(skin.features), given(skin.body)
    for _, f in ipairs(MULTIData.FaceFeatures) do
        InvokeNative(N.CHAR_EXPRESSION, ped, f.id, (face[f.id] or 0.0) + 0.0)
    end
    for _, f in ipairs(MULTIData.BodyFeatures or {}) do
        if sex == 'female' or not f.female then
            InvokeNative(N.CHAR_EXPRESSION, ped, f.id, (body[f.id] or 0.0) + 0.0)
        end
    end
    local lo = LC.MinHeight or 0.9
    local hi = LC.MaxHeight or 1.1
    InvokeNative(N.PED_SCALE, ped, clamp(skin.height, lo, hi, 1.0) + 0.0)
    updateVariation(ped, false)
    -- kept so clothing changes can set the latest sliders again
    record(ped).sliders = { sex = skin.sex, features = skin.features, body = skin.body, height = skin.height }
    return true
end

-- ---------------------------------------------------------------
-- overlays (texture layers on the head) - rsg-appearance ApplyOverlays
-- ---------------------------------------------------------------

local function releaseTexture(tex)
    if tex and tex ~= -1 then
        InvokeNative(N.CLEAR_TEXTURE, tex)
        InvokeNative(N.RELEASE_TEXTURE, tex)
    end
end

--- albedo, normal, material of the head the ped wears (rsg-appearance GetHeadIndex + GetMetaPedAssetGuids)
local function headTexture(ped, sex)
    local count = InvokeNative(N.NUM_COMPONENTS, ped, AsInt()) or 0
    for i = 0, count - 1 do
        if u32(InvokeNative(N.CATEGORY_AT_INDEX, ped, i, 0, AsInt())) == u32(`heads`) then
            local _, albedo, normal, material = InvokeNative(N.META_PED_ASSET_GUIDS, ped, i,
                Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
            if albedo and albedo ~= 0 then return albedo, normal, material end
        end
    end
    local base = MULTIData.HeadTexture[sex]
    return joaat(base.albedo), joaat(base.normal), base.material
end

local function ApplyOverlays(ped, skin)
    if not DoesEntityExist(ped) or type(skin) ~= 'table' then return false end
    local sex = sexOf(ped, skin)
    local rec = record(ped)
    local overlays = type(skin.overlays) == 'table' and skin.overlays or {}

    local layers = {}
    for _, name in ipairs(OVERLAY_ORDER) do
        local o = overlays[name]
        local list = MULTIData.Overlays[name]
        if type(o) == 'table' and list then
            local e = list[math.floor(tonumber(o.tx) or 1)] or list[1]
            local alpha = clamp(o.opacity, 0.0, 1.0, 1.0)
            if e and alpha > 0.0 then layers[#layers + 1] = { name = name, o = o, e = e, alpha = alpha } end
        end
    end

    -- only the newest call for this ped may finish (several scripts can ask at once)
    local token = (rec.ovToken or 0) + 1
    rec.ovToken = token

    -- the old texture goes first, so the head shows its own texture again before it is read
    if rec.tex then
        releaseTexture(rec.tex)
        rec.tex = nil
        local head = pieceHash(sex, 'heads', (bodyIndexes(sex, skin)))
        if head then
            applyItem(ped, head)
            local readyBy = GetGameTimer() + 1000 -- let the head swap finish before its texture is read
            while not InvokeNative(N.READY_TO_RENDER, ped) and GetGameTimer() < readyBy do Wait(0) end
        end
    end
    if #layers == 0 then return true end
    if rec.ovToken ~= token then return false end

    local albedo, normal, material = headTexture(ped, sex)
    local tex = InvokeNative(N.REQUEST_TEXTURE, albedo, normal, material, AsInt())
    if not tex or tex == -1 then return false end

    for _, l in ipairs(layers) do
        local o, e = l.o, l.e
        local colorType = COLOR_TYPE[l.name] or 0
        local layer = InvokeNative(N.ADD_TEXTURE_LAYER, tex, e.id, 0, 0, colorType, 1.0, 0, AsInt())
        if colorType == 0 then
            local pal = paletteHash(o.palette or 1)
            if pal then InvokeNative(N.LAYER_PALETTE, tex, layer, pal) end
            InvokeNative(N.LAYER_TINT, tex, layer, math.floor(tonumber(o.c1) or 0), math.floor(tonumber(o.c2) or 0), math.floor(tonumber(o.c3) or 0))
        end
        InvokeNative(N.LAYER_SHEET_GRID, tex, layer, math.floor(tonumber(o.var) or 0))
        InvokeNative(N.LAYER_ALPHA, tex, layer, l.alpha + 0.0)
    end

    local untilTime = GetGameTimer() + T.textureMs
    while not InvokeNative(N.TEXTURE_VALID, tex) and GetGameTimer() < untilTime do Wait(0) end
    -- a texture that never loaded draws as a black face: keep the plain head instead.
    -- A newer call that started meanwhile wins: give this texture back.
    if not InvokeNative(N.TEXTURE_VALID, tex) or rec.ovToken ~= token or not DoesEntityExist(ped) then
        releaseTexture(tex)
        return false
    end

    InvokeNative(N.UPDATE_TEXTURE, tex)
    InvokeNative(N.RESET_TEXTURE, tex)
    InvokeNative(N.APPLY_TEXTURE, ped, `heads`, tex)
    updateVariation(ped, false)
    rec.tex = tex -- only 32 textures exist for all peds at once: given back when replaced or the ped is gone
    return true
end

-- ---------------------------------------------------------------
-- whole skin
-- ---------------------------------------------------------------

local putOn, tintPiece   -- defined further down (clothing), used by ApplySkin to re-dress
local function ApplySkin(ped, skin)
    if not DoesEntityExist(ped) or type(skin) ~= 'table' then return false end
    local sex = sexOf(ped, skin)
    local rec = record(ped)
    if not rec.init then prepare(ped, sex) end -- a freshly made ped (e.g. a preview ped from CreatePed)
    rec.skin = skin

    -- rsg-appearance order: body + head, hair, beard, eyes, teeth, build, overlays (sliders last here)
    local head, up, low = bodyIndexes(sex, skin)
    for _, p in ipairs({ { 'heads', head }, { 'bodies_upper', up }, { 'bodies_lower', low } }) do
        local h = pieceHash(sex, p[1], p[2])
        if h then applyItem(ped, h) end
    end

    local hair = math.floor(tonumber(skin.hair) or 0)
    local hh = hair > 0 and pieceHash(sex, 'hair', hair)
    if hh then applyItem(ped, hh) else removeTag(ped, 'hair'); updateVariation(ped) end

    local beard = math.floor(tonumber(skin.beard) or 0)
    local bh = beard > 0 and pieceHash(sex, 'beards_complete', beard)
    if bh then applyItem(ped, bh)
    elseif listOf(sex, 'beards_complete') then removeTag(ped, 'beards_complete'); updateVariation(ped) end

    for _, p in ipairs({ { 'eyes', skin.eyes }, { 'teeth', skin.teeth } }) do
        local h = pieceHash(sex, p[1], skinIndex(sex, p[1], p[2] or 1))
        if h then applyItem(ped, h) end
    end

    applyBodyShape(ped, skin)
    ApplyOverlays(ped, skin)
    -- the bare body pieces above go on top of anything worn: put the worn clothes back on,
    -- otherwise only a shirt's collar and cuffs stay visible over a bare torso
    local worn = state.peds[ped] and state.peds[ped].comps
    if worn and next(worn) then
        for category, piece in pairs(worn) do putOn(ped, sex, category, piece) end
        for category, piece in pairs(worn) do tintPiece(ped, category, piece) end
        updateVariation(ped)
    end
    ApplyFeatures(ped, skin)
    return true
end

-- ---------------------------------------------------------------
-- clothing
-- ---------------------------------------------------------------

-- rsg-appearance NativeSetPedComponentEnabledClothes: refresh the category, apply, update
putOn = function(ped, sex, category, piece)
    if type(piece) ~= 'table' then return nil end
    local h = pieceHash(sex, category, piece.index)
    if not h then return nil end
    local cat = InvokeNative(N.SHOP_ITEM_CATEGORY, h, sex == 'female', true, AsInt())
    InvokeNative(N.REFRESH_SHOP_ITEMS, ped, cat)
    applyItem(ped, h, T.compReadyMs)
    return h
end

-- tints on the whole category (rsg-appearance ApplyClothes: NativeSetTextureOutfitTints)
tintPiece = function(ped, category, piece)
    if piece.palette == nil and piece.tint0 == nil and piece.tint1 == nil and piece.tint2 == nil then return end
    local pal = paletteHash(piece.palette) or MULTIData.Palettes[1]
    InvokeNative(N.OUTFIT_TINTS, ped, joaat(category), pal, math.floor(tonumber(piece.tint0) or 0),
        math.floor(tonumber(piece.tint1) or 0), math.floor(tonumber(piece.tint2) or 0))
end

--- puts the body piece back under every body part that no worn category covers
local function coverBody(ped, sex, worn)
    local covered = {}
    for category in pairs(worn) do
        for _, part in ipairs(BODY_PART_OF[category] or {}) do covered[part] = true end
    end
    local skin = (state.peds[ped] and state.peds[ped].skin) or {}
    for _, part in ipairs({ 'bodies_upper', 'bodies_lower' }) do
        if not covered[part] then applyBodyPart(ped, sex, skin, part) end
    end
end

local function reapplyFeatures(ped)
    local rec = state.peds[ped]
    local sliders = rec and (rec.sliders or rec.skin)
    if sliders then ApplyFeatures(ped, sliders) end
end

local function ApplyComp(ped, category, piece)
    if not DoesEntityExist(ped) or type(category) ~= 'string' or SKIN_CATEGORIES[category] then return false end
    local sex = sexOf(ped)
    local h = putOn(ped, sex, category, piece)
    if not h then return false end
    tintPiece(ped, category, piece)
    local rec = record(ped); rec.comps = rec.comps or {}; rec.comps[category] = piece
    updateVariation(ped, false)
    reapplyFeatures(ped)
    return true
end

--- Takes a category off. The body underneath (bodies_upper / bodies_lower) is put back so no part goes missing.
local function RemoveComp(ped, category)
    if not DoesEntityExist(ped) or type(category) ~= 'string' or SKIN_CATEGORIES[category] then return false end
    local sex = sexOf(ped)
    removeTag(ped, category)
    updateVariation(ped)
    local rec = state.peds[ped]
    if rec and rec.comps then rec.comps[category] = nil end
    for _, part in ipairs(BODY_PART_OF[category] or {}) do
        applyBodyPart(ped, sex, (rec and rec.skin) or {}, part)
    end
    reapplyFeatures(ped)
    return true
end

--- Dresses the ped in exactly `comps`: categories not listed are taken off (pass keepOthers = true to only add).
local function ApplyComps(ped, comps, keepOthers)
    if not DoesEntityExist(ped) or type(comps) ~= 'table' then return false end
    local sex = sexOf(ped)
    if not keepOthers then
        for category in pairs(MULTIData.Clothes[sex] or {}) do
            if not SKIN_CATEGORIES[category] and comps[category] == nil then removeTag(ped, category) end
        end
        for _, category in ipairs(MULTIData.ExtraClothingTags or {}) do removeTag(ped, category) end
        updateVariation(ped)
    end
    local worn = {}
    for category, piece in pairs(comps) do
        if not SKIN_CATEGORIES[category] and putOn(ped, sex, category, piece) then
            worn[category] = piece
        end
    end
    for category, piece in pairs(worn) do tintPiece(ped, category, piece) end
    -- remember what is worn, so a later skin change can put it back on top of the body
    local rec = record(ped)
    if keepOthers and rec.comps then
        for category, piece in pairs(worn) do rec.comps[category] = piece end
    else
        rec.comps = worn
    end
    if not keepOthers then coverBody(ped, sex, worn) end
    updateVariation(ped)
    reapplyFeatures(ped)
    return true
end

local function ApplyLook(ped, look)
    if not DoesEntityExist(ped) or type(look) ~= 'table' then return false end
    if type(look.skin) == 'table' then ApplySkin(ped, look.skin) end
    ApplyComps(ped, type(look.comps) == 'table' and look.comps or {})
    if ped == PlayerPedId() then state.lastPed = ped end
    return true
end

-- ---------------------------------------------------------------
-- model and the logged-in character
-- ---------------------------------------------------------------

local function setPlayerModel(sex)
    sex = sex == 'female' and 'female' or 'male'
    local model = MODELS[sex]
    RequestModel(model, false)
    local untilTime = GetGameTimer() + T.modelMs
    while not HasModelLoaded(model) and GetGameTimer() < untilTime do Wait(0) end
    if not HasModelLoaded(model) then return PlayerPedId() end
    local oldPed = PlayerPedId()
    InvokeNative(0xED40380076A31506, PlayerId(), model, false) -- SET_PLAYER_MODEL
    SetModelAsNoLongerNeeded(model)
    local ped = PlayerPedId()
    if oldPed ~= ped and state.peds[oldPed] then
        releaseTexture(state.peds[oldPed].tex)
        state.peds[oldPed] = nil
    end
    state.peds[ped] = nil
    -- naked but complete (rsg-appearance LoadModel + FixIssues), then visible (character select hides the player)
    prepare(ped, sex)
    SetEntityVisible(ped, true)
    state.lastPed = ped
    return ped
end

-- MULTIcore:client:lookApplied (reason) fires (local event) each time the logged-in character's
-- saved look has been put back on: 'reload' (ReloadLook), 'respawn' or 'revive'.
-- The optional vorp_character stand-in (MULTIvorpchar) turns it into vorp_character's events.
local function reloadLook(reason)
    local look = lib.callback.await('MULTIcore:look:get', false)
    if type(look) ~= 'table' or type(look.skin) ~= 'table' then return false end
    state.look = look
    local sex = look.skin.sex == 'female' and 'female' or 'male'
    local ped = PlayerPedId()
    if GetEntityModel(ped) ~= MODELS[sex] then ped = setPlayerModel(sex) end
    ApplyLook(ped, look)
    TriggerEvent('MULTIcore:client:lookApplied', reason or 'reload')
    return true
end
local function ReloadLook() return reloadLook('reload') end

local function GetLook() return state.look end
local function GetData() return MULTIData end

exports('ApplyLook', ApplyLook)
exports('ApplySkin', ApplySkin)
exports('ApplyComps', ApplyComps)
exports('ApplyComp', ApplyComp)
exports('RemoveComp', RemoveComp)
exports('ApplyOverlays', ApplyOverlays)
exports('ApplyFeatures', ApplyFeatures) -- extra: face + body sliders and height only (used while sliding in the creator)
exports('SetPlayerModel', setPlayerModel)
exports('ReloadLook', ReloadLook)
exports('GetLook', GetLook)
exports('GetData', GetData)

-- ---------------------------------------------------------------
-- keep the look after VORP-style respawn / revive and on logout
-- ---------------------------------------------------------------

local function afterRespawn(reason)
    if not state.look or type(state.look.skin) ~= 'table' then return end
    CreateThread(function()
        Wait(T.respawnMs) -- let the respawn finish first
        local ped = PlayerPedId()
        local sex = state.look.skin.sex == 'female' and 'female' or 'male'
        if GetEntityModel(ped) ~= MODELS[sex] then
            reloadLook(reason)
            return
        elseif ped ~= state.lastPed then
            ApplyLook(ped, state.look)
        end
        TriggerEvent('MULTIcore:client:lookApplied', reason)
    end)
end

RegisterNetEvent('MULTIcore:vorp:respawn', function() afterRespawn('respawn') end)
RegisterNetEvent('MULTIcore:vorp:revive', function() afterRespawn('revive') end)

-- the server saved a new look (SaveLook, look:save, clothing checkout): keep the cache fresh.
-- Not re-applied here: whoever changed it has already put it on the ped.
RegisterNetEvent('MULTIcore:client:lookChanged', function(look)
    if type(look) == 'table' and type(look.skin) == 'table' then state.look = look end
end)

RegisterNetEvent('MULTIcore:client:loggedOut', function()
    state.look = nil
end)

-- texture ids of peds that no longer exist are given back (32 textures for every ped in the game)
CreateThread(function()
    while true do
        Wait(T.cleanupMs)
        for ped, rec in pairs(state.peds) do
            if not DoesEntityExist(ped) then
                releaseTexture(rec.tex)
                state.peds[ped] = nil
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, rec in pairs(state.peds) do releaseTexture(rec.tex) end
end)
