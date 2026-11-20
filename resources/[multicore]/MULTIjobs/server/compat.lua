-- ============================================================
-- MULTIjobs :: server - rsg-bossmenu, rsg-gangmenu, rsg-multijob
-- MULTIjobs answers to these three names (fxmanifest provide), so RSG v2
-- scripts that call their exports, events or callbacks keep working.
-- Names and argument shapes come from the RSG v2 framework (GPL v3);
-- every call runs through the same checks as the MULTIjobs menus.
-- ============================================================

local RSGCore = exports['rsg-core']:GetCoreObject()
AddEventHandler('RSGCore:Server:UpdateObject', function()
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

local function exportAs(resourceName, exportName, fn)
    AddEventHandler(('__cfx_export_%s_%s'):format(resourceName, exportName), function(setCB) setCB(fn) end)
end

local function say(src, res)
    if res and res.msg then MJ.Notify(src, res.msg, res.ok and 'success' or 'error') end
end

local function fullName(ci)
    ci = ci or {}
    return ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

-- money through MULTIbank (society = job name, gang = prefix .. gang name)
local function balance(acc) return tonumber(MJ.Bank('GetAccountBalance', acc)) or 0 end
local function addMoney(acc, amount, reason) return MJ.Bank('AddAccountMoney', acc, amount, reason) == true end
local function removeMoney(acc, amount, reason) return MJ.Bank('RemoveAccountMoney', acc, amount, reason) == true end

---------------------------------
-- shared bits of both menus
---------------------------------
-- RSG's employee list shape: { empSource = citizenid, grade = { name, level }, isboss, name }
local function rsgEmployees(src, kind, orgName)
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return {} end
    local own = kind == 'job' and P.PlayerData.job or P.PlayerData.gang
    if not own or own.name ~= orgName then return {} end
    local res = MJ.Boss(src, kind, 'state')
    if not res.ok then return {} end
    local out = {}
    for _, m in ipairs(res.state.staff) do
        out[#out + 1] = {
            empSource = m.cid,
            grade = { name = m.gradeName, level = m.grade, isboss = m.isboss },
            isboss = m.isboss,
            name = (m.online and _L('tag_online') or _L('tag_offline')) .. ' ' .. m.name,
        }
    end
    return out
end

-- RSG's nearby player list shape
local function rsgNearby(src, kind)
    local res = MJ.Boss(src, kind, 'nearby')
    if not res.ok then return {} end
    local out = {}
    for _, p in ipairs(res.list) do
        local ped = GetPlayerPed(p.id)
        out[#out + 1] = {
            id = p.id, coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0, 0, 0), name = p.name,
            citizenid = p.citizenid, sources = ped, sourceplayer = p.id,
        }
    end
    return out
end

-- only a boss of that job / gang sees its balance
local function ownBalance(src, kind, orgName)
    local P = RSGCore.Functions.GetPlayer(src)
    if not P or type(orgName) ~= 'string' then return 0 end
    local own = kind == 'job' and P.PlayerData.job or P.PlayerData.gang
    if not own or own.name ~= orgName or not own.isboss then return 0 end
    return balance(MJ.Account(kind, orgName))
end

local function stash(src, kind, stashName)
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return end
    local own = kind == 'job' and P.PlayerData.job or P.PlayerData.gang
    local expect = (kind == 'job' and 'boss_' or 'gang_') .. tostring(own and own.name)
    if stashName ~= expect then return end
    local res = MJ.Boss(src, kind, 'stash')
    if not res.ok then say(src, res) end
end

---------------------------------
-- rsg-bossmenu
---------------------------------
exportAs('rsg-bossmenu', 'GetAccount', function(acc) return balance(acc) end)
exportAs('rsg-bossmenu', 'AddMoney', function(acc, amount) return addMoney(acc, amount, 'rsg-bossmenu') end)
exportAs('rsg-bossmenu', 'RemoveMoney', function(acc, amount) return removeMoney(acc, amount, 'rsg-bossmenu') end)

