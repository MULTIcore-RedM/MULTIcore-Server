-- ============================================================
-- MULTIcore :: VORP face - user and character objects
-- Written from VORP's public API documentation; no VORP code is used.
--
-- A VORP script gets these through Core.getUser(source). Like on VORP,
-- the fields are a snapshot taken when getUser is called, and the
-- methods change the live MULTIcore player (the same player RSG scripts
-- see through RSGCore.Functions.GetPlayer).
-- ============================================================

MULTI.Vorp = MULTI.Vorp or {}
local V = MULTI.Vorp
local cfg = MULTIConfig.Vorp

-- VORP currency numbers -> MULTIcore money types
V.Currency = { [0] = 'cash', [1] = 'gold', [2] = 'rol' }

local function live(src) return RSGCore.Players[src] end

local function genderName(g)
    if g == 1 or g == '1' or g == 'female' or g == 'Female' then return 'female' end
    return 'male'
end

local function vorpMeta(P)
    MULTI.Accounts.VorpDefaults(P.PlayerData)
    return P.PlayerData.metadata.vorp
end

-- Saves metadata.vorp changes and tells the client
local function touch(P)
    P.Functions.SetMetaData('vorp', P.PlayerData.metadata.vorp)
end

local function skillLevel(exp)
    return math.floor((tonumber(exp) or 0) / cfg.SkillLevelXp) + 1
end

--- Plain character fields, VORP names, from a MULTIcore player.
function V.CharacterFields(P)
    local d = P.PlayerData
    local v = vorpMeta(P)
    local ci = d.charinfo or {}
    local job = d.job or {}
    local acc = MULTI.Accounts.bySource[d.source]
    local look = MULTI.Appearance.Get(d.citizenid, 'vorp')
    if not look.skin and not look.comps then
        -- made with MULTIcore's own creator: hand VORP scripts that look instead
        local own = MULTI.Appearance.Get(d.citizenid, 'multi')
        look = { skin = own.skin, comps = own.comps }
    end
    local skills = {}
    for name, s in pairs(v.skills) do
        skills[name] = { Exp = s.Exp or 0, Level = skillLevel(s.Exp) }
    end
    return {
        identifier = acc and acc.identifier or d.license,
        charIdentifier = d.id,
        citizenid = d.citizenid,
        group = v.group,
        job = job.name,
        jobGrade = job.grade and job.grade.level or 0,
        jobLabel = job.label,
        multiJobs = v.multijobs,
        money = d.money.cash or 0,
        gold = d.money.gold or 0,
        rol = d.money.rol or 0,
        xp = v.xp,
        firstname = ci.firstname,
        lastname = ci.lastname,
        status = { hunger = d.metadata.hunger, thirst = d.metadata.thirst, stress = d.metadata.stress },
        coords = d.position,
        isdead = v.isdead or d.metadata.isdead == true,
        skin = look.skin or '{}',
        comps = look.comps or '{}',
        compTints = look.tints or '{}',
        age = v.age,
        gender = genderName(ci.gender),
        charDescription = v.description,
        nickname = v.nickname,
        invCapacity = v.invCapacity,
        skills = skills,
        steamname = d.name,
        hours = v.hours,
    }
end

