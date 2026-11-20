-- ============================================================
-- MULTIinventory :: server/clothing/equipment.lua
--
-- The equipment container 'equip:<charid>' (slot = ClothingCategories[].order) is the
-- source of truth for worn clothing. Every route that changes it - the
-- 'equip'/'unequip' actions, a plain NUI drag ('move'), the exports, admin tools - goes
-- through the core rule layer (Inv.*) and therefore through the hooks below, so the rules
-- hold everywhere:
--   canPlace  (equip slot)  contract cv=1 (or a legacy piece if allowed), category, gender,
--                           exclusions (Coat vs CoatClosed, Dress vs Shirt/Pant/Skirt, ...),
--                           requirements (Holster / GunbeltAccs need a Gunbelt)
--   canRemove (equip)       a piece other worn pieces depend on cannot be dragged out alone
--   canAdd/canRemove        worn clothing of someone else: never from a player session unless
--                           Config.Secondary.search.allowClothing (), admin excepted
--   canAdd (wardrobe:*)     wardrobe stashes hold clothing only
-- After a change (core containerChanged, batched 100 ms):
--   TriggerEvent('MULTIinventory:clothingChanged', charId, key, meta|nil)   (one per changed slot)
--   InvHooks.emit('clothingChanged', charId, key, meta|nil)
-- the owner's client gets the full worn set ('MULTIinventory:cl:clothing') and applies it,
-- and the framework mirror is queued (appearance_vorp.lua / appearance_rsg.lua).
--
-- "Seeded": a character's equipment container is managed by the inventory once it was filled
-- by the migration, by the first-load import, or confirmed empty while the framework record is
-- empty too. Only seeded characters are stripped of unworn categories and mirrored - so a
-- character whose clothes were never imported can never lose their look (c.flags.clothingSeeded).
--
--   Equipment.equip(src, fromC, fromSlot) -> ok, err          (conflicts swapped out per config)
--   Equipment.equipStack(src, stackId) -> ok, err
--   Equipment.unequip(src, key, opts) -> ok, err              opts.toSlot, opts.cascade
--   Equipment.worn(charId) -> { [key] = meta }                (loads the container if needed)
--   Equipment.genderOf(charId) -> 'male'|'female'|nil
--   Equipment.isSeeded(c) -> bool
--   Equipment.push(src|'equip:<cid>', reason)                 send the worn set to the client
--   Equipment.build(spec) -> ok, meta|err    Equipment.create(target, spec, count, ctx) -> ok, err|placed
-- Actions (NUI): equip { container?, slot } | unequip { key | slot, toSlot? } | clothingCatalog { category, gender }
-- Usable: every clothing_* item -> "use" = wear it.
-- Server exports (exports.MULTIinventory:<Name>):
--   BuildClothingMetadata(spec) -> ok, meta|err       CreateClothingItem(target, spec, count) -> ok, err|placed
--   GetClothingCatalog(key?, gender?) -> list         GetClothingCategories() -> categories
--   EquipClothing(src, stackId) -> ok, err            UnequipClothing(src, key, toSlot?) -> ok, err
--   GetWorn(charId) -> { [key] = meta }               ReapplyClothing(src) -> bool
-- ============================================================

Equipment = Equipment or {}

local function CC() return Config.Clothing or {} end
local BYKEY, BYITEM = ClothingCategoriesByKey, ClothingCategoriesByItem

local genders = {}    -- [charId] = 'male' | 'female'
local lastWorn = {}   -- [charId] = { [key] = hash }

local MSG = {
    clothing_gender = 'That piece does not fit you.',
    clothing_conflict = 'Take off the piece that is in the way first.',
    clothing_requires = 'You need to wear a gunbelt for that.',
    clothing_required_by = 'Take off what hangs on it first.',
    clothing_contract = 'That item cannot be worn.',
    not_clothing = 'That is not clothing.',
    clothing_only = 'Only clothing goes in a wardrobe.',
}
Equipment.MSG = MSG

