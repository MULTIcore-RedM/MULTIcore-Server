# MULTIweather

MULTIcore's weather and time. Every player sees the same time of day and the same sky, the clock keeps running, and the weather changes by itself in believable steps (sun, clouds, overcast, drizzle, rain, storm and back).

## Install

```
ensure MULTIcore
ensure MULTIadmin      # optional: its weather and time buttons then drive MULTIweather
ensure MULTIweather
```

Do **not** run another weather or time script (weathersync and the like) as well.

## What it does

- **One clock** for the whole server. By default an in-game day lasts 48 real minutes, the game's own speed, with shorter nights (`Config.Time`). Or set `Config.Time.Mode = 'real'` to follow the real clock.
- **Weather that changes by itself** every 20 to 40 real minutes. What can follow what is in `Config.Weather.Pattern`, with a weight for each, so a storm never jumps straight to blue sky. Snow, blizzards and sandstorms are not picked by themselves, because they would cover the whole map.
- **Remembers** the time and weather across restarts (`Config.Time.Remember`).
- Late joiners get the same sky as everyone else.

## Admin

| Command | What it does |
|---|---|
| `/weather [type]` | Sets that weather and holds it |
| `/weather auto` | Lets the weather change by itself again |
| `/time [hour] [minute]` | Sets the time; the clock keeps running |
| `/freezetime` | Stops or restarts the clock |

The commands use the `command.<name>` ace. `group.admin` already has `command` in `server.cfg`.

The **MULTIadmin** menu's World buttons do the same. "Reset weather" goes back to weather that changes by itself, and "Reset time" restarts the clock.

## Config

| Option | Default | What it does |
|---|---|---|
| `Config.Time.Mode` | `'game'` | `'game'` = an in-game day; `'real'` = the real clock |
| `Config.Time.MinuteSeconds` | `2.0` | Real seconds per game minute in the day |
| `Config.Time.NightMinuteSeconds` | `1.0` | The same at night (shorter nights) |
| `Config.Time.NightStart` / `NightEnd` | `22` / `5` | When night speed applies |
| `Config.Time.RealOffsetHours` | `0` | `'real'` mode: hours added to UTC |
| `Config.Time.StartHour` | `8` | Hour on the very first start |
| `Config.Time.Remember` | `true` | Keep time and weather across restarts |
| `Config.Weather.Auto` | `true` | Weather changes by itself |
| `Config.Weather.Start` | `'sunny'` | Weather on the very first start |
| `Config.Weather.ChangeMinutes` | `{ 20, 40 }` | Real minutes between changes |
| `Config.Weather.TransitionSeconds` | `45.0` | How long the sky takes to blend |
| `Config.Weather.Pattern` | see file | What may follow each weather, with weights |
| `Config.Weather.Types` | see file | Every weather an admin may set |
| `Config.SyncSeconds` | `30` | How often the exact time is resent |
| `Config.Commands` | see file | Command names; `false` turns one off |

Text: `locales/` (10 languages).

## Exports (server)

```lua
exports.MULTIweather:GetWeather()                -- 'rain'
exports.MULTIweather:GetTime()                   -- { hour = 14, minute = 30, second = 0, frozen = false }
exports.MULTIweather:SetWeather('fog', true)     -- true = hold it; optional third value: blend seconds
exports.MULTIweather:SetWeatherAuto()
exports.MULTIweather:SetTime(21, 0, false)       -- hour, minute, stop the clock
exports.MULTIweather:FreezeTime(true)
```

Client: `exports.MULTIweather:GetWeather()`.

Scripts can also read `GlobalState.multiWeather` (`{ w = type }`) and `GlobalState.multiClock` (`{ s = second of the day, r = real seconds per game minute, 0 = stopped }`).

## Licence

GPL-3.0-or-later, part of MULTIcore by RINGO (RINGOscripting).
