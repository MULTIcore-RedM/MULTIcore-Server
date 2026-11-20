--[[
    NPC clothing at the Outfit Designer (optional; RINGOnpcclothing, soft dependency - Config.NpcClothing).

    Tailors pick CONFIRMED NPC pieces (RINGOnpcclothing decides which), preview them on the fitting dummy,
    name every piece and cut either ONE garment (npc_garment) or an OUTFIT of minOutfitPieces..maxOutfitPieces
    pieces (npc_outfit). Using an npc_outfit unpacks it into its garments; using an npc_garment puts the piece
    into the character's NPC wardrobe (RINGOnpcclothing, with the tailor's name) and puts it on.

    lib.callback:
      multitailor:npc:list   ({ pointId, sex, q, cat, page })                 -> { ok, rows, page, pages, total, cats }
      multitailor:npc:piece  ({ pointId, sex, id, v })                        -> { ok, piece, view }
      multitailor:npc:cut    ({ pointId, sex, mode = 'garment'|'outfit', name, pieces = { { id, v, name } },
                               session, hits })                               -> { ok, error?, pockets?, quality? }
    garment metadata : { uid, kind = 'npc_garment', label, description, sex, npc = { id, v, name }, materials,
                         tailor, maker, maker_cid, made_by, made_at, quality, quality_label }
    outfit metadata  : { uid, kind = 'npc_outfit', label, outfit, description, sex, npc = { { id, v, name } ... },
                         materials, tailor ... }
]]
TNpc = TNpc or {}
local busy, lastUse = {}, {}

local function cfg() return Config.NpcClothing or {} end
local function res() return cfg().resource or 'RINGOnpcclothing' end

function TNpc.available()
    return cfg().enabled ~= false and GetResourceState(res()) == 'started'
end

local function call(fn, ...)
    if not TNpc.available() then return nil, 'npc_off' end
    local ok, a, b, c = pcall(function(...) return exports[res()][fn](exports[res()], ...) end, ...)
    if not ok then TU.debug('RINGOnpcclothing %s failed: %s', fn, tostring(a)) return nil, 'npc_off' end
    return a, b, c
end

local function craftPoint(src, pointId)
    local p, role = TP.access(src, pointId, 'staff')
    if not p then return nil, role end
    if p.kind ~= 'craft' then return nil, L('err_no_access') end
    return p, role
end

---Materials for one RINGOnpcclothing category id.
function TNpc.materialsOf(catId)
    local m = cfg().materials or {}
    return m[catId] or m.default or {}
end

local function pieceName(s)
    local n = TU.text(s, cfg().pieceNameMax or 40)
    if not n or #n < 2 then return nil end
    return n
end

