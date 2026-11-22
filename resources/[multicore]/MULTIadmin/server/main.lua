-- ============================================================
-- MULTIadmin :: server core
-- Permission checks, logging and the player list. Every action in
-- server/actions.lua goes through Admin.Allowed() first; nothing the
-- client sends is trusted.
-- ============================================================

RSGCore = exports['rsg-core']:GetCoreObject()
Admin = {}

local LEVEL = { none = 0, mod = 1, admin = 2 }
Admin.LEVEL = LEVEL

local function anyPass(src, list, fn)
    for _, name in ipairs(list or {}) do
        if fn(src, name) then return true end
    end
    return false
end

local function hasLevel(src, name) return RSGCore.Functions.HasPermission(src, name) end
local function hasAce(src, name) return IsPlayerAceAllowed(src, name) end

--- 2 = admin, 1 = mod, 0 = nobody. Console (src 0) counts as admin.
function Admin.Level(src)
    src = tonumber(src)
    if src == 0 then return LEVEL.admin end
    if not src or not GetPlayerName(src) then return LEVEL.none end
    local p = Config.Permissions
    if anyPass(src, p.Admin.Levels, hasLevel) or anyPass(src, p.Admin.Ace, hasAce) then return LEVEL.admin end
    if anyPass(src, p.Mod.Levels, hasLevel) or anyPass(src, p.Mod.Ace, hasAce) then return LEVEL.mod end
    return LEVEL.none
end

--- True when src may do this action (Config.ActionLevel). Unknown actions are refused.
function Admin.Allowed(src, action)
    local need = LEVEL[Config.ActionLevel[action] or '']
    if not need then return false end
    return Admin.Level(src) >= need
end

--- The action list the menu may show for this player.
function Admin.AllowedList(src)
    local out = {}
    for action in pairs(Config.ActionLevel) do
        out[action] = Admin.Allowed(src, action)
    end
    return out
end

--- Mods can't act on admins (Config.ProtectHigherRank). Acting on yourself is always fine.
function Admin.CanTarget(src, target)
    if src == target or src == 0 or not Config.ProtectHigherRank then return true end
    return Admin.Level(src) >= Admin.Level(target)
end

-- ---------------------------------------------------------------
-- Logging: console always, Discord when the convar is set
-- ---------------------------------------------------------------

local function who(src)
    if src == 0 then return _L('console') end
    local name = GetPlayerName(src) or '?'
    local lic = GetPlayerIdentifierByType(src, 'license') or '?'
    return ('%s [%d] (%s)'):format(name, src, lic)
end
Admin.Who = who

