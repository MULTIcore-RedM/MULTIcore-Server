-- ============================================================
-- MULTIcrafting :: server
-- Stations, recipes and crafting. Everything is decided here: the client only
-- says where it is crafting and which recipe; the server checks the station
-- (distance with OneSync), the job, the inputs, the tool and the room for the
-- output, and at the end takes the inputs and gives the output in one step.
-- Also the campfires players put down with the campfire item.
-- GPL v3, part of MULTIcore.
-- ============================================================

local MI = exports.MULTIinventory
local RSGCore = exports['rsg-core']:GetCoreObject()

Craft = {
    Recipes = {},   -- list in config order (validated)
    ById = {},      -- [id] = recipe
    Active = {},    -- [src] = { recipe, count, started, duration, ref, pos }
    Open = {},      -- [src] = station ref the screen was opened with
    Last = {},      -- [src] = { [kind] = GetGameTimer() of the last request } (rate limit)
    Fires = {},     -- [id] = { id, cid, coords, heading, expires }
    Placing = {},   -- [src] = GetGameTimer() until which a campfire may be put down
    ready = false,
}
local fireSeq = 0

local function debug(fmt, ...)
    if Config.Debug then print(('^5[MULTIcrafting]^7 ' .. fmt):format(...)) end
end

local function notify(src, key, kind, ...)
    local text = _L(key, ...)
    pcall(function() exports.MULTIcore:Notify(src, { text = text, title = _L('title'), type = kind or 'info' }) end)
end
Craft.Notify = notify

local function getPlayer(src)
    src = tonumber(src)
    return src and RSGCore.Functions.GetPlayer(src) or nil
end

--- The player's position (OneSync). Replaced by the self-test hook for pretend players.
function Craft.PlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

local function toVec(c)
    if type(c) ~= 'table' and type(c) ~= 'vector3' and type(c) ~= 'vector4' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    if not (x and y and z) then return nil end
    return vector3(x + 0.0, y + 0.0, z + 0.0)
end

-- per player and kind of request ('open', 'start'), so opening and crafting do not block each other
local function rateLimited(src, kind)
    local now = GetGameTimer()
    local t = Craft.Last[src] or {}
    Craft.Last[src] = t
    local last = t[kind or 'start']
    if last and now - last < Config.Craft.RateLimitMs then return true end
    t[kind or 'start'] = now
    return false
end

-- ------------------------------------------------------------
-- jobs
-- ------------------------------------------------------------
local function jobList(job)
    if job == nil then return nil end
    if type(job) == 'string' then return { job } end
    if type(job) == 'table' then return job end
    return nil
end

--- Does the player's job allow `job` (name or list) at `grade` or higher?
local function jobAllows(P, job, grade)
    local list = jobList(job)
    if not list then return true end
    local j = P and P.PlayerData and P.PlayerData.job
    if not j then return false end
    local ok = false
    for _, name in ipairs(list) do if name == j.name then ok = true break end end
    if not ok then return false end
    local level = tonumber(j.grade and j.grade.level) or 0
    if level < (tonumber(grade) or 0) then return false end
    if Config.RequireDuty and j.onduty == false then return false end
    return true
end
Craft.JobAllows = jobAllows

-- ------------------------------------------------------------
-- stations
-- ------------------------------------------------------------
local stationById = {}
for _, s in ipairs(Config.Stations or {}) do
    if s.id and s.enabled ~= false then stationById[s.id] = s end
end

local function typeDef(t) local d = Config.StationTypes[t] return d and d.enabled ~= false and d or nil end

local function typeLabel(t)
    local d = Config.StationTypes[t]
    return d and _L(d.label or ('station_' .. t)) or t
end

local function nearestFire(pos, maxDist)
    local best, bestD
    for _, f in pairs(Craft.Fires) do
        local d = #(pos - f.coords)
        if d <= maxDist and (not bestD or d < bestD) then best, bestD = f, d end
    end
    return best
end

