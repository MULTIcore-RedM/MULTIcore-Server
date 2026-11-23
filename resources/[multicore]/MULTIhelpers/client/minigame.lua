-- ============================================================
-- MULTIhelpers :: skill bar (stands in for syn_minigame and fx-minigame)
--
--   local result = exports['syn_minigame']:taskBar(difficulty, skillGap)
--   local result = exports['fx-minigame']:taskBar(difficulty, skillGap)
--     difficulty  ms the marker takes to cross the bar (lower = harder)
--     skillGap    width of the target zone in % of the bar (lower = harder)
--   Waits for the player and returns 100 on a hit, 0 on a miss (Esc or no press = miss).
--
-- A marker sweeps once across a bar in the MULTI look; the player presses the
-- key (Config.Minigame.Key, E) while it is inside the marked zone.
-- Own code, written from the public API description. GPL v3, part of MULTIcore.
-- ============================================================

local Cfg = Config.Minigame

local running = nil     -- { token, p = promise, owner }
local seq = 0

local function finish(ok)
    local r = running
    if not r then return end
    running = nil
    Helpers.SetFocus('skill', nil)
    r.p:resolve(ok and 100 or 0)
end

local function taskBar(difficulty, skillGap)
    -- one bar at a time: a second caller waits its turn
    while running do Wait(50) end

    local sweep = math.max(tonumber(Cfg.MinSweep) or 600, math.floor(tonumber(difficulty) or 3000))
    local zoneFrom, zoneTo = tonumber(Cfg.ZoneFrom) or 30, tonumber(Cfg.ZoneTo) or 95
    local width = tonumber(skillGap) or 10
    width = math.max(tonumber(Cfg.MinZone) or 4, math.min(tonumber(Cfg.MaxZone) or 50, width))
    width = math.min(width, zoneTo - zoneFrom)
    local start = zoneFrom + math.random() * math.max(0, zoneTo - zoneFrom - width)

    seq = seq + 1
    running = { token = seq, p = promise.new(), owner = GetInvokingResource() }
    local r = running
    local key = tostring(Cfg.Key or 'E')
    Helpers.SetFocus('skill', { keyboard = true, cursor = false })
    Helpers.Send('skillShow', {
        token = seq, duration = sweep, zoneStart = start, zoneWidth = width, key = key,
        hint = _L('skill_hint', '<span class="mh-key">' .. key:upper() .. '</span>'),
    })
    -- the page ends it when the marker reaches the end; this is only a safety net
    SetTimeout(sweep + 3000, function()
        if running == r then
            Helpers.Send('skillHide')
            finish(false)
        end
    end)
    return Citizen.Await(r.p)
end

RegisterNUICallback('skill', function(d, reply)
    reply('ok')
    if not running or type(d) ~= 'table' or d.token ~= running.token then return end
    finish(d.ok == true)
end)

-- the calling script stopped: end its bar as a miss
AddEventHandler('onClientResourceStop', function(res)
    if running and running.owner == res then
        Helpers.Send('skillHide')
        finish(false)
    end
end)

Helpers.Export('taskBar', taskBar, { 'syn_minigame', 'fx-minigame' })
