# MULTIhouses

Houses for MULTIcore. GPL v3 (see `LICENSE`).
MULTIcore was founded and created by RINGO (RINGOscripting).

- **50 houses** across the map, each with a map blip. Houses for sale show as "For sale: House N", owned ones as
  "<owner>'s house".
- **Buying:** hold **Left Alt** (MULTItarget) at the house point and pick **View the house**. You pay a deposit
  (`Config.DepositPercent`, 20% by default) in cash; the rest is the **balance**, paid off later. One house per
  character (`Config.MaxHousesPerPlayer`).
- **The house menu** (black and white MULTIcore page): guests, property tax credit, pay the balance, storage,
  outfits, telegrams, sell, give up the house. While a balance is owed only pay, sell and give up are offered.
- **Guest keys:** give a key to another character by citizen ID, take it back at any time. Guests can open the
  storage, change outfits and lock or unlock the doors.
- **Storage:** one MULTIinventory stash per house (`stash:house_<houseid>`), 48 slots and 4000 kg by default.
- **Outfits:** opens MULTItailor's outfit list (it also gives the wardrobe pass there).
- **Doors:** hold Left Alt at a door and pick **Lock / unlock** (key holders only). Doors are locked while a house
  is owned and open while it is for sale; after a restart the doors of owned houses are locked.
- **Land tax** (off by default, `Config.BillingEnabled`): every cycle takes `Config.LandTaxPerCycle` from the
  house's credit. Low credit sends a warning telegram; no credit takes the house back.
- **Balance:** a reminder telegram goes out every `Config.BalanceReminderInterval`. When `Config.BalanceGracePeriod`
  (30 days) has passed since buying and the balance is not paid, the house is taken back.
- **Break-ins:** with a `lockpick`, hold Left Alt at a locked door of a house you hold no key to and pick
  **Pick the lock**: a progress bar, then an ox_lib skill check. The lockpick can break; it is used up on success.
  The door then stays open for `Config.Robbery.RobberyMinutes` and **Search the storage** appears at the house point.
  Cooldowns per house and per player. Optional MULTIlaw alert.
- 10 languages, nothing drawn in the world (no markers, no floating text, no dots).

Every action is checked on the server: the player exists, owns or holds a key for the house, stands near the house
point or the door, and has the money. Prices and payouts are worked out on the server; amounts typed on the page are
only taken after they pass the checks (whole numbers, above 0, never more than owed or held).

## Setup
1. Put `MULTIhouses` in `resources/[multicore]`.
2. `server.cfg`, after MULTItarget, MULTIcore, MULTIinventory, MULTItailor and MULTItelegram:
   ```
   ensure MULTIhouses
   ```
3. The tables `multi_houses`, `multi_housekeys` and `multi_housedoors` are made on start. The 51 houses with their
   prices and the door hashes are added while the tables are empty (`sql/multihouses.sql` has the same for a manual
   install). A house or door added to `config.lua` later gets its row on the next start. Prices live in
   `multi_houses.price`.
4. The `lockpick` item is added to MULTIinventory's item list at start when it is missing
   (`Config.Robbery.RegisterItem`). Put a `lockpick.png` in MULTIimages' `images` folder if you have none.
5. Optional: `setr multicore_locale de` picks the language for all MULTI scripts (`Config.Locale` for this one only).
6. `/removehouse` and releasing any house need the `admin` permission (`Config.AdminPermission`), for example
   `add_ace group.admin admin allow`.

Uses when running: MULTItailor (outfits), MULTItelegram (telegram button and the tax / balance telegrams),
MULTIjobs (only if you add a tax office button to the page), MULTIlaw (`Config.Robbery.PoliceAlert`),
MULTIserver (logs, `Config.LogName`).

## Commands
| Command | Who | What it does |
|---|---|---|
| `/releasehouse <number>` | owner | gives up your house for nothing, e.g. `/releasehouse 10` |
| `/removehouse [houseid]` | admin | takes a house from its owner (asks for the id when left out) |
| `/endrob` | everyone | ends your own break-in and locks the door again |
| `/fixnui` | everyone | closes the house page if it got stuck |

Names in `Config.Commands` (`''` = off).

