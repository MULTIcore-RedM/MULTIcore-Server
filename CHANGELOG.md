# Changelog

*MULTIcore was founded and created by RINGO (RINGOscripting).*

## 2026-11-20 (fixes)

- **Respawn:** the "You are unconscious" screen no longer stays up after you respawn at the doctor.
- **Calling your horse:** it now appears about 10 feet (3 m) in front of you, on your own ground level. It no longer appears on roofs or inside buildings. If a wall is in the way, it appears beside or behind you instead. Setting: `Config.SpawnDistance` in MULTIhorses.
- **Last location:** "Last location" in the spawn picker is now where you actually were when you logged out or closed the game. It used to be where you had logged in.
- **Targeting (MULTItarget)** now works like rsg-target. Hold **Left Alt** and an eye shows in the middle of the screen; it lights up when what you look at has options, and the options appear beside it. **Left-click** to bring out the cursor, then click the option you want. **Right-click** or **Esc** cancels. There is no more scrolling. Nothing is drawn in the world: no dots or sprites.

## 2026-11-20 (later)

### New
- **Hands up and point.** Hold **X** to put your hands up (the weapon goes away and you can't shoot; lawmen can search you) and hold **B** to point. You can still walk while doing either. While an emote, eating or crafting is running, X stops that instead. Settings in MULTIemotes `config.lua`.
- **Base-game map.** The buildings, interiors and furniture that RedM leaves out are now loaded: shops, banks, saloons, the Saint Denis buildings and more. This comes from **redm-ipls**, included unchanged in `resources/[standalone]` under its own MIT licence.
  Already installed? Copy `resources/[standalone]/redm-ipls` into your server and add `ensure redm-ipls` after `ensure ox_lib`.

### Changed
- **Inventory** opens with **I** (was B).
- **Voice range** changes with the **`` ` ``** key, left of 1 (was U). Players can also change this key in the game's own key settings.

## 2026-11-20

### New
- **txAdmin recipe.** Install the whole server from txAdmin's setup page: choose **Remote URL Template** and paste
  `https://raw.githubusercontent.com/RINGOBenny/MULTIcore-Server/main/recipe/multicore.yaml`.
  txAdmin downloads everything, makes the database and writes `server.cfg` for you. See the README.
- **RedEM:RP support.** MULTIcore now also answers as `redem_roleplay`, and the MULTI scripts as `redemrp_inventory`, `redemrp_status`, `redemrp_respawn`, `redemrp_bossmenu`, `redemrp_menu_base` and `redemrp_progressbars`. RedEM:RP scripts now run next to RSG v2 and VORP scripts, on the same players, money, jobs and items. How to add their items is in the server owner guide, section 7.
- **MULTIweather.** One clock and one sky for every player. The weather changes by itself in believable steps, nights are shorter, and the time and weather are remembered across restarts. Admins: `/weather [type]`, `/weather auto`, `/time [hour] [minute]`, `/freezetime`, or the admin menu.
- **MULTIvoice.** Proximity voice: whisper, talk and shout (**U** or `/voice`, or the F6 menu). The game's own push-to-talk key (**N**) talks. Radio and call channels for other scripts. Scripts written for pma-voice work unchanged.

### Changed
- The HUD's voice gauge works with MULTIvoice.
- The admin menu's weather and time buttons drive MULTIweather.
- `server.cfg.example`: MULTIvoice, MULTIweather and the two voice settings.
- README and server owner guide updated for all of the above.

## 2026-11-19

- **Credits:** RINGO (RINGOscripting) is credited as founder in the README, NOTICE, every script and the loading screen.
- **Server owner guide:** item pictures, items, jobs, gangs, stores, staff and money, step by step.
- **MULTIimages:** one picture folder for the inventory and the stores.
- **`/giveitem`:** new admin command.
- **Menus and dialogs:** menus from ox_lib calls are now drawn black and white by MULTIcore.
- **MULTIchat:** MULTIcore's own chat with `/me`, `/do` and `/try`.
- **First public release:** MULTIcore with 30 MULTI scripts, ox_lib, oxmysql, `server.cfg.example` and the developer docs.
