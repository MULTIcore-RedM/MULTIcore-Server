-- ============================================================
-- MULTIinventory :: server/handcraft/core.lua
--
-- Pure crafting logic (no FiveM calls, no globals besides HandCraftCore), so the
-- offline test (tests/handcraft_harness.lua) can drive it with a fake inventory.
--
--   HandCraftCore.num(v) -> finite number | nil           (NaN / +-inf / junk -> nil)
--   HandCraftCore.int(v, lo, hi) -> integer clamped | nil  (nil only when v is not a finite number)
--   HandCraftCore.normalize(id, data, defaults) -> recipe | nil, err
--   HandCraftCore.plan(recipe, qty, countFn) -> take | nil, missing
--       take    = { { item, count }, ... }    ingredients to remove for qty crafts
--       missing = { { kind = 'ingredient'|'tool', index, short }, ... }
--   HandCraftCore.maxCraft(recipe, countFn, cap) -> n
--   HandCraftCore.duration(recipe, qty, cfg) -> ms
--   HandCraftCore.execute(adapter, recipe, qty) -> ok, err|result
--       adapter.count(item) -> n
--       adapter.remove(item, n) -> ok, records|err      records = { { item, count, metadata, decayAt }, ... }
--       adapter.restore(record) -> ok                    put a removed record back (rollback)
--       adapter.add(item, n, metadata) -> ok, handle|err
--       adapter.unadd(handle)                            take an added output back (rollback)
--       adapter.warn(msg)                                optional
-- ============================================================

HandCraftCore = HandCraftCore or {}
local M = HandCraftCore

local HUGE = math.huge

function M.num(v)
    v = tonumber(v)
    if v == nil or v ~= v or v == HUGE or v == -HUGE then return nil end
    return v
end

function M.int(v, lo, hi)
    v = M.num(v)
    if not v then return nil end
    v = math.floor(v)
    if lo and v < lo then v = lo end
    if hi and v > hi then v = hi end
    return math.tointeger(v) or v
end

