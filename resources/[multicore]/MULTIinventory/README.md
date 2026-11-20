# MULTIinventory

One inventory for RSG and VORP scripts side by side. It answers as **rsg-inventory** and as
**vorp_inventory** (`provide` both), so both kinds of script give, take, check and use the same
items from the same satchel. Part of MULTIcore, GPL v3 (see `CREDITS.md`).

## Setup
1. Remove `rsg-inventory`, `vorp_inventory` (and `rsg-ammo` if you want rounds counted by MULTIinventory).
2. `server.cfg`, after MULTIcore and its base scripts:
   ```
   ensure MULTIinventory
   ```
3. Tables are made on start (`CREATE TABLE IF NOT EXISTS`): `inventories`, `items` (VORP's shape),
   `multiinventory_kv`. `sql/multiinventory.sql` holds the same statements if you want to import them yourself.
   The satchel lives in `players.inventory` (RSG's column, from MULTIcore).
4. Item images: put the `nui://` folders of your images in `Config.ImagePaths`. None are shipped.
5. Stores are not part of the inventory: they are their own resource, **MULTIstores** (`ensure MULTIstores` after
   MULTIinventory). See "Stores" below.

## Items
- One registry: `RSGCore.Shared.Items` + VORP's `items` table (+ every weapon and an ammo round item for
  every ammo type, made when missing). Same name in both = one item: RSG's label / image / weight win;
  VORP's `limit`, `can_remove`, `desc`, `usable` are kept. VORP weights are kilograms (`Config.VorpItems.WeightUnit`).
- Items made here or found only in `items` are added to `RSGCore.Shared.Items`, so RSG scripts see them.
- Scripts that `INSERT IGNORE INTO items` at runtime: an unknown name is looked up in the table at once,
  and the table is re-read every `Config.VorpItems.RefreshMinutes`.
- Rules, all on the server: slots, weight (RSG), per-item `limit` (VORP, satchel), `metadata.vorp.invCapacity`
  (VORP item count without weapons and ammo), optional total count (`maxCount`).
- Stacking: unique items never stack; the rest stack when name and info match (`lastUpdate` ignored).

## Weapons and ammo
- Weapons are items with `info = { serie, quality, id, components = {}, ammo?, ammoType? }`. `id` is a
  whole number from a counter kept in the database; `serie` follows rsg-inventory's pattern.
- Thrown weapons (dynamite, molotov, knives, tomahawks, bolas, hatchets, cleaver) stack; the count is the ammo.
- Rounds are items: every AMMO_* type has a one-round item (`ammo_revolver`, `ammo_rifle_express`,
  `ammo_arrow_single` ...). Ammo boxes and RSG's arrow bundles turn into rounds as soon as they reach a
  satchel (`Config.Ammo.BoxesToRounds`; off by itself when rsg-ammo runs), so partly used boxes never exist.
- `def.ammoPer` (rounds per item) and `def.ammotype` are set on every ammo item.
- Shared data for any script: `MULTIInvData.Weapons[name] = { name, hash, group, type, ammoTypes, ammoType, thrown, melee, noAmmo, weight }`,
  `MULTIInvData.Ammo[AMMO_X] = { name, hash, item, max, refill, verified }`, `MULTIInvData.AmmoItems`,
  `MULTIInvData.AmmoBoxes`; server: `exports.MULTIinventory:GetWeaponData(name?)`, `GetAmmoData()`.

## Engine API (server)
Global `MULTIInv` in this resource; every function is also `exports.MULTIinventory:<Name>`.

| Function | Returns |
|---|---|
| `Get(invId)` / `Exists(invId)` | inventory (Get makes an empty stash-type one) / existing only |
| `PlayerInv(src)` | `'player:<citizenid>'` |
| `Create(invId, data)`, `Configure(invId, data)`, `Delete(invId)` | data = `{ label, slots, maxWeight, maxCount, coords, reach, itemLimits, whitelist, blacklist, acceptWeapons, ignoreItemLimits }` (`reach` = metres from `coords` within which items may be moved; default `Config.MaxDistance`) |
| `AddItem(invId, name, amount, info?, slot?, reason?)` | `true, nil, slot` or `false, err` |
| `RemoveItem(invId, name, amount, slot?, infoMatch?, reason?)` | `true, nil, info` or `false, err` |
| `Count(invId, name, infoMatch?)`, `Find(invId, name, infoMatch?)` (= `FindItems`), `GetSlot(invId, slot)` | number / stacks / stack |
| `CanAdd(invId, name, amount, info?)` | `true` or `false, err` |
| `ItemCount(invId, { skipWeapons, skipAmmo })`, `SetCapacity(invId, n)` | VORP invCapacity count / set |
| `SetInfo(invId, slot, info)` (merge), `ReplaceInfo(invId, slot, info)` | bool |
| `Move(src, fromInv, fromSlot, toInv, toSlot?, amount?)` | `true` or `false, err` (the only path the UI uses) |
| `Open(src, invId or spec?, opts?)`, `OpenPlayer(src, targetSrc)`, `Close(src)` | bool |
| `RegisterUsable(name, fn(src, stack, invId), opts?)`, `UnregisterUsable(name, resource?)`, `Use(src, slot)` | bool |
| `Give(src, target, slot, amount)`, `DropFromSlot(src, slot, amount)`, `ForceDrop(src, name, amount, info)` | bool / dropId |
| `RegisterItem(def)`, `GetItemDef(name)`, `GetItems()` | |
| `Save(invId)`, `SaveAll()` | |
| `WeaponNew(name, info?)`, `WeaponFindById(id)`, `WeaponFindBySerial(serial)` | info / invId, slot, stack |
| `TradeRequest(src, target)`, `TradeAnswer(src, from, accept)` | `true` or `false, err` (see Trading) |
| `TradeSetItem(src, satchelSlot, amount)` (0 = take back), `TradeSetCash(src, dollars)`, `TradeAccept(src, state)`, `TradeCancel(src, reasonKey?)` | `true` or `false, err` |
| `InTrade(src)`, `TradeView(src)`, `SlotLocked(inv, slot)` | trade id / what src sees / bool |

Errors: `unknown_item`, `bad_amount`, `too_heavy`, `limit`, `no_space`, `not_allowed`, `no_inventory`,
`not_enough`, `no_access`, `too_far`, `busy`, `locked` (the slot is offered in a trade).

Inventory ids: `player:<citizenid>`, `stash:<name>` (saved as `<name>`, RSG's key), `glovebox:<plate>`,
`trunk:<plate>`, `custom:<name>`, `drop:<n>` (memory only).

Move hooks: an inventory table may carry `canPut(src, name, amount, info)` / `canTake(...)` (return
`false` to refuse) and `onPut` / `onTake` (after the move); called on moves and gives.

Server events: `MULTIinventory:changed (invId, changes)`, `MULTIinventory:ready`, `MULTIinventory:itemsLoaded`,
`MULTIinventory:playerLoaded (src, invId)`, `MULTIinventory:opened / closed (src, invId)`,
`MULTIinventory:used (src, name, slot)`, `MULTIinventory:given (src, target, name, amount)`,
`MULTIinventory:dropCreated / dropRemoved`, `MULTIinventory:tradeStarted (id, a, b)`, `MULTIinventory:tradeDone (id, a, b)`,
`MULTIinventory:tradeCancelled (id, a, b, reasonKey)`.

`Config.ServerOpenOnly` lists inventory id prefixes a client may never ask to open; only a server script opens those.
Defaults: `custom:safedeposit:` (MULTIbank safe-deposit boxes), `custom:camp:` (MULTIcamps chests),
`custom:horse_` (MULTIhorses saddlebags), `stash:multilaw_evidence_`, `stash:multilaw_jailitems_` and
`stash:lawstorage` (MULTIlaw evidence lockers, items kept in jail / Sisika, rsg-lawman law storage) and `trunk:`
(MULTIwagons wagon storage; rsg-wagons and other RSG trunk scripts also open it from the server). If you change
MULTIlaw's stash prefixes, change them here too.

## RSG scripts (rsg-inventory)
`exports['rsg-inventory']:*` with rsg-inventory's shapes: `LoadInventory`, `SaveInventory`, `AddItem`
(full satchel -> item on the ground, returns `true, 'dropped'`), `RemoveItem`, `HasItem`, `GetItemByName`,
`GetItemsByName`, `GetItemBySlot`, `GetItemCount`, `CanAddItem` (`false, 'weight'|'slots'`), `GetFreeWeight`,
`GetTotalWeight`, `GetSlots`, `GetSlotsByItem`, `GetFirstSlotByItem`, `GetItemWeight`, `SetInventory`,
`SetItemData`, `ClearInventory`, `ClearStash`, `SaveStash`, `OpenInventory`, `OpenInventoryById`,
`CloseInventory`, `GetInventory`, `GetStashItems`, `CreateInventory`, `RegisterStash`, `DeleteInventory`,
`RemoveInventory`, `ForceDropItem`, `UseItem`, `CreateUseableItem` / `CreateUsableItem`.
- Shop exports `CreateShop`, `OpenShop`, `DoesShopExist`, `RestockShop` are passed on, with the same arguments, to
  MULTIstores when it is started. Without MULTIstores they print one warning and return `false`.
- `Player.Functions.AddItem / RemoveItem / GetItemBySlot / GetItemByName / GetItemsByName / ClearInventory / SetInventory / HasItem`.
- `Player.PlayerData.items` always mirrors the satchel; a script that writes it with `SetPlayerData('items', ...)` is followed.
- Events: `rsg-inventory:server:useItem`, `rsg-inventory:server:closeInventory`, `rsg-inventory:server:SetInventoryData`,
  `rsg-inventory:server:openPlayerInventory`; callbacks `rsg-inventory:server:giveItem`, `rsg-inventory:server:getPlayerName`;
  fires `rsg-inventory:server:itemRemovedFromPlayerInventory`.
- Stash names are kept as RSG saves them, so an existing `inventories` table carries over.

## VORP scripts (vorp_inventory)
MULTIinventory answers as `vorp_inventory`, so VORP scripts call `exports.vorp_inventory:*` as usual and work on the same satchel RSG scripts use.

- **Items:** addItem, subItem, subItemById, getItem, getItemCount, getItemById, getUserInventoryItems, getItemDB, canCarryItem(s), setItemMetadata, registerUsableItem / unRegisterUsableItem. Every export takes an optional callback and also returns the answer.
- **Weapons** are weapon items that keep the VORP weapon id, serial, loaded rounds, components, custom label and description. createWeapon, giveWeapon, subWeapon, deleteWeapon, getUserInventoryWeapons, getUserWeapon, canCarryWeapons, setWeaponCustomLabel / CustomDesc / SerialNumber and the component exports all work.
- **Ammo** is items in the satchel (ammo_revolver, ammo_rifle_express, ammo_arrow_fire, ...). Thrown weapons (knives, tomahawks, bolas, dynamite, molotovs, poison bottles, hatchets) are their own items, and their count is the ammo. getUserAmmo returns `{ AMMO_X = n }` for every type, variants included. addBullets / subBullets / getWeaponBullets / removeAllUserAmmo map AMMO_* types to these items. Change the mapping with `Config.Vorp.AmmoItems`.
- **Custom inventories:** registerInventory and the rest of the custom inventory exports. A shared one is saved as `custom:<id>`, a per-character one as `custom:<id>:<charIdentifier>`. VORP's `limit` is the inventory's total item count. White lists, black lists, item limits and acceptWeapons apply.
- **Inventory capacity:** each character's VORP capacity (invCapacity, changed with updateInvCapacity) limits how many items can go in the satchel. Weapons and ammo don't count.
- **The old API** works too: `exports.vorp_inventory:vorp_inventoryApi()` and the server events `vorpCore:addItem`, `vorpCore:getItemCount`, ...
- **Client:**
  - exports getInventoryItems, getInventoryItem, getServerItem, closeInventory;
  - the events `vorp_inventory:Client:OnInvStateChange`, `vorp_inventory:onWeaponEquipped`, componentAdded / componentRemoved, `vorp_inventory:blockInventory`;
  - the state bags IsInvActive and `GetEquippedWeaponData_<hash>`.
- **Not yet:** item ids are new after a restart; openPlayerInventory ignores title, blacklist, itemsLimit and timeout.

Settings: `Config.Vorp` in config.lua.

## UI (satchel, hotbar, drops, weapons on the ped)
- **Satchel:** B (the game's satchel key) or `/inventory`. Two black panes in the base-game look: the satchel on the left, and on the right whatever is open — a stash, a drop, storage, a wagon or another player. With nothing open, the right pane is the ground: drag items there to drop them. The Trade button in the satchel title offers a trade to the nearest player (see "Trading between players").
- **Moving:** drag and drop, Shift-click moves the whole stack, double-click or Enter uses. Split, give (nearest player), drop, put away, take. Every move is checked by the server.
- **Hotbar:** keys 1-5 use satchel slots 1-5; Z shows the bar.
- **Item pop-ups** at the bottom when items are added, removed or used.
- **Drops:** a bag on the ground, opened with MULTItarget "Open" (Left Alt) when MULTItarget runs, else with a hold-E prompt (`Config.Drops.UseTarget`). `/mcinteract` (MULTIcore) prints the drop and trade targets / prompts to the server console.
- **Weapons on the ped:**
  - Using a weapon item equips it with its own ammo, ammo type, components and wear.
  - A second sidearm goes on the left hip, a second long arm on the shoulder.
  - Ammo items fill the ped's ammo by type, and using an ammo item loads that type.
  - Thrown weapons count as items.
  - Ammo use is synced to the server.
  - After death, weapons follow MULTImedic's settings and are never duplicated.
- **Pictures:** `Config.ImagePaths` lists `nui://` folders tried in order (e.g. an item image folder already on your server); a plain icon shows when none is found. No images are shipped. Other pages read the same list with the client export `exports.MULTIinventory:GetImagePaths()` (MULTIstores does).
- **Restyle:** `html/custom.css`.

## Trading between players
- **Offering:** `/trade` (the nearest player within `Config.Trade.Distance`) or `/trade <server id>`, the **Trade**
  button on the satchel page, or "Offer a trade" on a player through MULTItarget. The other player answers Yes / No
  in a dialog; an unanswered request runs out after `RequestSeconds`. Two players who ask each other start at once.
- **The trade window** is the satchel page in trade mode: your satchel on the left; on the right your offer, the
  other player's offer and the cash each side puts in (dollars with cents). Drag a stack (or part of it, with Amount)
  from the satchel into your offer, Shift-click or double-click to offer the whole stack, drag it back or press
  Take back to remove it. Up to `MaxItems` stacks and `MaxCash` dollars each.
- **Accepting:** both must accept. Any change by either side clears both accepts, and Accept works again only
  `AcceptDelayMs` after the last change, so nothing can be swapped in at the last second.
- **The swap** happens on the server in one go, or not at all. It checks again that every offered stack is
  still the same stack with enough in it, that both players still hold the cash, that both satchels have room
  (weight, slots, limits) once the outgoing items have left, that the players are alive, free and within
  `KeepDistance`. Any failure undoes everything and both players are told why (for example
  "Trade Beta has no room for everything"). Weapons keep their serial and id.
- **No dupes:** a stack in a pending offer is locked. It cannot be moved, swapped, used, given or dropped
  (`locked`); the satchel shows it dimmed with "In the trade". Walking further apart than `KeepDistance`, dying,
  being cuffed, logging out, leaving, closing the window or opening another inventory cancels the trade and
  unlocks everything.

| `Config.Trade` | Default | What |
|---|---|---|
| `Enabled` | `true` | trading on / off |
| `Command` | `'trade'` | chat command |
| `UseTarget` / `TargetIcon` | `true` / `'fas fa-handshake'` | MULTItarget option on players (added when MULTItarget runs, also if it starts later; reach 2.5 m at most) |
| `SatchelButton` | `true` | Trade button on the satchel page |
| `Distance` / `KeepDistance` | `3.0` / `6.0` | metres to offer / to stay in the trade (also checked at the swap) |
| `RequestSeconds` | `20` | how long a request waits for an answer |
| `MaxItems` / `MaxCash` | `12` / `10000` | stacks and dollars each player may offer |
| `AcceptDelayMs` | `1500` | wait after any change before Accept works |
| `CheckMs` | `1000` | how often walking away / death / leaving is checked |

## Stores
Stores (buying, selling to a store, stock, prices) are their own resource, MULTIstores, with their own screen.
MULTIinventory only gives and takes the items: MULTIstores checks room with `CanAdd`, gives with `AddItem`
(weapons through `WeaponNew`, so each has a serial) and takes with `RemoveItem`. RSG scripts that call
`exports['rsg-inventory']:CreateShop / OpenShop / DoesShopExist / RestockShop` keep working: the calls go on to MULTIstores.

## Config
Everything is in `config.lua`, every option with its default. Words are in `locales/` (10 languages).

## Self-test
`test/inventory_selftest` (needs `setr multicore_selftest true`): prints `[invtest] DONE: n passed, m failed`.
`test/trade_selftest` covers trading (and MULTIbank's safe-deposit boxes): `[tradetest] DONE: n passed, m failed`.
