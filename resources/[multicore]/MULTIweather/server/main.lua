-- ============================================================
-- MULTIweather :: server
-- Keeps the one clock and the one weather for the whole server and
-- shares them through GlobalState:
--   GlobalState.multiClock   = { s = second of the day, r = real seconds per game minute (0 = stopped) }
--   GlobalState.multiWeather = { w = weather type, t = blend seconds }
-- Players keep the clock running between syncs on their own.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local DAY = 24 * 60 * 60

local state = {
    second = (Config.Time.StartHour or 8) * 3600,  -- second of the game day
    frozen = false,                                -- clock stopped
    weather = Config.Weather.Start or 'sunny',
    hold = false,                                  -- true = an admin set the weather; no changes by itself
    nextChange = 0,                                -- GetGameTimer() of the next weather change
}

local function log(msg, ...)
    if Config.LogToConsole then print(('[MULTIweather] ' .. msg):format(...)) end
end

local function isType(w)
    for _, t in ipairs(Config.Weather.Types) do if t == w then return true end end
    return false
end

-- ---------------------------------------------------------------
-- clock
-- ---------------------------------------------------------------

--- Real seconds per game minute at this second of the day (0 = stopped).
local function rate(second)
    if state.frozen then return 0 end
    local T = Config.Time
    if T.Mode == 'real' then return 60.0 end   -- one game minute per real minute
    local h = math.floor(second / 3600) % 24
    local night
    if T.NightStart > T.NightEnd then
        night = h >= T.NightStart or h < T.NightEnd
    else
        night = h >= T.NightStart and h < T.NightEnd
    end
    return (night and T.NightMinuteSeconds or T.MinuteSeconds) + 0.0
end

local function realSecond()
    local t = os.time() + math.floor((Config.Time.RealOffsetHours or 0) * 3600)
    return t % DAY
end

local function publishClock()
    GlobalState.multiClock = { s = math.floor(state.second), r = rate(state.second) }
end

local function publishWeather(blend)
    GlobalState.multiWeather = { w = state.weather, t = blend or Config.Weather.TransitionSeconds }
end

local function save()
    if not Config.Time.Remember then return end
    SetResourceKvpInt('second', math.floor(state.second))
    SetResourceKvpInt('frozen', state.frozen and 1 or 0)
    SetResourceKvp('weather', state.weather)
    SetResourceKvpInt('hold', state.hold and 1 or 0)
end

-- ---------------------------------------------------------------
-- weather
-- ---------------------------------------------------------------

local function scheduleNext()
    local range = Config.Weather.ChangeMinutes or { 20, 40 }
    local low = math.floor(range[1] or 20)
    local high = math.max(low, math.floor(range[2] or low))
    state.nextChange = GetGameTimer() + math.random(low, high) * 60000
end

--- The season (Config.Weather.Season) when today's real date is inside it, else nil.
local function activeSeason()
    local S = Config.Weather.Season
    if type(S) ~= 'table' or S.Enabled == false or type(S.Pattern) ~= 'table' then return nil end
    local today = os.date('%Y-%m-%d')
    if type(S.From) == 'string' and today < S.From then return nil end
    if type(S.Until) == 'string' and today > S.Until then return nil end
    return S
end