RegisterNetEvent('rsg-bossmenu:server:withdrawMoney', function(amount)
    local src = source
    say(src, MJ.Boss(src, 'job', 'withdraw', { amount = amount }))
end)
RegisterNetEvent('rsg-bossmenu:server:depositMoney', function(amount)
    local src = source
    say(src, MJ.Boss(src, 'job', 'deposit', { amount = amount }))
end)
RegisterNetEvent('rsg-bossmenu:server:GradeUpdate', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    say(src, MJ.Boss(src, 'job', 'setgrade', { cid = data.cid, grade = data.grade }))
end)
RegisterNetEvent('rsg-bossmenu:server:FireEmployee', function(cid)
    local src = source
    say(src, MJ.Boss(src, 'job', 'fire', { cid = cid }))
end)
RegisterNetEvent('rsg-bossmenu:server:HireEmployee', function(target)
    local src = source
    say(src, MJ.Boss(src, 'job', 'hire', { target = target }))
end)
RegisterNetEvent('rsg-bossmenu:server:openinventory', function(stashName)
    stash(source, 'job', stashName)
end)
RSGCore.Functions.CreateCallback('rsg-bossmenu:server:GetAccount', function(src, cb, jobName)
    cb(ownBalance(src, 'job', jobName))
end)
RSGCore.Functions.CreateCallback('rsg-bossmenu:server:GetEmployees', function(src, cb, jobName)
    cb(rsgEmployees(src, 'job', jobName))
end)
RSGCore.Functions.CreateCallback('rsg-bossmenu:getplayers', function(src, cb)
    cb(rsgNearby(src, 'job'))
end)

---------------------------------
-- rsg-gangmenu
---------------------------------
local function gangAcc(acc) return Config.Gang.AccountPrefix .. tostring(acc) end
exportAs('rsg-gangmenu', 'GetGangAccount', function(acc) return balance(gangAcc(acc)) end)
exportAs('rsg-gangmenu', 'AddGangMoney', function(acc, amount) return addMoney(gangAcc(acc), amount, 'rsg-gangmenu') end)
exportAs('rsg-gangmenu', 'RemoveGangMoney', function(acc, amount) return removeMoney(gangAcc(acc), amount, 'rsg-gangmenu') end)

RegisterNetEvent('rsg-gangmenu:server:withdrawMoney', function(amount)
    local src = source
    say(src, MJ.Boss(src, 'gang', 'withdraw', { amount = amount }))
end)
RegisterNetEvent('rsg-gangmenu:server:depositMoney', function(amount)
    local src = source
    say(src, MJ.Boss(src, 'gang', 'deposit', { amount = amount }))
end)
RegisterNetEvent('rsg-gangmenu:server:GradeUpdate', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    say(src, MJ.Boss(src, 'gang', 'setgrade', { cid = data.cid, grade = data.grade }))
end)
RegisterNetEvent('rsg-gangmenu:server:FireMember', function(cid)
    local src = source
    say(src, MJ.Boss(src, 'gang', 'fire', { cid = cid }))
end)
RegisterNetEvent('rsg-gangmenu:server:HireMember', function(target)
    local src = source
    say(src, MJ.Boss(src, 'gang', 'hire', { target = target }))
end)
RegisterNetEvent('rsg-gangmenu:server:openinventory', function(stashName)
    stash(source, 'gang', stashName)
end)
RSGCore.Functions.CreateCallback('rsg-gangmenu:server:GetAccount', function(src, cb, gangName)
    cb(ownBalance(src, 'gang', gangName))
end)
RSGCore.Functions.CreateCallback('rsg-gangmenu:server:GetEmployees', function(src, cb, gangName)
    cb(rsgEmployees(src, 'gang', gangName))
end)
RSGCore.Functions.CreateCallback('rsg-gangmenu:getplayers', function(src, cb)
    cb(rsgNearby(src, 'gang'))
end)

-- admin: /removegang <id> <gang>
RSGCore.Commands.Add('removegang', _L('cmd_removegang'), { { name = 'id', help = _L('cmd_arg_id') }, { name = 'gang', help = _L('cmd_arg_gang') } }, true, function(source, args)
    local T = RSGCore.Functions.GetPlayer(tonumber(args[1]))
    if not T then return MJ.Notify(source, _L('not_online'), 'error') end
    if T.PlayerData.gang.name ~= args[2] then return MJ.Notify(source, _L('not_staff'), 'error') end
    T.Functions.SetGang('none', 0)
    MJ.Notify(source, _L('kicked', fullName(T.PlayerData.charinfo)), 'success')
    MJ.Notify(T.PlayerData.source, _L('you_were_kicked', args[2]), 'error')
    MJ.PushRefresh(T.PlayerData.source)
end, 'admin')

