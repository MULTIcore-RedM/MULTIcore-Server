--[[
    Outfit Designer (server). Every callback re-checks the point, the distance and the job.

    lib.callback:
      multitailor:designer:open     (pointId)                                          -> payload | nil, err
      multitailor:designer:cut      ({ pointId, name, sex, pieces, session, hits })    -> { ok, error?, pockets?, quality? }
      multitailor:designer:patternSave / patternLoad / patternDelete  ({ pointId, ... })
      multitailor:catalogue         ()                                                 -> catalogue (client fallback)
    pieces = { { c = categoryId, m = model index, v = variant index, p = palette hash | 0, t = { t0, t1, t2 } } }
    (catalogue indices; the hash is resolved HERE from the same clothing file).
    Server event: 'MULTItailor:cut' (src, { businessId, uid, name, sex, pieces, quality })
]]
TDesigner = TDesigner or {}

local busy = {}
local P = TDB.patterns

local function cfg() return Config.Designer end

local function craftPoint(src, pointId)
    local p, role = TP.access(src, pointId, 'staff')
    if not p then return nil, role end
    if p.kind ~= 'craft' then return nil, L('err_no_access') end
    return p, role
end

local function materialItems()
    local set, list = {}, {}
    for _, c in ipairs(cfg().categories) do
        for _, m in ipairs(c.materials or {}) do
            if not set[m.item] then set[m.item] = true list[#list + 1] = m.item end
        end
    end
    for _, r in ipairs(Config.Sewing.recipes or {}) do
        for _, m in ipairs(r.required or {}) do
            if not set[m.item] then set[m.item] = true list[#list + 1] = m.item end
        end
        if not set[r.receive] then set[r.receive] = true list[#list + 1] = r.receive end
    end
    for _, mats in pairs((Config.NpcClothing or {}).materials or {}) do   -- NPC clothing section
        for _, m in ipairs(mats) do
            if not set[m.item] then set[m.item] = true list[#list + 1] = m.item end
        end
    end
    table.sort(list)
    return list
end

function TDesigner.pockets(src)
    local out = {}
    for _, item in ipairs(materialItems()) do out[item] = TA.count(src, item) end
    return out
end

function TDesigner.itemLabels()
    local out = {}
    for _, item in ipairs(materialItems()) do out[item] = TA.label(item) end
    return out
end

local function cleanName(name)
    local n = TU.text(name, cfg().nameMaxLength or 40)
    if not n or #n < 2 then return nil end
    return n
end

---Validate client pieces -> sanitized pieces with resolved hashes, or nil, err.
function TDesigner.validatePieces(sex, pieces)
    if type(pieces) ~= 'table' then return nil, L('err_no_pieces') end
    local cat, err = TS.catalogue()
    if not cat then return nil, L('err_no_catalogue', tostring(err)) end
    local out, seen = {}, {}
    for _, p in ipairs(pieces) do
        if type(p) ~= 'table' then return nil, L('err_bad_piece') end
        local c = TS.category(p.c)
        if not c or seen[c.id] then return nil, L('err_bad_piece') end
        seen[c.id] = true
        local m, v = TU.int(p.m, 1, 100000), TU.int(p.v, 1, 100000)
        local hash = m and v and TS.resolve(sex, c.id, m, v)
        if not hash then return nil, L('err_bad_piece') end
        local palette = TU.int(p.p, -2147483648, 4294967295) or 0
        if palette ~= 0 and not TS.palette(palette) then palette = 0 end
        local t = type(p.t) == 'table' and p.t or {}
        local function tint(x) return TU.int(x, 0, 254) or 0 end -- nan guard
        out[#out + 1] = { c = c.id, m = m, v = v, h = hash, p = palette, t = { tint(t[1]), tint(t[2]), tint(t[3]) }, _order = c.order }
        if #out > (cfg().maxPieces or 30) then return nil, L('err_too_many') end
    end
    if #out == 0 then return nil, L('err_no_pieces') end
    table.sort(out, function(a, b) return a._order < b._order end)
    for _, p in ipairs(out) do p._order = nil end
    return out
end

local function listPatterns(bid)
    local rows = MySQL.query.await('SELECT id, name, sex, pieces FROM `' .. P .. '` WHERE business_id = ? ORDER BY name', { bid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local ok, pcs = pcall(json.decode, r.pieces or '[]')
        out[#out + 1] = { id = tonumber(r.id), name = r.name, sex = r.sex, count = (ok and type(pcs) == 'table') and #pcs or 0 }
    end
    return out
end

-- ---------------------------------------------------------------- open
lib.callback.register('multitailor:designer:open', function(src, pointId)
    if not TA.rate(src, 'default') then return nil, L('err_slow') end
    local p, err = craftPoint(src, pointId)
    if not p then return nil, err end
    local cat, cerr = TS.catalogue()
    if not cat then return nil, L('err_no_catalogue', tostring(cerr)) end
    local b = TP.business(p)
    local cats, labels = {}, TDesigner.itemLabels()
    for _, c in ipairs(cfg().categories) do
        local mats = {}
        for _, m in ipairs(c.materials or {}) do mats[#mats + 1] = { item = m.item, amount = m.amount } end
        cats[#cats + 1] = { id = c.id, label = c.label, group = c.group, keep = c.keep == true, materials = mats }
    end
    local palettes = {}
    for _, pal in ipairs(cfg().palettes or {}) do
        if not pal.hidden then palettes[#palettes + 1] = { hash = pal.hash, label = pal.label } end
    end
    TDB.ready()
    return {
        pointId = p.id,
        businessId = b and b.id or nil,
        businessLabel = b and b.label or Config.Tailor.label,
        townLabel = b and b.town or nil,
        tailorName = TA.name(src),
        sex = TA.sex(src) or 'male',
        sexLabels = cfg().sexLabels,
        categories = cats,
        palettes = palettes,
        itemLabels = labels,
        pockets = TDesigner.pockets(src),
        patterns = b and listPatterns(b.id) or {},
        maxPieces = cfg().maxPieces,
        nameMax = cfg().nameMaxLength,
        format = TA.clothingFormat(),
        designer = p.designer,
        npc = (TNpc and TNpc.available()) and { min = Config.NpcClothing.minOutfitPieces or 3, max = Config.NpcClothing.maxOutfitPieces or 14,
                                                 nameMax = Config.NpcClothing.pieceNameMax or 40 } or nil,
    }
end)

local catalogueAsked = {}
lib.callback.register('multitailor:catalogue', function(src)
    local now = os.time()
    if catalogueAsked[src] and now - catalogueAsked[src] < 30 then return nil end
    catalogueAsked[src] = now
    return (TS.catalogue())
end)

-- ---------------------------------------------------------------- cut
local function takeAll(src, need)
    local taken = {}
    for item, n in pairs(need) do
        if n > 0 then
            if not TA.remove(src, item, n) then
                for it, k in pairs(taken) do TA.give(src, it, k) end
                return false
            end
            taken[item] = n
        end
    end
    return true, taken
end

lib.callback.register('multitailor:designer:cut', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'cut') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    local p, err = craftPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local job = TA.job(src)
    local okL, why = TA.licence(src, 'crafting', job and job.name)
    if not okL then return { ok = false, error = why } end
    local name = cleanName(data.name)
    if not name then return { ok = false, error = L('err_bad_name') } end
    local sex = TS.sexOf(data.sex)
    if not sex then return { ok = false, error = L('err_bad_piece') } end
    local pieces, perr = TDesigner.validatePieces(sex, data.pieces)
    if not pieces then return { ok = false, error = perr } end
    local okS, hits = TSew.finish(src, data.session, data.hits, 'outfit', p.id)
    if not okS then return { ok = false, error = hits } end
    local fmt = TA.clothingFormat()
    if fmt == 'unavailable' then return { ok = false, error = L('err_inventory_missing') } end

    busy[src] = true
    local result = { ok = false }
    local ok, e = pcall(function()
        local need = TS.materialsFor(pieces)
        local short = {}
        for item, n in pairs(need) do
            local have = TA.count(src, item)
            if have < n then short[#short + 1] = ('%d %s'):format(n - have, TA.label(item)) end
        end
        if #short > 0 then result = { ok = false, error = L('err_missing', table.concat(short, ', ')) } return end
        if fmt == 'outfit' and not TA.canCarry(src, Config.Items.outfitItem, 1) then result = { ok = false, error = L('err_no_room') } return end

        local took, taken = takeAll(src, need)
        if not took then result = { ok = false, error = L('err_cut_failed') } return end

        local q = TL.quality(hits, #Config.Sewing.rounds)
        local b = TP.business(p)
        local tailor = TA.name(src)
        local labels = {}
        for _, pc in ipairs(pieces) do labels[#labels + 1] = TS.category(pc.c).label end
        local sexLabel = (cfg().sexLabels or {})[sex] or sex
        local meta = {
            uid = ('%x%03x'):format(os.time(), math.random(0, 4095)),
            outfit = name, label = (q.id == 'standard') and name or (q.label .. ' ' .. name),
            tailor = tailor, maker = tailor, maker_cid = TA.cid(src), made_by = b and b.id or nil, made_at = os.time(),
            quality = q.id, quality_label = q.label, sex = sex, pieces = pieces,
            description = L('item_desc', sexLabel, name, tailor, b and b.label or Config.Tailor.label, table.concat(labels, ', ')),
        }
        local okG, gerr = TA.giveOutfit(src, { name = meta.label, description = meta.description, sex = sex, pieces = pieces, meta = meta })
        if not okG then
            for it, k in pairs(taken) do TA.give(src, it, k) end
            result = { ok = false, error = (gerr == 'slots' or gerr == 'weight' or gerr == 'no_room') and L('err_no_room') or L('err_cut_failed') }
            TU.debug('cut give failed: %s', tostring(gerr))
            return
        end
        TriggerEvent('MULTItailor:cut', src, { businessId = b and b.id or nil, uid = meta.uid, name = name, sex = sex,
            pieces = #pieces, quality = q.id })
        TA.notify(src, L('cut_ok', meta.label, q.label), 'success')
        result = { ok = true, pockets = TDesigner.pockets(src), quality = q.label }
    end)
    busy[src] = nil
    if not ok then
        print(('^1[MULTItailor] cut failed: %s^0'):format(tostring(e)))
        return { ok = false, error = L('err_cut_failed') }
    end
    return result
end)

-- ---------------------------------------------------------------- pattern book
lib.callback.register('multitailor:designer:patternSave', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, err = craftPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local b = TP.business(p)
    if not b then return { ok = false, error = L('err_no_book') } end
    local name = cleanName(data.name)
    if not name then return { ok = false, error = L('err_bad_name') } end
    local sex = TS.sexOf(data.sex)
    local pieces, perr = nil, L('err_bad_piece')
    if sex then pieces, perr = TDesigner.validatePieces(sex, data.pieces) end
    if not pieces then return { ok = false, error = perr } end
    local n = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `' .. P .. '` WHERE business_id = ?', { b.id })) or 0
    if n >= (cfg().patternsPerBusiness or 40) then return { ok = false, error = L('err_pattern_full') } end
    for _, pc in ipairs(pieces) do pc.h = nil end -- hashes are re-resolved when cut
    local cid = TA.cid(src)
    if cid then
        MySQL.insert.await('INSERT INTO `' .. P .. '` (business_id, name, sex, pieces, created_by, created_cid, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { b.id, name, sex, json.encode(pieces), TA.name(src), cid, os.time() })
    else
        MySQL.insert.await('INSERT INTO `' .. P .. '` (business_id, name, sex, pieces, created_by, created_cid, created_at) VALUES (?, ?, ?, ?, ?, NULL, ?)',
            { b.id, name, sex, json.encode(pieces), TA.name(src), os.time() })
    end
    return { ok = true, message = L('pattern_saved', name), patterns = listPatterns(b.id) }
end)

lib.callback.register('multitailor:designer:patternLoad', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, err = craftPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local b = TP.business(p)
    local id = TU.int(data.id, 1, 2147483647)
    if not b or not id then return { ok = false, error = L('err_bad_piece') } end
    local row = MySQL.single.await('SELECT id, name, sex, pieces FROM `' .. P .. '` WHERE id = ? AND business_id = ?', { id, b.id })
    if not row then return { ok = false, error = L('err_bad_piece') } end
    local ok, pcs = pcall(json.decode, row.pieces or '[]')
    return { ok = true, pattern = { id = tonumber(row.id), name = row.name, sex = row.sex, pieces = ok and pcs or {} } }
end)

lib.callback.register('multitailor:designer:patternDelete', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, err = craftPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local b = TP.business(p)
    local id = TU.int(data.id, 1, 2147483647)
    if not b or not id then return { ok = false, error = L('err_bad_piece') } end
    MySQL.update.await('DELETE FROM `' .. P .. '` WHERE id = ? AND business_id = ?', { id, b.id })
    return { ok = true, message = L('pattern_deleted'), patterns = listPatterns(b.id) }
end)

AddEventHandler('playerDropped', function() busy[source] = nil catalogueAsked[source] = nil end)
