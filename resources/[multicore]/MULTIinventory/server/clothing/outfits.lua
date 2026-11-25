-- ============================================================
-- MULTIinventory :: server/clothing/outfits.lua
--
-- 1) Saved outfits (multiinv_outfits): a named list of REFERENCES to owned clothing stacks
--    { key, stack = stackId, hash = meta hash, item, label, look = metadata copy }.
--    Wear = equip each referenced piece the player can reach: own grid, own equipment, or an
--    open wardrobe stash of their own ('wardrobe:<charid>:<houseId>'). A piece whose stack id
--    changed (merged/split) is found again by item + identical metadata. Missing pieces are
--    reported, never created ("equips owned pieces only", 8.10 #9). `look` lets a tailor
--    reproduce a shared outfit; it is never turned into items here.
-- 2) Bundle item 'clothing_outfit': metadata = { cv = 1, kind = 'outfit', label, description?,
--    pieces = { <clothing v1 metadata>, ... }, quality/maker fields? }. Using it unpacks the
--    pieces into the grid (all or nothing); 'outfitPack' folds grid pieces into one bundle.
--
--   Outfits.list(charId) -> { { id, name, pieces, createdAt } }        (yields on first load)
--   Outfits.save(src, name) -> ok, id|err         from what is worn now
--   Outfits.wear(src, id, opts) -> ok, { equipped, missing = { key... }, failed = { key = err } }
--        opts.undress = true: also take off worn pieces that are not part of the outfit
--   Outfits.delete(src, id) -> ok, err          Outfits.rename(src, id, name) -> ok, err
--   Outfits.import(src, name, pieces) -> ok, id|err   a copy of another player's outfit (pieces matched by item + look)
--   Outfits.buildBundle(spec, opts) -> ok, meta|err       spec = { label, description?, pieces = { spec... } }
--   Outfits.unpack(src, stackId) -> ok, err
--   Outfits.pack(src, slots, label) -> ok, err|stackId     slots = player grid slots
-- Actions: outfitList {} | outfitSave { name } | outfitWear { id, undress? } | outfitDelete { id }
--          | outfitPack { slots, label }
-- Exports: GetOutfits(src) SaveOutfit(src, name) WearOutfit(src, id, undress?) DeleteOutfit(src, id) RenameOutfit(src, id, name)
--          ImportOutfit(src, name, pieces)
--          BuildOutfitMetadata(spec) CreateOutfitBundle(target, spec)
-- ============================================================

Outfits = Outfits or {}

local function CC() return Config.Clothing or {} end
local cache = {}   -- [charId] = { [id] = outfit }

local function decodePieces(s)
    local t = Util.jsonDecode(s, {})
    return type(t) == 'table' and t or {}
end

local function loadChar(charId)
    charId = tonumber(charId)
    if cache[charId] then return cache[charId] end
    local rows = InvDB.query('SELECT `id`, `name`, `pieces`, `created_at` FROM `multiinv_outfits` WHERE `charid` = ? ORDER BY `id`', { charId })
    local t = {}
    for _, r in ipairs(rows) do
        local id = math.tointeger(tonumber(r.id))
        t[id] = { id = id, name = r.name, pieces = decodePieces(r.pieces), createdAt = tonumber(r.created_at) }
    end
    cache[charId] = t
    return t
end

