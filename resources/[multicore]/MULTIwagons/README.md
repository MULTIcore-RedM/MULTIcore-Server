# MULTIwagons

Basic owned wagons for MULTIcore servers: wagon dealers in six towns, buy / name / rename / sell back,
take out and put away (one wagon out at a time), a storage inventory in every wagon, health that is
kept between take-outs, and repair with a kit or at the dealer. It answers as **rsg-wagons**
(`provide 'rsg-wagons'`, same table, same event and callback names). GPL v3, part of MULTIcore
(see `CREDITS.md`).

Deliberately simple: no customisation (tints, liveries, lanterns), no carcass storage, no chop shop,
no shared keys. Those are the job of a premium wagon script.

## What it does

- **Dealers** in Valentine, Saint Denis, Strawberry, Blackwater, Tumbleweed and Caliga Hall
  (places from RSG v2's rsg-wagons), with a clerk, a map blip and MULTItarget on the spot and the clerk (hold Left Alt) when it runs, else a hold-key prompt within `Config.PromptDistance` (`Config.Interact = 'auto'`). `/mcinteract` (MULTIcore) prints what was placed to the server console.
- **Buy** from a list of 20 carts, buggies, wagons and a carriage at 1899 prices (`config/wagons.lua`),
  and **name** the wagon. A character owns at most `Config.MaxWagonsPerCharacter` (3).
- **Sell back** at a dealer for `Config.SellBackRate` (40 %) of the price paid, never more than half.
  The wagon's storage must be empty first (`Config.SellNeedsEmptyStorage`).
- **Take out** at a dealer or a call point (`Config.CallPoints`): the wagon appears at that place's spawn
  spot. With `Config.CallAnywhere` the `/wagon` command calls it to the nearest road anywhere.
- **Put away** near a dealer or call point (or anywhere with `Config.StoreAnywhere`). One wagon out per
  character. The wagon is put away by itself when its owner leaves or switches character
  (`Config.DespawnOnLeave`), when the take-out never completes, or when the wagon is gone from the world.
- **Plate**: every wagon gets a unique id like `K7RW2M` (`custom.plate`).
- **Storage**: every wagon has a MULTIinventory inventory `trunk:<plate>` (slots and weight per model),
  opened at the wagon's back with a hold-key prompt (`Config.StorageKey`) or MULTItarget. Only the owner
  (or anyone, `Config.StorageOpenTo`). The server checks the distance on opening and closes it when the
  player walks off. Saved in `inventories` under `trunk:<plate>`.
- **Damage**: the owner's game reports the wagon's health while it is out; it is saved when the wagon
  is put away. A wagon below `Config.Health.MinToTakeOut` % must be repaired first.
- **Repair**: the `wagon_repair_kit` item (use it next to your wagon), or at a dealer for
  `Config.Repair.DealerFeePerPercent` per missing percent (a wreck costs $8.00).

## Setup

1. Put `MULTIwagons` in `resources/[multicore]/`.
2. `server.cfg`, after MULTIcore and MULTIinventory:
   ```
   ensure MULTIwagons
   ```
3. Remove `rsg-wagons` from the server: MULTIwagons stands in for it.
4. Needs `oxmysql`, `ox_lib`, `MULTIcore`, `MULTIinventory`; `MULTItarget` recommended (used automatically when it runs; `Config.Interact` `'auto'`, `'target'` or `'prompt'`).
5. The table `rsg_wagons` is created on start (rsg-wagons' own shape). Rows rsg-wagons wrote keep
   working: they get a plate and storage on the first start, and the items of the old stash
   `Wagon_Stash_<id>` move into the new storage (`Config.MigrateRsgStashes`).
6. Sell the repair kit in a general store (`wagon_repair_kit`).

## Data

`rsg_wagons` (id, citizenid, wagon = model, custom JSON, animals JSON, active). MULTIwagons keeps its
data inside `custom`: `{ name, plate, health (0-100), price (paid), buyMoneyType = 'cash' }`.
`active` is 1 while the wagon is out. A deleted character's wagons and their storage are removed.

## Config

Everything is in `config.lua` (every option with its default), `config/dealers.lua` (dealers and call
points) and `config/wagons.lua` (models, prices, storage). Words are in `locales/` (10 languages);
a new wagon or place needs a `wagon_<model>` / `place_<name>` line.

## Commands

- `/wagon` (`Config.CallCommand`): the menu of the dealer / call point you stand at; anywhere with
  `Config.CallAnywhere`.

## Exports (server)

| Export | Returns |
|---|---|
| `GetWagons(src or citizenid)` | list of `{ id, citizenid, model, name, plate, health, out, netId, storage }` |
| `GetWagon(id)`, `GetWagonByPlate(plate)`, `GetWagonByNetId(netId)`, `GetActiveWagon(src or citizenid)` | one of those, or nil |
| `GetStorageId(id or plate)` | `'trunk:<plate>'` |
| `GetModelConfig(model)` | the `config/wagons.lua` entry |
| `Buy(src, model, name)` | `true, id, plate` or `false, err` |
| `Sell(src, id)` | `true, payout` or `false, err` |
| `Rename(src, id, name)` | `true` or `false, err` |
| `TakeOut(src, id, spawn?)` | `true, data` or `false, err` (the owner's game is told to make it only through the menu; scripts send `MULTIwagons:client:spawn` with `data`) |
| `Store(src, id?, health?)`, `PutAway(id, health?, reason?)` | `true` or `false, err` |
| `Repair(src, id, 'dealer' or 'item')` | `true, fee` or `false, err` |
| `OpenStorage(src, id)` | opens the wagon's storage for src |
| `SellPrice(id)`, `RepairFee(id)` | money |

Exports are server-trusted: they skip the distance checks the menus get. Errors: `no_player`, `busy`,
`unknown_model`, `bad_name`, `limit`, `name_taken`, `no_money`, `no_wagon`, `not_owner`, `is_out`,
`already_out`, `not_out`, `broken`, `not_empty`, `not_damaged`, `no_item`, `error`.

Server events: `MULTIwagons:ready`, `MULTIwagons:bought (src, id, model, plate)`, `MULTIwagons:sold (src, id, model, payout)`,
`MULTIwagons:spawned (src, id, netId)`, `MULTIwagons:stored (src, id, reason)`.
A wagon that is out carries the state bag `multiwagon = { id, plate, owner, model, name }`.

Client exports: `GetMyWagon()`, `OpenMenu()`.

## rsg-wagons scripts

| Call | What MULTIwagons does |
|---|---|
| table `rsg_wagons` | same shape; `custom.name` is the name |
| callback `rsg-wagons:checkMyWagons` | `models[], customs[]` of the caller's wagons |
| callback `rsg-wagons:isWagonRegistered (netId)` | `true, isOwner, id, model, netId` for a wagon that is out, else `false` |
| callback `rsg-wagons:getAnimalStorage` | `{}` (no carcass storage) |
| event `rsg-wagons:getWagonDataByCitizenID` | sends `rsg-wagons:receiveWagonData (model, custom, animals, id)` for the wagon that is out |
| event `rsg-wagons:openWagonStash (stash, model, id, netId)` | opens that wagon's storage (same checks as the prompt) |
| event `rsg-wagons:saveWagonToDatabase (model, custom)` | buys at the dealer the player stands at |
| event `rsg-wagons:sellWagon (model, custom)` | sells at the dealer the player stands at |
| event `rsg-wagons:toggleWagonActive (model, custom)` | takes that wagon out at the nearest dealer / call point |
| event `rsg-wagons:removeWagon (netId)` | puts the caller's wagon away |
| client `rsg-wagons:client:callwagon` | opens "my wagons" at the dealer / call point (or anywhere with CallAnywhere) |
| client `rsg-wagons:client:dellwagon` | puts the own wagon away |

## Self-test

`test/wagons_selftest` (needs `setr multicore_selftest true`): prints `[wagontest] DONE: n passed, m failed`.
