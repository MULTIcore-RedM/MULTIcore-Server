# MULTIfarming

Basic farming for MULTIcore. GPL v3 (see `CREDITS.md`).

Buy seeds, a hoe and a watering can at the general store, plant the seeds in open ground, keep the crops watered and
harvest them for MULTIinventory items the general store buys. Deliberately simple: no soil quality, no fertiliser,
no farm plots, no skills. Premium farming scripts do those.

## Setup
1. Put `MULTIfarming` in `resources/[multicore]`.
2. `server.cfg`, after oxmysql, MULTIinventory and MULTIstores: `ensure MULTIfarming`.
3. The table `multi_farming_plants` is created by itself at start (`CREATE TABLE IF NOT EXISTS`).
4. Item pictures: add `hoe.png`, `wateringcan.png` and `seed_corn.png` ... `seed_tobacco.png` to MULTIinventory's
   item images (the items work without them).

## How it works
Every decision is made on the server. The client never names an item or an amount.

- **Planting.** Use a seed from the satchel (`seed_corn`, `seed_potato` ...) with a `hoe` in the satchel. The seed goes
  just in front of you. Refused in towns, inside buildings, in water, on roads and closer than `MinSpacing` to another
  crop. The server checks the seed, the hoe, the limit per character (`MaxPlantsPerPlayer`), the distance from your
  position (OneSync; `Config.AllowWithoutPosition`), `Config.FarmZones` (when set) and the spacing again, then takes
  one seed.
- **Growing.** A crop has three looks: seedling, growing and ripe, each its own game model. It only grows while it has
  water; each minute of growth uses `waterUse` % of its water. Growth is worked out on the server from timestamps
  and saved in MySQL, so it survives restarts (time while the server is off does not count unless
  `Config.Growth.CountOfflineTime = true`).
- **Watering.** Fill the `wateringcan` by using it while standing in a river, creek, lake, pond or swamp (the game's
  water map). A full can holds `CanUses` waterings (kept in the can's `info.water`). Use the can next to a crop, or
  pick Water on the crop: it adds `Amount` % water.
- **Withering.** A crop that is not ripe and stays dry for `DryWitherMinutes`, or is ripe and left for
  `RipeWitherMinutes`, withers. A withered crop is taken away after `DeadRemoveMinutes`.
- **Harvesting.** A ripe crop gives `min`-`max` of its item and, with `seedBack.chance` %, some seeds back. Items are
  given all-or-nothing (nothing is lost when the satchel is full). With `Config.Harvest.OwnerOnly = true` (default)
  only the planter may harvest. The planter can always dig up their own crop (it is lost).
- **Interaction.** MULTItarget on the crop: Check crop (a note with crop, stage and water %), Water, Harvest, Dig up.
  Without MULTItarget a hold prompt next to the crop opens the same choices in a menu (`Config.Interaction`).
  Notes and menus use MULTIcore's look, so the UI presets apply.
- **Props.** Crops are local objects, put into the world within `LoadRange` and taken out beyond `UnloadRange`.
  The server sends every player the crop list in chunks at login and each change after that.

All work (plant, water, harvest, dig up, fill) runs in two steps: the server notes the start, then checks the time
really passed and everything again before acting. One request per kind per `RateLimitMs`.

## Selling and buying
MULTIstores' general store sells the hoe, the watering can and the eight seeds, and buys corn, potatoes, tomatoes,
carrots, onions, wheat, pumpkins and tobacco leaves.

## Config
- `config.lua`: rules, planting, watering, growth and withering, harvesting, prop range, admin, new items.
  Every option is commented with its default.
- `config/crops.lua`: one entry per crop: seed item, crop item, amount, stage models and minutes, water use,
  seed-back chance.
- Any item named in the config that MULTIinventory does not know is registered at start (with a console note).
- Words: `locales/` (32 languages).

## Crops
| Crop | Seed | Gives | Models (seedling, growing, ripe) |
|---|---|---|---|
| corn | `seed_corn` | `corn` 2-4 | `crp_seedling_aa_sim`, `crp_cornstalks_cb_sim`, `crp_cornstalks_ab_sim` |
| potato | `seed_potato` | `potato` 2-4 | `crp_seedling_aa_sim`, `crp_potato_sap_aa_sim`, `crp_potato_aa_sim` |
| tomato | `seed_tomato` | `tomato` 2-4 | `crp_seedling_aa_sim`, `crp_tomatoes_sap_aa_sim`, `crp_tomatoes_aa_sim` |
| carrot | `seed_carrot` | `horsecarrot` 2-4 | `crp_seedling_aa_sim`, `crp_carrots_sap_ba_sim`, `crp_carrots_ba_sim` |
| onion | `seed_onion` | `onion_vidalia` 2-3 | `crp_seedling_aa_sim`, `crp_seedling_aa_sim`, `p_oniongreen02x` |
| wheat | `seed_wheat` | `grain_wheat` 2-4 | `crp_wheat_sap_ac`, `crp_wheat_sap_long_aa_sim`, `crp_wheat_dry_long_aa_sim` |
| pumpkin | `seed_pumpkin` | `pumpkin` 1-2 | `crp_seedling_aa_sim`, `crp_lettuce_aa_sim`, `p_pumpkin_01x` |
| tobacco | `seed_tobacco` | `tobacco_leaf` 2-3 | `crp_tobaccoplant_aa_sim`, `crp_tobaccoplant_ab_sim`, `crp_tobaccoplant_ac_sim` |

A withered crop shows `crp_tobaccoburnt_bb_sim` (`Config.Growth.DeadProp`).

## Commands
| Command | Who | What |
|---|---|---|
| `/farmclear [radius] [dead\|all]` | admin (`Config.Admin.Groups` or the ace `multifarming.admin`) | clears withered crops (or all) within the radius (default 50 m); from the server console: the whole map |

## Exports (server)
| Export | Returns |
|---|---|
| `GetPlants(citizenid)` | `{ { id, crop, x, y, z, stage, ripe, dead, water } }` |
| `CountPlants(src)` | number of crops the player's character has in the ground |
| `Begin(src, action, target)` | `true, ms` / `false, err`. action `plant` (target = crop id), `water` / `harvest` / `remove` (target = crop row id), `fill` |
| `Finish(src, data?)` | `true` / `false, err`; `data = { x, y, z, h }` for `plant` |
| `Cancel(src)` | drops the running job |
| `IsReady()` | true once the crops are loaded |

Errors: `no_player`, `bad_action`, `bad_crop`, `busy`, `no_seed`, `need_tool`, `limit`, `bad_pos`, `too_far`, `no_zone`,
`too_close`, `gone`, `dead`, `not_ripe`, `not_owner`, `wet_enough`, `can_empty`, `can_full`, `no_job`, `too_soon`,
`expired`, `no_space`, `too_heavy`, `failed`.

Server event: `MULTIfarming:harvested (src, crop, given)` after each harvest (`given` = `{ { name, amount } }`),
for XP or quest scripts.
