# Credits for MULTIemotes

MULTIemotes is GPL v3, written for MULTIcore. It uses game facts and code patterns from these projects:

- **RSG v2 rsg-animations** 2.0.2 (GPL v3; XakraD, original creator; RSG / Rexshack-RedM, adaptation and maintenance; community contributors), https://github.com/Rexshack-RedM/rsg-animations:
  - every kit emote name in `config/emotes.lua` is one rsg-animations uses (and each was checked against the game's emote list);
  - the animation dictionary + clip pairs in `config/emotes.lua` (campfire sit, lie down, ledger, knock, fidget, lean on a fence);
  - the emote call (`TASK_PLAY_EMOTE_WITH_HASH`, full and upper body) and the `TaskPlayAnim` argument pattern in `client/main.lua`;
  - the export `PlayAnimation(name, body)` and the event names answered in `client/compat.lua` and `server/compat.lua`.
- **RSG v2 rsg-radialmenu** (GPL v3, RSG / Rexshack-RedM; radial menu originally based on work by zfbx), https://github.com/Rexshack-RedM/rsg-radialmenu:
  - the walk style ids and their archetype / motion pairs marked `rsg` in `config/walkstyles.lua`;
  - the way walk styles are kept (metadata key `walkstyle`, the `walkstyle` state bag) and applied on every client (`client/walk.lua`).
- **femga, rdr3_discoveries** (https://github.com/femga/rdr3_discoveries), `natives.json`: the emote, scenario and locomotion natives, and the archetype names marked `game` in `config/walkstyles.lua`.
- **RedM-info** (scenario and animation dictionary lists; scenario data credited there to PichotM): `Scenarios.lua`, `animations.lua` and `emotes.lua`, against which every name was checked.
