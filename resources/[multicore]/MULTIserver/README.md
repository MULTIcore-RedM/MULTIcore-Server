# MULTIserver

Basic server tools for MULTIcore servers:

- **Discord logs.** Answers `rsg-log` (`provide 'rsg-log'`). Every `rsg-log:server:CreateLog` call from MULTIcore, the MULTI scripts and RSG scripts goes to a Discord webhook chosen by log name, with a coloured embed. Posts are queued, one at a time; when Discord says "too many requests" (429) the post waits the time Discord asks for and is sent again. With no webhook set, the log is printed to the server console.
- **Whitelist** (off by default). Only players whose licence, licence2, Steam or Discord identifier is in the `multiserver_whitelist` table may join. Staff add and remove with commands.
- **Connect queue** (off by default). When every slot is taken, joining players wait on the connect screen with their place shown. Priority levels by ACE; a player who crashed and rejoins within a few minutes goes to the front.
- **Player list** (`/players`). Server id, name, character name, job and ping in the game's black menu look. Staff see citizen id and licence too.
- **Server info** (`/info`). Server name, a few lines of text, rules / Discord / website links with a copy button, players online.

Licence: GPL v3 (see LICENSE). Part of MULTIcore. Credits in CREDITS.md.

## Requirements

`oxmysql`, `ox_lib`, `MULTIcore`. Start it after MULTIcore and before any script that logs:

```
ensure oxmysql
ensure ox_lib
ensure MULTIcore
ensure MULTIserver
...
ensure MULTIadmin
```

The table `multiserver_whitelist` is created on start (also in `sql/multiserver.sql`).

Don't run a second answer to `rsg-log:server:CreateLog` (RSG v2's `rsg-essentials` has one in `server/logs.lua`), or every log is posted twice.

## Discord webhooks (server.cfg)

Webhook URLs are secrets. They go in **server.cfg as plain `set` convars** (never `setr`, which sends them to every player, and never in config.lua). MULTIserver never prints them.

```
# default: every log name without its own webhook goes here
set multiserver_webhook "https://discord.com/api/webhooks/..."

# one log name to its own channel:  multiserver_webhook_<name>
set multiserver_webhook_playermoney "https://discord.com/api/webhooks/..."
set multiserver_webhook_joinleave   "https://discord.com/api/webhooks/..."
set multiserver_webhook_anticheat   "https://discord.com/api/webhooks/..."
set multiserver_webhook_death       "https://discord.com/api/webhooks/..."

# optional: avatar picture for the posts
set multiserver_webhook_avatar "https://example.com/logo.png"
```

Routing for a log name: `multiserver_webhook_<name>` if set, else `multiserver_webhook` (when `Config.Logs.UseDefault`), else the server console (`Config.Logs.ConsoleFallback`). Names listed in `Config.Logs.Ignore` are dropped. Only `https://` values count.

Log names used by MULTIcore and the MULTI scripts: `playermoney`, `joinleave`, `anticheat`, `ooc`, `playerinventory`, `death`, plus MULTIserver's own `character`, `law` and `whitelist`. RSG scripts add their own (`bossmenu`, `gangmenu`, `adminmenu`, `bans`, `fishing` ...). Any name works.

Test a route in game or from the console: `multiserver_testlog <name>` (staff only). It answers with the convar the log went to (or `console`), never the URL.

### Logs MULTIserver writes itself

Only events the MULTI scripts really fire are used (`Config.Logs.Events`):

| Event | Log name | When |
|---|---|---|
| `MULTIcore:characterSelected (src, citizenid, isNew)` | `character` | a new character was made (`isNew`) |
| `MULTIlaw:server:jailed (src, minutes, place, officer)` | `law` | someone was jailed |
| `MULTIlaw:server:released (src, citizenid)` | `law` | someone was released |

Character deletions, money changes, joins / drops and anti-cheat are already logged by MULTIcore through `rsg-log` (`joinleave`, `playermoney`, `anticheat`). MULTIadmin logs its own actions to its own webhook (`set multiadmin_webhook`) and fires no event for other scripts; MULTIbank fires no transfer event (its money moves show up as `playermoney`).

### Logs sent from game clients

RSG's admin menu and medic send their logs from the client (`TriggerServerEvent`). Those are taken only for the names in `Config.Logs.Client.Names` (default `death`, `adminmenu`), at most `PerMinute` per player, cut to `MaxLength`, never with @everyone, and marked with the sender's name and id. Anything else from a client is dropped.

## Whitelist

`Config.Whitelist.Enabled = true` turns it on. On join, every identifier of the kinds in `Config.Whitelist.Identifiers` is checked against the table. Players with the ACE `multiserver.whitelist.bypass` always get in.

