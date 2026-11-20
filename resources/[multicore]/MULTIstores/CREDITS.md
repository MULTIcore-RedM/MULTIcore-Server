# Credits for MULTIstores

MULTIstores is GPL v3, part of MULTIcore. Parts of it are based on RSG v2 resources by
**Rexshack-RedM, RexShack and their contributors**, who keep their copyright. Each of those
resources ships a GPL v3 `LICENSE` file. MULTIstores is not affiliated with or endorsed by the RSG team.
No VORP code and no code from any paid store script is used.

## rsg-shops
Original project: https://github.com/RexShack/rsg-shops (RSG v2 fork, version 2.1.3)
- RSG / Rexshack-RedM and contributors; community testers and translators. License: GPL-3.0.
- Reused: the store locations, clerk models and scenarios of the general stores, gunsmiths and saloons
  (`config/stores.lua`), the store names (`gen-valentine` ...), the `rsg-shops:server:openstore` event and its
  rules (product check, 10 m distance, `armoury` for `leo`, `medic` for `medic` job types; `server/compat.lua`),
  the `armoury` / `prison` / `medic` product lists (`Config.RsgShops`, prices changed to the server's economy).

## rsg-inventory
Original project: https://github.com/Rexshack-RedM/rsg-inventory (RSG v2 fork)
- Copyright (C) Rexshack-RedM and contributors.
- Reused: the shop item shape (`name, price, amount, buyPrice, maxStock, minQuality, restock, info`), the shape of the
  `CreateShop` / `OpenShop` / `DoesShopExist` / `RestockShop` exports, buy and sell rules (stock, refund when the
  satchel refuses, sale price by quality, `maxStock`), persistent stock and restock (`server/main.lua`, `server/compat.lua`).

## rsg-hunting
Original project: https://github.com/Rexshack-RedM/rsg-hunting (RSG v2 fork)
- Reused: butcher locations and clerk spots (`Config.ButcherLocations`), trapper locations and clerk spots
  (`Config.Vendors`), the trapper blip name, and the list of animal parts trappers buy (prices changed).

## rsg-medic
Original project: https://github.com/Rexshack-RedM/rsg-medic (RSG v2 fork)
- Reused: the Valentine doctor's counter location and the doctor blip name.

## Game data
- Clerk models checked against femga `peds_list.lua`; scenarios against redm-info `Scenarios.lua`;
  natives (`TASK_START_SCENARIO_IN_PLACE_HASH`, `_SET_BLIP_NAME`, `_SET_RANDOM_OUTFIT_VARIATION`, `GET_CLOCK_HOURS`)
  against femga `natives.json`.
- Blip texture names are the ones RSG v2 scripts use (rsg-shops, rsg-hunting, rsg-medic, rsg-adminmenu's blip list);
  they are not in the local game-data files.
