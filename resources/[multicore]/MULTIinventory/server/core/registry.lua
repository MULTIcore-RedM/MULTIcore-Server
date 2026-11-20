-- ============================================================
-- MULTIinventory :: server/core/registry.lua
--
-- Item definitions, read-only from the shared `items` table (RINGObridge and
-- other resources keep inserting there) + multiinv_item_ext overrides +
-- the item_group / item_rarity lookups.
--
--   Registry.reload()                 full reload (start, RINGObridge restart, /invreload)
--   Registry.get(name) -> def|nil     a miss triggers one throttled single-row lookup
--   Registry.all() -> { [name] = def }
--   Registry.groups() -> { { id, key, label, parent, hidden }, ... }   UI filter tabs
--   Registry.put(def)                 inject a definition (tests / other parts)
--   Registry.refresh(name) -> def|nil re-read ONE item from `items` now (live add / edit by another
--                                     resource, e.g. RINGOjobtools); a row that is gone is dropped
--   Registry.forget(name) -> bool     drop one cached definition (row deleted elsewhere)
--   Registry.setImage(name, src|nil)  live picture override (https:// / nui:// URL), in memory only;
--                                     reaches the NUI through def.image (Sync puts it on every stack view)
--   Registry.imageOverrides() -> { [name] = src }
--
-- def = { name, label, weight, limit, canRemove, type, usable, useExpired, group (key),
--         groupId, rarity (1-5), rarityName, metadata (table), desc, degradation (minutes),
--         durability, instructions, image, category, clothingKey, hotbar }
-- ============================================================

Registry = Registry or {}

local defs, groups, groupsById, rarities = {}, {}, {}, {}
local missAt = {}
local MISS_RETRY = 30
local imageOverride = {} -- [name] = src (Registry.setImage)

local function titleCase(s)
    return (tostring(s):gsub('_', ' '):gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end

local function buildDef(r, ext)
    local name = r.item
    local meta = Util.jsonDecode(r.metadata, {})
    if type(meta) ~= 'table' then meta = {} end
    local g = groupsById[tonumber(r.groupId) or 1]
    local rar = rarities[tonumber(r.rarityId) or 1]
    ext = ext or {}
    local d = {
        name        = name,
        label       = r.label or name,
        weight      = tonumber(r.weight) or 0.0,
        limit       = tonumber(r.limit) or 0,
        canRemove   = r.can_remove == nil and true or Util.tbool(r.can_remove),
        type        = r.type or 'item_standard',
        usable      = Util.tbool(r.usable),
        useExpired  = Util.tbool(r.useExpired),
        groupId     = tonumber(r.groupId) or 1,
        group       = g and g.key or 'default',
        rarity      = tonumber(r.rarityId) or 1,
        rarityName  = rar or 'Common',
        metadata    = meta,
        desc        = r.desc or '',
        degradation = tonumber(r.degradation) or 0,
        durability  = tonumber(r.durability),
        instructions = r.instructions,
        image       = imageOverride[name] or ext.image or (name .. '.png'),
        category    = ext.category,
        clothingKey = ext.clothing_key,
        hotbar      = ext.hotbar == nil and true or Util.tbool(ext.hotbar),
    }
    -- money items (server/core/money.lua): no carry limit, not usable, weight from Config.Money
    if Money and Money.patchDef then Money.patchDef(d) end
    return d
end

local function loadLookups()
    groups, groupsById, rarities = {}, {}, {}
    local labels = Config.Groups and Config.Groups.labels or {}
    local parents = Config.Groups and Config.Groups.parents or {}
    local hidden = Config.Groups and Config.Groups.hidden or {}
    for _, r in ipairs(InvDB.query('SELECT `id`, `description` FROM `item_group` ORDER BY `id`')) do
        local key = tostring(r.description or ('group' .. r.id))
        local g = { id = tonumber(r.id), key = key, label = labels[key] or titleCase(key),
                    parent = parents[key], hidden = hidden[key] and true or false }
        groups[#groups + 1] = g
        groupsById[g.id] = g
    end
    for _, r in ipairs(InvDB.query('SELECT `id`, `name` FROM `item_rarity`')) do
        rarities[tonumber(r.id)] = r.name
    end
end

local function loadExt()
    local ext = {}
    for _, r in ipairs(InvDB.query('SELECT * FROM `multiinv_item_ext`')) do ext[r.item] = r end
    return ext
end

function Registry.reload()
    loadLookups()
    local ext = loadExt()
    local n, fresh = 0, {}
    for _, r in ipairs(InvDB.query('SELECT * FROM `items`')) do
        if r.item then
            fresh[r.item] = buildDef(r, ext[r.item])
            n = n + 1
        end
    end
    -- keep injected defs (Registry.put) that the table does not have
    for k, d in pairs(defs) do if d._injected and not fresh[k] then fresh[k] = d end end
    defs = fresh
    missAt = {}
    print(('[MULTIinventory] item registry: %d items, %d groups'):format(n, #groups))
    return n
end

function Registry.get(name)
    if type(name) ~= 'string' or name == '' then return nil end
    local d = defs[name]
    if d then return d end
    -- unknown: maybe RINGObridge inserted it after our load. One lookup per MISS_RETRY s.
    local now = Util.now()
    if missAt[name] and now - missAt[name] < MISS_RETRY then return nil end
    missAt[name] = now
    local rows = InvDB.query('SELECT * FROM `items` WHERE `item` = ?', { name })
    if rows[1] then
        local extRows = InvDB.query('SELECT * FROM `multiinv_item_ext` WHERE `item` = ?', { name })
        d = buildDef(rows[1], extRows[1])
        defs[name] = d
        missAt[name] = nil
        return d
    end
    return nil
end

function Registry.all() return defs end
function Registry.groups() return groups end

function Registry.put(def)
    assert(def and def.name, 'def.name')
    local d = buildDef({ item = def.name, label = def.label, weight = def.weight, limit = def.limit,
        can_remove = def.canRemove == false and 0 or 1, type = def.type, usable = def.usable and 1 or 0,
        useExpired = def.useExpired and 1 or 0, groupId = def.groupId, rarityId = def.rarity,
        metadata = def.metadata, desc = def.desc, degradation = def.degradation, durability = def.durability },
        { image = def.image, category = def.category, clothing_key = def.clothingKey })
    d._injected = true
    defs[def.name] = d
    return d
end

---Re-read one item from `items` (+ ext) right now. Used when another resource inserted or
---edited that row while we run. A row that no longer exists is dropped (injected defs stay).
function Registry.refresh(name)
    if type(name) ~= 'string' or name == '' then return nil end
    missAt[name] = nil
    local rows = InvDB.query('SELECT * FROM `items` WHERE `item` = ?', { name })
    if rows[1] then
        local extRows = InvDB.query('SELECT * FROM `multiinv_item_ext` WHERE `item` = ?', { name })
        local d = buildDef(rows[1], extRows[1])
        defs[name] = d
        return d
    end
    if defs[name] and not defs[name]._injected then defs[name] = nil end
    return defs[name]
end

function Registry.forget(name)
    if type(name) ~= 'string' or not defs[name] or defs[name]._injected then return false end
    defs[name] = nil
    missAt[name] = nil
    return true
end

---Live picture override. src must be an absolute https:// or nui:// URL; nil clears it.
function Registry.setImage(name, src)
    if type(name) ~= 'string' or name == '' then return false end
    if src ~= nil and (type(src) ~= 'string' or #src > 512 or not (src:match('^https://[%w%.%-]+[:%d]*/[%w%-%._~/%%]+$')
        or src:match('^nui://[%w_%-]+/[%w%-%._/]+$') or src:match('^http://[%w%.%-]+:?%d*/[%w%-%._~/%%]+$'))) then
        return false
    end
    imageOverride[name] = src
    if defs[name] then defs[name].image = src or (name .. '.png') end
    return true
end

function Registry.imageOverrides()
    local out = {}
    for k, v in pairs(imageOverride) do out[k] = v end
    return out
end

-- RINGObridge inserts items on its own start; reload shortly after it (re)starts.
AddEventHandler('onResourceStart', function(res)
    if res == 'RINGObridge' and InvDB.ready() then
        SetTimeout(5000, function() Registry.reload() end)
    end
end)
