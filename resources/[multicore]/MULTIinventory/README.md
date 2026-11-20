# MULTIinventory

The inventory of MULTIcore: a slot and weight satchel with stashes, worn clothing slots, weapons
with a gunbelt for spare ammo, ground drops, hand crafting and a crafting journal. It answers as
**rsg-inventory**, **vorp_inventory** and **redemrp_inventory** at the same time (`provide`), so
scripts written for RSG, VORP and RedEM:RP give, take, check and use the same items from the same
satchel.

Part of MULTIcore by RINGO (RINGOscripting). Licence: GPL-3.0-or-later (see `LICENSE`).

## Install

1. Remove `rsg-inventory`, `vorp_inventory` and `redemrp_inventory` if you have them.
2. `server.cfg`, after MULTIcore and MULTItarget:
   ```
   ensure MULTItarget
   ensure MULTIimages
   ensure MULTIinventory
   ```
   (MULTIstores, MULTItailor and the other MULTI scripts come after it.)
3. The tables are made on start (`sql/install.sql`, applied automatically): `multiinv_*` plus an
   empty VORP-style `items` table, so VORP item install SQL works on a MULTIcore server.
4. Item pictures: put your `.png` files in `MULTIimages/images/`, named as each item's `image`
   field (`bread.png`). None are shipped.

## Moving from the old inventory

On the first start, items saved by the old MULTIinventory (or rsg-inventory) are copied over:
satchels in `players.inventory` and stashes in the `inventories` table. Items keep their slot,
amount and info; weapons keep their serial, parts, condition and loaded rounds; loose rounds and
ammo boxes stay items (use them to fill the gunbelt). Stash ids stay the same (`foo` becomes
`stash:foo`; `trunk:`, `glovebox:` and `custom:` ids are kept), so saddlebags, wagon storage, camp
chests and bank boxes find their items. The old data is not changed. The console prints one
summary line. `Config.MigrateOld = false` turns it off. To run it again, delete the
`old_multiinventory` row from `multiinv_migration` and restart; inventories that already hold
items are skipped.

## Keys and commands

