-- ============================================================
-- MULTIinventory :: server/workshop/stations.lua
--
-- Placeable work stations (Config.Stations, config_workshop.lua): grinding wheel,
-- spinning wheel, mortar & pestle. Bought as items, placed anywhere, gone after
-- lifetimeHours (counted from the first placement; picking up keeps the clock).
--
-- Flow (server authority):
--   use <station item>  -> client gets a one-time token  (MULTIinventory:cl:stationPlace)
--   stationPlace  { token, x, y, z, heading }  -> takes the item, saves multiinv_stations, broadcasts
--   stationList   {}                           -> { stations }     (client streams the props)
--   stationUse    { id } | { type, x, y, z }   -> opens a "session" at that station (also world props /
--                                                 housing furniture with the same model when worldProps)
--   stationPickup { id }                       -> owner gets the item back (with metadata.expiresAt)
-- Client events: MULTIinventory:cl:stationAdd (view) / stationRemove (id)
-- Hook for recipes: HandCraft.atStation(src, type)   Stations.at(src, type) -> bool
-- ============================================================

Stations = Stations or {}

local SC = Config.Stations or { enabled = false, types = {} }
local L = WorkshopLogic

local list = {}         -- [id] = { id, type, owner, x, y, z, heading, createdAt, expiresAt }
local tokens = {}       -- [src] = { token, type, stackId, until }
local sessions = {}     -- [src] = { type, x, y, z, until, id }
local tokenSeq = 0

local function now() return Util.now() end

function Stations.typeOf(key) return type(key) == 'string' and (SC.types or {})[key] or nil end

local function view(s)
    local t = Stations.typeOf(s.type) or {}
    return { id = s.id, type = s.type, model = t.model, owner = s.owner, x = s.x, y = s.y, z = s.z,
             heading = s.heading, expiresAt = s.expiresAt }
end

function Stations.all()
    local out = {}
    for _, s in pairs(list) do out[#out + 1] = view(s) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Stations.get(id) return list[math.tointeger(tonumber(id)) or -1] end

local function pedPos(src)
    local ok, v = pcall(function()
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return nil end
        return GetEntityCoords(ped)
    end)
    if not ok or not v then return nil end
    local x, y, z = L.num(v.x), L.num(v.y), L.num(v.z)
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z }
end
Stations.pedPos = pedPos

local function charOf(src)
    local st = State.get(src)
    return st and st.charId or nil
end

local function isAdmin(src)
    return src == 0 or (Config.Admin and Config.Admin.ace and IsPlayerAceAllowed(src, Config.Admin.ace)) or false
end

-- ------------------------------------------------------------
-- "at a station?"  (session from a target, a placed station near, or a carried hand tool)
-- ------------------------------------------------------------
function Stations.at(src, stype)
    if not SC.enabled then return false end
    local t = Stations.typeOf(stype)
    if not t then return false end
    if t.carryItems then
        local c = Actions.ref(src, 'player')
        if c then
            for _, it in ipairs(t.carryItems) do
                if Inv.count(c, it) > 0 then return true end
            end
        end
    end
    local radius = L.num(SC.recipeRadius) or 3.5
    local pos = pedPos(src)
    local s = sessions[src]
    if s and s.type == stype and s['until'] > now() then
        if s.id and not list[s.id] then sessions[src] = nil
        else
            local d = L.dist(pos, s)
            if d == nil or d <= radius then return true end   -- position unknown on this build: trust the session
        end
    end
    return L.nearest(list, pos, stype, radius) ~= nil
end

HandCraft.atStation = function(src, stype) return Stations.at(src, stype) end

---The station the player is working at now (for the book header): { key, label } | nil
function Stations.current(src)
    local s = sessions[src]
    if s and s['until'] > now() and Stations.at(src, s.type) then
        local t = Stations.typeOf(s.type)
        return { key = s.type, label = t and t.label or s.type }
    end
    local pos = pedPos(src)
    for key, t in pairs(SC.types or {}) do
        if L.nearest(list, pos, key, L.num(SC.recipeRadius) or 3.5) then return { key = key, label = t.label or key } end
    end
    return nil
