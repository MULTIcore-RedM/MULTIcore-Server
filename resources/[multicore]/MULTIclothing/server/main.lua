-- ============================================================
-- MULTIclothing :: server
-- Store checkout (cash) and saved outfits. Talks to MULTIcore only through
-- its exports (GetLook / SaveLook) and the RSGCore player object.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local Clothes = (MULTIData and MULTIData.Clothes) or {}

local PRICE = {}
for _, c in ipairs(Config.Categories) do PRICE[c.key] = c.price end

local busy = {}
local TINT_MAX = 254 -- highest tint the MULTIcore look format accepts (format limit, BASE_SET)

local function dbg(...)
    if Config.Debug then print('[MULTIclothing]', ...) end
end

-- ---------------------------------------------------------------
-- Database
-- ---------------------------------------------------------------

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS multicore_outfits (
            id INT NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(50) NOT NULL,
            name VARCHAR(64) NOT NULL,
            comps LONGTEXT NOT NULL,
            created TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY citizenid (citizenid)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    dbg('outfits table ready')
end)

-- ---------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------

local function player(src)
    return RSGCore.Functions.GetPlayer(src)
end

local function decode(v)
    if type(v) ~= 'string' then return v end
    local ok, out = pcall(json.decode, v)
    return ok and out or nil
end