--- Turns what the client sent into a checked station.
--- ref = { type = 'hand' } | { id = 'config station id' } | { type = 'campfire', fire = id } | { type = t, coords = {x,y,z} }
--- → station = { type, label, coords?, job?, grade?, fire? } or nil, err
function Craft.ResolveStation(src, ref)
    if type(ref) ~= 'table' then return nil, 'err_no_station' end

    if ref.type == 'hand' then
        if not typeDef('hand') then return nil, 'err_no_station' end
        return { type = 'hand', label = typeLabel('hand') }
    end

    local pos = Craft.PlayerCoords(src)
    if not pos then return nil, 'err_too_far' end

    -- a fixed station from config/stations.lua
    if ref.id ~= nil then
        local s = stationById[tostring(ref.id)]
        if not s then return nil, 'err_no_station' end
        local d = typeDef(s.type)
        if not d then return nil, 'err_no_station' end
        local c = toVec(s.coords)
        if not c or #(pos - c) > (s.radius or d.distance or 3.0) then return nil, 'err_too_far' end
        return { type = s.type, id = s.id, coords = c, label = s.label or typeLabel(s.type), job = s.job, grade = s.grade }
    end

    local t = ref.type
    local d = type(t) == 'string' and typeDef(t) or nil
    if not d or t == 'hand' then return nil, 'err_no_station' end
    local maxDist = d.distance or 3.0

    -- a campfire a player put down (the server knows where it is)
    if t == 'campfire' then
        local f
        if ref.fire ~= nil then
            f = Craft.Fires[tonumber(ref.fire) or -1]
            if f and #(pos - f.coords) > maxDist then return nil, 'err_too_far' end
        end
        f = f or nearestFire(pos, maxDist)
        if f then return { type = 'campfire', coords = f.coords, label = typeLabel('campfire'), fire = f.id } end
    end

    -- a prop that is part of the map (campfire, anvil ...): only the distance can be checked
    if Config.AllowWorldProps and type(d.worldProps) == 'table' and #d.worldProps > 0 then
        local c = toVec(ref.coords)
        if not c then return nil, 'err_no_station' end
        if #(pos - c) > maxDist then return nil, 'err_too_far' end
        return { type = t, coords = c, label = typeLabel(t), world = true }
    end
    return nil, 'err_no_station'
end

-- ------------------------------------------------------------
-- recipes
-- ------------------------------------------------------------
local function itemDef(name) return name and MI:GetItemDef(name) or nil end

local function itemLabel(name)
    local d = itemDef(name)
    return d and d.label or name
end

local function recipeLabel(r)
    if r.label then
        local t = _L(r.label)
        return t
    end
    return itemLabel(r.output.item)
end

