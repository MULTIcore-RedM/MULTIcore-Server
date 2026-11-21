# MULTIhorses

Horses and stables for MULTIcore. GPL v3 (see `LICENSE`). Stands in for **rsg-horses** (`provide 'rsg-horses'`).
MULTIcore was founded and created by RINGO (RINGOscripting).

- **Stables** in nine towns, each with a stable hand and a map blip. Hold **Left Alt** (MULTItarget) on the stable hand
  and pick **Stable Menu**. Without MULTItarget a hold-key prompt is used (`Config.Interact`).
- **The stable page** (MULTIcore's black and white look): view your horses and ride one, sell, move to another stable,
  trade to a nearby player, breed, the horse shop, store your horse, buy a horse, customize.
- **Buying** at the stables in `Config.BuyStables` (Valentine): 104 horses, a live preview you can turn, a name and gelding or mare.
- **Customization** at the stables in `Config.CustomizeStables` (Valentine): saddles, blankets, horns, saddlebags, stirrups,
  bedrolls, manes, tails, masks, mustaches, bridles, horseshoes, plus coat colour, markings, nose, mane and tail colour.
  Every changed piece is paid once (`Config.PriceComponent`, `Config.CoatPresets`).
- **Calling:** H (the game's whistle) calls the active horse; far away it is brought near you.
- **On the horse** (MULTItarget): lantern, holster on / off, store or take a long arm, saddlebags.
- **Care:** use horse food from the satchel next to your horse (`horsecarrot`, `horseapple`, `hay`, and MULTIcore's
  `horse_carrot`, `horse_apple`, `haysnack`, `horsemeal`), the stimulant, the brush, the reviver. Leading the horse to
  water, a trough or a hay pile lets it drink or graze (game key prompts while leading).
- **Horse xp and levels:** feeding, brushing, drinking and grazing give xp (server-side, cooldown per horse). Ten levels
  raise health, stamina, speed and acceleration, the saddlebag size and the bond. Tricks: **Lay** at 1000 xp, **Play** at 2000.
- **Saddlebags:** one MULTIinventory inventory per horse (`custom:horse_<horseid>`), sized by level. They open while the horse
  wears a saddle and saddlebags (`Config.SaddlebagsNeedTack`).
- **Breeding** (job `horsebreeder`, `Config.Breeding`): a mare and a stallion, hay, a foal is born after the gestation time and grows up.
- **Death and old age:** a fallen horse can be revived for `Config.DeathGracePeriod`; after that it goes back to its
  stable (`Config.DeleteDeadHorse = true` makes it gone for good instead). Horses die of old age after
  `Config.HorseDieAge` days, the starter horse after `Config.StarterHorseDieAge` (0 = never); the owner gets a telegram.
- **Wild horses:** tame one, ride it to a horse seller (Van Horn, Valentine, Blackwater) and sell it or have it stabled
  (`config/wildhorse.lua`). Rewards are worked out on the server.
- 10 languages, nothing drawn in the world (no markers, no floating text, no dots).

Everything that costs money or changes a horse is checked on the server (ownership, stable distance, prices, quantities).

## Setup
1. Put `MULTIhorses` in `resources/[multicore]`. Do **not** run `rsg-horses` as well.
2. `server.cfg`, after MULTItarget, MULTIcore and MULTIinventory: `ensure MULTIhorses`.
3. `player_horses` is made on start; missing columns are added by themselves (`sql/multihorses.sql` has the same).
   Servers coming from the earlier MULTIhorses keep their horses: on the first start they are made grown up, their
   saddle and blanket become customization pieces and each gets saddlebags. `multihorses_state` is then no longer used.
4. Items: `hay`, `horsecarrot`, `horseapple` and `horse_holster` are added at start when MULTIcore's items do not have them
   (`Config.NewItems`). Pictures are in `images/` — copy them into MULTIimages' `images` folder.
5. Optional: `setr multicore_locale de` picks the language for all MULTI scripts (`Config.Locale` for this one only).

## Commands
| Command | What it does |
|---|---|
| `/findhorse` | lists your horses, where they are stabled and which is active (MULTIradial uses it) |
| `/fleehorse` | sends your horse away (MULTIradial uses it) |
| `/sethorsename` | renames your active horse |
| `/accepttrade` | takes a horse someone offered you |
| `/seat 2` | change seats on a horse or wagon |

Names in `Config.Commands` ('' = off). `/sethorsewild` (admins) only with `Config.WildHorse.Debug`.

## Config
`config.lua`, one comment per option: money, stable interaction and distances, which stables sell and customize, the
horse shop, prices for tack and coats, old age and death, saddlebags, levels, food and xp, drinking and grazing, blips,
breeding, foals, commands, Discord logs (`Config.Webhooks`, off by default), stables. Wild horse sellers:
`config/wildhorse.lua`. Horses for sale: `shared/horse_settings.lua`. Tack pieces: `shared/horse_comp.lua`.
Text: `locales/<lang>.lua` (en, de, es, fr, it, nl, pl, pt-br, ru, tr). Change the look in `html/custom.css`.

## Exports
Server (`exports.MULTIhorses` and `exports['rsg-horses']`):
- `GetHorses(srcOrCitizenid)` → rows of `player_horses`
- `GetActiveHorse(srcOrCitizenid)` → the active row or nil
- `SaddlebagId(horseid)` → MULTIinventory id of the saddlebags
- `SellPrice(model)` → what a stable pays, or nil
- `IsReady()` → true once the table is set up

Client: `CheckActiveHorse()` (ped or 0), `CheckHorseLevel()`, `CheckHorseBondingLevel()` (also as `exports['rsg-horses']`),
and `GetHorse()`, `GetHorseData()`, `CallHorse()`, `SendAway()`.

Server event fired: `MULTIhorses:ready` once the table is set up.

## rsg-horses compatibility
- Every server event `rsg-horses:server:<name>` (and `rsg-horses:renameHorse`) runs the same MULTIhorses function with
  the same checks: `BuyHorse`, `SetHoresActive`, `SetHoresUnActive`, `deletehorse`, `MoveHorse`, `openhorseinventory`,
  `HorseDied`, `sethorseAttributes`, `openShop`, `buyShopItems`, `fleeStoreHorse`, `breedHorse`, `TradeHorse`,
  `AcceptTrade`, `storeHorseWeapon`, `retrieveHorseWeapon`, `clearHorseWeapon`, `SaveComponents`, `SetPlayerBucket`,
  `brushhorse`, `AddHorseXp`.
- Callbacks `rsg-horses:server:GetActiveHorse`, `GetHorse`, `GetAllHorses`, `GetPlayerHorses`, `CheckComponents`,
  `getHorseWeapon`, `getWeaponData`, both as ox_lib callbacks and as core callbacks.
- Client events `rsg-horses:client:FleeHorse`, `SpawnHorse`, `equipHorseLantern`, `equipHorseHolster`, `inventoryHorse`,
  `gethorselocation`, `stablemenu` and the rest of the client events.
- `player_horses` keeps the same table and columns, so starter horses inserted by character scripts and scripts that
  read the table keep working.

## Credits
- **MULTIhorses is based on rsg-horses by Phil**, renamed and fitted to MULTIcore with Phil's permission. Thank you, Phil:
  the stable page, buying and preview, customization and coats, breeding and foals, horse xp and levels, the holster,
  trading, moving, the horse shop, wild horses, Discord logs.
- rsg-horses is GPL v3 and builds on the RSG v2 framework resource by **Rexshack-RedM, RexShack and their contributors**
  (https://github.com/Rexshack-RedM/rsg-horses), who keep their copyright. See `CREDITS.md`.
- **RINGO (RINGOscripting)**: founder of MULTIcore; the MULTIcore version.

## Licence
GPL-3.0-or-later. See `LICENSE`.
