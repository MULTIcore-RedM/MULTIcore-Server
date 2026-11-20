-- ============================================================
-- MULTIinventory :: server/secondary/search.lua
--
-- Player search / robbery: the searcher sees the target's player grid as the secondary
-- panel (container 'player:<targetCharId>'). Worn clothing (equip:<charid>) is never
-- opened ( , Config.Secondary.search.allowClothing = false; the core's
-- Actions.ref also refuses someone else's equipment).
--
-- Conditions (player-started searches, or script calls with checkConditions = true):
--   target hands up / cuffed / hogtied / dead (client state bag `multiInvPose` written by
--   client/secondary.lua + the state bags in Config.Secondary.search.stateBags + server
--   health), searcher free (not dead/cuffed/hogtied), distance <= maxDistance, cooldown.
-- While open: closes when the target leaves the allowed states (requireConditionWhileOpen),
-- either player walks away (closeDistance), drops or unloads.
-- Takes: blacklist (config + per-call), itemsLimit { items = n, weapons = n } per session
-- (also the vorp shape { items = { limit = n }, weapons = { limit = n } }), items whose
-- definition says can_remove = 0 are never taken. Putting items INTO the target only with
-- allowGive. Everything taken is written to the audit log ('search_take').
--
-- Lua API:
--   SecondarySearch.open(src, target, opts) -> ok, err
--       opts = { title, blacklist, itemsLimit, timeout (cooldown s), checkConditions,
--                checkDistance (default true), maxDistance }
--   SecondarySearch.openFor(data)  vorp openPlayerInventory shape { source, target, title,
--                                  blacklist, itemsLimit, timeout }
--   SecondarySearch.close(src)     SecondarySearch.sessionOf(src)  SecondarySearch.searchersOf(target)
--   SecondarySearch.targetState(src) -> { handsUp, cuffed, hogtied, dead }
--   SecondarySearch.isVulnerable(src) -> bool, why
--   SecondarySearch.tick()         (monitor; runs every checkIntervalMs)
-- Action (NUI/client): 'search' { target = serverId|nil }  (nil = closest player)
-- Events (server-local): MULTIinventory:searchStarted (src, target), :searchEnded (src, target, taken),
--                        :searchTake (src, target, item{name,amount,metadata,weaponId?})
-- ============================================================

SecondarySearch = SecondarySearch or {}

local sessions = {}   -- [searcherSrc] = session
local pending = {}    -- [searcherSrc] = containerId being opened (authorises canOpen)
local cooldowns = {}  -- ['<searcherCharId>:<targetCharId>'] = until (unix s)

local function cfg() return (Config.Secondary and Config.Secondary.search) or {} end
local function msg(key) return ((Config.Secondary or {}).messages or {})[key] end

local function bag(src, key)
    local ok, v = pcall(function() return Player(src).state[key] end)
    if ok then return v end
    return nil
end

local function coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local v = GetEntityCoords(ped)
    return v and { x = v.x, y = v.y, z = v.z } or nil
end

local function distance(a, b)
    local p, q = coords(a), coords(b)
    if not p or not q then return math.huge end
    local dx, dy, dz = p.x - q.x, p.y - q.y, p.z - q.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
SecondarySearch.distance = distance

function SecondarySearch.targetState(src)
    local s = { handsUp = false, cuffed = false, hogtied = false, dead = false }
    local pose = bag(src, 'multiInvPose')
    if type(pose) == 'table' then
        for k in pairs(s) do if pose[k] == true then s[k] = true end end
    end
    for k, keys in pairs(cfg().stateBags or {}) do
        for _, key in ipairs(keys) do
            if bag(src, key) == true then s[k] = true end
        end
    end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 and GetEntityHealth then
        local ok, h = pcall(GetEntityHealth, ped)
        if ok and tonumber(h) and tonumber(h) <= 0 then s.dead = true end
    end
    return s
end

function SecondarySearch.isVulnerable(src)
    local s = SecondarySearch.targetState(src)
    for k, on in pairs(cfg().conditions or {}) do
        if on and s[k] then return true, k end
    end
    return false
end

local function searcherFree(src)
    local s = SecondarySearch.targetState(src)
    return not (s.dead or s.cuffed or s.hogtied)
end

local function keyOf(set)
    local out = {}
    if type(set) ~= 'table' then return out end
    for k, v in pairs(set) do
        local name = type(k) == 'number' and v or k
        local on = type(k) == 'number' or v == true
        local key = Secondary.nameKey(name)
        if key and on then out[key] = true end
    end
    return out
end

local function limitsOf(l)
    if type(l) ~= 'table' then return {} end
    local out = {}
    for _, cat in ipairs({ 'items', 'weapons' }) do
        local v = l[cat]
        if type(v) == 'table' then v = v.limit end
        v = tonumber(v)
        if v and v >= 0 then out[cat] = math.floor(v) end
    end
    return out
end

function SecondarySearch.sessionOf(src) return sessions[tonumber(src)] end

function SecondarySearch.searchersOf(target)
    local out = {}
    for s, x in pairs(sessions) do if x.target == target then out[#out + 1] = s end end
    return out
end

local function endSession(src, reason)
    local s = sessions[src]
    if not s then return end
    sessions[src] = nil
    local taken = s.taken.items + s.taken.weapons
    if taken > 0 then
        local cd = tonumber(s.timeout) or tonumber(cfg().cooldownSeconds) or 0
        if cd > 0 then
            local k = s.charId .. ':' .. s.targetCharId
            cooldowns[k] = math.max(cooldowns[k] or 0, Util.now() + cd)
        end
    end
    TriggerEvent('MULTIinventory:searchEnded', src, s.target, s.taken, reason)
end

---Close the search of `src` (UI closed on his side).
function SecondarySearch.close(src, reason)
    src = tonumber(src)
    local s = sessions[src]
    if not s then return false end
    if State.secondaryOf(src) == s.cid then
        State.close(src, true)      -- fires containerClosed -> endSession
    end
    endSession(src, reason or 'closed')
    return true
end

function SecondarySearch.open(src, target, opts)
    opts = opts or {}
    local sc = cfg()
    src, target = tonumber(src), tonumber(target)
    if sc.enabled == false and not opts.force then return false, 'disabled' end
    local st = src and State.get(src)
    if not st then return false, 'player_not_loaded' end
    if not target or target == src then return false, 'bad_target' end
    local tst = State.get(target)
    if not tst then return false, 'target_not_loaded' end
    if opts.checkDistance ~= false then
        local maxD = tonumber(opts.maxDistance) or tonumber(sc.maxDistance) or 2.0
        if distance(src, target) > maxD then return false, 'search_too_far' end
    end
    if opts.checkConditions then
        if sc.robberMustBeFree ~= false and not searcherFree(src) then return false, 'search_self' end
        if sc.requireHandsUpOrCuffed ~= false and not SecondarySearch.isVulnerable(target) then
            return false, 'search_not_allowed'
        end
    end
    local ck = st.charId .. ':' .. tst.charId
    if (cooldowns[ck] or 0) > Util.now() then return false, 'search_cooldown' end

    local cid = 'player:' .. tst.charId
    local s = {
        target = target, charId = st.charId, targetCharId = tst.charId, cid = cid,
        blacklist = keyOf(opts.blacklist), limits = limitsOf(opts.itemsLimit or sc.itemsLimit),
        timeout = opts.timeout, checkConditions = opts.checkConditions == true,
        taken = { items = 0, weapons = 0 }, startedAt = Util.now(),
    }
    pending[src] = cid
    local ok, err = State.open(src, cid, { label = opts.title or tst.name or ('#' .. target) })
    pending[src] = nil
    if not ok then
        if err == 'locked' then err = 'search_busy' end
        return false, err
    end
    sessions[src] = s
    if sc.notifyTarget ~= false and msg('search_target') then Sync.notify(target, msg('search_target'), 'inform') end
    InvLog.write('search_open', { actorSrc = src, targetCharId = tst.charId, from = cid })
    TriggerEvent('MULTIinventory:searchStarted', src, target)
    return true
end

---vorp openPlayerInventory shape: { source, target, title, blacklist, itemsLimit, timeout }
function SecondarySearch.openFor(data)
    if type(data) ~= 'table' then return false, 'bad_data' end
    return SecondarySearch.open(data.source, data.target, {
        title = data.title, blacklist = data.blacklist, itemsLimit = data.itemsLimit, timeout = data.timeout,
        checkConditions = data.checkConditions == true, checkDistance = data.checkDistance == true,
        maxDistance = data.maxDistance, force = true,
    })
end

-- ------------------------------------------------------------
-- rules (core hooks)
-- ------------------------------------------------------------
-- Only these player-driven reasons can reach someone else's grid through a search session
-- (Actions.ref). Admin tools ('admin'), gives, API calls, drops etc. are never touched here.
local SEARCH_REASONS = { move = true, split = true, merge = true, sort = true }
local function searchCtx(ctx)
    return ctx ~= nil and ctx.src ~= nil and not ctx.admin and SEARCH_REASONS[ctx.reason or ''] == true
end

local function isOtherPlayer(c, src)
    if c.kind ~= 'player' and c.kind ~= 'equip' then return false end
    local st = State.get(src)
    return st ~= nil and c.ownerCharId ~= nil and c.ownerCharId ~= st.charId
end

-- someone else's player grid / equipment can only be opened through a search (admins skip hooks)
InvHooks.register('canOpen', function(src, c, opts)
    if not isOtherPlayer(c, src) then return true end
    if c.kind == 'equip' and not cfg().allowClothing then return false, 'no_access' end
    if pending[src] == c.id then return true end
    return false, 'no_access'
end)

local function stillValid(src, s)
    local sc = cfg()
    if not State.get(s.target) or not State.get(src) then return false, 'gone' end
    local cd = tonumber(sc.closeDistance) or 4.0
    if distance(src, s.target) > cd then return false, 'search_too_far' end
    if s.checkConditions and sc.requireConditionWhileOpen ~= false and sc.requireHandsUpOrCuffed ~= false
        and not SecondarySearch.isVulnerable(s.target) then
        return false, 'search_not_allowed'
    end
    return true
end

local function refuse(src, err)
    local m = msg(err)
    if m then Sync.notify(src, m, 'error') end
    return false, err
end

InvHooks.register('canRemove', function(c, entry, count, ctx)
    if not searchCtx(ctx) or not isOtherPlayer(c, ctx.src) then return true end
    if State.isAdminSession(ctx.src) then return true end
    local s = sessions[ctx.src]
    if not s or s.cid ~= c.id then return false, 'no_access' end
    local ok, why = stillValid(ctx.src, s)
    if not ok then return refuse(ctx.src, why) end
    local key = Secondary.nameKey(entry.item)
    local gbl = keyOf(cfg().blacklist)
    if key and (gbl[key] or s.blacklist[key]) then return refuse(ctx.src, 'blacklisted') end
    if entry.kind ~= 'weapon' and Inv.def(entry.item).canRemove == false then return refuse(ctx.src, 'blacklisted') end
    local cat = entry.kind == 'weapon' and 'weapons' or 'items'
    local lim = s.limits[cat]
    local n = count
    -- cash (Config.Money): a stack of bills/coins counts as ONE take, not one per cent
    if entry.kind ~= 'weapon' and Money and Money.isMoney and Money.isMoney(entry.item)
        and Config.Money and Config.Money.searchCountsAsOne ~= false then n = 1 end
    if lim and s.taken[cat] + n > lim then return refuse(ctx.src, 'search_limit') end
    return true
end)

InvHooks.register('canAdd', function(c, item, count, meta, ctx)
    if not searchCtx(ctx) or not isOtherPlayer(c, ctx.src) then return true end
    if State.isAdminSession(ctx.src) then return true end
    local s = sessions[ctx.src]
    if not s or s.cid ~= c.id then return true end   -- not a search (e.g. other parts' flows)
    if not cfg().allowGive then return false, 'no_access' end
    local ok, why = stillValid(ctx.src, s)
    if not ok then return refuse(ctx.src, why) end
    return true
end)

local function recordTake(src, s, c, item, count, meta, weaponId)
    local cat = weaponId and 'weapons' or 'items'
    local n = count
    if not weaponId and Money and Money.isMoney and Money.isMoney(item)
        and Config.Money and Config.Money.searchCountsAsOne ~= false then n = 1 end
    s.taken[cat] = s.taken[cat] + n
    local lim = s.limits[cat]
    if lim and s.taken[cat] >= lim then
        local cd = tonumber(s.timeout) or tonumber(cfg().cooldownSeconds) or 0
        if cd > 0 then cooldowns[s.charId .. ':' .. s.targetCharId] = Util.now() + cd end
    end
    local snap = { item = item, count = count, metadata = Util.deepcopy(meta or {}), weaponId = weaponId }
    InvLog.write('search_take', { actorSrc = src, targetCharId = s.targetCharId, from = c.id,
                                  to = 'player:' .. s.charId, item = item, count = count, data = { stacks = { snap } } })
    if cfg().notifyTarget ~= false and msg('search_taken') then
        local st = State.get(src)
        local d = Registry.get(item)
        local label = (type(meta) == 'table' and meta.label) or (d and d.label) or item
        Sync.notify(s.target, msg('search_taken'):format(st and st.name or ('#' .. src), label, count), 'error')
    end
    TriggerEvent('MULTIinventory:searchTake', src, s.target, { name = item, amount = count, metadata = snap.metadata, weaponId = weaponId })
end

InvHooks.register('itemRemoved', function(c, item, count, meta, ctx)
    if not searchCtx(ctx) then return end
    local s = sessions[ctx.src]
    if s and s.cid == c.id then recordTake(ctx.src, s, c, item, count, meta, nil) end
end)

InvHooks.register('occupantMoved', function(fromC, toC, e, ctx)
    if fromC == toC or not searchCtx(ctx) then return end
    local s = sessions[ctx.src]
    if s and s.cid == fromC.id then recordTake(ctx.src, s, fromC, e.item, 1, e.metadata, e.weaponId or true) end
end)

-- the session ends whenever the searcher's secondary changes or closes
AddEventHandler('MULTIinventory:containerClosed', function(src, id)
    local s = sessions[src]
    if s and s.cid == id then endSession(src, 'closed') end
end)

-- target or searcher leaves: close at once
InvHooks.register('characterUnloaded', function(src)
    if sessions[src] then SecondarySearch.close(src, 'unloaded') end
    for _, r in ipairs(SecondarySearch.searchersOf(src)) do SecondarySearch.close(r, 'target_gone') end
end)

function SecondarySearch.tick()
    local list = {}
    for src, s in pairs(sessions) do list[#list + 1] = { src, s } end
    for _, x in ipairs(list) do
        local src, s = x[1], x[2]
        if sessions[src] == s then
            if State.secondaryOf(src) ~= s.cid then
                endSession(src, 'closed')
            else
                local ok, why = stillValid(src, s)
                if not ok then
                    local m = msg(why)
                    if m then Sync.notify(src, m, 'error') end
                    SecondarySearch.close(src, why)
                end
            end
        end
    end
    local now = Util.now()
    for k, t in pairs(cooldowns) do if t <= now then cooldowns[k] = nil end end
end

CreateThread(function()
    while true do
        Wait(math.max(250, tonumber(cfg().checkIntervalMs) or 1000))
        if next(sessions) ~= nil then
            local ok, err = pcall(SecondarySearch.tick)
            if not ok then print('^1[MULTIinventory] search: ' .. tostring(err) .. '^7') end
        end
    end
end)

-- ------------------------------------------------------------
-- player action + exports
-- ------------------------------------------------------------
local function closest(src, maxD)
    local best, bestD
    for tsrc in pairs(State.all()) do
        if tsrc ~= src then
            local d = distance(src, tsrc)
            if d <= maxD and (not bestD or d < bestD) then best, bestD = tsrc, d end
        end
    end
    return best
end

Actions.register('search', function(src, d)
    local sc = cfg()
    if sc.enabled == false then return false, 'disabled' end
    local target = Util.toInt(d.target)
    if not target then
        target = closest(src, tonumber(sc.maxDistance) or 2.0)
        if not target then return refuse(src, 'search_none') end
    end
    local ok, err = SecondarySearch.open(src, target, { checkConditions = true })
    if not ok then refuse(src, err) end
    return ok, err
end)

exports('SearchPlayer', function(src, target, opts)
    InvDB.awaitReady()
    opts = type(opts) == 'table' and opts or {}
    if opts.checkConditions == nil then opts.checkConditions = true end
    return SecondarySearch.open(src, target, opts)
end)
exports('StopSearch', function(src) return SecondarySearch.close(src, 'api') end)
exports('IsBeingSearched', function(target) return #SecondarySearch.searchersOf(tonumber(target)) > 0 end)
exports('GetSearchState', function(src) return SecondarySearch.targetState(tonumber(src)) end)

-- tests only
function SecondarySearch._reset() sessions, pending, cooldowns = {}, {}, {} end
function SecondarySearch._cooldowns() return cooldowns end
