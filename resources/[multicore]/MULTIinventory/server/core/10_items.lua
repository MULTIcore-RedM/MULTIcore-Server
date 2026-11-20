-- ============================================================
-- MULTIinventory :: item registry (server)
-- One list for both faces:
--   1. RSGCore.Shared.Items (MULTIcore shared/items.lua)
--   2. the VORP `items` table, when it exists (columns read defensively)
--   3. every weapon in MULTIInvData.Weapons and every ammo round item (generated if missing)
-- Same name in RSG and VORP = one item: RSG's label / image / weight win, VORP's
-- limit / can_remove / desc / usable are kept.
-- Items made here that RSG does not know are added to RSGCore.Shared.Items
-- (exports['rsg-core']:AddItems), so RSG scripts and clients see them too.
-- ============================================================

local Inv = MULTIInv

local vorpRows = {}      -- name -> parsed VORP row (kept so a reload of RSG items can re-merge)
local runtime = {}       -- name -> definition registered at runtime through RegisterItem

local function pretty(name)
    local s = name:lower():gsub('^weapon_', ''):gsub('^ammo_', ''):gsub('_', ' ')
    return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end

--- Turns any item shape into the registry definition (keeps RSG's keys, adds the engine's).
local function normalize(def, name)
    local d = {}
    for k, v in pairs(def) do d[k] = v end
    d.name = (d.name or name):lower()
    d.label = d.label or pretty(d.name)
    d.weight = tonumber(d.weight) or 0
    d.type = d.type or 'item'
    d.image = d.image or (d.name .. '.png')
    if d.useable == nil then d.useable = d.usable end
    d.usable = d.useable and true or false
    d.useable = d.usable
    d.unique = d.unique and true or false
    if d.shouldClose == nil then d.shouldClose = true end
    d.description = d.description or d.desc or ''
    d.desc = d.description
    d.limit = tonumber(d.limit) or 0
    if d.canRemove == nil then d.canRemove = true end
    d.metadata = type(d.metadata) == 'table' and d.metadata or {}
    local w = MULTIInvData.Weapons[d.name]
    if w then
        d.type = 'weapon'
        d.unique = not w.thrown
        d.ammotype = d.ammotype or w.ammoType
    end
    local ammo = MULTIInvData.AmmoItems[d.name]
    if ammo and not w then d.ammoType = ammo end
    return d
end

--- RSG item shape (what RSGCore.Shared.Items holds) for a definition.
function Inv.ToRsgItem(d)
    return {
        name = d.name, label = d.label, weight = d.weight, type = d.type, image = d.image,
        unique = d.unique, useable = d.useable, shouldClose = d.shouldClose,
        description = d.description, combinable = d.combinable, decay = d.decay, delete = d.delete,
        ammotype = d.ammotype, category = d.category,
    }
end

