--[[
    Tailor shop points: cutting tables (craft), counters (store), offices (boss), stockrooms (storage).

    Sources: config/locations.lua (Config.UseConfigLocations) and the dynamic-location API below,
    which has the same contract as other MULTI job tools - a placement tool sends its tailor
    points here (trade 'tailor'). Persistence is the caller's job; this registry lives in memory.

    Server exports (exports.MULTItailor:<Name>):
      RegisterDynamicLocation(def) / UpdateDynamicLocation(def) -> ok, stationId | false, err
      RemoveDynamicLocation(id)       -> ok, err
      ReloadDynamicLocations(list)    -> { loaded, failed = { { id, err } } }   replaces the caller's points
      GetDynamicLocations(owner?)     -> { def..., stationId, owner }
      GetStationTemplates()           -> { { trade, tradeLabel, recipeSet, label, recipes, icon, jobs, townJobs } }
      GetJobSetupInfo()               -> { useConfigLocations, trades = { { trade, label, jobs, recipeSets, benchSet, shopItems } } }
      GetDynamicLocationsApi()        -> { version = 3, maxLocations, features }
    Client sync: 'MULTItailor:points' (full list), 'MULTItailor:pointSet' (one), 'MULTItailor:pointRemoved' (id).

    TP.get(id) -> point | nil
    TP.access(src, id, need) -> point, role | nil, err    need = 'staff' | 'boss' | 'public'
]]
TP = TP or {}

local RES = GetCurrentResourceName()
local registry = {}   -- [id] = { point = p, owner = resource }

local function count()
    local n = 0
    for _ in pairs(registry) do n = n + 1 end
    return n
end

local function stationIdOf(id) return ('%s_%s'):format(Config.Tailor.tradeName, id) end