local function str(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('^%s+', ''):gsub('%s+$', '')
    if v == '' then return nil end
    return v:sub(1, max or 64)
end

local function itemName(v)
    v = str(v, 64)
    if not v or not v:match('^[%w_%-%.]+$') then return nil end
    -- weapons are occupants, never ingredients (weapon_repair_kit and other *_kit items are plain items)
    if v:upper():sub(1, 7) == 'WEAPON_' and not v:lower():find('_kit$') then return nil end
    return v
end

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end
M.copy = copy

-- { items = {..}|item = 'x', count, label } | 'x'  ->  { items, count, label }
local function normGroup(g, what)
    if type(g) == 'string' then g = { item = g } end
    if type(g) ~= 'table' then return nil, 'bad_' .. what end
    local list = g.items or g.item or g.name
    if type(list) == 'string' then list = { list } end
    if type(list) ~= 'table' then return nil, 'bad_' .. what end
    local items, seen = {}, {}
    for _, n in ipairs(list) do
        local nm = itemName(n)
        if not nm then return nil, 'bad_' .. what .. '_item' end
        if not seen[nm] then seen[nm] = true; items[#items + 1] = nm end
    end
    if #items == 0 or #items > 8 then return nil, 'bad_' .. what end
    local count = M.int(g.count or g.amount or 1, nil, nil)
    if not count or count < 1 or count > 1000 then return nil, 'bad_' .. what .. '_count' end
    return { items = items, count = count, label = str(g.label, 48) }
end

local function normGroups(list, what, required)
    if list == nil then list = {} end
    if type(list) ~= 'table' then return nil, 'bad_' .. what end
    local out = {}
    for _, g in ipairs(list) do
        local n, err = normGroup(g, what)
        if not n then return nil, err end
        out[#out + 1] = n
    end
    if required and #out == 0 then return nil, 'no_' .. what end
    if #out > 10 then return nil, 'too_many_' .. what end
    -- single-choice groups first: they cannot use an alternative, so they claim their item first
    local idx = {}
    for i, g in ipairs(out) do idx[g] = i end
    table.sort(out, function(a, b)
        if #a.items ~= #b.items then return #a.items < #b.items end
        return idx[a] < idx[b]
    end)
    return out
end

local function normAnim(a, default)
    if a == false then return false end
    if a == nil then a = default end
    if type(a) ~= 'table' then return false end
    local scen = str(a.scenario, 96)
    if scen then
        if not scen:match('^[%w_]+$') then return false end
        return { scenario = scen }
    end
    local dict, clip = str(a.dict, 128), str(a.clip or a.anim or a.name, 128)
    if not dict or not clip or not dict:match('^[%w_@%-/%.]+$') or not clip:match('^[%w_@%-/%.]+$') then return false end
    return { dict = dict, clip = clip, flag = M.int(a.flag, 0, 1048575) or 31 }
end

local function normJobs(j)
    if j == nil then return nil end
    if type(j) == 'string' then j = { j } end
    if type(j) ~= 'table' then return nil, 'bad_jobs' end
    local out = {}
    for k, v in pairs(j) do
        local name, grade
        if type(k) == 'number' then name, grade = str(v, 64), 0
        else name, grade = str(k, 64), M.int(v, 0, 1000) or 0 end
        if not name then return nil, 'bad_jobs' end
        out[#out + 1] = { name = name, grade = grade, pattern = name:sub(1, 1) == '^' }
    end
    if #out == 0 then return nil end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

---Validate + normalise a recipe definition. defaults = { anim, maxQuantity }
function M.normalize(id, data, defaults)
    defaults = defaults or {}
    id = str(id, 64)
    if not id or not id:match('^[%w_%-%.:]+$') then return nil, 'bad_id' end
    if type(data) ~= 'table' then return nil, 'bad_data' end
    local ingredients, err = normGroups(data.ingredients or data.inputs, 'ingredient', true)
    if not ingredients then return nil, err end
    local tools
    tools, err = normGroups(data.tools, 'tool', false)
    if not tools then return nil, err end
    local outputs = {}
    local rawOut = data.outputs or data.output
    if type(rawOut) == 'table' and (rawOut.item or rawOut.name) then rawOut = { rawOut } end
    if type(rawOut) ~= 'table' then return nil, 'no_output' end
    for _, o in ipairs(rawOut) do
        if type(o) == 'string' then o = { item = o } end
        if type(o) ~= 'table' then return nil, 'bad_output' end
        local nm = itemName(o.item or o.name)
        local cnt = M.int(o.count or o.amount or 1, nil, nil)
        if not nm or not cnt or cnt < 1 or cnt > 1000 then return nil, 'bad_output' end
        local meta = o.metadata or o.meta or o.info
        if meta ~= nil and type(meta) ~= 'table' then return nil, 'bad_output_metadata' end
        outputs[#outputs + 1] = { item = nm, count = cnt, metadata = meta and copy(meta) or nil }
    end
    if #outputs == 0 or #outputs > 6 then return nil, 'bad_output' end
    local jobs
    jobs, err = normJobs(data.jobs or data.job)
    if err then return nil, err end
    local skill
    if type(data.skill) == 'table' and str(data.skill.name, 64) then
        skill = { name = str(data.skill.name, 64), level = M.num(data.skill.level) or 0 }
    end
    local maxQ = M.int(defaults.maxQuantity, 1, 100) or 20
    return {
        id = id,
        label = str(data.label, 64) or id,
        description = str(data.description or data.desc, 240),
        category = str(data.category, 32) or 'General',
        ingredients = ingredients,
        tools = tools,
        outputs = outputs,
        time = M.int(data.time or data.duration, 500, 60000) or 5000,
        anim = normAnim(data.anim, defaults.anim),
        jobs = jobs,
        knownItem = data.knownItem ~= nil and itemName(data.knownItem) or nil,
        station = data.station ~= nil and itemName(data.station) or nil,   -- station type key (needs one nearby)
        unlock = data.unlock ~= nil and itemName(data.unlock) or nil,      -- recipe book item that teaches it
        copyOf = data.copyOf ~= nil and str(data.copyOf, 64) or nil,      -- "write a copy" of that recipe (needs it learned)
        copyable = data.copyable ~= false,
        hidden = data.hidden == true or nil,                               -- not listed (copy recipes live on their recipe's page)
        skill = skill,
        cooldown = M.int(data.cooldown, 0, 86400) or 0,
        maxQuantity = M.int(data.maxQuantity, 1, maxQ) or maxQ,
        enabled = data.enabled ~= false,
    }
end

---What qty crafts would take, honouring alternatives and items shared between groups.
---countFn(item) -> carried count. Tools need their count once (not per craft) and are not taken.
function M.plan(recipe, qty, countFn)
    qty = M.int(qty, 1, nil)
    if not qty then return nil, { { kind = 'bad_count' } } end
    local reserved, take, missing = {}, {}, {}
    local function scan(groups, kind, mult)
        for gi, g in ipairs(groups) do
            local left = g.count * mult
            for _, it in ipairs(g.items) do
                if left <= 0 then break end
                local avail = (M.num(countFn(it)) or 0) - (reserved[it] or 0)
                if avail > 0 then
                    local n = math.min(avail, left)
                    n = math.floor(n)
                    if n > 0 then
                        reserved[it] = (reserved[it] or 0) + n
                        if kind == 'ingredient' then take[#take + 1] = { item = it, count = n } end
                        left = left - n
                    end
                end
            end
            if left > 0 then missing[#missing + 1] = { kind = kind, index = gi, short = left } end
        end
    end
    scan(recipe.ingredients, 'ingredient', qty)
    scan(recipe.tools or {}, 'tool', 1)
    if #missing > 0 then return nil, missing end
    -- merge rows for the same item (two groups may both draw on it)
    local merged, byItem = {}, {}
    for _, t in ipairs(take) do
        local m = byItem[t.item]
        if m then m.count = m.count + t.count
        else m = { item = t.item, count = t.count }; byItem[t.item] = m; merged[#merged + 1] = m end
    end
    return merged, {}
end

function M.maxCraft(recipe, countFn, cap)
    cap = M.int(cap or recipe.maxQuantity, 0, 1000) or 0
    local n = 0
    for q = 1, cap do
        if M.plan(recipe, q, countFn) then n = q else break end
    end
    return n
end

function M.duration(recipe, qty, cfg)
    cfg = cfg or {}
    qty = M.int(qty, 1, 1000) or 1
    local t = recipe.time + (qty - 1) * recipe.time * (M.num(cfg.repeatFactor) or 0.6)
    local cap = M.int(cfg.maxDurationMs or 45000, 1000, 600000)
    return math.floor(math.max(500, math.min(t, cap)))
end

local NO_ROOM = { weight = true, slots = true, limit = true, stack_full = true }

---Take the ingredients and give the outputs as one unit; any failure puts everything back.
function M.execute(a, recipe, qty)
    qty = M.int(qty, 1, nil)
    if not qty then return false, 'bad_count' end
    local warn = a.warn or function() end
    local take = M.plan(recipe, qty, a.count)
    if not take then return false, 'missing' end

    local removed = {}
    local function restore()
        for i = #removed, 1, -1 do
            local r = removed[i]
            local ok = a.restore(r)
            if not ok then warn(('rollback: could not return %s x%s'):format(tostring(r.item), tostring(r.count))) end
        end
    end

    for _, t in ipairs(take) do
        local ok, recs = a.remove(t.item, t.count)
        if not ok then
            restore()
            return false, (recs == 'not_enough' or recs == 'no_item') and 'missing' or (recs or 'missing')
        end
        if type(recs) == 'table' then
            for _, r in ipairs(recs) do removed[#removed + 1] = r end
        else
            removed[#removed + 1] = { item = t.item, count = t.count }
        end
    end

    local added, produced = {}, {}
    for _, o in ipairs(recipe.outputs) do
        local n = o.count * qty
        local ok, h = a.add(o.item, n, o.metadata and copy(o.metadata) or nil)
        if not ok then
            for i = #added, 1, -1 do a.unadd(added[i]) end
            restore()
            return false, NO_ROOM[h] and 'no_room' or (h or 'no_room')
        end
        added[#added + 1] = h
        produced[#produced + 1] = { item = o.item, count = n, metadata = o.metadata }
    end
    return true, { consumed = take, produced = produced, removed = removed }
end

return M
