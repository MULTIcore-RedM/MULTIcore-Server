# MULTIdoors

Door locks for MULTIcore servers. Every door the game registers (1,707 doors, from femga's door hash list) is known by hash, model and area. The owner decides which doors are locked and who holds the key. Answers as RSG v2 `rsg-doorlock`.

GPL v3, like MULTIcore. See `CREDITS.md`.

## What it does

- **Every door known.** `data/doors.lua` lists each door hash with its model hash, model name, position and town (from `config/towns.lua`). A door is only touched when a lock rule names it.
- **Lock rules** in `config/locks.lua`, one line per door (or double door): who may lock / unlock it by **job** (with lowest grade), **gang** (lowest grade), **citizen id** or **key item**; locked after a restart or not; **lockpickable**; **auto-lock** after N seconds; reach in metres.
- **Default rules:** every law office and jail cell (Valentine, Rhodes, Blackwater, Strawberry, Saint Denis, Sisika from rsg-doorlock's list; the cells of Annesburg, Armadillo, Tumbleweed and Van Horn for marshals), the five banks (front doors open, counters, staff doors and vaults locked, `banker` job) and the Valentine and Saint Denis doctors (open; medics lock up). Each law office has a key item (`key_valentine_jail` ...), each bank and doctor too.
- **State on the server only**, sent to everyone through GlobalState (`multidoors:<rule id>` = true when locked). Clients set the managed doors near them and reset them when the script stops.
- **Using a door:** MULTItarget on the door (Left Alt: "Lock / unlock", "Pick the lock") when MULTItarget runs, else a hold-key prompt at the door (`Config.PromptKey`, default ENTER, like rsg-doorlock); `Config.Interact`, `'auto'` by default. `/mcinteract` (MULTIcore) prints the door targets / prompts to the server console. The player turns to the door and plays the key animation; the server checks the rule, the distance (OneSync) and a cooldown.
- **Lockpicking** (doors with `lockpickable = true`): needs the `lockpick` item and a minigame (MULTIrobberies' pin lock - move the pick with the mouse and set each pin - when that script runs, else an ox_lib skill check; `Config.Lockpick.Minigame`), the lockpick may break on a failure; the server refuses a "success" that came too fast. The law (job type `leo`, on duty) gets a notification and a map blip.
- **Key items** named by any rule are added to the item list at start through MULTIinventory (`RegisterItem`) if they do not exist yet. Admins hand them out with the inventory's give command.
- **Admin tool `/doors`:** aim at a door to see its hash, model and area; list the doors near you; make or edit a lock rule in game (saved in the `multicore_doors` table and winning over a config rule with the same id); switch a config rule off or back on; lock / unlock any door; teleport to a door; copy hashes and coordinates.

## Setup

1. Put `MULTIdoors` in `resources/[multicore]/`.
2. `server.cfg`, after MULTIcore and MULTIinventory:
   ```
   ensure MULTIdoors
   add_ace group.admin multidoors.admin allow
   ```
3. Remove `rsg-doorlock` from the server (`provide 'rsg-doorlock'`).
4. Needs `oxmysql`, `ox_lib`, `MULTIcore`; MULTIinventory for key items and lockpicks; `MULTItarget` recommended (used automatically when it runs). The table is created on first start (`sql/multidoors.sql` is the same statement).
5. MULTIbank sets its bank doors once at start (`Config.Doors` in MULTIbank). MULTIdoors keeps the same defaults, so they agree; set MULTIbank's `Config.Doors.Enabled = false` if you change the bank rules here.

## Lock rules (`config/locks.lua`)

```lua
{ id = 'val_sheriff_front', label = 'Valentine sheriff - front door', door = 1988748538, locked = true,
  jobs = { vallaw = 0, marshal = 0 }, gangs = nil, citizenids = nil, items = { 'key_valentine_jail' },
  lockpickable = true, autoLock = nil, distance = 2.5 },
{ id = 'blk_sheriff_front', door = { 3410720590, 3821185084 }, ... }, -- double door
```

- `id` is how the door is saved and synced: never rename it once in use.
- A rule with no jobs, gangs, citizen ids or items is for admins only.
- `jobs = { 'vallaw' }` (a plain list) means grade 0.
- `coords = vector3(...)` only for a door not in `data/doors.lua`.
- `rsg = n` ties the rule to number n of rsg-doorlock's door list (see below).
- `Config.RequireOnDuty = true` makes jobs count only on duty.

Find hashes in game with `/doors` (aim, or "doors near me"), or search `data/doors.lua` by town or model name.

Moving from rsg-doorlock: paste its `Config.DoorList` into `config/rsg_doorlist.lua`. Entry k becomes rule `rsg_k`; its `objCoords` are matched to the door list, `authorizedJobs` become jobs.

## Config (`config.lua`)

| Option | Default | What |
|---|---|---|
| `Locale` | `''` | language; empty = `setr multicore_locale`, else English |
| `LockedState` | `1` | door state written for locked (rsg-doorlock writes 3) |
| `ApplyDistance` / `ApplyIntervalMs` | 60 / 1000 | clients set managed doors this close, this often |
| `DefaultDistance` | 2.0 | reach when a rule gives none |
| `ServerDistanceCheck` / `ServerDistanceSlack` | true / 2.5 | server distance check (OneSync) |
| `CooldownMs` | 1200 | between two lock changes by one player |
| `RequireOnDuty` | false | jobs count only on duty |
| `AdminsUseAll` | true | admins open every managed door |
| `Interact` | `'auto'` | `'auto'` (MULTItarget when it runs, else prompts), `'target'` or `'prompt'`; both use the rule's `distance` (`DefaultDistance` 2.0) |
| `PromptKey` / `PromptHoldMs` | `'ENTER'` / 700 | lock key and hold time |
| `Anim` | rsg-doorlock's key animation | on / off, timing, key prop |
| `Keys` | register on | key item weight and image |
| `Lockpick` | on, item `lockpick` | break chance, skill check, cooldown, key `G` |
| `Alert` | on, job type `leo` on duty | lockpick alert, blip |
| `Admin` | `/doors`, ACE `multidoors.admin`, RSG `admin` | tool settings |
| `Towns` (`config/towns.lua`) | 27 places | town centres for area names |

Texts are in `locales/*.lua` (en, de, fr, es, pt-br, it, pl, ru, nl, tr).

## Commands

- `/doors` (admin): the door tool.

## Exports (server)

| Export | Returns |
|---|---|
| `IsReady()` | true once rules are loaded |
| `GetRules()` | list of rules (id, label, doors, area, coords, distance, lockpickable) |
| `GetRule(id)` | the rule in its editable form, or nil |
| `IsLocked(id)` | true / false / nil |
| `SetLocked(id, locked)` | sets the state for everyone (no permission check) |
| `SetDoorLocked(doorHash, locked)` | same, by any door hash of a rule |
| `RuleForDoor(doorHash)` | rule id or nil |
| `CanUse(src, id)` | true, how (`admin`, `job`, `gang`, `citizenid`, `item`) or false, error |
| `Use(src, id, wantLocked?)` | `{ ok, locked }` or `{ ok = false, err }`, with distance and cooldown checks |
| `SaveRule(rule)` / `DeleteRule(id)` / `ResetRule(id)` | rule made in game (database) |
| `GetDoorData(doorHash)` | `{ model, name, x, y, z, area }` from the door list |
| `Reload()` | re-reads the database and rebuilds the rules |

Server events: `MULTIdoors:server:changed (id, locked, by)`, `MULTIdoors:server:lockpickAlert (id, coords, src)`.

## RSG compatibility (rsg-doorlock 1.0.3)

rsg-doorlock has no exports; it is driven by events that name a door by its number in its `Config.DoorList`.

| Call | MULTIdoors |
|---|---|
| `TriggerServerEvent('rsg-doorlock:updatedoorsv', doorID, state)` | checks the key (job, gang, citizen, item) and distance; refused = "no key" notification; else sends `rsg-doorlock:changedoor` to that player |
| client `rsg-doorlock:changedoor (doorID, state)` | plays the key animation, then `rsg-doorlock:updateState` |
| `TriggerServerEvent('rsg-doorlock:updateState', doorID, state)` | checks again, sets the state |
| client `rsg-doorlock:setState (doorID, state)` | sent to everyone whenever a rule with that number changes |

The default law-office rules carry the numbers of rsg-doorlock's stock list (1 = Valentine sheriff front door ... 36 = Sisika east tower). Three Sisika entries of that list are not doors in the door list (rsg-doorlock gave a model hash) and are left out.

No VORP door-lock script is called by the scripts surveyed, so MULTIdoors provides no VORP name.
