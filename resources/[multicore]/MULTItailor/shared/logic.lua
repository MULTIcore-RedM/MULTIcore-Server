--[[
    TL - pure rules shared by client and server (no natives, no database), covered by
    tests/harness.lua. Server files call these; the client only uses them for display.

    Jobs / shops
      TL.townJobs()                       -> { 'valtailor', ... }
      TL.townLabel(townJob)               -> 'Valentine' | nil
      TL.businessId(townJob)              -> 'tailor_valtailor' | nil
      TL.storageKey(businessId)           -> 'multi_storage_tailor_valtailor'
      TL.roleAt(point, job)               -> 'boss' | 'employee' | nil   job = { name, grade, isboss }
      TL.sanitizePoint(def)               -> point | nil, err    (dynamic-location API input)
      TL.configPoints()                   -> { point, ... }      (Config.Locations when enabled)
    Sewing
      TL.quality(hits, rounds)            -> Config.Sewing.quality row
      TL.checkSession(sess, now, hits)    -> ok, err             (minigame timing / bounds)
    Money
      TL.lineTotal(price, qty)            -> total | nil
      TL.storePrice(line, store)          -> price | nil
      TL.suggestPrice(meta)               -> counter ask for a tailored outfit
      TL.allowedOnCounter(item)           -> boolean
    Clothes stores
      TL.resolveStoreCatalogue()          -> lines, skipped
      TL.stockTake(stock, key, n, now)    -> ok, left
]]
TL = TL or {}

local function T() return Config.Tailor end

