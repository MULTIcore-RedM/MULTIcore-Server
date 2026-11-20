-- ============================================================
-- MULTIjobs :: client
-- Job centres (clerk, blip, prompt), boss desks, duty points, the
-- commands and the NUI. The client never changes a job: it asks the
-- server (lib.callback) and shows the answer.
-- GPL v3.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()

local screen = nil      -- open page: 'centre' | 'myjobs' | 'boss' | 'gang'
local openAt = nil      -- coords the open page belongs to (nil = opened anywhere)
local blips, clerks, zones = {}, {}, {}
local jobPrompts = {}   -- prompt ids made for the current job / gang

local function notify(msg, kind)
    if not msg then return end
    exports.MULTIcore:Notify({ text = msg, title = _L('title'), type = kind or 'info', duration = Config.NotifyDuration })
end

local function pdata() return RSGCore.Functions.GetPlayerData() or {} end
local function myPos() return GetEntityCoords(cache.ped) end

local function nearestOf(list, key, value, dist)
    local pos, best, bestD = myPos(), nil, nil
    for i, p in ipairs(list) do
        if value == nil or p[key] == value then
            local d = #(pos - p.coords)
            if d <= dist and (not bestD or d < bestD) then best, bestD = i, d end
        end
    end
    return best
end

---------------------------------
-- NUI
---------------------------------
local function closePage()
    if not screen then return end
    screen, openAt = nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openPage(which, tab)
    if screen then closePage() end
    local res = lib.callback.await('MULTIjobs:open', false, which)
    if type(res) ~= 'table' or not res.ok then
        notify(res and res.msg or _L('failed'), 'error')
        return
    end
    screen = which
    openAt = nil
    if which == 'centre' then
        local i = nearestOf(Config.JobCentres, nil, nil, Config.CloseDistance)
        openAt = i and Config.JobCentres[i].coords
    elseif which == 'boss' then
        local i = nearestOf(Config.BossPoints, 'job', pdata().job and pdata().job.name, Config.CloseDistance)
        openAt = i and Config.BossPoints[i].coords
    elseif which == 'gang' then
        local i = nearestOf(Config.GangPoints, 'gang', pdata().gang and pdata().gang.name, Config.CloseDistance)
        openAt = i and Config.GangPoints[i].coords
    end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', screen = which, tab = tab, state = res.state, L = _LT(), lang = _LCode() })
end
exports('Open', function(which, tab) CreateThread(function() openPage(which, tab) end) end)

RegisterNUICallback('close', function(_, cb)
    closePage()
    cb({})
end)

RegisterNUICallback('action', function(data, cb)
    if not screen or type(data) ~= 'table' then return cb({ ok = false }) end
    local res = lib.callback.await('MULTIjobs:action', false, screen, data.action, data.data or {})
    if type(res) ~= 'table' then res = { ok = false, msg = _L('failed') } end
    cb(res)
    if res.close then closePage() end
end)

-- something changed for this player (hired, fired, job switched): refresh an open page
RegisterNetEvent('MULTIjobs:client:changed', function()
    if not screen then return end
    local which = screen
    CreateThread(function()
        local res = lib.callback.await('MULTIjobs:open', false, which)
        if screen ~= which then return end
        if type(res) == 'table' and res.ok then
            SendNUIMessage({ action = 'state', state = res.state })
        else
            closePage()
        end
    end)
end)

-- walking away closes a page that belongs to a place
CreateThread(function()
    while true do
        Wait(Config.CheckIntervalMs)
        if screen and openAt and #(myPos() - openAt) > Config.CloseDistance then closePage() end
    end
end)

---------------------------------
-- commands and key
---------------------------------
local function later(which, tab) return function() CreateThread(function() openPage(which, tab) end) end end
for _, name in ipairs(Config.Commands.MyJobs) do
    RegisterCommand(name, later('myjobs'), false)
end
RegisterCommand(Config.Commands.BossMenu, later('boss'), false)
RegisterCommand(Config.Commands.GangMenu, later('gang'), false)
RegisterCommand(Config.Commands.Duty, function() TriggerServerEvent('MULTIjobs:server:duty') end, false)

if Config.MyJobsKey and Config.MyJobsKey ~= '' then
    local k = Config.MyJobsKey:upper()
    if k == 'PAGEDOWN' or k == 'NEXT' or k == 'PGDN' then
        print('^1[MULTIjobs] PageDown may not be used for the jobs menu; key mapping skipped^7')
    else
        RegisterKeyMapping(Config.Commands.MyJobs[1], _L('key_myjobs'), 'keyboard', Config.MyJobsKey)
    end
end

---------------------------------
-- job centres: prompt / target, blips, clerks
---------------------------------
RegisterNetEvent('MULTIjobs:client:openCentre', later('centre'))
RegisterNetEvent('MULTIjobs:client:openBoss', later('boss'))
RegisterNetEvent('MULTIjobs:client:openGang', later('gang'))
RegisterNetEvent('MULTIjobs:client:duty', function() TriggerServerEvent('MULTIjobs:server:duty') end)

