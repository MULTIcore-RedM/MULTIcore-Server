# MULTIjobs

Jobs and gangs for MULTIcore servers: a job centre in every town, several jobs per character, a boss menu, a gang menu and duty. RSG v2 and VORP scripts keep working: MULTIjobs answers as `rsg-bossmenu`, `rsg-gangmenu` and `rsg-multijob`, and keeps VORP's job calls in step.

GPL v3, like MULTIcore.

## What it does

- **Job centre** (town halls / government offices in nine towns): lists the jobs in `Config.PublicJobs` with a description, the ranks and the starting pay. Take a job (grade 0) or quit your active job. Clerk NPC and map blip. Opened with MULTItarget on the counter or the clerk (Left Alt), or a hold-key prompt (J) when MULTItarget is not running.
- **My jobs** (`/jobs`, `/myjobs`, optional key): every job you hold, switch the active one, go off the clock as a civilian, quit a job, clock in / out, see your gang and leave it.
- **Multi-job**: a character holds up to the account's job limit (`users.max_jobs`, MULTIcore `MULTIConfig.Vorp.MaxJobs`, VORP `maxJobsAllowed`). The list is the character's `metadata.vorp.multijobs`, which is also VORP's `character.multiJobs`. Any job set by any script (VORP `setJob`, `/setjob`, an RSG script) joins the list.
- **Boss menu** (boss desk or `/bossmenu`) for players whose grade has `isboss`:
  - staff list, online and offline, with the rank, whether the job is their active one and their duty;
  - hire a player standing next to you;
  - promote / demote / let go;
  - pay per grade within `Config.BossMenu.Pay` (saved in `multijobs_pay`);
  - business funds: balance, deposit, withdraw (MULTIbank account named after the job);
  - duty roster;
  - storage (`boss_<job>` stash, when an inventory answers as rsg-inventory).
- **Gang menu** (`/gangmenu`): bosses recruit, rank, throw out and use gang funds (MULTIbank account `gang_<gang>`); members see their gang.
- **Duty**: duty points at the law offices and the Valentine doctor, `/duty`, an on-duty count export. Players who stand still on duty for `Config.Duty.AfkMinutes` are put off duty (no pay for idling).

Paychecks come from MULTIcore (`RSGConfig.Money.PayCheckTimeOut`). With `RSGConfig.Money.PayCheckSociety = true` in MULTIcore's `config.lua`, wages are taken from the job's MULTIbank account (if that account exists); without money there, nobody is paid.

## Server checks