-- ------------------------------------------------------------
-- rules (built from config; rebuilt when Config.Clothing is replaced)
-- ------------------------------------------------------------
local rulesFor, conflicts, requires, dependants
local function rules()
    local cfg = CC()
    if rulesFor == cfg and conflicts then return end
    rulesFor = cfg
    conflicts, requires, dependants = {}, {}, {}
    for _, pair in ipairs(cfg.exclusions or {}) do
        local a, b = pair[1], pair[2]
        if BYKEY[a] and BYKEY[b] then
            conflicts[a] = conflicts[a] or {}; table.insert(conflicts[a], b)
            conflicts[b] = conflicts[b] or {}; table.insert(conflicts[b], a)
        end
    end
    for k, req in pairs(cfg.requires or {}) do
        if BYKEY[k] and BYKEY[req] then
            requires[k] = req
            dependants[req] = dependants[req] or {}
            table.insert(dependants[req], k)
        end
    end
    for _, l in pairs(dependants) do table.sort(l) end
end
function Equipment.rules() rulesFor = nil; rules() return conflicts, requires, dependants end

-- ------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------
local function equipIdOf(charId) return 'equip:' .. tostring(charId) end
local function playerIdOf(charId) return 'player:' .. tostring(charId) end

function Equipment.char(src)
    local ok, user = pcall(function() return MBridge.Core.getUser(src) end)
    if not ok or not user then return nil end
    local ch = user.getUsedCharacter
    if type(ch) == 'function' then ch = ch() end
    return ch
end

function Equipment.genderOf(charId)
    charId = tonumber(charId)
    if not charId then return nil end
    if genders[charId] then return genders[charId] end
    local src = State.srcOfChar(charId)
    if src then
        local ch = Equipment.char(src)
        genders[charId] = ch and ClothingMeta.normGender(ch.gender) or nil
    end
    return genders[charId]
end

function Equipment.isSeeded(c)
    return c ~= nil and c.flags ~= nil and c.flags.clothingSeeded == true
end

function Equipment.setSeeded(c)
    c.flags = c.flags or {}
    if c.flags.clothingSeeded then return end
    c.flags.clothingSeeded = true
    c.defDirty = true
    Persistence.markDirty(c)
end

local function pieceGender(meta)
    local g = meta and meta.gender
    if g == 'unisex' then return 'unisex' end
    return ClothingMeta.normGender(g)
end

local function isAdminCtx(ctx)
    return ctx ~= nil and (ctx.admin == true or tostring(ctx.reason or ''):sub(1, 5) == 'admin')
end

local function foreignOk(c, ctx)
    if not ctx or not ctx.src or isAdminCtx(ctx) then return true end
    local st = State.get(ctx.src)
    if st and equipIdOf(st.charId) == c.id then return true end
    if State.isAdminSession(ctx.src) then return true end
    local s = Config.Secondary and Config.Secondary.search
    return s ~= nil and s.allowClothing == true
end

---Validate a piece for the container's character (contract, category, gender). No slot rules.
function Equipment.checkPiece(c, cat, meta)
    meta = meta or {}
    if meta.cv == nil then
        if not CC().allowLegacyPieces then return false, 'clothing_contract' end
        if meta.category ~= nil and meta.category ~= cat.key then return false, 'clothing_contract' end
    else
        if not ClothingMeta.check(meta, cat.key) then return false, 'clothing_contract' end
    end
    if not ClothingMeta.genderOk(pieceGender(meta), Equipment.genderOf(c.ownerCharId)) then
        return false, 'clothing_gender'
    end
    return true
end

local function conflictIn(c, cat, entry)
    rules()
    for _, k in ipairs(conflicts[cat.key] or {}) do
        local o = c.stacks[BYKEY[k].order]
        if o and o ~= entry then return k end
    end
    return nil
end

