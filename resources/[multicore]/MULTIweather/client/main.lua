-- ============================================================
-- MULTIweather :: client
-- Applies the server's one clock and one weather. Between syncs the
-- clock keeps running here at the speed the server sent.
-- GPL v3, part of MULTIcore by RINGO (RINGOscripting).
-- ============================================================

local N = {
    NETWORK_CLOCK_TIME_OVERRIDE = 0x669E223E64B1903C, -- _NETWORK_CLOCK_TIME_OVERRIDE (hour, minute, second, transitionMs, pauseClock)
    SET_WEATHER_TYPE_FROZEN = 0xD74ACDF7DB8114AF,     -- _SET_WEATHER_TYPE_FROZEN (toggle)
}

local ready = false
local clock = nil        -- { s, r, at = GetGameTimer() when received }
local appliedWeather = nil

local function applyWeather(data, instant)
    if not ready or type(data) ~= 'table' or not data.w then return end
    if data.w == appliedWeather then return end
    local blend = instant and 0.0 or (tonumber(data.t) or Config.Weather.TransitionSeconds) + 0.0
    -- SET_WEATHER_TYPE (hash, p1, p2, transition, transitionTime, p5)
    Citizen.InvokeNative(N.SET_WEATHER_TYPE_FROZEN, false)
    SetWeatherType(joaat(data.w), true, false, true, blend, false)
    -- frozen: the game must not drift to its own weather between server changes
    Citizen.InvokeNative(N.SET_WEATHER_TYPE_FROZEN, true)
    appliedWeather = data.w
end

local function takeClock(data)
    if type(data) ~= 'table' or not data.s then return end
    clock = { s = data.s, r = tonumber(data.r) or 0, at = GetGameTimer() }
end

AddStateBagChangeHandler('multiClock', 'global', function(_, _, value) takeClock(value) end)
AddStateBagChangeHandler('multiWeather', 'global', function(_, _, value) applyWeather(value, false) end)

CreateThread(function()
    Wait(Config.ApplyDelayMs)
    ready = true
    takeClock(GlobalState.multiClock)
    applyWeather(GlobalState.multiWeather, true)

    while true do
        if clock then
            local s = clock.s
            if clock.r > 0 then s = s + (GetGameTimer() - clock.at) / 1000.0 * 60.0 / clock.r end
            s = math.floor(s) % 86400
            Citizen.InvokeNative(N.NETWORK_CLOCK_TIME_OVERRIDE, s // 3600, (s % 3600) // 60, s % 60, 0, true)
        end
        Wait(1000)
    end
end)

-- the same weather again after a long load screen or a respawn far away
AddEventHandler('playerSpawned', function()
    if not ready then return end
    appliedWeather = nil
    applyWeather(GlobalState.multiWeather, true)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Citizen.InvokeNative(N.SET_WEATHER_TYPE_FROZEN, false)
    ClearOverrideWeather()
    NetworkClearClockTimeOverride()
end)

exports('GetWeather', function() return appliedWeather end)
