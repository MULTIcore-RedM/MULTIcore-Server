--[[
    TS - clothing catalogue + outfit helpers (client + server).

    TS.category(id)                 -> Config.Designer.categories row | nil
    TS.categoryByVorp(key)          -> row | nil
    TS.appearance()                 -> 'MULTIcore' | 'vorp_character' | 'rsg-character' | 'rsg-appearance'
    TS.catalogue()                  -> { male = { [catId] = { { title?, key?, hashes = {...} }, ... } }, female = ... } | nil, err
         On MULTIcore: built from MULTIcore's own game data (MULTIData.Clothes, @MULTIcore/data/clothes.lua):
         pieces with the same item name (its _TINT_nnn dropped) are one style, their tints its colours.
         Elsewhere: from the appearance resource's own clothing file. Same order on both sides, so
         (catId, model, variant) indices sent by a client resolve to the same hash on the server.
    TS.setCatalogue(cat) / TS.resetCatalogue()
    TS.resolve(sex, catId, m, v)    -> hash | nil
    TS.findModel(sex, catId, key)   -> model index | nil   (key = vorp hash name without _TINT_nnn)
    TS.materialsFor(pieces)         -> { [item] = amount }
    TS.components(meta)             -> normalised outfit (GetOutfitComponents) | nil
    TS.sexOf(value)                 -> 'male' | 'female' | nil
    TS.palette(hash)                -> palette row | nil
]]
TS = TS or {}
local S = TS

local function cfg() return Config.Designer end

local byId, byVorp
local function index()
    if byId then return end
    byId, byVorp = {}, {}
    for i, c in ipairs(cfg().categories or {}) do
        c.order = i
        byId[c.id] = c
        byVorp[c.vorp] = c
    end
end

function S.category(id) index() return byId[id] end
function S.categoryByVorp(key) index() return byVorp[key] end

function S.sexOf(v)
    if v == nil then return nil end
    if v == true or v == 0 then return 'male' end
    if v == false or v == 1 then return 'female' end
    v = tostring(v):lower()
    if v == 'male' or v == 'm' or v == 'mp_male' or v == '0' or v == 'gentleman' then return 'male' end
    if v == 'female' or v == 'f' or v == 'mp_female' or v == '1' or v == 'lady' then return 'female' end
    return nil
end

local paletteById
function S.palette(hash)
    if not paletteById then
        paletteById = {}
        for _, p in ipairs(cfg().palettes or {}) do paletteById[p.hash] = p end
    end
    return paletteById[tonumber(hash) or -1]
end

local function started(name)
    local s = GetResourceState(name)
    return s == 'started' or s == 'starting'
end

local function multiData()
    return type(MULTIData) == 'table' and type(MULTIData.Clothes) == 'table' and MULTIData.Clothes.male ~= nil
end

function S.appearance()
    if multiData() then return 'MULTIcore' end
    if not (MBridge and MBridge.IsRsg) then return 'vorp_character' end
    local want = (cfg().catalogue.rsg or {}).resource or 'auto'
    if want ~= 'auto' then return want end
    if started('rsg-character') then return 'rsg-character' end
    return 'rsg-appearance'
end

-- ---------------------------------------------------------------- catalogue
local catalogue, catalogueErr

local function hashOf(v)
    if type(v) == 'number' then return math.floor(v) end
    if type(v) == 'table' then return tonumber(v.hash) or tonumber(v.hash_dec_signed) end
    return nil
end

local function keyOf(name)
    if type(name) ~= 'string' or name == '' then return nil end
    return (name:gsub('_TINT_%d+$', ''))
end

