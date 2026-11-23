-- ============================================================
-- MULTIadmin :: chat commands
-- The menu's player, world and server actions as chat commands (/heal, /revive, /kick ...).
-- Each one is added through MULTIcore's command list, so the chat box shows it as you type:
-- the command, its arguments in [brackets] and what to type for the argument you are on.
-- They run through Admin.Run: the same permission levels (Config.ActionLevel), rank
-- protection, checks and logging as the menu. Names: Config.ChatCommands (false = off).
-- ============================================================

local CC = Config.ChatCommands or {}

local function reply(src, text, kind)
    if not text or text == '' then return end
    if src == 0 then return print(('[MULTIadmin] %s'):format(text)) end
    Admin.Notify(src, text, { type = kind or 'info' })
end

--- runs an action and tells the admin how it went
local function run(src, action, data, okText)
    local res = Admin.Run(src, action, data)
    if res.ok then
        reply(src, res.msg or okText or _L('cmd_done'), 'success')
    else
        reply(src, res.msg or _L('err_failed'), 'error')
    end
end

--- the rest of the words from the n-th on, as one text
local function rest(args, n)
    local out = {}
    for i = n, #args do out[#out + 1] = args[i] end
    return table.concat(out, ' ')
end

--- player id from the first word; empty = the admin themself (when self is allowed)
local function idOr(src, word, selfOk)
    local id = tonumber(word)
    if id then return math.floor(id) end
    if selfOk and src ~= 0 then return src end
    return nil
end

local function join(list)
    local out = {}
    for _, v in ipairs(list or {}) do out[#out + 1] = tostring(v) end
    return table.concat(out, ', ')
end

local P = {
    idSelf = function() return { name = 'id', help = _L('p_id_self') } end,
    id = function() return { name = 'id', help = _L('p_id') } end,
    reason = function() return { name = 'reason', help = _L('p_reason') } end,
}

-- action -> { args = function() -> argument list, run = function(src, args) }
local defs = {
    heal = {
        args = function() return { P.idSelf() } end,
        run = function(src, a) run(src, 'heal', { target = idOr(src, a[1], true) }) end,
    },
    revive = {
        args = function() return { P.idSelf() } end,
        run = function(src, a) run(src, 'revive', { target = idOr(src, a[1], true) }) end,
    },
    kill = {
        args = function() return { P.idSelf() } end,
        run = function(src, a) run(src, 'kill', { target = idOr(src, a[1], true) }) end,
    },
    ['goto'] = {
        args = function() return { P.id() } end,
        run = function(src, a) run(src, 'goto', { target = idOr(src, a[1], false) }) end,
    },
    bring = {
        args = function() return { P.id() } end,
        run = function(src, a) run(src, 'bring', { target = idOr(src, a[1], false) }) end,
    },
    freeze = {
        args = function() return { P.id() } end,
        run = function(src, a) run(src, 'freeze', { target = idOr(src, a[1], false) }) end,
    },
    spectate = {
        args = function() return { { name = 'id', help = _L('p_spectate') } } end,
        run = function(src, a)
            local id = tonumber(a[1])
            if id then run(src, 'spectate', { target = math.floor(id) }) else run(src, 'spectate', { stop = true }) end
        end,
    },
    kick = {
        args = function() return { P.id(), P.reason() } end,
        run = function(src, a) run(src, 'kick', { target = idOr(src, a[1], false), reason = rest(a, 2) }) end,
    },
    ban = {
        args = function()
            return { P.id(), { name = 'hours', help = _L('p_hours', join(Config.BanDurations)) }, P.reason() }
        end,
        run = function(src, a) run(src, 'ban', { target = idOr(src, a[1], false), hours = tonumber(a[2]), reason = rest(a, 3) }) end,
    },
    warn = {
        args = function() return { P.id(), P.reason() } end,
        run = function(src, a) run(src, 'warn', { target = idOr(src, a[1], false), reason = rest(a, 2) }) end,
    },
    kit = {
        args = function()
            local list = {}
            for i, k in ipairs(Config.ItemKits or {}) do list[#list + 1] = ('%d = %s'):format(i, tostring(k.label)) end
            return { P.idSelf(), { name = 'kit', help = _L('p_kit', table.concat(list, '; ')) } }
        end,
        run = function(src, a)
            -- "/kit 2" = kit 2 for yourself, "/kit 5 2" = kit 2 for player 5
            if a[1] and not a[2] then return run(src, 'kit', { target = src, kit = tonumber(a[1]) }) end
            run(src, 'kit', { target = idOr(src, a[1], true), kit = tonumber(a[2]) })
        end,
    },
    announce = {
        args = function() return { { name = 'message', help = _L('p_message') } } end,
        run = function(src, a) run(src, 'announce', { text = rest(a, 1) }) end,
    },
    weather = {
        args = function() return { { name = 'type', help = _L('p_weather', join(Config.WeatherTypes)) } } end,
        run = function(src, a) run(src, 'weather', { weather = tostring(a[1] or ''):lower() }) end,
    },
    time = {
        args = function()
            return { { name = 'hour', help = _L('p_hour') }, { name = 'minute', help = _L('p_minute') }, { name = 'freeze', help = _L('p_freeze') } }
        end,
        run = function(src, a)
            if tostring(a[1] or ''):lower() == 'reset' then return run(src, 'time', { reset = true }) end
            run(src, 'time', { hour = tonumber(a[1]), minute = tonumber(a[2] or 0), freeze = tostring(a[3] or ''):lower() == 'freeze' })
        end,
    },
}

-- the order they are added in (the chat list is sorted by name anyway)
local ORDER = { 'heal', 'revive', 'kill', 'goto', 'bring', 'freeze', 'spectate', 'kick', 'ban', 'warn', 'kit', 'announce', 'weather', 'time' }

CreateThread(function()
    if not (RSGCore and RSGCore.Commands and RSGCore.Commands.Add) then return end
    for _, action in ipairs(ORDER) do
        local name, def = CC[action], defs[action]
        if name and name ~= '' and def then
            -- who may use it: the action's level; admins may always use mod commands
            local level = Config.ActionLevel[action] or 'admin'
            local fn = function(src, args) def.run(src, args or {}) end
            if level == 'mod' then
                RSGCore.Commands.Add(name, _L('cmd_' .. action), def.args(), false, fn, 'admin', 'mod')
            else
                RSGCore.Commands.Add(name, _L('cmd_' .. action), def.args(), false, fn, 'admin')
            end
        end
    end
end)
