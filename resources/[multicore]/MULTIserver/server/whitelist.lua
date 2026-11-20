-- ============================================================
-- MULTIserver :: whitelist (Config.Whitelist.Enabled, off by default)
-- Identifiers in the multiserver_whitelist table may join. Bans are
-- MULTIadmin's job (its own playerConnecting check); nothing here
-- looks at bans.
-- ============================================================

local W = Config.Whitelist
Whitelist = {}

local kinds = {}
for _, k in ipairs(W.Identifiers) do kinds[k] = true end

--- 'license:abc' -> 'license:abc' when its kind is allowed, else nil.
function Whitelist.Clean(identifier)
    if type(identifier) ~= 'string' then return nil end
    identifier = identifier:gsub('%s', '')
    local kind, value = identifier:match('^(%w+):([%w_%-]+)$')
    if not kind or not kinds[kind:lower()] or #identifier > 100 then return nil end
    return kind:lower() .. ':' .. value
end

--- The identifiers of `list` that the whitelist checks.
function Whitelist.Checked(list)
    local out = {}
    for _, id in ipairs(list or {}) do
        local c = Whitelist.Clean(id)
        if c then out[#out + 1] = c end
    end
    return out
end

--- True when any identifier of the list has a row.
function Whitelist.Allowed(list)
    local ids = Whitelist.Checked(list)
    if #ids == 0 then return false end
    local marks = ('?,'):rep(#ids):sub(1, -2)
    local hit = MySQL.scalar.await(('SELECT 1 FROM multiserver_whitelist WHERE identifier IN (%s) LIMIT 1'):format(marks), ids)
    return hit ~= nil
end

function Whitelist.Add(identifier, note, by)
    local id = Whitelist.Clean(identifier)
    if not id then return false, 'bad_identifier' end
    note = note and tostring(note):sub(1, W.MaxNoteLength) or nil
    local n = MySQL.update.await('INSERT IGNORE INTO multiserver_whitelist (identifier, note, added_by, created) VALUES (?, ?, ?, ?)',
        { id, note, by, os.time() }) or 0
    if n == 0 then return false, 'exists' end
    return true, id
end

function Whitelist.Remove(identifier)
    local id = Whitelist.Clean(identifier)
    if not id then return false, 'bad_identifier' end
    local n = MySQL.update.await('DELETE FROM multiserver_whitelist WHERE identifier = ?', { id }) or 0
    if n == 0 then return false, 'missing' end
    return true, id
end

function Whitelist.Find(identifier)
    local id = Whitelist.Clean(identifier)
    if not id then return nil end
    return MySQL.single.await('SELECT identifier, note, added_by, created FROM multiserver_whitelist WHERE identifier = ?', { id })
end

--- Join check used by the connect handler: true, or false + the text for the player.
function Whitelist.Check(src)
    if not W.Enabled then return true end
    if IsPlayerAceAllowed(src, W.BypassAce) then return true end
    local giveUp = GetGameTimer() + W.DbWaitMs
    while not MS.dbReady and GetGameTimer() < giveUp do Wait(100) end
    local ok, allowed = pcall(Whitelist.Allowed, MS.Identifiers(src))
    if not ok then return false, _L('wl_db_error') end
    if not allowed then
        MS.Debug('whitelist refused %s', GetPlayerName(src) or '?')
        return false, _L('wl_refused')
    end
    return true
end

-- ---------------------------------------------------------------
-- commands: a server id (online player -> their license) or an identifier
-- ---------------------------------------------------------------

local function canUse(src) return src == 0 or IsPlayerAceAllowed(src, W.CommandAce) or MS.IsAdmin(src) end

local function target(arg)
    local id = tonumber(arg)
    if id then
        if not GetPlayerName(id) then return nil end
        return GetPlayerIdentifierByType(id, 'license')
    end
    return arg
end

local function byName(src)
    if src == 0 then return 'console' end
    return GetPlayerIdentifierByType(src, 'license') or tostring(src)
end

RegisterCommand(W.AddCommand, function(src, args)
    if not canUse(src) then return MS.Reply(src, _L('no_permission'), 'error') end
    local id = target(args[1])
    if not id then return MS.Reply(src, _L('wl_usage_add', W.AddCommand), 'error') end
    local note = #args > 1 and table.concat(args, ' ', 2) or nil
    local ok, res = Whitelist.Add(id, note, byName(src))
    if ok then
        MS.Reply(src, _L('wl_added', res), 'success')
        Logs.Add('whitelist', _L('wl_log_title'), 'green', _L('wl_log_added', res, byName(src)))
    else
        MS.Reply(src, _L('wl_' .. res, tostring(id)), 'error')
    end
end, false)

RegisterCommand(W.RemoveCommand, function(src, args)
    if not canUse(src) then return MS.Reply(src, _L('no_permission'), 'error') end
    local id = target(args[1])
    if not id then return MS.Reply(src, _L('wl_usage_remove', W.RemoveCommand), 'error') end
    local ok, res = Whitelist.Remove(id)
    if ok then
        MS.Reply(src, _L('wl_removed', res), 'success')
        Logs.Add('whitelist', _L('wl_log_title'), 'red', _L('wl_log_removed', res, byName(src)))
    else
        MS.Reply(src, _L('wl_' .. res, tostring(id)), 'error')
    end
end, false)

RegisterCommand(W.CheckCommand, function(src, args)
    if not canUse(src) then return MS.Reply(src, _L('no_permission'), 'error') end
    local id = target(args[1])
    if not id then return MS.Reply(src, _L('wl_usage_check', W.CheckCommand), 'error') end
    local row = Whitelist.Find(id)
    if row then
        MS.Reply(src, _L('wl_is_listed', row.identifier, row.note or '-'), 'info')
    else
        MS.Reply(src, _L('wl_not_listed', tostring(id)), 'info')
    end
end, false)

exports('WhitelistAdd', function(identifier, note, by) return Whitelist.Add(identifier, note, by) end)
exports('WhitelistRemove', function(identifier) return Whitelist.Remove(identifier) end)
--- True when any of the identifiers (a list, or a server id's identifiers) is on the whitelist.
exports('IsWhitelisted', function(listOrSrc)
    if type(listOrSrc) ~= 'table' then listOrSrc = MS.Identifiers(listOrSrc) end
    return Whitelist.Allowed(listOrSrc)
end)