| Key / command | What it does |
|---|---|
| `I` (`Config.Player.openKey`) | open the satchel |
| `1`-`5` | use the hotbar slots |
| `/inventory` | open the satchel (MULTIradial's satchel button uses it) |
| `/closeinv` | close it |
| `/giveitem [id] [item] [amount]` | admin: give a player any item or weapon |

The satchel does not open while another script holds `LocalPlayer.state.inv_busy`, and sets it while open.

## Configuration

| File | What |
|---|---|
| `config.lua` | language, commands, satchel size and keys, item pop-ups, drops, decay, stacking, saving, images, admin |
| `config/weapons.lua` | weapons, gunbelt ammo items (`ammoItems`), throwables, dual wield, cleaning |
| `config/secondary.lua` | stashes, saddlebags, trunks, searching players |
| `config/clothing.lua` | clothing as items and the worn slots |
| `config/rsg.lua` | rsg-inventory behaviour (force drop when full, PlayerData mirror, echo events) |
| `config_handcraft*.lua`, `config_workshop.lua` | hand crafting recipes, crafting journal, work stations |

Language: `setr multicore_locale "de"` in `server.cfg` (de, en, es, fr, it, nl, pl, pt-br, ru, tr).

## Items

- Item definitions come from MULTIcore's item list (`RSGCore.Shared.Items`) and from the `items`
  table; a row in `items` wins over the list for the same name (its weight is in kilograms).
- `exports.MULTIinventory:RegisterItem(def)` adds an item at runtime to both MULTIinventory and
  `RSGCore.Shared.Items`, so every script sees it.
- Unique items never stack; the rest stack when name and metadata match.

## Weapons and the gunbelt

- Every weapon is its own slot with a serial number, condition, parts and loaded rounds.
- Spare ammo lives on the character's **gunbelt**, per ammo type. Ammo boxes and arrow bundles
  (`ammo_box_revolver`, `ammo_arrow` ...) are used to put their rounds on the belt; loose rounds
  (`ammo_revolver`, `ammo_arrow_single` ...) put the whole stack on the belt when used. The list is
  `Config.Weapons.ammoItems`.
- Throwables (dynamite, fire bottles, knives, tomahawks, bolas) are one stack per kind; its number is
  how many you can throw.

## Export API (server)

`exports.MULTIinventory:<Name>(...)`. An inventory id is `player:<charId>` (from `PlayerInv(src)`),
or a stash id such as `stash:<name>`, `trunk:<plate>`, `custom:horse_<id>`, `custom:camp:<citizenid>`,
`custom:safedeposit:<citizenid>:<bank>`. A player's server id works as their satchel id too.

| Function | Returns |
|---|---|
| `IsReady()` | bool |
| `PlayerInv(src)` | `'player:<charId>'` or nil |
| `Get(id)` / `Exists(id)` | inventory view (Get makes an empty stash) / only when it exists |
| `Create(id, { label, slots, maxWeight, coords, reach, acceptWeapons, shared })`, `Configure(id, data)`, `Delete(id)` | view / view / bool. `maxWeight` in grams, `reach` = metres from `coords` within which items may be moved (default 5) |
| `Open(src, id or { id, type, label, slots, maxWeight, coords, reach }, opts?)` | `true` or `false, err` (`in_use` when someone else has it open) |
| `Close(src)`, `OpenPlayer(officer, target)` | - / bool |
| `AddItem(id, name, amount, info?, slot?, reason?)` | `true, nil, slot` or `false, err` |
| `RemoveItem(id, name, amount, slot?, infoMatch?, reason?)` | `true, nil, info` or `false, err` |
| `Count(id, name, infoMatch?)`, `ItemCount(id, { skipWeapons, skipAmmo })` | number |
| `CanAdd(id, name, amount, info?)` | `true` or `false, err` |
| `FindItems(id, name, infoMatch?)` (= `Find`), `GetSlot(id, slot)` | stacks / stack |
| `SetInfo(id, slot, info)` (merge), `ReplaceInfo(id, slot, info)` | bool |
| `Move(src, fromId, fromSlot, toId, toSlot?, amount?)`, `CanAccess(src, id)` | `true` or `false, err` / bool |
| `Use(src, slot)`, `UseByName(src, name, stack?)` | `true` or `false, err` |
| `RegisterUsable(name, fn(src, stack, invId), { builtin = true }?)`, `UnregisterUsable(name, resource?)`, `IsUsable(name)` | a `builtin` use only runs when nothing else handles the item |
| `GetItemDef(name)`, `GetItems()`, `RegisterItem(def)` | definition in rsg-core's shape (weight in grams, `type` `'item'` / `'weapon'`) |
| `ItemBox(src, name, amount, 'add' or 'remove' or 'use')` | item pop-up on the player's screen |
| `WeaponNew(name, info?)` | info for `AddItem(id, weaponName, 1, info)`; the serial is given when it is added |
| `WeaponFindById(id)`, `WeaponFindBySerial(serial)` | `invId, slot, stack` |
| `GetWeaponData(name?)` | `{ [weapon_name] = { name, hash, group, label, ammoTypes, ammoType, thrown, melee, noAmmo, weight (g), clip } }` |
| `GetAmmoData()` | see below |
| `Save(id?, await?)`, `Weight(id)` | bool / grams |
| `GetAmmo(src)`, `AddAmmo(src, type, n)`, `RemoveAmmo(src, type, n)` | gunbelt `{ [AMMO_X] = n }` / `ok, count` |
| `GetCharId(src)` | MULTIcore numeric character id |
| clothing: `CreateClothingItem`, `CreateOutfitBundle`, `EquipClothing`, `UnequipClothing`, `GetWorn`, `ReapplyClothing`, `GetOutfits`, `SaveOutfit`, `WearOutfit`, `RenameOutfit`, `DeleteOutfit` | |

Stack shape: `{ name, amount, info, label, description, weight (grams per unit), type, unique, useable, image, slot, id }`;
a weapon has `info.serie` (serial), `info.components`, `info.quality`.

Inventory view: `{ id, type, kind, label, slots, maxWeight (grams), weight (grams), items = { [slot] = stack }, isOpen, viewers, coords, reach }`.

Errors: `unknown_item`, `bad_amount`, `too_heavy`, `no_space`, `limit`, `not_allowed`, `no_inventory`,
`not_enough`, `no_item`, `in_use`, `too_far`, `no_access`, `no_player`.

`GetAmmoData()`:
```lua
{
  gunbelt = true,
  ammo   = { AMMO_REVOLVER = { name, label, max, item = 'ammo_revolver', refill = 12 }, ... },
  boxes  = { ammo_box_revolver = { ammo = 'AMMO_REVOLVER', rounds = 12 }, ... },  -- one used = rounds on the belt
  rounds = { ammo_revolver = 'AMMO_REVOLVER', ... },                              -- loose rounds: the stack goes on the belt
  items  = { [every item that feeds the belt] = 'AMMO_X' },
}
```

Server events: `MULTIinventory:ready`, `MULTIinventory:opened (src, id)`, `MULTIinventory:closed (src, id)`,
`MULTIinventory:used (src, name, slot)`, `MULTIinventory:itemAdded / itemRemoved (id, name, count, meta, reason, ownerSrc)`,
`MULTIinventory:clothingChanged`.

Client: `exports.MULTIinventory:GetItemCount(name)`, `GetImagePaths()`, `GetItems()`, `IsOpen()`, `Open()`, `Close()`,
`ReapplyClothing`, `PreviewClothing`, `ClearPreview`; event `MULTIinventory:client:itembox (def, amount, kind)`.

## RSG scripts (rsg-inventory)

`exports['rsg-inventory']:` `AddItem` (a full satchel drops the item on the ground and returns `true, 'dropped'`),
`RemoveItem`, `HasItem`, `GetItemCount`, `CanAddItem` (`false, 'weight'|'slots'`), `GetFreeWeight`, `GetSlots`,
`GetItemBySlot`, `GetItemByName`, `GetItemsByName`, `GetItemWeight`, `GetTotalWeight`, `GetSlotsByItem`,
`GetFirstSlotByItem`, `SetItemData`, `SetInventory`, `ClearInventory`, `UseItem`, `CreateUseableItem`,
`LoadInventory`, `SaveInventory`, `OpenInventory`, `OpenInventoryById`, `CloseInventory`, `CreateInventory`,
`RegisterStash`, `DeleteInventory`, `RemoveInventory`, `GetInventory`, `GetStashItems`, `ClearStash`,
`SaveStash`, `ForceDropItem`. Shop exports (`CreateShop`, `OpenShop`, `DoesShopExist`, `RestockShop`) are passed
on to MULTIstores. A stash name `x` is the inventory `stash:x`.

`Player.Functions.AddItem / RemoveItem / GetItemByName / GetItemsByName / GetItemBySlot / ClearInventory / SetInventory`,
and `Player.PlayerData.items` mirrors the satchel. Client: `HasItem`, `GetItemCount`, `GetPlayerItems`, `IsOpen`,
`OpenInventory`, `CloseInventory`, `ItemBox`; events `rsg-inventory:client:ItemBox`, `closeInv`, `giveAnim`.

## VORP scripts (vorp_inventory)

Items, weapons, ammo (the gunbelt), custom inventories and permissions, with an optional callback on every
export: `addItem`, `subItem`, `subItemById` / `subItemID`, `getItem`, `getItemByName`, `getItemById` /
`getItemByMainId`, `getItemContainingMetadata`, `getItemMatchingMetadata`, `getItemCount`, `getItemDB`,
`getUserInventoryItems` / `getUserInventory`, `canCarryItem(s)`, `setItemMetadata`, `registerUsableItem`,
`createWeapon`, `giveWeapon`, `subWeapon`, `deleteWeapon`, `getUserInventoryWeapons` / `getUserWeapons`,
`getUserWeapon` / `getWeapon`, `setWeaponSerialNumber` / `setWeaponSerial`, the component and ammo exports,
`registerInventory` and the custom inventory exports, `vorp_inventoryApi()` and the `vorpCore:*` events.
Client: `closeInventory`, `getInventoryItems`, `getInventoryItem`, `getServerItem`.

## RedEM:RP scripts (redemrp_inventory)

`TriggerEvent('redemrp_inventory:getData', function(Inv) ... end)` with `getItem(src, name, meta)`
(`ItemAmount`, `AddItem`, `RemoveItem`, `ChangeMeta`, `getAllItemOfName`), `getItemData`, `getPlayerInventory`,
`removePlayerInventory`; `exports.redemrp_inventory:GetItemsList()`, `GetStashWeight(id)`; client event
`redemrp_inventory:OpenStash(id, kg)`. A usable item nothing else handles fires `RegisterUsableItem:<name>`.

## Credits

Weapon and ammo data use public RedM game names; native references from the RedM community (femga's rdr3 discoveries).
