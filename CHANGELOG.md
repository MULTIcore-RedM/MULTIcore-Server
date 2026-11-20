# Changelog

*MULTIcore was founded and created by RINGO (RINGOscripting).*

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
