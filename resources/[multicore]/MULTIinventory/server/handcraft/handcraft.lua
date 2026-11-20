-- ============================================================
-- MULTIinventory :: server/handcraft/handcraft.lua
--
-- Hand crafting from the inventory's Craft tab (Config.HandCraft, config_handcraft.lua).
-- Server authority: the client only names a recipe id and a quantity; the server
-- recomputes the recipe, checks access, the busy lock, rate limit and cooldown,
-- and at the finish takes the ingredients + gives the outputs in one step
-- (HandCraftCore.execute, rolled back on any failure / no room).
--
-- Actions (MULTIinventory:sv:action, client/handcraft.lua):
--   handcraftList   {}                  -> { recipes = { view, ... }, busy }
--   handcraftBegin  { id, qty }         -> { token, duration, anim, label, qty }   (locks the player)
--   handcraftFinish { token }           -> { produced }                             (does the craft)
--   handcraftCancel { token }           -> true
-- Exports: RegisterHandRecipe(id, data) -> ok, err   RemoveHandRecipe(id) -> ok   GetHandRecipes() -> { [id] = recipe }
-- Server event after a craft: MULTIinventory:handCrafted (src, recipeId, qty, produced)
-- Recipes registered by a resource are dropped when that resource stops.
--
-- Workshop (server/workshop/*.lua) plugs in through three hooks below:
--   HandCraft.isLearned(src, recipe) -> bool        recipe.unlock (recipe book) read by this character
--   HandCraft.atStation(src, stationKey) -> bool    recipe.station nearby (spinning wheel, mortar, ...)
--   HandCraft.hasBook(src, counts) -> bool          book mode: the Crafting Journal is carried
-- HandCraft.list(src, { book = true }) also returns locked / away-from-station recipes for the book.
-- ============================================================

HandCraft = HandCraft or {}

local HC = Config.HandCraft or { enabled = false, recipes = {} }
local Core = HandCraftCore

local recipes = {}      -- [id] = normalized recipe (+ owner)
local busy = {}         -- [src] = { token, id, qty, started, duration, coords }
local lastStart = {}    -- [src] = ms
local cooldowns = {}    -- [charId] = { [recipeId] = unix seconds when it ends }
local warnedUnknown = {}
local tokenSeq = 0

if Config.Log and Config.Log.actions and Config.Log.actions.craft == nil then
    Config.Log.actions.craft = HC.log ~= false
end

local function nowMs() return GetGameTimer() end

local function text(key, vars, fallback)
    local s = key
    if L then s = vars and L(key, vars) or L(key) end
    if s == key then
        s = fallback
        if vars then s = s:gsub('{([%w_]+)}', function(k) return vars[k] ~= nil and tostring(vars[k]) or '{' .. k .. '}' end) end
    end
    return s
end

local function defaults()
    return { anim = HC.defaultAnim, maxQuantity = HC.maxQuantity }
end

-- ------------------------------------------------------------
-- registry
-- ------------------------------------------------------------
function HandCraft.register(id, data, owner)
    local r, err = Core.normalize(id, data, defaults())
    if not r then return false, err end
    r.owner = owner or 'config'
    recipes[r.id] = r
    warnedUnknown[r.id] = nil
    return true, r.id
end

function HandCraft.remove(id)
    if type(id) ~= 'string' or not recipes[id] then return false end
    recipes[id] = nil
    return true
end

function HandCraft.get(id) return type(id) == 'string' and recipes[id] or nil end

function HandCraft.all()
    local out = {}
    for id, r in pairs(recipes) do out[id] = Core.copy(r) end
    return out
end

function HandCraft.loadConfig()
    for id, r in pairs(recipes) do if r.owner == 'config' then recipes[id] = nil end end
    local ids = {}
    for id in pairs(HC.recipes or {}) do ids[#ids + 1] = id end
    table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
    for _, id in ipairs(ids) do
        local ok, err = HandCraft.register(id, HC.recipes[id], 'config')
        if not ok then print(('^3[MULTIinventory] hand recipe %s skipped: %s^7'):format(tostring(id), tostring(err))) end
    end
end

-- ------------------------------------------------------------
-- player helpers
-- ------------------------------------------------------------
local function jobOf(src)
    local ok, user = pcall(function() return MBridge.Core.getUser(src) end)
    if not ok or not user then return nil, 0 end
    local ch = user.getUsedCharacter
    if type(ch) == 'function' then ch = ch() end
    if not ch then return nil, 0 end
    return ch.job, tonumber(ch.jobGrade or ch.jobgrade or ch.grade) or 0
end

local function jobAllowed(src, r)
    if not r.jobs then return true end
    local job, grade = jobOf(src)
    if type(job) ~= 'string' then return false end
    for _, j in ipairs(r.jobs) do
        local match
        if j.pattern then
            local ok, res = pcall(string.match, job, j.name)
            match = ok and res ~= nil
        else
            match = job == j.name
        end
        if match and grade >= j.grade then return true end
    end
    return false
end

local function skillAllowed(src, r)
    if not r.skill then return true end
    local sk = HC.skill
    if not (sk and sk.enabled and type(sk.getLevel) == 'function') then return true end   -- skills off: ignore
    local ok, lvl = pcall(sk.getLevel, src, r.skill.name)
    lvl = ok and Core.num(lvl) or 0
    return lvl >= r.skill.level
end

-- carried totals of the player grid (one pass), used for listing and the start check
local function tally(c)
    local t = {}
    for _, e in pairs(c.stacks) do
        if e.kind ~= 'weapon' and e.item then t[e.item] = (t[e.item] or 0) + (tonumber(e.count) or 0) end
    end
    return t
end

-- workshop hooks (overridden by server/workshop/*.lua; safe defaults when it is not loaded)
HandCraft.isLearned = HandCraft.isLearned or function() return true end
HandCraft.atStation = HandCraft.atStation or function() return false end
HandCraft.hasBook = HandCraft.hasBook or function() return true end

local function accessOk(src, r, counts)
    if not r.enabled then return false, 'unknown_recipe' end
    if not jobAllowed(src, r) then return false, 'no_permission' end
    if r.knownItem and (counts[r.knownItem] or 0) < 1 then return false, 'recipe_unknown' end
    if not skillAllowed(src, r) then return false, 'skill_low' end
    if r.unlock and not HandCraft.isLearned(src, r) then return false, 'locked' end
    if r.copyOf then   -- writing a recipe page: only what you know yourself
        local orig = recipes[r.copyOf]
        if not orig or not orig.enabled or not HandCraft.isLearned(src, orig) then return false, 'locked' end
    end
    -- book mode: hand recipes need the journal; station recipes only need the station
    if not r.station and not HandCraft.hasBook(src, counts) then return false, 'no_book' end
    return true
end

local function stationOk(src, r)
    if not r.station then return true end
    return HandCraft.atStation(src, r.station) == true
end

-- every output must be a known item; otherwise the recipe is hidden (warned once)
local function outputsKnown(r)
    for _, o in ipairs(r.outputs) do
        if not Registry.get(o.item) then
            if not warnedUnknown[r.id] then
                warnedUnknown[r.id] = true
                print(('^3[MULTIinventory] hand recipe %s hidden: unknown output item %s^7'):format(r.id, o.item))
            end
            return false
        end
    end
    return true
end

local function cooldownLeft(src, r)
    if (r.cooldown or 0) <= 0 then return 0 end
    local st = State.get(src)
    local cd = st and cooldowns[st.charId]
    local untilT = cd and cd[r.id]
    if not untilT then return 0 end
    return math.max(0, untilT - Util.now())
end

-- most crafts the item limits (items.limit, per inventory) still allow
local function outputCap(r, counts, cap)
    if Config.Stacking and Config.Stacking.limitIsPerStack then return cap end
    for _, o in ipairs(r.outputs) do
        local d = Registry.get(o.item)
        local lim = d and tonumber(d.limit) or 0
        if lim > 0 then
            local consumedSelf = 0
            for _, g in ipairs(r.ingredients) do
                if #g.items == 1 and g.items[1] == o.item then consumedSelf = consumedSelf + g.count end
            end
            local per = o.count - consumedSelf
            if per > 0 then cap = math.min(cap, math.floor(math.max(0, lim - (counts[o.item] or 0)) / per)) end
        end
    end
    return math.max(0, cap)
end

local function labelOf(item)
    local d = Registry.get(item)
    return d and d.label or item
end
local function imageOf(item)
    local d = Registry.get(item)
    return d and d.image or (item .. '.png')
end

local function groupView(g, counts, consumed)
    local have, pick = 0, nil
    local alts = {}
    for _, it in ipairs(g.items) do
        local n = counts[it] or 0
        have = have + n
        if n > 0 and not pick then pick = it end
        alts[#alts + 1] = labelOf(it)
    end
    pick = pick or g.items[1]
    return { name = pick, image = imageOf(pick), label = g.label or labelOf(g.items[1]), alts = alts,
             items = g.items, need = g.count, have = have, kept = not consumed }
end

local function recipeView(src, r, counts)
    local cap = math.min(r.maxQuantity, Core.int(HC.maxQuantity, 1, 100) or 20)
    local countFn = function(it) return counts[it] or 0 end
    local maxIng = Core.maxCraft(r, countFn, cap)
    local maxCraft = outputCap(r, counts, maxIng)
    local _, missing = Core.plan(r, 1, countFn)
    local nMissing = #missing
    local status = nMissing == 0 and (maxCraft > 0 and 'ready' or 'full') or (nMissing == 1 and 'nearly' or 'missing')
    local ings, tools, outs = {}, {}, {}
    for _, g in ipairs(r.ingredients) do ings[#ings + 1] = groupView(g, counts, true) end
    for _, g in ipairs(r.tools) do tools[#tools + 1] = groupView(g, counts, false) end
    for _, o in ipairs(r.outputs) do
        local m = o.metadata or {}
        outs[#outs + 1] = { name = o.item, image = m.image or imageOf(o.item), label = m.label or labelOf(o.item),
                            count = o.count, metadata = o.metadata }
    end
    return {
        id = r.id, label = r.label, description = r.description, category = r.category,
        time = r.time, status = status, missing = nMissing, maxCraft = maxCraft, cooldown = cooldownLeft(src, r),
        ingredients = ings, tools = tools, outputs = outs,
        knownItem = r.knownItem and labelOf(r.knownItem) or nil,
    }
end

local RANK = { ready = 0, full = 1, nearly = 2, missing = 3, station = 4, locked = 5 }

---The page view of one recipe for this player (the book uses it for "write a copy").
function HandCraft.view(src, r, counts)
    if not outputsKnown(r) then return nil end
    local ok = accessOk(src, r, counts)
    if not ok then return nil end
    return recipeView(src, r, counts)
end

-- opts.book = true: the Crafting Journal (locked and away-from-station recipes are listed too,
-- with view.locked / view.atStation; the book draws them as such). Without it (Craft tab) they are left out.
function HandCraft.list(src, opts)
    opts = opts or {}
    local c, err = Actions.ref(src, 'player')
    if not c then return nil, err end
    local counts = tally(c)
    local out = {}
    local decorate = HandCraft.decorateView
    for _, r in pairs(recipes) do
        if not r.hidden and outputsKnown(r) then
            local ok, why = accessOk(src, r, counts)
            local locked = not ok and why == 'locked'
            if ok or (opts.book and locked) then   -- no journal (opened at a station): station recipes only
                local v = recipeView(src, r, counts)
                local here = stationOk(src, r)
                v.locked = locked or nil
                v.station = r.station
                v.atStation = here
                if locked then
                    v.status, v.maxCraft = 'locked', 0
                elseif not here then
                    v.status, v.maxCraft = 'station', 0
                end
                if decorate then decorate(v, r, src, counts, locked) end
                if opts.book or (here and not locked) then
                    if v.status ~= 'missing' or HC.showUnavailable ~= false or opts.book then out[#out + 1] = v end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        local ra, rb = RANK[a.status] or 9, RANK[b.status] or 9
        if ra ~= rb then return ra < rb end
        if a.category ~= b.category then return a.category < b.category end
        return a.label < b.label
    end)
    return out
end

-- ------------------------------------------------------------
-- busy lock
-- ------------------------------------------------------------
local function lockOf(src)
    local b = busy[src]
    if b and nowMs() > b.started + b.duration + (Core.int(HC.lockTimeoutMs, 1000, 600000) or 15000) then
        busy[src] = nil
        b = nil
    end
    return b
end

function HandCraft.isBusy(src) return lockOf(src) ~= nil end

local function pedPos(src)
    local ok, v = pcall(function()
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return nil end
        return GetEntityCoords(ped)
    end)
    if not ok or not v then return nil end
    local x, y, z = Core.num(v.x), Core.num(v.y), Core.num(v.z)
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z }
end

local function dist(a, b)
    if not a or not b then return 0 end   -- position unknown on this server build: do not block
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function readId(v)
    if type(v) ~= 'string' or #v > 64 then return nil end
    return v
end

function HandCraft.begin(src, d)
    if not HC.enabled then return false, 'disabled' end
    local id = readId(d.id)
    local r = id and recipes[id]
    if not r then return false, 'unknown_recipe' end
    if d.qty ~= nil and not Core.num(d.qty) then return false, 'bad_count' end   -- NaN / inf / junk
    local cap = math.min(r.maxQuantity, Core.int(HC.maxQuantity, 1, 100) or 20)
    local qty = Core.int(d.qty or 1, 1, cap)
    if lockOf(src) then return false, 'busy' end
    local t = nowMs()
    local gap = Core.int(HC.minIntervalMs, 0, 60000) or 1500
    if lastStart[src] and t - lastStart[src] < gap then return false, 'rate_limited' end
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    local counts = tally(c)
    local ok
    ok, err = accessOk(src, r, counts)
    if not ok then return false, err end
    if not outputsKnown(r) then return false, 'unknown_recipe' end
    if not stationOk(src, r) then return false, 'station_far' end
    if cooldownLeft(src, r) > 0 then return false, 'cooldown' end
    if not Core.plan(r, qty, function(it) return counts[it] or 0 end) then return false, 'missing' end
    if outputCap(r, counts, qty) < qty then return false, 'limit' end
    if HandCraft.otherBusy and HandCraft.otherBusy(src) then return false, 'busy' end
    lastStart[src] = t
    tokenSeq = tokenSeq + 1
    local token = tokenSeq * 1000 + math.random(0, 999)
    local duration = Core.duration(r, qty, HC)
    busy[src] = { token = token, id = r.id, qty = qty, started = t, duration = duration, coords = pedPos(src) }
    return true, { token = token, duration = duration, anim = r.anim, label = r.label, qty = qty,
                   book = d.book == true or nil, chapter = HandCraft.chapterOf and HandCraft.chapterOf(r) or nil,
                   cancelDistance = Core.num(HC.cancelDistance) or 0.8, animLoadTimeoutMs = Core.int(HC.animLoadTimeoutMs, 100, 10000) or 1500 }
end

function HandCraft.cancel(src, d)
    local b = busy[src]
    if not b then return true end
    local token = Core.int(d and d.token)
    if token ~= b.token then return false, 'bad_token' end
    busy[src] = nil
    return true
end

local function adapterFor(c, ctx)
    return {
        count = function(item) return Inv.count(c, item) end,
        remove = function(item, n) return Inv.remove(c, item, n, nil, ctx) end,
        restore = function(rec)
            return Inv.add(c, rec.item, rec.count, rec.metadata, ctx, { decayAt = rec.decayAt, noDecay = rec.decayAt == nil })
        end,
        add = function(item, n, meta)
            local ok, placed = Inv.add(c, item, n, meta, ctx)
            if not ok then return false, placed end
            return true, { item = item, placed = placed }
        end,
        unadd = function(h)
            for _, p in ipairs(h.placed or {}) do Inv.removeStack(c, p.id, p.count, ctx) end
        end,
        warn = function(msg) print('^1[MULTIinventory] hand craft ' .. tostring(msg) .. '^7') end,
    }
end

function HandCraft.finish(src, d)
    local b = lockOf(src)
    if not b then return false, 'not_busy' end
    local token = Core.int(d and d.token)
    if not token or token ~= b.token then return false, 'bad_token' end
    busy[src] = nil   -- one finish per start, whatever happens next
    local elapsed = nowMs() - b.started
    local ratio = Core.num(HC.minElapsedRatio) or 0.9
    if elapsed < b.duration * ratio then
        print(('^3[MULTIinventory] hand craft from %s finished early (%d of %d ms)^7'):format(tostring(src), elapsed, b.duration))
        return false, 'too_fast'
    end
    if dist(pedPos(src), b.coords) > (Core.num(HC.maxMoveDistance) or 3.0) then return false, 'moved' end
    local r = recipes[b.id]
    if not r then return false, 'unknown_recipe' end
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    local ok
    ok, err = accessOk(src, r, tally(c))
    if not ok then return false, err end
    if not stationOk(src, r) then return false, 'station_far' end
    if cooldownLeft(src, r) > 0 then return false, 'cooldown' end

    local ctx = { src = src, reason = 'craft', from = c.id, to = c.id, recipe = r.id }
    local res
    ok, res = Core.execute(adapterFor(c, ctx), r, b.qty)
    if not ok then return false, res end

    local st = State.get(src)
    if (r.cooldown or 0) > 0 and st then
        cooldowns[st.charId] = cooldowns[st.charId] or {}
        cooldowns[st.charId][r.id] = Util.now() + r.cooldown
    end
    if HC.log ~= false and InvLog then
        InvLog.write('craft', { actorSrc = src, targetCharId = st and st.charId or nil, from = c.id, to = c.id,
                                item = r.id, count = b.qty,
                                data = { recipe = r.id, consumed = res.consumed, produced = res.produced } })
    end
    local o = res.produced[1]
    local lbl = (o.metadata and o.metadata.label) or labelOf(o.item)
    Sync.notify(src, text('craft_done', { label = lbl, count = o.count }, 'You made {label} x{count}.'), 'success')
    TriggerEvent('MULTIinventory:handCrafted', src, r.id, b.qty, res.produced)
    return true, { produced = res.produced }
end

-- ------------------------------------------------------------
-- actions + messages
-- ------------------------------------------------------------
local REASON = {
    missing = 'You are missing something for that.', no_room = 'You have no room to carry the result.',
    limit = 'You cannot carry more of that.', busy = 'You are already making something.',
    cooldown = 'You need a moment before making that again.', moved = 'You moved away; the work is spoiled.',
    too_fast = 'That was too quick.', no_permission = 'You do not know how to make that.',
    recipe_unknown = 'You do not know how to make that.', skill_low = 'You are not skilled enough for that.',
    unknown_recipe = 'That cannot be made.', disabled = 'Hand crafting is not available.',
    locked = 'You have not learned that yet.', station_far = 'You need to be at the right station for that.',
    no_book = 'You need your Crafting Journal for that.',
}
HandCraft.REASON = REASON

local function wrap(fn, notifyErr)
    return function(src, d)
        if not HC.enabled then return false, 'disabled' end
        local ok, res = fn(src, d or {})
        if not ok and notifyErr and REASON[res] then
            Sync.notify(src, text('craft_err_' .. tostring(res), nil, REASON[res]), 'error')
        end
        return ok, res
    end
end

Actions.register('handcraftList', wrap(function(src, d)
    local list, err = HandCraft.list(src, { book = d.book == true })
    if not list then return false, err end
    return true, { recipes = list, busy = HandCraft.isBusy(src) }
end, false))
Actions.register('handcraftBegin', wrap(HandCraft.begin, false))     -- the NUI shows begin errors itself
Actions.register('handcraftFinish', wrap(HandCraft.finish, true))    -- the inventory is closed by then
Actions.register('handcraftCancel', wrap(HandCraft.cancel, false))

-- NUI: tell the page the Craft tab exists
InvHooks.register('openPayload', function(src, payload)
    payload.config = payload.config or {}
    local tab = HC.enabled and not (Config.CraftBook and Config.CraftBook.mode == 'book')
    payload.config.handcraft = tab and { enabled = true, maxQuantity = HC.maxQuantity } or false
end)

-- ------------------------------------------------------------
-- exports
-- ------------------------------------------------------------
exports('RegisterHandRecipe', function(id, data)
    return HandCraft.register(id, data, GetInvokingResource() or GetCurrentResourceName())
end)
exports('RemoveHandRecipe', function(id) return HandCraft.remove(id) end)
exports('GetHandRecipes', function() return HandCraft.all() end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then return end
    for id, r in pairs(recipes) do
        if r.owner == res then recipes[id] = nil end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    busy[src] = nil
    lastStart[src] = nil
end)

HandCraft.loadConfig()
HandCraft._busy = busy   -- tests
