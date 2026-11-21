# MULTIcoroner

Coroner inquests for MULTIcore. GPL v3.

**Credit:** MULTIcoroner is **phils-coroner by Phil**, renamed and fitted to MULTIcore with Phil's permission. Thank you, Phil.
MULTIcore was founded and created by RINGO (RINGOscripting).

- **Examine the dead.** Hold **Left Alt** (MULTItarget) on a dead player, stranger or animal and pick **Perform inquest**.
- **The inquest form** fills in the place by itself (nearest town, or wilderness). For a dead player it also fills in the character's name. Add the cause of death, the manner of death, your notes and the conclusion, then file it.
- **The ledger:** `/inquests` lists every filed report, newest first. Click one to read it in full, print another copy or delete it.
- **Copies as items:** filing a report gives you an **Inquest Report** (`coroner_report`). Anyone holding a copy can use it to read the report, and it can be handed on like any item. A copy of a deleted report says so.
- Drawn in MULTIcore's black and white look, in 10 languages. Nothing is drawn in the world: no dots or sprites.

## Setup
1. Put `MULTIcoroner` in `resources/[multicore]`.
2. In `server.cfg`, after MULTItarget, MULTIcore and MULTIinventory: `ensure MULTIcoroner`.
3. The table `multicoroner_reports` is made by itself on the first start (a copy is in `sql/multicoroner.sql`).
4. The **coroner** job (Assistant, Deputy Coroner, Coroner) and the **coroner_report** item are in MULTIcore's `shared/jobs.lua` and `shared/items.lua`. Put a picture named `coroner_report.png` in MULTIimages' `images` folder if you want one.
5. Optional: `setr multicore_locale de` picks the language for all MULTI scripts.

## Who may use it
- Players with the **coroner** or **medic** job, and every **law** job (job type `leo`). Change this with `Config.Jobs` and `Config.JobTypes`.
- They must be on duty (`Config.RequireOnDuty`).
- Admins always may: the `admin` ace (MULTIcore's server.cfg gives it to `group.admin`) or `add_ace group.admin multicoroner.admin allow`.

## Commands
| Command | What it does |
|---|---|
| `/inquests` | opens the inquest ledger (name set by `Config.ReportsCommand`) |
| `/coronerdebug` | admins: prints what the script sees to the console (job, duty, bodies near you, report count) |

## Config
Everything is in `config.lua`, one comment per option:

| Setting | Purpose |
|---|---|
| `Config.Locale` | language for this script only |
| `Config.Debug` | prints target, access and SQL checks |
| `Config.Jobs`, `Config.JobTypes` | who may perform inquests and read the ledger |
| `Config.RequireOnDuty` | must be on duty |
| `Config.AdminAce` | ace that always may |
| `Config.TargetDistance` | how close you must be to the body |
| `Config.CorpseZoneRadius`, `Config.CorpseScanDistance` | the small zones put on dead strangers and animals near you |
| `Config.CorpseLifetime` | seconds a body can still be examined (0 = no limit) |
| `Config.Manners` | manner of death choices (their words are in the locales, `manner_<CODE>`) |
| `Config.MaxReports` | reports kept; the oldest are dropped |
| `Config.ReportsCommand` | the ledger command |
| `Config.ReportItem`, `Config.GiveReportItemOnFile` | the copy item and whether filing gives one |
| `Config.LocationTowns`, `Config.LocationTownRadius`, `Config.IncludeCoordsInLocation` | how the place is found |
| `Config.DatabaseTable` | table name |

Change the look in `html/custom.css`.

## Credits
- **Phil**: the original phils-coroner (inquest form, ledger, printed copies, corpse targeting, town detection).
- **RINGO (RINGOscripting)**: founder of MULTIcore; the MULTIcore version.

## Licence
GPL-3.0-or-later. See `LICENSE`.
