-- ============================================================
-- MULTItarget :: qb-target / rsg-target calls (client)
-- Answers exports['rsg-target']:X() (qb-target style calls, as RSG v2
-- scripts make them) on MULTItarget's engine. Written for MULTIcore (GPL v3).
--
-- qb-target options table:
--   { options = { { type, event, icon, label, action, canInteract, job, gang,
--                   citizenid, item, distance, ...extra fields } }, distance = n }
-- becomes MULTItarget (ox_target style) options:
--   action      -> onSelect (called with the entity, as qb-target does)
--   type/event  -> event ('client' or none), serverEvent ('server'), command ('command'),
--                  'rsgcommand' / 'qbcommand' -> RSGCore:CallCommand
--   job / gang / citizenid -> groups ({ name = minimum grade })
--   item        -> items
--   canInteract(entity, distance, data) keeps qb-target's arguments
--   distance    -> option distance (option, else call, else Config.DefaultDistance)
-- Every option is named '<calling resource>:<label>', so labels from two scripts never
-- replace each other, removal by label works per script, and a script's targets are
-- taken away when it stops.
-- ============================================================

local SELF = GetCurrentResourceName()

local function dbg(...)
    if Config.Debug then print('[MULTItarget]', ...) end
end

local function callable(f)
    if type(f) == 'function' then return true end
    local mt = type(f) == 'table' and getmetatable(f)
    return mt and mt.__call ~= nil or false
end

local function ox(fn, ...)
    local f = MT.API[fn]
    if not f then return nil end
    local ok, res = pcall(f, ...)
    if not ok then
        print(('[MULTItarget] %s failed: %s'):format(fn, tostring(res)))
        return nil
    end
    return res
end

local function caller()
    local res = GetInvokingResource()
    if not res or res == '' then res = SELF end
    return res
end

-- ---------------------------------------------------------------
-- who added what: reg[resource] = {
--   ents = { [key] = { net = bool, id = handle|netId, names = set } }, handles = { [handle] = key },
--   models = { [hash] = set }, globals = { [Ped|Vehicle|Object|Player] = set }, bones = set,
--   zones = { [name] = { id = zoneId } | { ent = handle, names = list } } }
-- ---------------------------------------------------------------

local reg = {}

local function R(res)
    local r = reg[res]
    if not r then
        r = { ents = {}, handles = {}, models = {}, globals = {}, bones = {}, zones = {} }
        reg[res] = r
    end
    return r
end

