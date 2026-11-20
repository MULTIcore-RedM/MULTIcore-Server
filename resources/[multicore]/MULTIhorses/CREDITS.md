# Credits for MULTIhorses

MULTIhorses is GPL v3, part of MULTIcore by RINGO (RINGOscripting). Parts of it are based on an RSG v2 resource by
**Rexshack-RedM, RexShack and their contributors**, who keep their copyright. That resource ships a GPL v3
`LICENSE` file. MULTIhorses is not affiliated with or endorsed by the RSG team.
No VORP code and no code from any paid stable script is used.

## rsg-horses
Original project: https://github.com/Rexshack-RedM/rsg-horses (RSG v2 fork, version 2.3.3)
- Copyright (C) Rexshack-RedM and contributors. License: GPL-3.0.
- Reused:
  - the stable locations, stable hand spots and models (`config/stables.lua`), the stable names (`valentine`, `saintdenis` ...);
  - the `player_horses` table (`installation/setup.sql`; `server/main.lua`, `sql/multihorses.sql`);
  - the item names `hay`, `horsecarrot`, `horseapple` (`config/items.lua`);
  - the spawn sequence for a player horse (config flags, ownership, personality, companion decorator, gender expression,
    blip style) and the feed / stimulant / brush interactions and lantern component (`client/horse.lua`);
  - the rsg-horses event, callback and export names and argument shapes (`server/compat.lua`, `client/compat.lua`);
  - rules: buy-back as a share of the price, delete-then-pay on selling, a transfer fee of base + per metre,
    the bonding level from attribute 7.

## Game data
- Horse and stable hand models checked against femga `peds_list.lua`.
- Natives checked against femga `natives.json`; controls against redm-info `Controls.cs`;
  scenarios (`WORLD_HUMAN_WRITE_NOTEBOOK`, `WORLD_HUMAN_CROUCH_INSPECT`) against redm-info `Scenarios.lua`.
- Saddle, blanket and lantern hashes from femga `tack_catalog.lua` (built from rdr3_discoveries `cloth_hash_names.lua`).
- Values used as rsg-horses uses them, not found in the local game-data files: the stable blip style and texture,
  the horse blip style, the gender expression id, the feed and stimulant interaction types.