## Config (`config.lua`)
| Option | Default | What it does |
|---|---|---|
| `Locale` | `''` | language for this script; empty = `multicore_locale`, else English |
| `Debug` | `false` | extra prints |
| `Currency` | `'cash'` | money type paid and received |
| `MaxHousesPerPlayer` | `1` | houses one character may own |
| `DepositPercent` | `20` | share of the price paid when buying |
| `SellBack` | `0.8` | selling pays this share of the price, minus any balance owed |
| `BalanceGracePeriod` | `2592000` | seconds after buying before an unpaid balance takes the house back |
| `BalanceReminderInterval` | `86400000` | ms between balance reminder telegrams |
| `BillingEnabled` | `false` | land tax on or off |
| `BillingCycle` | `360` | hours between tax cycles |
| `LandTaxPerCycle` | `5` | credit taken per house per cycle |
| `StartCredit` | `10` | credit a house starts with |
| `CreditWarning` | `5` | warning telegram when credit < `LandTaxPerCycle` x this |
| `MaxCredit` | `100000` | most credit one house may hold |
| `StorageMaxWeight` | `4000000` | stash weight in grams (4000 kg) |
| `StorageMaxSlots` | `48` | stash slots |
| `PurgeStorage` | `false` | empty the stash when a house is sold, given up or taken back |
| `ShowBlips` | `true` | house blips on or off |
| `OwnedHouseBlips` | `false` | only houses you hold a key to get a blip |
| `BlipStyle`, `BlipForSale`, `BlipOwned`, `BlipScaleForSale`, `BlipScaleOwned` | | blip look |
| `Interact` | `'auto'` | `'auto'` = MULTItarget when it runs, else hold-key prompts; `'target'`; `'prompt'` |
| `HouseKey` / `DoorKey` | `'G'` / `'ENTER'` | prompt keys (prompt mode only) |
| `TargetRadius` / `TargetDistance` | `1.5` / `2.5` | MULTItarget point size / reach |
| `PromptDistance` | `2.0` | prompt reach (prompt mode) |
| `ServerDistance` | `10.0` | metres from the house point for menu, stash, outfits, buy, sell, pay, credit, guests |
| `DoorDistance` | `6.0` | metres from the door for lock / unlock and lockpicking |
| `DoorRefreshSeconds` | `30` | how often a client asks for all door states |
| `AdminPermission` | `'admin'` | permission for `/removehouse` and releasing any house |
| `Robbery.Enabled` | `true` | break-ins on or off |
| `Robbery.RequireLockpick` / `LockpickItem` | `true` / `'lockpick'` | item needed |
| `Robbery.RegisterItem` / `ItemWeight` | `true` / `50` | add the item when missing / its weight in grams |
| `Robbery.LockpickBreakChance` | `10` | percent chance the lockpick breaks on an attempt |
| `Robbery.UseUpOnSuccess` | `true` | a picked lock uses up the lockpick |
| `Robbery.PickSeconds` | `30` | progress bar length (the server refuses answers much faster than this) |
| `Robbery.SkillCheck` / `SkillKeys` | `{ 'easy' }` / `{ 'w' }` | ox_lib skill check |
| `Robbery.CooldownPerHouse` / `GlobalCooldown` | `30` / `5` | minutes per house / per player |
| `Robbery.OnlyRobOwnedHouses` | `false` | only owned houses can be broken into |
| `Robbery.RobberyMinutes` | `5` | the door stays open this long |
| `Robbery.LeaveDistance` | `50.0` | walking farther ends the break-in |
| `Robbery.PoliceAlert` | `false` | MULTIlaw alert on every attempt |
| `Commands` | | command names |
| `LogName` | `'houses'` | MULTIserver log name (`''` = no logs) |
| `Houses` | 50 houses | `houseid`, `menucoords` (house point), `blipcoords`, `showblip`, optional `label` |
| `HouseDoors` | 87 doors | `houseid`, `doorid` (game door hash), `doorcoords` |

Text: `locales/<lang>.lua` (en, de, es, fr, it, nl, pl, pt-br, ru, tr). Change the look in `html/custom.css`.

## Exports (server)
- `IsReady()` → true once the tables are set up
- `StashId(houseid)` → MULTIinventory id of the house stash
- `GetHouse(houseid)` → the `multi_houses` row or nil
- `GetHouses(srcOrCitizenid)` → `{ { houseid, key = 'owner' | 'guest' }, ... }`
- `HasKey(srcOrCitizenid, houseid)` → bool
- `IsDoorLocked(doorid)` → bool

Server event fired: `MULTIhouses:ready` once the tables are set up.

## Events (for developers)
Server events (all checked on the server): `MULTIhouses:server:buy`, `sell`, `release`, `adminRemove`, `payBalance`,
`addCredit`, `removeCredit`, `addGuest`, `removeGuest`, `openStorage`, `outfits`, `toggleDoor`, `finishPick`,
`robberyLoot`, `endRobbery`.
ox_lib callbacks `MULTIhouses:server:<name>`: `GetState`, `GetKeys`, `GetDoors`, `GetBuyInfo`, `GetMenu`, `GetGuests`,
`GetMoneyInfo`, `GetSellInfo`, `AddGuest`, `RemoveGuest`, `StartPick`, `CanLockpick`.
Client events: `MULTIhouses:client:owned`, `door`, `doors`, `keysChanged`, `robberyStarted`, `robberyEnded`.

## Self-test
`houses_selftest` (in MULTIcore's `test` folder) runs the server side against pretend players with
`setr multicore_selftest true`. The test hooks (`_TestCall`, `_TestSetCoords` ...) only exist with that setting.

## Licence
GPL-3.0-or-later. See `LICENSE`.