local function clientList()
    local out = {}
    for _, e in pairs(registry) do out[#out + 1] = e.point end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function TP.list() return clientList() end
function TP.get(id) local e = registry[id] return e and e.point or nil end

local function changed()
    TriggerEvent('MULTItailor:pointsChanged')
end

local function apply(def, owner, silent)
    local p, err = TL.sanitizePoint(def)
    if not p then return false, err end
    local e = registry[p.id]
    if e and e.owner ~= owner then return false, 'owned_by_other' end
    if not e and count() >= (Config.DynamicLocations.max or 300) then return false, 'limit_reached' end
    if type(def.designer) == 'table' and p.kind == 'craft' then p.designer = def.designer end
    if def.blip ~= nil and type(def.blip) ~= 'table' then p.blip = def.blip == true end
    p.stationId = stationIdOf(p.id)
    registry[p.id] = { point = p, owner = owner }
    if not silent then
        TriggerClientEvent('MULTItailor:pointSet', -1, p)
        changed()
    end
    return true, p.stationId
end

local function remove(id, owner, silent)
    local e = registry[id]
    if not e then return false, 'not_found' end
    if owner and e.owner ~= owner then return false, 'owned_by_other' end
    registry[id] = nil
    if not silent then
        TriggerClientEvent('MULTItailor:pointRemoved', -1, id)
        changed()
    end
    return true
end

local function caller() return GetInvokingResource() or RES end

local function reload(list)
    local owner = caller()
    local result = { loaded = 0, failed = {} }
    if type(list) ~= 'table' then result.failed[1] = { id = '?', err = 'bad_list' } return result end
    for id, e in pairs(registry) do if e.owner == owner then remove(id, owner, true) end end
    for i = 1, #list do
        local ok, err = apply(list[i], owner, true)
        if ok then result.loaded = result.loaded + 1
        else result.failed[#result.failed + 1] = { id = type(list[i]) == 'table' and tostring(list[i].id) or '?', err = err } end
    end
    TriggerClientEvent('MULTItailor:points', -1, clientList())
    changed()
    return result
end

local function templates()
    local n = #(Config.Sewing.recipes or {})
    return { {
        trade = Config.Tailor.tradeName, tradeLabel = Config.Tailor.label, recipeSet = 'tailor_bench',
        label = L('bench_label'), recipes = n, placeableOnly = false, icon = 'fa-solid fa-shirt',
        jobs = (function() local j = {} for _, x in ipairs(Config.Tailor.globalJobs) do j[#j + 1] = x end
            for _, x in ipairs(TL.townJobs()) do j[#j + 1] = x end return j end)(),
        townJobs = TL.townJobs(),
    } }
end

local function jobSetupInfo()
    local jobs = {}
    for _, x in ipairs(Config.Tailor.globalJobs) do jobs[#jobs + 1] = x end
    for _, x in ipairs(TL.townJobs()) do jobs[#jobs + 1] = x end
    local shopItems = {}
    for item, price in pairs(Config.Counter.defaultPrices or {}) do
        shopItems[#shopItems + 1] = { item = item, price = price, amount = 1, label = TA.label(item) }
    end
    table.sort(shopItems, function(a, b) return a.item < b.item end)
    return {
        useConfigLocations = Config.UseConfigLocations == true,
        trades = { {
            trade = Config.Tailor.tradeName, label = Config.Tailor.label, jobs = jobs,
            recipeSets = { { key = 'tailor_bench', label = L('bench_label'), recipes = #(Config.Sewing.recipes or {}) } },
            benchSet = 'tailor_bench', shopItems = shopItems, provider = RES,
        } },
    }
end

if Config.DynamicLocations.enabled ~= false then
    exports('RegisterDynamicLocation', function(def) return apply(def, caller()) end)
    exports('UpdateDynamicLocation', function(def) return apply(def, caller()) end)
    exports('RemoveDynamicLocation', function(id)
        if type(id) ~= 'string' then return false, 'bad_id' end
        return remove(id, caller())
    end)
    exports('ReloadDynamicLocations', reload)
    exports('GetDynamicLocations', function(owner)
        local out = {}
        for _, e in pairs(registry) do
            if not owner or e.owner == owner then
                local row = TU.copy(e.point)
                row.owner = e.owner
                out[#out + 1] = row
            end
        end
        table.sort(out, function(a, b) return a.id < b.id end)
        return out
    end)
    exports('GetStationTemplates', templates)
    exports('GetJobSetupInfo', jobSetupInfo)
    exports('GetDynamicLocationsApi', function()
        return { version = 3, maxLocations = Config.DynamicLocations.max or 300, provider = RES, trades = { Config.Tailor.tradeName },
                 features = { players = true, kinds = true, jobSetup = true, recipes = false } }
    end)
end

-- config shops
CreateThread(function()
    for _, p in ipairs(TL.configPoints()) do
        p.stationId = stationIdOf(p.id)
        registry[p.id] = { point = p, owner = RES }
    end
    TriggerClientEvent('MULTItailor:points', -1, clientList())
end)

AddEventHandler('onResourceStop', function(res)
    if res == RES then return end
    local any = false
    for id, e in pairs(registry) do
        if e.owner == res then registry[id] = nil any = true end
    end
    if any then
        TriggerClientEvent('MULTItailor:points', -1, clientList())
        changed()
    end
end)

local asked = {}
RegisterNetEvent('MULTItailor:requestPoints', function()
    local src = source
    local now = GetGameTimer()
    if asked[src] and now - asked[src] < 5000 then return end
    asked[src] = now
    TriggerClientEvent('MULTItailor:points', src, clientList())
end)
AddEventHandler('playerDropped', function() asked[source] = nil end)

-- ---------------------------------------------------------------- access
---need: 'public' (anyone near), 'staff' (job of the shop), 'boss' (boss of the shop)
function TP.access(src, id, need, maxDist)
    local p = TP.get(id)
    if not p then return nil, L('err_no_access') end
    if TA.dist(src, p.coords) > (maxDist or Config.Tailor.stationDistance or 4.0) then return nil, L('err_too_far') end
    if need == 'public' then return p, nil end
    local a = p.access
    if a then
        if a.players then
            local hit = false
            for _, x in ipairs(a.players) do if x == tonumber(src) then hit = true break end end
            if not hit then return nil, L('err_no_access') end
        end
        if a.ace and not IsPlayerAceAllowed(src, a.ace) then return nil, L('err_no_access') end
        if a.item and TA.count(src, a.item) < (a.itemCount or 1) then return nil, L('err_need_item', TA.label(a.item)) end
    end
    local job = TA.job(src)
    local role = job and TL.roleAt(p, job) or nil
    if not role and a and a.players then role = 'employee' end   -- an admin test bench (placement tool)
    if not role then return nil, L('err_no_access') end
    if need == 'boss' and role ~= 'boss' then return nil, L('err_boss_only') end
    if p.kind == 'storage' and p.storage and p.storage.minGrade and (job and job.grade or 0) < p.storage.minGrade and role ~= 'boss' then
        return nil, L('err_no_access')
    end
    return p, role, job
end

---Shop (business) of a point: { id, townJob, label }
function TP.business(p)
    if not p or not p.businessId then return nil end
    local town = TL.townLabel(p.townJob)
    return { id = p.businessId, townJob = p.townJob,
             label = town and ('%s %s'):format(town, Config.Tailor.label) or (p.label or Config.Tailor.label), town = town }
end

---Points of one business (to find its counter for a customer, its office ...).
function TP.ofBusiness(bid, kind)
    local out = {}
    for _, e in pairs(registry) do
        if e.point.businessId == bid and (not kind or e.point.kind == kind) then out[#out + 1] = e.point end
    end
    return out
end
