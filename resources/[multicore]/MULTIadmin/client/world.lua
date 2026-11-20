-- ============================================================
-- MULTIadmin :: client - weather and time
-- The server keeps one world state in GlobalState.multiadminWorld
-- ({ weather, hour, minute, freeze }); every client applies it, late
-- joiners included. Off when Config.WorldSync is false.
-- ============================================================

if not Config.WorldSync then return end

local N = {
    NETWORK_CLOCK_TIME_OVERRIDE = 0x669E223E64B1903C, -- _NETWORK_CLOCK_TIME_OVERRIDE (h, m, s, transitionMs, pauseClock)
    SET_WEATHER_TYPE_FROZEN = 0xD74ACDF7DB8114AF,     -- _SET_WEATHER_TYPE_FROZEN (toggle)
}

local applied = {}

local function apply(world, instant)
    -- MULTIweather carries out the menu's weather and time when it runs
    if GetResourceState('MULTIweather') == 'started' then return end
    world = type(world) == 'table' and world or {}

    if world.weather ~= applied.weather then
        if world.weather then
            -- SET_WEATHER_TYPE (hash, p1, p2, transition, transitionTime, p5)
            SetWeatherType(joaat(world.weather), true, false, true, instant and 0.0 or Config.WeatherTransition + 0.0, false)
            Citizen.InvokeNative(N.SET_WEATHER_TYPE_FROZEN, true)
        elseif applied.weather then
            Citizen.InvokeNative(N.SET_WEATHER_TYPE_FROZEN, false)
            ClearOverrideWeather()
        end
        applied.weather = world.weather
    end

    local timeKey = world.hour and ('%d:%d:%s'):format(world.hour, world.minute or 0, tostring(world.freeze)) or nil
    if timeKey ~= applied.time then
        if world.hour then
            Citizen.InvokeNative(N.NETWORK_CLOCK_TIME_OVERRIDE, world.hour, world.minute or 0, 0, instant and 0 or Config.TimeTransitionMs, world.freeze == true)
        elseif applied.time then
            NetworkClearClockTimeOverride()
        end
        applied.time = timeKey
    end
end

AddStateBagChangeHandler('multiadminWorld', 'global', function(_, _, value)
    apply(value, false)
end)

CreateThread(function()
    Wait(Config.WorldApplyDelayMs)
    apply(GlobalState.multiadminWorld, true)
end)