local function normaliseModels(list)
    local models = {}
    if type(list) ~= 'table' then return models end
    local keys = {}
    for k in pairs(list) do if type(k) == 'number' then keys[#keys + 1] = k end end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local variants = list[k]
        local hashes, title, key = {}, nil, nil
        if type(variants) == 'table' then
            local vkeys = {}
            for vk in pairs(variants) do if type(vk) == 'number' then vkeys[#vkeys + 1] = vk end end
            table.sort(vkeys)
            for _, vk in ipairs(vkeys) do
                local entry = variants[vk]
                local h = hashOf(entry)
                if h and h ~= 0 then
                    hashes[#hashes + 1] = h
                    if type(entry) == 'table' then
                        if not title and type(entry.title) == 'string' then title = entry.title end
                        if not key then key = keyOf(entry.hashname) end
                    end
                end
            end
        end
        if #hashes > 0 then models[#models + 1] = { title = title, key = key, hashes = hashes } end
    end
    return models
end

local function loadVorp()
    local src = cfg().catalogue.vorp
    local raw = LoadResourceFile(src.resource, src.file)
    if not raw then return nil, src.resource .. '/' .. src.file end
    raw = raw:gsub('`([^`]*)`', function(s) return tostring(GetHashKey(s)) end)
    local env = {}
    local chunk, err = load(raw, '@' .. src.resource .. '/' .. src.file, 't', env)
    if not chunk then return nil, tostring(err) end
    local ok, runErr = pcall(chunk)
    if not ok then return nil, tostring(runErr) end
    local data = env.Data and env.Data.clothing
    if type(data) ~= 'table' then return nil, 'Data.clothing missing' end
    local out = { male = {}, female = {} }
    for _, sex in ipairs({ 'male', 'female' }) do
        local bySex = data[sex] or {}
        for _, c in ipairs(cfg().categories) do
            local models = normaliseModels(bySex[c.vorp])
            if #models > 0 then out[sex][c.id] = models end
        end
    end
    return out
end

local function loadRsg()
    local res = S.appearance()
    local file = (cfg().catalogue.rsg or {}).file or 'data/clothing.lua'
    local raw = LoadResourceFile(res, file)
    if not raw then return nil, res .. '/' .. file end
    local env = {}
    local chunk, err = load(raw, '@' .. res .. '/' .. file, 't', env)
    if not chunk then return nil, tostring(err) end
    local ok, data = pcall(chunk)
    if not ok then return nil, tostring(data) end
    if type(data) ~= 'table' then
        for _, v in pairs(env) do if type(v) == 'table' then data = v break end end
    end
    if type(data) ~= 'table' then return nil, 'no clothing table' end
    local out = { male = {}, female = {} }
    for _, sex in ipairs({ 'male', 'female' }) do
        local bySex = data[sex] or {}
        for _, c in ipairs(cfg().categories) do
            local models = normaliseModels(bySex[c.tag] or bySex[c.vorp])
            if #models > 0 then out[sex][c.id] = models end
        end
    end
    return out
end

-- MULTIcore: MULTIData.Clothes[sex][tag] = { { h = hash, n = item name? }, ... } (game data, fixed order).
-- Named pieces are grouped into styles by name (CLOTHING_ITEM_M_HAT_000_TINT_003 -> style
-- CLOTHING_ITEM_M_HAT_000, colour 3); styles in name order, colours in tint order. Unnamed pieces
-- follow, one style each, in data order.
local function tintOf(name)
    return tonumber(name:match('_TINT_(%d+)$')) or tonumber(name:match('_V_(%d+)$')) or 0
end

local function loadMulti()
    local out = { male = {}, female = {} }
    local total = 0
    for _, sex in ipairs({ 'male', 'female' }) do
        local bySex = MULTIData.Clothes[sex] or {}
        for _, c in ipairs(cfg().categories) do
            local list = bySex[c.tag]
            if type(list) == 'table' then
                local groups, keys, loose = {}, {}, {}
                for _, item in ipairs(list) do
                    local h = tonumber(item.h)
                    if h and h ~= 0 then
                        local key = keyOf(item.n)
                        if key then
                            if not groups[key] then groups[key] = {} keys[#keys + 1] = key end
                            local g = groups[key]
                            g[#g + 1] = { h = math.floor(h), t = tintOf(item.n) }
                        else
                            loose[#loose + 1] = math.floor(h)
                        end
                    end
                end
                table.sort(keys)
                local models = {}
                for _, key in ipairs(keys) do
                    local g = groups[key]
                    table.sort(g, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.h < b.h end)
                    local hashes = {}
                    for i, e in ipairs(g) do hashes[i] = e.h end
                    models[#models + 1] = { key = key, hashes = hashes }
                end
                for _, h in ipairs(loose) do models[#models + 1] = { hashes = { h } } end
                if #models > 0 then out[sex][c.id] = models total = total + 1 end
            end
        end
    end
    if total == 0 then return nil, 'MULTIData.Clothes has no clothing' end
    return out
end

function S.catalogue()
    if catalogue then return catalogue end
    if catalogueErr then return nil, catalogueErr end
    local ok, res, err = pcall(function()
        if multiData() then return loadMulti() end
        if MBridge and MBridge.IsRsg then return loadRsg() end
        return loadVorp()
    end)
    if ok and res then
        catalogue = res
        return catalogue
    end
    catalogueErr = ok and err or tostring(res)
    return nil, catalogueErr
end

function S.resetCatalogue() catalogue, catalogueErr = nil, nil end

function S.setCatalogue(cat)
    if type(cat) == 'table' and type(cat.male) == 'table' and type(cat.female) == 'table' then
        catalogue, catalogueErr = cat, nil
        return true
    end
    return false
end

function S.resolve(sex, catId, m, v)
    local cat = S.catalogue()
    local models = cat and cat[sex] and cat[sex][catId]
    local model = models and models[tonumber(m) or -1]
    return model and model.hashes[tonumber(v) or -1] or nil
end

function S.findModel(sex, catId, key)
    local cat = S.catalogue()
    local models = cat and cat[sex] and cat[sex][catId]
    if not models or type(key) ~= 'string' then return nil end
    for i, model in ipairs(models) do
        if model.key == key then return i end
    end
    return nil
end

function S.categoryCount()
    local cat = S.catalogue()
    local n = 0
    if cat then for _, sex in pairs(cat) do for _ in pairs(sex) do n = n + 1 end end end
    return n
end

-- ---------------------------------------------------------------- outfits
function S.materialsFor(pieces)
    local need = {}
    for _, p in ipairs(pieces or {}) do
        local c = S.category(p.c)
        for _, m in ipairs(c and c.materials or {}) do
            need[m.item] = (need[m.item] or 0) + (tonumber(m.amount) or 0)
        end
    end
    return need
end

---Normalised outfit from a tailored_outfit item's metadata (nil if it is not one).
---meta.kind == 'piece' (a single ready-made garment) never empties the other slots.
function S.components(meta)
    if type(meta) ~= 'table' or type(meta.pieces) ~= 'table' then return nil end
    local sex = S.sexOf(meta.sex)
    if not sex then return nil end
    local out = {
        uid = meta.uid, name = meta.outfit or meta.label, tailor = meta.tailor or meta.maker, sex = sex,
        madeBy = meta.made_by, madeAt = meta.made_at, single = meta.kind == 'piece',
        pieces = {}, vorp = {}, rsg = {}, clears = { vorp = {}, tags = {} },
    }
    local have = {}
    for _, p in ipairs(meta.pieces) do
        local c = type(p) == 'table' and S.category(p.c) or nil
        local hash = c and tonumber(p.h)
        if c and hash and not have[c.id] then
            have[c.id] = true
            local t = type(p.t) == 'table' and p.t or {}
            local row = {
                category = c.id, label = c.label, vorp = c.vorp, tag = c.tag, keep = c.keep == true,
                hash = hash, model = tonumber(p.m), variant = tonumber(p.v),
                palette = tonumber(p.p) or 0, tint0 = tonumber(t[1]) or 0, tint1 = tonumber(t[2]) or 0, tint2 = tonumber(t[3]) or 0,
            }
            out.pieces[#out.pieces + 1] = row
            out.vorp[c.vorp] = { comp = hash, palette = row.palette, tint0 = row.tint0, tint1 = row.tint1, tint2 = row.tint2 }
            out.rsg[c.tag] = { hash = hash, model = row.model, texture = row.variant, palette = row.palette ~= 0 and row.palette or nil,
                tint0 = row.tint0, tint1 = row.tint1, tint2 = row.tint2 }
        end
    end
    if not out.single then
        for _, c in ipairs(cfg().categories) do
            if not have[c.id] and not c.keep then
                out.clears.vorp[#out.clears.vorp + 1] = c.vorp
                out.clears.tags[#out.clears.tags + 1] = c.tag
            end
        end
    end
    if #out.pieces == 0 then return nil end
    return out
end
