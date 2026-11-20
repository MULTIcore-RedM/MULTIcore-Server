-- ============================================================
-- MULTIcore :: accounts
-- One account per player (the `users` table, VORP shape). Holds the
-- account group, warnings, character slots and multi-job limit. The
-- account group is mirrored to an ACE principal so RSG permission
-- checks and VORP group checks agree.
-- ============================================================

MULTI.Accounts = { bySource = {} }
local Accounts = MULTI.Accounts
local cfg = MULTIConfig.Vorp

--- The identifier VORP scripts see for this player (steam by default, else license).
function Accounts.Identifier(src)
    if cfg.Identifier == 'steam' then
        local steam = GetPlayerIdentifierByType(src, 'steam')
        if steam then return steam end
    end
    return GetPlayerIdentifierByType(src, 'license')
end

local function applyPrincipal(license, oldGroup, newGroup)
    if not license then return end
    local old = oldGroup and cfg.GroupPrincipals[oldGroup]
    local new = newGroup and cfg.GroupPrincipals[newGroup]
    if old and old ~= new then
        ExecuteCommand(('remove_principal identifier.%s %s'):format(license, old))
    end
    if new and new ~= old then
        ExecuteCommand(('add_principal identifier.%s %s'):format(license, new))
    end
end

local function fromRow(src, row, identifier, license)
    return {
        source = src,
        identifier = identifier,
        license = license,
        group = row.group or cfg.DefaultGroup,
        warnings = tonumber(row.warnings) or 0,
        maxCharacters = tonumber(row.char) or cfg.MaxCharacters,
        maxJobs = tonumber(row.max_jobs) or cfg.MaxJobs,
        banneduntil = tonumber(row.banneduntil) or 0,
    }
end

--- Loads (or creates) the account for an online player. Cached until they leave.
function Accounts.Load(src)
    local cached = Accounts.bySource[src]
    if cached then return cached end
    MULTI.Schema.Wait()
    local identifier = Accounts.Identifier(src)
    if not identifier then return nil end
    local license = GetPlayerIdentifierByType(src, 'license')
    MySQL.insert.await('INSERT IGNORE INTO users (identifier, `group`, `char`, max_jobs, license) VALUES (?, ?, ?, ?, ?)',
        { identifier, cfg.DefaultGroup, cfg.MaxCharacters, cfg.MaxJobs, license })
    local row = MySQL.single.await('SELECT * FROM users WHERE identifier = ?', { identifier }) or {}
    if license and row.license ~= license then
        MySQL.update('UPDATE users SET license = ? WHERE identifier = ?', { license, identifier })
    end
    local acc = fromRow(src, row, identifier, license)
    Accounts.bySource[src] = acc
    applyPrincipal(license, nil, acc.group)
    return acc
end

function Accounts.Get(src) return Accounts.bySource[src] or Accounts.Load(src) end

function Accounts.SetGroup(src, group)
    local acc = Accounts.Get(src)
    if not acc or type(group) ~= 'string' then return false end
    local old = acc.group
    acc.group = group
    MySQL.update('UPDATE users SET `group` = ? WHERE identifier = ?', { group, acc.identifier })
    applyPrincipal(acc.license, old, group)
    return true, old
end

function Accounts.SetWarnings(src, n)
    local acc = Accounts.Get(src)
    if not acc then return false end
    acc.warnings = math.max(0, math.floor(tonumber(n) or 0))
    MySQL.update('UPDATE users SET warnings = ? WHERE identifier = ?', { acc.warnings, acc.identifier })
    return true
end

function Accounts.SetMaxJobs(src, n)
    local acc = Accounts.Get(src)
    if not acc then return false end
    acc.maxJobs = math.max(0, math.floor(tonumber(n) or 0))
    MySQL.update('UPDATE users SET max_jobs = ? WHERE identifier = ?', { acc.maxJobs, acc.identifier })
    return true
end

-- VORP-only character fields live in metadata.vorp, so both faces read one store
function Accounts.VorpDefaults(PlayerData)
    local m = PlayerData.metadata
    m.vorp = m.vorp or {}
    local v = m.vorp
    v.group = v.group or 'user'
    v.xp = tonumber(v.xp) or 0
    v.age = tonumber(v.age) or 0
    v.nickname = v.nickname or ''
    v.description = v.description or ''
    v.skills = v.skills or {}
    v.multijobs = v.multijobs or {}
    -- item count the satchel holds (VORP invCapacity). invBase remembers the default the
    -- character got; when the owner changes DefaultInvCapacity, existing characters move with
    -- it and keep any upgrade they were given (updateInvCapacity). Characters made before
    -- invBase existed got the old default of 35.
    local base = math.max(0, math.floor(tonumber(cfg.DefaultInvCapacity) or 200))
    if tonumber(v.invCapacity) == nil then
        v.invCapacity = base
    elseif tonumber(v.invBase) ~= base then
        local oldBase = tonumber(v.invBase) or 35
        v.invCapacity = math.max(0, math.floor(tonumber(v.invCapacity) + base - oldBase))
    else
        v.invCapacity = tonumber(v.invCapacity)
    end
    v.invBase = base
    v.isdead = v.isdead == true
    v.hours = tonumber(v.hours) or 0
end

--- Called by the player object just before a character goes live.
function Accounts.OnCharacterLoaded(Player)
    Accounts.Load(Player.PlayerData.source)
    Accounts.VorpDefaults(Player.PlayerData)
    -- looks read now, so vorp:SelectedCharacter fires inside PlayerLoaded without a database wait
    MULTI.Appearance.Preload(Player.PlayerData.citizenid)
end

AddEventHandler('playerDropped', function()
    Accounts.bySource[source] = nil
end)

-- Test hook: lets the self-test give a fake player an account without a real connection
function Accounts._Inject(src, acc) Accounts.bySource[src] = acc end
