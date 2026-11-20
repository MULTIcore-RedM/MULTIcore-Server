# Credits for MULTIlaw

MULTIlaw is part of MULTIcore and is licensed GPL v3 (see LICENSE).

Parts of it follow, and in places reuse, code and data from the RSG v2 framework (GPL v3), by **RSG / Rexshack-RedM** and contributors:

- **rsg-lawman** (https://github.com/Rexshack-RedM/rsg-lawman): the handcuff controls list and natives (`SetEnableHandcuffs`, `DisablePlayerFiring`, `SetPedCanPlayGestureAnims`, `DisplayRadar`), the escort attach (bone 11816, offset 0.45 / 0.45), the law alert blips (styles, sprites, pulse modifier, GPS route), the law badge shop items, the law office coordinates and every event / callback name and argument shape answered in `server/compat.lua` and `client/compat.lua`.
- **rsg-prison** (https://github.com/Rexshack-RedM/rsg-prison): the Sisika coordinates (spawns, release point, centre, menu point), the Sisika uniform shop items, and the event names answered in the compat files.
- **rsg-adminmenu**: the town jail cell door positions used as cell spots (`config/places.lua`) and the bounty poster blip name.
- **rsg-essentials**: the hands-up animation dictionary and clip.

Files with reused parts say so in their header comment. No VORP code was used.