end

-- ------------------------------------------------------------
-- database
-- ------------------------------------------------------------
local function insertRow(s)
    local ok, id = pcall(MySQL.insert.await,
        'INSERT INTO `multiinv_stations` (`type`, `owner_charid`, `x`, `y`, `z`, `heading`, `created_at`, `expires_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { s.type, s.owner, s.x, s.y, s.z, s.heading, s.createdAt, s.expiresAt })
    if not ok then print('^1[MULTIinventory] station insert: ' .. tostring(id) .. '^7') return nil end
    return math.tointeger(tonumber(id))
end

local function deleteRow(id)
    InvDB.update('DELETE FROM `multiinv_stations` WHERE `id` = ?', { id })
end

function Stations.load()
    for k in pairs(list) do list[k] = nil end
    InvDB.update('DELETE FROM `multiinv_stations` WHERE `expires_at` <= ?', { now() })
    for _, r in ipairs(InvDB.query('SELECT * FROM `multiinv_stations`', {})) do
        local id = math.tointeger(tonumber(r.id))
        if id and Stations.typeOf(r.type) then
            list[id] = { id = id, type = r.type, owner = math.tointeger(tonumber(r.owner_charid)),
                         x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), heading = tonumber(r.heading) or 0.0,
                         createdAt = tonumber(r.created_at), expiresAt = tonumber(r.expires_at) }
        end
    end
end

local function remove(id, reason)
    if not list[id] then return end
    list[id] = nil
    deleteRow(id)
    for src, s in pairs(sessions) do if s.id == id then sessions[src] = nil end end
    TriggerClientEvent('MULTIinventory:cl:stationRemove', -1, id, reason)
end
Stations.remove = remove

