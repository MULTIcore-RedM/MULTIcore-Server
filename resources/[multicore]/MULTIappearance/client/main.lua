-- ============================================================
-- MULTIappearance :: client
-- rsg-appearance's client exports and events, answered from the
-- MULTIcore look library (exports.MULTIcore:GetLook / ApplyComps /
-- ApplyLook / ReloadLook). Names and argument shapes follow RSG v2
-- rsg-appearance (GPL v3); the code is MULTIcore's own.
-- ============================================================

local dbg = MA.Debug

local function look()
    local l = exports.MULTIcore:GetLook()
    if type(l) ~= 'table' then return { skin = {}, comps = {} } end
    return { skin = type(l.skin) == 'table' and l.skin or {}, comps = type(l.comps) == 'table' and l.comps or {} }
end

local function sexNow()
    local s = look().skin.sex
    if s == 'male' or s == 'female' then return s end
    return IsPedMale(PlayerPedId()) and 'male' or 'female'
end

local function pedSex(ped)
    if ped == PlayerPedId() then return sexNow() end
    return IsPedMale(ped) and 'male' or 'female'
end

-- ---------------------------------------------------------------
-- clothes cache (rsg-appearance client/clothes.lua exports)
-- ---------------------------------------------------------------

local function clothesCache()
    return MA.ToRsgClothes(look().comps, sexNow())
end

-- GetClothesCache() -> { [category] = { hash, palette?, tint0?, tint1?, tint2? } } of the saved clothing
MA.Export('GetClothesCache', function()
    return clothesCache()
end)

-- GetClothesComponentId(category) -> that category's cache entry or nil
MA.Export('GetClothesComponentId', function(name)
    return clothesCache()[name]
end)

-- GetClothesCurrentComponentHash(category) -> hash of the saved piece in that category, 0 when none
MA.Export('GetClothesCurrentComponentHash', function(name)
    local piece = look().comps[name]
    if type(piece) ~= 'table' then return 0 end
    return MA.PieceHash(sexNow(), name, piece.index) or 0
end)

-- GetClothesComponents() -> { male, female }, each { [category] = { hash, ... } } (every piece MULTIcore knows)
local allClothes
MA.Export('GetClothesComponents', function()
    if not allClothes then
        allClothes = {}
        for n, sex in ipairs({ 'male', 'female' }) do
            local t = {}
            for cat, list in pairs(MULTIData.Clothes[sex] or {}) do
                if not MA.SkinCategories[cat] then
                    local hashes = {}
                    for i, item in ipairs(list) do hashes[i] = item.h end
                    t[cat] = hashes
                end
            end
            allClothes[n] = t
        end
    end
    return allClothes
end)

---@deprecated in rsg-appearance too (it checks the inClothingStore state bag)
MA.Export('IsCothingActive', function()
    return LocalPlayer.state.inClothingStore == true
end)

-- ---------------------------------------------------------------
-- body / skin (rsg-appearance client/creator.lua exports)
-- ---------------------------------------------------------------

local BODY_KEYS = { BODIES_UPPER = 'bodies_upper', BODIES_LOWER = 'bodies_lower' }

-- RSG name -> { category, skin field } for the parts a MULTIcore skin holds
local SKIN_PART = {
    hair = { 'hair', 'hair' },
    beard = { 'beards_complete', 'beard' },
    heads = { 'heads', 'head' },
    head = { 'heads', 'head' },
    eyes = { 'eyes', 'eyes' },
    teeth = { 'teeth', 'teeth' },
    BODIES_UPPER = { 'bodies_upper', 'bodyUpper' },
    BODIES_LOWER = { 'bodies_lower', 'bodyLower' },
    bodies_upper = { 'bodies_upper', 'bodyUpper' },
    bodies_lower = { 'bodies_lower', 'bodyLower' },
}
local SKIN_DEFAULT = { head = 1, eyes = 1, teeth = 1, bodyUpper = 1, bodyLower = 1, hair = 0, beard = 0 }

local function skinPartHash(name)
    local part = SKIN_PART[name]
    if not part then return nil end
    local skin = look().skin
    local idx = tonumber(skin[part[2]]) or SKIN_DEFAULT[part[2]] or 0
    if idx < 1 then return nil end
    return MA.PieceHash(sexNow(), part[1], idx)
end

-- GetComponentId(name) -> rsg-appearance's LoadedComponents[name] (its skin table).
-- Answered for: sex (1 male / 2 female), head (index), height, hair / beard / eyes / teeth ({ hash }).
-- RSG's own fields (skin_tone, body_size, face sliders, overlays ...) have no MULTIcore match: nil.
MA.Export('GetComponentId', function(name)
    local skin = look().skin
    if name == 'sex' then return sexNow() == 'female' and 2 or 1 end
    if name == 'head' then return tonumber(skin.head) or 1 end
    if name == 'height' then return tonumber(skin.height) or 1.0 end
    if name == 'hair' or name == 'beard' or name == 'eyes' or name == 'teeth' then
        -- rsg-essentials' bandana reads GetComponentId('beard').hash, so a table always comes back
        return { hash = skinPartHash(name) or 0 }
    end
    dbg('GetComponentId: no MULTIcore value for', tostring(name))
    return nil
end)