function Equipment.wornMapOf(c)
    local out = {}
    if not c then return out end
    for _, cat in ipairs(ClothingCategories) do
        local e = c.stacks[cat.order]
        if e and e.kind ~= 'weapon' then out[cat.key] = e.metadata or {} end
    end
    return out
end

function Equipment.worn(charId)
    local c = Containers.peek(equipIdOf(charId)) or Inv.resolve(equipIdOf(charId))
    return Util.deepcopy(Equipment.wornMapOf(c))
end

local function hashesOf(c)
    local out = {}
    if not c then return out end
    for _, cat in ipairs(ClothingCategories) do
        local e = c.stacks[cat.order]
        if e then out[cat.key] = e.hash or Meta.hash(e.metadata) end
    end
    return out
end

local function findByKey(c, item, key)
    for slot, e in pairs(c.stacks) do
        if e.item == item and e.key == key then return slot, e end
    end
    return nil
end
Equipment.findByKey = findByKey

local function log(action, src, charId, from, to, item, meta)
    InvLog.write(action, { actorSrc = src, targetCharId = charId, from = from, to = to, item = item, count = 1,
                           data = { stacks = { { item = item, count = 1, metadata = Util.deepcopy(meta) } } } })
end
Equipment.log = log

-- ------------------------------------------------------------
-- change notification + client push
-- ------------------------------------------------------------
function Equipment.slotsView()
    local slots = {}
    for _, c in ipairs(ClothingCategories) do
        slots[#slots + 1] = { slot = c.order, key = c.key, item = c.item, label = c.label, panel = c.panel }
    end
    rules()
    return { slots = slots, conflicts = conflicts, requires = requires }
end

function Equipment.push(target, reason)
    local src, charId
    if type(target) == 'string' then charId = tonumber(target:match('(%d+)$')) else src = tonumber(target) end
    if src then local st = State.get(src); charId = st and st.charId end
    if charId and not src then src = State.srcOfChar(charId) end
    if not src or not charId then return false end
    local c = Containers.peek(equipIdOf(charId))
    if not c then return false end
    TriggerClientEvent('MULTIinventory:cl:clothing', src, {
        charId = charId,
        gender = Equipment.genderOf(charId),
        authoritative = Equipment.isSeeded(c),
        pieces = Equipment.wornMapOf(c),
        reason = reason or 'change',
    })
    return true
end

function Equipment.onChanged(c)
    local cid = c.ownerCharId
    local now = hashesOf(c)
    local prev = lastWorn[cid] or {}
    local changed = false
    for _, cat in ipairs(ClothingCategories) do
        if now[cat.key] ~= prev[cat.key] then
            changed = true
            local e = c.stacks[cat.order]
            local meta = e and Util.deepcopy(e.metadata) or nil
            TriggerEvent('MULTIinventory:clothingChanged', cid, cat.key, meta)
            InvHooks.emit('clothingChanged', cid, cat.key, meta)
        end
    end
    lastWorn[cid] = now
    if not changed then return end
    Equipment.push('equip:' .. cid, 'change')
    if ClothingMirror then ClothingMirror.queue(cid) end
end

function Equipment.onLoaded(src, charId)
    local ch = Equipment.char(src)
    genders[charId] = ch and ClothingMeta.normGender(ch.gender) or nil
    local c = Containers.peek(equipIdOf(charId))
    if not c then return end
    if not Equipment.isSeeded(c) then
        if next(c.stacks) ~= nil then
            Equipment.setSeeded(c)  -- filled by the migration (or the API) before this load
        elseif ClothingFramework and ClothingFramework.seed then
            ClothingFramework.seed(src, charId, c, ch)   -- import, or confirm "nothing worn"
        end
    end
    lastWorn[charId] = hashesOf(c)
    Equipment.push(src, 'load')
    if Equipment.isSeeded(c) and ClothingMirror then ClothingMirror.queue(charId) end
end

-- ------------------------------------------------------------
-- hooks
-- ------------------------------------------------------------
local function registerHooks()
    InvHooks.register('canPlace', function(c, slot, entry, ctx)
        if c.kind ~= 'equip' then return true end
        local cat = ClothingCategories[slot]
        if not cat then return true end
        if not foreignOk(c, ctx) then return false, 'no_access' end
        local ok, err = Equipment.checkPiece(c, cat, entry.metadata)
        if not ok then return false, err end
        if conflictIn(c, cat, entry) then return false, 'clothing_conflict' end
        local req = requires[cat.key]
        if req and not c.stacks[BYKEY[req].order] then return false, 'clothing_requires' end
        return true
    end)

    InvHooks.register('canRemove', function(c, e, count, ctx)
        if c.kind ~= 'equip' then return true end
        if not foreignOk(c, ctx) then return false, 'no_access' end
        -- API/admin calls (no player) and swaps into the same slot are never blocked
        if not ctx or not ctx.src or isAdminCtx(ctx) or ctx.cascade or ctx.to == c.id then return true end
        local cat = BYITEM[e.item]
        if not cat then return true end
        rules()
        for _, dk in ipairs(dependants[cat.key] or {}) do
            if c.stacks[BYKEY[dk].order] then return false, 'clothing_required_by' end
        end
        return true
    end)

    InvHooks.register('canAdd', function(c, item, count, meta, ctx)
        if c.kind == 'equip' then
            if not foreignOk(c, ctx) then return false, 'no_access' end
            return true
        end
        local pre = CC().wardrobePrefix
        if pre and pre ~= '' and tostring(c.id):sub(1, #pre) == pre then
            if not BYITEM[item] and item ~= ClothingOutfitItem then return false, 'clothing_only' end
        end
        return true
    end)

    InvHooks.register('containerChanged', function(c)
        if c.kind ~= 'equip' or not c.ownerCharId then return end
        Equipment.onChanged(c)
    end)

    InvHooks.register('characterLoaded', function(src, charId)
        Equipment.onLoaded(src, charId)
    end)

    InvHooks.register('characterUnloaded', function(src, charId)
        if ClothingMirror then ClothingMirror.flushChar(charId) end
        lastWorn[charId] = nil
        genders[charId] = nil
    end)

    InvHooks.register('openPayload', function(src, payload)
        payload.clothing = Equipment.slotsView()
    end)
end

-- ------------------------------------------------------------
-- equip / unequip
-- ------------------------------------------------------------
-- undo pieces taken off during a failed equip/unequip (best effort; printed on failure)
local function moveBack(ec, pc, list, ctx)
    for i = #list, 1, -1 do
        local x = list[i]
        local slot = findByKey(pc, x.item, x.key)
        if slot and not ec.stacks[x.order] then
            local ok, err = Inv.move(pc, slot, ec, x.order, 1, ctx)
            if not ok then print(('^1[MULTIinventory] clothing rollback failed (%s): %s^7'):format(x.item, tostring(err))) end
        end
    end
end

function Equipment.equip(src, fromC, fromSlot)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local e = fromC and fromC.stacks[fromSlot]
    if not e or e.kind == 'weapon' then return false, 'no_item' end
    local cat = BYITEM[e.item]
    if not cat then return false, 'not_clothing' end
    local ec = Containers.get(equipIdOf(st.charId), { create = true })
    local pc = Containers.get(playerIdOf(st.charId), { create = true })
    if fromC == ec then return true end
    local ctx = { src = src, reason = 'equip', from = fromC.id, to = ec.id }
    local ok, err = Equipment.checkPiece(ec, cat, e.metadata)
    if not ok then return false, err end
    rules()
    local req = requires[cat.key]
    if req and not ec.stacks[BYKEY[req].order] then return false, 'clothing_requires' end

    local taken = {}
    local undoCtx = { src = src, reason = 'equip', cascade = true, from = pc.id, to = ec.id }
    -- conflicting pieces (Coat <-> CoatClosed, ...)
    for _, k in ipairs(conflicts[cat.key] or {}) do
        local kc = BYKEY[k]
        local o = ec.stacks[kc.order]
        if o then
            if CC().exclusionMode ~= 'swap' then moveBack(ec, pc, taken, undoCtx) return false, 'clothing_conflict' end
            local item, key = o.item, o.key
            local okU, errU = Equipment.unequip(src, k, { cascade = true })
            if not okU then moveBack(ec, pc, taken, undoCtx) return false, errU end
            taken[#taken + 1] = { item = item, key = key, order = kc.order }
        end
    end
    -- the slot itself
    local old = ec.stacks[cat.order]
    if old and e.count == 1 then
        -- whole-entry swap: the old piece lands where the new one was
        ok, err = Inv.move(fromC, fromSlot, ec, cat.order, 1, ctx)
    else
        if old then
            local oldItem, oldKey = old.item, old.key
            -- replacing a piece others depend on keeps the requirement met -> cascade ctx
            ok, err = Inv.move(ec, cat.order, pc, nil, 1, { src = src, reason = 'unequip', cascade = true, from = ec.id, to = pc.id })
            if not ok then moveBack(ec, pc, taken, undoCtx) return false, err end
            taken[#taken + 1] = { item = oldItem, key = oldKey, order = cat.order }
        end
        ok, err = Inv.move(fromC, fromSlot, ec, cat.order, 1, ctx)
    end
    if not ok then moveBack(ec, pc, taken, undoCtx) return false, err end
    local worn = ec.stacks[cat.order]
    log('clothing_equip', src, st.charId, fromC.id, ec.id, worn.item, worn.metadata)
    return true
end

function Equipment.equipStack(src, stackId)
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local c, e = Containers.findStack(stackId)
    if not e then return false, 'no_item' end
    if not State.canAccess(src, c.id) then return false, 'no_access' end
    return Equipment.equip(src, c, e.slot)
end

---opts: toSlot, cascade (skip the "required by" refusal; dependants are taken off first anyway)
function Equipment.unequip(src, key, opts)
    opts = opts or {}
    local st = State.get(src)
    if not st then return false, 'player_not_loaded' end
    local cat = BYKEY[key]
    if not cat then return false, 'bad_category' end
    local ec = Containers.get(equipIdOf(st.charId), { create = true })
    local pc = Containers.get(playerIdOf(st.charId), { create = true })
    local e = ec.stacks[cat.order]
    if not e then return false, 'no_item' end
    rules()
    local deps = {}
    for _, dk in ipairs(dependants[key] or {}) do
        if ec.stacks[BYKEY[dk].order] then deps[#deps + 1] = dk end
    end
    if #deps > 0 and not opts.cascade and not CC().cascadeUnequip then return false, 'clothing_required_by' end
    local ctx = { src = src, reason = 'unequip', cascade = true, from = ec.id, to = pc.id }
    local undoCtx = { src = src, reason = 'equip', cascade = true, from = pc.id, to = ec.id }
    local moved = {}
    for _, dk in ipairs(deps) do
        local d = ec.stacks[BYKEY[dk].order]
        local item, mkey, meta = d.item, d.key, Util.deepcopy(d.metadata)
        local ok, err = Inv.move(ec, BYKEY[dk].order, pc, nil, 1, ctx)
        if not ok then moveBack(ec, pc, moved, undoCtx) return false, err end
        moved[#moved + 1] = { item = item, key = mkey, order = BYKEY[dk].order }
        log('clothing_unequip', src, st.charId, ec.id, pc.id, item, meta)
    end
    local item, meta = e.item, Util.deepcopy(e.metadata)
    local toSlot = Util.toInt(opts.toSlot)
    if toSlot and (toSlot < 1 or toSlot > pc.slots or pc.stacks[toSlot]) then toSlot = nil end
    local ok, err = Inv.move(ec, cat.order, pc, toSlot, 1, ctx)
    if not ok then moveBack(ec, pc, moved, undoCtx) return false, err end
    log('clothing_unequip', src, st.charId, ec.id, pc.id, item, meta)
    return true
end

-- ------------------------------------------------------------
-- creation (shops, tailors, admin)
-- ------------------------------------------------------------
---Validate a spec -> metadata. Returns ok, meta|err. opts.trusted only from inside the resource.
function Equipment.build(spec, opts)
    local meta, err = ClothingMeta.build(spec, opts)
    if not meta then return false, err end
    return true, meta
end

function Equipment.create(target, spec, count, ctx, opts)
    local ok, meta = Equipment.build(spec, opts)
    if not ok then return false, meta end
    local cat = BYKEY[meta.category]
    return Inv.add(target, cat.item, count or 1, meta, ctx or { reason = 'api' })
end

-- ------------------------------------------------------------
-- actions, usables, exports
-- ------------------------------------------------------------
function Equipment.notifyErr(src, err)
    local m = MSG[err]
    if m and src then Sync.notify(src, m, 'error') end
end

local function registerActions()
    Actions.register('equip', function(src, d)
        local c, err = Actions.ref(src, d.container or 'player')
        if not c then return false, err end
        local ok, e2 = Equipment.equip(src, c, Util.toInt(d.slot) or -1)
        if not ok then Equipment.notifyErr(src, e2) end
        return ok, e2
    end)
    Actions.register('unequip', function(src, d)
        local key = d.key
        if not key and d.slot then local cat = ClothingCategories[Util.toInt(d.slot) or -1]; key = cat and cat.key end
        local ok, err = Equipment.unequip(src, key, { toSlot = d.toSlot })
        if not ok then Equipment.notifyErr(src, err) end
        return ok, err
    end)
    Actions.register('clothingCatalog', function(src, d)
        return true, ClothingCat.list(d.category, d.gender)
    end)
end

local function registerUsables()
    local res = GetCurrentResourceName()
    for _, cat in ipairs(ClothingCategories) do
        Usables.register(cat.item, function(data)
            local ok, err = Equipment.equipStack(data.source, data.item.id)
            if not ok then Equipment.notifyErr(data.source, err) end
        end, res)
    end
end

local API = {}
function API.BuildClothingMetadata(spec) return Equipment.build(spec) end
local function trustedCaller(res)
    for _, r in ipairs((Config.Clothing or {}).trustedResources or {}) do if r == res then return true end end
    return false
end

function API.CreateClothingItem(target, spec, count)
    InvDB.awaitReady()
    local res = GetInvokingResource()
    return Equipment.create(target, spec, count, { reason = 'shop', resource = res }, trustedCaller(res) and { trusted = true } or nil)
end
function API.GetClothingCatalog(key, gender)
    if key == nil then
        local out = {}
        for _, c in ipairs(ClothingCategories) do
            out[#out + 1] = { key = c.key, label = c.label, panel = c.panel, item = c.item,
                              male = #ClothingCat.list(c.key, 'male'), female = #ClothingCat.list(c.key, 'female') }
        end
        return out
    end
    return ClothingCat.list(key, gender)
end
function API.GetClothingCategories() return Util.deepcopy(ClothingCategories) end
function API.EquipClothing(src, stackId) InvDB.awaitReady() return Equipment.equipStack(tonumber(src), stackId) end
function API.UnequipClothing(src, key, toSlot) InvDB.awaitReady() return Equipment.unequip(tonumber(src), key, { toSlot = toSlot }) end
function API.GetWorn(charId) InvDB.awaitReady() return Equipment.worn(charId) end
function API.ReapplyClothing(src) return Equipment.push(tonumber(src), 'reapply') end
Equipment.API = API

if CC().enabled ~= false then
    registerHooks()
    registerActions()
    registerUsables()
    for name, fn in pairs(API) do exports(name, fn) end
end
