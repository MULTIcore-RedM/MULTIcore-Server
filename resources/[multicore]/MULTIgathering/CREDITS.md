# Credits for MULTIgathering

MULTIgathering is GPL v3, part of MULTIcore. Parts of it are based on RSG v2 resources by
**Rexshack-RedM, RexShack and their contributors**, who keep their copyright. Those resources ship under GPL v3.
MULTIgathering is not affiliated with or endorsed by the RSG team. No VORP code and no code from any paid script is used.

## rsg-fishing
Original project: https://github.com/Rexshack-RedM/rsg-fishing (RSG v2 fork, version 2.0.6)
- Copyright (C) Rexshack-RedM, RexShack and contributors. License: GPL-3.0. rsg-fishing itself credits
  FRP_Framework (https://github.com/Faroeste-Roleplay/frp-lua-rdr3) and VORP's vorp_fishing-lua for parts of its
  minigame; those parts reach MULTIgathering only through rsg-fishing's GPL v3 code.
- Reused:
  - reading and writing the game's fishing task data through a small JavaScript helper
    (`client/fishing.js`, based on `GET_TASK_FISHING_DATA_EXTRA` / `SET_TASK_FISHING_DATA_EXTRA`);
  - the minigame steps: putting the bait on the rod, drawing fish to the hook, hooking, reeling with struggles,
    keep or throw back, removing a fish from the hands (`client/fishing.lua`);
  - the server rules: one fish per used bait, a short cooldown, known fish models only, the weight kept in range
    (`server/fishing.lua`);
  - which bait draws which fish (`config/fish.lua`, `Config.BaitFish`) and the weight classes.

## rsg-herbalist
Original project: https://github.com/Rexshack-RedM/rsg-herbalist (RSG v2 fork, version 2.0.5)
- Copyright (C) Rexshack-RedM, RexShack and contributors. License: GPL-3.0.
- Reused:
  - the herb spots: `config/herb_spots.lua` is rsg-herbalist's `shared/zones_data.lua` with the table renamed;
  - which plant gives which herb item (`config/herbs.lua`);
  - putting the game's herb plants into the world and the pick-up detection (`client/herbs.js`, based on
    `NativeCreateComposite`; `client/herbs.lua`: streaming, the pick-up controls, the gathering scenario);
  - the server rules: the client only names a spot, the server knows the plant, checks distance and cooldown and lets
    the plant regrow (`server/herbs.lua`).

## rsg-lumberjack
Original project: https://github.com/Rexshack-RedM/rsg-lumberjack (RSG v2 fork)
- Copyright (C) Rexshack-RedM, RexShack and contributors. License: GPL-3.0.
- Reused:
  - the secure two-step work flow (the server authorises a job and later checks it was finished) used for mining,
    lumber and panning (`server/work.lua`);
  - the chop animation and the axe in the hand (`config.lua`, `Config.Lumber.Anim` / `Prop`);
  - the tree model list for ox_target (`config/lumber.lua`, `Config.TreeModels`, a subset);
  - the lumber zone centres (its log sale points, `config/lumber.lua`).

## rsg-goldclaim
Original project: https://github.com/Rexshack-RedM/rsg-goldclaim (RSG v2 fork)
- Read for game facts only: the nugget item names (`smallnugget`, `mediumnugget`, `largenugget`) and the
  `blip_gold` blip name. No code is reused. It has no mining spots.

## Game data
- Fish models checked against femga `peds_list.lua`; tree models and `p_miningpan01x` against redm-info `objects.lua`;
  scenarios `WORLD_HUMAN_PICKAXE_WALL` and `WORLD_HUMAN_CROUCH_INSPECT` against redm-info `Scenarios.lua`.
- Natives checked against femga `natives.json`: `_GET_TASK_FISHING`, `_SET_TASK_FISHING`, `_SET_FISHING_BAIT`,
  `TASK_SWAP_FISHING_BAIT`, `_PED_FISHINGROD_HOOK_ENTITY`, `_GET_ENTITIES_NEAR_POINT`, `_GET_PED_CURRENT_HELD_WEAPON`,
  `_GET_FIRST_ENTITY_PED_IS_CARRYING`, `_GET_WATER_MAP_ZONE_AT_COORDS`, `IS_ENTITY_IN_WATER`, `IS_PED_SWIMMING`,
  `_CREATE_HERB_COMPOSITES`, `_REQUEST_HERB_COMPOSITE_ASSET`, `ARE_COMPOSITE_LOOTABLE_ENTITY_DEF_ASSETS_LOADED`,
  `_DELETE_PATCH_OBJECTS_FROM_HERB_COMPOSITES`, `DISABLE_LOOTING_COMPOSITE_LOOTABLE_THIS_FRAME`,
  `TASK_START_SCENARIO_IN_PLACE_HASH`, `_UI_PROMPT_SET_ACTIVE_GROUP_THIS_FRAME`.
