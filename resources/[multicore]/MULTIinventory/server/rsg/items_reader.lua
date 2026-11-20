-- ============================================================
-- MULTIinventory :: server/rsg/items_reader.lua
--
-- Reader for RSG-Core item definitions (rsg-core shared/items.lua and the live
-- RSGCore.Shared.Items table). FORMAT READER ONLY: it turns rsg item rows into RINGO
-- definitions and reports format problems. It never writes to a database.
-- Pure Lua 5.4, no FXServer calls: loaded by the server (fxmanifest, before rsg_api.lua)
-- and by the offline tools/rsg_items.lua + tests/rsg_harness.lua.
--
--   RsgItems.parse(text, chunkname?)  -> items | nil, err
--       runs the data file in an empty sandbox (only RSGShared / RSGCore / QBShared tables,
--       string/table/math, pairs/ipairs/tostring/tonumber/type/next/select/vector3) with an
--       instruction budget; accepts  RSGShared.Items = {...},  RSGShared.Items['x'] = {...},
--       RSGCore.Shared.Items = {...}  and  return {...}.
--   RsgItems.readFile(path)           -> items | nil, err          (offline tools only: io.open)
--   RsgItems.normalize(key, raw, opts?) -> def | nil, err
--       def = { name, label, weight (kg), weightRaw (rsg units), limit = 0, type = 'item_standard'|
--               'item_weapon', rsgType, usable, unique, shouldClose, combinable, desc, image,
--               category, group, degradation (minutes, rsg `decay`), removeWhenExpired (rsg `delete`),
--               ammotype, metadata (rsg `info` default), canRemove = true, useExpired = false }
--       opts = { weightUnit = 1000, categoryGroups = { [rsgCategory] = groupKey } }
--   RsgItems.normalizeAll(items, opts?) -> { [name] = def }, issues
--   RsgItems.validate(items)          -> issues  { { key, problem }, ... }  (sorted by key)
--   RsgItems.summary(items, opts?)    -> { count, weapons, unique, usable, decaying, categories = {[c]=n} }
--
-- rsg row fields read (rsg-core shared items format, public data):
--   name, label, weight, type ('item' | 'weapon' | 'weapon_thrown' | ...), image, unique,
--   useable, shouldClose, description, category, decay, delete, ammotype, combinable, info
-- ============================================================

RsgItems = RsgItems or {}

local DEFAULT_UNIT = 1000      -- rsg weights are grams
local BUDGET = 5000000         -- VM instructions allowed for one data file

local function isWeaponName(name)
    return type(name) == 'string' and name:upper():sub(1, 7) == 'WEAPON_'
end

local function isWeaponType(t)
    return type(t) == 'string' and t:sub(1, 6) == 'weapon'
end

