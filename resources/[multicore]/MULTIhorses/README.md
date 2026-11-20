# MULTIhorses

Basic horses and stables for MULTIcore. GPL v3 (see `CREDITS.md`). Stands in for **rsg-horses** (`provide 'rsg-horses'`).
Deliberately simple: breeding, horse levels, trading, coat editing, wild horses and a showroom are left to premium stable scripts.

- **Stables** in nine towns (rsg-horses' places), each with a stable hand and a map blip. "Open stable" through MULTItarget on the stable hand (Left Alt) when MULTItarget runs, else a hold-key prompt (`Config.Interact = 'auto'`, `Config.PromptDistance`).
- **Buy** a horse from a list of 41 breeds and coats at RDR2's 1899 stable prices, **name** it, pick stallion or mare.
  A character owns up to `Config.MaxHorses` (3).
- **Riding horse:** pick one at the stable it stands in. **Fetch** a horse from another stable for a small fee.
  **Stable** your riding horse at any stable. **Rename** at a stable. **Sell** back for 40 % of the price
  (never more than half; the saddlebags must be empty).
- **Calling:** H (the game's whistle) calls the riding horse. Close by, it walks to you; far away, it is brought
  near you. On the horse (MULTItarget, or the game's prompts when you look at it): **Saddlebags**, **Brush**, **Feed**,
  **Follow me**, **Send away**, **Use horse reviver**. `/fleehorse` sends it away, `/findhorse` lists your horses.
- **Care:** feeding (carrots, apples, hay snack, horse meal, stimulant, and rsg-horses' `horsecarrot`, `horseapple`, `hay`)
  raises the health and stamina cores; brushing cleans the horse and gives a little stamina. The cores are saved.
- **Falling:** a horse that dies lies there for `Config.Revive.BodySeconds`; a horse reviver brings it back. After that
  the stable takes it in, and it can't be called until the vet at a stable has nursed it back (`Config.Revive.StableFee`).
- **Saddlebags:** every horse has its own MULTIinventory custom inventory (`custom:horse_<horseid>`),
  `Config.Saddlebag` slots and weight. Opened only beside your horse.
- **Tack:** six saddles and six blankets at the stable (`config/tack.lua`).

Everything that costs money or changes a horse is checked on the server (stable distance with OneSync, ownership,
limits, horse beside the player, items in the satchel, rate limit).

## Setup
1. Put `MULTIhorses` in `resources/[multicore]`.
2. `server.cfg`, after MULTIcore and MULTIinventory: `ensure MULTIhorses`.
3. Do **not** run `rsg-horses` as well. Existing `player_horses` rows carry over (horses stay; old rsg-horses
   saddlebag stashes are not moved).
4. Tables are made on start: `player_horses` (rsg-horses' shape) and `multihorses_state`. `sql/multihorses.sql` has the same.
5. Recommended: MULTItarget. With `Config.Interact = 'auto'` (default) the stable and horse options use it when it runs (the script waits for it at start and switches if it starts or stops later), else prompts. `/mcinteract` (MULTIcore) prints the targets, prompts and stable hands this script placed to the server console.

## Config
Everything is in `config.lua`, one comment per option: money and limits, stable interaction and distances, stable hands,
blips, transfers, whistle key and calling, care (food list, brush, lantern, reviver, vet fee), saddlebags, horse prompts,
rate limit, commands. Stables are in `config/stables.lua`, horses and prices in `config/horses.lua`, tack in
`config/tack.lua`, the extra items in `config/items.lua`.
Text is in `locales/<lang>.lua` (en, de, fr, es, pt-br, it, pl, ru, nl, tr). The menus are ox_lib menus.

## Items
Uses MULTIcore's `horse_brush`, `horse_carrot`, `horse_apple`, `haysnack`, `horsemeal`, `horse_stimulant`,
`horse_reviver`, `horse_lantern`; registers `hay`, `horsecarrot`, `horseapple` when missing. The usable items are
registered as built-in, so a premium stable script that handles them keeps them.

## Exports (server)
- `Buy(src, stableId, model, name, gender)` → `true, { id, horseid }` | `false, err`
- `Sell(src, id, stableId)` → `true, paid` · `SetActive(src, id, stableId)` · `Store(src, stableId)`
- `Transfer(src, id, toStableId, fromStableId?)` → `true, fee` · `Rename(src, id, name)`
- `ReviveAtStable(src, id, stableId)` · `SetTack(src, id, 'saddle'|'blanket', index (0 = off), stableId)`
- `Feed(src, item?, slot?)` · `Brush(src)` · `ReviveWithItem(src, slot?)` · `OpenSaddlebag(src)`
- `GetHorses(srcOrCitizenid)` · `GetActiveHorse(srcOrCitizenid)` · `GetHorseOut(src)` → `{ horseid, netId, dead }`
- `SaddlebagId(horseid)` · `SellPrice(model)` · `RegisterStable({ id, label?, coords?, distance? })` · `GetStable(id)` · `IsReady()`

`id` is the `player_horses.id` number or the `horseid` string. Errors: `too_far`, `bad_stable`, `bad_horse`, `bad_name`,
`limit`, `no_money`, `not_owner`, `bag_not_empty`, `injured`, `not_here`, `no_active`, `is_active`, `already_here`,
`not_injured`, `bad_tack`, `tack_same`, `no_horse`, `horse_dead`, `not_dead`, `no_food`, `no_brush`, `no_reviver`, `slow_down`, `busy`.

Server events fired: `MULTIhorses:bought (src, horseid, model)`, `MULTIhorses:sold (src, horseid)`,
`MULTIhorses:spawned (src, horseid, netId)`, `MULTIhorses:died (src, horseid)`, `MULTIhorses:ready`.
The spawned horse carries the state bag `multihorse = <horseid>` (set by the server).

## Exports (client)
`GetHorse()` (ped or 0), `GetHorseData()`, `CallHorse()`, `SendAway()`.

## rsg-horses compatibility
- `exports['rsg-horses']:CheckActiveHorse()`, `CheckHorseLevel()` (1 while a horse is out), `CheckHorseBondingLevel()`.
- Client events `rsg-horses:client:FleeHorse`, `equipHorseLantern`, `inventoryHorse`, `SpawnHorse`, `gethorselocation`.
- Server callbacks `rsg-horses:server:GetActiveHorse`, `GetHorse`, `GetAllHorses`, `GetPlayerHorses`; events `BuyHorse`,
  `SetHoresActive`, `SetHoresUnActive`, `deletehorse`, `MoveHorse`, `renameHorse`, `openhorseinventory`, `HorseDied`,
  `sethorseAttributes`, all with MULTIhorses' checks. Breeding, trading, holster weapons and customisation events are accepted and ignored.
- `player_horses` keeps rsg-horses' columns, so starter horses inserted by rsg-multicharacter and scripts that read the table work.
- A dying horse is not deleted (rsg-horses deletes it): it is hurt until revived.

## Self-test
`test/horses_selftest` (needs `setr multicore_selftest true`): prints `[horsetest] DONE: n passed, m failed`.