---Validate the pieces of a cut -> { { id, v, name, cat, label } }, need | nil, err
function TNpc.validate(sex, mode, pieces)
    if type(pieces) ~= 'table' then return nil, L('err_no_pieces') end
    local minN = mode == 'outfit' and (cfg().minOutfitPieces or 3) or 1
    local maxN = mode == 'outfit' and (cfg().maxOutfitPieces or 14) or 1
    if #pieces < minN then return nil, mode == 'outfit' and L('err_npc_min', minN) or L('err_no_pieces') end
    if #pieces > maxN then return nil, L('err_too_many') end
    local out, seen, need = {}, {}, {}
    for _, p in ipairs(pieces) do
        if type(p) ~= 'table' or type(p.id) ~= 'string' or #p.id > 96 then return nil, L('err_bad_piece') end
        local v = TU.int(p.v or 1, 1, 256)
        if not v or seen[p.id] then return nil, L('err_bad_piece') end
        seen[p.id] = true
        local ok, label, cat = call('CheckTailorPiece', sex, p.id, v)
        if not ok then return nil, label == 'npc_off' and L('err_npc_off') or L('err_npc_piece') end
        local piece = call('GetTailorPiece', sex, p.id, v)
        local gcat = type(piece) == 'table' and piece.gcat or p.id
        if seen['g:' .. gcat] then return nil, L('err_npc_same_slot') end   -- two pieces for one body slot
        seen['g:' .. gcat] = true
        local name = pieceName(p.name)
        if not name then return nil, L('err_npc_piece_name') end
        out[#out + 1] = { id = p.id, v = v, name = name, cat = cat, label = label }
        for _, m in ipairs(TNpc.materialsOf(cat)) do need[m.item] = (need[m.item] or 0) + (TU.int(m.amount, 0, 1000) or 0) end
    end
    return out, need
end

-- ---------------------------------------------------------------- browse / preview
lib.callback.register('multitailor:npc:list', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'default') then return { ok = false, error = L('err_slow') } end
    local p, err = craftPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local sex = TS.sexOf(data.sex)
    if not sex then return { ok = false, error = L('err_bad_piece') } end
    local r = call('GetTailorPieces', sex, {
        q = type(data.q) == 'string' and data.q:sub(1, 48) or nil,
        cat = type(data.cat) == 'string' and #data.cat <= 32 and data.cat or nil,
        page = TU.int(data.page or 1, 1, 10000) or 1,
    })
    if type(r) ~= 'table' then return { ok = false, error = L('err_npc_off') } end
    for _, row in ipairs(r.rows or {}) do
        local mats = {}
        for _, m in ipairs(TNpc.materialsOf(row.cat)) do mats[#mats + 1] = { item = m.item, amount = m.amount } end
        row.materials = mats
    end
    r.ok = true
    return r
end)

lib.callback.register('multitailor:npc:piece', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'preview') then return { ok = false, error = L('err_slow') } end
    local p, err = craftPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local sex = TS.sexOf(data.sex)
    if not sex or type(data.id) ~= 'string' then return { ok = false, error = L('err_bad_piece') } end
    local piece, why = call('GetTailorPiece', sex, data.id, TU.int(data.v or 1, 1, 256) or 1)
    if type(piece) ~= 'table' then return { ok = false, error = why == 'npc_off' and L('err_npc_off') or L('err_npc_piece') } end
    local _, _, cat = call('CheckTailorPiece', sex, data.id, piece.v)
    return { ok = true, piece = piece, gcat = piece.gcat, view = (cfg().views or {})[cat] or 'full' }
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

local function uid() return ('%x%03x'):format(os.time(), math.random(0, 4095)) end

lib.callback.register('multitailor:npc:cut', function(src, data)
    data = type(data) == 'table' and data or {}
    if not TA.rate(src, 'cut') then return { ok = false, error = L('err_slow') } end
    if busy[src] then return { ok = false, error = L('err_busy') } end
    if not TNpc.available() then return { ok = false, error = L('err_npc_off') } end
    local p, err = craftPoint(src, data.pointId)
    if not p then return { ok = false, error = err } end
    local job = TA.job(src)
    local okL, why = TA.licence(src, 'crafting', job and job.name)
    if not okL then return { ok = false, error = why } end
    local mode = data.mode == 'outfit' and 'outfit' or 'garment'
    local sex = TS.sexOf(data.sex)
    if not sex then return { ok = false, error = L('err_bad_piece') } end
    local outfitName
    if mode == 'outfit' then
        outfitName = TU.text(data.name, Config.Designer.nameMaxLength or 40)
        if not outfitName or #outfitName < 2 then return { ok = false, error = L('err_bad_name') } end
    end
    local pieces, need = TNpc.validate(sex, mode, data.pieces)
    if not pieces then return { ok = false, error = need } end
    local okS, hits = TSew.finish(src, data.session, data.hits, 'outfit', p.id)
    if not okS then return { ok = false, error = hits } end

    busy[src] = true
    local result = { ok = false }
    local ok, e = pcall(function()
        local short = {}
        for item, n in pairs(need) do
            local have = TA.count(src, item)
            if have < n then short[#short + 1] = ('%d %s'):format(n - have, TA.label(item)) end
        end
        if #short > 0 then result = { ok = false, error = L('err_missing', table.concat(short, ', ')) } return end
        local item = mode == 'outfit' and cfg().outfitItem or cfg().garmentItem
        if not TA.canCarry(src, item, 1) then result = { ok = false, error = L('err_no_room') } return end
        local took, taken = takeAll(src, need)
        if not took then result = { ok = false, error = L('err_cut_failed') } return end

        local q = TL.quality(hits, #Config.Sewing.rounds)
        local b = TP.business(p)
        local tailor = TA.name(src)
        local sexLabel = (Config.Designer.sexLabels or {})[sex] or sex
        local shop = b and b.label or Config.Tailor.label
        local prefix = (q.id == 'standard') and '' or (q.label .. ' ')
        local meta = {
            uid = uid(), kind = mode == 'outfit' and 'npc_outfit' or 'npc_garment', sex = sex, materials = need,
            tailor = tailor, maker = tailor, maker_cid = TA.cid(src), made_by = b and b.id or nil, made_at = os.time(),
            quality = q.id, quality_label = q.label,
        }
        if mode == 'outfit' then
            local names, list = {}, {}
            for _, pc in ipairs(pieces) do
                names[#names + 1] = pc.name
                list[#list + 1] = { id = pc.id, v = pc.v, name = pc.name }
            end
            meta.outfit, meta.label, meta.npc = outfitName, prefix .. outfitName, list
            meta.description = L('npc_outfit_desc', sexLabel, outfitName, tailor, shop, table.concat(names, ', '))
        else
            local pc = pieces[1]
            meta.label, meta.npc = prefix .. pc.name, { id = pc.id, v = pc.v, name = pc.name }
            meta.description = L('npc_garment_desc', sexLabel, pc.name, tailor, shop)
        end
        if not TA.give(src, item, 1, meta) then
            for it, k in pairs(taken) do TA.give(src, it, k) end
            result = { ok = false, error = L('err_no_room') }
            return
        end
        TriggerEvent('MULTItailor:cut', src, { businessId = b and b.id or nil, uid = meta.uid, name = meta.label, sex = sex,
            pieces = #pieces, quality = q.id, npc = true })
        TA.notify(src, L('cut_ok', meta.label, q.label), 'success')
        result = { ok = true, pockets = TDesigner.pockets(src), quality = q.label }
    end)
    busy[src] = nil
    if not ok then
        print(('^1[MULTItailor] NPC cut failed: %s^0'):format(tostring(e)))
        return { ok = false, error = L('err_cut_failed') }
    end
    return result
end)

-- ---------------------------------------------------------------- using the items
local function metaOf(data)
    local it = data and data.item or {}
    local meta = it.metadata or it.info
    return type(meta) == 'table' and meta or {}, it
end

---Find the exact inventory row of a unique item (by its uid) -> row | nil
local function rowByUid(src, item, u)
    if type(u) ~= 'string' then return nil end
    for _, r in ipairs(TA.items(src)) do
        if r.name == item and r.metadata.uid == u then return r end
    end
    return nil
end

local function guard(src)
    local now = GetGameTimer()
    if lastUse[src] and now - lastUse[src] < 2500 then TA.notify(src, L('err_wear_busy'), 'error') return false end
    lastUse[src] = now
    return true
end

local function sexOk(src, meta)
    local sex = TA.sex(src)
    if sex and meta.sex and sex ~= meta.sex then
        TA.notify(src, L('err_wrong_sex', ((Config.Designer.sexLabels or {})[meta.sex] or meta.sex):lower()), 'error')
        return false
    end
    return true
end

function TNpc.useGarment(src, meta)
    local g = type(meta.npc) == 'table' and meta.npc or nil
    if not g or type(g.id) ~= 'string' then return TA.notify(src, L('err_not_outfit'), 'error') end
    if not sexOk(src, meta) then return end
    if not TNpc.available() then return TA.notify(src, L('err_npc_off'), 'error') end
    local row = rowByUid(src, cfg().garmentItem, meta.uid)
    if not row then return TA.notify(src, L('err_not_outfit'), 'error') end
    local ok, why = call('GrantTailorPiece', src, g.id, TU.int(g.v or 1, 1, 256) or 1, g.name)
    if not ok then
        TU.debug('GrantTailorPiece refused: %s', tostring(why))
        return TA.notify(src, L('err_npc_piece'), 'error')
    end
    TA.removeById(src, row.id, 1)
    TA.closeInventory(src)
    TA.notify(src, L('npc_garment_worn', g.name or meta.label or ''), 'success')
    TriggerEvent('MULTItailor:npcGarmentUsed', src, { uid = meta.uid, id = g.id, v = g.v, name = g.name })
end

function TNpc.unpack(src, meta)
    local list = type(meta.npc) == 'table' and meta.npc or nil
    if not list or #list == 0 then return TA.notify(src, L('err_not_outfit'), 'error') end
    if not sexOk(src, meta) then return end
    local item = cfg().garmentItem
    if not TA.canCarry(src, item, #list) then return TA.notify(src, L('err_no_room'), 'error') end
    local row = rowByUid(src, cfg().outfitItem, meta.uid)
    if not row or not TA.removeById(src, row.id, 1) then return TA.notify(src, L('err_not_outfit'), 'error') end
    local sexLabel = (Config.Designer.sexLabels or {})[meta.sex] or meta.sex or ''
    local given = 0
    for _, g in ipairs(list) do
        if type(g) == 'table' and type(g.id) == 'string' then
            local gm = {
                uid = uid(), kind = 'npc_garment', sex = meta.sex, npc = { id = g.id, v = g.v, name = g.name },
                label = g.name, materials = nil, tailor = meta.tailor, maker = meta.maker, maker_cid = meta.maker_cid,
                made_by = meta.made_by, made_at = meta.made_at, quality = meta.quality, quality_label = meta.quality_label,
                from_outfit = meta.outfit,
                description = L('npc_garment_desc', sexLabel, g.name or '', meta.tailor or '?', meta.outfit or ''),
            }
            if TA.give(src, item, 1, gm) then given = given + 1 end
        end
    end
    TA.closeInventory(src)
    TA.notify(src, L('npc_unpacked', meta.outfit or meta.label or '', given), 'success')
    TriggerEvent('MULTItailor:npcOutfitUnpacked', src, { uid = meta.uid, pieces = given })
end

CreateThread(function()
    if cfg().enabled == false then return end
    if MBridge.WaitForFramework then pcall(MBridge.WaitForFramework, 60000) end
    Wait(2500)
    TA.registerUsable(cfg().garmentItem or 'npc_garment', function(data)
        local src = data and data.source
        if not src or not guard(src) then return end
        TNpc.useGarment(src, (metaOf(data)))
    end)
    TA.registerUsable(cfg().outfitItem or 'npc_outfit', function(data)
        local src = data and data.source
        if not src or not guard(src) then return end
        TNpc.unpack(src, (metaOf(data)))
    end)
end)

AddEventHandler('playerDropped', function() busy[source], lastUse[source] = nil, nil end)
