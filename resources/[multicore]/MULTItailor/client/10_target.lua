--[[
    Interaction: MULTItarget when it runs (Config.Target 'auto' / 'ox'), otherwise the bridge's key
    prompt (MBridge.Interact - a RedM prompt group while you stand close). No floating 3D text.

    TT.addZone(id, spec) / TT.removeZone(id)
    TT.addEntity(entity, spec) / TT.removeEntity(entity)
    spec = { coords, radius, distance, title, options = { { label, icon, canInteract(), onSelect() } } }
]]
TT = TT or {}

local zones, ents = {}, {}

local function oxReady()
    if Config.Target == 'prompt' then return false end
    if GetResourceState('MULTItarget') == 'started' then return true end
    if Config.Target == 'ox' or Config.Target == 'auto' then
        local t = GetGameTimer() + 8000
        while GetResourceState('MULTItarget') ~= 'started' and GetResourceState('MULTItarget') ~= 'missing' and GetGameTimer() < t do Wait(250) end
    end
    return GetResourceState('MULTItarget') == 'started'
end

local function oxOptions(id, spec)
    local out = {}
    for i, o in ipairs(spec.options or {}) do
        out[#out + 1] = {
            name = ('multitailor:%s:%d'):format(id, i),
            label = o.label, icon = o.icon or 'fa-solid fa-shirt', distance = spec.distance or 2.5,
            canInteract = function(entity) return not o.canInteract or o.canInteract(entity) end,
            onSelect = function(data) if o.onSelect then o.onSelect(data and data.entity) end end,
        }
    end
    return out
end

function TT.addZone(id, spec)
    TT.removeZone(id)
    if oxReady() then
        local ok, zid = pcall(function()
            return exports.MULTItarget:addSphereZone({ name = 'multitailor:' .. id, coords = spec.coords, radius = spec.radius or 1.2,
                debug = Config.Debug == true, options = oxOptions(id, spec) })
        end)
        if ok then zones[id] = { ox = zid } return end
    end
    MBridge.Interact.AddZone('rt_' .. id, { coords = spec.coords, radius = spec.radius, distance = spec.distance or 2.0,
        title = spec.title, options = spec.options })
    zones[id] = { kp = true }
end

function TT.removeZone(id)
    local z = zones[id]
    if not z then return end
    if z.ox then pcall(function() exports.MULTItarget:removeZone(z.ox) end) end
    if z.kp then MBridge.Interact.RemoveZone('rt_' .. id) end
    zones[id] = nil
end

function TT.addEntity(entity, spec)
    if not entity or entity == 0 then return end
    TT.removeEntity(entity)
    if oxReady() then
        local opts = oxOptions('e' .. tostring(entity), spec)
        local ok = pcall(function() exports.MULTItarget:addLocalEntity(entity, opts) end)
        if ok then
            local names = {}
            for _, o in ipairs(opts) do names[#names + 1] = o.name end
            ents[entity] = { ox = names }
            return
        end
    end
    MBridge.Interact.AddEntity(entity, { distance = spec.distance or 2.5, title = spec.title, options = spec.options })
    ents[entity] = { kp = true }
end

function TT.removeEntity(entity)
    local e = ents[entity]
    if not e then return end
    if e.ox and DoesEntityExist(entity) then pcall(function() exports.MULTItarget:removeLocalEntity(entity, e.ox) end) end
    if e.kp then MBridge.Interact.RemoveEntity(entity) end
    ents[entity] = nil
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(zones) do TT.removeZone(id) end
    for e in pairs(ents) do TT.removeEntity(e) end
end)
