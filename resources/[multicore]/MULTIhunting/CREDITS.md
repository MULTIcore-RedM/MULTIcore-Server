# Credits for MULTIhunting

MULTIhunting is GPL v3, part of MULTIcore. Parts of it are based on an RSG v2 resource by
**Rexshack-RedM, RexShack and their contributors**, who keep their copyright. That resource ships under GPL v3.
MULTIhunting is not affiliated with or endorsed by the RSG team. No VORP code and no code from any paid script is used.

## rsg-hunting
Original project: https://github.com/Rexshack-RedM/rsg-hunting (RSG v2 fork, version 2.0.2)
- Copyright (C) Rexshack-RedM, RexShack and contributors. License: GPL-3.0.
- Reused:
  - how skinning is detected: the loot-complete event `1376140891`, read with `GET_EVENT_DATA` through a small
    JavaScript helper (`client/events.js`, based on `DataViewNativeGetEventData`), the field layout
    (looting ped, looted entity, finished flag) and removing what the game puts in the player's hands
    (`_GET_FIRST_ENTITY_PED_IS_CARRYING`) (`client/main.lua`);
  - the reward rules: only configured items, a short per-player cooldown, room checked before giving (`server/main.lua`);
  - the animal list: which model gives which skin, pelt, hide and parts (`config/animals.lua`; meat amounts, quality
    grades and the per-grade layout are MULTIcore's own).

## Game data
- Animal models checked against femga `peds_list.lua`.
- Natives checked against femga `natives.json`: `_GET_PED_QUALITY`, `_GET_PED_DAMAGE_CLEANLINESS`,
  `_GET_FIRST_ENTITY_PED_IS_CARRYING`, `_GET_IS_CARRIABLE_PELT`, `_GET_CARCASS_FROM_PELT`, `GET_EVENT_DATA`,
  `GET_NUMBER_OF_EVENTS`, `GET_EVENT_AT_INDEX`, `NETWORK_GET_ENTITY_IS_NETWORKED`.
