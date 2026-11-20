# MULTIcore changes to rsg-core 2.4.1

MULTIcore starts from rsg-core 2.4.1 (GPL v3, see CREDITS.md and LICENSE). What changed:

- **Resource name and provides:** the resource is `MULTIcore` and provides both `rsg-core` and `vorp_core`.
- **Export aliases** (`shared/alias.lua`): every export is also registered under `rsg-core`.
- **Character id:** every character has a whole-number id (`players.id`, `PlayerData.id`). A new character's row is written at once to get it (`RSGCore.Player.InsertNew`).
- **Money:**
  - cash, bank, gold and role tokens (`rol`, new) keep cents;
  - money is a number, not an inventory item (`EnableMoneyItems = false`);
  - a currency added to the config later starts at 0 for existing characters.
- **Accounts** (`server/multi/accounts.lua`): a `users` table in the shape VORP scripts expect. The account group is mirrored to an ACE principal.
- **Jobs** (`server/multi/jobs.lua`): a job or grade set by a script that isn't in `shared/jobs.lua` is added on the spot.
- **Appearance** (`server/multi/appearance.lua`): looks are stored in the format of the creator that wrote them.
- **Database tables** (`server/multi/schema.lua`): missing tables are created on start.
- **VORP face** (`server/vorp/`):
  - written from VORP's public API documentation; no VORP code is used;
  - covers `GetCore`, users, characters, currency, jobs, groups, experience, skills, callbacks, notifications and the VORP events.
- **Players without a name** (test players) get a fallback name instead of an error.
- **Test hooks** (`server/multi/testhooks.lua`): only active with `setr multicore_selftest true`.

- **VORP client face** (`client/vorp/`):
  - written from VORP's public API documentation and from how scripts call it; no VORP code is used;
  - `exports.vorp_core:GetCore()` / `ClientRpcCall()` / `DisplayTipRight()` on the client, and the old `getCore` event;
  - every VORP `Notify*` kind and the old `vorp:TipRight`-style client events go through MULTIcore's own notifications (`exports.MULTIcore:Notify`), so VORP scripts look like the rest;
  - `Core.Callback` (TriggerAsync, TriggerAwait, Register) over MULTIcore's own callback events;
  - heal, revive and respawn (nearest town) for `Core.Player.*`, with VORP's `OnPlayerHeal` / `OnPlayerRevive` / `OnPlayerRespawn` / `OnPlayerSpawned` / `OnPlayerDeath` client events;
  - `LocalPlayer.state.Character` is set by the server face (CharId, names, job, group, money, gold, rol, age, gender, nickname, description); client `Core.instancePlayers(n)` handled by the server.
- **Character login API** (`server/multi/login.lua`): list / create / select / delete characters and save looks in MULTIcore's own format; see docs/BASE_SET.md.
- **Language helper** (`shared/i18n.lua`), shared UI theme (`html/theme/multi.css`), creator game data (`data/`).
- **RSG player-loaded events** (`client/multi/loaded.lua`): `RSGCore:Client:OnPlayerLoaded` / `RSGCore:Server:OnPlayerLoaded` fire once per login when the character is in the world (after MULTIcharacter's spawn, `MULTIcore:spawned`, or a fallback timer), as rsg-spawn does on RSG.
- **Inventory checks** use `GetResourceState('rsg-inventory') == 'started'` instead of "not missing", so a present-but-stopped inventory is never called.
- **Prompt reach** (`client/prompts.lua`): `createPrompt(name, coords, key, text, options)` reads an optional `options.distance` (metres) for that prompt; without it `RSGConfig.PromptDistance` is used, as on RSG.
- **World interaction helper** (`lib/interact.lua`, loaded by MULTI scripts as `@MULTIcore/lib/interact.lua`) and the `/mcinteract` command (`client/multi/interact.lua`, `server/multi/interact.lua`), see README "World interactions".