function Stations.sweep()
    local t = now()
    local gone = {}
    for id, s in pairs(list) do if s.expiresAt <= t then gone[#gone + 1] = id end end
    for _, id in ipairs(gone) do remove(id, 'expired') end
    for src, tk in pairs(tokens) do if tk['until'] < t then tokens[src] = nil end end
    return #gone
end

-- ------------------------------------------------------------
-- placement
-- ------------------------------------------------------------
local function notify(src, text, kind) Sync.notify(src, text, kind) end

---Item use -> ask the client where to put it.
function Stations.beginPlace(src, stype, itemTable)
    if not SC.enabled then return false, 'disabled' end
    local t = Stations.typeOf(stype)
    if not t then return false, 'unknown_station' end
    local charId = charOf(src)
    if not charId then return false, 'player_not_loaded' end
    local max = math.tointeger(tonumber(SC.maxPerCharacter)) or 2
    if max > 0 and L.countOwned(list, charId, stype) >= max then
        notify(src, ('You already have %d %s set up.'):format(max, (t.label or stype):lower() .. (max == 1 and '' or 's')), 'error')
        return false, 'too_many'
    end
    local meta = itemTable and itemTable.metadata or {}
    if L.num(meta.expiresAt) and L.num(meta.expiresAt) <= now() then
        local c = Actions.ref(src, 'player')
        if c and itemTable.id then Inv.removeStack(c, itemTable.id, 1, { src = src, reason = 'expire' }) end
        notify(src, ('The %s has fallen apart.'):format((t.label or stype):lower()), 'error')
        return false, 'worn_out'
    end
    tokenSeq = tokenSeq + 1
    local token = tokenSeq * 1000 + math.random(0, 999)
    tokens[src] = { token = token, type = stype, stackId = itemTable and itemTable.id, ['until'] = now() + 120 }
    TriggerClientEvent('MULTIinventory:cl:stationPlace', src, {
        token = token, type = stype, model = t.model, label = t.label or stype,
        useItemPlacer = SC.useItemPlacer ~= false, placeDistance = L.num(SC.placeDistance) or 5.0,
    })
    return true
end

function Stations.place(src, d)
    local tk = tokens[src]
    if not tk or tk.token ~= math.tointeger(L.num(d.token) or -1) then return false, 'bad_token' end
    tokens[src] = nil
    if tk['until'] < now() then return false, 'bad_token' end
    local t = Stations.typeOf(tk.type)
    local p = L.validPlacement(d)
    if not t or not p then return false, 'bad_position' end
    local charId = charOf(src)
    if not charId then return false, 'player_not_loaded' end
    local d0 = L.dist(pedPos(src), p)
    if d0 and d0 > (L.num(SC.placeDistance) or 5.0) + 1.5 then return false, 'too_far' end
    local max = math.tointeger(tonumber(SC.maxPerCharacter)) or 2
    if max > 0 and L.countOwned(list, charId, tk.type) >= max then return false, 'too_many' end
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    local ctx = { src = src, reason = 'station_place', from = c.id }
    -- the stack that was used, else any one of that item
    local ok, removed = false, nil
    if tk.stackId then ok, removed = Inv.removeStack(c, tk.stackId, 1, ctx) end
    if not ok then ok, removed = Inv.remove(c, t.item, 1, nil, ctx) end
    if not ok or type(removed) ~= 'table' or not removed[1] then return false, 'missing' end
    local rec = removed[1]
    local s = { type = tk.type, owner = charId, x = p.x, y = p.y, z = p.z, heading = p.heading,
                createdAt = now(), expiresAt = L.expiry(rec.metadata, now(), SC.lifetimeHours) }
    if s.expiresAt <= now() then
        notify(src, ('The %s has fallen apart.'):format((t.label or tk.type):lower()), 'error')
        return false, 'worn_out'
    end
    local id = insertRow(s)
    if not id then
        Inv.add(c, rec.item, 1, rec.metadata, ctx)
        return false, 'db_error'
    end
    s.id = id
    list[id] = s
    TriggerClientEvent('MULTIinventory:cl:stationAdd', -1, view(s))
    if InvLog then
        InvLog.write('station', { actorSrc = src, targetCharId = charId, from = c.id, item = t.item, count = 1,
                                  data = { op = 'place', id = id, type = s.type, x = s.x, y = s.y, z = s.z, expiresAt = s.expiresAt } })
    end
    local hours = math.max(1, math.floor((s.expiresAt - now()) / 3600 + 0.5))
    notify(src, ('%s set up. It will last about %d hours.'):format(t.label or tk.type, hours), 'success')
    return true, view(s)
end

function Stations.pickup(src, d)
    if SC.allowPickup == false then return false, 'disabled' end
    local s = Stations.get(d.id)
    if not s then return false, 'gone' end
    local charId = charOf(src)
    if s.owner ~= charId and not isAdmin(src) then return false, 'not_owner' end
    local dd = L.dist(pedPos(src), s)
    if dd and dd > (L.num(SC.interactDistance) or 2.5) + 2.0 then return false, 'too_far' end
    local t = Stations.typeOf(s.type)
    local c, err = Actions.ref(src, 'player')
    if not c then return false, err end
    local left = math.max(0, s.expiresAt - now())
    local meta = { expiresAt = s.expiresAt,
                   description = ('Already used - it will last about %d more hours.'):format(math.max(1, math.floor(left / 3600 + 0.5))) }
    local ok = Inv.add(c, t.item, 1, meta, { src = src, reason = 'station_pickup', to = c.id })
    if not ok then return false, 'no_room' end
    remove(s.id, 'pickup')
    if InvLog then
        InvLog.write('station', { actorSrc = src, targetCharId = s.owner, to = c.id, item = t.item, count = 1,
                                  data = { op = 'pickup', id = s.id, type = s.type } })
    end
    return true
end

-- ------------------------------------------------------------
-- using a station (target)
-- ------------------------------------------------------------
function Stations.use(src, d)
    if not SC.enabled then return false, 'disabled' end
    local pos = pedPos(src)
    local reach = (L.num(SC.interactDistance) or 2.5) + 2.0
    local s
    if d.id ~= nil then
        local st = Stations.get(d.id)
        if not st then return false, 'gone' end
        local dd = L.dist(pos, st)
        if dd and dd > reach then return false, 'too_far' end
        s = { type = st.type, x = st.x, y = st.y, z = st.z, id = st.id }
    else
        if SC.worldProps == false then return false, 'disabled' end
        local stype = type(d.type) == 'string' and d.type or nil
        if not Stations.typeOf(stype) then return false, 'unknown_station' end
        local p = L.validPlacement(d)
        if not p then return false, 'bad_position' end
        local dd = L.dist(pos, p)
        if dd and dd > reach then return false, 'too_far' end
        s = { type = stype, x = p.x, y = p.y, z = p.z }
    end
    s['until'] = now() + (L.num(SC.sessionMinutes) or 10) * 60
    sessions[src] = s
    local t = Stations.typeOf(s.type)
    return true, { type = s.type, action = t.action, chapter = t.chapter, label = t.label }
end

-- ------------------------------------------------------------
-- actions, usables, loops
-- ------------------------------------------------------------
local REASON = {
    bad_token ='That placement expired - use the item again.', bad_position = 'You cannot put it there.',
    too_far = 'That is too far away.', missing = 'You no longer have it.', db_error = 'That did not work - try again.',
    gone = 'It is gone.', not_owner = 'That is not yours.', no_room = 'You have no room to carry it.',
    disabled = 'That is switched off on this server.', unknown_station = 'That is not a work station.',
}
Stations.REASON = REASON

local function wrap(fn)
    return function(src, d)
        local ok, res = fn(src, d or {})
        if not ok and REASON[res] then notify(src, REASON[res], 'error') end
        return ok, res
    end
end

Actions.register('stationList', function(src) return true, { me = charOf(src), stations = Stations.all(), types = (function()
    local out = {}
    for k, t in pairs(SC.types or {}) do out[k] = { label = t.label, model = t.model, worldModels = t.worldModels, icon = t.icon,
                                                    action = t.action, targetLabel = t.targetLabel } end
    return out
end)(), enabled = SC.enabled == true, worldProps = SC.worldProps ~= false, allowPickup = SC.allowPickup ~= false,
    interactDistance = L.num(SC.interactDistance) or 2.5, streamDistance = L.num(SC.streamDistance) or 120.0 } end)
Actions.register('stationPlace', wrap(Stations.place))
Actions.register('stationPickup', wrap(Stations.pickup))
Actions.register('stationUse', wrap(Stations.use))

if SC.enabled then
    for key, t in pairs(SC.types or {}) do
        if t.item then
            Usables.register(t.item, function(data)
                local src = data.source
                local ok, err = Stations.beginPlace(src, key, data.item)
                if not ok and err == 'disabled' then notify(src, REASON.disabled, 'error') end
            end, GetCurrentResourceName())
        end
    end
    Config.Log = Config.Log or {}
    Config.Log.actions = Config.Log.actions or {}
    if Config.Log.actions.station == nil then Config.Log.actions.station = true end
end

AddEventHandler('MULTIinventory:ready', function()
    if not SC.enabled then return end
    Stations.load()
    TriggerClientEvent('MULTIinventory:cl:stationsReset', -1, Stations.all())
    CreateThread(function()
        while true do
            Wait(60000)
            local ok, err = pcall(Stations.sweep)
            if not ok then print('^1[MULTIinventory] station sweep: ' .. tostring(err) .. '^7') end
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    tokens[src] = nil
    sessions[src] = nil
end)

Stations._list, Stations._sessions, Stations._tokens = list, sessions, tokens   -- tests
function Stations._reset() for k in pairs(list) do list[k] = nil end for k in pairs(sessions) do sessions[k] = nil end for k in pairs(tokens) do tokens[k] = nil end end