-- Config.Interact 'auto' / 'target' / 'prompt' (see @MULTIcore/lib/interact.lua)
local interactMode = nil    -- 'target' or 'prompt' once MCI.Run has decided

local function addPoint(id, coords, label, event, icon, canUse)
    if interactMode == 'target' then
        zones[#zones + 1] = MCI.AddZone({
            coords = coords,
            radius = Config.TargetRadius,
            options = { {
                name = id, label = label, icon = icon, distance = Config.TargetDistance,
                canInteract = canUse, onSelect = function() TriggerEvent(event) end,
            } },
        })
        return nil
    end
    MCI.AddPrompt(id, coords, Config.PromptKey, label, { type = 'client', event = event }, Config.PromptDistance)
    return id
end

-- the job centre option (counter zone and clerk use the same one)
local function centreOption(c)
    return {
        name = 'multijobs_centre_' .. c.id, label = _L('prompt_centre'), icon = Config.TargetIcons.centre,
        distance = Config.TargetDistance, onSelect = function() TriggerEvent('MULTIjobs:client:openCentre') end,
    }
end

-- blips (do not depend on the interaction mode)
CreateThread(function()
    for _, c in ipairs(Config.JobCentres) do
        if Config.Blips.Enabled and c.blip then
            local blip = BlipAddForCoords(Config.Blips.Style, c.coords.x, c.coords.y, c.coords.z)
            SetBlipSprite(blip, joaat(Config.Blips.JobCentreSprite), true)
            SetBlipScale(blip, Config.Blips.Scale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, _L(c.label)) -- _SET_BLIP_NAME
            blips[#blips + 1] = blip
        end
    end
end)

-- prompt mode: boss desk, duty and gang prompts only for the player's own job and gang
-- (rebuilt on login, job and gang changes; MULTItarget zones are made once and canInteract checks the job)
local function refreshJobPrompts()
    if interactMode ~= 'prompt' then return end
    for _, id in ipairs(jobPrompts) do MCI.RemovePrompt(id) end
    jobPrompts = {}
    if not LocalPlayer.state.isLoggedIn then return end
    local d = pdata()
    local job, gang = d.job or {}, d.gang or {}
    for i, b in ipairs(Config.BossPoints) do
        if b.job == job.name and job.isboss then
            jobPrompts[#jobPrompts + 1] = addPoint('multijobs_boss_' .. i, b.coords, _L('prompt_boss'), 'MULTIjobs:client:openBoss')
        end
    end
    for i, p in ipairs(Config.DutyPoints) do
        if p.job == job.name then
            jobPrompts[#jobPrompts + 1] = addPoint('multijobs_duty_' .. i, p.coords, _L('prompt_duty'), 'MULTIjobs:client:duty')
        end
    end
    for i, g in ipairs(Config.GangPoints) do
        if g.gang == gang.name then
            jobPrompts[#jobPrompts + 1] = addPoint('multijobs_gang_' .. i, g.coords, _L('prompt_gang'), 'MULTIjobs:client:openGang')
        end
    end
end

MCI.Run(Config.Interact, function(mode)
    interactMode = mode
    for i, c in ipairs(Config.JobCentres) do
        if mode == 'target' then
            zones[#zones + 1] = MCI.AddZone({ coords = c.coords, radius = Config.TargetRadius, options = { centreOption(c) } })
            if clerks[i] then MCI.AddEntity(clerks[i], { centreOption(c) }) end
        else
            addPoint('multijobs_centre_' .. c.id, c.coords, _L('prompt_centre'), 'MULTIjobs:client:openCentre')
        end
    end
    if mode == 'target' then
        for i, b in ipairs(Config.BossPoints) do
            addPoint('multijobs_boss_' .. i, b.coords, _L('prompt_boss'), 'MULTIjobs:client:openBoss', Config.TargetIcons.boss, function()
                local j = pdata().job
                return j and j.name == b.job and j.isboss == true
            end)
        end
        for i, d in ipairs(Config.DutyPoints) do
            addPoint('multijobs_duty_' .. i, d.coords, _L('prompt_duty'), 'MULTIjobs:client:duty', Config.TargetIcons.duty, function()
                local j = pdata().job
                return j and j.name == d.job
            end)
        end
        for i, g in ipairs(Config.GangPoints) do
            addPoint('multijobs_gang_' .. i, g.coords, _L('prompt_gang'), 'MULTIjobs:client:openGang', Config.TargetIcons.gang, function()
                local gg = pdata().gang
                return gg and gg.name == g.gang
            end)
        end
    else
        -- the resource may start (or restart) while the player is already in the world
        refreshJobPrompts()
    end
end, function(mode)
    for _, id in ipairs(zones) do MCI.RemoveZone(id) end
    zones = {}
    for _, ped in pairs(clerks) do MCI.RemoveEntity(ped) end
    for _, c in ipairs(Config.JobCentres) do MCI.RemovePrompt('multijobs_centre_' .. c.id) end
    for _, id in ipairs(jobPrompts) do MCI.RemovePrompt(id) end
    jobPrompts = {}
    interactMode = nil
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() SetTimeout(1000, refreshJobPrompts) end)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() SetTimeout(0, refreshJobPrompts) end)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', function() SetTimeout(250, refreshJobPrompts) end)
RegisterNetEvent('RSGCore:Client:OnGangUpdate', function() SetTimeout(250, refreshJobPrompts) end)

local function spawnClerk(c)
    local model = joaat(Config.Npc.Model)
    RequestModel(model, false)
    local deadline = GetGameTimer() + Config.Npc.LoadTimeoutMs
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(model) then return nil end
    local ped = CreatePed(model, c.npc.x, c.npc.y, c.npc.z + Config.Npc.ZOffset, c.npc.w, false, false, false, false)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if Config.Npc.Scenario and Config.Npc.Scenario ~= '' then
        Citizen.InvokeNative(0x524B54361229154F, ped, joaat(Config.Npc.Scenario), -1, true, 0, -1.0, false) -- TASK_START_SCENARIO_IN_PLACE_HASH
    end
    SetModelAsNoLongerNeeded(model)
    return ped
end

CreateThread(function()
    if not Config.Npc.Enabled then return end
    while true do
        Wait(Config.CheckIntervalMs)
        local pos = myPos()
        for i, c in ipairs(Config.JobCentres) do
            local near = #(pos - c.npc.xyz) < Config.Npc.SpawnDistance
            if near and not clerks[i] then
                clerks[i] = spawnClerk(c)
                if clerks[i] and interactMode == 'target' then MCI.AddEntity(clerks[i], { centreOption(c) }) end
            elseif not near and clerks[i] then
                MCI.RemoveEntity(clerks[i])
                if DoesEntityExist(clerks[i]) then DeletePed(clerks[i]) end
                clerks[i] = nil
            end
        end
    end
end)

-- for /mcinteract
MCI.Counter('npcs', function()
    local n = 0
    for _ in pairs(clerks) do n = n + 1 end
    return n
end)

---------------------------------
-- no pay for idling: standing still on duty for too long puts the player off duty
---------------------------------
CreateThread(function()
    local minutes = Config.Duty.AfkMinutes or 0
    if minutes <= 0 then return end
    local mark, idleSince = nil, nil
    while true do
        Wait(30000)
        local job = pdata().job
        if job and job.onduty and job.name ~= 'unemployed' then
            local pos = myPos()
            if mark and #(pos - mark) < Config.Duty.AfkMoveMetres then
                idleSince = idleSince or GetGameTimer()
                if GetGameTimer() - idleSince >= minutes * 60000 then
                    TriggerServerEvent('MULTIjobs:server:afk')
                    idleSince = nil
                end
            else
                mark, idleSince = pos, nil
            end
        else
            mark, idleSince = nil, nil
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if screen then SetNuiFocus(false, false) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for _, ped in pairs(clerks) do
        if DoesEntityExist(ped) then DeletePed(ped) end
    end
    for _, c in ipairs(Config.JobCentres) do MCI.RemovePrompt('multijobs_centre_' .. c.id) end
    for _, id in ipairs(jobPrompts) do MCI.RemovePrompt(id) end
    -- MULTItarget drops this script's zones and entity options by itself when it stops
end)

---------------------------------
-- rsg-bossmenu / rsg-gangmenu / rsg-multijob client events
---------------------------------
RegisterNetEvent('rsg-bossmenu:client:mainmenu', later('boss'))
RegisterNetEvent('rsg-bossmenu:client:employeelist', later('boss', 'staff'))
RegisterNetEvent('rsg-bossmenu:client:HireMenu', later('boss', 'hire'))
RegisterNetEvent('rsg-bossmenu:client:SocietyMenu', later('boss', 'money'))
RegisterNetEvent('rsg-bossmenu:client:Stash', function()
    TriggerServerEvent('rsg-bossmenu:server:openinventory', 'boss_' .. tostring(pdata().job and pdata().job.name))
end)
RegisterNetEvent('rsg-gangmenu:client:mainmenu', later('gang'))
RegisterNetEvent('rsg-gangmenu:client:commandmenu', later('gang'))
RegisterNetEvent('rsg-gangmenu:client:employeelist', later('gang', 'staff'))
RegisterNetEvent('rsg-gangmenu:client:HireMenu', later('gang', 'hire'))
RegisterNetEvent('rsg-gangmenu:client:SocietyMenu', later('gang', 'money'))
RegisterNetEvent('rsg-gangmenu:client:Stash', function()
    TriggerServerEvent('rsg-gangmenu:server:openinventory', 'gang_' .. tostring(pdata().gang and pdata().gang.name))
end)
RegisterNetEvent('rsg-multijob:client:openmenu', later('myjobs'))
RegisterNetEvent('rsg-multijob:client:refreshJobs', function()
    if screen == 'myjobs' then TriggerEvent('MULTIjobs:client:changed') end
end)