function Outfits.list(charId)
    local out = {}
    for _, o in pairs(loadChar(charId)) do out[#out + 1] = Util.deepcopy(o) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function cleanName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' or #name > 64 then return nil end
    return name
end

function Outfits.save(src, name)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    name = cleanName(name)
    if not name then return false, 'bad_name' end
    local list = loadChar(st.charId)
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    if n >= (CC().maxOutfits or 20) then return false, 'outfit_limit' end
    local ec = Containers.get('equip:' .. st.charId, { create = true })
    local pieces = {}
    for _, cat in ipairs(ClothingCategories) do
        local e = ec.stacks[cat.order]
        if e then
            pieces[#pieces + 1] = { key = cat.key, stack = e.id, hash = e.hash or Meta.hash(e.metadata), item = e.item,
                                    label = e.metadata and e.metadata.label or cat.label, look = Util.deepcopy(e.metadata) }
        end
    end
    if #pieces == 0 then return false, 'nothing_worn' end
    local now = Util.now()
    local ok, id = pcall(MySQL.insert.await, 'INSERT INTO `multiinv_outfits` (`charid`,`name`,`pieces`,`created_at`) VALUES (?,?,?,?)',
        { st.charId, name, json.encode(pieces), now })
    id = ok and math.tointeger(tonumber(id)) or nil
    if not id or id < 1 then return false, 'sql_error' end
    list[id] = { id = id, name = name, pieces = pieces, createdAt = now }
    return true, id
end

---A copy of another player's saved outfit (MULTItailor's "give a copy"). Only the piece list is kept, with no
---stack ids, so wearing it puts on the garments this player owns that match (same item, identical look). -> ok, id|err
function Outfits.import(src, name, pieces)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    name = cleanName(name)
    if not name then return false, 'bad_name' end
    if type(pieces) ~= 'table' then return false, 'no_pieces' end
    local list = loadChar(st.charId)
    local n = 0
    for _ in pairs(list) do n = n + 1 end
    if n >= (CC().maxOutfits or 20) then return false, 'outfit_limit' end
    local clean, seen = {}, {}
    for _, p in ipairs(pieces) do
        local cat = type(p) == 'table' and ClothingCategoriesByKey[p.key] or nil
        if cat and not seen[cat.key] and p.item == cat.item and (type(p.hash) == 'string' or type(p.hash) == 'number') then
            seen[cat.key] = true
            clean[#clean + 1] = { key = cat.key, hash = p.hash, item = cat.item,
                                  label = type(p.label) == 'string' and p.label:sub(1, 64) or cat.label,
                                  look = type(p.look) == 'table' and Util.deepcopy(p.look) or nil }
        end
    end
    if #clean == 0 then return false, 'no_pieces' end
    local now = Util.now()
    local ok, id = pcall(MySQL.insert.await, 'INSERT INTO `multiinv_outfits` (`charid`,`name`,`pieces`,`created_at`) VALUES (?,?,?,?)',
        { st.charId, name, json.encode(clean), now })
    id = ok and math.tointeger(tonumber(id)) or nil
    if not id or id < 1 then return false, 'sql_error' end
    list[id] = { id = id, name = name, pieces = clean, createdAt = now }
    return true, id
end

function Outfits.delete(src, id)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    id = math.tointeger(tonumber(id))
    local list = loadChar(st.charId)
    if not id or not list[id] then return false, 'no_outfit' end
    InvDB.update('DELETE FROM `multiinv_outfits` WHERE `id` = ? AND `charid` = ?', { id, st.charId })
    list[id] = nil
    return true
end

function Outfits.rename(src, id, name)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    id = math.tointeger(tonumber(id))
    name = cleanName(name)
    if not name then return false, 'bad_name' end
    local list = loadChar(st.charId)
    if not id or not list[id] then return false, 'no_outfit' end
    InvDB.update('UPDATE `multiinv_outfits` SET `name` = ? WHERE `id` = ? AND `charid` = ?', { name, id, st.charId })
    list[id].name = name
    return true
end

