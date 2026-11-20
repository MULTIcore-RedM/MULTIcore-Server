-- ============================================================
-- MULTIinventory :: server/secondary/permissions.lua
--
-- Rules of registered secondary inventories, enforced through the core hooks
-- (InvHooks canAdd / canRemove), so EVERY path (NUI moves, give, API) obeys them:
--   * acceptWeapons = false        -> no weapons in
--   * black list (BlackListCustomAny, UseBlackList)
--   * whitelistItems / whitelistWeapons -> only names with a limit
--     (setCustomInventoryItemLimit / setCustomInventoryWeaponLimit) may go in
--   * per-item / per-weapon limits (max of that name inside the inventory)
--   * count limit (Config.Secondary.limitMode = 'count')
--   * UsePermissions: job + minimum grade, or charid, to MOVE items in / TAKE items out.
--     Only player-driven changes (ctx.src set) are checked; scripts calling the API act
--     with their own authority. Admin sessions bypass permissions (configurable).
--
-- Lua API:
--   SecondaryPerms.addJob(id, 'move'|'take', job, grade) -> ok
--   SecondaryPerms.addChar(id, 'move'|'take', charId, state) -> ok
--   SecondaryPerms.blacklist(id, name, state) -> ok
--   SecondaryPerms.setItemLimit(id, item, limit) / setWeaponLimit(id, weapon, limit) -> ok
--   SecondaryPerms.allowed(src, container, 'move'|'take') -> bool
--   SecondaryPerms.checkAdd(c, item, count) -> ok, err      (list/limit rules only)
-- Errors: no_weapons, blacklisted, not_allowed, limit, no_permission
-- ============================================================

SecondaryPerms = SecondaryPerms or {}

local function cfg() return Config.Secondary or {} end
local function pcfg() return cfg().permissions or {} end

local function regOf(id)
    local r = Secondary.registration(id)
    if r then return r end
    return nil
end

-- job + grade of the player's character (VORP character / RSG through the bridge)
local function who(src)
    local st = State.get(src)
    local charId = st and st.charId
    local job, grade
    local ok, user = pcall(function() return MBridge.Core.getUser(src) end)
    if ok and user then
        local ch = user.getUsedCharacter
        if type(ch) == 'function' then ch = ch() end
        if ch then
            job = ch.job
            grade = tonumber(ch.jobGrade or ch.jobgrade or ch.grade) or 0
        end
    end
    return charId, job, grade or 0
end
SecondaryPerms.who = who

local function changed(id) Secondary.apply(id) return true end

function SecondaryPerms.addJob(id, op, job, grade)
    local r = regOf(id)
    if not r then return false, 'unknown_container' end
    if type(job) ~= 'string' or job == '' then return false, 'bad_job' end
    local list = op == 'move' and r.perms.jobsMove or r.perms.jobsTake
    local g = math.floor(tonumber(grade) or 0)
    if list[job] == g then return true end
    list[job] = g
    return changed(r.id)
end

function SecondaryPerms.addChar(id, op, charId, state)
    local r = regOf(id)
    if not r then return false, 'unknown_container' end
    local n = math.tointeger(tonumber(charId))
    if not n then return false, 'bad_charid' end
    local list = op == 'move' and r.perms.charsMove or r.perms.charsTake
    local key = tostring(n)
    local v = (state ~= false and state ~= 0) and true or nil
    if list[key] == v then return true end   -- called on every open by several resources: no re-save
    list[key] = v
    return changed(r.id)
end

function SecondaryPerms.blacklist(id, name, state)
    local r = regOf(id)
    if not r then return false, 'unknown_container' end
    local key = Secondary.nameKey(name)
    if not key then return false, 'bad_name' end
    local v = (state ~= false) and true or nil
    if r.flags.blacklist[key] == v then return true end
    r.flags.blacklist[key] = v
    return changed(r.id)
end

local function setLimit(listName, id, name, limit)
    local r = regOf(id)
    if not r then return false, 'unknown_container' end
    local key = Secondary.nameKey(name)
    if not key then return false, 'bad_name' end
    local n = tonumber(limit)
    local v = (n and n > 0) and math.floor(n) or nil
    if r.flags[listName][key] == v then return true end
    r.flags[listName][key] = v
    return changed(r.id)
end
function SecondaryPerms.setItemLimit(id, item, limit) return setLimit('itemLimits', id, item, limit) end
function SecondaryPerms.setWeaponLimit(id, weapon, limit) return setLimit('weaponLimits', id, weapon, limit) end

-- ------------------------------------------------------------
-- checks
-- ------------------------------------------------------------
local function weaponCount(c, key)
    local n = 0
    for _, e in pairs(c.stacks) do
        if e.kind == 'weapon' and Secondary.nameKey(e.item) == key then n = n + 1 end
    end
    return n