-- GetBodyComponents() -> { male, female }, each { [category] = { hash, ... } } for body parts
-- (keys as rsg-appearance: BODIES_UPPER, BODIES_LOWER, heads, eyes, teeth, hair, beard)
local bodyLists
MA.Export('GetBodyComponents', function()
    if not bodyLists then
        bodyLists = {}
        for n, sex in ipairs({ 'male', 'female' }) do
            local t = {}
            local function put(key, cat)
                local list = MULTIData.Clothes[sex] and MULTIData.Clothes[sex][cat]
                if not list then return end
                local hashes = {}
                for i, item in ipairs(list) do hashes[i] = item.h end
                t[key] = hashes
            end
            for key, cat in pairs(BODY_KEYS) do put(key, cat) end
            put('heads', 'heads'); put('eyes', 'eyes'); put('teeth', 'teeth')
            put('hair', 'hair'); put('beard', 'beards_complete')
            bodyLists[n] = t
        end
    end
    return bodyLists
end)

-- GetBodyCurrentComponentHash(name) -> hash of the worn body part (hair, beard, BODIES_UPPER, BODIES_LOWER,
-- heads, eyes, teeth); nil when none or unknown (as rsg-appearance)
MA.Export('GetBodyCurrentComponentHash', function(name)
    return skinPartHash(name)
end)

-- GetComponentsMax(name) -> how many pieces exist for that part / category
MA.Export('GetComponentsMax', function(name)
    local part = SKIN_PART[name]
    return MA.Count(sexNow(), part and part[1] or name)
end)

-- GetMaxTexturesForModel(category, model): MULTIcore pieces have no model / texture split, every piece is one entry
MA.Export('GetMaxTexturesForModel', function()
    return 1
end)

-- RSG creator data (overlays, hair, beard in rsg-appearance's own numbering) cannot be translated
for _, name in ipairs({ 'SetFaceOverlays', 'SetHair', 'SetBeard' }) do
    MA.Export(name, function()
        dbg(name .. ': rsg-appearance creator data has no MULTIcore mapping, ignored (use MULTIcreator)')
    end)
end

-- ---------------------------------------------------------------
-- applying looks
-- ---------------------------------------------------------------

-- puts the logged-in character's saved look back on (same as exports.MULTIcore:ReloadLook), keeping health
local function applySavedLook()
    local ped = PlayerPedId()
    local health = GetEntityHealth(ped)
    local ok = exports.MULTIcore:ReloadLook()
    if not ok then dbg('ApplySkin: no saved look for this character yet') end
    if Config.KeepHealthOnApplySkin and PlayerPedId() ~= ped and health > 0 then
        SetEntityHealth(PlayerPedId(), health)
    end
    return ok
end

-- ApplySkin(): rsg-spawn / rsg-prison call it with no arguments to load the player's own look
MA.Export('ApplySkin', function()
    applySavedLook()
end)

-- ApplySkinMultiChar(skin, ped, clothes): dresses a preview ped.
-- A MULTIcore skin is applied fully; an RSG-format skin cannot be translated, so only its clothes are put on.
MA.Export('ApplySkinMultiChar', function(skin, ped, clothes)
    if not ped or not DoesEntityExist(ped) then return end
    local sex = MA.SexOf(skin, IsPedMale(ped) and 'male' or 'female')
    local comps, skipped = MA.FromRsgClothes(clothes, sex)
    if MA.IsMultiSkin(skin) then
        exports.MULTIcore:ApplyLook(ped, { skin = skin, comps = comps })
    else
        dbg('ApplySkinMultiChar: RSG-format skin not translated, clothes only')
        exports.MULTIcore:ApplyComps(ped, comps, true)
    end
    if #skipped > 0 then dbg('ApplySkinMultiChar: no mapping for', table.concat(skipped, ', ')) end
end)

-- rsg-appearance:client:ApplyClothes(clothes, ped?): puts the given clothes on (adds, does not take others off,
-- like rsg-appearance). Accepts RSG { hash } entries and MULTIcore { index } pieces.
RegisterNetEvent('rsg-appearance:client:ApplyClothes', function(clothes, target)
    -- a ped handle only makes sense when the event came from this client
    local fromServer = source ~= nil and source ~= '' and source ~= 0
    local ped = (not fromServer and target and DoesEntityExist(target)) and target or PlayerPedId()
    if type(clothes) ~= 'table' or next(clothes) == nil then
        SetEntityAlpha(ped, 255, false)
        return
    end
    CreateThread(function()
        local comps, skipped = MA.FromRsgClothes(clothes, pedSex(ped))
        if next(comps) then exports.MULTIcore:ApplyComps(ped, comps, true) end
        SetEntityAlpha(ped, 255, false)
        if #skipped > 0 then dbg('ApplyClothes: no mapping for', table.concat(skipped, ', ')) end
    end)
end)

-- the server side of LoadSkin answers with this (also rsg-appearance's own reply event name)
RegisterNetEvent('MULTIappearance:client:reload', function()
    CreateThread(applySavedLook)
end)
RegisterNetEvent('rsg-appearance:client:ApplySkin', function()
    -- the RSG-format data sent with it cannot be translated: load the saved MULTIcore look instead
    CreateThread(applySavedLook)
end)

-- rsg-appearance's creator: MULTIcharacter / MULTIcreator own character creation
RegisterNetEvent('rsg-appearance:client:OpenCreator', function()
    dbg('OpenCreator: ignored, MULTIcharacter and MULTIcreator create characters')
end)

-- rsg-appearance's outfit menu -> MULTItailor's outfit list
RegisterNetEvent('rsg-appearance:client:outfits', function()
    if GetResourceState('MULTItailor') == 'started' then
        TriggerEvent('MULTItailor:client:openOutfits')
    else
        dbg('outfits: MULTItailor is not running')
    end
end)
