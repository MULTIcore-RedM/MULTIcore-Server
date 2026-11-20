--[[
    Tailor shop points on the client: one target per point (synced from the server).
      craft   -> Outfit Designer, Sew cloth & notions      (staff)
      store   -> Tailor's counter                          (everyone; staff see stock / orders)
      boss    -> Tailor's office                           (boss)
      storage -> Stockroom                                 (staff)
    The job check here only hides options; the server decides.
]]
TPoints = TPoints or { list = {} }

local blips = {}

---Best-effort job of the local character { name, grade } (nil = unknown -> options stay visible).
function TCJob()
    if MBridge.IsRsg then
        local ok, d = pcall(function() return exports['rsg-core']:GetCoreObject().Functions.GetPlayerData() end)
        local job = ok and d and d.job
        if job and job.name then
            local g = type(job.grade) == 'table' and tonumber(job.grade.level) or tonumber(job.grade) or 0
            return { name = tostring(job.name):lower(), grade = g, isboss = job.isboss == true }
        end
        return nil
    end
    local st = LocalPlayer.state
    local c = st and st.Character
    if type(c) == 'table' and c.Job then
        -- grade unknown on this client -> treat as high so no option is hidden by mistake
        return { name = tostring(c.Job):lower(), grade = tonumber(c.Grade or c.JobGrade or c.jobGrade) or 99 }
    end
    return nil
end

local function hint(p, boss)
    local job = TCJob()
    if not job then return true end
    local role = TL.roleAt(p, job)
    if boss then return role == 'boss' end
    return role ~= nil
end

local function vec(c) return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0) end

local function removeBlip(id)
    if blips[id] then RemoveBlip(blips[id]) blips[id] = nil end
end

local function addBlip(p)
    removeBlip(p.id)
    local cfg = Config.Tailor.blips or {}
    if cfg.enabled == false or p.kind ~= 'store' or p.blip ~= true then return end
    local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, p.coords.x, p.coords.y, p.coords.z)
    SetBlipSprite(b, cfg.sprite or 1195729388, true)
    SetBlipScale(b, cfg.scale or 0.2)
    local town = TL.townLabel(p.townJob)
    Citizen.InvokeNative(0x9CB1A1623062F402, b, town and ('%s %s'):format(town, cfg.name or 'Tailor') or (cfg.name or 'Tailor'))
    blips[p.id] = b
end

local function setup(p)
    TT.removeZone(p.id)
    removeBlip(p.id)
    local opts
    if p.kind == 'craft' then
        opts = {
            { label = L('opt_designer'), icon = 'fa-solid fa-shirt', canInteract = function() return not TC.view and hint(p) end,
              onSelect = function() CreateThread(function() TDes.open(p) end) end },
            { label = L('opt_sew'), icon = 'fa-solid fa-scissors', canInteract = function() return not TC.view and hint(p) end,
              onSelect = function() CreateThread(function() TSewC.open(p) end) end },
        }
    elseif p.kind == 'store' then
        opts = { { label = L('opt_counter'), icon = 'fa-solid fa-store', canInteract = function() return not TC.view end,
                   onSelect = function() CreateThread(function() TBiz.counter(p) end) end } }
    elseif p.kind == 'boss' then
        opts = { { label = L('opt_office'), icon = 'fa-solid fa-briefcase', canInteract = function() return not TC.view and hint(p, true) end,
                   onSelect = function() CreateThread(function() TBiz.boss(p) end) end } }
    elseif p.kind == 'storage' then
        opts = { { label = L('opt_storage'), icon = 'fa-solid fa-box-open', canInteract = function() return not TC.view and hint(p) end,
                   onSelect = function() TriggerServerEvent('MULTItailor:openStorage', p.id) end } }
    end
    if not opts then return end
    TT.addZone(p.id, { coords = vec(p.coords), radius = p.radius or 1.2, distance = 2.5, title = L('title'), options = opts })
    addBlip(p)
end

local function setAll(list)
    for id in pairs(TPoints.list) do TT.removeZone(id) removeBlip(id) end
    TPoints.list = {}
    for _, p in ipairs(type(list) == 'table' and list or {}) do
        TPoints.list[p.id] = p
        setup(p)
    end
end

RegisterNetEvent('MULTItailor:points', function(list) setAll(list) end)
RegisterNetEvent('MULTItailor:pointSet', function(p)
    if type(p) ~= 'table' or not p.id then return end
    TPoints.list[p.id] = p
    setup(p)
end)
RegisterNetEvent('MULTItailor:pointRemoved', function(id)
    TPoints.list[id] = nil
    TT.removeZone(id)
    removeBlip(id)
end)

CreateThread(function()
    if MBridge.WaitForSession then MBridge.WaitForSession() end
    Wait(1500)
    TriggerServerEvent('MULTItailor:requestPoints')
    TriggerServerEvent('MULTItailor:requestStores')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(blips) do removeBlip(id) end
end)