--- Checks and normalises one recipe. → recipe or nil, why
local function normalize(r)
    if type(r) ~= 'table' or type(r.id) ~= 'string' or r.id == '' then return nil, 'no id' end
    if type(r.output) ~= 'table' or not itemDef(r.output.item) then return nil, 'unknown output item ' .. tostring(r.output and r.output.item) end
    local out = {
        id = r.id, label = r.label, category = r.category or 'other',
        time = math.max(0, tonumber(r.time) or 5),
        job = r.job, grade = tonumber(r.grade) or 0, tool = r.tool,
        output = { item = r.output.item, amount = math.max(1, math.floor(tonumber(r.output.amount) or 1)) },
        inputs = {}, stations = {},
    }
    if out.tool and not itemDef(out.tool) then return nil, 'unknown tool ' .. tostring(out.tool) end
    for _, i in ipairs(r.inputs or {}) do
        if type(i) ~= 'table' or not itemDef(i.item) then return nil, 'unknown input item ' .. tostring(i and i.item) end
        out.inputs[#out.inputs + 1] = { item = i.item, amount = math.max(1, math.floor(tonumber(i.amount) or 1)) }
    end
    if #out.inputs == 0 then return nil, 'no inputs' end
    for _, s in ipairs(type(r.stations) == 'table' and r.stations or { r.stations }) do
        if Config.StationTypes[s] then out.stations[s] = true end
    end
    if not next(out.stations) then return nil, 'no known station type' end
    return out
end

function Craft.AddRecipe(r)
    local n, why = normalize(r)
    if not n then
        print(('^3[MULTIcrafting] recipe "%s" skipped: %s^7'):format(tostring(type(r) == 'table' and r.id), why))
        return false, why
    end
    if Craft.ById[n.id] then
        for i, old in ipairs(Craft.Recipes) do
            if old.id == n.id then Craft.Recipes[i] = n break end
        end
    else
        Craft.Recipes[#Craft.Recipes + 1] = n
    end
    Craft.ById[n.id] = n
    return true
end

function Craft.RemoveRecipe(id)
    if not Craft.ById[id] then return false end
    Craft.ById[id] = nil
    for i, r in ipairs(Craft.Recipes) do
        if r.id == id then table.remove(Craft.Recipes, i) break end
    end
    return true
end

--- How many of this recipe the satchel holds inputs for (0 = none).
local function maxFromInputs(pid, r)
    local max = math.huge
    for _, i in ipairs(r.inputs) do
        max = math.min(max, math.floor((MI:Count(pid, i.item) or 0) / i.amount))
    end
    return max == math.huge and 0 or max
end

--- Every check except the station distance. → true | false, err
local function checkRecipe(src, P, pid, r, station, count)
    if not r.stations[station.type] then return false, 'err_wrong_station' end
    if not jobAllows(P, station.job, station.grade) then return false, 'err_station_job' end
    if not jobAllows(P, r.job, r.grade) then return false, 'err_job' end
    if r.tool and (MI:Count(pid, r.tool) or 0) < 1 then return false, 'err_tool' end
    if maxFromInputs(pid, r) < count then return false, 'err_missing' end
    local ok = MI:CanAdd(pid, r.output.item, r.output.amount * count)
    if not ok then return false, 'err_no_room' end
    return true
end

-- what the menu shows for one recipe
local function recipeView(P, pid, r, station)
    local def = itemDef(r.output.item) or {}
    local v = {
        id = r.id, label = recipeLabel(r), category = r.category, time = r.time,
        output = { item = r.output.item, label = def.label or r.output.item, image = def.image, amount = r.output.amount, desc = def.description },
        inputs = {},
        jobOk = jobAllows(P, r.job, r.grade) and jobAllows(P, station.job, station.grade),
        max = 0,
    }
    for _, i in ipairs(r.inputs) do
        local d = itemDef(i.item) or {}
        v.inputs[#v.inputs + 1] = { item = i.item, label = d.label or i.item, image = d.image, amount = i.amount, have = MI:Count(pid, i.item) or 0 }
    end
    if r.tool then
        local d = itemDef(r.tool) or {}
        v.tool = { item = r.tool, label = d.label or r.tool, image = d.image, have = (MI:Count(pid, r.tool) or 0) > 0 }
    end
    if r.job then
        local list = jobList(r.job)
        local labels = {}
        for _, name in ipairs(list) do
            local j = RSGCore.Shared.Jobs[name]
            labels[#labels + 1] = j and j.label or name
        end
        v.jobLabel = table.concat(labels, ', ')
    end
    local max = maxFromInputs(pid, r)
    if v.tool and not v.tool.have then max = 0 end
    if not v.jobOk then max = 0 end
    v.max = math.min(max, Config.Craft.MaxBatch)
    return v
end

-- ------------------------------------------------------------
-- crafting
-- ------------------------------------------------------------

--- What the crafting screen at this station shows. → state | nil, err
function Craft.View(src, ref)
    local P = getPlayer(src)
    if not P then return nil, 'err_no_player' end
    local station, err = Craft.ResolveStation(src, ref)
    if not station then return nil, err end
    local pid = MI:PlayerInv(src)
    local list = {}
    for _, r in ipairs(Craft.Recipes) do
        if r.stations[station.type] then list[#list + 1] = recipeView(P, pid, r, station) end
    end
    local state = { station = { type = station.type, label = station.label }, recipes = list, maxBatch = Config.Craft.MaxBatch }
    if station.fire then
        local f = Craft.Fires[station.fire]
        state.fire = { id = station.fire, canPutOut = f and Craft.CanPutOut(src, f) or false }
    end
    return state
end

--- Opens the crafting screen (server side: remembers the station).
function Craft.OpenFor(src, ref)
    local state, err = Craft.View(src, ref)
    if not state then return nil, err end
    Craft.Open[src] = ref
    return state
end

--- Takes the inputs and gives the output in one step. → true | false, err
local function doCraft(src, pid, r, count)
    local removed = {}
    local function giveBack()
        for _, x in ipairs(removed) do MI:AddItem(pid, x.item, x.amount, nil, nil, 'crafting rollback') end
    end
    for _, i in ipairs(r.inputs) do
        local need = i.amount * count
        local ok = MI:RemoveItem(pid, i.item, need, nil, nil, 'crafting')
        if not ok then giveBack() return false, 'err_missing' end
        removed[#removed + 1] = { item = i.item, amount = need }
    end

    local total = r.output.amount * count
    local def = itemDef(r.output.item) or {}
    local ok, err
    if def.type == 'weapon' or def.unique then
        -- one at a time; weapons get their own serial
        local added = {}
        for _ = 1, total do
            local info = def.type == 'weapon' and MI:WeaponNew(r.output.item) or nil
            local good, e, slot = MI:AddItem(pid, r.output.item, 1, info, nil, 'crafting')
            if not good then ok, err = false, e break end
            added[#added + 1] = slot
        end
        if ok == false then
            for _, slot in ipairs(added) do MI:RemoveItem(pid, r.output.item, 1, slot, nil, 'crafting rollback') end
        else
            ok = true
        end
    else
        ok, err = MI:AddItem(pid, r.output.item, total, nil, nil, 'crafting')
    end
    if not ok then
        giveBack()
        debug('output %s x%d refused for %s: %s', r.output.item, total, src, tostring(err))
        return false, 'err_no_room'
    end
    return true
end

--- Starts crafting `count` of a recipe at the station the screen was opened with.
--- → true, durationMs | false, err
function Craft.Start(src, id, count, ref)
    src = tonumber(src)
    if Craft.Active[src] then return false, 'err_busy' end
    if rateLimited(src, 'start') then return false, 'err_rate' end
    local P = getPlayer(src)
    if not P then return false, 'err_no_player' end
    local r = Craft.ById[tostring(id)]
    if not r then return false, 'err_unknown_recipe' end
    count = math.floor(tonumber(count) or 1)
    if count < 1 or count > Config.Craft.MaxBatch then return false, 'err_bad_amount' end
    ref = ref or Craft.Open[src]
    local station, err = Craft.ResolveStation(src, ref)
    if not station then return false, err end
    local pid = MI:PlayerInv(src)
    local ok, e = checkRecipe(src, P, pid, r, station, count)
    if not ok then return false, e end
    local duration = math.floor(r.time * count * 1000)
    Craft.Active[src] = { recipe = r, count = count, started = GetGameTimer(), duration = duration, ref = ref, cid = P.PlayerData.citizenid }
    debug('%s started %s x%d at %s (%d ms)', src, r.id, count, station.type, duration)
    return true, duration
end

--- Ends the craft that is running: checks the time, the station and everything again,
--- then takes the inputs and gives the output. force (self-test only) skips the time.
--- → true, { item, amount, label } | false, err
function Craft.Finish(src, force)
    src = tonumber(src)
    local a = Craft.Active[src]
    if not a then return false, 'err_not_crafting' end
    local now = GetGameTimer()
    if not force and now - a.started < a.duration - Config.Craft.TimeToleranceMs then
        return false, 'err_too_early'      -- keep the craft: the real finish may still come
    end
    Craft.Active[src] = nil
    local P = getPlayer(src)
    if not P or P.PlayerData.citizenid ~= a.cid then return false, 'err_no_player' end
    local station, err = Craft.ResolveStation(src, a.ref)
    if not station then return false, err end
    local pid = MI:PlayerInv(src)
    local r = a.recipe
    local ok, e = checkRecipe(src, P, pid, r, station, a.count)
    if not ok then return false, e end
    ok, e = doCraft(src, pid, r, a.count)
    if not ok then return false, e end
    local total = r.output.amount * a.count
    debug('%s crafted %s x%d -> %s x%d', src, r.id, a.count, r.output.item, total)
    TriggerEvent('MULTIcrafting:crafted', src, r.id, a.count, r.output.item, total)
    return true, { item = r.output.item, amount = total, label = itemLabel(r.output.item) }
end

function Craft.Cancel(src)
    src = tonumber(src)
    if not Craft.Active[src] then return false end
    Craft.Active[src] = nil
    return true
end

-- forget crafts whose client never came back
CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for src, a in pairs(Craft.Active) do
            if now - a.started > a.duration + Config.Craft.MaxWaitMs then Craft.Active[src] = nil end
        end
    end
end)

-- ------------------------------------------------------------
-- placed campfires
-- ------------------------------------------------------------
local function fireList()
    local out = {}
    for id, f in pairs(Craft.Fires) do
        out[#out + 1] = { id = id, x = f.coords.x, y = f.coords.y, z = f.coords.z, h = f.heading }
    end
    return out
end

local function broadcastFires() TriggerClientEvent('MULTIcrafting:client:fires', -1, fireList()) end

function Craft.CanPutOut(src, f)
    if Config.Campfire.AnyoneCanPutOut then return true end
    local P = getPlayer(src)
    if P and P.PlayerData.citizenid == f.cid then return true end
    return IsPlayerAceAllowed(src, Config.Campfire.AdminAce) == true
end

local function firesOf(cid)
    local n = 0
    for _, f in pairs(Craft.Fires) do if f.cid == cid then n = n + 1 end end
    return n
end

--- Puts a campfire down for the player at `coords` (takes one campfire item). → id | false, err
function Craft.PlaceFire(src, coords, heading)
    local P = getPlayer(src)
    if not P then return false, 'err_no_player' end
    local c = toVec(coords)
    local pos = Craft.PlayerCoords(src)
    if not c or not pos then return false, 'err_too_far' end
    if #(pos - c) > Config.Campfire.PlaceDistance then return false, 'err_too_far' end
    local cid = P.PlayerData.citizenid
    if firesOf(cid) >= Config.Campfire.MaxPerPlayer then return false, 'err_fire_limit' end
    for _, f in pairs(Craft.Fires) do
        if #(f.coords - c) < Config.Campfire.MinSpacing then return false, 'err_fire_spacing' end
    end
    local pid = MI:PlayerInv(src)
    if not MI:RemoveItem(pid, Config.Campfire.Item, 1, nil, nil, 'campfire placed') then return false, 'err_no_campfire' end
    fireSeq = fireSeq + 1
    Craft.Fires[fireSeq] = {
        id = fireSeq, cid = cid, coords = c, heading = tonumber(heading) or 0.0,
        expires = os.time() + Config.Campfire.LifetimeMinutes * 60,
    }
    broadcastFires()
    debug('%s put a campfire down (#%d)', src, fireSeq)
    return fireSeq
end

function Craft.RemoveFire(id)
    if not Craft.Fires[id] then return false end
    Craft.Fires[id] = nil
    broadcastFires()
    return true
end

-- the campfire item
local function onCampfireUse(src)
    src = tonumber(src)
    if not Config.Campfire.Enabled then return end
    local P = getPlayer(src)
    if not P then return end
    if Craft.Active[src] then return notify(src, 'err_busy', 'error') end
    if firesOf(P.PlayerData.citizenid) >= Config.Campfire.MaxPerPlayer then return notify(src, 'err_fire_limit', 'error') end
    Craft.Placing[src] = GetGameTimer() + Config.Campfire.PlaceMs + 15000
    TriggerClientEvent('MULTIcrafting:client:placeFire', src)
end

-- burnt-out fires
CreateThread(function()
    while true do
        Wait(10000)
        local now, changed = os.time(), false
        for id, f in pairs(Craft.Fires) do
            if now >= f.expires then Craft.Fires[id] = nil changed = true end
        end
        if changed then broadcastFires() end
    end
end)

-- ------------------------------------------------------------
-- start-up: items, recipes, the campfire usable
-- ------------------------------------------------------------
CreateThread(function()
    local t = 0
    while (GetResourceState('MULTIinventory') ~= 'started' or not MI:IsReady()) and t < 1200 do Wait(250) t = t + 1 end
    if GetResourceState('MULTIinventory') ~= 'started' then
        print('^1[MULTIcrafting] MULTIinventory is not running; crafting is off^7')
        return
    end
    local added = 0
    for name, def in pairs(Config.NewItems or {}) do
        if not MI:GetItemDef(name) and MI:RegisterItem(def) then added = added + 1 end
    end
    for _, r in ipairs(Config.Recipes or {}) do Craft.AddRecipe(r) end
    if Config.Campfire.Enabled and MI:GetItemDef(Config.Campfire.Item) then
        MI:RegisterUsable(Config.Campfire.Item, function(src) onCampfireUse(src) end, { builtin = true, face = 'multi' })
    end
    Craft.ready = true
    print(('[MULTIcrafting] %d items added to the registry, %d recipes ready'):format(added, #Craft.Recipes))
end)

-- ------------------------------------------------------------
-- net callbacks
-- ------------------------------------------------------------
lib.callback.register('MULTIcrafting:open', function(src, ref)
    if not Craft.ready then return { ok = false, err = _L('err_not_ready') } end
    if rateLimited(src, 'open') then return { ok = false, err = _L('err_rate') } end
    local state, err = Craft.OpenFor(src, ref)
    if not state then return { ok = false, err = _L(err) } end
    return { ok = true, state = state }
end)

lib.callback.register('MULTIcrafting:refresh', function(src)
    local ref = Craft.Open[src]
    if not ref then return { ok = false } end
    local state = Craft.View(src, ref)
    return state and { ok = true, state = state } or { ok = false }
end)

lib.callback.register('MULTIcrafting:start', function(src, id, count)
    if not Craft.Open[src] then return { ok = false, err = _L('err_no_station') } end
    local ok, res = Craft.Start(src, id, count)
    if not ok then return { ok = false, err = _L(res) } end
    local st = Craft.ResolveStation(src, Craft.Open[src])
    local r = Craft.ById[id]
    return { ok = true, duration = res, station = st and st.type or 'hand', label = r and recipeLabel(r) or id }
end)

lib.callback.register('MULTIcrafting:finish', function(src)
    local ok, res = Craft.Finish(src, false)
    if not ok then
        if res ~= 'err_too_early' then notify(src, res, 'error') end
        return { ok = false, err = res }
    end
    notify(src, 'crafted', 'success', res.amount, res.label)
    return { ok = true }
end)

RegisterNetEvent('MULTIcrafting:server:cancel', function()
    if Craft.Cancel(source) then notify(source, 'cancelled', 'info') end
end)

RegisterNetEvent('MULTIcrafting:server:close', function()
    Craft.Open[source] = nil
end)

lib.callback.register('MULTIcrafting:fires', function() return fireList() end)

lib.callback.register('MULTIcrafting:placeFire', function(src, coords, heading)
    local until_ = Craft.Placing[src]
    Craft.Placing[src] = nil
    if not until_ or GetGameTimer() > until_ then return false end
    local id, err = Craft.PlaceFire(src, coords, heading)
    if not id then notify(src, err, 'error') return false end
    notify(src, 'fire_placed', 'success')
    return id
end)

RegisterNetEvent('MULTIcrafting:server:placeCancel', function() Craft.Placing[source] = nil end)

lib.callback.register('MULTIcrafting:putOut', function(src, id)
    local f = Craft.Fires[tonumber(id) or -1]
    if not f then return false end
    if not Craft.CanPutOut(src, f) then notify(src, 'err_not_yours', 'error') return false end
    local pos = Craft.PlayerCoords(src)
    if not pos or #(pos - f.coords) > (Config.StationTypes.campfire.distance or 3.0) + 1.0 then notify(src, 'err_too_far', 'error') return false end
    Craft.RemoveFire(f.id)
    Craft.Open[src] = nil
    notify(src, 'fire_out', 'info')
    return true
end)

AddEventHandler('playerDropped', function()
    local src = source
    Craft.Active[src], Craft.Open[src], Craft.Placing[src], Craft.Last[src] = nil, nil, nil, nil
end)
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    src = tonumber(src)
    if src then Craft.Active[src], Craft.Open[src], Craft.Placing[src] = nil, nil, nil end
end)

-- ------------------------------------------------------------
-- exports (server)
-- ------------------------------------------------------------
--- Every recipe (copies). → list
exports('GetRecipes', function() return Craft.Recipes end)
--- One recipe or nil.
exports('GetRecipe', function(id) return Craft.ById[id] end)
--- Adds or replaces a recipe at runtime (same shape as config/recipes.lua). → true | false, why
exports('AddRecipe', function(def) return Craft.AddRecipe(def) end)
--- Removes a recipe. → bool
exports('RemoveRecipe', function(id) return Craft.RemoveRecipe(id) end)
--- Could the player craft `count` of a recipe at this station now? → true | false, err (locale key)
exports('CanCraft', function(src, id, count, ref)
    local P = getPlayer(src)
    if not P then return false, 'err_no_player' end
    local r = Craft.ById[id]
    if not r then return false, 'err_unknown_recipe' end
    local station, err = Craft.ResolveStation(src, ref or { type = 'hand' })
    if not station then return false, err end
    return checkRecipe(src, P, MI:PlayerInv(src), r, station, math.max(1, math.floor(tonumber(count) or 1)))
end)
--- Opens the crafting screen for a player at a station ref (e.g. { type = 'hand' } or { id = 'kitchen_valentine' }). → bool
exports('OpenMenu', function(src, ref)
    local state, err = Craft.OpenFor(src, ref)
    if not state then notify(src, err, 'error') return false end
    TriggerClientEvent('MULTIcrafting:client:openState', src, state, ref)
    return true
end)
--- Are the recipes loaded?
exports('IsReady', function() return Craft.ready end)
--- Is the player crafting right now?
exports('IsCrafting', function(src) return Craft.Active[tonumber(src)] ~= nil end)
--- Placed campfires: list of { id, x, y, z, h }.
exports('GetCampfires', function() return fireList() end)
--- Removes a placed campfire. → bool
exports('RemoveCampfire', function(id) return Craft.RemoveFire(tonumber(id)) end)

-- ------------------------------------------------------------
-- self-test hooks (only with  setr multicore_selftest true; never on a live server)
-- ------------------------------------------------------------
if GetConvar('multicore_selftest', 'false') == 'true' then
    local fake = {}
    local real = Craft.PlayerCoords
    Craft.PlayerCoords = function(src)
        local c = fake[tonumber(src) or -1]
        if c then return c end
        return real(src)
    end
    --- Gives a pretend player (no ped) a position.
    exports('_TestSetCoords', function(src, x, y, z)
        src = tonumber(src)
        if not src then return false end
        fake[src] = x and vector3(x + 0.0, y + 0.0, z + 0.0) or nil
        return true
    end)
    --- Opens, starts and (force = true: at once) finishes a craft. → ok, err | result
    exports('_TestCraft', function(src, id, count, ref, force)
        src = tonumber(src)
        Craft.Last[src] = nil
        Craft.Active[src] = nil
        local state, err = Craft.OpenFor(src, ref)
        if not state then return false, err end
        local ok, e = Craft.Start(src, id, count)
        if not ok then return false, e end
        return Craft.Finish(src, force ~= false)
    end)
    --- Opens and starts a craft without finishing it. → ok, durationMs | false, err
    exports('_TestStart', function(src, id, count, ref)
        src = tonumber(src)
        Craft.Last[src] = nil
        local state, err = Craft.OpenFor(src, ref)
        if not state then return false, err end
        return Craft.Start(src, id, count)
    end)
    --- Finishes the running craft (force = true skips the time check). → ok, err | result
    exports('_TestFinish', function(src, force) return Craft.Finish(src, force == true) end)
    exports('_TestCancel', function(src) return Craft.Cancel(src) end)
    exports('_TestView', function(src, ref) return Craft.View(src, ref) end)
    --- Puts a campfire down as if the player had used the item and chosen the spot.
    exports('_TestPlaceFire', function(src, x, y, z) return Craft.PlaceFire(tonumber(src), { x = x, y = y, z = z }, 0.0) end)
    exports('_TestReset', function(src)
        src = tonumber(src)
        Craft.Active[src], Craft.Open[src], Craft.Last[src], Craft.Placing[src] = nil, nil, nil, nil
        return true
    end)
end
