-- ============================================================
-- MULTItarget :: engine (client)
-- MULTIcore's own target system. Keeps every target scripts add (zones, entities,
-- models, global types), finds the options for what the player looks at and runs
-- the one they pick. The API has the same calls as ox_target, so scripts written for
-- ox_target work unchanged (MULTItarget provides 'ox_target' and answers its exports).
-- Written for MULTIcore (GPL v3).
-- ============================================================

MT = MT or {}
MT.API = {}

local API = MT.API
local nextZoneId = 0

local zones = {}            -- [id] = zone
local zoneByName = {}       -- [name] = id
local localEnts = {}        -- [entity handle] = { options }
local netEnts = {}          -- [net id] = { options }
local models = {}           -- [model hash] = { options }
local globals = { ped = {}, player = {}, vehicle = {}, object = {}, option = {} }
local entityLabels = {}     -- [entity] = { title, sub }
local modelLabels = {}      -- [hash] = { title, sub }
local itemNames = {}        -- [item] = true, every item an option asks for
MT.ItemNames = itemNames

-- ------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------

local function owner()
    local res = GetInvokingResource()
    if not res or res == '' then res = GetCurrentResourceName() end
    return res
end

local function vec(c)
    if not c then return nil end
    if type(c) == 'vector3' then return c end
    if type(c) == 'vector4' then return vector3(c.x, c.y, c.z) end
    if type(c) == 'table' then
        local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
        if x and y then return vector3(x, y, z or 0.0) end
    end
    return nil
end

local function noteItems(o)
    local it = o.items
    if type(it) == 'string' then itemNames[it] = true
    elseif type(it) == 'table' then
        for k, v in pairs(it) do
            if type(k) == 'string' then itemNames[k] = true elseif type(v) == 'string' then itemNames[v] = true end
        end
    end
end