local function pickNext(from)
    local season = activeSeason()
    local pattern = season and season.Pattern or Config.Weather.Pattern
    local start = season and season.Start or Config.Weather.Start
    local options = pattern[from]
    if not options then
        -- a weather with no pattern line (set by an admin, or the season began / ended):
        -- carry on from the start weather's line
        options = pattern[start] or { [start or 'sunny'] = 1 }
    end
    -- pairs order is not fixed, so walk a sorted list
    local names, total = {}, 0
    for name, weight in pairs(options) do
        if isType(name) then
            names[#names + 1] = name
            total = total + weight
        end
    end
    table.sort(names)
    local roll = math.random() * total
    for _, name in ipairs(names) do
        roll = roll - options[name]
        if roll <= 0 then return name end
    end
    return names[#names] or from
end

--- Sets the weather. hold = true keeps it until auto is switched back on.
local function setWeather(w, hold, blend)
    w = tostring(w or ''):lower()
    if not isType(w) then return false end
    state.weather = w
    state.hold = hold == true
    scheduleNext()
    publishWeather(tonumber(blend))
    save()
    log('weather %s%s', w, state.hold and ' (held)' or '')
    return true
end

local function setAuto()
    state.hold = false
    scheduleNext()
    save()
    log('weather changes by itself again')
end

local function setTime(h, m, freeze)
    h, m = tonumber(h), tonumber(m) or 0
    if not h or h % 1 ~= 0 or m % 1 ~= 0 or h < 0 or h > 23 or m < 0 or m > 59 then return false end
    state.second = h * 3600 + m * 60
    if freeze ~= nil then state.frozen = freeze == true end
    -- real-time mode follows the real clock; a set time stops it there
    if Config.Time.Mode == 'real' then state.frozen = true end
    publishClock()
    save()
    log('time %02d:%02d%s', h, m, state.frozen and ' (stopped)' or '')
    return true
end

local function setFrozen(frozen)
    state.frozen = frozen == true
    if not state.frozen and Config.Time.Mode == 'real' then state.second = realSecond() end
    publishClock()
    save()
    log('clock %s', state.frozen and 'stopped' or 'running')
end

-- ---------------------------------------------------------------
-- start and the main loop
-- ---------------------------------------------------------------

CreateThread(function()
    math.randomseed(os.time())

    if Config.Time.Remember then
        local saved = GetResourceKvpString('weather')
        if saved and isType(saved) then
            state.second = GetResourceKvpInt('second') % DAY
            state.frozen = GetResourceKvpInt('frozen') == 1
            state.weather = saved
            state.hold = GetResourceKvpInt('hold') == 1
        end
    end
    if Config.Time.Mode == 'real' and not state.frozen then state.second = realSecond() end

    scheduleNext()
    publishClock()
    publishWeather(0.0)
    log('started: %02d:%02d, %s', math.floor(state.second / 3600), math.floor(state.second % 3600 / 60), state.weather)

    local last = GetGameTimer()
    local sinceSync, sinceSave = 0, 0
    while true do
        Wait(1000)
        local now = GetGameTimer()
        local dt = (now - last) / 1000.0
        last = now

        if not state.frozen then
            if Config.Time.Mode == 'real' then
                state.second = realSecond()
            else
                state.second = (state.second + dt * 60.0 / rate(state.second)) % DAY
            end
        end

        -- the season began or ended: change over now instead of waiting for the next change
        local season = activeSeason()
        local inSeason = season ~= nil
        if state.wasSeason == nil then state.wasSeason = inSeason end
        if inSeason ~= state.wasSeason then
            state.wasSeason = inSeason
            state.nextChange = now
            log(inSeason and 'season starts' or 'season is over: normal weather again')
        end
        if season and not state.hold and not season.Pattern[state.weather] then state.nextChange = now end

        if Config.Weather.Auto and not state.hold and now >= state.nextChange then
            state.weather = pickNext(state.weather)
            scheduleNext()
            publishWeather()
            log('weather changes to %s', state.weather)
        end

        -- resend the exact time now and then, and at once when the speed changes (night starts or ends)
        sinceSync = sinceSync + dt
        local shared = GlobalState.multiClock
        if sinceSync >= Config.SyncSeconds or (shared and shared.r ~= rate(state.second)) then
            sinceSync = 0
            publishClock()
        end

        sinceSave = sinceSave + dt
        if sinceSave >= 60 then
            sinceSave = 0
            save()
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then save() end
end)

-- ---------------------------------------------------------------
-- MULTIadmin's weather and time buttons
-- MULTIadmin writes GlobalState.multiadminWorld; while MULTIweather runs,
-- this script carries it out (MULTIadmin's own client side stands back).
-- ---------------------------------------------------------------

local function timeKey(w)
    return w.hour and ('%d:%d:%s'):format(w.hour, w.minute or 0, tostring(w.freeze)) or nil
end

local lastAdmin = type(GlobalState.multiadminWorld) == 'table' and GlobalState.multiadminWorld or {}

AddStateBagChangeHandler('multiadminWorld', 'global', function(_, _, world)
    world = type(world) == 'table' and world or {}
    if world.weather ~= lastAdmin.weather then
        if world.weather then setWeather(world.weather, true) else setAuto() end
    end
    if timeKey(world) ~= timeKey(lastAdmin) then
        if world.hour then setTime(world.hour, world.minute, world.freeze == true) else setFrozen(false) end
    end
    lastAdmin = { weather = world.weather, hour = world.hour, minute = world.minute, freeze = world.freeze }
end)

-- ---------------------------------------------------------------
-- commands (restricted: ace command.<name>)
-- ---------------------------------------------------------------

local function reply(src, text, kind)
    if src > 0 then
        TriggerClientEvent('MULTIcore:notify', src, { text = text, type = kind or 'info' })
    else
        print('[MULTIweather] ' .. text)
    end
end

local C = Config.Commands

if C.Weather then
    RegisterCommand(C.Weather, function(src, args)
        local w = tostring(args[1] or ''):lower()
        if w == 'auto' then
            setAuto()
            reply(src, _L('weather_auto'), 'success')
        elseif setWeather(w, true) then
            reply(src, _L('weather_set', w), 'success')
        else
            reply(src, _L('weather_usage', table.concat(Config.Weather.Types, ', ')), 'error')
        end
    end, true)
end

if C.Time then
    RegisterCommand(C.Time, function(src, args)
        if setTime(args[1], args[2]) then
            reply(src, _L('time_set', math.floor(tonumber(args[1])), math.floor(tonumber(args[2]) or 0)), 'success')
        else
            reply(src, _L('time_usage'), 'error')
        end
    end, true)
end

if C.FreezeTime then
    RegisterCommand(C.FreezeTime, function(src)
        setFrozen(not state.frozen)
        reply(src, _L(state.frozen and 'time_frozen' or 'time_running'), 'success')
    end, true)
end

-- ---------------------------------------------------------------
-- exports
-- ---------------------------------------------------------------

exports('GetWeather', function() return state.weather end)
exports('GetTime', function()
    local s = math.floor(state.second)
    return { hour = s // 3600, minute = (s % 3600) // 60, second = s % 60, frozen = state.frozen }
end)
exports('SetWeather', function(w, hold, blendSeconds) return setWeather(w, hold ~= false, blendSeconds) end)
exports('SetWeatherAuto', setAuto)
exports('SetTime', function(h, m, freeze) return setTime(h, m, freeze) end)
exports('FreezeTime', function(frozen) setFrozen(frozen ~= false) end)
