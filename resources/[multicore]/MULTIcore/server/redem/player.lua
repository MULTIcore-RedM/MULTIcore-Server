-- ============================================================
-- MULTIcore :: RedEM:RP face - the player object
-- Written from RedEM:RP's public API (the 2023 redem_roleplay); no
-- RedEM:RP code is used. GPL v3, part of MULTIcore by RINGO (RINGOscripting).
--
-- A RedEM:RP script gets this through RedEM.GetPlayer(source). As on
-- RedEM:RP, the fields are a snapshot taken when GetPlayer is called and
-- the methods change the live MULTIcore player (the same player RSG and
-- VORP scripts see).
-- ============================================================

MULTI.Redem = MULTI.Redem or {}
local R = MULTI.Redem

local session = {}   -- [src] = { key = value } (SetSessionVar / GetSessionVar)

AddEventHandler('playerDropped', function() session[source] = nil end)

local function live(src) return RSGCore.Players[tonumber(src) or -1] end

--- RedEM:RP permission group: user | mod | admin | superadmin.
function R.Group(src)
    local acc = MULTI.Accounts.bySource[src]
    local g = acc and acc.group
    if g == 'superadmin' or g == 'admin' or g == 'mod' then return g end
    if RSGCore.Functions.HasPermission(src, 'god') then return 'superadmin' end
    if RSGCore.Functions.HasPermission(src, 'admin') then return 'admin' end
    if RSGCore.Functions.HasPermission(src, 'mod') then return 'mod' end
    return 'user'
end

--- A 6-digit post box number, the same for a character every time.
local function poBox(citizenid)
    local h = 0
    for i = 1, #citizenid do h = (h * 31 + citizenid:byte(i)) % 900000 end
    return 100000 + h
end

--- The fields RedEM:RP puts on a player (and in PlayerData on the client).
function R.Fields(P)
    local d = P.PlayerData
    local ci = d.charinfo or {}
    local job, gang = d.job or {}, d.gang or {}
    local meta = d.metadata or {}
    local acc = MULTI.Accounts.bySource[d.source]
    return {
        source = d.source,
        name = GetPlayerName(d.source) or d.name,
        group = R.Group(d.source),
        license = d.license,
        identifier = acc and acc.identifier or d.license,
        charid = tonumber(d.cid) or 1,
        citizenid = d.citizenid,
        money = d.money and d.money.cash or 0,
        bankmoney = d.money and d.money.bank or 0,
        firstname = ci.firstname,
        lastname = ci.lastname,
        job = job.name or 'unemployed',
        jobgrade = job.grade and tonumber(job.grade.level) or 0,
        gang = gang.name or 'none',
        ganggrade = gang.grade and tonumber(gang.grade.level) or 0,
        pobox = tonumber(meta.pobox) or poBox(d.citizenid or ''),
        jailed = tonumber(meta.injail) or 0,
        metadata = meta,
    }
end

--- The PlayerData table the client gets (redemrp:receivePlayerData).
function R.PlayerData(P)
    local f = R.Fields(P)
    return {
        isLoggedIn = true,
        citizenid = f.citizenid,
        money = f.money,
        bankmoney = f.bankmoney,
        group = f.group,
        firstname = f.firstname,
        lastname = f.lastname,
        charname = ('%s %s'):format(f.firstname or '', f.lastname or ''),
        job = f.job,
        jobgrade = f.jobgrade,
        gang = f.gang,
        ganggrade = f.ganggrade,
        pobox = f.pobox,
        jailed = f.jailed,
        metadata = f.metadata,
    }
end

--- State bags and client data, as RedEM:RP's SendPlayerDataToClient does.
function R.Push(src)
    local P = live(src)
    if not P then return end
    local data = R.PlayerData(P)
    local state = Player(src).state
    -- pcall: a player that is not really connected (tests) has no state bag
    pcall(function() for k, v in pairs(data) do state:set(k, v, true) end end)
    TriggerClientEvent('redemrp:receivePlayerData', src, data)
end

local function money(P, kind, op, n)
    n = tonumber(n)
    if not n or n < 0 then return end
    if op == 'add' then P.Functions.AddMoney(kind, n, 'redem')
    elseif op == 'remove' then P.Functions.RemoveMoney(kind, n, 'redem')
    else P.Functions.SetMoney(kind, n, 'redem') end
end

local function setJob(P, name, grade)
    MULTI.Jobs.Set(P, name, grade)
    TriggerClientEvent('redem_roleplay:JobChange', P.PlayerData.source, P.PlayerData.job.name)
end

local function setGang(P, name, grade)
    if type(name) ~= 'string' then return end
    name = name:lower()
    grade = math.floor(tonumber(grade) or 0)
    if not RSGCore.Shared.Gangs[name] then
        RSGCore.Functions.AddGang(name, { label = name, grades = { [tostring(grade)] = { name = 'Grade ' .. grade } } })
    elseif not RSGCore.Shared.Gangs[name].grades[tostring(grade)] then
        RSGCore.Shared.Gangs[name].grades[tostring(grade)] = { name = 'Grade ' .. grade }
    end
    P.Functions.SetGang(name, grade)
end