-- options may be one option or a list; each gets its owner and a name
local function optionList(options, res)
    if type(options) ~= 'table' then return {} end
    local list = (options.label or options.name or options.onSelect) and { options } or options
    local out = {}
    for i, o in ipairs(list) do
        if type(o) == 'table' then
            o.resource = o.resource or res
            if o.name == nil then o.name = ('%s:%s:%d'):format(res, tostring(o.label), i) end
            noteItems(o)
            out[#out + 1] = o
        end
    end
    return out
end

local function append(list, opts)
    for _, o in ipairs(opts) do
        -- an option with the same name replaces the old one, as in ox_target
        for i = #list, 1, -1 do if list[i].name == o.name then table.remove(list, i) end end
        list[#list + 1] = o
    end
end

local function nameSet(names)
    if names == nil then return nil end
    local set = {}
    if type(names) == 'table' then for _, n in ipairs(names) do set[n] = true end else set[names] = true end
    return set
end

local function strip(list, names)
    if not list then return end
    local set = nameSet(names)
    for i = #list, 1, -1 do
        if set == nil or set[list[i].name] then table.remove(list, i) end
    end
end

local function many(v)
    if type(v) == 'table' and v[1] ~= nil then return v end
    return { v }
end

local function hashOf(m)
    if type(m) == 'string' then return joaat(m) end
    return tonumber(m)
end

-- ------------------------------------------------------------
-- zones
-- ------------------------------------------------------------

local function contains(z, p)
    if z.kind == 'sphere' then
        return #(p - z.coords) <= z.radius
    elseif z.kind == 'box' then
        local d = p - z.coords
        local r = math.rad(-(z.rotation or 0.0))
        local c, s = math.cos(r), math.sin(r)
        local lx = d.x * c - d.y * s
        local ly = d.x * s + d.y * c
        return math.abs(lx) <= z.size.x / 2 and math.abs(ly) <= z.size.y / 2 and math.abs(d.z) <= z.size.z / 2
    elseif z.kind == 'poly' then
        if math.abs(p.z - z.coords.z) > z.thickness / 2 then return false end
        local inside, pts = false, z.points
        local j = #pts
        for i = 1, #pts do
            local a, b = pts[i], pts[j]
            if (a.y > p.y) ~= (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x then
                inside = not inside
            end
            j = i
        end
        return inside
    end
    return false
end
MT.ZoneContains = contains

local function addZone(z, data)
    nextZoneId = nextZoneId + 1
    z.id = nextZoneId
    z.resource = owner()
    z.name = data.name
    z.label = data.label
    z.options = optionList(data.options, z.resource)
    z.distance = tonumber(data.distance)
    if z.name then
        if zoneByName[z.name] then zones[zoneByName[z.name]] = nil end
        zoneByName[z.name] = z.id
    end
    zones[z.id] = z
    return z.id
end

function API.addSphereZone(data)
    local c = type(data) == 'table' and vec(data.coords)
    if not c then return nil end
    return addZone({ kind = 'sphere', coords = c, radius = tonumber(data.radius) or 1.5 }, data)
end

function API.addBoxZone(data)
    local c = type(data) == 'table' and vec(data.coords)
    if not c then return nil end
    local s = vec(data.size) or vector3(2.0, 2.0, 2.0)
    return addZone({ kind = 'box', coords = c, size = s, rotation = tonumber(data.rotation) or 0.0 }, data)
end

function API.addPolyZone(data)
    if type(data) ~= 'table' or type(data.points) ~= 'table' or #data.points < 3 then return nil end
    local pts, zsum = {}, 0.0
    for i, p in ipairs(data.points) do
        local v = vec(p)
        if not v then return nil end
        pts[i] = v
        zsum = zsum + v.z
    end
    return addZone({ kind = 'poly', points = pts, coords = vector3(0.0, 0.0, zsum / #pts),
        thickness = tonumber(data.thickness) or 4.0 }, data)
end

function API.removeZone(id)
    if type(id) == 'string' then id = zoneByName[id] end
    local z = id and zones[id]
    if not z then return end
    if z.name and zoneByName[z.name] == id then zoneByName[z.name] = nil end
    zones[id] = nil
end

function API.zoneExists(id)
    if type(id) == 'string' then return zoneByName[id] ~= nil end
    return zones[id] ~= nil
end

-- ------------------------------------------------------------
-- entities, models, global types
-- ------------------------------------------------------------

function API.addLocalEntity(entities, options)
    local opts = optionList(options, owner())
    for _, e in ipairs(many(entities)) do
        e = tonumber(e)
        if e then localEnts[e] = localEnts[e] or {} append(localEnts[e], opts) end
    end
end

function API.removeLocalEntity(entities, names)
    for _, e in ipairs(many(entities)) do
        e = tonumber(e)
        if e and localEnts[e] then
            strip(localEnts[e], names)
            if #localEnts[e] == 0 then localEnts[e] = nil end
        end
    end
end

function API.addEntity(netIds, options)
    local opts = optionList(options, owner())
    for _, n in ipairs(many(netIds)) do
        n = tonumber(n)
        if n then netEnts[n] = netEnts[n] or {} append(netEnts[n], opts) end
    end
end

function API.removeEntity(netIds, names)
    for _, n in ipairs(many(netIds)) do
        n = tonumber(n)
        if n and netEnts[n] then
            strip(netEnts[n], names)
            if #netEnts[n] == 0 then netEnts[n] = nil end
        end
    end
end

function API.addModel(list, options)
    local opts = optionList(options, owner())
    for _, m in ipairs(many(list)) do
        local h = hashOf(m)
        if h then models[h] = models[h] or {} append(models[h], opts) end
    end
end

function API.removeModel(list, names)
    for _, m in ipairs(many(list)) do
        local h = hashOf(m)
        if h and models[h] then
            strip(models[h], names)
            if #models[h] == 0 then models[h] = nil end
        end
    end
end

for kind, key in pairs({ Ped = 'ped', Player = 'player', Vehicle = 'vehicle', Object = 'object', Option = 'option' }) do
    API['addGlobal' .. kind] = function(options) append(globals[key], optionList(options, owner())) end
    API['removeGlobal' .. kind] = function(names) strip(globals[key], names) end
end

-- headings shown above the list (MULTItarget only)
function API.setEntityLabel(entity, title, sub)
    entity = tonumber(entity)
    if entity then entityLabels[entity] = title and { title = title, sub = sub } or nil end
end

function API.setModelLabel(model, title, sub)
    local h = hashOf(model)
    if h then modelLabels[h] = title and { title = title, sub = sub } or nil end
end

function API.hasEntityOptions(entity)
    entity = tonumber(entity)
    if not entity then return false end
    if localEnts[entity] and #localEnts[entity] > 0 then return true end
    if NetworkGetEntityIsNetworked(entity) then
        local l = netEnts[NetworkGetNetworkIdFromEntity(entity)]
        if l and #l > 0 then return true end
    end
    local l = models[GetEntityModel(entity)]
    return l ~= nil and #l > 0
end

-- true when a zone with options lies within `radius` metres of `coords`;
-- zones of the resource named `ignore` don't count (pass your own name to skip your zones)
function API.hasZoneNear(coords, radius, ignore)
    local p = vec(coords)
    if not p then return false end
    radius = tonumber(radius) or 1.5
    for _, z in pairs(zones) do
        if z.resource ~= ignore and z.options and #z.options > 0 then
            if contains(z, p) then return true end
            local reach = (z.kind == 'sphere' and z.radius)
                or (z.kind == 'box' and math.max(z.size.x, z.size.y) / 2)
            if reach and #(p - z.coords) <= reach + radius then return true end
        end
    end
    return false
end

-- a script stopped: its targets go with it
AddEventHandler('onClientResourceStop', function(res)
    local function drop(list) for i = #list, 1, -1 do if list[i].resource == res then table.remove(list, i) end end end
    for id, z in pairs(zones) do
        if z.resource == res then API.removeZone(id) else drop(z.options) end
    end
    for _, t in ipairs({ localEnts, netEnts, models }) do
        for k, list in pairs(t) do
            drop(list)
            if #list == 0 then t[k] = nil end
        end
    end
    for _, list in pairs(globals) do drop(list) end
end)

-- local entities that were deleted without being removed
CreateThread(function()
    while true do
        Wait(30000)
        for e in pairs(localEnts) do if not DoesEntityExist(e) then localEnts[e] = nil end end
        for e in pairs(entityLabels) do if not DoesEntityExist(e) then entityLabels[e] = nil end end
    end
end)

-- ------------------------------------------------------------
-- checks on an option
-- ------------------------------------------------------------

local RSGCore = nil
local function playerData()
    if not RSGCore then
        local ok, core = pcall(function() return exports['rsg-core']:GetCoreObject() end)
        if ok then RSGCore = core end
    end
    if not RSGCore or type(RSGCore.Functions) ~= 'table' then return {} end
    local ok, pd = pcall(RSGCore.Functions.GetPlayerData)
    return ok and type(pd) == 'table' and pd or {}
end
MT.PlayerData = playerData

local function gradeOf(g)
    if type(g) ~= 'table' then return 0 end
    local gr = g.grade
    if type(gr) == 'table' then return tonumber(gr.level or gr.grade) or 0 end
    return tonumber(gr) or 0
end

local function groupOk(groups)
    if groups == nil then return true end
    local pd = playerData()
    local have = {}
    if pd.job and pd.job.name then have[pd.job.name] = gradeOf(pd.job) end
    if pd.gang and pd.gang.name then have[pd.gang.name] = gradeOf(pd.gang) end
    if pd.citizenid then have[pd.citizenid] = 0 end
    if type(groups) == 'string' then return have[groups] ~= nil end
    if type(groups) ~= 'table' then return true end
    if groups[1] ~= nil then
        for _, n in ipairs(groups) do if have[n] then return true end end
        return false
    end
    for n, min in pairs(groups) do
        if have[n] and have[n] >= (tonumber(min) or 0) then return true end
    end
    return false
end

MT.ItemCounts = {}          -- filled from the server when targeting starts (client/main.lua)

local function itemOk(items, any)
    if items == nil then return true end
    local counts = MT.ItemCounts
    local function has(name, n) return (counts[name] or 0) >= (tonumber(n) or 1) end
    if type(items) == 'string' then return has(items, 1) end
    local found, need = 0, 0
    for k, v in pairs(items) do
        local name, n = k, v
        if type(k) == 'number' then name, n = v, 1 end
        need = need + 1
        if has(name, n) then
            if any then return true end
            found = found + 1
        end
    end
    return found == need and need > 0
end

local function boneOk(o, entity, coords)
    if not o.bones then return true, nil end
    if not entity or entity == 0 then return false end
    local best, bestD = nil, nil
    for _, b in ipairs(many(o.bones)) do
        local idx = GetEntityBoneIndexByName(entity, b)
        if idx and idx ~= -1 then
            local d = #(coords - GetWorldPositionOfEntityBone(entity, idx))
            if not bestD or d < bestD then best, bestD = b, d end
        end
    end
    if bestD and bestD <= (Config.BoneDistance or 1.2) then return true, best end
    return false
end

local function usable(o, ctx)
    if ctx.distance > (tonumber(o.distance) or ctx.zoneDistance or Config.DefaultDistance or 2.5) then return false end
    if not groupOk(o.groups) then return false end
    if not itemOk(o.items, o.anyItem) then return false end
    local ok, bone = boneOk(o, ctx.entity, ctx.coords)
    if not ok then return false end
    if o.canInteract then
        local good, res = pcall(o.canInteract, ctx.entity, ctx.distance, ctx.coords, o.name, bone)
        if not good then
            if Config.Debug then print(('[MULTItarget] canInteract of %s failed: %s'):format(tostring(o.name), tostring(res))) end
            return false
        end
        if not res then return false end
    end
    return true
end

-- ------------------------------------------------------------
-- what is there for this hit?  entity may be 0, coords = where the ray ended
-- returns { { option, zone }... }, title, sub
-- ------------------------------------------------------------
function MT.Gather(entity, coords, distance, menu)
    local found, seen = {}, {}
    local title, sub
    local function take(list, ctx, zone)
        if not list then return end
        for _, o in ipairs(list) do
            if not seen[o] and (o.menuName or false) == (menu or false) and usable(o, ctx) then
                seen[o] = true
                found[#found + 1] = { option = o, zone = zone }
            end
        end
    end
    local ctx = { entity = entity, coords = coords, distance = distance }

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        local kind = GetEntityType(entity)
        local model = GetEntityModel(entity)
        take(localEnts[entity], ctx)
        if NetworkGetEntityIsNetworked(entity) then take(netEnts[NetworkGetNetworkIdFromEntity(entity)], ctx) end
        take(models[model], ctx)
        if kind == 1 then
            if IsPedAPlayer(entity) then take(globals.player, ctx) else take(globals.ped, ctx) end
        elseif kind == 2 then take(globals.vehicle, ctx)
        elseif kind == 3 then take(globals.object, ctx) end
        if kind ~= 0 then take(globals.option, ctx) end
        local l = entityLabels[entity] or modelLabels[model]
        if l then title, sub = l.title, l.sub end
    end

    for _, z in pairs(zones) do
        if contains(z, coords) then
            local zctx = { entity = entity, coords = coords, distance = distance, zoneDistance = z.distance }
            local before = #found
            take(z.options, zctx, z)
            if not title and #found > before and z.label then title = z.label end
        end
    end
    return found, title, sub
end

-- ------------------------------------------------------------
-- running a picked option
-- ------------------------------------------------------------
function MT.Run(o, hit)
    local data = {}
    for k, v in pairs(o) do data[k] = v end
    data.entity = hit.entity
    data.coords = hit.coords
    data.distance = hit.distance
    data.zone = hit.zone and hit.zone.id or nil

    if o.onSelect then return o.onSelect(data) end
    if o.export then
        local res, fn = tostring(o.export):match('^([^%.]+)%.(.+)$')
        if res then return exports[res][fn](nil, data) end
    end
    if o.event then return TriggerEvent(o.event, data) end
    if o.serverEvent then
        if data.entity and data.entity ~= 0 and NetworkGetEntityIsNetworked(data.entity) then
            data.entity = NetworkGetNetworkIdFromEntity(data.entity)
        else
            data.entity = 0
        end
        data.onSelect, data.canInteract = nil, nil
        return TriggerServerEvent(o.serverEvent, data)
    end
    if o.command then return ExecuteCommand(o.command) end
end
