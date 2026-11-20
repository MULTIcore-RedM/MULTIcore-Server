-- ============================================================
-- MULTIappearance :: server
-- rsg-appearance's server events and callbacks, answered from MULTIcore's
-- look storage (exports.MULTIcore:GetLook / SaveLook) and, for outfits,
-- MULTIclothing's multicore_outfits table. Event names and arguments follow
-- RSG v2 rsg-appearance (GPL v3); the code is MULTIcore's own.
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

local function outfitsOn()
    return Config.Outfits.UseMULTIclothing and GetResourceState('MULTIclothing') == 'started'
end

local function cleanName(s)
    s = tostring(s or ''):gsub('[%c<>"\\]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #s < 1 then return nil end
    if #s > Config.Outfits.NameMax then s = s:sub(1, Config.Outfits.NameMax) end
    return s
end

local function decode(v)
    if type(v) ~= 'string' then return v end
    local ok, out = pcall(json.decode, v)
    return ok and out or nil
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

RegisterNetEvent('rsg-appearance:server:LoadSkin', function()
    local src = source
    local P = player(src)
    if not P then return end
    if not lookOf(P) then
        -- rsg-appearance would open its creator here; MULTIcharacter owns character creation
        dbg(('LoadSkin: %s has no saved look, nothing applied'):format(P.PlayerData.citizenid))
        return
    end
    TriggerClientEvent('MULTIappearance:client:reload', src)
end)

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
lib.callback.register('rsg-appearance:server:getOutfits', function(source)
    local P = player(source)
    if not P or not outfitsOn() then return {} end
    local cid = P.PlayerData.citizenid
    local sex = sexOf(P, lookOf(P))
    local rows = MySQL.query.await('SELECT id, name, comps FROM multicore_outfits WHERE citizenid = ? ORDER BY name', { cid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = r.id, citizenid = cid, name = r.name, clothes = MA.ToRsgClothes(decode(r.comps) or {}, sex) }
    end
    return out
end)

-- rsg-appearance:server:saveOutfit(newClothes, isMale, outfitName)
-- RSG charged the store price and saved the clothes, plus a named outfit. Here:
--   * the named outfit is stored in multicore_outfits: the clothes sent when Config.AllowClientSaves,
--     else the character's saved clothing (what they own), as MULTIclothing does
--   * the worn clothing changes only when Config.AllowClientSaves (no charge)
RegisterNetEvent('rsg-appearance:server:saveOutfit', function(newClothes, isMale, outfitName)
    local src = source
    local P = player(src)
    if not P then return end
    local l = lookOf(P) or { skin = {}, comps = {} }
    local sex = sexOf(P, l)
    if isMale ~= nil and not l.skin.sex then sex = isMale and 'male' or 'female' end

    local comps = l.comps
    if Config.AllowClientSaves and type(newClothes) == 'table' then
        local skipped
        comps, skipped = MA.FromRsgClothes(newClothes, sex)
        logSkipped('saveOutfit', skipped)
        exports.MULTIcore:SaveLook(src, 'comps', comps)
    else
        dbg('saveOutfit: clothes sent by the client not worn (Config.AllowClientSaves = false)')
    end

    local name = outfitName and cleanName(outfitName)
    if not name then return end
    if not outfitsOn() then
        dbg('saveOutfit: MULTIclothing is not running, outfit not stored')
        return
    end
    local cid = P.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM multicore_outfits WHERE citizenid = ?', { cid }) or 0
    if count >= Config.Outfits.Max then
        dbg(('saveOutfit: %s already has %d outfits'):format(cid, count))
        return
    end
    MySQL.insert.await('INSERT INTO multicore_outfits (citizenid, name, comps) VALUES (?, ?, ?)', { cid, name, json.encode(comps) })
end)

-- rsg-appearance:server:saveUseOutfit(clothes): makes an outfit the saved clothing.
-- Allowed when the clothes are one of the character's saved outfits, or when Config.AllowClientSaves.
RegisterNetEvent('rsg-appearance:server:saveUseOutfit', function(clothes)
    local src = source
    local P = player(src)
    if not P or type(clothes) ~= 'table' then return end
    local sex = sexOf(P, lookOf(P))
    local comps, skipped = MA.FromRsgClothes(clothes, sex)
    logSkipped('saveUseOutfit', skipped)

    local allowed = Config.AllowClientSaves
    if not allowed and outfitsOn() then
        local rows = MySQL.query.await('SELECT comps FROM multicore_outfits WHERE citizenid = ?', { P.PlayerData.citizenid }) or {}
        for _, r in ipairs(rows) do
            if MA.SameComps(sex, decode(r.comps), comps) then
                allowed = true
                break
            end
        end
    end
    if not allowed then
        dbg(('saveUseOutfit from %s ignored: not one of their outfits'):format(src))
        return
    end
    exports.MULTIcore:SaveLook(src, 'comps', comps)
end)

-- rsg-appearance:server:DeleteOutfit(name)
RegisterNetEvent('rsg-appearance:server:DeleteOutfit', function(name)
    local src = source
    local P = player(src)
    if not P or not outfitsOn() then return end
    if type(name) ~= 'string' and type(name) ~= 'number' then return end
    MySQL.update.await('DELETE FROM multicore_outfits WHERE citizenid = ? AND name = ?', { P.PlayerData.citizenid, tostring(name) })
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