local function int(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    v = math.floor(v)
    if v < lo or v > hi then return nil end
    return v
end

local function lookOf(P)
    local look = exports.MULTIcore:GetLook(P.PlayerData.citizenid)
    if type(look) ~= 'table' then look = { skin = {}, comps = {} } end
    look.skin = type(look.skin) == 'table' and look.skin or {}
    look.comps = type(look.comps) == 'table' and look.comps or {}
    return look
end

local function sexOf(P, look)
    if look.skin.sex == 'female' or look.skin.sex == 'male' then return look.skin.sex end
    local g = P.PlayerData.charinfo and P.PlayerData.charinfo.gender
    return (g == 1 or g == '1') and 'female' or 'male'
end

local function sold(sex, cat)
    return Clothes[sex] ~= nil and Clothes[sex][cat] ~= nil and not Config.NotSold[cat]
end

-- one piece from the client, checked against the look data
local function cleanPiece(sex, cat, p)
    if type(p) ~= 'table' then return nil end
    local list = Clothes[sex] and Clothes[sex][cat]
    if not list then return nil end
    local index = int(p.index, 1, #list)
    if not index then return nil end
    local out = { index = index }
    if Config.AllowColours then
        local palettes = (MULTIData and MULTIData.Palettes) and #MULTIData.Palettes or 0
        out.palette = int(p.palette, 1, palettes)
        if out.palette then
            out.tint0 = int(p.tint0, 0, TINT_MAX) or 0
            out.tint1 = int(p.tint1, 0, TINT_MAX) or 0
            out.tint2 = int(p.tint2, 0, TINT_MAX) or 0
        end
    end
    return out
end

local function sameColour(a, b)
    return a.palette == b.palette and (a.tint0 or 0) == (b.tint0 or 0)
        and (a.tint1 or 0) == (b.tint1 or 0) and (a.tint2 or 0) == (b.tint2 or 0)
end

local function cents(n) return math.floor(n * 100 + 0.5) / 100 end

local function near(src, points)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for _, p in ipairs(points) do
        if p and #(pos - vector3(p.x, p.y, p.z)) <= Config.UseRange then return true end
    end
    return false
end

local function storePoints(store)
    return { store.coords, store.fitting, store.exit }
end

local function nearStore(src, storeId)
    local store = Config.Stores[storeId]
    return store ~= nil and near(src, storePoints(store))
end

local function nearAnyWardrobe(src)
    if Config.Outfits.Command then return true end
    for _, s in pairs(Config.Stores) do
        if near(src, storePoints(s)) then return true end
    end
    for _, coords in ipairs(Config.Wardrobes) do
        if near(src, { coords }) then return true end
    end
    return false
end

local function cleanName(s)
    s = tostring(s or ''):gsub('[%c<>"\\]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #s < 1 then return nil end
    if #s > Config.Outfits.NameMax then s = s:sub(1, Config.Outfits.NameMax) end
    return s
end

-- ---------------------------------------------------------------
-- Store checkout
-- wanted = the client's comps for every sold category (missing = taken off).
-- The price is worked out here from the saved look, never taken from the client.
-- ---------------------------------------------------------------

local function buy(src, storeId, wanted)
    local P = player(src)
    if not P then return false, 'failed' end
    if not nearStore(src, storeId) then return false, 'too_far' end
    if type(wanted) ~= 'table' then return false, 'failed' end

    local look = lookOf(P)
    local sex = sexOf(P, look)
    local old = look.comps
    local new, total = {}, 0.0

    -- keep everything the store doesn't sell exactly as it is
    for cat, piece in pairs(old) do
        if not sold(sex, cat) then new[cat] = piece end
    end

    for cat in pairs(Clothes[sex] or {}) do
        if sold(sex, cat) then
            local w = cleanPiece(sex, cat, wanted[cat])
            if w then
                new[cat] = w
                local o = old[cat]
                local price = PRICE[cat] or Config.DefaultPrice
                if type(o) ~= 'table' or tonumber(o.index) ~= w.index then
                    total = total + price
                elseif not sameColour(o, w) then
                    total = total + price * Config.RecolourFactor
                end
            end
        end
    end
    total = cents(total)

    if total > 0 then
        if (P.PlayerData.money.cash or 0) < total then return false, 'no_cash' end
        if not P.Functions.RemoveMoney("cash", total, Config.MoneyReason) then return false, 'no_cash' end
    end

    local ok = exports.MULTIcore:SaveLook(src, 'comps', new)
    if not ok then
        if total > 0 then P.Functions.AddMoney("cash", total, Config.MoneyReason) end
        return false, 'failed'
    end
    dbg(('%s paid %.2f at %s'):format(P.PlayerData.citizenid, total, tostring(storeId)))
    return true, total
end

lib.callback.register('MULTIclothing:buy', function(src, storeId, wanted)
    if busy[src] then return false, 'busy' end
    busy[src] = true
    local ok, a, b = pcall(buy, src, storeId, wanted)
    busy[src] = nil
    if not ok then
        print('[MULTIclothing] buy error: ' .. tostring(a))
        return false, 'failed'
    end
    return a, b
end)

-- ---------------------------------------------------------------
-- Outfits
-- ---------------------------------------------------------------

lib.callback.register('MULTIclothing:outfits:list', function(src)
    local P = player(src)
    if not P then return {} end
    return MySQL.query.await('SELECT id, name FROM multicore_outfits WHERE citizenid = ? ORDER BY name',
        { P.PlayerData.citizenid }) or {}
end)

-- saves the character's saved look (not an unpaid preview) under a name
lib.callback.register('MULTIclothing:outfits:save', function(src, name)
    local P = player(src)
    if not P then return false, 'failed' end
    name = cleanName(name)
    if not name then return false, 'failed' end
    local cid = P.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM multicore_outfits WHERE citizenid = ?', { cid }) or 0
    if count >= Config.Outfits.Max then return false, 'full' end
    local comps = lookOf(P).comps
    local id = MySQL.insert.await('INSERT INTO multicore_outfits (citizenid, name, comps) VALUES (?, ?, ?)',
        { cid, name, json.encode(comps) })
    return id ~= nil, id
end)

lib.callback.register('MULTIclothing:outfits:rename', function(src, id, name)
    local P = player(src)
    id, name = tonumber(id), cleanName(name)
    if not P or not id or not name then return false end
    local n = MySQL.update.await('UPDATE multicore_outfits SET name = ? WHERE id = ? AND citizenid = ?',
        { name, id, P.PlayerData.citizenid })
    return (n or 0) > 0
end)

lib.callback.register('MULTIclothing:outfits:delete', function(src, id)
    local P = player(src)
    id = tonumber(id)
    if not P or not id then return false end
    local n = MySQL.update.await('DELETE FROM multicore_outfits WHERE id = ? AND citizenid = ?',
        { id, P.PlayerData.citizenid })
    return (n or 0) > 0
end)

-- makes the outfit the character's saved clothing
lib.callback.register('MULTIclothing:outfits:wear', function(src, id)
    local P = player(src)
    id = tonumber(id)
    if not P or not id then return false, 'failed' end
    if not nearAnyWardrobe(src) then return false, 'too_far' end
    local raw = MySQL.scalar.await('SELECT comps FROM multicore_outfits WHERE id = ? AND citizenid = ?',
        { id, P.PlayerData.citizenid })
    local comps = decode(raw)
    if type(comps) ~= 'table' then return false, 'failed' end
    if not exports.MULTIcore:SaveLook(src, 'comps', comps) then return false, 'failed' end
    return true
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)

-- ---------------------------------------------------------------
-- rsg-wardrobe server API (names and arguments as in RSG v2 rsg-wardrobe;
-- e.g. rsg-bathing calls RemovePlayerClothing / DressPlayer)
--   TogglePlayerClothing(source, name)
--   RemovePlayerClothing(source)
--   DressPlayer(source)        puts the saved clothing back on
-- ---------------------------------------------------------------

MCAlias.Wardrobe('TogglePlayerClothing', function(source, name)
    TriggerClientEvent('rsg-wardrobe:client:OnOffClothing', source, name)
end)

MCAlias.Wardrobe('RemovePlayerClothing', function(source)
    TriggerClientEvent('rsg-wardrobe:client:removeAllClothing', source)
end)

MCAlias.Wardrobe('DressPlayer', function(source)
    if not player(source) then return end
    TriggerClientEvent('MULTIclothing:client:dress', source)
end)

-- A deleted character's outfits go with it
AddEventHandler('MULTIcore:characterDeleted', function(_, citizenid)
    if type(citizenid) ~= 'string' then return end
    MySQL.update('DELETE FROM multicore_outfits WHERE citizenid = ?', { citizenid })
end)
