-- ============================================================
-- MULTIweather :: config
-- One clock and one sky for every player. Every option has a one-line comment.
-- Do not run another weather / time script (weathersync ...) next to this one.
-- ============================================================

Config = {}

-- Config.Locale = 'en'           -- language for this script only (else setr multicore_locale, else English)

-- ---------------------------------------------------------------
-- Time
-- ---------------------------------------------------------------
Config.Time = {
    Mode = 'game',                -- 'game' = an in-game day (see MinuteSeconds), 'real' = the real clock (see RealOffsetHours)
    MinuteSeconds = 2.0,          -- 'game' mode: real seconds per game minute (2.0 = a 48 minute day, the game's own speed)
    NightMinuteSeconds = 1.0,     -- 'game' mode: the same between NightStart and NightEnd (shorter nights); = MinuteSeconds for no change
    NightStart = 22,              -- hour the night speed starts
    NightEnd = 5,                 -- hour the night speed ends
    RealOffsetHours = 0,          -- 'real' mode: hours added to UTC (e.g. -5 for New York in winter, 1 for Berlin in winter)
    StartHour = 8,                -- hour on the very first start (later starts carry on from the saved time)
    Remember = true,              -- keep the time and weather across server restarts
}

-- ---------------------------------------------------------------
-- Weather
-- ---------------------------------------------------------------
Config.Weather = {
    Auto = true,                  -- the weather changes by itself
    Start = 'sunny',              -- weather on the very first start
    ChangeMinutes = { 20, 40 },   -- real minutes between changes (a random time between the two)
    TransitionSeconds = 45.0,     -- how long the sky takes to blend into new weather

    -- What may follow each weather, with a chance weight (bigger = more likely).
    -- Only weather listed here is picked by itself. Admins can still set any type from Config.Types.
    -- Snow, blizzard and sandstorm are left out: they cover the whole map, deserts and swamps too.
    Pattern = {
        sunny        = { sunny = 4, highpressure = 3, clouds = 3 },
        highpressure = { sunny = 4, highpressure = 2, clouds = 2 },
        clouds       = { sunny = 3, clouds = 2, overcast = 3, misty = 1 },
        overcast     = { clouds = 3, overcast = 1, overcastdark = 2, drizzle = 2, fog = 1 },
        overcastdark = { overcast = 2, drizzle = 2, rain = 2, thunder = 1 },
        misty        = { clouds = 3, sunny = 2, fog = 1 },
        fog          = { misty = 3, overcast = 2, clouds = 1 },
        drizzle      = { overcast = 3, shower = 2, rain = 1, clouds = 1 },
        shower       = { clouds = 3, overcast = 2, drizzle = 1 },
        rain         = { drizzle = 3, overcast = 2, thunder = 1, thunderstorm = 1 },
        thunder      = { rain = 3, overcastdark = 2 },
        thunderstorm = { rain = 3, overcastdark = 2 },
    },

    -- Every weather an admin may set (RDR2 weather type names).
    Types = {
        'sunny', 'clouds', 'overcast', 'overcastdark', 'highpressure', 'misty', 'fog',
        'drizzle', 'shower', 'rain', 'thunder', 'thunderstorm', 'hurricane',
        'hail', 'sleet', 'snowlight', 'snow', 'blizzard', 'groundblizzard', 'whiteout', 'sandstorm',
    },
}

-- ---------------------------------------------------------------
-- Sync and commands
-- ---------------------------------------------------------------
Config.SyncSeconds = 30           -- how often the server sends the exact time to everyone (players keep the clock running in between)
Config.ApplyDelayMs = 2000        -- wait after joining before the sky is set (the world must load first)

-- Admin commands (ace command.<name>; group.admin has "command" in server.cfg). Set one to false to turn it off.
Config.Commands = {
    Weather = 'weather',          -- /weather [type]  holds that weather;  /weather auto  lets it change by itself again
    Time = 'time',                -- /time [hour] [minute]
    FreezeTime = 'freezetime',    -- /freezetime  stops or restarts the clock
}

Config.LogToConsole = true        -- print weather changes to the server console