function Admin.Log(src, action, detail, target)
    local line = ('%s -> %s%s%s'):format(who(src), action,
        target and _L('log_on', who(target)) or '',
        detail and detail ~= '' and (' : ' .. detail) or '')
    print(('^3[MULTIadmin]^7 %s'):format(line))

    local hook = GetConvar(Config.WebhookConvar, '')
    if hook == '' or not hook:find('^https://') then return end
    PerformHttpRequest(hook, function() end, 'POST', json.encode({
        username = Config.WebhookName,
        embeds = { {
            title = action,
            description = line,
            color = Config.WebhookColor,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }), { ['Content-Type'] = 'application/json' })
end

--- Notifies through MULTIcore's notify system. opts = { title, type, duration, style }
local function notifyData(text, opts)
    opts = opts or {}
    return {
        text = text,
        title = opts.title or _L('admin_title'),
        type = opts.type or 'info',
        duration = opts.duration or Config.NotifyDuration,
        style = opts.style,
    }
end

function Admin.Notify(src, text, opts)
    if src == 0 then return print(('[MULTIadmin] %s'):format(text)) end
    exports.MULTIcore:Notify(src, notifyData(text, opts))
end

--- Same message to every online player (MULTIcore NotifyAll).
function Admin.NotifyAll(text, opts)
    exports.MULTIcore:NotifyAll(notifyData(text, opts))
end

-- ---------------------------------------------------------------
-- VORP user object (account group, warnings), through the core's VORP face
-- ---------------------------------------------------------------

local vorpCore
function Admin.VorpUser(src)
    if not vorpCore then
        local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
        if ok then vorpCore = core end
    end
    return vorpCore and vorpCore.getUser(src) or nil
end

-- ---------------------------------------------------------------
-- Player list
-- ---------------------------------------------------------------

local function round2(n) return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100 end

function Admin.PlayerRow(src)
    local row = { id = src, name = GetPlayerName(src) or '?', ping = GetPlayerPing(src) }
    local P = RSGCore.Functions.GetPlayer(src)
    if P then
        local d = P.PlayerData
        local ci = d.charinfo or {}
        row.charName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        row.citizenid = d.citizenid
        row.charId = d.id
        row.job = d.job and d.job.name or nil
        row.jobLabel = d.job and d.job.label or nil
        row.grade = d.job and d.job.grade and d.job.grade.level or 0
        row.gradeName = d.job and d.job.grade and d.job.grade.name or nil
        local m = d.money or {}
        row.cash, row.bank, row.gold, row.rol = round2(m.cash), round2(m.bank), round2(m.gold), round2(m.rol)
    end
    local user = Admin.VorpUser(src)
    row.group = user and user.group or nil
    row.warnings = user and user.getPlayerwarnings and user.getPlayerwarnings() or 0
    row.staff = ({ [0] = '', [1] = 'mod', [2] = 'admin' })[Admin.Level(src)]
    row.frozen = Admin.Frozen[src] == true
    return row
end

Admin.Frozen = {}

function Admin.PlayerList()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        list[#list + 1] = Admin.PlayerRow(tonumber(id))
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function jobList()
    local out = {}
    for name, j in pairs(RSGCore.Shared.Jobs or {}) do
        local grades = {}
        for g, gd in pairs(j.grades or {}) do
            grades[#grades + 1] = { level = tonumber(g) or 0, name = type(gd) == 'table' and gd.name or tostring(g) }
        end
        table.sort(grades, function(a, b) return a.level < b.level end)
        out[#out + 1] = { name = name, label = j.label or name, grades = grades }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

-- every item MULTIinventory knows, for the give item search: { { name, label }, ... } by label
local function itemList()
    local ok, items = pcall(function() return exports.MULTIinventory:GetItems() end)
    local out = {}
    if ok and type(items) == 'table' then
        for name, def in pairs(items) do
            if type(name) == 'string' and type(def) == 'table' then
                out[#out + 1] = { name = name, label = tostring(def.label or name) }
            end
        end
    end
    table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
    return out
end

local function kitList()
    local out = {}
    for i, k in ipairs(Config.ItemKits or {}) do out[#out + 1] = { id = i, label = tostring(k.label or ('Kit ' .. i)) } end
    return out
end

-- Menu open: the client gets the data only when the server says yes
lib.callback.register('MULTIadmin:open', function(src)
    local level = Admin.Level(src)
    if level == LEVEL.none then return false end
    Admin.Log(src, 'menu', 'opened the admin menu')
    local canItems = Admin.Allowed(src, 'item') or Admin.Allowed(src, 'kit')
    return {
        items = canItems and itemList() or {},
        kits = canItems and kitList() or {},
        level = level == LEVEL.admin and 'admin' or 'mod',
        allowed = Admin.AllowedList(src),
        players = Admin.PlayerList(),
        jobs = jobList(),
        groups = Config.Groups,
        moneyTypes = Config.MoneyTypes,
        banDurations = Config.BanDurations,
        notifyTypes = Config.NotifyTypes,
        notifyStyles = Config.NotifyStyles,
        ui = Config.Ui,
        locale = _LT(),
        localeCode = _LCode(),
        weatherTypes = Config.WeatherTypes,
        spawnPresets = Config.SpawnPresets,
        world = GlobalState.multiadminWorld,
        self = src,
    }
end)

lib.callback.register('MULTIadmin:players', function(src)
    if Admin.Level(src) == LEVEL.none then return false end
    return Admin.PlayerList()
end)

AddEventHandler('playerDropped', function()
    Admin.Frozen[source] = nil
end)
