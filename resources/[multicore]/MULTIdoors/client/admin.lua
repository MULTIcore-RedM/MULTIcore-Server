-- ============================================================
-- MULTIdoors :: admin tool (/doors), client
-- Aim at a door to see its hash and model, make or edit a lock rule,
-- list rules, lock / unlock, teleport. The server checks admin rights
-- on every call; this file only shows ox_lib menus.
-- Natives (femga natives.json): START_SHAPE_TEST_LOS_PROBE 0x7EE9F5D83DD4F90E,
-- GET_SHAPE_TEST_RESULT, GET_GAMEPLAY_CAM_COORD / ROT, GET_ENTITY_MODEL,
-- IS_ENTITY_AN_OBJECT, SET_ENTITY_COORDS.
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
local N = { START_SHAPE_TEST_LOS_PROBE = 0x7EE9F5D83DD4F90E } -- (x1, y1, z1, x2, y2, z2, flags, entity, p8) -> handle
local A = Config.Admin
local aiming = false

local openMain, openDoor, openRule, editRule

local function call(name, ...)
    local res = lib.callback.await('MULTIdoors:admin:' .. name, false, ...)
    if not res or not res.ok then
        MDC.Notify(MDC.ErrText(res and res.err), 'error')
        return nil
    end
    return res
end

local function fmt(n) return ('%.2f'):format(n) end

local function teleport(x, y, z)
    DoScreenFadeOut(300)
    Wait(300)
    SetEntityCoords(cache.ped, x, y, z, false, false, false, false)
    Wait(300)
    DoScreenFadeIn(300)
end

