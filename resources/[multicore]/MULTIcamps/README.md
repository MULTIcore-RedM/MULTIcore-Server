# MULTIcamps

Basic player camps for MULTIcore. A character carries a **tent** (the camp kit), pitches it out in
the wild and gets a small camp: tent, bedroll, campfire, a storage chest and (optional) a hitching
post. Deliberately simple: no building, upgrades or furniture. Part of MULTIcore, GPL v3 (see `CREDITS.md`).

## Setup
1. `server.cfg`, after MULTIinventory (and after MULTIcrafting if you run it):
   ```
   ensure MULTIcamps
   ```
2. Tables are made on start (`CREATE TABLE IF NOT EXISTS`): `multicamps` (one row per camp) and
   `multicamps_notices` (messages for owners whose camp decayed while they were away).
3. The kit item `tent` is added to the item registry if no script has it yet. Sell it in a general
   store (suggested price $5.50).

## Playing
- **Pitch:** use the tent from the satchel. A see-through camp appears in front of you. Arrow
  left / right turns it, arrow up / down pushes it further or pulls it closer, it follows the ground.
  Hold left mouse to pitch, right mouse to cancel. The prompt title tells you why a spot is not
  allowed (town, road, other camp, steep ground, water). Pitching takes a few seconds; the tent is
  taken from the satchel.
- **Rules (checked on the server):** one camp per character (`Config.MaxCampsPerCharacter`), not
  inside a town zone (`config/towns.lua`), at least `Config.MinCampDistance` from any other camp,
  within `Config.PlaceDistance` of the player. Roads (`Config.MinRoadDistance`), slope and water are
  checked by the game while previewing.
- **Camp menu:** "Camp" through MULTItarget (Left Alt) on the tent, bedroll, fire or chest when MULTItarget runs, else hold J (`Config.PromptKey`) there (`Config.Interact = 'auto'`). `/mcinteract` (MULTIcore) prints the camp targets and prompts to the server console.
  - Open chest: the MULTIinventory custom inventory `custom:camp:<citizenid>` (20 slots, 60 kg).
  - Rest in the tent: lie down; adds 25 to the health and stamina cores, once per 20 minutes.
    An optional clock skip (`Config.Sleep.TimeSkipHours`) is off by default; it only moves the
    sleeper's own clock, and a time sync script sets it back.
  - Light / put out the fire. A lit fire is a `p_campfire01x`, which MULTIcrafting treats as a
    **campfire crafting station** by itself (its own prompt shows at the fire, with
    `Config.AllowWorldProps = true` there). With MULTIcrafting started, the menu also offers
    "Cook at the fire" (`exports.MULTIcrafting:OpenMenu`).
  - Owner only: share the chest with my gang (on / off), pack up camp.
- **Pack up:** the tent goes back to the satchel. Anything in the chest moves to the satchel too
  if all of it fits (`Config.Storage.PackMovesToSatchel`); otherwise nothing moves and the camp stays.
  Set `PackMovesToSatchel = false` to require an empty chest.
- **Gang sharing** (`Config.GangSharing`): the owner lets members of his MULTIcore gang open the
  chest, rest and tend the fire. The share follows the owner's gang: if he changes gang, the new
  gang gets access, the old one loses it.
- **Decay** (`Config.Decay`): a camp whose owner has not been within 50 m of it for 7 days is taken
  down with its chest contents. The owner is told at once if online, otherwise at the next login.
  Using the chest or resting there also counts as a visit.

## How it works
- The server holds every camp (table `multicamps`). Each client asks for the list once and gets
  changes as they happen; it makes the props as local objects when within `Config.StreamDistance`
  and removes them beyond it.
- Every action is a `lib.callback` that the server checks: rate limit, ownership or gang, and the
  player's distance to the camp part (OneSync).
- A camp chest can only be opened through MULTIcamps. If a client asks MULTIinventory for
  `custom:camp:...` directly, MULTIcamps closes it again at once.

## Config
All in `config.lua` (one comment per line): the kit item, limits and distances, preview keys,
prop models and their offsets, hitching post on / off, stream distance, interaction mode (`Interact`, `TargetIcon`, `TargetDistance`), prompt key, fire, rest,
chest size, gang sharing, decay, items added to the registry, rate limit. No-camp zones are in
`config/towns.lua`.

## Exports (server)
| Export | Returns |
|---|---|
| `IsReady()` | bool |
| `GetCamp(id)` | `{ id, citizenid, ownerName, x, y, z, heading, lit, shared, gang, created, lastVisit, storage }` or nil |
| `GetCamps(src or citizenid or nil)` | list of camps (all camps when nil) |
| `GetCampAt(coords, dist?)` | nearest camp or nil |
| `GetStorageId(src or citizenid)` | `'custom:camp:<citizenid>'` |
| `CanPlace(src, coords)` | `true` or `false, err, arg` (`limit`, `in_town` + place name, `near_camp`, `bad_coords`) |
| `Place(src, coords, heading)` | `true, id` or `false, err` (takes one kit; no distance check) |
| `PackUp(src, id)` | `true, stacksMoved` or `false, err` (`not_owner`, `no_room`, `not_empty`) |
| `RemoveCamp(id, reason?)` | bool (nothing given back) |
| `SetFire(src, id, lit)`, `SetShared(src, id, on)` | `true` or `false, err` |
| `CanUseStorage(src, id)`, `OpenStorage(src, id)` | `true` or `false, err` |
| `Sweep()` | number of decayed camps removed |

Server events: `MULTIcamps:placed (src, id)`, `MULTIcamps:removed (id, citizenid, reason)` with
reason `packed`, `decayed`, `character_deleted` or what `RemoveCamp` was given.

## Compatibility
Neither RSG v2 nor the scripts surveyed call a camp resource by name, so MULTIcamps answers to no
other resource name.
