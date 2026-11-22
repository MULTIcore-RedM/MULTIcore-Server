# MULTIcore Server

**MULTIcore was founded and created by RINGO (RINGOscripting).**

A ready-to-run RedM base server on **MULTIcore**: one core that runs **RSG v2, VORP and RedEM:RP scripts side by side**, with its own full set of base scripts in the game's own look (black panels, white text).

## What you get

- **MULTIcore**: the core. It answers to `rsg-core`, `vorp_core` and `redem_roleplay`, so scripts written for any of the three frameworks find their core and share the same players, money, jobs and items.
- **36 MULTI scripts** (`resources/[multicore]`): login and character select, character creator, inventory, stores, clothing as items with a tailor job, HUD, food and drink, bank, jobs, medic, coroner inquests, admin, camps, crafting, doors, emotes, gathering, horses, houses, hunting, law, telegrams, wagons, vendors who buy your goods, a radial menu, Discord logs and whitelist, its own **target system** (MULTItarget), its own **chat** (MULTIchat), **proximity voice** (MULTIvoice), **one clock and weather for everyone** (MULTIweather) and a picture folder for items (MULTIimages).
- **ox_lib**, **oxmysql** and **redm-ipls** (`resources/[standalone]`), unchanged, with their own licences. redm-ipls loads the base-game map pieces RedM leaves out: buildings, interiors and their furniture.
- 32 languages, chosen with one line in `MULTIcore/config_multi.lua`: English, German, French, Spanish, Portuguese (Brazil and Portugal), Italian, Polish, Russian, Dutch, Turkish, Romanian, Czech, Hungarian, Ukrainian, Bulgarian, Greek, Swedish, Danish, Norwegian, Finnish, Slovak, Croatian, Serbian, Slovenian, Chinese, Japanese, Korean, Arabic, Indonesian, Vietnamese and Thai.
- 1899 prices.

## Quick start

You need:
- a recent RedM server build (FXServer for Windows or Linux) from the Cfx.re artifacts;
- a free licence key from [portal.cfx.re](https://portal.cfx.re);
- MariaDB or MySQL. The scripts create their own tables on first start, so there is no SQL to run.

### With txAdmin (easiest)

1. Start FXServer and open txAdmin's setup page.
2. At "Deployment Type" choose **Remote URL Template** and paste:
   ```
   https://raw.githubusercontent.com/MULTIcore-RedM/MULTIcore-Server/main/recipe/multicore.yaml
   ```
3. Give it your licence key and database details when it asks. txAdmin downloads everything, makes the database and writes `server.cfg` with your key, your database and you as admin.
4. Start the server, join, make a character, and play.

### By hand

1. Download this repository (Code → Download ZIP, or `git clone`) and use it as your server-data folder.
2. Copy `server.cfg.example` to `server.cfg` and fill in the three lines marked `CHANGE`: your licence key, your database, and your own licence as admin.
3. Start the server from this folder: `FXServer +exec server.cfg`. With txAdmin, point it at this folder and this `server.cfg`, and turn OneSync on in txAdmin's settings.
4. Join, make a character, and play.

**Then read [`docs/MULTIcore-Server-Owner-Guide.md`](docs/MULTIcore-Server-Owner-Guide.md):** item pictures, adding items, jobs, gangs, stores, staff and money, step by step.

## Keys

| Key | What it does |
|---|---|
| **T** | Chat. `/me` (white on black), `/do` (blue on black), `/try`, `/ooc` |
| **N** (hold) | Talk (proximity voice; the game's own push-to-talk key) |
| **`` ` ``** (left of 1) | Voice range: whisper, talk, shout (also `/voice`) |
| **Left Alt** (hold) | Target: look at a person, horse, wagon, door or counter to see its options |
| **I** | Inventory |
| **X** (hold) | Hands up |
| **B** (hold) | Point |
| **F6** | Radial menu |
| **F5** | Emote menu (**X** stops an emote) |
| `/notifylayout` | Move and resize your notifications (drag, mouse wheel), then Save. `/notifyreset` puts them back |

Every key can be changed in the script's `config.lua`. The voice range key is also in the game's own key settings, so each player can change it.

## Adding your own scripts

Put them in `resources/` and `ensure` them **below** the MULTI scripts in `server.cfg`. RSG v2, VORP and RedEM:RP scripts work without edits. Do not also start `rsg-core`, `vorp_core`, `redem_roleplay`, `redemrp_inventory`, `ox_target`, `rsg-target`, `chat`, `rsg-inventory`, `vorp_inventory`, `rsg-wardrobe`, `RINGOinventory`, `RINGOtailor`, `pma-voice`, `weathersync` or a second IPL script: MULTIcore and its scripts already answer as those (or do the same job).

## Making MULTI scripts

Everything a script writer needs is in [`docs/`](docs):

| File | What it is |
|---|---|
| `MULTIcore-Server-Owner-Guide.md` | Pictures, items, jobs, gangs, stores, staff: for server owners |
| `MULTIcore-API.md` | The MULTIcore API (players, money, items, jobs, notifications) |
| `MULTItarget-API.md` | The target system |
| `MULTIcore-Script-Rules.md` | The rules every MULTI script follows |
| `MULTIcore-UI-Guide.md` + `MULTIcore-UI-Kit.zip` | How to make screens that match, with a working example menu |
| `MULTIstarter.zip` | A small working script to start from |

## Item pictures

None are included. Put your own `.png` files in `resources/[multicore]/MULTIimages/images/`, named as each item's `image` field (`bread.png` ...). Until then, items show a plain icon. See the server owner guide.

## Game fonts (optional)

The menus look most like the game with its own style of fonts. They are not included, because the font files belong to their owners. See `resources/[multicore]/MULTIcore/html/theme/fonts/README.md`. Without them, close free fonts are used.

## Reporting problems

Open an issue on this repository. Include:
- what you did;
- what happened;
- what you expected;
- the server console lines (F8 lines too, if any).

## Licence and credits

**Founder and creator: RINGO (RINGOscripting).** MULTIcore, the MULTI scripts, MULTItarget, MULTIchat and the MULTIcore look are RINGO's work. Copyright (C) 2026 RINGO (RINGOscripting). See `NOTICE.md`.

GPL-3.0 (see `LICENSE`). If you share a changed copy, keep the credits and licence notices. MULTIcore is built on **rsg-core 2.4.1** and other RSG v2 framework code (GPL v3); see each script's `CREDITS.md`, and `resources/[multicore]/MULTIcore/CREDITS.md` and `MULTICORE_CHANGES.md`. **MULTIcoroner** is based on **phils-coroner by Phil**, **MULTIhorses** on **rsg-horses by Phil**, and **MULTIwagons** on **rsg-wagons by Phil** with wagon work by **Mack**. **MULTIvendor** is by **Mack**. All are renamed and fitted to MULTIcore with their permission. The **item pictures** in MULTIimages are by **Tankie** (The Icon Library Project, https://github.com/TankieTwitch/FREE-RedM-Image-Library). **ox_lib** and **oxmysql** are by Overextended, and **redm-ipls** by Heather Rhodes (MIT), under their own licences (included in their folders).
