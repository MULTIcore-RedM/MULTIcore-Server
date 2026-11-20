# MULTImedic

Death, respawn and medics for MULTIcore. GPL v3. Stands in for **rsg-medic** (`provide 'rsg-medic'`).

- **Death screen** in the game's own style: black fade, "You are unconscious", a countdown, then "Hold E to respawn". A "Call for a doctor" button (key G) sends a call with a map blip and GPS route to every medic on duty, and shows how many doctors are on duty.
- **The player stays down.** cfx spawnmanager's auto respawn is turned off (if it runs). Death is set **server-side**: metadata `isdead`, state bag `isDead` (pma-voice and others read it).
- **Respawn** at the nearest doctor, with a doctor's fee (cash, then bank), optional loss of cash / blood money / weapons in hand, and needs refilled through MULTIhud.
- **Medic revive and treatment** with an animation (scenario `WORLD_HUMAN_CROUCH_INSPECT`), through MULTItarget on players or the `/medrevive` and `/medtreat` commands. The server checks the job, duty, distance (OneSync), the patient's state and how long the action took.
- **Admins:** MULTIadmin's revive / heal already go through MULTIcore's core revive; MULTImedic hears them and clears the death state. `/revive [id]`, `/heal [id]`, `/kill id` as rsg-medic had them.
- **Logging out while dead** brings the player back down on the next login.
- **Simple injuries** (off by default): big hits can hurt a body part; a hurt leg means walking only, a bleeding part costs health now and then. Medics' treatment, respawn and revive heal them.

## Setup
1. Put `MULTImedic` in `resources/[multicore]`.
2. In `server.cfg`, after MULTIcore and MULTIhud: `ensure MULTImedic`.
3. Do **not** run `rsg-medic` as well; MULTImedic takes its place.
4. Recommended: MULTItarget ("Revive" / "Treat wounds" on players for medics, Left Alt). MULTImedic waits for MULTItarget at start and adds them again if MULTItarget is restarted. `/mcinteract` (MULTIcore) prints them to the server console.
5. Optional: `setr multicore_locale de` picks the language for all MULTI scripts.

## Config
Everything is in `config.lua`, one comment per option:
- `Config.MedicJobs`, `Config.RequireOnDuty`, `Config.AdminPermissions`, `Config.ServerDistanceCheck`
- `Config.RespawnTimer`, `Config.HoldSeconds`, keys, `Config.KeepDeadOnRelog`, `Config.Screen` (mouse cursor, fee, doctor count)
- `Config.Call`: cooldown, blip time and look, GPS route
- `Config.Respawn`: fee, losses, health after respawn, needs reset, hospital list
- `Config.Revive`, `Config.Treat`, `Config.Target`: times, health, distance, commands
- `Config.Commands`: admin command names and permission
- `Config.Compat`: whether rsg-medic client revive events from other scripts are trusted, death log
- `Config.Injuries`: on/off, chances, limp, bleeding

Text is in `locales/<lang>.lua` (en, de, fr, es, pt-br, it, pl, ru, nl, tr). Extra styling goes in `html/custom.css`.

## Items
Items go through MULTIinventory:
- Medics use up a first aid kit per revive and a bandage per treatment (`Config.Revive.Item` / `Config.Treat.Item`; set `RequireItem = false` to need none). Doctor stores sell both.
- Bandage, field bandage and first aid can be used on yourself from the satchel (`Config.SelfCare`): health back and the worst wounds get better. The item is only used up when the bandaging finishes.
- `Config.Respawn.LoseItems = true` empties the satchel on respawn, except `Config.Respawn.KeepItems`.
- Medic supplies are sold by MULTIstores (the doctor stores).

## Commands
- `/revive [id]`, `/heal [id]`, `/kill id` (admin; names in `Config.Commands`)
- `/medrevive`: revive the nearest downed player (medic)
- `/medtreat`: treat the nearest player (medic)

## Exports
Server:
- `exports.MULTImedic:IsDead(src)`
- `exports.MULTImedic:Revive(src, healthPercent)` / `Heal(src)` / `Kill(src)`
- `exports.MULTImedic:IsMedic(src)`, `GetMedicCount()`
- `exports.MULTImedic:AlertMedics(vector3, text)` returns how many medics got it
- `exports.MULTImedic:GetInjuries(src)`, `ResetInjuries(src)`

Client:
- `exports.MULTImedic:IsDead()`

`exports['rsg-medic']:IsDead()` answers too (client and server).

## Events
Fired by MULTImedic for other scripts:
- server: `MULTImedic:server:onDeath (src, killerId, cause)`, `MULTImedic:server:onRevive (src)`, `MULTImedic:server:onMedicRevive (medicSrc, patientSrc)`
- client: `MULTImedic:client:onDeath (killerId, cause)`, `MULTImedic:client:onRevive`

VORP's `vorp_core:Client:OnPlayerDeath`, `OnPlayerRevive`, `OnPlayerRespawn` come from MULTIcore (MULTImedic uses the core's revive). When MULTImedic moves the player to the doctor itself (`Config.Respawn.UseCoreRespawn = false`), it fires `vorp_core:Client:OnPlayerRespawn` and `vorp_core:Server:OnPlayerRespawn` once, as the core's respawn would.

`vorp_core:Client:AddTimeToRespawn (seconds)` (a client event VORP scripts send to a downed player, for example when a doctor takes the call) adds those seconds to the respawn timer of the current death, on the screen and in the server check. It only ever makes the wait longer, is ignored while alive, and is capped per death by `Config.Compat.MaxAddRespawnSeconds` (default 900, 0 = no cap).

## rsg-medic compatibility
Server events (other scripts' clients send these):
| Event | Arguments | What MULTImedic does |
|---|---|---|
| `rsg-medic:server:RevivePlayer` | target id | medic revive, full server checks |
| `rsg-medic:server:TreatWounds` | target id | medic treatment, full server checks |
| `rsg-medic:server:healSelfInjury` | none | improves the worst injury one step (injuries on) |
| `rsg-medic:server:resetPlayerInjuries` | none | clears the sender's own injuries (only while alive) |
| `rsg-medic:server:medicAlert` | text | sends the text to medics on duty, at the sender's position (cooldown) |
| `rsg-medic:server:deathactions` | none | fee / losses, once per death, only while dead |
| `rsg-medic:server:applyDeathInjuries` | none | random injuries, once per death, only while dead |
| `rsg-medic:server:recordBodyHit` | part name | counts a hit (injuries on, cooldown) |
| `rsg-medic:server:watchSkeleton`, `unwatchSkeleton`, `openSkeletonAdmin`, `buyMedicItem`, `openstash`, `removeitem` | | accepted and ignored (debug print) |

Callbacks: `rsg-medic:server:getmedics` (medics on duty), `rsg-medic:server:getPlayerInjuries` (own, or a medic's patient).

Client events: `rsg-medic:client:adminRevive`, `playerRevive`, `adminHeal` (sent on to the server, see `Config.Compat.TrustClientRevive`), `revive` (respawn request), `KillPlayer`, `medicAlert (coords, text)`, `RevivePlayer` / `TreatWounds` (nearest player, rsg-radialmenu), `ToggleDuty`, `updateInjuries`. The office menu, supplies, storage, skeleton screen, bandage and death cam events are accepted and ignored.

## Credits
Doctor coordinates, event names and argument shapes come from rsg-medic and the scripts of the RSG v2 framework (GPL v3). No code was copied. No VORP code was used.
