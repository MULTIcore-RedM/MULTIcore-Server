# MULTIadmin

Admin menu for MULTIcore servers. One NUI menu with three tabs:

- **Players**: every online player with server id, name, character name, citizen id, character id, job and grade, cash / bank / gold / rol, account group and warnings. Actions: go to, bring, freeze / unfreeze, spectate, heal, revive, kill, kick (reason), ban (length + reason), warn (reason), give / take money, set job + grade, set account group, send back to character select, send a notification.
- **Self**: noclip (smooth, speed steps on the mouse wheel), godmode, invisible, teleport to waypoint, position with copy as `vector3` / `vector4` / table, heal / revive yourself, spawn a horse or wagon by model name, server-wide weather and time.
- **Server**: announcement to everyone, notification to one player or everyone, list of active bans with unban.

Every action is checked on the server (the client is never trusted) and logged to the server console, and to Discord when a webhook is set.

Licence: GPL v3 (see LICENSE). Part of MULTIcore.

## Requirements

`oxmysql`, `ox_lib`, `MULTIcore`. Start order: after MULTIcore and the other MULTI base resources:

```
ensure oxmysql
ensure ox_lib
ensure MULTIcore
...
ensure MULTIadmin
```

The ban table `multicore_bans` is created on start (also in `sql/multiadmin.sql`).

## Permissions (server.cfg)

MULTIadmin has two levels: **mod** and **admin** (admins can do everything mods can). A player is admin when any of `Config.Permissions.Admin` passes, mod when any of `Config.Permissions.Mod` passes:

- rsg-core permission levels (`RSGCore.Functions.HasPermission`) - by default `god` / `admin` for admin and `mod` for mod;
- plain ACE names - by default `multiadmin.admin` and `multiadmin.mod`.

MULTIcore puts players whose VORP account group is `admin` / `superadmin` in `group.admin` and `mod` in `group.mod` (see MULTIcore `config_multi.lua`). Give those principals the permissions:

```
# rsg-core permission levels
add_ace group.admin admin allow
add_ace group.mod mod allow
add_principal group.admin group.mod

# MULTIadmin's own ACE names (either set works)
add_ace group.admin multiadmin.admin allow
add_ace group.mod multiadmin.mod allow

# yourself (owner): rsg-core 'god' level (may give the superadmin group)
add_principal identifier.license:YOUR_LICENSE group.admin
add_ace identifier.license:YOUR_LICENSE god allow

# console/ACE unban command
add_ace group.admin command.multiadmin_unban allow

# optional Discord log (never put the URL in config.lua)
set multiadmin_webhook "https://discord.com/api/webhooks/..."
```

Which level each action needs is in `Config.ActionLevel`. With `Config.ProtectHigherRank` a mod can't act on an admin.

## Commands

| Command | Who | What |
|---|---|---|
| `/admin` (`Config.Command`) | staff | open / close the menu |
| `/adminnoclip` (`Config.NoclipCommand`) | staff with noclip | toggle noclip without the menu |
| `multiadmin_unban <id>` | console / ACE | remove a ban |

Both client commands are also in the game's key settings (`RegisterKeyMapping`); they ship **unbound** (`Config.OpenKey = ''`, `Config.NoclipKey = ''`). PageDown is never bound.

Noclip keys: W A S D move, Space up, Q down, mouse wheel speed step, Shift fast, Ctrl slow (all control hashes in `Config.Noclip.Controls`). Spectate: Backspace stops (`Config.Spectate.StopControl`).

## Config

Everything is in `config.lua`, one comment per option: permissions, action levels, webhook convar, notification durations and the types/styles the notify form offers, money types and limit, assignable groups, warning kick limit, ban lengths, noclip speeds and keys, teleport and spectate timings, spawn presets, weather list and transition, menu timings. `Config.WorldSync = false` hands weather and time to another script (weathersync etc.).

## Languages

Text is in `locales/`: `en` (master), `de`, `fr`, `es`, `pt-br`, `it`, `pl`, `ru`, `nl`, `tr`, all with the same keys. The language follows `setr multicore_locale xx` for all MULTI scripts, or `Config.Locale` for this one. Russian switches the menu to the theme's Cyrillic fonts.

## Look

The menu uses MULTIcore's shared theme (`nui://MULTIcore/html/theme/multi.css`). Put your own CSS in `html/custom.css` (loaded last).

## Notifications

All messages go through `exports.MULTIcore:Notify` / `NotifyAll`, so they look like every other MULTI, RSG and VORP notification on the server.

## How actions reach the core

- Heal / revive: `exports.vorp_core:GetCore().Player.Heal / Revive` (MULTIcore's VORP face; its client does the work). `Config.LocalHealthFallback = true` adds MULTIadmin's own heal / revive for core builds without that client part.
- Warnings and account group: the VORP user object (`getPlayerwarnings` / `setPlayerWarnings`, `setGroup`).
- Money and job: rsg-core player functions (`AddMoney`, `RemoveMoney`, `SetJob`).
- Character menu: `exports.MULTIcore:LogoutCharacter(src)`.
- Weather / time: `GlobalState.multiadminWorld`, applied by every client (late joiners too).

## Exports / events

None for other scripts. Internal: server callbacks `MULTIadmin:open`, `MULTIadmin:players`, `MULTIadmin:action`; client events `MULTIadmin:client:*` (sent by the server only).
