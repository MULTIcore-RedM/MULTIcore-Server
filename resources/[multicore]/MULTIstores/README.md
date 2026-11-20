# MULTIstores

Stores for MULTIcore servers: general stores, gunsmiths, butchers, trappers, doctors and saloons in the
towns, with their own store screen in the base-game look. Stores are not part of the inventory:
MULTIstores keeps prices and stock, and gives and takes items through MULTIinventory.
It answers as **rsg-shops**, and it is where `exports['rsg-inventory']:CreateShop / OpenShop / DoesShopExist /
RestockShop` end up, so RSG scripts that make or open shops work without changes. Part of MULTIcore, GPL v3
(see `CREDITS.md`).

## Setup
1. Remove `rsg-shops` (MULTIstores `provide`s it).
2. `server.cfg`, after MULTIinventory:
   ```
   ensure MULTIinventory
   ensure MULTIstores
   ```
3. Tables are made on start (`CREATE TABLE IF NOT EXISTS`):
   - `multistores_stock` (`store`, `item`, `stock`): stock that survives a restart;
   - `multistores_restock` (`store`, `restocked_at`): when each store was last restocked, so the restock timer carries on after a restart.
4. Item pictures come from MULTIinventory's `Config.ImagePaths` (or set `Config.ImagePaths` here).

