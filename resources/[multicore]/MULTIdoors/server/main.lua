-- ============================================================
-- MULTIdoors :: server
-- Lock rules (config/locks.lua, config/rsg_doorlist.lua, then the
-- database table multicore_doors on top), the lock state of every rule,
-- who may lock / unlock, lockpicking, law alerts and the admin tool.
-- The state lives here only; clients read it from GlobalState
-- ('multidoors:<rule id>' = true when locked) and set the doors near them.
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
AddEventHandler('RSGCore:Server:UpdateObject', function()
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

MD = {
    Rules = {},     -- id -> rule (normalized)
    ByHash = {},    -- door hash -> rule id
    ByRsg = {},     -- rsg-doorlock list number -> rule id
    State = {},     -- id -> true (locked) / false
    DbRows = {},    -- id -> decoded data of the database row
    ready = false,
}
local SELFTEST = GetConvar('multicore_selftest', 'false') == 'true'
local STATE_PREFIX = 'multidoors:'

local lastUse = {}      -- src -> GetGameTimer() of the last lock change
local lastPick = {}     -- src -> os.time() of the last lockpick attempt
local picks = {}        -- src -> { id, token, t0 }
local autoTokens = {}   -- id -> number, cancels an older auto-lock timer

local function dbg(...)
    if Config.Debug then print('^5[MULTIdoors]^7', ...) end
end

local function notify(src, text, kind)
    exports.MULTIcore:Notify(src, { text = text, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end
MD.Notify = notify

local function getP(src) return RSGCore.Functions.GetPlayer(tonumber(src)) end

---------------------------------
-- rule shape
---------------------------------
local function clampNum(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- { a = 1 } or { 'a', 'b' } -> { a = n, b = 0 }
local function gradeMap(t)
    if type(t) ~= 'table' then return nil end
    local out, any = {}, false
    for k, v in pairs(t) do
        if type(k) == 'number' and type(v) == 'string' and v ~= '' then
            out[v] = 0; any = true
        elseif type(k) == 'string' and k ~= '' then
            out[k] = math.floor(clampNum(v, 0, 100, 0)); any = true
        end
    end
    return any and out or nil
end

-- { 'A', 'B' } or { A = true } -> { A = true, B = true }
local function setOf(t, lower)
    if type(t) ~= 'table' then return nil end
    local out, any = {}, false
    for k, v in pairs(t) do
        local s = (type(k) == 'number') and v or (v and k)
        if type(s) == 'string' and s ~= '' and #s <= 64 then
            out[lower and s:lower() or s] = true; any = true
        end
    end
    return any and out or nil
end

local function toVec(c)
    if type(c) == 'vector3' or type(c) == 'vector4' then return vector3(c.x, c.y, c.z) end
    if type(c) == 'table' then
        local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
        if x and y and z then return vector3(x, y, z) end
    end
    return nil
end

--- Turns a rule as written (config, database, admin tool) into the shape the script uses.
--- Returns rule or nil, error key.
function MD.Normalize(raw, origin)
    if type(raw) ~= 'table' then return nil, 'bad_rule' end
    if not MDS.ValidId(raw.id) then return nil, 'bad_id' end
    local list = type(raw.door) == 'table' and raw.door or { raw.door }
    local doors, seen = {}, {}
    for _, h in ipairs(list) do
        local hash = MDS.Hash(h)
        if not hash then return nil, 'bad_door' end
        if not seen[hash] then doors[#doors + 1] = hash; seen[hash] = true end
    end
    if #doors == 0 or #doors > 4 then return nil, 'bad_door' end

    local coords = toVec(raw.coords)
    if not coords then
        local sx, sy, sz, n = 0.0, 0.0, 0.0, 0
        for _, h in ipairs(doors) do
            local d = MULTIDoorData[h]
            if d then sx, sy, sz, n = sx + d.x, sy + d.y, sz + d.z, n + 1 end
        end
        if n == 0 then return nil, 'no_coords' end
        coords = vector3(sx / n, sy / n, sz / n)
    end

    local label = type(raw.label) == 'string' and raw.label:sub(1, 80) or ''
    if label == '' then
        local d = MULTIDoorData[doors[1]]
        label = (d and d.name or tostring(doors[1])) .. ' - ' .. MDS.AreaOf(coords.x, coords.y)
    end

    local rsg
    if raw.rsg ~= nil then
        rsg = {}
        for _, k in ipairs(type(raw.rsg) == 'table' and raw.rsg or { raw.rsg }) do
            k = tonumber(k)
            if k and k >= 1 and k % 1 == 0 then rsg[#rsg + 1] = k end
        end
    end

    local items = setOf(raw.items, true)
    return {
        id = raw.id,
        label = label,
        doors = doors,
        coords = coords,
        area = MDS.AreaOf(coords.x, coords.y),
        locked = raw.locked ~= false,
        jobs = gradeMap(raw.jobs),
        gangs = gradeMap(raw.gangs),
        citizenids = setOf(raw.citizenids, false),
        items = items,
        lockpickable = raw.lockpickable == true,
        autoLock = math.floor(clampNum(raw.autoLock, 0, 86400, 0)),
        distance = clampNum(raw.distance, 0.5, 15.0, Config.DefaultDistance),
        rsg = rsg,
        origin = origin or 'config',
    }
end

--- The editable form of a rule (what the admin tool shows and the database stores).
function MD.Editable(rule)
    local function keys(t) local o = {} for k in pairs(t or {}) do o[#o + 1] = k end table.sort(o) return o end
    return {
        id = rule.id, label = rule.label,
        door = rule.doors,
        coords = { x = rule.coords.x, y = rule.coords.y, z = rule.coords.z },
        locked = rule.locked, jobs = rule.jobs, gangs = rule.gangs,
        citizenids = keys(rule.citizenids), items = keys(rule.items),
        lockpickable = rule.lockpickable, autoLock = rule.autoLock, distance = rule.distance,
        rsg = rule.rsg,
    }
end

-- what clients get: no job, gang, citizen or item lists
local function publicRule(r)
    return {
        id = r.id, label = r.label, doors = r.doors, area = r.area,
        coords = { x = r.coords.x, y = r.coords.y, z = r.coords.z },
        distance = r.distance, lockpickable = r.lockpickable, rsg = r.rsg,
    }
end

function MD.PublicRules()
    local out = {}
    for _, r in pairs(MD.Rules) do out[#out + 1] = publicRule(r) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

---------------------------------
-- RSG v2 rsg-doorlock list (config/rsg_doorlist.lua)
---------------------------------
local function nearestDoor(c, maxD)
    local best, bd
    for h, d in pairs(MULTIDoorData) do
        local dist = #(vector3(d.x, d.y, d.z) - c)
        if dist <= maxD and (not bd or dist < bd) then best, bd = h, dist end
    end
    return best
end

-- door hash for one rsg-doorlock entry: its doorid when that is a listed door, else the listed door
-- at its objCoords, else its doorid as it is (a door the list does not have; coords from objCoords)
local function rsgDoorHash(entry)
    local id = MDS.Hash(entry.doorid)
    if id and MULTIDoorData[id] then return id end
    local c = toVec(entry.objCoords)
    local found = c and nearestDoor(c, Config.RsgDoorMatchDistance)
    if found then return found end
    return id, c
end

local function rsgRules()
    local out = {}
    for k, e in ipairs(Config.DoorList or {}) do
        local hashes, coords = {}, nil
        for _, d in ipairs(type(e.doors) == 'table' and e.doors or { e }) do
            local h, c = rsgDoorHash(d)
            if h then hashes[#hashes + 1] = h end
            coords = coords or c
        end
        if #hashes == 0 then
            print(('^3[MULTIdoors] rsg_doorlist entry %d: no door hash found, skipped^7'):format(k))
        else
            out[#out + 1] = {
                id = 'rsg_' .. k, door = hashes, locked = e.locked ~= false,
                jobs = e.authorizedJobs, distance = e.distance, rsg = k,
                coords = coords,
            }
        end
    end
    return out
end

---------------------------------
-- building the rule set
---------------------------------
local function broadcastRules()
    TriggerClientEvent('MULTIdoors:client:rules', -1, MD.PublicRules())
end

local function setGlobal(id, locked)
    GlobalState[STATE_PREFIX .. id] = locked
end

--- Rebuilds MD.Rules from config, the RSG list and the database rows. Keeps the state of rules that stay.
function MD.Build()
    local rules, configIds = {}, {}
    local function add(raw, origin)
        local r, err = MD.Normalize(raw, origin)
        if not r then
            print(('^3[MULTIdoors] rule %s (%s) skipped: %s^7'):format(tostring(raw and raw.id), origin, err))
            return
        end
        rules[r.id] = r
    end
    for _, raw in ipairs(Config.Locks or {}) do add(raw, 'config'); configIds[raw.id or ''] = true end
    for _, raw in ipairs(rsgRules()) do add(raw, 'rsg'); configIds[raw.id] = true end
    for id, data in pairs(MD.DbRows) do
        if data.disabled then
            rules[id] = nil
        else
            data.id = id
            add(data, configIds[id] and 'db_override' or 'db')
        end
    end

    local byHash, byRsg = {}, {}
    for id, r in pairs(rules) do
        for _, h in ipairs(r.doors) do
            if byHash[h] and byHash[h] ~= id then
                local win = (id > byHash[h]) and id or byHash[h]
                print(('^3[MULTIdoors] door %d is in rules %s and %s; %s answers for it^7'):format(h, byHash[h], id, win))
                byHash[h] = win
            else
                byHash[h] = id
            end
        end
        for _, k in ipairs(r.rsg or {}) do byRsg[k] = id end
    end

    -- state: keep what is known, new rules start at their default
    for id in pairs(MD.Rules) do
        if not rules[id] then MD.State[id] = nil; setGlobal(id, nil) end
    end
    for id, r in pairs(rules) do
        if MD.State[id] == nil then MD.State[id] = r.locked end
        setGlobal(id, MD.State[id])
    end
    MD.Rules, MD.ByHash, MD.ByRsg = rules, byHash, byRsg
    if MD.RegisterKeys then MD.RegisterKeys() end
    broadcastRules()
    local n = 0
    for _ in pairs(rules) do n = n + 1 end
    return n
end

---------------------------------
-- database (rules made in game)
---------------------------------
local function loadDb()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multicore_doors` (
            `id` VARCHAR(64) NOT NULL,
            `data` LONGTEXT NOT NULL,
            `updated_by` VARCHAR(64) DEFAULT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    local rows = MySQL.query.await('SELECT id, data FROM multicore_doors') or {}
    MD.DbRows = {}
    for _, row in ipairs(rows) do
        local ok, data = pcall(json.decode, row.data)
        if ok and type(data) == 'table' then MD.DbRows[row.id] = data
        else print(('^3[MULTIdoors] database rule %s could not be read, skipped^7'):format(row.id)) end
    end
end

local function byWho(src)
    if not src or src == 0 then return 'console' end
    local P = getP(src)
    return P and P.PlayerData.citizenid or ('src:' .. tostring(src))
end

--- Saves (creates or replaces) a rule made in game. Returns true or false, error key.
function MD.SaveRule(raw, src)
    local r, err = MD.Normalize(raw, 'db')
    if not r then return false, err end
    local data = MD.Editable(r)
    data.id = nil
    MySQL.query.await('INSERT INTO multicore_doors (id, data, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)',
        { r.id, json.encode(data), byWho(src) })
    MD.DbRows[r.id] = data
    local old = MD.Rules[r.id]
    if old and old.locked ~= r.locked then MD.State[r.id] = nil end -- a new default state takes effect now
    MD.Build()
    dbg('rule saved', r.id, 'by', byWho(src))
    return true
end

--- Removes a rule. A config rule is switched off (a database row says so); a rule made in game is deleted.
function MD.DeleteRule(id, src)
    if not MDS.ValidId(id) then return false, 'bad_id' end
    local inConfig = false
    for _, raw in ipairs(Config.Locks or {}) do if raw.id == id then inConfig = true end end
    for _, raw in ipairs(rsgRules()) do if raw.id == id then inConfig = true end end
    if not inConfig and not MD.DbRows[id] then return false, 'no_rule' end
    if inConfig then
        MySQL.query.await('INSERT INTO multicore_doors (id, data, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), updated_by = VALUES(updated_by)',
            { id, json.encode({ disabled = true }), byWho(src) })
        MD.DbRows[id] = { disabled = true }
    else
        MySQL.query.await('DELETE FROM multicore_doors WHERE id = ?', { id })
        MD.DbRows[id] = nil
    end
    MD.Build()
    dbg('rule removed', id, 'by', byWho(src))
    return true
end

--- Drops the database row of a rule, so the config version (if any) applies again.
function MD.ResetRule(id, src)
    if not MDS.ValidId(id) or not MD.DbRows[id] then return false, 'no_rule' end
    MySQL.query.await('DELETE FROM multicore_doors WHERE id = ?', { id })
    MD.DbRows[id] = nil
    MD.State[id] = nil
    MD.Build()
    dbg('rule reset to config', id, 'by', byWho(src))
    return true
end

---------------------------------
-- state
---------------------------------
--- Locks / unlocks a rule's doors for everyone. No permission check (callers check).
function MD.SetLocked(id, locked, by)
    local r = MD.Rules[id]
    if not r then return false, 'no_rule' end
    locked = locked and true or false
    MD.State[id] = locked
    setGlobal(id, locked)
    autoTokens[id] = (autoTokens[id] or 0) + 1
    if not locked and r.autoLock > 0 then
        local token = autoTokens[id]
        SetTimeout(r.autoLock * 1000, function()
            if autoTokens[id] == token and MD.Rules[id] and MD.State[id] == false then
                MD.SetLocked(id, true, 'autolock')
            end
        end)
    end
    for _, k in ipairs(r.rsg or {}) do TriggerClientEvent('rsg-doorlock:setState', -1, k, locked) end
    TriggerEvent('MULTIdoors:server:changed', id, locked, by)
    dbg(locked and 'locked' or 'unlocked', id, 'by', tostring(by))
    return true
end

function MD.IsLocked(id) return MD.State[id] end

---------------------------------
-- permissions
---------------------------------
function MD.IsAdmin(src)
    src = tonumber(src)
    if not src then return false end
    if src == 0 then return true end
    if IsPlayerAceAllowed(tostring(src), Config.Admin.Ace) then return true end
    local perm = Config.Admin.RsgPermission
    if perm and perm ~= '' and RSGCore.Functions.HasPermission(src, perm) then return true end
    return false
end

local function hasItem(src, name)
    local ok, n = pcall(function()
        local MI = exports.MULTIinventory
        return MI:Count(MI:PlayerInv(src), name)
    end)
    return ok and (tonumber(n) or 0) > 0
end

--- May this player lock / unlock this rule? Returns true, how ('admin', 'job', 'gang', 'citizenid', 'item') or false, error key.
function MD.CanUse(src, id)
    local r = MD.Rules[id]
    if not r then return false, 'no_rule' end
    local P = getP(src)
    if not P then return false, 'no_player' end
    if Config.AdminsUseAll and MD.IsAdmin(src) then return true, 'admin' end
    local pd = P.PlayerData
    if r.jobs and pd.job then
        local min = r.jobs[pd.job.name]
        local grade = pd.job.grade and tonumber(pd.job.grade.level) or 0
        if min and grade >= min and (not Config.RequireOnDuty or pd.job.onduty) then return true, 'job' end
    end
    if r.gangs and pd.gang then
        local min = r.gangs[pd.gang.name]
        local grade = pd.gang.grade and tonumber(pd.gang.grade.level) or 0
        if min and grade >= min then return true, 'gang' end
    end
    if r.citizenids and r.citizenids[pd.citizenid] then return true, 'citizenid' end
    if r.items then
        for name in pairs(r.items) do
            if hasItem(src, name) then return true, 'item' end
        end
    end
    return false, 'no_key'
end

--- Is the player close enough to the rule's doors (OneSync)?
function MD.Near(src, r, extra)
    if not Config.ServerDistanceCheck then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return SELFTEST end
    local pos = GetEntityCoords(ped)
    local limit = r.distance + Config.ServerDistanceSlack + (extra or 0)
    if #(pos - r.coords) <= limit then return true end
    for _, h in ipairs(r.doors) do
        local d = MULTIDoorData[h]
        if d and #(pos - vector3(d.x, d.y, d.z)) <= limit then return true end
    end
    return false
end

--- Full check for a player's lock / unlock (rule, distance, permission). Returns true, how or false, error key.
function MD.Check(src, id)
    local r = MD.Rules[id]
    if not r then return false, 'no_rule' end
    if not MD.Near(src, r) then return false, 'too_far' end
    return MD.CanUse(src, id)
end

--- A player locks / unlocks a rule (wantLocked nil = flip). Returns { ok, locked } or { ok = false, err }.
function MD.Use(src, id, wantLocked)
    local now = GetGameTimer()
    if lastUse[src] and now - lastUse[src] < Config.CooldownMs then return { ok = false, err = 'cooldown' } end
    local ok, how = MD.Check(src, id)
    if not ok then
        dbg('refused', id, 'for', src, how)
        return { ok = false, err = how }
    end
    lastUse[src] = now
    local locked
    if wantLocked == nil then locked = not MD.State[id] else locked = wantLocked and true or false end
    MD.SetLocked(id, locked, src)
    return { ok = true, locked = locked, how = how }
end

---------------------------------
-- lockpicking
---------------------------------
local function lawGetsAlert(P)
    local job = P.PlayerData.job
    if not job then return false end
    local def = RSGCore.Shared.Jobs[job.name]
    local wanted = (def and Config.Alert.JobTypes[def.type or job.type or '']) or Config.Alert.Jobs[job.name]
    if not wanted then return false end
    return (not Config.Alert.OnDutyOnly) or job.onduty == true
end

--- Sends the lockpick alert to the law. Returns how many got it.
function MD.AlertLaw(r, fromSrc)
    if not Config.Alert.Enabled then return 0 end
    if math.random() > Config.Alert.Chance then return 0 end
    local n = 0
    local text = _L('alert_text', r.label, r.area)
    for s, P in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if s ~= fromSrc and lawGetsAlert(P) then
            TriggerClientEvent('MULTIdoors:client:alert', s, r.coords, text)
            n = n + 1
        end
    end
    TriggerEvent('MULTIdoors:server:lockpickAlert', r.id, r.coords, fromSrc)
    return n
end

--- Starts a lockpick attempt. Returns { ok, token } or { ok = false, err }.
function MD.PickStart(src, id)
    local L = Config.Lockpick
    local r = MD.Rules[id]
    if not L.Enabled then return { ok = false, err = 'pick_off' } end
    if not r then return { ok = false, err = 'no_rule' } end
    if not r.lockpickable then return { ok = false, err = 'not_pickable' } end
    if MD.State[id] ~= true then return { ok = false, err = 'not_locked' } end
    if not MD.Near(src, r) then return { ok = false, err = 'too_far' } end
    if lastPick[src] and os.time() - lastPick[src] < L.CooldownSeconds then return { ok = false, err = 'cooldown' } end
    if not hasItem(src, L.Item) then return { ok = false, err = 'no_lockpick' } end
    lastPick[src] = os.time()
    local token = ('%d-%d'):format(GetGameTimer(), math.random(100000, 999999))
    picks[src] = { id = id, token = token, t0 = GetGameTimer() }
    if not Config.Alert.OnSuccessOnly then MD.AlertLaw(r, src) end
    return { ok = true, token = token }
end

--- Ends a lockpick attempt. Returns { ok, unlocked, broke } or { ok = false, err }.
function MD.PickEnd(src, token, success)
    local L = Config.Lockpick
    local p = picks[src]
    picks[src] = nil
    if not p or p.token ~= token then return { ok = false, err = 'no_attempt' } end
    local took = GetGameTimer() - p.t0
    if took > L.MaxMs then return { ok = false, err = 'too_slow' } end
    local r = MD.Rules[p.id]
    if not r then return { ok = false, err = 'no_rule' } end
    if not MD.Near(src, r) then return { ok = false, err = 'too_far' } end
    if success == true and took >= L.MinMs then
        MD.SetLocked(p.id, false, 'lockpick:' .. tostring(src))
        if Config.Alert.OnSuccessOnly then MD.AlertLaw(r, src) end
        return { ok = true, unlocked = true }
    end
    local broke = false
    if math.random() < L.BreakChance then
        local MI = exports.MULTIinventory
        broke = MI:RemoveItem(MI:PlayerInv(src), L.Item, 1, nil, nil, 'lockpick broke') == true
    end
    return { ok = true, unlocked = false, broke = broke }
end

---------------------------------
-- key items
---------------------------------
local itemsDone = {}
function MD.RegisterKeys()
    if not Config.Keys.Register and not Config.Lockpick.RegisterItem then return end
    if GetResourceState('MULTIinventory') ~= 'started' then return end
    local MI = exports.MULTIinventory
    if not MI:IsReady() then return end
    local added = 0
    if Config.Keys.Register then
        for _, r in pairs(MD.Rules) do
            for name in pairs(r.items or {}) do
                if not itemsDone[name] and not MI:GetItemDef(name) then
                    if MI:RegisterItem({
                        name = name, label = _L('key_label', MDS.Pretty(name)), weight = Config.Keys.Weight,
                        type = 'item', unique = false, useable = false, image = Config.Keys.Image,
                        description = _L('key_desc'),
                    }) then added = added + 1 end
                end
                itemsDone[name] = true
            end
        end
    end
    local pick = Config.Lockpick.Item
    if Config.Lockpick.Enabled and Config.Lockpick.RegisterItem and not itemsDone[pick] then
        if not MI:GetItemDef(pick) then
            if MI:RegisterItem({
                name = pick, label = _L('lockpick_label'), weight = Config.Lockpick.ItemWeight,
                type = 'item', unique = false, useable = false, image = pick .. '.png',
                description = _L('lockpick_desc'),
            }) then added = added + 1 end
        end
        itemsDone[pick] = true
    end
    if added > 0 then print(('[MULTIdoors] %d key / lockpick items added to the item list'):format(added)) end
end

---------------------------------
-- start
---------------------------------
CreateThread(function()
    Wait(0) -- area names (shared/doors.lua) first
    loadDb()
    local n = MD.Build()
    local t = 0
    while GetResourceState('MULTIinventory') == 'started' and not exports.MULTIinventory:IsReady() and t < 300 do Wait(100) t = t + 1 end
    MD.RegisterKeys()
    MD.ready = true
    local doors = 0
    for _ in pairs(MULTIDoorData) do doors = doors + 1 end
    print(('[MULTIdoors] %d lock rules active, %d doors known'):format(n, doors))
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'MULTIinventory' and MD.ready then
        itemsDone = {}
        SetTimeout(2000, MD.RegisterKeys)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastUse[src], lastPick[src], picks[src] = nil, nil, nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(MD.Rules) do setGlobal(id, nil) end
end)

---------------------------------
-- player callbacks
---------------------------------
lib.callback.register('MULTIdoors:getRules', function()
    while not MD.ready do Wait(100) end
    return MD.PublicRules()
end)

lib.callback.register('MULTIdoors:check', function(src, id)
    if type(id) ~= 'string' then return { ok = false, err = 'no_rule' } end
    local ok, how = MD.Check(src, id)
    return { ok = ok, err = not ok and how or nil, locked = MD.State[id] }
end)

lib.callback.register('MULTIdoors:use', function(src, id, wantLocked)
    if type(id) ~= 'string' then return { ok = false, err = 'no_rule' } end
    if wantLocked ~= nil and type(wantLocked) ~= 'boolean' then return { ok = false, err = 'bad_rule' } end
    return MD.Use(src, id, wantLocked)
end)

lib.callback.register('MULTIdoors:pickStart', function(src, id)
    if type(id) ~= 'string' then return { ok = false, err = 'no_rule' } end
    return MD.PickStart(src, id)
end)

lib.callback.register('MULTIdoors:pickEnd', function(src, token, success)
    if type(token) ~= 'string' then return { ok = false, err = 'no_attempt' } end
    return MD.PickEnd(src, token, success == true)
end)

---------------------------------
-- admin tool
---------------------------------
RegisterCommand(Config.Admin.Command, function(src)
    if src == 0 then
        print(('[MULTIdoors] %d rules. Use the tool in game.'):format(#MD.PublicRules()))
        return
    end
    if not MD.IsAdmin(src) then notify(src, _L('no_permission'), 'error') return end
    TriggerClientEvent('MULTIdoors:client:admin', src)
end, false)

local function adminOnly(fn)
    return function(src, ...)
        if not MD.IsAdmin(src) then return { ok = false, err = 'no_permission' } end
        return fn(src, ...)
    end
end

lib.callback.register('MULTIdoors:admin:list', adminOnly(function()
    local out = {}
    for id, r in pairs(MD.Rules) do
        out[#out + 1] = { id = id, label = r.label, area = r.area, locked = MD.State[id], origin = r.origin,
            doors = r.doors, coords = { x = r.coords.x, y = r.coords.y, z = r.coords.z } }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    local disabled = {}
    for id, d in pairs(MD.DbRows) do if d.disabled then disabled[#disabled + 1] = id end end
    table.sort(disabled)
    return { ok = true, list = out, disabled = disabled }
end))

lib.callback.register('MULTIdoors:admin:get', adminOnly(function(_, id)
    local r = MD.Rules[id]
    if not r then return { ok = false, err = 'no_rule' } end
    return { ok = true, rule = MD.Editable(r), origin = r.origin, locked = MD.State[id] }
end))

lib.callback.register('MULTIdoors:admin:door', adminOnly(function(_, hash)
    hash = MDS.Hash(hash)
    if not hash then return { ok = false, err = 'bad_door' } end
    return { ok = true, hash = hash, rule = MD.ByHash[hash] }
end))

lib.callback.register('MULTIdoors:admin:save', adminOnly(function(src, raw)
    local ok, err = MD.SaveRule(raw, src)
    return { ok = ok, err = err }
end))

lib.callback.register('MULTIdoors:admin:delete', adminOnly(function(src, id)
    local ok, err = MD.DeleteRule(id, src)
    return { ok = ok, err = err }
end))

lib.callback.register('MULTIdoors:admin:reset', adminOnly(function(src, id)
    local ok, err = MD.ResetRule(id, src)
    return { ok = ok, err = err }
end))

lib.callback.register('MULTIdoors:admin:setState', adminOnly(function(src, id, locked)
    local ok, err = MD.SetLocked(id, locked == true, src)
    return { ok = ok, err = err }
end))

---------------------------------
-- exports (server)
---------------------------------
exports('IsReady', function() return MD.ready end)
exports('GetRules', function() return MD.PublicRules() end)
exports('GetRule', function(id) local r = MD.Rules[id] return r and MD.Editable(r) or nil end)
exports('IsLocked', function(id) return MD.State[id] end)
exports('SetLocked', function(id, locked) return MD.SetLocked(id, locked, GetInvokingResource() or 'export') end)
exports('CanUse', function(src, id) return MD.CanUse(src, id) end)
exports('Use', function(src, id, wantLocked) return MD.Use(src, id, wantLocked) end)
exports('RuleForDoor', function(hash) local h = MDS.Hash(hash) return h and MD.ByHash[h] or nil end)
exports('SetDoorLocked', function(hash, locked)
    local h = MDS.Hash(hash)
    local id = h and MD.ByHash[h]
    if not id then return false, 'no_rule' end
    return MD.SetLocked(id, locked, GetInvokingResource() or 'export')
end)
exports('SaveRule', function(rule) return MD.SaveRule(rule, 0) end)
exports('DeleteRule', function(id) return MD.DeleteRule(id, 0) end)
exports('ResetRule', function(id) return MD.ResetRule(id, 0) end)
exports('GetDoorData', function(hash) return MDS.Door(hash) end)
exports('Reload', function()
    loadDb()
    return MD.Build()
end)

-- self-test only: lockpick steps without a client
if SELFTEST then
    exports('_TestPickStart', function(src, id) return MD.PickStart(src, id) end)
    exports('_TestPickEnd', function(src, token, success) return MD.PickEnd(src, token, success) end)
end
