# MULTIlaw

Basic law for MULTIcore. GPL v3. Stands in for **rsg-lawman** and **rsg-prison** (`provide` both).

It gives a server the plain tools every law job needs. It is deliberately simple: no MDT, no warrants, no prison jobs, no lockpicks. A premium police script can replace it.

## What it does
- **Who is the law:** MULTIcore jobs of type `leo` (town law: `vallaw`, `rholaw`, `blklaw`, `strlaw`, `stdenlaw`, and `marshal`) and `doj` (`judge`). The tools work only on duty (MULTIjobs' duty points or `/duty`). `Config.Permissions` sets which type may do what (by default the court can jail, fine, post bounties and read records, but not cuff or search).
- **Handcuffs:** the `handcuffs` item (MULTIcore's item list already has it). Use it, `/cuff`, the law menu or MULTItarget to cuff / uncuff the nearest player. Cuffed players walk with their hands bound (the game's own handcuff mode, as rsg-lawman did) and can't fight, aim, run, jump or ride. The state is the server's (`metadata.ishandcuffed`), so RSG scripts that read it keep working; a client can never uncuff itself.
- **Lead (escort):** a cuffed or downed player walks at the lawman's side.
- **Wagon / horse:** put a cuffed player into the nearest wagon (a free seat) or onto the nearest horse, and take him out again.
- **Search:** opens the satchel of a cuffed, downed, hogtied, lassoed or hands-up player (through MULTIinventory's player open; the server checks job, duty, distance and the state).
- **Confiscate:** take items from such a player into the **evidence locker** of the lawman's office (a stash per office, opened at the office).
- **Jail and Sisika:** send a player to a town cell or to Sisika for N minutes. The release time is saved, so **time runs while the player is offline** and survives restarts. The time left shows at the top of the screen. Leaving the cell / prison grounds puts you back (escape off by default). Sisika takes the satchel and gives it back on release, and puts on the prison uniform. Law can let a prisoner go early (`/unjail id`).
- **Fines:** a lawman writes a fine (amount and reason). The player pays now or later (`/fines`), from cash, then bank. The money goes to a MULTIbank account: the officer's job account (`vallaw` ...) or a fixed county account (`Config.Fines.Account`).
- **Wanted posters and bounties:** at a law office the law posts a bounty (person, reward, reason). Everyone reads the posters at the **bounty boards**. When a lawman jails that person, the reward is paid to him from the posting office's account. An office can't promise more than its funds hold. Posters come down after `Config.Bounty.ExpireHours`.
- **Records:** a line per arrest, fine, bounty, confiscation and early release, per character. Law on duty reads them at an office (search by name or citizen id).
- **Law alerts:** `exports.MULTIlaw:Alert(coords, text)` puts a pulsing blip (and a GPS route) on the map of every lawman on duty.
- **Badge:** `/lawbadge` puts the star on the coat (rsg-lawman's).

## Setup
1. Put `MULTIlaw` in `resources/[multicore]`.
2. `server.cfg`, after MULTIcore, MULTIinventory, MULTIbank and MULTIjobs: `ensure MULTIlaw`.
3. Do **not** run `rsg-lawman` or `rsg-prison` as well.
4. Tables are made on start: `multilaw_jail`, `multilaw_fines`, `multilaw_bounties`, `multilaw_records`.
5. Recommended: MULTItarget. With `Config.Interact = 'auto'` (default) offices and boards use MULTItarget spheres when it runs (else hold-key prompts, `Config.PromptDistance` 2.0 m), and `Config.PlayerTarget` adds "Law" (`target_law`) on every player for lawmen. `/mcinteract` (MULTIcore) prints what was placed to the server console.
6. **Check the town cell spots in game** (`config/places.lua`): they are the cell door positions; move each a step into its cell if needed. If a doors script keeps cell doors unlocked, the escape check still holds the prisoner.

## Config
`config.lua`, one comment per option: who is law (`LawTypes`, `RequireOnDuty`, `Permissions`), distances, `Cuff`, `Escort`, `Vehicle`, `Search`, `Evidence`, `Jail`, `Fines`, `Bounty`, `Records`, `Alerts`, `Badge`, `Blips`, `Commands`, `Compat`. Places (offices, boards, cells, Sisika, uniform) in `config/places.lua`.

Text is in `locales/<lang>.lua` (en, de, fr, es, pt-br, it, pl, ru, nl, tr). Extra styling goes in `html/custom.css`.

## Commands
| Command | Who | What |
|---|---|---|
| `/lawmenu` | law | all actions on the nearest player |
| `/cuff`, `/escort`, `/putin`, `/takeout`, `/searchplayer`, `/confiscate`, `/fine` | law | on the nearest player |
| `/jail [id] [minutes] [cell\|prison]` | law | without id: asks for the nearest player |
| `/unjail id` | law, admin, console | early release |
| `/fines` | everyone | your unpaid fines, pay them |
| `/lawbadge` | law | badge on / off |

At a law office (MULTItarget with Left Alt, or hold-key prompt **G** when MULTItarget is not running): records, evidence locker, post a bounty, the bounty board. At a bounty board: the posters.

## Exports (server)
- `Alert(coords, text)` → how many lawmen got it
- `IsLaw(src)`, `IsLawJob(src)`, `GetLawCount()`
- `IsCuffed(src)`, `SetCuffed(src, bool)` (no checks, for scripts), `Cuff(officer, target)`, `Uncuff(officer, target)`, `Search(officer, target)`, `Confiscate(officer, target, slot, amount)`
- `Jail(target, minutes, place ('cell'|'prison'|'auto'), reason, officer?)` (no officer = no law checks), `Release(srcOrCitizenid, by?)`, `IsJailed(srcOrCitizenid)` → bool, seconds left
- `Fine(officer, target, amount, reason)`, `PayFine(src, id)`, `GetFines(citizenid, unpaidOnly)`
- `PostBounty(officer, { target, reward, reason })`, `CancelBounty(officer, id)`, `GetBounties()`
- `AddRecord(citizenid, name, kind, { detail, amount, minutes, officer })`, `GetRecord(citizenid)`, `SearchRecords(query)`

Answers are tables `{ ok, err, msg }`.

Client: `Alert(coords?, text)` (server checks position and cooldown), `IsCuffed()`, `IsJailed()`.

Events fired: server `MULTIlaw:server:cuffed (src, on, by)`, `jailed (src, minutes, place, officer)`, `released (src, citizenid)`, `fined`, `finePaid`, `bountyPosted`, `bountyClaimed`, `alert`; client `MULTIlaw:client:jailStarted`, `jailEnded`.

## RSG compatibility (rsg-lawman, rsg-prison)
| Call | Who uses it | What MULTIlaw does |
|---|---|---|
| server `rsg-lawman:server:lawmanAlert (text, coords?)` | rsg-radialmenu, RINGOradialmenu | alert to law on duty (cooldown; position checked) |
| server `rsg-lawman:server:cuffplayer (id)` | rsg-lawman client | cuff / uncuff with all checks |
| server `rsg-lawman:server:escortplayer (id)` | | lead / let go with all checks |
| server `rsg-lawman:server:jailplayer (id, minutes)` | | jail (cell if short and near, else Sisika) |
| server `rsg-lawman:server:SearchPlayer` | | search the nearest player |
| server `rsg-lawman:server:sethandcuffstatus (bool)` | | `true` taken, `false` ignored while cuffed |
| server `rsg-lawman:server:setescortstatus` | | ignored (server keeps it) |
| server `rsg-lawman:server:storage (job)` | | law storage stash `lawstorage<job>` at an office |
| server `rsg-lawman:server:updateoutlawstatus (amount)` | crime scripts | adds to `players.outlawstatus` (1 .. `Compat.MaxOutlawStep`) |
| callback `rsg-lawman:server:getlaw` | | lawmen (`leo`) on duty |
| client `rsg-lawman:client:cuffplayer`, `escortplayer`, `jailplayer (id?, time?)`, `searchplayer`, `mainmenu`, `openstorage`, `lawbadge`, `ToggleDuty` | rsg-radialmenu | the same action on the nearest player |
| client `rsg-lawman:client:getcuffed (by)` | rsg-adminmenu | toggles cuffs when `by` is an admin |
| client `rsg-lawman:client:sendtojail (time)` | rsg-mdt (after it sets `metadata.injail`) | serves the metadata time as a real sentence |
| client `rsg-lawman:client:lawmanAlert (coords, text)` | | alert blip (law only) |
| server `rsg-prison:server:resetoutlawstatus` | rsg-medic (respawn) | sender's `outlawstatus` = 0 (`Compat.AllowOutlawReset`) |
| server `rsg-prison:server:FreePlayer` | | release only when the time is served |
| server `rsg-prison:server:updateSentance`, `RemovePlayerJob`, `SaveJailItems`, `GiveJailItems`, `CheckRecordStatus` | | ignored: the server keeps time, job and items itself |
| client `rsg-prison:client:Enter (time)` | | as `sendtojail` |
| client `rsg-prison:client:freedom` | rsg-lawman's `/unjail` | asks the server; free only when served |
| client `rsg-prison:client:prisonclothes`, `menu`, `shop`, `telegrammenu`, `rsg-lawman:client:openarmoury` | | ignored (no prison shop / armoury) |

Metadata kept as RSG has it: `ishandcuffed`, `injail` (minutes left), `criminalrecord`.

## Credits
See `CREDITS.md` (rsg-lawman, rsg-prison, rsg-adminmenu, rsg-essentials; RSG v2 framework, GPL v3).