## Stores in the towns
| Type | Towns | What it does |
|---|---|---|
| General store | Valentine, Rhodes, Saint Denis, Blackwater, Strawberry, Armadillo, Tumbleweed, Van Horn, Annesburg | sells food, drink, tobacco (cigarettes, cigars, pipe and pipe tobacco, chewing tobacco), tools, lanterns, camp, fishing and horse care (37 items); buys eggs, milk, flour, wood and fish meat |
| Gunsmith | Valentine, Rhodes, Saint Denis, Tumbleweed, Annesburg | sells every weapon in MULTIinventory's weapon data (65), every ammo box and arrow bundle, the two special throwing-knife rounds and the weapon repair kit |
| Butcher | Valentine, Saint Denis, Rhodes, Annesburg, Tumbleweed, Blackwater, Strawberry, Van Horn | sells raw meat; buys meat, hearts, heads and small game |
| Trapper | Valentine, Tumbleweed, Strawberry, Rhodes, Saint Denis | buys pelts, skins, hides, horns, antlers, claws, teeth, feathers, beaks and small birds (140 items) |
| Doctor | Valentine | sells bandages, field bandages, first aid kits (MULTImedic's items), laudanum and tonics (with the temperance tonic); buys medicinal herbs |
| Saloon | Valentine, Rhodes, La Bastille (Saint Denis), Blackwater, Tumbleweed, Annesburg, Old Light (Van Horn) | sells beer, whiskey, rum, gin, wine, coffee, water, stew, cooked meat and fish, bread |

Coordinates are RSG v2's (rsg-shops, rsg-hunting, rsg-medic). Clerks stand at every store except the doctor (RSG v2
has no clerk spot for it). Blips: `blip_shop_store`, `blip_shop_gunsmith`, `blip_shop_animal_trapper` (butchers and
trappers), `blip_shop_doctor`, `blip_saloon` (the names RSG v2's scripts use).

Only items that exist in MULTIinventory's registry are used. A configured item that does not exist is skipped with a
warning in the server console when the stores are built.

## Using a store
Walk up to the counter and hold Left Alt (MULTItarget): look at the clerk or the counter and pick **Open ...**. When MULTItarget is not running, a hold-**J** prompt shows within `Config.PromptDistance` (2.5 m) of the clerk spot instead (`Config.Interact = 'auto'`, `'target'` or `'prompt'`). `/mcinteract` (MULTIcore) prints how many targets, prompts and clerks were placed to the server console. The store screen is a
black column on the left like the game's store menus: the store's name, your cash, tabs for each kind of goods
and a **Sell** tab when the store buys anything. Each row shows the picture, the name, the stock and the price
(small raised cents). Pick an amount with the arrows; the total turns game red and Buy greys out when you can't
afford it. Keys: Up / Down pick a row, Left / Right change the amount, Tab changes the tab, Enter buys or sells,
Esc closes. Walking away closes the store.

## Rules (all checked on the server)
- The store must be open for that player (opened by the server: the counter, `OpenStore` or a script).
- The player must stand at the counter (`Config.MaxUseDistance`, OneSync). Stores without coords (made by scripts)
  are opened by those scripts, which do their own checks, like rsg-inventory.
- Stock, money (`Config.Currency`, cents allowed) and room in the satchel (`CanAdd`) are checked before anything moves.
  If the satchel refuses the item after the money is taken, the money is given back.
- Weapons are made one by one through `exports.MULTIinventory:WeaponNew`, so each has its own serial and id.
- Selling: only items the store buys, only items that may be removed, at most the stack held, `maxStock` and
  `minQuality` respected; items with `info.quality` pay in proportion (`Config.Sell.QualityScales`).
- Job stores: `jobs = { 'doctor' }` or `jobType = 'leo'`, optional `onDuty = true`.
- Opening hours: `Config.Hours` (off by default) or a store's own `hours`; checked on the client against the game clock.
- No money loops: at start, a warning is printed for any store that pays more than half the lowest price
  the same item is sold for.

## Prices
All prices are **1899-level**, the year the game is set in: RDR2's own store prices where they are known
(Cattleman revolver $50, Schofield $84, Springfield $120, Carcano $190), otherwise historical prices of the late
1890s (a loaf of bread 10c, a glass of beer 5c, a bottle of whiskey $1, a cigar 10c, a box of revolver cartridges $1).
The old economy SPEC is no longer the price source. Change prices in `config/products.lua` and `config/gunsmith.lua`;
the stores never buy anything back for more than half of its lowest sale price.

## Config
- `config.lua`: money, interaction, distance, stock and restock timer, selling, hours, clerks, blips, store types,
  rsg-shops lists. Every option is commented with its default.
- `config/stores.lua`: the stores (name, type, town, counter coords, clerk spot and model, optional hours / jobs).
- `config/products.lua`: what each type sells and buys, in rsg-inventory's item shape
  (`name, price, amount, restock, buyPrice, maxStock, minQuality, category, info`).
- `config/gunsmith.lua`: weapon prices (by name, then by group), ammo box prices, extra items, stock.
- Words: `locales/` (10 languages). Looks: `html/custom.css`.

## Exports (server)
| Export | Returns |
|---|---|
| `CreateStore(def)` | `true` / `false, err`. `def = { name, label, items = {...}, coords?, distance?, persistentStock?, jobs?, jobType?, onDuty? }` |
| `OpenStore(src, name)`, `CloseStore(src)` | `true` / `false, err` (`no_store`, `not_allowed`, `too_far`, `no_player`) |
| `DoesStoreExist(name)` | bool |
| `AddStock(name, item, amount)` | bool (negative takes stock away) |
| `SetPrice(name, item, price?, buyPrice?)` | bool |
| `RestockStore(name, percent?)` | bool |
| `Buy(src, name, index, amount)`, `Sell(src, name, slot, amount)` | `true, nil, { name, label, amount, total }` / `false, err` |
| `GetStore(name)`, `GetStores()`, `IsReady()` | plain copies |
| rsg-inventory shapes: `CreateShop(shopData or list)`, `OpenShop(src, name)`, `DoesShopExist(name)`, `RestockShop(name, percent)` | as rsg-inventory |

Errors: `not_open`, `not_for_sale`, `bad_amount`, `out_of_stock`, `no_money`, `no_space`, `too_heavy`, `limit`,
`not_bought`, `no_item`, `quality_low`, `store_full`, `worthless`, `busy`.

Server events: `MULTIstores:ready`, `MULTIstores:opened / closed (src, store)`,
`MULTIstores:bought / sold (src, store, item, amount, total)`.
Client exports: `IsOpen()`, `Close()`.

## RSG compatibility
| RSG call | Who uses it | What MULTIstores does |
|---|---|---|
| `TriggerServerEvent('rsg-shops:server:openstore', products, name, label)` | rsg-shops' own client, rsg-lawman (`'armoury'`), rsg-prison (`'prison'`) | a town store by rsg-shops' name (`gen-valentine`, `wep-rhodes`, `val-saloon` ...) opens with the usual checks; `armoury`, `prison`, `medic` open the lists in `Config.RsgShops` (job types `leo` / `medic` like rsg-shops) |
| `exports['rsg-inventory']:CreateShop({ name, label, slots, items, coords?, persistentStock? })` | rsg-shops, rsg-horses | MULTIinventory passes it on; a table of shops works too |
| `exports['rsg-inventory']:OpenShop(src, name)` | rsg-shops, rsg-horses | opens the store screen |
| `exports['rsg-inventory']:DoesShopExist(name)` | rsg-shops | bool |
| `exports['rsg-inventory']:RestockShop(name, percent)` | (rsg-inventory export) | restocks |

Not answered: rsg-inventory's vending machines (`rsg-inventory:server:openVending`), which only rsg-inventory's own
client sends.

## Self-test
`test/stores_selftest` (needs `setr multicore_selftest true`): prints `[storetest] DONE: n passed, m failed`.