-- VORP's `items` table: made on start in VORP's column set, so VORP item install SQL
-- (INSERT IGNORE INTO items (item, label, limit, can_remove, type, usable, desc, weight, groupId, rarityId, metadata))
-- works on any MULTIcore server. Weight is kilograms there.
local ITEMS_TABLE = [[CREATE TABLE IF NOT EXISTS `items` (
  `item` VARCHAR(50) NOT NULL,
  `label` VARCHAR(50) NOT NULL,
  `limit` INT NOT NULL DEFAULT 1,
  `can_remove` TINYINT(1) NOT NULL DEFAULT 1,
  `type` VARCHAR(50) NULL DEFAULT 'item_standard',
  `usable` TINYINT(1) NULL DEFAULT 0,
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `groupId` INT UNSIGNED NOT NULL DEFAULT 1,
  `rarityId` INT NOT NULL DEFAULT 1,
  `metadata` LONGTEXT NULL,
  `desc` VARCHAR(5550) NOT NULL DEFAULT '',
  `weight` FLOAT NOT NULL DEFAULT 0.25,
  PRIMARY KEY (`item`),
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local cols   -- lower-case column name -> real name (nil until read)

local function readColumns()
    if not Config.VorpItems.Enabled then return false end
    pcall(MySQL.query.await, ITEMS_TABLE)
    local ok, list = pcall(MySQL.query.await, "SHOW COLUMNS FROM `items`")
    if not ok or type(list) ~= 'table' or #list == 0 then return false end
    cols = {}
    for _, c in ipairs(list) do cols[(c.Field or c.field or ''):lower()] = c.Field or c.field end
    if not cols.item then cols = nil end
    return cols ~= nil
end

local function parseRow(r)
    local has = cols
    local name = r[has.item]
    if type(name) ~= 'string' or name == '' then return nil end
    local mult = Config.VorpItems.WeightUnit == 'kg' and 1000 or 1
    local meta = has.metadata and r[has.metadata]
    if type(meta) == 'string' then meta = json.decode(meta) end
    local vtype = has.type and tostring(r[has.type] or '') or ''
    local usable = has.usable and r[has.usable]
    return {
        name = name:lower(),
        label = has.label and r[has.label] or nil,
        limit = has.limit and tonumber(r[has.limit]) or 0,
        canRemove = not (has.can_remove and (r[has.can_remove] == 0 or r[has.can_remove] == false)),
        desc = has.desc and r[has.desc] or nil,
        usable = usable == 1 or usable == true,
        weight = has.weight and tonumber(r[has.weight]) and math.floor(tonumber(r[has.weight]) * mult + 0.5) or nil,
        vorpType = vtype,
        type = vtype:find('weapon') and 'weapon' or 'item',
        metadata = type(meta) == 'table' and meta or {},
    }
end

local function readVorpItems()
    if not cols and not readColumns() then return end
    local rows = MySQL.query.await('SELECT * FROM `items`') or {}
    for _, r in ipairs(rows) do
        local v = parseRow(r)
        if v then vorpRows[v.name] = v end
    end
    Inv.Debug(('%d VORP items read'):format(#rows))
end

--- Builds the whole registry. Returns the definitions RSG does not know yet.
local function build()
    local core = Inv.Core(true)
    local rsg = core.Shared.Items or {}
    local items, missing = {}, {}

    for name, def in pairs(rsg) do
        if type(def) == 'table' then items[name:lower()] = normalize(def, name) end
    end

    -- VORP rows: merge onto RSG items or add new ones
    for name, v in pairs(vorpRows) do
        local d = items[name]
        if d then
            d.limit = v.limit
            d.canRemove = v.canRemove
            if v.desc and v.desc ~= '' then d.description = v.desc; d.desc = v.desc end
            d.usable = d.usable or v.usable
            d.useable = d.usable
            d.metadata = v.metadata
        else
            items[name] = normalize(v, name)
            missing[name] = items[name]
        end
    end

    -- every weapon is an item
    local rsgWeapons = core.Shared.Weapons or {}
    for name, w in pairs(MULTIInvData.Weapons) do
        if not items[name] then
            local label
            for _, rw in pairs(rsgWeapons) do
                if type(rw) == 'table' and rw.name == name then label = rw.label break end
            end
            items[name] = normalize({
                name = name, label = label or pretty(name), weight = w.weight, type = 'weapon',
                unique = not w.thrown, useable = true, shouldClose = true,
                description = '', category = 'weapons',
            }, name)
            missing[name] = items[name]
        end
    end

    -- every ammo type has a round item
    for ammoName, a in pairs(MULTIInvData.Ammo) do
        if not items[a.item] then
            items[a.item] = normalize({
                name = a.item, label = _L('ammo_label', pretty(ammoName)), weight = Config.Ammo.RoundWeight,
                type = 'ammo', unique = false, useable = false, shouldClose = false,
                description = _L('ammo_desc', pretty(ammoName)), category = 'ammo',
            }, a.item)
            missing[a.item] = items[a.item]
        end
    end

    for name, d in pairs(runtime) do
        items[name] = d
        if not rsg[name] then missing[name] = d end
    end

    -- ammo: def.ammotype / def.ammoPer on every item that holds ammo (read by the client and the VORP face)
    MULTIInvData.AmmoBoxes = {}
    local ammoItems = {}
    for box, v in pairs(Config.Ammo.Boxes or {}) do
        local d = items[box]
        if d and MULTIInvData.Ammo[v[1]] then
            local rounds = tonumber(v[2]) or MULTIInvData.Ammo[v[1]].refill
            MULTIInvData.AmmoBoxes[box] = { ammo = v[1], rounds = rounds }
            d.ammotype, d.ammoPer = v[1], rounds
            ammoItems[box] = v[1]
        end
    end
    for ammoName, a in pairs(MULTIInvData.Ammo) do
        local d = items[a.item]
        if d then
            d.ammoPer = 1
            if not MULTIInvData.Weapons[a.item] then
                d.ammotype = ammoName
                ammoItems[a.item] = ammoName
            end
        end
    end
    for extra, t in pairs(Config.Vorp and Config.Vorp.AmmoItems or {}) do
        if items[extra] and MULTIInvData.Ammo[t] then
            items[extra].ammotype = items[extra].ammotype or t
            items[extra].ammoPer = items[extra].ammoPer or 1
            ammoItems[extra] = t
        end
    end
    Inv.AmmoItems = ammoItems

    Inv.Items = items
    return missing
end

local pushing = false
local function pushToRsg(missing)
    if not next(missing) then return end
    local known = Inv.Core().Shared.Items or {}
    local out, any = {}, false
    pushing = true
    for name, d in pairs(missing) do
        if known[name] then
            pcall(function() return exports['rsg-core']:UpdateItem(name, Inv.ToRsgItem(d)) end)
        else
            out[name] = Inv.ToRsgItem(d)
            any = true
        end
    end
    local ok, err = true, nil
    if any then ok, err = pcall(function() return exports['rsg-core']:AddItems(out) end) end
    pushing = false
    if not ok then print('^3[MULTIinventory] could not add items to RSGCore.Shared.Items: ' .. tostring(err) .. '^7') end
    Inv.Core(true)
end

--- (Re)loads the registry. Called on start and when RSG's shared items change.
function Inv.LoadItems(readVorp)
    if readVorp then readVorpItems() end
    local missing = build()
    pushToRsg(missing)
    local n = 0
    for _ in pairs(Inv.Items) do n = n + 1 end
    Inv.Debug(('%d items in the registry'):format(n))
    TriggerEvent('MULTIinventory:itemsLoaded')
end

-- RSG items added or changed at runtime (exports['rsg-core']:AddItem / UpdateItem ...)
local pending = false
AddEventHandler('RSGCore:Server:UpdateObject', function()
    if pushing or pending or not Inv.ready then return end
    pending = true
    SetTimeout(250, function()
        pending = false
        build()
    end)
end)

--- Item definition (nil when unknown).
function Inv.GetItemDef(name)
    if type(name) ~= 'string' then return nil end
    name = name:lower()
    return Inv.Items[name] or Inv.LookupVorpItem(name)
end

-- Scripts INSERT IGNORE their items into `items` at runtime: an unknown name is looked up there
-- (at most once per name every 30 s), and the whole table is re-read every few minutes.
local lastLookup = {}
function Inv.LookupVorpItem(name)
    if not Inv.ready or not cols or type(name) ~= 'string' or #name > 50 then return nil end
    local now = os.time()
    if lastLookup[name] and now - lastLookup[name] < 30 then return nil end
    lastLookup[name] = now
    local ok, row = pcall(MySQL.single.await, ('SELECT * FROM `items` WHERE `%s` = ? LIMIT 1'):format(cols.item), { name })
    if not ok or not row then return nil end
    local v = parseRow(row)
    if not v then return nil end
    vorpRows[v.name] = v
    local d = normalize(v, v.name)
    Inv.Items[d.name] = d
    pushToRsg({ [d.name] = d })
    Inv.Debug('item found in `items` at runtime: ' .. d.name)
    return d
end

function Inv.ReloadVorpItems()
    if not Config.VorpItems.Enabled then return end
    readVorpItems()
    local missing = build()
    local fresh = {}
    for n, d in pairs(missing) do if not (Inv.Core().Shared.Items or {})[n] then fresh[n] = d end end
    pushToRsg(fresh)
end

CreateThread(function()
    while true do
        Wait(math.max(1, tonumber(Config.VorpItems.RefreshMinutes) or 5) * 60000)
        if Inv.ready and Config.VorpItems.Enabled and (tonumber(Config.VorpItems.RefreshMinutes) or 5) > 0 then
            Inv.ReloadVorpItems()
        end
    end
end)

--- Registers (or replaces) an item at runtime. def uses RSG or engine keys.
function Inv.RegisterItem(def)
    if type(def) ~= 'table' or type(def.name) ~= 'string' then return false end
    local d = normalize(def, def.name)
    runtime[d.name] = d
    Inv.Items[d.name] = d
    pushToRsg({ [d.name] = d })
    return true
end
