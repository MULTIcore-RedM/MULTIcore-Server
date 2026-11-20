-- ============================================================
-- MULTIinventory :: server/clothing/appearance_vorp.lua
--
-- VORP "mirror mode"). The equipment container is the source of
-- truth; after every change the worn pieces are written into the character's appearance record
-- (characters.compPlayer + compTints) so vorp_character keeps re-applying the same look on spawn
-- and after death. vorp_character itself is not changed and none of its code is used: online
-- characters are written through vorp_core's public character API (updateComps /
-- updateCompTints, JSON strings); offline characters with one UPDATE of those two columns.
-- Keys MULTIinventory does not own (Teeth, body parts, anything unknown) are always kept.
--
-- Shapes (as stored in characters.*):
--   compPlayer = { Hat = <signed comp> | -1, Shirt = ..., Teeth = ..., ... }
--   compTints  = { Hat = { ["<comp>"] = { tint0, tint1, tint2, palette, index?, color? } }, ... }
--
--   ClothingVorp.fromFramework(compPlayer, compTints, gender) -> { { key, meta }, ... }, skipped
--; also for the migration part: index/color -> palette_index/color_index)
--   ClothingVorp.toFramework(worn, prevComps, prevTints) -> comps, tints
--   ClothingVorp.project(equipContainer) -> comps, tints     (verification: re-projection)
--   ClothingVorp.write(charId) -> ok, how|err                ('online' | 'offline' | 'unchanged')
--   ClothingVorp.seed(src, charId, c, char)                  first-load import / "nothing worn"
--   ClothingMirror.queue(charId)   ClothingMirror.flush(force)   ClothingMirror.flushChar(charId)
-- ============================================================

ClothingVorp = ClothingVorp or {}
ClothingMirror = ClothingMirror or {}

local function CC() return Config.Clothing or {} end

local function decode(v)
    if type(v) == 'table' then return v end
    local t = Util.jsonDecode(v, {})
    return type(t) == 'table' and t or {}
end
ClothingVorp.decode = decode

