--[[
    TA - the server adapter. Everything framework / inventory specific goes through here, so the
    rest of MULTItailor never touches vorp_core / rsg-core / an inventory directly.

    Player   TA.char(src) TA.job(src) -> { name, grade, isboss } | nil   TA.name(src) TA.cid(src) TA.cidInt(src)
             TA.sex(src) -> 'male'|'female'|nil   TA.setJob(src, job, grade) -> ok   TA.isAdmin(src)
             TA.dist(src, coords) -> metres (math.huge when unknown)   TA.players() -> { src, ... }
             TA.ensureRsgJobs() -> n   (RSG: add install/jobs_rsg.lua jobs rsg-core lacks)
    Money    TA.money(src)  TA.takeMoney(src, amount) -> ok  TA.giveMoney(src, amount) -> ok
    Items    TA.count(src, item)  TA.remove(src, item, n)  TA.give(src, item, n, meta)  TA.canCarry(src, item, n)
             TA.label(item)  TA.items(src) -> { { id, name, label, count, metadata } }  TA.removeById(src, id, n)
             TA.registerUsable(item, fn(data))  TA.closeInventory(src)
    Stash    TA.stashOpen(src, key, opts)
    Clothing TA.clothingFormat() -> 'multi' | 'unavailable'   TA.givePiece(src, piece) / TA.giveOutfit(src, outfit)
    Other    TA.notify(src, text, type)  TA.rate(src, bucket) -> allowed  TA.licence(src, activity, job) -> ok, reason
]]
TA = TA or {}

local RES = GetCurrentResourceName()

local function started(name)
    local s = GetResourceState(name)
    return s == 'started'
end

-- ---------------------------------------------------------------- player
function TA.char(src)
    local ok, c = pcall(function()
        local user = MBridge.Core.getUser(tonumber(src))
        return user and user.getUsedCharacter or nil
    end)
    return ok and c or nil
end

-- rsg-core hands out a COPY of its core object; take a fresh one when its shared
-- tables change (RSGCore:Server:UpdateObject) or rsg-core restarts.
local rsgCoreObj
local function rsgCore()
    if not rsgCoreObj then rsgCoreObj = exports['rsg-core']:GetCoreObject() end
    return rsgCoreObj
end
AddEventHandler('RSGCore:Server:UpdateObject', function() rsgCoreObj = nil end)
AddEventHandler('onResourceStart', function(res) if res == 'rsg-core' then rsgCoreObj = nil end end)

local function rsgPlayer(src)
    local ok, p = pcall(function() return rsgCore().Functions.GetPlayer(tonumber(src)) end)
    return ok and p or nil
end

---rsg-core job definition (Shared.Jobs[name]) or nil.
local function rsgJobDef(name)
    local ok, jobs = pcall(function() return rsgCore().Shared.Jobs end)
    return ok and type(jobs) == 'table' and jobs[tostring(name):lower()] or nil
end

function TA.job(src)
    if MBridge.IsRsg then
        local p = rsgPlayer(src)
        local job = p and p.PlayerData and p.PlayerData.job
        if not job or not job.name then return nil end
        local grade = job.grade
        local level = type(grade) == 'table' and tonumber(grade.level) or tonumber(grade) or 0
        return { name = tostring(job.name):lower(), grade = level, isboss = job.isboss == true or (type(grade) == 'table' and grade.isboss == true) }
    end
    local c = TA.char(src)
    if not c or not c.job then return nil end
    return { name = tostring(c.job):lower(), grade = tonumber(c.jobGrade) or 0, isboss = false }
end