---------------------------------
-- rsg-multijob
---------------------------------
-- rsg-multijob's list shape: { job, salary, jobLabel, gradeLabel, grade }
local function jobList(held)
    local out = {}
    for job, h in pairs(held or {}) do
        local def = RSGCore.Shared.Jobs[job]
        local g = def and def.grades[tostring(tonumber(h.grade) or 0)]
        if g then
            out[#out + 1] = { job = job, salary = g.payment or 0, jobLabel = def.label, gradeLabel = g.name, grade = tonumber(h.grade) or 0 }
        end
    end
    table.sort(out, function(a, b) return a.jobLabel < b.jobLabel end)
    return out
end

local function heldByCid(cid)
    local P = RSGCore.Functions.GetPlayerByCitizenId(cid)
    if P then
        local v = P.PlayerData.metadata.vorp
        return v and v.multijobs or {}, P
    end
    local raw = MySQL.scalar.await('SELECT `metadata` FROM `players` WHERE `citizenid` = ?', { cid })
    if not raw then return nil end
    local ok, md = pcall(json.decode, raw)
    local v = ok and type(md) == 'table' and md.vorp or {}
    return type(v.multijobs) == 'table' and v.multijobs or {}, nil
end

function MJ.RsgJobList(cid, P)
    if P then return jobList(P.PlayerData.metadata.vorp and P.PlayerData.metadata.vorp.multijobs) end
    return jobList((heldByCid(cid)))
end

-- identifier = server id (online) or citizenid (online or offline)
local function resolve(identifier)
    local P
    if type(identifier) == 'number' then P = RSGCore.Functions.GetPlayer(identifier)
    elseif type(identifier) == 'string' then P = RSGCore.Functions.GetPlayerByCitizenId(identifier) end
    local cid = P and P.PlayerData.citizenid or (type(identifier) == 'string' and identifier or nil)
    return cid, P
end

--- rsg-multijob AddJob(identifier, job, grade, bypassMax) -> ok, reason
local function addHeld(identifier, job, grade, bypassMax)
    grade = math.floor(tonumber(grade) or 0)
    local def = type(job) == 'string' and RSGCore.Shared.Jobs[job]
    if not def or Config.MultiJob.NotListed[job] then return false, 'invalid_job' end
    if not def.grades[tostring(grade)] then return false, 'invalid_grade' end
    local cid, P = resolve(identifier)
    if not cid then return false, 'player_not_found' end
    if P then
        local src = P.PlayerData.source
        local max = MJ.MaxJobs(src)
        P = RSGCore.Functions.GetPlayer(src)
        local v = P.PlayerData.metadata.vorp or {}
        v.multijobs = type(v.multijobs) == 'table' and v.multijobs or {}
        local n = 0
        for _ in pairs(v.multijobs) do n = n + 1 end
        if not v.multijobs[job] and not bypassMax and n >= max then return false, 'max_jobs' end
        v.multijobs[job] = { grade = grade, label = def.label }
        P.Functions.SetMetaData('vorp', v)
        if P.PlayerData.job.name == job and tonumber(P.PlayerData.job.grade.level) ~= grade then P.Functions.SetJob(job, grade) end
        MJ.PushRefresh(src)
        return true, nil
    end
    local row = MySQL.single.await('SELECT `metadata` FROM `players` WHERE `citizenid` = ?', { cid })
    if not row then return false, 'player_not_found' end
    local ok, md = pcall(json.decode, row.metadata or '{}')
    md = ok and type(md) == 'table' and md or {}
    md.vorp = type(md.vorp) == 'table' and md.vorp or {}
    md.vorp.multijobs = type(md.vorp.multijobs) == 'table' and md.vorp.multijobs or {}
    local n = 0
    for _ in pairs(md.vorp.multijobs) do n = n + 1 end
    if not md.vorp.multijobs[job] and not bypassMax and n >= Config.MultiJob.FallbackMaxJobs then return false, 'max_jobs' end
    md.vorp.multijobs[job] = { grade = grade, label = def.label }
    MySQL.update.await('UPDATE `players` SET `metadata` = ? WHERE `citizenid` = ?', { json.encode(md), cid })
    if Config.MultiJob.MirrorPlayerJobsTable then
        MySQL.insert.await('INSERT INTO `player_jobs` (`citizenid`, `job`, `grade`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `grade` = VALUES(`grade`)', { cid, job, grade })
        MJ.MirrorForget(cid)
    end
    return true, nil
end

--- rsg-multijob RemoveJob(identifier, job) -> ok, reason
local function removeHeld(identifier, job)
    if type(job) ~= 'string' then return false, 'invalid_job' end
    local cid, P = resolve(identifier)
    if not cid then return false, 'player_not_found' end
    if P then
        local src = P.PlayerData.source
        local v = P.PlayerData.metadata.vorp or {}
        if not (v.multijobs and v.multijobs[job]) and P.PlayerData.job.name ~= job then return false, 'job_not_held' end
        local res = MJ.Quit(src, job)
        return res.ok, res.ok and nil or 'job_not_held'
    end
    local row = MySQL.single.await('SELECT `job`, `metadata` FROM `players` WHERE `citizenid` = ?', { cid })
    if not row then return false, 'player_not_found' end
    local ok, md = pcall(json.decode, row.metadata or '{}')
    md = ok and type(md) == 'table' and md or {}
    local held = md.vorp and type(md.vorp.multijobs) == 'table' and md.vorp.multijobs or {}
    local okJ, active = pcall(json.decode, row.job or '{}')
    active = okJ and type(active) == 'table' and active or {}
    if not held[job] and active.name ~= job then return false, 'job_not_held' end
    held[job] = nil
    local cols, vals = { '`metadata` = ?' }, { json.encode(md) }
    if active.name == job then
        local def = RSGCore.Shared.Jobs.unemployed
        local g = def and def.grades['0'] or {}
        cols[#cols + 1] = '`job` = ?'
        vals[#vals + 1] = json.encode({ name = 'unemployed', label = def and def.label or 'Civilian', type = 'none', onduty = true, payment = g.payment or 0,
            isboss = false, grade = { name = g.name or 'Unemployed', level = 0, payment = g.payment or 0, isboss = false } })
    end
    vals[#vals + 1] = cid
    MySQL.update.await(('UPDATE `players` SET %s WHERE `citizenid` = ?'):format(table.concat(cols, ', ')), vals)
    if Config.MultiJob.MirrorPlayerJobsTable then
        MySQL.update.await('DELETE FROM `player_jobs` WHERE `citizenid` = ? AND `job` = ?', { cid, job })
        MJ.MirrorForget(cid)
    end
    return true, nil
end

local function getJobs(identifier)
    local cid, P = resolve(identifier)
    if not cid then return {} end
    return MJ.RsgJobList(cid, P)
end

exportAs('rsg-multijob', 'AddJob', addHeld)
exportAs('rsg-multijob', 'RemoveJob', removeHeld)
exportAs('rsg-multijob', 'GetJobs', getJobs)
-- rsg-core's /setjob calls this one when rsg-multijob is started
exportAs('rsg-multijob', 'AddJobToPlayer', function(cid, job, grade) return addHeld(cid, job, grade, false) end)
exports('AddJob', addHeld)
exports('RemoveJob', removeHeld)
exports('GetJobs', getJobs)

RegisterNetEvent('rsg-multijob:server:changeJob', function(job)
    local src = source
    say(src, MJ.Switch(src, job))
end)
RegisterNetEvent('rsg-multijob:server:deleteJob', function(job)
    local src = source
    say(src, MJ.Quit(src, job))
end)
-- rsg-multijob's client sends its job on every job update. The server already keeps the
-- active job in the list, so this only re-checks the player's real job (never the sent one).
RegisterNetEvent('rsg-multijob:server:newJob', function()
    local src = source
    MJ.SyncActive(src)
end)

lib.callback.register('rsg-multijob:server:myJobs', function(src)
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return {} end
    return MJ.RsgJobList(P.PlayerData.citizenid, P)
end)
RSGCore.Functions.CreateCallback('rsg-multijob:server:checkjobs', function(src, cb)
    local P = RSGCore.Functions.GetPlayer(src)
    if not P then return cb(false) end
    local n = 0
    for _ in pairs(P.PlayerData.metadata.vorp and P.PlayerData.metadata.vorp.multijobs or {}) do n = n + 1 end
    cb(n < MJ.MaxJobs(src))
end)

-- admin: /removejob <id> <job>
RSGCore.Commands.Add('removejob', _L('cmd_removejob'), { { name = 'id', help = _L('cmd_arg_id') }, { name = 'job', help = _L('cmd_arg_job') } }, true, function(source, args)
    local id = tonumber(args[1])
    local T = id and RSGCore.Functions.GetPlayer(id)
    if not T then return MJ.Notify(source, _L('not_online'), 'error') end
    local ok = removeHeld(id, args[2])
    MJ.Notify(source, ok and _L('job_removed_admin', tostring(args[2]), id) or _L('not_held'), ok and 'success' or 'error')
end, 'admin')
