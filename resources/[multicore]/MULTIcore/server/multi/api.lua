-- ============================================================
-- MULTIcore :: native API (server)
-- MULTIcore's own short functions for scripts made only for MULTIcore.
-- Everything works by player source, so nothing is copied between resources.
--
--   exports.MULTIcore:GetCharacter(src)          -- or MC.GetCharacter(src) with @MULTIcore/lib/api.lua
--
-- Full list and examples: docs/API.md
-- ============================================================

local MC = {}
local MONEY_DEFAULT = 'cash'

local function P(src)
    src = tonumber(src)
    return src and RSGCore.Functions.GetPlayer(src) or nil
end

local function inv() return GetResourceState('MULTIinventory') == 'started' and exports.MULTIinventory or nil end

local function copyRole(r)
    if type(r) ~= 'table' then return nil end
    local g = type(r.grade) == 'table' and r.grade or {}
    return {
        name = r.name, label = r.label,
        grade = tonumber(g.level) or 0, gradeLabel = g.name,
        isBoss = r.isboss == true or g.isboss == true,
        onDuty = r.onduty == true,
    }
end

-- ---------- players ----------

--- True when the source has a character loaded.
function MC.IsLoggedIn(src) return P(src) ~= nil end

--- The sources of every player with a character loaded.
function MC.GetPlayers()
    local list = {}
    for src in pairs(RSGCore.Players) do list[#list + 1] = src end
    table.sort(list)
    return list
end

--- A plain copy of the character: { citizenid, firstname, lastname, name, gender, job, gang, money }.
function MC.GetCharacter(src)
    local p = P(src)
    if not p then return nil end
    local d, ci = p.PlayerData, p.PlayerData.charinfo or {}
    local money = {}
    for k, v in pairs(d.money or {}) do money[k] = v end
    return {
        source = d.source, citizenid = d.citizenid,
        firstname = ci.firstname, lastname = ci.lastname,
        name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        gender = ci.gender,
        job = copyRole(d.job), gang = copyRole(d.gang),
        money = money,
    }
end

--- The source of an online character, or nil.
function MC.GetSourceByCitizenId(citizenid)
    local p = citizenid and RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    return p and p.PlayerData.source or nil
end

--- True when the player is an admin (RSG permission 'admin' or 'god', or ace 'command').
function MC.IsAdmin(src)
    src = tonumber(src)
    if not src then return false end
    return RSGCore.Functions.HasPermission(src, 'admin') or RSGCore.Functions.HasPermission(src, 'god')
        or IsPlayerAceAllowed(tostring(src), 'command') == true
end

-- ---------- money ----------
-- account: 'cash' (default), 'bank', 'gold' or any money type in config.lua

function MC.GetMoney(src, account)
    local p = P(src)
    return p and (p.Functions.GetMoney(account or MONEY_DEFAULT) or 0) or 0
end

--- Adds money. Returns true when it was added.
function MC.AddMoney(src, amount, account, reason)
    local p = P(src)
    amount = tonumber(amount)
    if not p or not amount or amount <= 0 then return false end
    return p.Functions.AddMoney(account or MONEY_DEFAULT, amount, reason or GetInvokingResource() or 'MULTIcore') == true
end

--- Takes money. Returns false (and takes nothing) when the player does not have enough.
function MC.RemoveMoney(src, amount, account, reason)
    local p = P(src)
    amount = tonumber(amount)
    account = account or MONEY_DEFAULT
    if not p or not amount or amount <= 0 then return false end
    if (p.Functions.GetMoney(account) or 0) < amount then return false end
    return p.Functions.RemoveMoney(account, amount, reason or GetInvokingResource() or 'MULTIcore') == true
end

-- ---------- jobs and gangs ----------

function MC.GetJob(src) local p = P(src) return p and copyRole(p.PlayerData.job) or nil end
function MC.GetGang(src) local p = P(src) return p and copyRole(p.PlayerData.gang) or nil end

--- Sets the job (job names from shared/jobs.lua). Returns true when done.
function MC.SetJob(src, job, grade)
    local p = P(src)
    return p and p.Functions.SetJob(job, tostring(grade or 0)) == true or false
end

function MC.SetGang(src, gang, grade)
    local p = P(src)
    return p and p.Functions.SetGang(gang, tostring(grade or 0)) == true or false
end

--- HasJob(src, 'blacksmith') or HasJob(src, { 'vallaw', 'stdenlaw' }, minGrade, mustBeOnDuty)
function MC.HasJob(src, jobs, minGrade, onDuty)
    local j = MC.GetJob(src)
    if not j then return false end
    local ok = false
    if type(jobs) == 'table' then
        for _, n in ipairs(jobs) do if n == j.name then ok = true break end end
    else
        ok = j.name == jobs
    end
    if not ok then return false end
    if minGrade and j.grade < tonumber(minGrade) then return false end
    if onDuty and not j.onDuty then return false end
    return true
end

function MC.SetDuty(src, onDuty)
    local p = P(src)
    if not p then return false end
    p.Functions.SetJobDuty(onDuty == true)
    return true
end

-- ---------- saved character data ----------
-- metadata survives log out; use your script's name in the key, e.g. 'mymod_level'

function MC.GetMeta(src, key) local p = P(src) return p and p.PlayerData.metadata[key] or nil end

function MC.SetMeta(src, key, value)
    local p = P(src)
    if not p or type(key) ~= 'string' then return false end
    p.Functions.SetMetaData(key, value)
    return true
end

-- ---------- items (MULTIinventory) ----------

local function playerInv(src) local I = inv() return I and I:PlayerInv(src) or nil, I end

--- Gives an item. Returns true when it fitted.
function MC.GiveItem(src, name, amount, info)
    local id, I = playerInv(src)
    if not id then return false end
    return I:AddItem(id, name, tonumber(amount) or 1, info, nil, GetInvokingResource()) == true
end

--- Takes an item. Returns false (and takes nothing) when the player has too few.
function MC.TakeItem(src, name, amount)
    local id, I = playerInv(src)
    amount = tonumber(amount) or 1
    if not id or (I:Count(id, name) or 0) < amount then return false end
    return I:RemoveItem(id, name, amount, nil, nil, GetInvokingResource()) == true
end

function MC.CountItem(src, name)
    local id, I = playerInv(src)
    return id and (I:Count(id, name) or 0) or 0
end

function MC.HasItem(src, name, amount) return MC.CountItem(src, name) >= (tonumber(amount) or 1) end

--- True when the item would fit (weight and slots).
function MC.CanCarry(src, name, amount)
    local id, I = playerInv(src)
    return id and I:CanAdd(id, name, tonumber(amount) or 1) == true or false
end

--- Adds an item to the item list at start: { name, label, weight, description, image, stack = true }
function MC.RegisterItem(def)
    local I = inv()
    return I and I:RegisterItem(def) or false
end

--- fn(src, item) runs when a player uses the item. Removed again when your resource stops.
function MC.RegisterUsableItem(name, fn)
    local I = inv()
    if not I then return false end
    return I:RegisterUsable(name, function(src, item) fn(src, item) end, { resource = GetInvokingResource(), face = 'multi' })
end

-- ---------- version ----------

function MC.GetApiVersion() return 1 end

MULTI.Api = MC
for name, fn in pairs(MC) do exports(name, fn) end
