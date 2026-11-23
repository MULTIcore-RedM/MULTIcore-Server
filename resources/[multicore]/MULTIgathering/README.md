# MULTIgathering

Basic gathering for MULTIcore. GPL v3 (see `CREDITS.md`).

Five activities give MULTIinventory items the trade jobs can sell: **fishing**, **mining**, **gold panning**,
**lumber** and **herb picking**. Deliberately simple: no skills, no XP, no tool wear screen, no claims, no sawmill
or smelter. Premium gathering scripts do those.

## Setup
1. Put `MULTIgathering` in `resources/[multicore]`.
2. `server.cfg`, after MULTIinventory and MULTIstores: `ensure MULTIgathering`.
3. Stores: add the gathered goods to MULTIstores' buy lists (see "Selling" below).
4. Check the mine coordinates in game (see "Mining") and fix them with `/gatherspot`.

If a script listed in `Config.StandDownFor` for an activity is started (for example `rsg-fishing`,
`rsg-lumberjack`, `rsg-herbalist`), MULTIgathering gives nothing for **that activity only**, shows no prompts for it
and says so in the server console. Nobody is paid twice.

## How it works
Every reward is decided on the server. The client never names an item or an amount.

- **Fishing** (the game's own rod fishing). Hold the fishing rod, then use a bait from the satchel: one bait is used
  per cast. Cast, wait for a bite, hook, reel in, then keep or throw back. When the player keeps a fish, the server
  checks a bait was really used (one fish per bait, `CastWindowSeconds`), the rod is carried, the fish is a known
  model, the bait can catch it (`Config.BaitFish`) and the cooldown. The fish item matches species and size
  (`a_c_fishperch_01_sm` ...) and carries `info.weight` in kg, kept inside the species' range. A fish the game puts in
  the player's hands is removed (it is an item now).
- **Mining.** At a rock face (`config/mining.lua`) with a `pickaxe` in the satchel, MULTItarget "Mine" on the rock (Left Alt; or a hold prompt without MULTItarget, `Config.Mining.Interaction = 'auto'`) starts the game's
  pickaxe scenario. The server checks the pickaxe, the distance (OneSync), the rock's charges and the cooldown, waits
  the work time, checks again, then rolls the chance table (coal, rock, iron, lead; copper, sulfur, nitrate, a little
  silver and gold in the desert). Each rock has a few swings, then is worked out until it refills.
- **Gold panning.** Use the `goldpan` while standing (not swimming) in a river, creek, lake, pond or swamp (the game's
  water map). Gold is rare: small nugget 10 %, medium 2 %, large 0.3 % per pan. The server cannot see water: by default
  it trusts the client's water check; set `Config.PanningZones` to make it check places too.
- **Lumber.** With an `axe`, MULTItarget "Chop wood" on a tree (or a prompt anywhere in the zone without MULTItarget, `Config.Lumber.Interaction = 'auto'`). `/mcinteract` (MULTIcore) prints the mining zones, tree target and prompts to the server console.
  The server checks the axe and that the player stands in a lumber zone (`config/lumber.lua`); each zone has a number
  of chops before it is cut out for a while. A chop gives 2-4 `wood` and sometimes `tree_seeds`.
  With MULTItarget every tree also runs out on its own: after `ChopsPerTree` chops (default 3) the tree is felled
  for `TreeRegrowMinutes` (default 20) and the player has to move on to another one. With no lumber zones in
  `config/lumber.lua` players can chop any tree on the map.
- **Herbs.** The game's own herb plants grow at about 6,000 spots (rsg-herbalist's list). Walk up to one and press the
  game's pick-up key. The server knows which plant grows at that spot, checks the distance, gives 1-2 of the herb and
  lets the plant regrow after `RegrowMinutes`.

All jobs: one request per kind per `RateLimitMs`, a per-player cooldown per activity, items given all-or-nothing
(nothing is lost when the satchel is full), tools can break (`ToolBreakChance`, off by default).

### Mining coordinates
No free RSG v2 resource ships mine coordinates, so the spots in `config/mining.lua` (Annesburg mine, Gaptooth Breach
near Tumbleweed) are approximate. Stand at a rock face and type `/gatherspot` (admin): it prints
`coords = vector3(...)` in F8 and the server console, ready to paste. Heights may be a few metres off
(`Config.ZTolerance`).

