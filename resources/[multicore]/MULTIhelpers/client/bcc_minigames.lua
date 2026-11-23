-- ============================================================
-- MULTIhelpers :: bcc-minigames stand-in
-- MiniGame = exports['bcc-minigames'].initiate()
--   MiniGame.Start(name, cfg, callback)   skillcheck, lockpick, rps, hammertime, cowmilker, diceroller
--   MiniGame.Stop()
--   MiniGame.Trigger(name, cfg)           a follow-up command for the running game (dice roller)
-- Drawn on MULTIhelpers' page by html/minigames/minigames.js as plain MULTI skill checks.
-- Own code, written from the public description of the API. GPL v3.
-- ============================================================

local GAMES = {
    skillcheck = { focus = true,  cursor = false },
    lockpick   = { focus = true,  cursor = true },
    rps        = { focus = true,  cursor = true },
    hammertime = { focus = true,  cursor = true },
    cowmilker  = { focus = true,  cursor = false },
    diceroller = { focus = false, cursor = false },
}

local current = nil   -- { token, name, cb, owner }
local seq = 0

local function copy(t, seen)
    if type(t) ~= 'table' then
        local tt = type(t)
        if tt == 'function' or tt == 'userdata' then return nil end
        return t
    end
    if rawget(t, '__cfx_functionReference') ~= nil then return nil end
    seen = seen or {}
    if seen[t] then return nil end
    seen[t] = true
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v, seen) end
    seen[t] = nil
    return out
end

local function setFocus(game, cfg)
    if not game then
        Helpers.SetFocus('minigame', nil)
        return
    end
    local def = GAMES[game]
    local focus = cfg.focus
    if focus == nil then focus = def.focus end
    local cursor = cfg.cursor
    if cursor == nil then cursor = def.cursor end
    if not focus and not cursor then
        Helpers.SetFocus('minigame', nil)
    else
        Helpers.SetFocus('minigame', { keyboard = focus and true or false, cursor = cursor and true or false })
    end
end

local function stop()
    if not current then return end
    current = nil
    Helpers.Send('mgStop')
    setFocus(nil)
end

-- Allow MiniGame:Start(...) as well as MiniGame.Start(...): drop a leading API table.
local function args(a, b, c, d)
    if type(a) == 'table' and type(b) == 'string' then return b, c, d end
    return a, b, c
end

local API = {}

function API.Start(...)
    local name, cfg, cb = args(...)
    name = tostring(name or ''):lower()
    if not GAMES[name] then
        print(('^1[MULTIhelpers] bcc-minigames: unknown game %s^7'):format(name))
        return false
    end
    if current then stop() end
    cfg = copy(type(cfg) == 'table' and cfg or {}) or {}
    seq = seq + 1
    current = { token = seq, name = name, cb = cb, owner = GetInvokingResource() }
    Helpers.Send('mgStart', { token = seq, game = name, cfg = cfg })
    setFocus(name, cfg)
    return true
end

function API.Stop()
    stop()
end

function API.Trigger(...)
    local name, cfg = args(...)
    name = tostring(name or ''):lower()
    cfg = copy(type(cfg) == 'table' and cfg or {}) or {}
    if not current or current.name ~= name then
        -- nothing of that kind running: a dice command starts the roller
        if name == 'diceroller' then return API.Start(name, cfg, nil) end
        return false
    end
    Helpers.Send('mgTrigger', { token = current.token, cfg = cfg })
    return true
end

-- ------------------------------------------------------------ from the page
RegisterNUICallback('mgResult', function(d, reply)
    reply('ok')
    if not current or type(d) ~= 'table' or d.token ~= current.token then return end
    local cb = current.cb
    current = nil
    Helpers.Send('mgStop')
    setFocus(nil)
    if cb then CreateThread(function() Helpers.SafeCall(cb, d.result or {}) end) end
end)

-- dice roller: progress events while the game keeps running
RegisterNUICallback('mgEvent', function(d, reply)
    reply('ok')
    if not current or type(d) ~= 'table' or d.token ~= current.token then return end
    local cb = current.cb
    if cb then CreateThread(function() Helpers.SafeCall(cb, d.result or {}) end) end
end)

-- the player closed the dice roller (Escape)
RegisterNUICallback('mgClosed', function(d, reply)
    reply('ok')
    if current and type(d) == 'table' and d.token == current.token then stop() end
end)

AddEventHandler('onClientResourceStop', function(res)
    if current and current.owner == res then
        current.cb = nil
        stop()
    end
end)

-- ------------------------------------------------------------ export
local function initiate()
    return API
end

-- answered only as exports['bcc-minigames'].initiate(): MULTIhelpers' own 'initiate' is vorp_progressbar's
Helpers.ExportAs('initiate', initiate, { 'bcc-minigames' })
