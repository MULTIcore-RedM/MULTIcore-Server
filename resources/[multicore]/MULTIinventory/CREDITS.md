# Credits for MULTIinventory

MULTIinventory is GPL v3, part of MULTIcore. Parts of it are based on RSG v2 resources by
**Rexshack-RedM, RexShack and their contributors**, who keep their copyright. Each of those
resources ships a GPL v3 `LICENSE` file; the RSG v2 framework's NOTICE.md lists them as LGPL.
Either way they may be reused in a GPL v3 work. MULTIinventory is not affiliated with or
endorsed by the RSG team.

No code from `vorp_inventory` (GPL v2) is used. The VORP face was written from VORP's public
documentation and from how scripts call it.

## rsg-inventory
Original project: https://github.com/Rexshack-RedM/rsg-inventory (RSG v2 fork, commit `6e1019d`)
- Copyright (C) Rexshack-RedM and contributors. Item icons it credits: The Icon Library Project
  (https://github.com/TankieTwitch/FREE-RedM-Image-Library); no images are copied here.

Reused (adapted to MULTIinventory's engine; marked in each file's header):
- `server/core/00_state.lua`: `NormalizeItems` (slot re-keying of saved items).
- `server/core/20_inventory.lua`: the stack shape, the saved shape `[ { name, amount, info, type, slot } ]`
  in `players.inventory` / `inventories.items`, add / remove rules (`Inventory.AddItem` / `RemoveItem`),
  weapon serial pattern, item decay (`CheckItemDecay`, the `decayNN` stash modifier).
- `server/core/30_player.lua`: satchel load / save (`LoadInventory` / `SaveInventory`), the `inventories`
  table shape and stash preload, save on stop.
- `server/core/40_access.lua`: move / split / stack / swap with rollback (`rsg-inventory:server:SetInventoryData`),
  restricted stash prefixes (`HasStashAccess`), search rules for other players.
- `server/core/50_use.lua`: the RSG usable-callback lookup (`Inventory.UseItem`), the weapon use path
  (`rsg-weapons:client:UseWeapon` / `UseThrownWeapon` / `UseEquipment`, `player_weapons` serial insert).
- `server/core/60_drops.lua`: force drop when the satchel is full (`ForceDropItem`), drop expiry.
- `server/core/80_give.lua`: give-to-player checks and rollback (`rsg-inventory:server:giveItem`).
- `server/rsg/face.lua`: every export's argument and return shape (the shop exports are passed on to MULTIstores), Player.Functions item methods
  (`registerPlayerMethods`), the server events.
- From the UI builder (client / html, written fresh): HasItem rules, give animation, isInMelee
  callback, event names.

## rsg-ammo
Original project: https://github.com/Rexshack-RedM/rsg-ammo (commit `c8e0eff`)
- RSG / Rexshack-RedM; adapted from early FRP / VORP ammo logic, rewritten for RSG Core; community translators.
- Reused: the AMMO_* type names, max / refill values and the ammo box -> ammo type table
  (`shared/weapons.lua`, `config.lua` `Config.Ammo.Boxes`); client: thrown ammo needs its weapon on the ped first.

## rsg-weapons
Original project: https://github.com/Rexshack-RedM/rsg-weapons (commit `f461b87`)
- Based on qbr-weapons and qr-weapons; RSG / Rexshack-RedM; community translators.
- Reused: the thrown weapon -> ammo type table (`shared/weapons.lua`); client: give-then-select flow,
  wear from quality.

## rsg-weaponcomp
Original project: https://github.com/Rexshack-RedM/rsg-weaponcomp (commit `9d4541b`)
- Reused (client): component apply order.

## Game data
- Ammo type hashes checked against redm-info `Weapons.cs` (`AmmoType`) and femga `natives.json`.
- Weapon names and groups from MULTIcore's `shared/weapons.lua` (RSGShared.Weapons).
