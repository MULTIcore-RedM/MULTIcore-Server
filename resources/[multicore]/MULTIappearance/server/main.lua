-- ============================================================
-- MULTIappearance :: server
-- rsg-appearance's server events and callbacks, answered from MULTIcore's
-- look storage (exports.MULTIcore:GetLook / SaveLook) and, for outfits,
-- MULTIinventory's saved outfits (clothing items; MULTItailor is the clothing
-- system). Event names and arguments follow RSG v2 rsg-appearance (GPL v3);
-- the code is MULTIcore's own.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local dbg = MA.Debug

local function player(src)
    return RSGCore.Functions.GetPlayer(src)
end

local function lookOf(P)
    local l = exports.MULTIcore:GetLook(P.PlayerData.citizenid)
    if type(l) ~= 'table' then return nil end
    l.skin = type(l.skin) == 'table' and l.skin or {}
    l.comps = type(l.comps) == 'table' and l.comps or {}
    return l
end

local function sexOf(P, l)
    if l and (l.skin.sex == 'male' or l.skin.sex == 'female') then return l.skin.sex end
    local g = P.PlayerData.charinfo and P.PlayerData.charinfo.gender
    return (g == 1 or g == '1') and 'female' or 'male'
end

local INV = 'MULTIinventory'

local function outfitsOn()
    return Config.Outfits.UseInventoryOutfits ~= false and GetResourceState(INV) == 'started'
end

-- MULTIinventory export call, pcall-protected: returns its results, or nil when it failed
local function inv(fn, ...)
    local ok, a, b = pcall(function(...) return exports[INV][fn](exports[INV], ...) end, ...)
    if not ok then dbg(('%s failed: %s'):format(fn, tostring(a))) return nil end
    return a, b
end

-- clothing slot key (MULTIinventory) -> game category (rsg-appearance clothes key)
local SLOT_GAME = {
    Hat = 'hats', EyeWear = 'eyewear', Mask = 'masks', NeckWear = 'neckwear', NeckTies = 'neckties',
    Bow = 'hair_accessories', Shirt = 'shirts_full', Vest = 'vests', Coat = 'coats', CoatClosed = 'coats_closed',
    Poncho = 'ponchos', Cloak = 'cloaks', Suspender = 'suspenders', Dress = 'dresses', Armor = 'armor',
    Badge = 'badges', Glove = 'gloves', Gauntlets = 'gauntlets', RingRh = 'jewelry_rings_right',
    RingLh = 'jewelry_rings_left', Bracelet = 'jewelry_bracelets', Gunbelt = 'gunbelts', Holster = 'holsters_left',
    GunbeltAccs = 'gunbelt_accs', Belt = 'belts', Buckle = 'belt_buckles', Satchels = 'satchels',
    Loadouts = 'loadouts', Pant = 'pants', Skirt = 'skirts', Chap = 'chaps', Boots = 'boots', Spats = 'spats',
    Spurs = 'boot_accessories', Accessories = 'accessories',
}

-- one saved outfit (MULTIinventory: pieces = { { key, look = item metadata } }) -> rsg-appearance clothes
local function outfitClothes(o)
    local out = {}
    for _, p in ipairs(type(o.pieces) == 'table' and o.pieces or {}) do
        local game = SLOT_GAME[p.key]
        local m = type(p.look) == 'table' and p.look or {}
        if game and tonumber(m.comp) then
            local e = { hash = tonumber(m.comp) }
            if tonumber(m.palette) then
                e.palette, e.tint0, e.tint1, e.tint2 = tonumber(m.palette), tonumber(m.tint0) or 0, tonumber(m.tint1) or 0, tonumber(m.tint2) or 0
            end
            out[game] = e
        end
    end
    return out
end