--- A VORP character object: fields plus methods bound to this player.
function V.BuildCharacter(P)
    local src = P.PlayerData.source
    local c = V.CharacterFields(P)

    -- every method looks the player up again, so it acts on the live data
    local function with(fn)
        return function(...)
            local p = live(src)
            if not p then return false end
            return fn(p, ...)
        end
    end

    -- jobs
    c.setJob = with(function(p, job, silent)
        local grade = p.PlayerData.job and p.PlayerData.job.grade and p.PlayerData.job.grade.level or 0
        return MULTI.Jobs.Set(p, job, grade, nil, silent)
    end)
    c.setJobGrade = with(function(p, grade, silent)
        return MULTI.Jobs.Set(p, p.PlayerData.job.name, grade, p.PlayerData.job.label, silent)
    end)
    c.setJobLabel = with(function(p, label)
        if type(label) ~= 'string' then return false end
        p.PlayerData.job.label = label
        p.Functions.UpdatePlayerData()
        return true
    end)
    c.setMultiJob = with(function(p, job, grade, label)
        local v = vorpMeta(p)
        local acc = MULTI.Accounts.bySource[src]
        if not v.multijobs[job] and acc and V.CountTable(v.multijobs) >= acc.maxJobs then return false end
        v.multijobs[job] = { grade = tonumber(grade) or 0, label = label or job }
        touch(p)
        return true
    end)
    c.removeMultiJob = with(function(p, job)
        local v = vorpMeta(p)
        v.multijobs[job] = nil
        touch(p)
        return true
    end)
    c.getMultiJobsCount = with(function(p) return V.CountTable(vorpMeta(p).multijobs) end)

    -- groups
    c.setGroup = with(function(p, group, silent)
        if type(group) ~= 'string' then return false end
        local v = vorpMeta(p)
        local old = v.group
        v.group = group
        touch(p)
        if not silent then TriggerEvent('vorp:playerGroupChange', src, group, old) end
        return true
    end)

    -- money: 0 = money (cash), 1 = gold, 2 = role tokens
    c.addCurrency = with(function(p, kind, amount)
        local mtype = V.Currency[tonumber(kind) or 0]
        if not mtype then return false end
        return p.Functions.AddMoney(mtype, tonumber(amount) or 0, 'vorp-script')
    end)
    c.removeCurrency = with(function(p, kind, amount)
        local mtype = V.Currency[tonumber(kind) or 0]
        if not mtype then return false end
        return p.Functions.RemoveMoney(mtype, tonumber(amount) or 0, 'vorp-script')
    end)
    c.setMoney = with(function(p, amount) return p.Functions.SetMoney('cash', tonumber(amount) or 0, 'vorp-script') end)
    c.setGold = with(function(p, amount) return p.Functions.SetMoney('gold', tonumber(amount) or 0, 'vorp-script') end)
    c.setRol = with(function(p, amount) return p.Functions.SetMoney('rol', tonumber(amount) or 0, 'vorp-script') end)

    -- experience and skills
    c.setXp = with(function(p, amount)
        vorpMeta(p).xp = math.max(0, math.floor(tonumber(amount) or 0)); touch(p); return true
    end)
    c.addXp = with(function(p, amount)
        local v = vorpMeta(p); v.xp = v.xp + math.max(0, math.floor(tonumber(amount) or 0)); touch(p); return true
    end)
    c.removeXp = with(function(p, amount)
        local v = vorpMeta(p); v.xp = math.max(0, v.xp - math.max(0, math.floor(tonumber(amount) or 0))); touch(p); return true
    end)
    c.setSkills = with(function(p, name, value)
        if type(name) ~= 'string' then return false end
        local v = vorpMeta(p)
        local s = v.skills[name] or { Exp = 0 }
        local before = skillLevel(s.Exp)
        s.Exp = math.max(0, (s.Exp or 0) + (tonumber(value) or 0))
        v.skills[name] = s
        touch(p)
        local after = skillLevel(s.Exp)
        if after ~= before then TriggerEvent('vorp_core:Server:OnPlayerLevelUp', src, name, after, before) end
        return true
    end)

    -- character details
    c.setFirstname = with(function(p, name)
        if type(name) ~= 'string' then return false end
        p.PlayerData.charinfo.firstname = name; p.Functions.SetPlayerData('charinfo', p.PlayerData.charinfo); return true
    end)
    c.setLastname = with(function(p, name)
        if type(name) ~= 'string' then return false end
        p.PlayerData.charinfo.lastname = name; p.Functions.SetPlayerData('charinfo', p.PlayerData.charinfo); return true
    end)
    c.setGender = with(function(p, g)
        p.PlayerData.charinfo.gender = genderName(g) == 'female' and 1 or 0
        p.Functions.SetPlayerData('charinfo', p.PlayerData.charinfo)
        return true
    end)
    c.setAge = with(function(p, age) vorpMeta(p).age = tonumber(age) or 0; touch(p); return true end)
    c.setCharDescription = with(function(p, text) vorpMeta(p).description = tostring(text or ''); touch(p); return true end)
    c.setNickName = with(function(p, text) vorpMeta(p).nickname = tostring(text or ''); touch(p); return true end)
    c.updateInvCapacity = with(function(p, change)
        local v = vorpMeta(p); v.invCapacity = math.max(0, v.invCapacity + (tonumber(change) or 0)); touch(p); return true
    end)

    -- appearance (stored in VORP format, see server/multi/appearance.lua)
    c.updateSkin = with(function(p, value) return MULTI.Appearance.Set(p.PlayerData.citizenid, 'vorp', 'skin', value) end)
    c.updateComps = with(function(p, value) return MULTI.Appearance.Set(p.PlayerData.citizenid, 'vorp', 'comps', value) end)
    c.updateCompTints = with(function(p, value) return MULTI.Appearance.Set(p.PlayerData.citizenid, 'vorp', 'tints', value) end)

    return c
end

function V.CountTable(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

--- Characters of an account, as plain VORP-style tables (for character menus).
function V.AccountCharacters(license)
    local rows = MySQL.query.await('SELECT id, citizenid, charinfo, job, money, metadata FROM players WHERE license = ?', { license }) or {}
    local online = {}
    for _, P in pairs(RSGCore.Players) do online[P.PlayerData.citizenid] = P.PlayerData end
    local out = {}
    for _, r in ipairs(rows) do
        -- a character in play may have changes not saved yet; use its live data
        local live = online[r.citizenid]
        local ci = live and live.charinfo or json.decode(r.charinfo or '{}') or {}
        local job = live and live.job or json.decode(r.job or '{}') or {}
        local money = live and live.money or json.decode(r.money or '{}') or {}
        out[#out + 1] = {
            charIdentifier = r.id,
            citizenid = r.citizenid,
            firstname = ci.firstname,
            lastname = ci.lastname,
            gender = genderName(ci.gender),
            job = job.name,
            jobGrade = job.grade and job.grade.level or 0,
            money = money.cash or 0,
            gold = money.gold or 0,
        }
    end
    return out
end

--- A VORP user object for an online player.
function V.BuildUser(src)
    src = tonumber(src)
    if not src or not GetPlayerName(src) and not RSGCore.Players[src] then return nil end
    local acc = MULTI.Accounts.Get(src)
    if not acc then return nil end
    local P = live(src)
    local user = {
        source = src,
        getGroup = acc.group,
        group = acc.group,
        maxJobsAllowed = acc.maxJobs,
        getUsedCharacter = P and V.BuildCharacter(P) or {},
    }
    user.getIdentifier = function() return acc.identifier end
    user.setGroup = function(group)
        local ok, old = MULTI.Accounts.SetGroup(src, group)
        if ok then TriggerEvent('vorp:userGroupChange', src, group, old) end
        return ok
    end
    user.SetGroup = user.setGroup
    user.setMaxJobsAllowed = function(n) return MULTI.Accounts.SetMaxJobs(src, n) end
    user.getPlayerwarnings = function() return (MULTI.Accounts.bySource[src] or acc).warnings end
    user.setPlayerWarnings = function(n) return MULTI.Accounts.SetWarnings(src, n) end
    user.getUserCharacters = function() return V.AccountCharacters(acc.license) end
    return user
end
