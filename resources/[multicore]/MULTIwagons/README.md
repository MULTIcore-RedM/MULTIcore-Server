# MULTIwagons

Owned wagons for MULTIcore servers. GPL v3.
MULTIcore was founded and created by RINGO (RINGOscripting).

- **Wagon dealers** in Valentine, Saint Denis, Strawberry, Blackwater, Tumbleweed and Caliga Hall, each with a clerk and a map blip. Hold **Left Alt** (MULTItarget) on the counter or the clerk, or use the hold-key prompt when MULTItarget is not running (`Config.Interact`).
- **The dealer page:** wagons for sale by kind (work, special, coaches), shown in the showroom with a camera you can turn. Buy one and give it a name.
- **My wagons:** pick one to take it out (it becomes your selected wagon), change it, or sell it.
- **Changes** (paid each time): side stripes, paint, extras (several at once), cargo sets in four groups, and lanterns. Shown on the showroom wagon before you pay.
- **Call your wagon** with `/wagon` (also in MULTIradial under Horse > Wagon). It comes to the nearest road. One wagon out at a time.
- **At the wagon** (MULTItarget, or hold-key prompts): **Wagon storage** at the back, **Send away** (owner), and for wagons that carry game, **Store carcass / pelt** and **Stored carcasses / pelts** (owner).
- **Storage:** every wagon has a MULTIinventory inventory `trunk:<id>` (slots and weight per model). The owner opens it; another player asks and the owner says yes or no (`Config.StorageOpenTo`). The server checks the distance and closes it when the player walks off.
- **Carcasses and pelts:** the hunting cart and some work wagons carry game (`maxAnimals` per model). The hunting cart's tarp fills up as you load it.
- **Chop shop:** bring any wagon and scrap it for wood and cash. Your own wagon is deleted for good; other players' owned wagons cannot be scrapped.
- Drawn in MULTIcore's black and white look, in 10 languages. Nothing is drawn in the world: no markers, no dots, no floating text.

## Setup
1. Put `MULTIwagons` in `resources/[multicore]`.
2. In `server.cfg`, after MULTItarget, MULTIcore and MULTIinventory: `ensure MULTIwagons`.
3. Do not run `rsg-wagons` as well: MULTIwagons answers in its place (`provide 'rsg-wagons'`).
4. The table `rsg_wagons` is made by itself on the first start, and columns an older table lacks are added (a copy is in `sql/multiwagons.sql`). The table keeps that name so wagons from earlier versions carry over: they get a storage id on the first start, their storage keeps its items, and items from old `Wagon_Stash_<id>` stashes move into it (`Config.MigrateOldStashes`). A player whose wagons have none selected gets the first one when they call.
5. The chop shop gives `wood`, which is in MULTIcore's `shared/items.lua`.
6. Optional: `setr multicore_locale de` picks the language for all MULTI scripts.

## Commands
| Command | What it does |
|---|---|
| `/wagon` | calls your selected wagon (name set by `Config.CallCommand`; MULTIradial uses it) |
| `/chopdebug` | only with `Config.Chop.Debug = true`: prints the chop shop checks to F8 |

## Config
Everything is in `config.lua`, one comment per option:

| Setting | Purpose |
|---|---|
| `Config.Locale` | language for this script only |
| `Config.Interact`, `Config.PromptKey`, `Config.PromptDistance`, `Config.Target*` | MULTItarget or hold-key prompts |
| `Config.WagonInteractDistance`, `Config.StorageDistance`, `Config.StorageBackOffset` | where the wagon options show |
| `Config.Keys` | keys of the wagon prompts (prompt mode) |
| `Config.CallCommand`, `Config.SpawnKey`, `Config.SpawnRadius`, `Config.FallbackSpawnDistance` | calling the wagon |
| `Config.DespawnOnLeave` | the wagon goes when its owner leaves |
| `Config.MoneyType`, `Config.CurrencySign` | money types and sign |
| `Config.maxWagonsPerPlayer`, `Config.Sell`, `Config.SellNeedsEmptyStorage`, `Config.NameMaxLength` | owning and selling |
| `Config.ServerDistanceCheck`, `Config.DealerUseDistance`, `Config.StorageServerDistance` | server checks |
| `Config.StorageOpenTo`, `Config.MigrateOldStashes` | storage |
| `Config.Blip` | dealer and own-wagon blips |
| `Config.Stores` | dealers: counter, clerk, showroom spot and camera |
| `Config.Wagons` | wagons for sale by kind: name, price (`priceGold` optional), storage slots and weight, `maxAnimals` |
| `Config.CustomPrice` | price of each change |
| `Config.AnimalsStorage` | carcasses and pelts a wagon takes, with their names |
| `Config.Chop` | chop shop places, rewards, cooldown, blip |