local function setToList(set)
    local out = {}
    for n in pairs(set or {}) do out[#out + 1] = n end
    return out
end

local function optName(res, tag, label)
    return ('%s:%s%s'):format(res, tag or '', tostring(label))
end

local function labelsToNames(res, tag, labels)
    if labels == nil then return nil end
    if type(labels) ~= 'table' then return { optName(res, tag, labels) } end
    local out = {}
    for _, l in pairs(labels) do out[#out + 1] = optName(res, tag, l) end
    return out
end

-- ---------------------------------------------------------------
-- option conversion
-- ---------------------------------------------------------------

-- qb-target fields that are translated, and engine fields a qb option must not set by accident
local RESERVED = {
    action = true, canInteract = true, event = true, type = true, job = true, gang = true, citizenid = true,
    item = true, items = true, name = true, resource = true, export = true, onSelect = true, serverEvent = true,
    command = true, groups = true, openMenu = true, menuName = true, bones = true, targeticon = true,
    drawDistance = true, drawColor = true, successDrawColor = true,
}

local function plainCopy(o)
    local out = {}
    for k, v in pairs(o) do
        if not callable(v) then out[k] = v end
    end
    return out
end

local function addGroups(groups, v)
    if type(v) == 'string' then
        if v ~= '' and v ~= 'all' then groups[v] = groups[v] or 0 end
        return
    end
    if type(v) ~= 'table' then return end
    for k, g in pairs(v) do
        if type(k) == 'number' then
            if type(g) == 'string' and g ~= 'all' then groups[g] = groups[g] or 0 end
        elseif type(k) == 'string' then
            groups[k] = tonumber(g) or 0 -- { police = 2 } = police grade 2 and up; { ABC123 = true } = grade 0
        end
    end
end

-- the options list of a qb-target params table, in a fixed order (array part, then named keys)
local function optionList(params)
    if type(params) ~= 'table' then return {}, nil end
    local opts = params.options
    if opts == nil and params[1] ~= nil then opts = params end -- options passed without the wrapper
    if type(opts) ~= 'table' then return {}, tonumber(params.distance) end
    if opts.label ~= nil and opts[1] == nil then opts = { opts } end -- a single option
    local list = {}
    for _, o in ipairs(opts) do list[#list + 1] = o end
    local keys = {}
    for k in pairs(opts) do
        if type(k) ~= 'number' then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do list[#list + 1] = opts[k] end
    return list, tonumber(params.distance)
end

local function convertOption(o, idx, dist, res, tag)
    local out = {}
    for k, v in pairs(o) do
        if not RESERVED[k] and not callable(v) then out[k] = v end
    end
    local label = o.label ~= nil and tostring(o.label) or ('option %d'):format(idx)
    out.label = label
    out.name = optName(res, tag, label)
    out.resource = res
    out.distance = tonumber(o.distance) or dist or Config.DefaultDistance

    local groups = {}
    addGroups(groups, o.job)
    addGroups(groups, o.gang)
    addGroups(groups, o.citizenid)
    if next(groups) then out.groups = groups end

    local item = o.item or o.items
    if item ~= nil and item ~= '' then out.items = item end

    local data = plainCopy(o) -- what qb-target hands to canInteract and events

    if callable(o.canInteract) then
        local ci = o.canInteract
        out.canInteract = function(entity, distance)
            return ci(entity, distance, data)
        end
    end

    local t = o.type
    if callable(o.action) then
        local act = o.action
        out.onSelect = function(resp)
            act(type(resp) == 'table' and resp.entity or resp)
        end
    elseif type(o.event) == 'string' then
        if t == 'server' then
            out.serverEvent = o.event
        elseif t == 'command' then
            out.command = o.event
        elseif t == 'rsgcommand' or t == 'qbcommand' then
            local ev = o.event
            out.onSelect = function(resp)
                local args = plainCopy(data)
                if type(resp) == 'table' then args.entity = resp.entity end
                TriggerServerEvent('RSGCore:CallCommand', ev, args)
            end
        else
            out.event = o.event
        end
    else
        dbg(('%s: option "%s" has no action or event'):format(res, label))
    end
    return out
end

--- qb-target params -> engine options, plus their names
local function convert(params, res, tag)
    local list, dist = optionList(params)
    local opts, names = {}, {}
    for i, o in ipairs(list) do
        if type(o) == 'table' then
            local c = convertOption(o, i, dist, res, tag)
            opts[#opts + 1] = c
            names[#names + 1] = c.name
        end
    end
    return opts, names
end

-- ---------------------------------------------------------------
-- entities
-- ---------------------------------------------------------------

local function entityKey(ent)
    if NetworkGetEntityIsNetworked(ent) then
        local netId = NetworkGetNetworkIdFromEntity(ent)
        return 'n:' .. netId, true, netId
    end
    return 'l:' .. ent, false, ent
end

local function addToEntity(res, ent, opts, names)
    ent = tonumber(ent)
    if not ent or not DoesEntityExist(ent) then
        dbg(('%s: entity %s does not exist'):format(res, tostring(ent)))
        return
    end
    local r = R(res)
    local key, net, id = entityKey(ent)
    ox(net and 'addEntity' or 'addLocalEntity', id, opts)
    local e = r.ents[key] or { net = net, id = id, names = {} }
    for _, n in ipairs(names) do e.names[n] = true end
    r.ents[key] = e
    r.handles[ent] = key
end

local function removeFromEntity(res, ent, names)
    local r = reg[res]
    ent = tonumber(ent)
    if not r or not ent then return end
    local key = r.handles[ent]
    if not key and DoesEntityExist(ent) then key = entityKey(ent) end
    local e = key and r.ents[key]
    if not e then return end
    local list = names or setToList(e.names)
    if #list > 0 then ox(e.net and 'removeEntity' or 'removeLocalEntity', e.id, list) end
    for _, n in ipairs(list) do e.names[n] = nil end
    if next(e.names) == nil then
        r.ents[key] = nil
        r.handles[ent] = nil
    end
end

local function entityList(entities)
    if type(entities) ~= 'table' then return { entities } end
    local out = {}
    for _, e in pairs(entities) do out[#out + 1] = e end
    return out
end

-- ---------------------------------------------------------------
-- models
-- ---------------------------------------------------------------

local function modelList(models)
    if type(models) ~= 'table' then models = { models } end
    local out = {}
    for _, m in pairs(models) do
        local h = tonumber(m) or (type(m) == 'string' and joaat(m)) or nil
        if h then out[#out + 1] = h end
    end
    return out
end

-- ---------------------------------------------------------------
-- zones (PolyZone-style arguments)
-- ---------------------------------------------------------------

local function field(c, key, i)
    local ok, v = pcall(function() return c[key] end)
    if ok and v ~= nil then return tonumber(v) end
    ok, v = pcall(function() return c[i] end)
    if ok then return tonumber(v) end
    return nil
end

local function xyz(c)
    if c == nil or (type(c) ~= 'table' and type(c):sub(1, 6) ~= 'vector') then return nil end
    local x, y = field(c, 'x', 1), field(c, 'y', 2)
    if not x or not y then return nil end
    return x, y, field(c, 'z', 3)
end

local function zoneDebug(options)
    return Config.Zone.Debug or (type(options) == 'table' and options.debugPoly == true) or false
end

local function removeZone(res, name)
    local r = reg[res]
    local z = r and r.zones[name]
    if not z then return false end
    if z.id then ox('removeZone', z.id, true) end
    if z.ent then removeFromEntity(res, z.ent, z.names) end
    r.zones[name] = nil
    return true
end

-- ---------------------------------------------------------------
-- cleanup
-- ---------------------------------------------------------------

local GLOBAL_KINDS = { 'Ped', 'Vehicle', 'Object', 'Player' }

local function removeAll(res)
    local r = reg[res]
    if not r then return end
    for name in pairs(r.zones) do removeZone(res, name) end
    for _, e in pairs(r.ents) do
        local list = setToList(e.names)
        if #list > 0 then ox(e.net and 'removeEntity' or 'removeLocalEntity', e.id, list) end
    end
    for h, set in pairs(r.models) do
        local list = setToList(set)
        if #list > 0 then ox('removeModel', h, list) end
    end
    for _, kind in ipairs(GLOBAL_KINDS) do
        local list = setToList(r.globals[kind])
        if #list > 0 then ox('removeGlobal' .. kind, list) end
    end
    local bones = setToList(r.bones)
    if #bones > 0 then ox('removeGlobalVehicle', bones) end
    reg[res] = nil
end

-- a script that stops takes its targets with it (the engine only sees MULTItarget as their owner)
AddEventHandler('onClientResourceStop', function(res)
    if res ~= SELF then removeAll(res) end
end)

-- local entities that were deleted without RemoveTargetEntity (the engine forgets them itself too)
CreateThread(function()
    while true do
        Wait(60000)
        for _, r in pairs(reg) do
            for handle, key in pairs(r.handles) do
                local e = r.ents[key]
                if e and not e.net and not DoesEntityExist(handle) then
                    r.ents[key] = nil
                    r.handles[handle] = nil
                end
            end
        end
    end
end)

-- ---------------------------------------------------------------
-- export registration
-- ---------------------------------------------------------------

-- registers fn as exports.MULTItarget:name, exports['rsg-target']:name and exports['qb-target']:name
local function Export(name, fn)
    exports(name, fn)
    for _, face in ipairs({ 'rsg-target', 'qb-target' }) do
        AddEventHandler(('__cfx_export_%s_%s'):format(face, name), function(setCB)
            setCB(fn)
        end)
    end
end

-- ---------------------------------------------------------------
-- entities
-- ---------------------------------------------------------------

-- AddTargetEntity(entity | entities, params)
Export('AddTargetEntity', function(entities, params)
    local res = caller()
    local opts, names = convert(params, res)
    if #opts == 0 then return end
    for _, ent in ipairs(entityList(entities)) do addToEntity(res, ent, opts, names) end
    dbg(res, 'AddTargetEntity', #opts)
end)

-- RemoveTargetEntity(entity | entities, label | labels | nil)  nil = everything this script added there
Export('RemoveTargetEntity', function(entities, labels)
    local res = caller()
    local names = labelsToNames(res, nil, labels)
    for _, ent in ipairs(entityList(entities)) do removeFromEntity(res, ent, names) end
end)

-- ---------------------------------------------------------------
-- models
-- ---------------------------------------------------------------

-- AddTargetModel(model | models, params)  models may be names or hashes
Export('AddTargetModel', function(models, params)
    local res = caller()
    local opts, names = convert(params, res)
    local hashes = modelList(models)
    if #opts == 0 or #hashes == 0 then return end
    ox('addModel', hashes, opts)
    local r = R(res)
    for _, h in ipairs(hashes) do
        r.models[h] = r.models[h] or {}
        for _, n in ipairs(names) do r.models[h][n] = true end
    end
    dbg(res, 'AddTargetModel', #hashes, #opts)
end)

-- RemoveTargetModel(model | models, label | labels | nil)
Export('RemoveTargetModel', function(models, labels)
    local res = caller()
    local r = reg[res]
    if not r then return end
    local want = labelsToNames(res, nil, labels)
    for _, h in ipairs(modelList(models)) do
        local set = r.models[h]
        if set then
            local list = want or setToList(set)
            if #list > 0 then ox('removeModel', h, list) end
            for _, n in ipairs(list) do set[n] = nil end
            if next(set) == nil then r.models[h] = nil end
        end
    end
end)

-- ---------------------------------------------------------------
-- globals
-- ---------------------------------------------------------------

local function addGlobal(kind, params)
    local res = caller()
    local opts, names = convert(params, res)
    if #opts == 0 then return end
    ox('addGlobal' .. kind, opts)
    local r = R(res)
    r.globals[kind] = r.globals[kind] or {}
    for _, n in ipairs(names) do r.globals[kind][n] = true end
end

local function removeGlobal(kind, labels)
    local res = caller()
    local r = reg[res]
    local set = r and r.globals[kind]
    if not set then return end
    local list = labelsToNames(res, nil, labels) or setToList(set)
    if #list > 0 then ox('removeGlobal' .. kind, list) end
    for _, n in ipairs(list) do set[n] = nil end
end

for _, kind in ipairs(GLOBAL_KINDS) do
    Export('AddGlobal' .. kind, function(params) addGlobal(kind, params) end)
    Export('RemoveGlobal' .. kind, function(labels) removeGlobal(kind, labels) end)
end

-- qb-target global types: 1 = ped, 2 = vehicle, 3 = object, 4 = player
local TYPE_KIND = { 'Ped', 'Vehicle', 'Object', 'Player' }

Export('AddGlobalType', function(typ, params)
    local kind = TYPE_KIND[tonumber(typ) or 0]
    if not kind then return dbg('AddGlobalType: unknown type', tostring(typ)) end
    addGlobal(kind, params)
end)

Export('RemoveGlobalType', function(typ, labels)
    local kind = TYPE_KIND[tonumber(typ) or 0]
    if not kind then return dbg('RemoveGlobalType: unknown type', tostring(typ)) end
    removeGlobal(kind, labels)
end)

-- ---------------------------------------------------------------
-- bones (vehicle / wagon bones, as global vehicle options with bones)
-- ---------------------------------------------------------------

-- AddTargetBone(bone | bones, params)
Export('AddTargetBone', function(bones, params)
    local res = caller()
    if type(bones) ~= 'table' then bones = { bones } end
    local list = {}
    for _, b in pairs(bones) do list[#list + 1] = b end
    local opts, names = convert(params, res, 'bone:')
    if #opts == 0 or #list == 0 then return end
    for _, o in ipairs(opts) do o.bones = list end
    ox('addGlobalVehicle', opts)
    local r = R(res)
    for _, n in ipairs(names) do r.bones[n] = true end
end)

-- RemoveTargetBone(bones, label | labels | nil): removes by label from every bone (the engine keeps one
-- option for all its bones)
Export('RemoveTargetBone', function(_, labels)
    local res = caller()
    local r = reg[res]
    if not r then return end
    local list = labelsToNames(res, 'bone:', labels) or setToList(r.bones)
    if #list > 0 then ox('removeGlobalVehicle', list) end
    for _, n in ipairs(list) do r.bones[n] = nil end
end)

-- ---------------------------------------------------------------
-- zones
-- ---------------------------------------------------------------

-- AddCircleZone(name, center, radius, options, params)
Export('AddCircleZone', function(name, center, radius, options, params)
    local res = caller()
    local x, y, z = xyz(center)
    if not x then return dbg(res, 'AddCircleZone: bad centre for', tostring(name)) end
    removeZone(res, name)
    local opts = convert(params, res)
    if #opts == 0 then return end
    local id = ox('addSphereZone', {
        name = optName(res, nil, name),
        coords = vector3(x, y, z or 0.0),
        radius = tonumber(radius) or 1.0,
        debug = zoneDebug(options),
        drawSprite = false, -- no white marker dots
        options = opts,
    })
    if id then R(res).zones[name] = { id = id } end
    return id
end)

-- AddBoxZone(name, center, length, width, options { heading, minZ, maxZ, debugPoly }, params)
-- length runs along the box's y axis, width along x (as ox_target's rsg-target bridge does)
Export('AddBoxZone', function(name, center, length, width, options, params)
    local res = caller()
    local x, y, cz = xyz(center)
    if not x then return dbg(res, 'AddBoxZone: bad centre for', tostring(name)) end
    options = type(options) == 'table' and options or {}
    local minZ, maxZ = tonumber(options.minZ), tonumber(options.maxZ)
    local h, z = Config.Zone.DefaultHeight, cz or 0.0
    if minZ and maxZ and maxZ > minZ then
        h, z = maxZ - minZ, (minZ + maxZ) / 2
    elseif minZ then
        z = minZ + h / 2
    elseif maxZ then
        z = maxZ - h / 2
    end
    removeZone(res, name)
    local opts = convert(params, res)
    if #opts == 0 then return end
    local id = ox('addBoxZone', {
        name = optName(res, nil, name),
        coords = vector3(x, y, z),
        size = vector3(tonumber(width) or 1.0, tonumber(length) or 1.0, h),
        rotation = tonumber(options.heading) or 0.0, -- UNVERIFIED: same turning direction as PolyZone's heading
        debug = zoneDebug(options),
        drawSprite = false, -- no white marker dots
        options = opts,
    })
    if id then R(res).zones[name] = { id = id } end
    return id
end)

-- AddPolyZone(name, points, options { minZ, maxZ, debugPoly }, params)
Export('AddPolyZone', function(name, points, options, params)
    local res = caller()
    options = type(options) == 'table' and options or {}
    if type(points) ~= 'table' then return dbg(res, 'AddPolyZone: no points for', tostring(name)) end
    local pts, zs = {}, {}
    for _, p in ipairs(points) do
        local x, y, z = xyz(p)
        if x then
            pts[#pts + 1] = { x, y }
            if z then zs[#zs + 1] = z end
        end
    end
    if #pts < 3 then return dbg(res, 'AddPolyZone: fewer than 3 points for', tostring(name)) end
    local minZ, maxZ = tonumber(options.minZ), tonumber(options.maxZ)
    local mid, thick
    if minZ and maxZ and maxZ > minZ then
        mid, thick = (minZ + maxZ) / 2, maxZ - minZ
    elseif #zs == #pts then
        local sum = 0.0
        for _, z in ipairs(zs) do sum = sum + z end
        mid, thick = sum / #zs, Config.Zone.DefaultHeight
    else
        mid, thick = Config.Zone.NoZCentre, Config.Zone.NoZThickness
    end
    local list = {}
    for i, p in ipairs(pts) do list[i] = vector3(p[1], p[2], mid) end
    removeZone(res, name)
    local opts = convert(params, res)
    if #opts == 0 then return end
    local id = ox('addPolyZone', {
        name = optName(res, nil, name),
        points = list,
        thickness = thick,
        debug = zoneDebug(options),
        drawSprite = false, -- no white marker dots
        options = opts,
    })
    if id then R(res).zones[name] = { id = id } end
    return id
end)

-- AddEntityZone(name, entity, options, params): becomes options on that entity, removable with RemoveZone(name)
Export('AddEntityZone', function(name, entity, _, params)
    local res = caller()
    removeZone(res, name)
    local opts, names = convert(params, res, 'zone:' .. tostring(name) .. ':')
    if #opts == 0 then return end
    addToEntity(res, entity, opts, names)
    R(res).zones[name] = { ent = tonumber(entity), names = names }
end)

-- RemoveZone(name)
Export('RemoveZone', function(name)
    local res = caller()
    if not removeZone(res, name) then dbg(res, 'RemoveZone: no zone named', tostring(name)) end
end)

-- ---------------------------------------------------------------
-- state
-- ---------------------------------------------------------------

-- AllowTargeting(state): false turns the target eye off
Export('AllowTargeting', function(state)
    ox('disableTargeting', state == false)
end)

Export('IsTargetActive', function()
    return ox('isActive') == true
end)

-- qb-target: "is the eye on something with options right now"
Export('IsTargetSuccess', function()
    return MT.HasOptions == true
end)

-- ---------------------------------------------------------------
-- qb-target calls with no counterpart here: accepted, nothing done
-- ---------------------------------------------------------------

local UNSUPPORTED = {
    'AddComboZone', 'SpawnPed', 'RemoveSpawnedPed', 'DeletePeds', 'GetPeds', 'UpdatePedsData',
    'RaycastCamera', 'CheckOptions', 'GetGlobalTypeData', 'GetZoneData', 'GetTargetBoneData',
    'GetTargetEntityData', 'GetTargetModelData', 'GetGlobalPedData', 'GetGlobalVehicleData',
    'GetGlobalObjectData', 'GetGlobalPlayerData', 'UpdateGlobalTypeData', 'UpdateZoneData',
    'UpdateTargetBoneData', 'UpdateTargetEntityData', 'UpdateTargetModelData', 'UpdateGlobalPedData',
    'UpdateGlobalVehicleData', 'UpdateGlobalObjectData', 'UpdateGlobalPlayerData',
}

for _, name in ipairs(UNSUPPORTED) do
    Export(name, function()
        dbg(('%s called %s: not supported, ignored'):format(caller(), name))
        return nil
    end)
end