Every action is checked on the server: the caller is a boss of that job / gang (from the grade's `isboss` in `shared/jobs.lua`, not from the client), the target holds that job / is in that gang, nobody changes their own rank, nobody gives or changes a rank at or above their own (`SameGradeCanManage` to allow the same rank), a hire stands next to the boss, pay is within the limits and below the boss's own rank, money amounts are positive and limited, and the player stands at the job centre / boss desk (OneSync). Spam guard per player. A failed second half of a money move is refunded.

## Setup

1. Put `MULTIjobs` in `resources/[multicore]/`.
2. `server.cfg`, after MULTIcore and MULTIbank, before RSG / VORP scripts:
   ```
   ensure MULTIjobs
   ```
3. Remove `rsg-bossmenu`, `rsg-gangmenu` and `rsg-multijob`: MULTIjobs stands in for them.
4. Needs `oxmysql`, `ox_lib`, `MULTIcore`; MULTIbank for business / gang funds; `MULTItarget` recommended (used automatically when it runs). Tables are created on first start (`player_jobs`, `multijobs_synced`, `multijobs_pay`).

Jobs, grades and pay are in MULTIcore's `shared/jobs.lua`, gangs in `shared/gangs.lua`.

## Config (`config.lua`)

Every option has a comment. The main ones:

| Option | Default | What |
|---|---|---|
| `Locale` | `''` | language; empty = `setr multicore_locale`, else English |
| `Interact` / `PromptKey` / `PromptDistance` | `'auto'` / `'J'` / 2.5 | `'auto'` = MULTItarget when it runs ("Look for work", "Open boss menu", "Clock in / out", "Open gang menu" on the points and the clerk, Left Alt), else hold-key prompts; `'target'`; `'prompt'`. `/mcinteract` (MULTIcore) prints what was placed to the server console |
| `Commands` | jobs, myjobs, bossmenu, gangmenu, duty | command names |
| `MyJobsKey` | `''` | optional key for My jobs (never PageDown) |
| `MultiJob.SwitchCooldownMs` | 3000 | wait between switches |
| `MultiJob.OffDutyOnSwitch` | true | a switched-to job starts off duty |
| `MultiJob.MirrorPlayerJobsTable` | true | keep RSG's `player_jobs` table in step |
| `PublicJobs` | 18 jobs | jobs offered at the job centre (+ description locale key) |
| `JobCentres` | 9 towns | office coords and clerk spot |
| `BossMenu.Anywhere` | false | boss menu only at the boss desk (jobs without a desk: anywhere) |
| `BossMenu.SameGradeCanManage` | false | allow managing staff of the same rank |
| `BossMenu.Pay` | 0 - 6 | pay limits per paycheck, per job overrides |
| `BossPoints`, `DutyPoints`, `GangPoints` | law offices, medic | places |
| `Duty.AfkMinutes` | 15 | idle minutes before being put off duty (0 = off) |
| `Gang.AccountPrefix` | `'gang_'` | MULTIbank account of a gang |

Texts are in `locales/*.lua` (en, de, fr, es, pt-br, it, pl, ru, nl, tr; English is the master). Job descriptions are locale keys (`desc_<job>`). Restyle the page in `html/custom.css`.

## Commands

| Command | Who | What |
|---|---|---|
| `/jobs`, `/myjobs` | everyone | My jobs |
| `/bossmenu` | bosses | boss menu |
| `/gangmenu` | gang members | gang menu |
| `/duty` | everyone with a job | clock in / out |
| `/removejob <id> <job>` | admin | take a job off a player |
| `/removegang <id> <gang>` | admin | take a player out of a gang |

## Exports (server)

```lua
exports.MULTIjobs:GetHeldJobs(src)            -- { [job] = { grade, label } }
exports.MULTIjobs:GetMaxJobs(src)             -- number
exports.MULTIjobs:TakeJob(src, job)           -- { ok, err, msg } (job centre rules)
exports.MULTIjobs:SwitchJob(src, job)         -- { ok, err, msg }
exports.MULTIjobs:QuitJob(src, job)           -- { ok, err, msg }
exports.MULTIjobs:BossAction(src, action, data)  -- 'state' | 'nearby' | 'hire' {target} | 'fire' {cid} | 'setgrade' {cid, grade} | 'setpay' {grade, amount} | 'deposit' {amount} | 'withdraw' {amount}
exports.MULTIjobs:GangAction(src, action, data)  -- same, no 'setpay'
exports.MULTIjobs:SetDuty(src, onOrNil)       -- nil toggles
exports.MULTIjobs:GetDutyCount(job)           -- number on duty
exports.MULTIjobs:GetOnDuty(job)              -- list of server ids
exports.MULTIjobs:GetMembers('job' | 'gang', name)
exports.MULTIjobs:AddJob(idOrCitizenid, job, grade, bypassMax) / RemoveJob(...) / GetJobs(...)
```
Client: `exports.MULTIjobs:Open('centre' | 'myjobs' | 'boss' | 'gang', tab)`.

## RSG compatibility

| Name | Kind | What MULTIjobs does |
|---|---|---|
| `exports['rsg-bossmenu']:GetAccount / AddMoney / RemoveMoney (job, amount)` | export | MULTIbank account named after the job |
| `rsg-bossmenu:server:withdrawMoney / depositMoney (amount)` | server event | boss menu money, same checks |
| `rsg-bossmenu:server:GradeUpdate ({ cid, grade })` | server event | set rank |
| `rsg-bossmenu:server:FireEmployee (cid)` | server event | let go (online or offline; also leaves the held list, like rsg-multijob) |
| `rsg-bossmenu:server:HireEmployee (serverId)` | server event | hire |
| `rsg-bossmenu:server:openinventory (stash)` | server event | `boss_<job>` storage |
| `rsg-bossmenu:server:GetAccount / GetEmployees`, `rsg-bossmenu:getplayers` | RSG callbacks | balance, staff (RSG shape), people nearby |
| `rsg-bossmenu:client:mainmenu / employeelist / HireMenu / SocietyMenu / Stash` | client events | open the boss menu on that tab |
| `exports['rsg-gangmenu']:GetGangAccount / AddGangMoney / RemoveGangMoney (gang, amount)` | export | MULTIbank account `gang_<gang>` |
| `rsg-gangmenu:server:withdrawMoney / depositMoney / GradeUpdate / FireMember / HireMember / openinventory` | server events | gang menu, same checks |
| `rsg-gangmenu:server:GetAccount / GetEmployees`, `rsg-gangmenu:getplayers` | RSG callbacks | as above |
| `rsg-gangmenu:client:mainmenu / commandmenu / employeelist / HireMenu / SocietyMenu / Stash` | client events | open the gang menu |
| `/removegang` | admin command | |
| `exports['rsg-multijob']:AddJob / RemoveJob / GetJobs` | export | the held list (online or offline, same returns: `ok, reason`) |
| `exports['rsg-multijob']:AddJobToPlayer (cid, job, grade)` | export | called by rsg-core's `/setjob` |
| `rsg-multijob:server:changeJob / deleteJob (job)` | server event | switch / quit |
| `rsg-multijob:server:newJob` | server event | re-checks the real active job (the sent job is never trusted) |
| `rsg-multijob:server:myJobs` | ox_lib callback | `{ job, salary, jobLabel, gradeLabel, grade }` list |
| `rsg-multijob:server:checkjobs` | RSG callback | true while below the job limit |
| `rsg-multijob:client:openmenu`, `rsg-multijob:client:refreshJobs` | client events | My jobs |
| `player_jobs` table | SQL | kept in step; rows deleted by other scripts (e.g. rsg-mdt) while a character is offline are taken over at login |
| `/removejob` | admin command | |

VORP: `character.setJob / setJobGrade / setJobLabel / setMultiJob / removeMultiJob / multiJobs / getMultiJobsCount` (MULTIcore's VORP face) work on the same data; `vorp:playerJobChange` and `vorp:playerJobGradeChange` fire for every change made in these menus.

## Credits

- Boss desk coordinates from `rsg-bossmenu`, law office duty points from `rsg-lawman`, the Valentine doctor from `rsg-medic`, and the names / shapes of the rsg-bossmenu, rsg-gangmenu and rsg-multijob calls: RSG v2 framework (GPL v3), by the RSG team.
- Built for MULTIcore, which is built on rsg-core 2.4.1 (GPL v3).

## RedEM:RP (redemrp_bossmenu)

`exports.redemrp_bossmenu:GetJobDuty(src)`, the duty toggle `redemrp_bossmenu:server:ToggleDuty` (same checks as `/duty`) and the client event `redemrp_bossmenu:client:ReceiveJob (job, grade)` on login and every job change.