-- ---------------------------------------------------------------- jobs / shops
function TL.townJobs()
    local out = {}
    for _, t in ipairs(T().towns or {}) do out[#out + 1] = t.prefix .. T().tradeName end
    return out
end

local function townOf(townJob)
    if type(townJob) ~= 'string' then return nil end
    for _, t in ipairs(T().towns or {}) do
        if townJob == t.prefix .. T().tradeName then return t end
    end
    return nil
end

function TL.townLabel(townJob)
    local t = townOf(townJob)
    return t and t.label or nil
end

function TL.businessId(townJob)
    if type(townJob) ~= 'string' or townJob == '' then return nil end
    return (T().businessPrefix or 'tailor_') .. townJob
end

function TL.storageKey(businessId)
    if not businessId then return nil end
    return 'multi_storage_' .. businessId
end

local function contains(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

---Job access to a shop point. A town tailor job only works at its own town; the global job anywhere.
function TL.roleAt(point, job)
    if type(point) ~= 'table' or type(job) ~= 'table' or type(job.name) ~= 'string' then return nil end
    local name = job.name:lower()
    local jobs = point.jobs
    if type(jobs) ~= 'table' or #jobs == 0 then
        jobs = {}
        for _, j in ipairs(T().globalJobs or {}) do jobs[#jobs + 1] = j end
        if point.townJob then jobs[#jobs + 1] = point.townJob end
    end
    local allowed = (point.townJob ~= nil and name == point.townJob) or contains(jobs, name)
    -- another town's tailor never works here, even if a list names it
    if allowed and point.townJob and name ~= point.townJob and townOf(name) then allowed = false end
    if not allowed then return nil end
    local grade = TU.finite(job.grade) or 0
    if grade < (TU.finite(point.jobGrade) or 0) then return nil end
    if job.isboss == true or grade >= (T().bossGrade or 4) then return 'boss' end
    return 'employee'
end

local KINDS = { craft = true, boss = true, store = true, storage = true }

---RegisterDynamicLocation def (sent by a job placement tool).
function TL.sanitizePoint(def)
    if type(def) ~= 'table' then return nil, 'bad_def' end
    local function str(v, max, pattern)
        if type(v) ~= 'string' then return nil end
        v = v:gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if v == '' or #v > max then return nil end
        if pattern and not v:match(pattern) then return nil end
        return v
    end
    local p = {}
    p.id = str(def.id, 48, '^[%w_%-]+$')
    if not p.id then return nil, 'bad_id' end
    local trade = str(def.trade, 48, '^[%w_%-]+$')
    if trade ~= T().tradeName then return nil, 'unknown_trade' end
    p.trade = trade
    p.kind = def.kind == nil and 'craft' or str(def.kind, 16, '^%a+$')
    if not KINDS[p.kind] then return nil, 'bad_kind' end
    if p.kind == 'craft' then
        local set = def.recipeSet == nil and 'tailor_bench' or str(def.recipeSet, 64, '^[%w_%-]+$')
        if set ~= 'tailor_bench' then return nil, 'unknown_recipe_set' end
        p.recipeSet = set
    end
    local c = def.coords
    if type(c) ~= 'table' and type(c) ~= 'vector3' and type(c) ~= 'vector4' then return nil, 'bad_coords' end
    local x, y, z = TU.finite(c.x or c[1]), TU.finite(c.y or c[2]), TU.finite(c.z or c[3])
    if not x or not y or not z or math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then
        return nil, 'bad_coords'
    end
    p.coords = { x = x, y = y, z = z }
    p.heading = (TU.finite(def.heading) or 0.0) % 360.0
    p.townJob = str(def.townJob, 48, '^[%w_%-]+$')
    if (p.kind == 'boss' or p.kind == 'storage' or p.kind == 'store') and not p.townJob then return nil, 'townjob_required' end
    if type(def.jobs) == 'table' then
        local jobs = {}
        for i = 1, math.min(#def.jobs, 24) do
            local j = str(def.jobs[i], 48, '^[%w_%-]+$')
            if j then jobs[#jobs + 1] = j:lower() end
        end
        if #jobs > 0 then p.jobs = jobs end
    end
    p.jobGrade = TU.int(def.jobGrade, 0, 100) or 0
    p.label = str(def.label, 64)
    if p.label then p.label = p.label:gsub('[<>]', '') end
    p.radius = TU.clamp(def.radius, 0.3, 10.0) or 1.2
    p.businessId = TL.businessId(p.townJob)
    if type(def.access) == 'table' then
        local a = def.access
        local access = { ace = str(a.ace, 64, '^[%w%._%-]+$'), item = str(a.item, 64, '^[%w_%-]+$') }
        access.itemCount = access.item and (TU.int(a.itemCount, 1, 1000) or 1) or nil
        if type(a.players) == 'table' then
            local list = {}
            for i = 1, math.min(#a.players, 32) do
                local id = TU.finite(a.players[i])
                if id and id > 0 and id == math.floor(id) then list[#list + 1] = math.floor(id) end
            end
            if #list > 0 then access.players = list end
        end
        if access.ace or access.item or access.players then p.access = access end
    end
    if p.kind == 'storage' and type(def.storage) == 'table' then
        local s = def.storage
        p.storage = {
            label = str(s.label, 48),
            slots = TU.int(s.slots, 1, 500),
            maxWeight = TU.int(s.maxWeight, 1000, 100000000),
            minGrade = TU.int(s.minGrade, 0, 100),
        }
    end
    if p.kind == 'store' and type(def.shop) == 'table' then
        p.shopLabel = str(def.shop.label, 48)
    end
    return p
end

---Shops from config/locations.lua (Config.UseConfigLocations = true).
function TL.configPoints()
    local out = {}
    if not Config.UseConfigLocations then return out end
    local jobs = {}
    for job in pairs(Config.Locations or {}) do jobs[#jobs + 1] = job end
    table.sort(jobs)
    for _, townJob in ipairs(jobs) do
        local loc = Config.Locations[townJob]
        for _, kind in ipairs({ 'bench', 'counter', 'boss', 'storage' }) do
            local c = loc[kind]
            if c then
                local p = TL.sanitizePoint({
                    id = ('cfg_%s_%s'):format(townJob, kind), trade = T().tradeName,
                    kind = (kind == 'bench' and 'craft') or (kind == 'counter' and 'store') or kind,
                    coords = { x = c.x, y = c.y, z = c.z }, townJob = townJob,
                })
                if p then
                    if kind == 'bench' and type(loc.designer) == 'table' and loc.designer.ped then
                        local d = loc.designer
                        p.designer = { ped = { x = d.ped.x, y = d.ped.y, z = d.ped.z, w = d.ped.w },
                            cam = d.cam and { x = d.cam.x, y = d.cam.y, z = d.cam.z } or nil }
                    end
                    p.blip = kind == 'counter'
                    out[#out + 1] = p
                end
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------- sewing
function TL.quality(hits, rounds)
    local list = Config.Sewing.quality
    rounds = TU.int(rounds, 1, 100) or 1
    hits = TU.int(hits, 0, rounds) or 0
    local share = hits / rounds
    local best = list[1]
    for _, q in ipairs(list) do
        if share + 1e-9 >= (q.min or 0) then best = q end
    end
    return best, share
end

---sess = { rounds, startedAt (ms), expiresAt (ms) }. hits = client-reported list of booleans.
function TL.checkSession(sess, now, hits)
    if type(sess) ~= 'table' then return false, 'no_session' end
    if now > (sess.expiresAt or 0) then return false, 'expired' end
    if type(hits) ~= 'table' or #hits ~= sess.rounds then return false, 'bad_result' end
    for i = 1, #hits do if type(hits[i]) ~= 'boolean' then return false, 'bad_result' end end
    if now - (sess.startedAt or now) < sess.rounds * (Config.Sewing.minMsPerRound or 350) then return false, 'too_fast' end
    local n = 0
    for i = 1, #hits do if hits[i] then n = n + 1 end end
    return true, n
end

-- ---------------------------------------------------------------- money
function TL.lineTotal(price, qty)
    price, qty = TU.money(price), TU.int(qty, 1, 1000)
    if not price or not qty or price < 0 then return nil end
    return TU.money(price * qty)
end

function TL.storePrice(line, store)
    if type(line) ~= 'table' then return nil end
    local base = TU.finite(line.price) or TU.finite((Config.Stores.prices or {})[line.cat])
    if not base or base <= 0 then return nil end
    local mult = (TU.finite(store and store.priceMultiplier) or 1.0) * (TU.finite(Config.Stores.priceMultiplier) or 1.0)
    if mult <= 0 then return nil end
    local price = TU.money(base * mult)
    if not price or price < 0.01 then return nil end
    return price
end

function TL.suggestPrice(meta)
    if type(meta) ~= 'table' then return nil end
    local need
    if type(meta.pieces) == 'table' then need = TS.materialsFor(meta.pieces)
    elseif type(meta.materials) == 'table' then need = meta.materials   -- NPC garments / outfits
    else return nil end
    local prices = Config.Counter.materialPrices or {}
    local cost = 0
    for item, n in pairs(need) do cost = cost + (TU.finite(prices[item]) or 0) * (TU.finite(n) or 0) end
    local q = (Config.Counter.qualityMarkup or {})[meta.quality or 'standard'] or 1.0
    local ask = TU.money(cost * (Config.Counter.suggestedMarkup or 1.4) * q)
    if not ask or ask < (Config.Counter.minPrice or 0.05) then return Config.Counter.minPrice or 0.05 end
    return ask
end

function TL.allowedOnCounter(item)
    if type(item) ~= 'string' then return false end
    for _, pat in ipairs(Config.Counter.allowed or {}) do
        if item:match(pat) then return true end
    end
    return false
end

-- ---------------------------------------------------------------- clothes stores
---Resolve Config.Stores.catalogue against the running clothing catalogue.
---lines = { { id, sex, cat, vorp, label, catLabel, price, colours = { { n, v, hash } } } }
function TL.resolveStoreCatalogue()
    local lines, skipped = {}, {}
    local seen = {}
    for _, l in ipairs(Config.Stores.catalogue or {}) do
        local sex = TS.sexOf(l.sex)
        local c = TS.category(l.cat)
        local why
        if type(l.id) ~= 'string' or seen[l.id] then why = 'duplicate or missing id'
        elseif not sex or not c then why = 'unknown sex / category'
        end
        local m = not why and (TU.int(l.m, 1, 10000) or TS.findModel(sex, c.id, l.model)) or nil
        if not why and not m then why = 'style not in the catalogue' end
        local colours = {}
        if not why then
            for i, v in ipairs(type(l.colours) == 'table' and l.colours or { 1 }) do
                local hash = TS.resolve(sex, c.id, m, v)
                if hash then colours[#colours + 1] = { n = i, v = TU.int(v, 1, 1000), hash = hash } end
            end
            if #colours == 0 then why = 'no colour of that style exists' end
        end
        if why then
            skipped[#skipped + 1] = { id = tostring(l.id), why = why }
        else
            seen[l.id] = true
            lines[#lines + 1] = {
                id = l.id, sex = sex, cat = c.id, vorp = c.vorp, tag = c.tag, m = m,
                label = TU.text(l.label, 48) or c.label, catLabel = c.label, group = c.group,
                price = TU.finite(l.price), colours = colours,
            }
        end
    end
    return lines, skipped
end

---In-memory store stock. stock = { [key] = { left, at } }. Unlimited when Config.Stores.stockPerLine <= 0.
local function refill(e, cap, now)
    local every = (TU.finite(Config.Stores.restockMinutes) or 30) * 60
    local amount = TU.int(Config.Stores.restockAmount, 1, 100000) or 1
    if every > 0 and now - e.at >= every then
        local steps = math.floor((now - e.at) / every)
        return math.min(cap, e.left + steps * amount), e.at + steps * every
    end
    return e.left, e.at
end

function TL.stockTake(stock, key, n, now)
    local cap = TU.int(Config.Stores.stockPerLine, 0, 100000) or 0
    if cap <= 0 then return true, nil end
    n = TU.int(n, 1, 1000) or 1
    local e = stock[key]
    if not e then e = { left = cap, at = now } stock[key] = e end
    e.left, e.at = refill(e, cap, now)
    if e.left < n then return false, e.left end
    e.left = e.left - n
    return true, e.left
end

---Stock left without taking any (nil = unlimited).
function TL.stockLeft(stock, key, now)
    local cap = TU.int(Config.Stores.stockPerLine, 0, 100000) or 0
    if cap <= 0 then return nil end
    local e = stock[key]
    if not e then return cap end
    return (refill(e, cap, now))
end