What each model can be fitted with is in `client/list.lua` and `client/wagon_extras.lua`.
Change the look in `html/custom.css`.

## Exports
Server:

| Export | Returns |
|---|---|
| `IsReady()` | true once the table and storages are ready |
| `GetWagons(src or citizenid)` | list of `{ id, citizenid, model, label, name, plate, selected, out, netId, storage, custom }` |
| `GetWagon(id)`, `GetWagonByPlate(plate)`, `GetWagonByNetId(netId)`, `GetActiveWagon(src or citizenid)` | one of those (the active one is the wagon that is out), or nil |
| `GetStorageId(id or plate)` | `'trunk:<plate>'` |
| `GetModelConfig(model)` | the `Config.Wagons` entry |
| `OpenStorage(src, id)` | opens that wagon's storage for src (no checks) |
| `CallWagon(src)` | calls src's selected wagon |
| `Despawn(id)` | removes that wagon from the world |

Server events: `MULTIwagons:ready`, `MULTIwagons:bought (src, id, model)`, `MULTIwagons:sold (src, id, model, payout)`,
`MULTIwagons:spawned (src, id, netId)`, `MULTIwagons:stored (src, id)`.
A wagon that is out carries the state bag `multiwagon = { id, owner, model, name, plate }`.

Client: `GetMyWagon()` (entity, id, model), `CallWagon()`, `SendAway()`, `OpenStore(storeId)`.

## Old wagon script names
For scripts written for rsg-wagons:

| Call | What MULTIwagons does |
|---|---|
| table `rsg_wagons` | same shape; `custom.name` is the name |
| callback `rsg-wagons:checkMyWagons` | `models[], customs[]` |
| callback `rsg-wagons:isWagonRegistered (netId)` | `true, isOwner, id, model, netId` for a wagon that is out, else `false` |
| callback `rsg-wagons:getAnimalStorage (id)` | the carcasses / pelts in that wagon |
| event `rsg-wagons:getWagonDataByCitizenID` | calls the player's selected wagon |
| event `rsg-wagons:openWagonStash (stash, model, id, netId)` | opens that wagon's storage (same checks) |
| event `rsg-wagons:saveWagonToDatabase (model, custom)` | buys at a dealer, named `custom.name` |
| event `rsg-wagons:sellWagon (model, custom)` | sells the wagon named `custom.name` |
| event `rsg-wagons:toggleWagonActive (model, custom)` | selects and calls that wagon |
| event `rsg-wagons:removeWagon (netId)` | sends the sender's wagon away |
| events `rsg-wagons:registerWagon`, `updateWagonAuth`, `storeAnimalInWagon`, `removeAnimalFromWagon` | the same as MULTIwagons' own |
| client `rsg-wagons:client:callwagon` / `dellwagon` / `openStore` | call / send away / open a dealer page |

## Credits
MULTIwagons is based on **rsg-wagons by Phil**, with wagon work by **Mack**, renamed and fitted to MULTIcore with their permission. Thank you, Phil and Mack.

- **Phil**: the original wagon script (dealers and showroom, buying and naming, changes, calling the wagon, storage with owner permission, carcass and pelt storage, chop shop).
- **Mack**: the wagon extras, liveries, cargo sets and lantern tiers in `client/wagon_extras.lua`.
- **RINGO (RINGOscripting)**: founder of MULTIcore; the MULTIcore version.

Earlier MULTIwagons versions were based in part on RSG v2's **rsg-wagons** (GPL v3, original project https://github.com/Rexshack-RedM/rsg-wagons, authors **Phil and mack**, with the Rexshack-RedM team and contributors), who keep their copyright. MULTIwagons is not affiliated with or endorsed by the RSG team.

## Licence
GPL-3.0-or-later. See `LICENSE`.