end

local function totalCount(c)
    local n = 0
    for _, e in pairs(c.stacks) do n = n + (e.count or 1) end
    return n
end

---List/limit rules for putting `count` of `item` into registered container c.
function SecondaryPerms.checkAdd(c, item, count)
    local f = c.flags
    if not (f and f.registered) then return true end
    local key = Secondary.nameKey(item)
    if not key then return true end
    local isWeapon = Util.isWeaponName(item)
    if isWeapon and f.acceptWeapons == false then return false, 'no_weapons' end
    local bl = f.blacklist
    if f.useBlackList ~= false and bl and (bl[key] or bl[tostring(item):lower()]) then return false, 'blacklisted' end
    if isWeapon then
        local lim = f.weaponLimits and f.weaponLimits[key]
        if f.whitelistWeapons and not lim then return false, 'not_allowed' end
        if lim and weaponCount(c, key) + count > lim then return false, 'limit' end
    else
        local lim = f.itemLimits and f.itemLimits[key]
        if f.whitelistItems and not lim then return false, 'not_allowed' end
        if lim and Weight.itemTotal(c, item) + count > lim then return false, 'limit' end
    end
    if f.countLimit and totalCount(c) + count > f.countLimit then return false, 'limit' end
    return true
end

---May player `src` move items into ('move') / take items out of ('take') container c?
function SecondaryPerms.allowed(src, c, op)
    local f, p, pc = c.flags or {}, c.perms or {}, pcfg()
    if pc.adminBypass ~= false and State.isAdminSession(src) then return true end
    local chars = (op == 'move' and p.charsMove or p.charsTake) or {}
    local jobs = (op == 'move' and p.jobsMove or p.jobsTake) or {}
    local charId, job, grade = who(src)
    if not f.usePermissions then
        if pc.enforceCharIdWithoutUsePermissions and next(chars) ~= nil then
            return charId ~= nil and chars[tostring(charId)] == true
        end
        return true
    end
    -- the owner of a per-character inventory always may use his own contents
    if f.perCharacter and c.ownerCharId and c.ownerCharId == charId then return true end
    if next(chars) == nil and next(jobs) == nil then return pc.emptyMeansOpen == true end
    if charId and chars[tostring(charId)] then return true end
    if job and jobs[job] ~= nil and grade >= (tonumber(jobs[job]) or 0) then return true end
    return false
end

-- Player-facing message for refusals the core does not word itself (it notifies
-- weight/limit/slots/locked). Only for player moves, never for API pre-checks.
local NOTIFY = { no_permission = true, blacklisted = true, not_allowed = true, no_weapons = true }

-- permission checks only for a player acting for himself (not admin tools, not scripts)
local function playerCtx(ctx)
    if not ctx or not ctx.src or ctx.admin then return false end
    if type(ctx.reason) == 'string' and ctx.reason:sub(1, 5) == 'admin' and pcfg().adminBypass ~= false then return false end
    return true
end
local function refuse(ctx, err)
    if ctx and ctx.src and NOTIFY[err] and ctx.reason ~= 'api' then Secondary.notifyErr(ctx.src, err) end
    return false, err
end

InvHooks.register('canAdd', function(c, item, count, meta, ctx)
    if not (c.flags and c.flags.registered) then return true end
    local ok, err = SecondaryPerms.checkAdd(c, item, count)
    if not ok then return refuse(ctx, err) end
    if playerCtx(ctx) and not SecondaryPerms.allowed(ctx.src, c, 'move') then return refuse(ctx, 'no_permission') end
    return true
end)

InvHooks.register('canRemove', function(c, entry, count, ctx)
    if not (c.flags and c.flags.registered) then return true end
    if playerCtx(ctx) and not SecondaryPerms.allowed(ctx.src, c, 'take') then return refuse(ctx, 'no_permission') end
    return true
end)

-- ------------------------------------------------------------
-- native exports
-- ------------------------------------------------------------
exports('SetSecondaryPermission', function(id, op, kind, key, value)
    if kind == 'job' then return SecondaryPerms.addJob(id, op, key, value) end
    if kind == 'char' or kind == 'charid' then return SecondaryPerms.addChar(id, op, key, value) end
    return false, 'bad_kind'
end)
exports('BlacklistSecondary', function(id, name, state) return SecondaryPerms.blacklist(id, name, state) end)
exports('SetSecondaryItemLimit', function(id, item, limit) return SecondaryPerms.setItemLimit(id, item, limit) end)
exports('SetSecondaryWeaponLimit', function(id, weapon, limit) return SecondaryPerms.setWeaponLimit(id, weapon, limit) end)