Easier: stand at the rock face and type `/minespot add coal` (or `desert`, or any table in `Config.MiningRewards`;
an optional third word is the radius in metres). The face can be mined at once, no restart, and joins the nearest
mine's blip. `/minespot remove` deletes the nearest face added this way within 10 m. Faces added in game are kept
in `data/mining_spots.json` and load on every start next to `config/mining.lua`.

## Selling
Everything gathered here already has a buyer in MULTIstores' default lists. Wood, rock, ores, coal, sulfur, nitrate,
nuggets, berries and mushrooms go to the general store, and medicinal herbs go to the doctor. Change prices or add
buyers in MULTIstores' `config/products.lua`.

## Config
- `config.lua`: rules, stand-down lists, the gold pan item, and one block per activity (tool, work time, cooldown,
  break chance, animation). Every option is commented with its default.
- `config/fish.lua`: fish model -> item and weight range; bait -> fish it draws.
- `config/mining.lua`: rock spots and reward tables. `config/lumber.lua`: zones, reward tables, tree models.
- `config/panning.lua`: reward table and optional zones. `config/herbs.lua`: plant -> herb item.
  `config/herb_spots.lua`: where plants grow.
- Reward tables: `{ item, chance (%), min, max }` per line, each rolled on its own; `fallback` is given when none hits.
- Any item named in the config that MULTIinventory does not know is registered at start (with a console note).
- Words: `locales/` (32 languages).

## Commands
| Command | Who | What |
|---|---|---|
| `/gatherspot` | admin | prints a `coords = vector3(...)` line for where you stand |
| `/minespot add <rewards> [radius]` | admin | makes the rock face you stand at a mining spot (saved, live at once) |
| `/minespot remove` | admin | removes the nearest rock face added in game (within 10 m) |

## Exports (server)
| Export | Returns |
|---|---|
| `Start(src, activity, target?)` | `true, ms` / `false, err`. activity `mining` (target = spot id), `lumber` (target = optional tree position `"x,y,z"`), `panning` |
| `Finish(src)` | `true, given` / `false, err`; `given` = `{ { name, amount } }` (may be empty for panning) |
| `Cancel(src)` | drops the running job |
| `Cast(src, bait)` | uses one bait: `true` / `false, err` |
| `Catch(src, model, kg)` | `true, given` / `false, err` |
| `Pick(src, spotKey)` | `true, given` / `false, err` |
| `GetSpot(id)`, `GetFish(model)`, `GetHerbSpot(key)`, `IsPicked(key)`, `HasCast(src)` | lookups |
| `Roll(table)` | rolls a reward table |
| `IsActive(activity)`, `StandingDownFor(activity)`, `IsReady()` | state |

Errors: `no_player`, `disabled`, `stand_down`, `busy`, `cooldown`, `need_tool`, `bad_spot`, `too_far`, `depleted`,
`no_zone`, `no_job`, `too_soon`, `expired`, `bad_bait`, `no_bait`, `no_cast`, `unknown_fish`, `wrong_bait`,
`picked`, `tree_done`, `no_item`, `no_space`, `too_heavy`, `limit`, `failed`.

Server event: `MULTIgathering:gathered (src, activity, place, given)` after each reward, for XP or quest scripts.

## Compatibility
| Call | Behaviour |
|---|---|
| rsg-fishing (`rsg-fishing:FishToInventory`, `rsg-fishing:server:removeBaitItem`, exports `GET_TASK_FISHING_DATA_EXTRA` ...) | Not answered, not provided: no RSG v2 or RINGO script calls them (only rsg-fishing's own client). Answering `FishToInventory` would let a client name its own fish. |
| rsg-goldclaim, rsg-lumberjack, rsg-herbalist events and exports | Not answered, not provided: no other script calls them. |
| `GetResourceState('rsg-fishing' / 'rsg-lumberjack' / 'rsg-herbalist')` | report `missing` as before; when the real one runs, MULTIgathering stands down for that activity |

## Self-test
`test/gathering_selftest` (needs `setr multicore_selftest true`): prints `[gathertest] DONE: n passed, m failed`.
