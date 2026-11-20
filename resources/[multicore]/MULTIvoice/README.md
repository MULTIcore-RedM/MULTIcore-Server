# MULTIvoice

MULTIcore's proximity voice. Players are heard only by those near them, in 3D, with three ranges: whisper, talk and shout. It also has radio and call channels for other scripts to use.

It answers the calls scripts make to **pma-voice** (`exports['pma-voice']:...`, the `proximity` and `radioActive` state bags), so scripts written for pma-voice work without edits.

## Install

```
setr voice_use3dAudio true
setr voice_useSendingRangeOnly true

ensure MULTIcore
ensure MULTIvoice
```

Both `setr` lines are already in `server.cfg.example`. Do **not** run pma-voice or another voice script as well. MULTIvoice `provide`s the name `pma-voice`, so scripts that depend on it still start.

## Using it

| | |
|---|---|
| **N** (hold) | Talk. This is the game's own push-to-talk key; players can change it or turn on voice activation in the game's settings |
| **U** | Next range: Whisper (2 m) → Talk (6 m) → Shout (15 m) |
| `/voice` | The same; `/voice 1`, `/voice 2` or `/voice 3` picks one |
| **F6** → Settings → Voice range | The same, from the radial menu |
| **[** (hold) | Talk on the radio, only while a script has put you on a radio channel |

The HUD's voice gauge shows the range, lights up while you talk and shows "Radio" while you use the radio.

Players in another routing bucket (character select, instances) never hear each other.

## Config

| Option | Default | What it does |
|---|---|---|
| `Config.Ranges` | 2 / 6 / 15 m | The ranges, in order (add or remove as you like) |
| `Config.DefaultRange` | `2` | Range a player starts in |
| `Config.CycleKey` | `0xD8F73058` (U) | Key for the next range; `false` = command only |
| `Config.Command` | `'voice'` | Command for the next range (`''` = none) |
| `Config.Notify` | `true` | Show the new range in a notification |
| `Config.UpdateMs` | `250` | How often the list of players in range is rebuilt |
| `Config.Radio.Enabled` / `Key` / `Volume` | `true` / `[` / `0.6` | Radio channels |
| `Config.Call.Enabled` / `Volume` | `true` / `0.6` | Call channels |

Text: `locales/` (10 languages).

## Exports

Client (also on `exports['pma-voice']`):

```lua
exports.MULTIvoice:setRadioChannel(3)          -- 0 = off the radio
exports.MULTIvoice:setCallChannel(12)          -- 0 = hang up
exports.MULTIvoice:setRadioVolume(60)          -- 0-100
exports.MULTIvoice:setCallVolume(60)
exports.MULTIvoice:setVoiceProperty('radioEnabled', false)
exports.MULTIvoice:overrideProximityRange(30.0, true)   -- e.g. a megaphone; true = range key blocked
exports.MULTIvoice:clearProximityOverride()
exports.MULTIvoice:getRange()                  -- metres
```

Also `addPlayerToRadio`, `removePlayerFromRadio`, `addPlayerToCall`, `removePlayerFromCall`, `getRangeIndex`, `setRange`.

Server (also on `exports['pma-voice']`):

```lua
exports.MULTIvoice:setPlayerRadio(src, 3)
exports.MULTIvoice:setPlayerCall(src, 12)
exports.MULTIvoice:getPlayersInRadioChannel(3)   -- { [src] = talking }
exports.MULTIvoice:addChannelCheck(3, function(src) return isLaw(src) end)
exports.MULTIvoice:removeChannelCheck(3)
```

State bags: `proximity` (`{ index, distance, mode }`), `radioActive`, `radioChannel`, `callChannel`.

## Licence

GPL-3.0-or-later, part of MULTIcore by RINGO (RINGOscripting).