function ClothingVorp.fromFramework(compPlayer, compTints, gender)
    local comps, tints = decode(compPlayer), decode(compTints)
    local g = ClothingMeta.normGender(gender)
    local pieces, skipped = {}, {}
    for _, cat in ipairs(ClothingCategories) do
        local v = comps[cat.key]
        if type(v) == 'table' then v = v.comp or v.hash end
        local comp = ClothingMeta.signed(v)
        if comp and comp ~= -1 and comp ~= 0 then
            local entry = ClothingCat.lookup(comp)
            local spec = { category = cat.key, comp = comp,
                           gender = g or (entry and entry.key == cat.key and entry.gender) or 'unisex' }
            local t = tints[cat.key]
            local tt = type(t) == 'table' and (t[tostring(comp)] or t[comp]) or nil
            if type(tt) == 'table' then
                spec.palette, spec.tint0, spec.tint1, spec.tint2 = tt.palette, tt.tint0, tt.tint1, tt.tint2
                spec.palette_index, spec.color_index = tt.index, tt.color
            end
            local meta, err = ClothingMeta.build(spec, { trusted = true, defaultLabel = 'Worn ' .. cat.label:lower() })
            if meta then pieces[#pieces + 1] = { key = cat.key, meta = meta }
            else skipped[cat.key] = err end
        end
    end
    for k in pairs(comps) do
        if not ClothingCategoriesByKey[k] and not ClothingCategoriesExcluded[k] then skipped[k] = 'not_clothing' end
    end
    return pieces, skipped
end

function ClothingVorp.toFramework(worn, prevComps, prevTints)
    local comps = Util.deepcopy(decode(prevComps))
    local tints = Util.deepcopy(decode(prevTints))
    for _, cat in ipairs(ClothingCategories) do
        local m = worn[cat.key]
        local comp = m and ClothingMeta.signed(m.comp)
        if comp then
            comps[cat.key] = comp
            local entry = {}
            for _, k in ipairs({ 'tint0', 'tint1', 'tint2', 'palette' }) do
                if m[k] ~= nil then entry[k] = m[k] end
            end
            if m.palette_index ~= nil then entry.index = m.palette_index end
            if m.color_index ~= nil then entry.color = m.color_index end
            if next(entry) then tints[cat.key] = { [tostring(comp)] = entry } else tints[cat.key] = nil end
        else
            -- not worn (route-B pieces have no shop hash and cannot be stored here)
            comps[cat.key] = -1
            tints[cat.key] = nil
        end
    end
    return comps, tints
end

function ClothingVorp.project(c)
    return ClothingVorp.toFramework(Equipment.wornMapOf(c), {}, {})
end

function ClothingVorp.write(charId)
    charId = tonumber(charId)
    local c = charId and Containers.peek('equip:' .. charId)
    if not c then return false, 'not_loaded' end
    if not Equipment.isSeeded(c) then return false, 'not_seeded' end
    local worn = Equipment.wornMapOf(c)
    local src = State.srcOfChar(charId)
    local ch = src and Equipment.char(src) or nil
    if ch and type(ch.updateComps) == 'function' then
        local prevC, prevT = decode(ch.comps), decode(ch.compTints)
        local nc, nt = ClothingVorp.toFramework(worn, prevC, prevT)
        local wrote = false
        if Meta.canonical(nc) ~= Meta.canonical(prevC) then ch.updateComps(Util.jsonEncode(nc)); wrote = true end
        if Meta.canonical(nt) ~= Meta.canonical(prevT) and type(ch.updateCompTints) == 'function' then
            ch.updateCompTints(Util.jsonEncode(nt)); wrote = true
        end
        return true, wrote and 'online' or 'unchanged'
    end
    if not CC().mirrorOffline then return false, 'offline' end
    local rows = InvDB.query('SELECT `compPlayer`, `compTints` FROM `characters` WHERE `charidentifier` = ?', { charId })
    if not rows[1] then return false, 'no_character' end
    local prevC, prevT = decode(rows[1].compPlayer), decode(rows[1].compTints)
    local nc, nt = ClothingVorp.toFramework(worn, prevC, prevT)
    if Meta.canonical(nc) == Meta.canonical(prevC) and Meta.canonical(nt) == Meta.canonical(prevT) then
        return true, 'unchanged'
    end
    local n = InvDB.update('UPDATE `characters` SET `compPlayer` = ?, `compTints` = ? WHERE `charidentifier` = ?',
        { Util.jsonEncode(nc), Util.jsonEncode(nt), charId })
    if n == nil then return false, 'sql_error' end
    return true, 'offline'
end

---First load of a character whose equipment container is empty (Equipment.onLoaded).
function ClothingVorp.seed(src, charId, c, ch)
    if not ch then return false end
    local pieces = ClothingVorp.fromFramework(ch.comps, ch.compTints, ch.gender)
    if #pieces == 0 then Equipment.setSeeded(c) return true end   -- nothing worn: nothing to lose
    if not CC().importOnFirstLoad then return false end
    local ctx = { reason = 'import' }
    local added = {}
    for _, p in ipairs(pieces) do
        local cat = ClothingCategoriesByKey[p.key]
        local ok, err = Inv.add(c, cat.item, 1, p.meta, ctx)
        if not ok then
            for _, a in ipairs(added) do Inv.remove(c, a.item, 1, a.meta, ctx) end
            print(('^3[MULTIinventory] clothing import for char %s skipped (%s: %s) - look left to the framework^7')
                :format(tostring(charId), p.key, tostring(err)))
            return false, err
        end
        added[#added + 1] = { item = cat.item, meta = p.meta }
    end
    Equipment.setSeeded(c)
    local stacks = {}
    for _, a in ipairs(added) do stacks[#stacks + 1] = { item = a.item, count = 1, metadata = a.meta } end
    InvLog.write('clothing_import', { actorSrc = src, targetCharId = charId, to = c.id, count = #added, data = { stacks = stacks } })
    return true
end

-- ------------------------------------------------------------
-- debounced writer (VORP only; the RSG mirror is appearance_rsg.lua, rsg face)
-- ------------------------------------------------------------
local pending = {}   -- [charId] = due ms

function ClothingMirror.queue(charId)
    if not MBridge.IsVorp or CC().mirrorToFramework == false then return end
    charId = tonumber(charId)
    if charId then pending[charId] = GetGameTimer() + (tonumber(CC().mirrorDebounceMs) or 1000) end
end

function ClothingMirror.flushChar(charId)
    charId = tonumber(charId)
    if not charId or not pending[charId] then return nil end
    pending[charId] = nil
    local ok, res, how = pcall(ClothingVorp.write, charId)
    if not ok then print(('^1[MULTIinventory] clothing mirror %s: %s^7'):format(tostring(charId), tostring(res))) return false end
    return res, how
end

function ClothingMirror.flush(force)
    local t = GetGameTimer()
    local due = {}
    for cid, at in pairs(pending) do if force or at <= t then due[#due + 1] = cid end end
    for _, cid in ipairs(due) do ClothingMirror.flushChar(cid) end
    return #due
end

function ClothingMirror.pending(charId) return pending[tonumber(charId)] ~= nil end

if MBridge.IsVorp then ClothingFramework = ClothingVorp end

CreateThread(function()
    while true do
        Wait(250)
        ClothingMirror.flush(false)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then ClothingMirror.flush(true) end
end)