function TA.name(src)
    local c = TA.char(src)
    if not c then return GetPlayerName(src) or 'Someone' end
    local n = ('%s %s'):format(c.firstname or '', c.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if n == '' then n = GetPlayerName(src) or 'Someone' end
    return n
end

function TA.cid(src)
    local c = TA.char(src)
    if not c then return nil end
    if MBridge.IsRsg then return c.citizenid and tostring(c.citizenid) or nil end
    return c.charIdentifier and tostring(c.charIdentifier) or nil
end

function TA.cidInt(src)
    local c = TA.char(src)
    local id = c and tonumber(c.charIdentifier)
    if id and id == math.floor(id) then return math.floor(id) end
    return nil
end

function TA.sex(src)
    local c = TA.char(src)
    if not c then return nil end
    if MBridge.IsRsg then
        local g = c.gender
        if g == nil then return nil end
        return tonumber(g) == 1 and 'female' or 'male'
    end
    return TS.sexOf(c.gender)
end

function TA.setJob(src, job, grade)
    grade = TU.int(grade, 0, 100) or 0
    if MBridge.IsRsg then
        local p = rsgPlayer(src)
        if not p or type(job) ~= 'string' then return false end
        -- rsg-core keys grades with STRINGS ('0', '1' ...). SetJob refuses an unknown job but
        -- silently drops an unknown grade to level 0, so check both here.
        local def = rsgJobDef(job)
        if not def then
            print(('^3[%s] rsg-core has no job "%s" - add it (install/jobs_rsg.lua)^0'):format(RES, job))
            return false
        end
        if type(def.grades) == 'table' and def.grades[tostring(grade)] == nil then
            print(('^3[%s] rsg-core job "%s" has no grade "%s"^0'):format(RES, job, tostring(grade)))
            return false
        end
        local ok, res = pcall(function() return p.Functions.SetJob(job:lower(), tostring(grade)) end)
        return ok and res ~= false
    end
    local c = TA.char(src)
    if not c or not c.setJob then return false end
    local ok = pcall(function()
        c.setJob(job, true)
        if c.setJobGrade then c.setJobGrade(grade, true) end
    end)
    return ok
end

---RSG only: add the tailor jobs of install/jobs_rsg.lua that rsg-core does not know yet
---(exports['rsg-core']:AddJob, runtime only). Returns the number added.
function TA.ensureRsgJobs()
    if not MBridge.IsRsg then return 0 end
    local raw = LoadResourceFile(RES, 'install/jobs_rsg.lua')
    if not raw then return 0 end
    local chunk = load(raw, '@' .. RES .. '/install/jobs_rsg.lua', 't', { pairs = pairs })
    local okRun, defs = pcall(chunk or error)
    if not okRun or type(defs) ~= 'table' then
        print(('^1[%s] install/jobs_rsg.lua did not load^0'):format(RES))
        return 0
    end
    local added, failed = 0, {}
    for name, def in pairs(defs) do
        if not rsgJobDef(name) then
            local ok, res = pcall(function() return exports['rsg-core']:AddJob(name, def) end)
            if ok and res ~= false then added = added + 1 else failed[#failed + 1] = name end
        end
    end
    if added > 0 then rsgCoreObj = nil print(('[%s] added %d tailor job(s) to rsg-core (runtime)'):format(RES, added)) end
    if #failed > 0 then
        table.sort(failed)
        print(('^3[%s] rsg-core refused job(s) %s - paste them from install/jobs_rsg.lua^0'):format(RES, table.concat(failed, ', ')))
    end
    return added
end

function TA.isAdmin(src)
    src = tonumber(src)
    if not src then return false end
    if Config.Admin.ace and IsPlayerAceAllowed(src, Config.Admin.ace) then return true end
    local ok, group = pcall(function()
        local user = MBridge.Core.getUser(src)
        local g = user and (user.getGroup or user.group)
        if type(g) == 'function' then g = g() end
        return g
    end)
    if ok and type(group) == 'string' then
        for _, g in ipairs(Config.Admin.groups or {}) do if g == group then return true end end
    end
    return false
end

function TA.dist(src, c)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or type(c) ~= 'table' and type(c) ~= 'vector3' and type(c) ~= 'vector4' then return math.huge end
    local p = GetEntityCoords(ped)
    local dx, dy, dz = p.x - c.x, p.y - c.y, p.z - c.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function TA.players()
    local out = {}
    for _, id in ipairs(GetPlayers()) do out[#out + 1] = tonumber(id) end
    return out
end

-- ---------------------------------------------------------------- money
function TA.money(src)
    local c = TA.char(src)
    return c and (TU.finite(c.money) or 0) or 0
end

function TA.takeMoney(src, amount)
    amount = TU.money(amount)
    if not amount or amount <= 0 then return false end -- nan guard
    local c = TA.char(src)
    if not c or (TU.finite(c.money) or 0) + 1e-9 < amount then return false end
    local ok, res = pcall(function() return c.removeCurrency(Config.Currency.id or 0, amount) end)
    return ok and res ~= false
end

function TA.giveMoney(src, amount)
    amount = TU.money(amount)
    if not amount or amount <= 0 then return false end -- nan guard
    local c = TA.char(src)
    if not c then return false end
    local ok, res = pcall(function() return c.addCurrency(Config.Currency.id or 0, amount) end)
    return ok and res ~= false
end

-- ---------------------------------------------------------------- items
local INV = function() return MBridge.INV end

function TA.count(src, item)
    local ok, n = pcall(function() return INV():getItemCount(src, nil, item) end)
    return (ok and TU.finite(n)) or 0
end

function TA.remove(src, item, n)
    n = TU.int(n, 1, 100000)
    if not n then return false end -- nan guard
    local ok, res = pcall(function() return INV():subItem(src, item, n) end)
    return ok and res ~= false and res ~= nil
end

function TA.give(src, item, n, meta)
    n = TU.int(n, 1, 100000)
    if not n then return false end -- nan guard
    local ok, res = pcall(function() return INV():addItem(src, item, n, meta) end)
    return ok and res ~= false and res ~= nil
end

function TA.canCarry(src, item, n)
    local ok, res = pcall(function() return INV():canCarryItem(src, item, n or 1) end)
    return not ok or res ~= false
end

local labels = {}
function TA.label(item)
    if labels[item] then return labels[item] end
    local ok, def = pcall(function() return INV():getItemDB(item) end)
    local label = ok and type(def) == 'table' and def.label or item
    labels[item] = label
    return label
end

function TA.items(src)
    local ok, list = pcall(function() return INV():getUserInventoryItems(src) end)
    local out = {}
    for _, it in ipairs(ok and type(list) == 'table' and list or {}) do
        local meta = it.metadata
        if type(meta) ~= 'table' then meta = {} end
        out[#out + 1] = { id = it.id or it.mainid, name = it.name, label = it.label or TA.label(it.name),
                          count = tonumber(it.count or it.amount) or 0, metadata = meta }
    end
    return out
end

function TA.removeById(src, id, n)
    n = TU.int(n, 1, 100000)
    if not n or id == nil then return false end
    local ok, res = pcall(function() return INV():subItemById(src, id, nil, nil, n) end)
    return ok and res ~= false and res ~= nil
end

function TA.registerUsable(item, fn)
    local ok, err = pcall(function() INV():registerUsableItem(item, fn) end)
    if not ok then print(('^3[%s] could not register %s as usable: %s^0'):format(RES, item, tostring(err))) end
    return ok
end

function TA.closeInventory(src)
    pcall(function() INV():closeInventory(src) end)
end

-- ---------------------------------------------------------------- stash (shop stockroom)
local registered = {}
function TA.stashOpen(src, key, opts)
    opts = opts or {}
    local label, slots, maxWeight = opts.label or 'Stockroom', opts.slots or 50, opts.maxWeight or 500000
    if MBridge.IsRsg and not MBridge.IsMultiInv then
        -- rsg-inventory (README): RegisterStash(id, {label, slots, maxWeight}) + OpenStash(src, id, opts);
        -- builds without them still have OpenInventory(src, id, {label, maxweight, slots}).
        local inv = exports['rsg-inventory']
        if not registered[key] then
            registered[key] = pcall(function() return inv:RegisterStash(key, { label = label, slots = slots, maxWeight = maxWeight }) end)
        end
        local okS, res = pcall(function() return inv:OpenStash(src, key, { label = label, slots = slots, maxWeight = maxWeight }) end)
        if okS and res ~= false then return true end
        local ok = pcall(function() inv:OpenInventory(src, key, { label = label, maxweight = maxWeight, slots = slots }) end)
        return ok
    end
    if not registered[key] then
        local okR, already = pcall(function() return INV():isCustomInventoryRegistered(key) end)
        if not (okR and already) then
            pcall(function()
                INV():registerInventory({ id = key, name = label, limit = maxWeight / 1000, acceptWeapons = true,
                    shared = true, ignoreItemStackLimit = true })
            end)
        end
        registered[key] = true
    end
    -- MULTIinventory on RSG: its compat API takes the numeric character id (bridge id map)
    local cid = MBridge.IsRsg and TA.cidInt(src) or TA.cid(src)
    if cid then pcall(function() INV():AddCharIdPermissionTakeFromCustom(key, tonumber(cid) or cid, true) end) end
    local ok = pcall(function() INV():openInventory(src, key) end)
    return ok
end

-- ---------------------------------------------------------------- clothing items
---'multi' = MULTIinventory clothing items (always on MULTIcore), 'unavailable' = MULTIinventory is not running.
---'outfit' (tailored_outfit items) only when Config.Items.format says so outside MULTIcore.
function TA.clothingFormat()
    local want = Config.Items.format or 'multi'
    if want == 'outfit' and not started('MULTIcore') then return 'outfit' end
    local res = Config.Items.inventoryResource or 'MULTIinventory'
    local s = GetResourceState(res)
    if s == 'started' or s == 'starting' then return 'multi' end
    return 'unavailable'
end

local function multiPalette(p)
    p = tonumber(p) or 0
    if p == 0 then return nil end
    local row = TS.palette(p)
    if row and row.inventory == false then return nil end
    return p
end

---piece = { cat, hash, sex, label, description, m, v, palette, tints = {t0,t1,t2}, quality?, maker? ... }
---Returns ok, err.
function TA.givePiece(src, piece)
    local c = TS.category(piece.cat)
    if not c then return false, 'bad_category' end
    local fmt = TA.clothingFormat()
    if fmt == 'unavailable' then return false, 'inventory_missing' end
    if fmt == 'multi' then
        local spec = { category = c.vorp, comp = piece.hash, gender = piece.sex, label = piece.label, description = piece.description }
        local pal = multiPalette(piece.palette)
        if pal then
            spec.palette = pal
            spec.tint0, spec.tint1, spec.tint2 = piece.tints and piece.tints[1] or 0, piece.tints and piece.tints[2] or 0, piece.tints and piece.tints[3] or 0
        end
        local res = Config.Items.inventoryResource or 'MULTIinventory'
        local ok, a, b = pcall(function() return exports[res]:CreateClothingItem(src, spec, 1) end)
        if not ok then return false, 'inventory_error' end
        if a then return true end
        return false, tostring(b or 'refused')
    end
    local item = Config.Items.outfitItem
    if not TA.canCarry(src, item, 1) then return false, 'no_room' end
    local meta = {
        kind = 'piece', uid = ('%x%03x'):format(os.time(), math.random(0, 4095)), sex = piece.sex,
        label = piece.label, outfit = piece.label, description = piece.description,
        pieces = { { c = c.id, h = piece.hash, m = piece.m, v = piece.v, p = tonumber(piece.palette) or 0,
                     t = { piece.tints and piece.tints[1] or 0, piece.tints and piece.tints[2] or 0, piece.tints and piece.tints[3] or 0 } } },
    }
    if TA.give(src, item, 1, meta) then return true end
    return false, 'no_room'
end

---outfit = { name, description, sex, pieces (validated), meta (full tailored_outfit metadata) }
function TA.giveOutfit(src, outfit)
    local fmt = TA.clothingFormat()
    if fmt == 'unavailable' then return false, 'inventory_missing' end
    if fmt == 'multi' then
        local m = outfit.meta
        local specs = {}
        for _, p in ipairs(outfit.pieces) do
            local c = TS.category(p.c)
            local spec = { category = c.vorp, comp = p.h, gender = outfit.sex, label = c.label }
            local pal = multiPalette(p.p)
            if pal then spec.palette, spec.tint0, spec.tint1, spec.tint2 = pal, p.t[1], p.t[2], p.t[3] end
            specs[#specs + 1] = spec
        end
        local bundle = {
            label = outfit.name, description = outfit.description and outfit.description:sub(1, 255) or nil, pieces = specs,
            quality = m.quality, quality_label = m.quality_label, maker = m.maker and m.maker:sub(1, 64) or nil,
            maker_cid = TA.cidInt(src), made_by = m.made_by, made_at = m.made_at,
        }
        local res = Config.Items.inventoryResource or 'MULTIinventory'
        local ok, a, b = pcall(function() return exports[res]:CreateOutfitBundle(src, bundle) end)
        if not ok then return false, 'inventory_error' end
        if a then return true end
        return false, tostring(b or 'refused')
    end
    local item = Config.Items.outfitItem
    if not TA.canCarry(src, item, 1) then return false, 'no_room' end
    if TA.give(src, item, 1, outfit.meta) then return true end
    return false, 'no_room'
end

-- ---------------------------------------------------------------- notify
function TA.notify(src, text, ntype, title)
    if not src then return end
    ntype = ntype or 'inform'
    local want = Config.Notify or 'auto'
    if want == 'auto' and started('MULTIcore') then
        local kind = (ntype == 'inform' and 'info') or ntype
        pcall(function()
            exports.MULTIcore:Notify(src, { title = title or L('title'), text = tostring(text or ''), type = kind, duration = 5000 })
        end)
        return
    end
    TriggerClientEvent('ox_lib:notify', src, { title = title or L('title'), description = tostring(text or ''),
        type = ntype, duration = 5000, position = 'top-right' })
end

-- ---------------------------------------------------------------- rate limits
local buckets = {}
function TA.rate(src, bucket)
    local rule = Config.RateLimits[bucket] or Config.RateLimits.default
    local now = GetGameTimer()
    local key = tostring(src) .. ':' .. tostring(bucket)
    local b = buckets[key]
    if not b or now - b.start > rule.window then
        buckets[key] = { start = now, n = 1 }
        return true
    end
    b.n = b.n + 1
    return b.n <= rule.count
end

AddEventHandler('playerDropped', function()
    local prefix = tostring(source) .. ':'
    for k in pairs(buckets) do if k:sub(1, #prefix) == prefix then buckets[k] = nil end end
end)

-- ---------------------------------------------------------------- licence office (optional)
function TA.licence(src, activity, jobName)
    local cfg = Config.Licence or {}
    if cfg.enabled == false or not (cfg.requireFor or {})[activity] then return true end
    local res = cfg.resource or 'RINGOjobsandcrafting'
    if not started(res) then
        if cfg.failOpen ~= false then return true end
        return false, L('err_licence_office')
    end
    local ok, allowed, reason = pcall(function()
        return exports[res]:CanUseJobFeature(src, { businessId = cfg.businessId or 'tailor', job = jobName })
    end)
    if not ok or allowed == nil then
        if cfg.failOpen ~= false then return true end
        return false, L('err_licence_office')
    end
    if allowed then return true end
    return false, reason or L('err_licence')
end