--- Builds the RedEM:RP player object for a source (nil until a character is loaded).
function R.BuildPlayer(src)
    src = tonumber(src)
    local P0 = live(src)
    if not P0 then return nil end
    local obj = R.Fields(P0)

    -- every method works on the live player, so a held object never goes stale
    local function with(fn)
        return function(...)
            local P = live(src)
            if not P then return nil end
            return fn(P, ...)
        end
    end

    -- names
    obj.GetName = with(function(P)
        local ci = P.PlayerData.charinfo or {}
        return ('%s %s'):format(ci.firstname or '', ci.lastname or '')
    end)
    obj.GetFirstName = with(function(P) return (P.PlayerData.charinfo or {}).firstname end)
    obj.GetLastName = with(function(P) return (P.PlayerData.charinfo or {}).lastname end)
    obj.SetFirstName = with(function(P, v)
        P.PlayerData.charinfo.firstname = tostring(v)
        P.Functions.UpdatePlayerData()
        R.Push(src)
    end)
    obj.SetLastName = with(function(P, v)
        P.PlayerData.charinfo.lastname = tostring(v)
        P.Functions.UpdatePlayerData()
        R.Push(src)
    end)

    -- ids and group
    obj.GetIdentifier = function() return obj.identifier end
    obj.GetActiveCharacter = function() return obj.charid end
    obj.CitizenId = function() return obj.citizenid end
    obj.GetGroup = function() return R.Group(src) end

    -- money (cash and bank). RemoveMoney checks the balance, unlike stock RedEM:RP.
    obj.GetMoney = with(function(P) return P.PlayerData.money.cash or 0 end)
    obj.AddMoney = with(function(P, n) money(P, 'cash', 'add', n) end)
    obj.RemoveMoney = with(function(P, n) money(P, 'cash', 'remove', n) end)
    obj.SetMoney = with(function(P, n) money(P, 'cash', 'set', n) end)
    obj.GetBankMoney = with(function(P) return P.PlayerData.money.bank or 0 end)
    obj.AddBankMoney = with(function(P, n) money(P, 'bank', 'add', n) end)
    obj.RemoveBankMoney = with(function(P, n) money(P, 'bank', 'remove', n) end)
    obj.SetBankMoney = with(function(P, n) money(P, 'bank', 'set', n) end)

    -- gold: stock RedEM:RP has none (returns 0); MULTIcore has gold, so it works
    obj.getGold = with(function(P) return P.PlayerData.money.gold or 0 end)
    obj.addGold = with(function(P, n) money(P, 'gold', 'add', n) end)
    obj.removeGold = with(function(P, n) money(P, 'gold', 'remove', n) end)
    obj.getXp = function() return 0 end
    obj.getLevel = function() return 0 end

    -- job and gang
    obj.GetJob = with(function(P) return P.PlayerData.job.name end)
    obj.SetJob = with(function(P, name) setJob(P, name, 0) end)
    obj.GetJobGrade = with(function(P) return tonumber(P.PlayerData.job.grade.level) or 0 end)
    obj.SetJobGrade = with(function(P, g) setJob(P, P.PlayerData.job.name, tonumber(g) or 0) end)
    obj.GetGang = with(function(P) return P.PlayerData.gang.name end)
    obj.SetGang = with(function(P, name) setGang(P, name, 0) end)
    obj.GetGangGrade = with(function(P) return tonumber(P.PlayerData.gang.grade.level) or 0 end)
    obj.SetGangGrade = with(function(P, g) setGang(P, P.PlayerData.gang.name, tonumber(g) or 0) end)

    -- post box and jail
    obj.GetPOBox = function() return obj.pobox end
    obj.GetJailTime = with(function(P) return tonumber(P.PlayerData.metadata.injail) or 0 end)
    obj.SetJailTime = with(function(P, n) P.Functions.SetMetaData('injail', tonumber(n) or 0) R.Push(src) end)

    -- metadata
    obj.GetMetaData = with(function(P) return P.PlayerData.metadata end)
    obj.SetMetaData = with(function(P, k, v) P.Functions.SetMetaData(k, v) R.Push(src) end)

    -- free fields and session values
    obj.set = function(k, v)
        obj[k] = v
        local P = live(src)
        if not P then return end
        if k == 'money' then money(P, 'cash', 'set', v)
        elseif k == 'bankmoney' then money(P, 'bank', 'set', v)
        elseif k == 'job' then setJob(P, v, 0)
        elseif k == 'jobgrade' then setJob(P, P.PlayerData.job.name, v)
        end
    end
    obj.get = function(k) return R.Fields(live(src) or P0)[k] or obj[k] end
    obj.SetSessionVar = function(k, v)
        session[src] = session[src] or {}
        session[src][k] = v
    end
    obj.GetSessionVar = function(k) return session[src] and session[src][k] end

    obj.kick = function(reason) DropPlayer(src, tostring(reason or '')) end
    obj.SendPlayerDataToClient = function() R.Push(src) end

    -- the older lowerCamel names, still called by many scripts
    obj.getName = obj.GetName
    obj.getIdentifier = obj.GetIdentifier
    obj.getGroup = obj.GetGroup
    obj.getMoney = obj.GetMoney
    obj.addMoney = obj.AddMoney
    obj.removeMoney = obj.RemoveMoney
    obj.setMoney = obj.SetMoney
    obj.getBankMoney = obj.GetBankMoney
    obj.addBankMoney = obj.AddBankMoney
    obj.removeBankMoney = obj.RemoveBankMoney
    obj.setBankMoney = obj.SetBankMoney
    obj.getJob = obj.GetJob
    obj.setJob = obj.SetJob
    obj.getJobgrade = obj.GetJobGrade
    obj.setJobgrade = obj.SetJobGrade
    obj.getGang = obj.GetGang
    obj.setGang = obj.SetGang
    obj.getSessionVar = obj.GetSessionVar
    obj.setSessionVar = obj.SetSessionVar
    obj.getFirstname = obj.GetFirstName
    obj.getLastname = obj.GetLastName
    obj.getCitizenId = obj.CitizenId

    return obj
end
