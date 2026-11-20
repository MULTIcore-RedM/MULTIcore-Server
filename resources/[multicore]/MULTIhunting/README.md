# MULTIhunting

Basic hunting for MULTIcore. GPL v3 (see `CREDITS.md`).

When a player skins an animal with the game's own skinning (or picks up small game), MULTIhunting gives
MULTIinventory items: the pelt / skin / hide, meat and animal parts (feathers, beaks, claws, teeth, antlers,
horns, hearts ...). The items are the ones MULTIstores' **trappers and butchers already buy**, so selling works
straight away. Deliberately simple: no hunting UI, no legendary hunts, no carcass sale, no XP. Premium hunting
scripts do those.

## Setup
1. Put `MULTIhunting` in `resources/[multicore]`.
2. `server.cfg`, after MULTIinventory and MULTIstores: `ensure MULTIhunting`.
3. Don't run `rsg-hunting` or another script that pays for skinning alongside it. If one listed in
   `Config.StandDownFor` is started (default `rsg-hunting`, `RINGOoutdoors`), MULTIhunting gives nothing and says so
   in the server console.

## How it works
- **Detection (client):** the game's loot-complete event (`1376140891`), read the way rsg-hunting reads it. Only the
  local player's own, finished skinning of a configured animal counts.
- **Grade:** the game's animal quality (`_GET_PED_QUALITY`) and kill cleanliness (`_GET_PED_DAMAGE_CLEANLINESS`),
  0 poor / 1 good / 2 perfect. `Config.Quality.Mode = 'min'` takes the lower of the two. The pelt carries
  `info.quality` (poor 40, good 70, perfect 100 by default) and MULTIstores pays `price x quality / 100`.
  An animal may instead give a different item per grade: `pelt = { poor = 'poor_pelt', good = 'good_pelt', perfect = 'perfect_pelt' }`.
  Legendary animals are always perfect.
- **Reward (server):** the server decides everything. Unknown animals give nothing. Each carcass (network id plus
  model) pays **once** (remembered `Config.CarcassMemorySeconds`), with a short per-player cooldown. With OneSync,
  when the server can see the carcass, its model and the distance to the player are checked. All items are checked
  for room first; if one doesn't fit, nothing is given and the carcass can be skinned again after making room.
- **The game's pelt:** after skinning, the game hands the player a pelt (which could be laid on the horse). The pelt
  is now an inventory item, so the carried copy is removed (`Config.RemoveCarriedPelt`). RedM has no working game
  trapper, so the game's own pelt-on-horse / sell loop pays nothing; removing the copy also stops another script from
  buying the same skin twice. Small game that the player picks up whole is removed from the hands the same way.
- **Tools (optional):** `Config.RequireItems = { 'weapon_melee_knife', ... }` means the player must carry one of them.
  Off by default.
- **Whole carcass sale:** not built. Carrying a carcass to the butcher is left to premium hunting scripts.

## Config
- `config.lua`: detection timings, carried pelt and carcass removal, quality, meat item, cooldown, carcass memory,
  distance, tools, stand-down list, notifications. Every option is commented with its default.
- `config/animals.lua`: what each animal gives, keyed by ped model name:
  `pelt` (string or per-grade table), `meat` (count of `Config.MeatItem`), `meatItem`, `parts`
  (`'item'` or `{ 'item', amount }`), `whole` (small game kept whole), `legendary`.
  93 animals are set up (from rsg-hunting's list, plus meat).
- Any item named there that MULTIinventory does not know is registered at start (with a console note); add it to a
  store to make it sellable.
- Words: `locales/` (10 languages).

## Exports (server)
| Export | Returns |
|---|---|
| `Reward(src, model, grade, netId?)` | `true, given` / `false, err`. `model` = name or hash; `grade` 0-2; `given` = `{ { name, amount, info? } }`. Errors: `no_player`, `stand_down`, `unknown_animal`, `cooldown`, `already_skinned`, `not_networked`, `wrong_model`, `too_far`, `need_tool`, `no_space`, `too_heavy`, `limit`, `failed` |
| `GetAnimal(model)` | the animal's config entry (copy) or nil |
| `GetRewards(model, grade)` | the item list a skinning would give, or nil |
| `Grade(quality, cleanliness)` | 0-2 with `Config.Quality.Mode` |
| `IsCarcassSkinned(netId, model?)` | bool |
| `IsReady()` | bool |

Server event: `MULTIhunting:skinned (src, model, grade, given)` after each reward, for XP or quest scripts.

## Compatibility
| Call | Behaviour |
|---|---|
| rsg-hunting events / exports (`rsg-hunting:server:giverewards`, `DataViewNativeGetEventData`) | Not answered and `rsg-hunting` is not provided: no RSG v2 or RINGO script calls them (only rsg-hunting's own client does). Answering `giverewards` would let a client name its own items. |
| `GetResourceState('rsg-hunting')` | reports `missing` as before; if the real rsg-hunting runs, MULTIhunting stands down |

## Self-test
`test/hunting_selftest` (needs `setr multicore_selftest true`): prints `[hunttest] DONE: n passed, m failed`.