---------------------------------
-- small text helpers for the rule form
---------------------------------
local function split(s)
    local out = {}
    for part in tostring(s or ''):gmatch('[^,%s]+') do out[#out + 1] = part end
    return out
end

-- "vallaw:0, marshal" -> { vallaw = 0, marshal = 0 }
local function parseGrades(s)
    local out, any = {}, false
    for _, part in ipairs(split(s)) do
        local name, grade = part:match('^([%w_%-]+):?(%d*)$')
        if name then out[name] = tonumber(grade) or 0; any = true end
    end
    return any and out or nil
end

local function gradesText(t)
    local parts = {}
    for k, v in pairs(t or {}) do parts[#parts + 1] = ('%s:%d'):format(k, v) end
    table.sort(parts)
    return table.concat(parts, ', ')
end

---------------------------------
-- aim finder
---------------------------------
local function camDir()
    local rot = GetGameplayCamRot(2)
    local yaw, pitch = math.rad(rot.z), math.rad(rot.x)
    return vector3(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
end

local nearby = {}   -- doors within reach, refreshed while aiming
local function refreshNearby()
    nearby = {}
    local pos = GetEntityCoords(cache.ped)
    local reach = A.AimDistance + 5.0
    for h, d in pairs(MULTIDoorData) do
        if math.abs(d.x - pos.x) < reach and math.abs(d.y - pos.y) < reach then
            nearby[#nearby + 1] = { h = h, d = d, c = vector3(d.x, d.y, d.z) }
        end
    end
end

-- door hash for what the camera looks at
local function aimedDoor()
    local from = GetGameplayCamCoord()
    local to = from + camDir() * A.AimDistance
    local handle = Citizen.InvokeNative(N.START_SHAPE_TEST_LOS_PROBE, from.x, from.y, from.z, to.x, to.y, to.z, A.RayFlags, cache.ped, 7, Citizen.ResultAsInteger())
    local status, hit, endCoords, _, entity = GetShapeTestResult(handle)
    if status ~= 2 or not hit or hit == 0 then return nil end
    -- 1. the hit object is a door model in the list: the closest listed door of that model
    if entity and entity ~= 0 and IsEntityAnObject(entity) then
        local model = MDS.Hash(GetEntityModel(entity))
        local ec = GetEntityCoords(entity)
        local best, bd
        for _, n in ipairs(nearby) do
            if MDS.Hash(n.d.model) == model then
                local dist = #(n.c - ec)
                if dist < 2.5 and (not bd or dist < bd) then best, bd = n.h, dist end
            end
        end
        if best then return best end
    end
    -- 2. else the closest listed door to the hit point
    local best, bd
    for _, n in ipairs(nearby) do
        local dist = #(n.c - endCoords)
        if dist <= A.AimFallbackRadius and (not bd or dist < bd) then best, bd = n.h, dist end
    end
    return best
end

local function aimMode()
    if aiming then return end
    aiming = true
    local keys = RSGCore.Shared.Keybinds
    local sel, cancel = keys[A.SelectKey], keys[A.CancelKey]
    local shown, lastRefresh = false, 0
    MDC.Notify(_L('aim_help', A.SelectKey, A.CancelKey), 'info')
    CreateThread(function()
        while aiming do
            if GetGameTimer() - lastRefresh > 1000 then refreshNearby(); lastRefresh = GetGameTimer() end
            local h = aimedDoor()
            if h ~= shown then
                if h then
                    local d = MULTIDoorData[h]
                    local rule = nil
                    for id, r in pairs(MDC.Rules) do for _, x in ipairs(r.doors) do if x == h then rule = id end end end
                    lib.showTextUI(_L('aim_text', h, d.name, d.area or '', rule or _L('none')))
                else
                    lib.hideTextUI()
                end
                shown = h
            end
            if IsControlJustPressed(0, sel) and h then
                aiming = false
                lib.hideTextUI()
                openDoor(h)
            elseif IsControlJustPressed(0, cancel) then
                aiming = false
                lib.hideTextUI()
            end
            Wait(0)
        end
    end)
end

---------------------------------
-- menus
---------------------------------
function openDoor(h)
    local d = MULTIDoorData[h]
    if not d then return end
    local res = call('door', h)
    if not res then return end
    local opts = {
        { title = _L('door_hash'), description = tostring(h), icon = 'hashtag',
          onSelect = function() lib.setClipboard(tostring(h)); MDC.Notify(_L('copied'), 'success') end },
        { title = _L('door_model'), description = ('%s (%d)'):format(d.name, d.model), icon = 'cube', readOnly = true },
        { title = _L('door_area'), description = d.area or '', icon = 'map', readOnly = true },
        { title = _L('door_coords'), description = ('%s, %s, %s'):format(fmt(d.x), fmt(d.y), fmt(d.z)), icon = 'location-dot',
          onSelect = function() lib.setClipboard(('vector3(%s, %s, %s)'):format(fmt(d.x), fmt(d.y), fmt(d.z))); MDC.Notify(_L('copied'), 'success') end },
    }
    if res.rule then
        opts[#opts + 1] = { title = _L('rule_open', res.rule), icon = 'lock', onSelect = function() openRule(res.rule) end }
    else
        opts[#opts + 1] = { title = _L('rule_create'), icon = 'plus', onSelect = function() editRule(nil, h) end }
    end
    opts[#opts + 1] = { title = _L('teleport'), icon = 'person-walking-arrow-right', onSelect = function() teleport(d.x, d.y, d.z) end }
    lib.registerContext({ id = 'multidoors_door', title = _L('door_title', d.name), menu = 'multidoors_main', options = opts })
    lib.showContext('multidoors_door')
end

function editRule(id, hash)
    local rule, origin
    if id then
        local res = call('get', id)
        if not res then return end
        rule, origin = res.rule, res.origin
    else
        local d = MULTIDoorData[hash]
        rule = { id = 'door_' .. tostring(hash), label = d and (d.name .. ' - ' .. (d.area or '')) or '', door = { hash },
                 locked = true, lockpickable = false, autoLock = 0, distance = Config.DefaultDistance }
    end
    local doorsText = {}
    for _, h in ipairs(rule.door or {}) do doorsText[#doorsText + 1] = tostring(h) end
    local input = lib.inputDialog(id and _L('form_edit', id) or _L('form_new'), {
        { type = 'input', label = _L('f_id'), description = _L('f_id_desc'), default = rule.id, required = true, disabled = id ~= nil },
        { type = 'input', label = _L('f_label'), default = rule.label },
        { type = 'input', label = _L('f_doors'), description = _L('f_doors_desc'), default = table.concat(doorsText, ', '), required = true },
        { type = 'checkbox', label = _L('f_locked'), checked = rule.locked ~= false },
        { type = 'input', label = _L('f_jobs'), description = _L('f_grades_desc'), default = gradesText(rule.jobs) },
        { type = 'input', label = _L('f_gangs'), description = _L('f_grades_desc'), default = gradesText(rule.gangs) },
        { type = 'input', label = _L('f_cids'), description = _L('f_list_desc'), default = table.concat(rule.citizenids or {}, ', ') },
        { type = 'input', label = _L('f_items'), description = _L('f_list_desc'), default = table.concat(rule.items or {}, ', ') },
        { type = 'checkbox', label = _L('f_pick'), checked = rule.lockpickable == true },
        { type = 'number', label = _L('f_autolock'), description = _L('f_autolock_desc'), default = rule.autoLock or 0, min = 0, max = 86400 },
        { type = 'number', label = _L('f_distance'), default = rule.distance or Config.DefaultDistance, min = 0.5, max = 15, step = 0.5, precision = 1 },
    })
    if not input then return end
    local doors = {}
    for _, s in ipairs(split(input[3])) do doors[#doors + 1] = tonumber(s) end
    local save = {
        id = id or input[1], label = input[2], door = doors, locked = input[4] == true,
        jobs = parseGrades(input[5]), gangs = parseGrades(input[6]),
        citizenids = split(input[7]), items = split(input[8]),
        lockpickable = input[9] == true, autoLock = tonumber(input[10]) or 0, distance = tonumber(input[11]),
        rsg = rule.rsg,
    }
    -- a door that is not in data/doors.lua keeps the coordinates it had
    if rule.coords then save.coords = rule.coords end
    for _, h in ipairs(doors) do if MULTIDoorData[MDS.Hash(h) or 0] then save.coords = nil end end
    if call('save', save) then
        MDC.Notify(_L('saved', save.id), 'success')
        if origin == 'config' then MDC.Notify(_L('saved_override'), 'info') end
    end
end

function openRule(id)
    local res = call('get', id)
    if not res then return end
    local r = res.rule
    local doorsText = {}
    for _, h in ipairs(r.door) do
        local d = MULTIDoorData[h]
        doorsText[#doorsText + 1] = ('%d (%s)'):format(h, d and d.name or '?')
    end
    local opts = {
        { title = r.label, description = _L('rule_info', res.origin, res.locked and _L('state_locked') or _L('state_unlocked')), icon = 'circle-info', readOnly = true },
        { title = _L('door_hash'), description = table.concat(doorsText, ', '), icon = 'hashtag', readOnly = true },
        { title = res.locked and _L('admin_unlock') or _L('admin_lock'), icon = res.locked and 'lock-open' or 'lock',
          onSelect = function()
              if call('setState', id, not res.locked) then MDC.Notify(res.locked and _L('door_unlocked', r.label) or _L('door_locked', r.label), 'success') end
              openRule(id)
          end },
        { title = _L('rule_edit'), icon = 'pen', onSelect = function() editRule(id) end },
        { title = _L('teleport'), icon = 'person-walking-arrow-right', onSelect = function() teleport(r.coords.x, r.coords.y, r.coords.z) end },
    }
    if res.origin == 'db_override' then
        opts[#opts + 1] = { title = _L('rule_reset'), description = _L('rule_reset_desc'), icon = 'rotate-left',
            onSelect = function() if call('reset', id) then MDC.Notify(_L('reset_done', id), 'success') end end }
    end
    opts[#opts + 1] = { title = _L('rule_delete'), description = (res.origin == 'db') and _L('rule_delete_desc') or _L('rule_disable_desc'), icon = 'trash',
        onSelect = function()
            local sure = lib.alertDialog({ header = _L('rule_delete'), content = _L('confirm_delete', r.label), centered = true, cancel = true })
            if sure == 'confirm' and call('delete', id) then MDC.Notify(_L('deleted', id), 'success') end
        end }
    lib.registerContext({ id = 'multidoors_rule', title = id, menu = 'multidoors_list', options = opts })
    lib.showContext('multidoors_rule')
end

local function openList(filter)
    local res = call('list')
    if not res then return end
    local opts = {
        { title = _L('list_search'), icon = 'magnifying-glass', onSelect = function()
            local input = lib.inputDialog(_L('list_search'), { { type = 'input', label = _L('list_search_label') } })
            openList(input and input[1] or nil)
        end },
    }
    local shown = 0
    for _, r in ipairs(res.list) do
        local hay = (r.id .. ' ' .. r.label .. ' ' .. (r.area or '')):lower()
        if (not filter or filter == '' or hay:find(filter:lower(), 1, true)) and shown < A.MaxListed then
            shown = shown + 1
            opts[#opts + 1] = { title = r.label, description = ('%s - %s - %s'):format(r.id, r.area or '', r.locked and _L('state_locked') or _L('state_unlocked')),
                icon = r.locked and 'lock' or 'lock-open', arrow = true, onSelect = function() openRule(r.id) end }
        end
    end
    for _, id in ipairs(res.disabled or {}) do
        opts[#opts + 1] = { title = _L('disabled_rule', id), icon = 'ban',
            onSelect = function() if call('reset', id) then MDC.Notify(_L('reset_done', id), 'success') end end }
    end
    lib.registerContext({ id = 'multidoors_list', title = _L('list_title', #res.list), menu = 'multidoors_main', options = opts })
    lib.showContext('multidoors_list')
end

local function openNearby()
    local pos = GetEntityCoords(cache.ped)
    local list = {}
    for h, d in pairs(MULTIDoorData) do
        local dist = #(pos - vector3(d.x, d.y, d.z))
        if dist <= A.NearbyRadius then list[#list + 1] = { h = h, d = d, dist = dist } end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local opts = {}
    for i = 1, math.min(#list, A.MaxListed) do
        local n = list[i]
        opts[#opts + 1] = { title = n.d.name, description = ('%d - %.1f m'):format(n.h, n.dist), icon = 'door-closed', arrow = true,
            onSelect = function() openDoor(n.h) end }
    end
    if #opts == 0 then opts[1] = { title = _L('nearby_none'), readOnly = true } end
    lib.registerContext({ id = 'multidoors_nearby', title = _L('nearby_title'), menu = 'multidoors_main', options = opts })
    lib.showContext('multidoors_nearby')
end

function openMain()
    lib.registerContext({
        id = 'multidoors_main',
        title = _L('admin_title'),
        options = {
            { title = _L('menu_aim'), description = _L('menu_aim_desc'), icon = 'crosshairs', onSelect = aimMode },
            { title = _L('menu_nearby'), description = _L('menu_nearby_desc'), icon = 'door-open', arrow = true, onSelect = openNearby },
            { title = _L('menu_list'), description = _L('menu_list_desc'), icon = 'list', arrow = true, onSelect = function() openList() end },
        },
    })
    lib.showContext('multidoors_main')
end

RegisterNetEvent('MULTIdoors:client:admin', function() openMain() end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and aiming then lib.hideTextUI() end
end)