-- containers the player may take outfit pieces from
local function sources(src, charId)
    local list = { Containers.peek('player:' .. charId) }
    local sec = State.secondaryOf(src)
    local pre = (CC().wardrobePrefix or 'wardrobe:') .. charId .. ':'
    if sec and sec:sub(1, #pre) == pre then
        local c = Containers.peek(sec)
        if c then list[#list + 1] = c end
    end
    return list
end

local function locate(src, charId, piece, ec)
    local cat = ClothingCategoriesByKey[piece.key]
    if not cat then return nil end
    local w = ec.stacks[cat.order]
    if w and (w.id == piece.stack or w.hash == piece.hash) then return 'worn' end
    local allowed = {}
    for _, c in ipairs(sources(src, charId)) do allowed[c.id] = c end
    local c, e = Containers.findStack(piece.stack)
    if e and allowed[c.id] and e.item == cat.item and (e.hash == piece.hash or not piece.hash) then return c, e end
    for _, sc in pairs(allowed) do
        for _, x in pairs(sc.stacks) do
            if x.item == cat.item and x.hash == piece.hash then return sc, x end
        end
    end
    return nil
end

function Outfits.wear(src, id, opts)
    opts = opts or {}
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local o = loadChar(st.charId)[math.tointeger(tonumber(id)) or -1]
    if not o then return false, 'no_outfit' end
    local ec = Containers.get('equip:' .. st.charId, { create = true })
    local res = { equipped = 0, missing = {}, failed = {} }
    local inOutfit = {}
    local _, requires = Equipment.rules()
    local pieces = {}
    for _, p in ipairs(o.pieces) do pieces[#pieces + 1] = p; inOutfit[p.key] = true end
    -- required pieces (gunbelt) before their dependants (holster), then slot order
    table.sort(pieces, function(a, b)
        local ra, rb = requires[a.key] ~= nil, requires[b.key] ~= nil
        if ra ~= rb then return not ra end
        return (ClothingCategoriesByKey[a.key] or { order = 99 }).order < (ClothingCategoriesByKey[b.key] or { order = 99 }).order
    end)
    if opts.undress then
        for _, cat in ipairs(ClothingCategories) do
            if ec.stacks[cat.order] and not inOutfit[cat.key] then
                local ok, err = Equipment.unequip(src, cat.key, { cascade = true })
                if not ok then res.failed[cat.key] = err end
            end
        end
    end
    for _, p in ipairs(pieces) do
        local c, e = locate(src, st.charId, p, ec)
        if c == 'worn' then
            res.equipped = res.equipped + 1
        elseif not c then
            res.missing[#res.missing + 1] = p.key
        else
            local ok, err = Equipment.equip(src, c, e.slot)
            if ok then res.equipped = res.equipped + 1 else res.failed[p.key] = err end
        end
    end
    return true, res
end

-- ------------------------------------------------------------
-- bundle item
-- ------------------------------------------------------------
function Outfits.buildBundle(spec, opts)
    if type(spec) ~= 'table' or type(spec.pieces) ~= 'table' then return false, 'bad_spec' end
    local label = 'Outfit'
    if spec.label ~= nil then
        if type(spec.label) ~= 'string' then return false, 'bad_spec' end
        label = spec.label:gsub('[%c]', '')
    end
    if #label == 0 or #label > 50 then return false, 'label_too_long' end
    local m = { cv = 1, kind = 'outfit', label = label, pieces = {} }
    if spec.description ~= nil then
        if type(spec.description) ~= 'string' or #spec.description > 255 then return false, 'description_too_long' end
        m.description = spec.description
    end
    local seen = {}
    for i, ps in ipairs(spec.pieces) do
        if i > #ClothingCategories then return false, 'too_many_pieces' end
        local meta, err = ClothingMeta.build(ps, opts)
        if not meta then return false, err end
        if seen[meta.category] then return false, 'duplicate_category' end
        seen[meta.category] = true
        m.pieces[#m.pieces + 1] = meta
    end
    if #m.pieces == 0 then return false, 'no_pieces' end
    for _, k in ipairs({ 'quality', 'quality_label', 'maker', 'maker_cid', 'made_by', 'made_at', 'batch' }) do
        local v = spec[k]
        if v ~= nil and ((type(v) == 'string' and #v <= 64) or math.type(v) == 'integer') then m[k] = v end
    end
    return true, m
end

function Outfits.unpack(src, stackId)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local pc = Containers.get('player:' .. st.charId, { create = true })
    local bundle
    stackId = math.tointeger(tonumber(stackId))
    for _, e in pairs(pc.stacks) do if e.id == stackId then bundle = e break end end
    if not bundle or bundle.item ~= ClothingOutfitItem then return false, 'no_item' end
    local meta = Util.deepcopy(bundle.metadata or {})
    local pieces = {}
    for _, p in ipairs(type(meta.pieces) == 'table' and meta.pieces or {}) do
        local built = ClothingMeta.build(p, { trusted = true })
        if not built then return false, 'clothing_contract' end
        pieces[#pieces + 1] = built
    end
    if #pieces == 0 then return false, 'no_pieces' end
    local ctx = { src = src, reason = 'unpack', from = pc.id, to = pc.id }
    local ok, err = Inv.removeStack(pc, bundle.id, 1, ctx)
    if not ok then return false, err end
    local added = {}
    for _, p in ipairs(pieces) do
        local item = ClothingCategoriesByKey[p.category].item
        local okA, errA = Inv.add(pc, item, 1, p, ctx)
        if not okA then
            for _, a in ipairs(added) do Inv.remove(pc, a.item, 1, a.meta, ctx) end
            Inv.add(pc, ClothingOutfitItem, 1, meta, ctx)   -- the bundle's slot/weight was just freed
            return false, errA
        end
        added[#added + 1] = { item = item, meta = p }
    end
    local stacks = {}
    for _, a in ipairs(added) do stacks[#stacks + 1] = { item = a.item, count = 1, metadata = a.meta } end
    InvLog.write('clothing_unpack', { actorSrc = src, targetCharId = st.charId, from = pc.id, to = pc.id,
                                      item = ClothingOutfitItem, count = 1, data = { bundle = meta, stacks = stacks } })
    return true, added
end

-- Using the bundle item: unpack it and put the pieces on (Config.Clothing.outfitItemWears, default on).
-- What was worn in those slots goes into the satchel. Pieces that cannot go on stay in the satchel.
function Outfits.useBundle(src, stackId)
    local ok, added = Outfits.unpack(src, stackId)
    if not ok or CC().outfitItemWears == false then return ok, added end
    local st = State.get(src)
    local pc = st and Containers.get('player:' .. st.charId, { create = true })
    if not pc then return true end
    local _, requires = Equipment.rules()
    table.sort(added, function(a, b)   -- required pieces (gunbelt) before their dependants (holster)
        local ka, kb = a.meta.category, b.meta.category
        local ra, rb = requires[ka] ~= nil, requires[kb] ~= nil
        if ra ~= rb then return not ra end
        return (ClothingCategoriesByKey[ka] or { order = 99 }).order < (ClothingCategoriesByKey[kb] or { order = 99 }).order
    end)
    for _, a in ipairs(added) do
        for slot, e in pairs(pc.stacks) do
            if e.item == a.item and e.metadata and Meta.hash(e.metadata) == Meta.hash(a.meta) then
                Equipment.equip(src, pc, slot)
                break
            end
        end
    end
    return true
end

-- Wearing a saved outfit from the inventory follows the same rule as MULTItailor's outfit list:
-- at a clothes store, a wardrobe point or another script's wardrobe (exports.MULTItailor:CanChangeOutfit).
-- A wardrobe stash of the player's own that is open right now counts too. Without MULTItailor it is allowed.
function Outfits.canChange(src)
    local sec = State.secondaryOf(src)
    local st = State.get(src)
    local pre = (CC().wardrobePrefix or 'wardrobe:') .. tostring(st and st.charId) .. ':'
    if sec and sec:sub(1, #pre) == pre then return true end
    if GetResourceState('MULTItailor') ~= 'started' then return true end
    local ok, allowed = pcall(function() return exports.MULTItailor:CanChangeOutfit(src) end)
    if not ok then return true end
    return allowed == true
end

function Outfits.pack(src, slots, label)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    if type(slots) ~= 'table' or #slots == 0 then return false, 'no_pieces' end
    local pc = Containers.get('player:' .. st.charId, { create = true })
    local specs, picked, seenSlot = {}, {}, {}
    for _, s in ipairs(slots) do
        s = Util.toInt(s)
        local e = s and pc.stacks[s]
        if not e or seenSlot[s] or not ClothingCategoriesByItem[e.item] then return false, 'not_clothing' end
        seenSlot[s] = true
        specs[#specs + 1] = e.metadata
        picked[#picked + 1] = { id = e.id, item = e.item, meta = Util.deepcopy(e.metadata) }
    end
    local ok, meta = Outfits.buildBundle({ label = label or 'Outfit', pieces = specs }, { trusted = true })
    if not ok then return false, meta end
    local ctx = { src = src, reason = 'pack', from = pc.id, to = pc.id }
    local removed = {}
    for _, p in ipairs(picked) do
        local okR, err = Inv.removeStack(pc, p.id, 1, ctx)
        if not okR then
            for _, r in ipairs(removed) do Inv.add(pc, r.item, 1, r.meta, ctx) end
            return false, err
        end
        removed[#removed + 1] = p
    end
    local okA, placed = Inv.add(pc, ClothingOutfitItem, 1, meta, ctx)
    if not okA then
        for _, r in ipairs(removed) do Inv.add(pc, r.item, 1, r.meta, ctx) end
        return false, placed
    end
    InvLog.write('clothing_pack', { actorSrc = src, targetCharId = st.charId, from = pc.id, to = pc.id,
                                    item = ClothingOutfitItem, count = 1, data = { bundle = meta } })
    return true, placed[1] and placed[1].id
end

-- ------------------------------------------------------------
-- wiring
-- ------------------------------------------------------------
local API = {}
function API.GetOutfits(src)
    InvDB.awaitReady()
    local st = State.get(tonumber(src))
    return st and Outfits.list(st.charId) or {}
end
function API.SaveOutfit(src, name) InvDB.awaitReady() return Outfits.save(tonumber(src), name) end
function API.WearOutfit(src, id, undress) InvDB.awaitReady() return Outfits.wear(tonumber(src), id, { undress = undress == true }) end
function API.DeleteOutfit(src, id) InvDB.awaitReady() return Outfits.delete(tonumber(src), id) end
function API.RenameOutfit(src, id, name) InvDB.awaitReady() return Outfits.rename(tonumber(src), id, name) end
function API.ImportOutfit(src, name, pieces) InvDB.awaitReady() return Outfits.import(tonumber(src), name, pieces) end
function API.BuildOutfitMetadata(spec) return Outfits.buildBundle(spec) end
function API.CreateOutfitBundle(target, spec)
    InvDB.awaitReady()
    local ok, meta = Outfits.buildBundle(spec)
    if not ok then return false, meta end
    return Inv.add(target, ClothingOutfitItem, 1, meta, { reason = 'shop', resource = GetInvokingResource() })
end
Outfits.API = API

if CC().enabled ~= false then
    Actions.register('outfitList', function(src) local st = State.get(src) return true, Outfits.list(st.charId) end)
    Actions.register('outfitSave', function(src, d) return Outfits.save(src, d.name) end)
    Actions.register('outfitWear', function(src, d)
        if not Outfits.canChange(src) then return false, 'wardrobe_only' end
        return Outfits.wear(src, d.id, { undress = d.undress == true })
    end)
    Actions.register('outfitDelete', function(src, d) return Outfits.delete(src, d.id) end)
    Actions.register('outfitRename', function(src, d) return Outfits.rename(src, d.id, d.name) end)
    Actions.register('outfitPack', function(src, d) return Outfits.pack(src, d.slots, d.label) end)
    Usables.register(ClothingOutfitItem, function(data)
        local ok, err = Outfits.useBundle(data.source, data.item.id)
        if not ok then
            Sync.notify(data.source, (err == 'slots' or err == 'weight' or err == 'limit')
                and 'Not enough room to unpack the outfit.' or 'The outfit cannot be unpacked.', 'error')
        end
    end, GetCurrentResourceName())
    InvHooks.register('characterUnloaded', function(_, charId) cache[tonumber(charId)] = nil end)
    for name, fn in pairs(API) do exports(name, fn) end
end

-- tests only
function Outfits._reset() cache = {} end