local function sameHashes(a, b)
    for k, v in pairs(a) do if type(b[k]) ~= 'table' or MA.U32(b[k].hash) ~= MA.U32(v.hash) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function cleanName(s)
    s = tostring(s or ''):gsub('[%c<>"\\]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #s < 1 then return nil end
    if #s > Config.Outfits.NameMax then s = s:sub(1, Config.Outfits.NameMax) end
    return s
end

local function logSkipped(what, skipped)
    if #skipped > 0 then dbg(what .. ': no mapping for', table.concat(skipped, ', ')) end
end

-- ---------------------------------------------------------------
-- rsg-appearance:server:SetPlayerBucket(bucket, random)
-- ---------------------------------------------------------------

RegisterNetEvent('rsg-appearance:server:SetPlayerBucket', function(b, random)
    local src = source
    if random then
        if not Config.Bucket.AllowRandom then
            dbg(('SetPlayerBucket: random bucket refused for %s (Config.Bucket.AllowRandom)'):format(src))
            return
        end
        local id = math.random(Config.Bucket.RandomMin, Config.Bucket.RandomMax)
        SetRoutingBucketPopulationEnabled(id, false)
        SetPlayerRoutingBucket(src, id)
        return
    end
    b = math.floor(tonumber(b) or 0)
    if b ~= 0 and not Config.Bucket.AllowAny then
        dbg(('SetPlayerBucket: bucket %d refused for %s (Config.Bucket.AllowAny)'):format(b, src))
        return
    end
    SetPlayerRoutingBucket(src, b)
end)

-- ---------------------------------------------------------------
-- rsg-appearance:server:LoadSkin() -> puts the saved look back on the player
-- (rsg-barbers fires it after the chair, rsg-multicharacter after select)
-- ---------------------------------------------------------------

local function loadSkin(src)
    local P = player(src)
    if not P then return end
    if not lookOf(P) then
        -- rsg-appearance would open its creator here; MULTIcharacter owns character creation
        dbg(('LoadSkin: %s has no saved look, nothing applied'):format(P.PlayerData.citizenid))
        return
    end
    TriggerClientEvent('MULTIappearance:client:reload', src)
end
RegisterNetEvent('rsg-appearance:server:LoadSkin', function() loadSkin(source) end)
-- RedEM:RP's name for the same (redemrp_respawn, redemrp_clothes_store)
RegisterNetEvent('RedEM:server:LoadSkin', function() loadSkin(source) end)

-- rsg-multicharacter fires this name as a plain event (it is a callback in rsg-appearance); nothing to do,
-- LoadSkin already put the whole look on
RegisterNetEvent('rsg-appearance:server:LoadClothes', function()
    dbg('LoadClothes event: ignored (LoadSkin applies clothes too)')
end)

-- ---------------------------------------------------------------
-- rsg-appearance:server:SaveSkin(skin, clothes, oldplayer)
-- ---------------------------------------------------------------

RegisterNetEvent('rsg-appearance:server:SaveSkin', function(skin, clothes, oldplayer)
    local src = source
    local P = player(src)
    if not P then return end
    if not Config.AllowClientSaves then
        dbg(('SaveSkin from %s ignored (Config.AllowClientSaves = false)'):format(src))
        return
    end
    local l = lookOf(P) or { skin = {}, comps = {} }

    if MA.IsMultiSkin(skin) then
        exports.MULTIcore:SaveLook(src, 'skin', skin)
    elseif skin ~= nil then
        dbg('SaveSkin: RSG-format skin has no MULTIcore mapping, skin not saved (use MULTIcreator)')
    end

    if type(clothes) == 'table' then
        local sex = MA.SexOf(MA.IsMultiSkin(skin) and skin or nil, sexOf(P, l))
        local comps, skipped = MA.FromRsgClothes(clothes, sex)
        logSkipped('SaveSkin', skipped)
        local new = comps
        if oldplayer then
            -- RSG merges into what is saved
            new = {}
            for cat, piece in pairs(l.comps) do new[cat] = piece end
            for cat, piece in pairs(comps) do new[cat] = piece end
        end
        exports.MULTIcore:SaveLook(src, 'comps', new)
    end
    -- a first save in rsg-appearance also opened rsg-spawn's spawn UI; MULTIcharacter does the first spawn
end)

-- ---------------------------------------------------------------
-- Clothes and outfits
-- ---------------------------------------------------------------

-- lib.callback 'rsg-appearance:server:LoadClothes' -> the saved clothes in rsg-appearance's shape
lib.callback.register('rsg-appearance:server:LoadClothes', function(source)
    local P = player(source)
    if not P then return {} end
    local l = lookOf(P)
    if not l then return {} end
    return MA.ToRsgClothes(l.comps, sexOf(P, l))
end)

-- lib.callback 'rsg-appearance:server:getOutfits' -> { { id, citizenid, name, clothes = rsg shape }, ... }
-- (MULTIinventory's saved outfits: lists of clothing items)
lib.callback.register('rsg-appearance:server:getOutfits', function(source)
    local P = player(source)
    if not P or not outfitsOn() then return {} end
    local cid = P.PlayerData.citizenid
    local out = {}
    for _, o in ipairs(inv('GetOutfits', source) or {}) do
        out[#out + 1] = { id = o.id, citizenid = cid, name = o.name, clothes = outfitClothes(o) }
    end
    table.sort(out, function(a, b) return tostring(a.name):lower() < tostring(b.name):lower() end)
    return out
end)

-- rsg-appearance:server:saveOutfit(newClothes, isMale, outfitName)
-- RSG charged the store price and saved the clothes, plus a named outfit. Here:
--   * the named outfit is saved in MULTIinventory: the clothing items the character wears now
--   * the clothes sent by the client are never turned into items; with Config.AllowClientSaves on
--     they only change the saved look (no charge)
RegisterNetEvent('rsg-appearance:server:saveOutfit', function(newClothes, isMale, outfitName)
    local src = source
    local P = player(src)
    if not P then return end
    if Config.AllowClientSaves and type(newClothes) == 'table' then
        local l = lookOf(P) or { skin = {}, comps = {} }
        local sex = sexOf(P, l)
        if isMale ~= nil and not l.skin.sex then sex = isMale and 'male' or 'female' end
        local comps, skipped = MA.FromRsgClothes(newClothes, sex)
        logSkipped('saveOutfit', skipped)
        exports.MULTIcore:SaveLook(src, 'comps', comps)
    else
        dbg('saveOutfit: clothes sent by the client not worn (Config.AllowClientSaves = false)')
    end

    local name = outfitName and cleanName(outfitName)
    if not name then return end
    if not outfitsOn() then
        dbg('saveOutfit: MULTIinventory is not running, outfit not stored')
        return
    end
    local ok, err = inv('SaveOutfit', src, name)
    if not ok then dbg(('saveOutfit: %s not stored (%s)'):format(name, tostring(err))) end
end)

-- rsg-appearance:server:saveUseOutfit(clothes): wears one of the character's saved outfits
-- (the one whose pieces match the clothes sent). Only pieces the character owns are put on.
RegisterNetEvent('rsg-appearance:server:saveUseOutfit', function(clothes)
    local src = source
    local P = player(src)
    if not P or type(clothes) ~= 'table' or not outfitsOn() then return end
    local want = {}
    for k, v in pairs(clothes) do
        local h = type(v) == 'table' and tonumber(v.hash) or tonumber(v)
        if type(k) == 'string' and h and h ~= 0 then want[k] = { hash = h } end
    end
    for _, o in ipairs(inv('GetOutfits', src) or {}) do
        if sameHashes(outfitClothes(o), want) then
            inv('WearOutfit', src, o.id)
            return
        end
    end
    dbg(('saveUseOutfit from %s ignored: not one of their outfits'):format(src))
end)

-- rsg-appearance:server:DeleteOutfit(name)
RegisterNetEvent('rsg-appearance:server:DeleteOutfit', function(name)
    local src = source
    local P = player(src)
    if not P or not outfitsOn() then return end
    if type(name) ~= 'string' and type(name) ~= 'number' then return end
    for _, o in ipairs(inv('GetOutfits', src) or {}) do
        if tostring(o.name) == tostring(name) or tostring(o.id) == tostring(name) then
            inv('DeleteOutfit', src, o.id)
            return
        end
    end
end)

-- ---------------------------------------------------------------
-- rsg-appearance events MULTIcore handles elsewhere
-- ---------------------------------------------------------------

-- deleteSkin(license): MULTIcore removes a deleted character's look itself
RegisterNetEvent('rsg-appearance:server:deleteSkin', function()
    dbg('deleteSkin: ignored, MULTIcore removes looks with the character')
end)

-- updategender(gender): the character's sex is set by MULTIcharacter / MULTIcreator
RegisterNetEvent('rsg-appearance:server:updategender', function()
    dbg('updategender: ignored, MULTIcore keeps the sex in the look')
end)