Bans stay with MULTIadmin: its own connect check refuses banned players. The whitelist does not look at bans and does not keep a ban list.

```
add_ace group.admin multiserver.whitelist allow          # may use the commands
add_ace group.admin multiserver.whitelist.bypass allow   # never stopped by the whitelist
```

| Command | What |
|---|---|
| `/wladd <server id or identifier> [note]` | add (a server id adds that player's licence) |
| `/wlremove <server id or identifier>` | remove |
| `/wlcheck <server id or identifier>` | is it listed? |

Identifiers look like `license:1a2b...`, `steam:1100001...`, `discord:1234...`. The commands also work from the server console. Staff from `Config.AdminAce` may use them too.

## Connect queue

`Config.Queue.Enabled = true` turns it on. Slots = `Config.Queue.MaxPlayers` (0 = `sv_maxclients`). While the server is full, joining players wait on the connect screen with "number X of Y" (plain text, or an adaptive card with `Config.Queue.Card = true`).

Order: higher priority first, then who came first. Priority comes from ACE:

```
add_ace group.vip multiserver.priority.1 allow
add_ace group.admin multiserver.priority.5 allow
```

A player who dropped within `GraceMinutes` (default 5) rejoins with `GracePriority` (ahead of everyone). A let-in player who hasn't arrived after `JoinTimeoutSec` frees the slot again.

Note: if FXServer itself already refuses players with "server full" before the queue can hold them, set `sv_maxclients` a few higher than `Config.Queue.MaxPlayers`.

## Player list and info

| Command | Key | What |
|---|---|---|
| `/players` (`Config.PlayerList.Command`) | unbound (`Config.PlayerList.Key = ''`) | open / close the list. R refreshes, Esc closes, typing searches |
| `/info` (`Config.Info.Command`) | unbound (`Config.Info.Key = ''`) | server info |

Both are in the game's key settings (`RegisterKeyMapping`); PageDown is never bound.

Players see: id, name, character name (`ShowCharacterName`), job (`ShowJob`), ping (`ShowPing`). Staff (`Config.AdminAce`: `multiserver.admin`, `multiadmin.admin`, `multiadmin.mod`; or rsg-core levels in `Config.AdminLevels`) always see character name and job, plus citizen id and licence. Hidden fields are never sent to players.

The info panel text comes from `Config.Info` (server name, description, rules / Discord / website links). Empty fields are hidden.

## Config

Everything is in `config.lua`, one comment per option: staff ACE / levels, log routing and queue timings, client log rules, colour names, MULTI events, whitelist kinds and commands, queue slots and priorities, player list columns, info texts.

## Languages

Text is in `locales/`: `en` (master), `de`, `fr`, `es`, `pt-br`, `it`, `pl`, `ru`, `nl`, `tr`, all with the same keys. Language follows `setr multicore_locale xx`, or `Config.Locale` for this script. Russian switches the page to the theme's Cyrillic fonts.

## Look

The page uses MULTIcore's shared theme (`nui://MULTIcore/html/theme/multi.css`). Put your own CSS in `html/custom.css` (loaded last).

## Compatibility

| Call | What MULTIserver does |
|---|---|
| `TriggerEvent('rsg-log:server:CreateLog', name, title, color, message, tagEveryone)` (server) | queued to the webhook for `name` (colour names as rsg-essentials, also numbers and `#rrggbb`); `tagEveryone` adds @everyone (`Config.Logs.AllowTagEveryone`) |
| `TriggerServerEvent('rsg-log:server:CreateLog', ...)` (client) | same, with the client checks above |
| `GetResourceState('rsg-log')` | `started` (`provide 'rsg-log'`) |

rsg-log has no exports that scripts call, so none are answered under its name.

## Exports (server)

| Export | Returns |
|---|---|
| `Log(name, title, color, message, tagEveryone)` | route used: convar name, `'console'`, `'ignored'` or `'off'` |
| `GetLogRoute(name)` | convar name the log goes to, or nil (never the URL) |
| `GetLogQueueLength()` | logs waiting to be sent |
| `WhitelistAdd(identifier, note, by)` | `true, identifier` or `false, 'bad_identifier' / 'exists'` |
| `WhitelistRemove(identifier)` | `true, identifier` or `false, 'bad_identifier' / 'missing'` |
| `IsWhitelisted(identifiers or serverId)` | bool |
| `GetQueueLength()` | players waiting in the queue |
| `GetPlayerList(viewerId)` | the list as that player would see it |
| `GetServerInfo()` | `{ name, desc, rules, discord, website, count, max }` |
| `IsReady()` | database table ready |

Server callbacks (ox_lib): `MULTIserver:players`, `MULTIserver:info`.