local function shallow(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = type(v) == 'table' and shallow(v) or v end
    return o
end

-- ------------------------------------------------------------
-- parse
-- ------------------------------------------------------------
local function sandbox()
    local env = {
        pairs = pairs, ipairs = ipairs, next = next, select = select, type = type,
        tostring = tostring, tonumber = tonumber, print = function() end,
        string = { format = string.format, lower = string.lower, upper = string.upper, sub = string.sub,
                   gsub = string.gsub, find = string.find, match = string.match, rep = string.rep, len = string.len },
        table = { insert = table.insert, concat = table.concat, unpack = table.unpack },
        math = { floor = math.floor, ceil = math.ceil, max = math.max, min = math.min, huge = math.huge },
        vector3 = function(x, y, z) return { x = x, y = y, z = z } end,
        vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end,
    }
    env.RSGShared = { Items = {} }
    env.QBShared = env.RSGShared
    env.RSGCore = { Shared = env.RSGShared }
    return env
end

---text -> items table (key = item name as written in the file)
function RsgItems.parse(text, chunkname)
    if type(text) ~= 'string' or text == '' then return nil, 'empty' end
    local env = sandbox()
    local chunk, err = load(text, '=' .. (chunkname or 'items.lua'), 't', env)
    if not chunk then return nil, 'syntax: ' .. tostring(err) end
    local dbg = rawget(_G, 'debug')
    local hooked = dbg and dbg.sethook and dbg.gethook and true or false
    local prevHook, prevMask, prevCount
    if hooked then
        prevHook, prevMask, prevCount = dbg.gethook()
        dbg.sethook(function() error('instruction budget exceeded', 2) end, '', BUDGET)
    end
    local ok, ret = pcall(chunk)
    if hooked then dbg.sethook(prevHook, prevMask or '', prevCount or 0) end
    if not ok then return nil, 'runtime: ' .. tostring(ret) end
    local items
    if type(ret) == 'table' and next(ret) ~= nil then
        items = ret.Items or ret
    elseif type(env.RSGShared.Items) == 'table' and next(env.RSGShared.Items) ~= nil then
        items = env.RSGShared.Items
    elseif type(env.RSGCore.Shared) == 'table' and type(env.RSGCore.Shared.Items) == 'table' then
        items = env.RSGCore.Shared.Items
    elseif type(env.Items) == 'table' then
        items = env.Items
    end
    if type(items) ~= 'table' or next(items) == nil then return nil, 'no items table found' end
    return items
end

---Offline helper (tools/tests). Not used on the server.
function RsgItems.readFile(path)
    local f, err = io.open(path, 'rb')
    if not f then return nil, 'open: ' .. tostring(err) end
    local text = f:read('a')
    f:close()
    return RsgItems.parse(text, path:match('[^/\\]+$'))
end

-- ------------------------------------------------------------
-- normalize
-- ------------------------------------------------------------
function RsgItems.normalize(key, raw, opts)
    if type(raw) ~= 'table' then return nil, 'not a table' end
    opts = opts or {}
    local unit = tonumber(opts.weightUnit) or DEFAULT_UNIT
    if unit <= 0 then unit = DEFAULT_UNIT end
    local name = raw.name or key
    if type(name) ~= 'string' or name == '' then return nil, 'no name' end
    name = name:lower()
    local weapon = isWeaponType(raw.type) or isWeaponName(name)
    local w = tonumber(raw.weight) or 0
    local groups = opts.categoryGroups or {}
    local cat = type(raw.category) == 'string' and raw.category or nil
    return {
        name = name,
        label = (type(raw.label) == 'string' and raw.label ~= '') and raw.label or name,
        weight = w / unit,
        weightRaw = w,
        limit = 0,
        type = weapon and 'item_weapon' or 'item_standard',
        rsgType = type(raw.type) == 'string' and raw.type or 'item',
        usable = raw.useable == true or raw.usable == true,
        unique = raw.unique == true,
        shouldClose = raw.shouldClose,
        combinable = raw.combinable,
        desc = type(raw.description) == 'string' and raw.description or '',
        image = type(raw.image) == 'string' and raw.image ~= '' and raw.image or (name .. '.png'),
        category = cat,
        group = cat and (groups[cat] or cat) or nil,
        degradation = math.max(0, tonumber(raw.decay) or 0),
        removeWhenExpired = raw.delete == true,
        ammotype = raw.ammotype,
        metadata = type(raw.info) == 'table' and shallow(raw.info) or nil,
        canRemove = true,
        useExpired = false,
    }
end

function RsgItems.normalizeAll(items, opts)
    local out, issues = {}, {}
    for key, raw in pairs(items or {}) do
        local d, err = RsgItems.normalize(key, raw, opts)
        if d then
            if out[d.name] then issues[#issues + 1] = { key = tostring(key), problem = 'duplicate name ' .. d.name } end
            out[d.name] = d
        else
            issues[#issues + 1] = { key = tostring(key), problem = err }
        end
    end
    table.sort(issues, function(a, b) return a.key < b.key end)
    return out, issues
end

-- ------------------------------------------------------------
-- validate / summary
-- ------------------------------------------------------------
function RsgItems.validate(items)
    local issues = {}
    local function add(k, p) issues[#issues + 1] = { key = tostring(k), problem = p } end
    for key, raw in pairs(items or {}) do
        if type(raw) ~= 'table' then
            add(key, 'row is not a table')
        else
            if raw.name == nil then add(key, 'missing name')
            elseif type(raw.name) ~= 'string' then add(key, 'name is not a string')
            else
                if type(key) == 'string' and raw.name ~= key then add(key, 'name differs from key: ' .. raw.name) end
                if raw.name ~= raw.name:lower() then add(key, 'name not lower case (rsg looks items up in lower case)') end
            end
            if raw.label == nil or raw.label == '' then add(key, 'missing label') end
            if tonumber(raw.weight) == nil then add(key, 'weight is not a number')
            elseif tonumber(raw.weight) < 0 then add(key, 'negative weight') end
            if raw.image == nil or raw.image == '' then add(key, 'missing image') end
            if raw.type ~= nil and type(raw.type) ~= 'string' then add(key, 'type is not a string') end
            if raw.decay ~= nil and tonumber(raw.decay) == nil then add(key, 'decay is not a number') end
            if isWeaponName(raw.name) and not isWeaponType(raw.type) then add(key, 'weapon_ name with type ' .. tostring(raw.type)) end
            if raw.info ~= nil and type(raw.info) ~= 'table' then add(key, 'info is not a table') end
        end
    end
    table.sort(issues, function(a, b) if a.key ~= b.key then return a.key < b.key end return a.problem < b.problem end)
    return issues
end

function RsgItems.summary(items, opts)
    local s = { count = 0, weapons = 0, unique = 0, usable = 0, decaying = 0, categories = {} }
    for key, raw in pairs(items or {}) do
        local d = RsgItems.normalize(key, raw, opts)
        if d then
            s.count = s.count + 1
            if d.type == 'item_weapon' then s.weapons = s.weapons + 1 end
            if d.unique then s.unique = s.unique + 1 end
            if d.usable then s.usable = s.usable + 1 end
            if d.degradation > 0 then s.decaying = s.decaying + 1 end
            local c = d.category or '(none)'
            s.categories[c] = (s.categories[c] or 0) + 1
        end
    end
    return s
end

return RsgItems
