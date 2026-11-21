# Changelog

*MULTIcore was founded and created by RINGO (RINGOscripting).*

## 2026-11-21 (new home)

- **MULTIcore has moved to its own GitHub organisation:** https://github.com/MULTIcore-RedM/MULTIcore-Server. Old links still lead there.
- The txAdmin recipe link is now
  `https://raw.githubusercontent.com/MULTIcore-RedM/MULTIcore-Server/main/recipe/multicore.yaml`.
- Changes to MULTIcore now come in as pull requests and are checked before they go live.

## 2026-11-21 (food, drink and medicine)

### New
- **635 new items, all with pictures by Tankie** (The Icon Library Project). MULTIcore now has 1150 items.
  - **Food (about 340):** cakes, pies, cookies, candy, ice cream, breads, stews, soups, full meals, canned goods, and cooked meats and fish. Cooked meat seasoned with oregano heals more, with thyme relieves stress, with mint restores stamina.
  - **Drinks:** teas, coffees, juices, lemonades, sodas and milkshakes.
  - **Alcohol:** beers, ales, wines, spirits, cocktails and 10 kinds of moonshine. They get you drunk, and a bottle leaves an empty bottle.
  - **Medicine:** tonics, restoratives, snake oils, antibiotics, antipoison, morphine and valerian root. Salves and balms heal wounds like a bandage.
  - **Ingredients:** raw meats, flour, spices, herbs, grains, fruit and vegetables, crates and sacks, and brewing malt and mash.
- Every food, drink and medicine works straight away through MULTIconsumables. Their effects are in `MULTIconsumables/config/consumables_library.lua`, one line per item.

### Updating an existing server
- Copy MULTIcore's `shared/items.lua`, `MULTIconsumables/config/consumables_library.lua` and `config/consumables.lua`, MULTImedic's `config.lua` and `MULTIimages/images` into your server. Keep a copy of your own changes to those files first.

## 2026-11-21 (item pictures)

### New
- **Item pictures included.** MULTIimages now comes with pictures for 394 of MULTIcore's 515 base items: food, drink, medicine, ammo, tools, ores, gems, pelts, herbs, money and more. They are by **Tankie** (The Icon Library Project, https://github.com/TankieTwitch/FREE-RedM-Image-Library), a free RedM picture library.
- Items without a picture yet (most guns, canteens, backpacks, some herbs and orchids) keep the plain placeholder. Add your own `.png` in `MULTIimages/images`, named as the item's `image`.

### Updating an existing server
- Copy `resources/[multicore]/MULTIimages/images` into your server. Pictures you added yourself with the same name are replaced, so keep a copy of them first.

## 2026-11-21 (coroner)

### New
- **MULTIcoroner: coroner inquests.** Hold **Left Alt** on a dead player, stranger or animal and pick **Perform inquest**. The form fills in the place (nearest town) and, for a dead player, the character's name. Add the cause and manner of death, notes and a conclusion, and file it. `/inquests` opens the ledger of every filed report, where reports can be read, copied or deleted. Filing gives you an **Inquest Report** item that anyone can read and hand on.
- **Coroner job** (Assistant, Deputy Coroner, Coroner) and the `coroner_report` item. Coroners, medics and lawmen on duty can hold inquests.
- MULTIcoroner is based on **phils-coroner by Phil**, renamed and fitted to MULTIcore with Phil's permission.

### Updating an existing server
- Copy `resources/[multicore]/MULTIcoroner` into your server, plus MULTIcore's `shared/jobs.lua` and `shared/items.lua`.
- In `server.cfg`, add `ensure MULTIcoroner` after `ensure MULTImedic`. Its table is made on the first start.

## 2026-11-20 (new inventory and clothing)

### New
- **MULTIinventory is a new inventory.** It is RINGO's full inventory, now free and part of MULTIcore:
  - slots and weight, a hotbar, and clothing slots;
  - weapons with serials, condition and components, and a gunbelt for spare ammo;
  - stashes, saddlebags and wagon storage, searching players;
  - a Craft tab and a crafting journal.

  It is drawn in MULTIcore's black and white look, and the key is still **I**. RSG v2, VORP and RedEM:RP inventory calls work as before.
- **MULTItailor replaces MULTIclothing. Clothes are now items.** What you wear sits in the clothing slots of your inventory. You can take pieces off, swap them, store them, trade them and save outfits. Clothes stores are in the main towns, and the tailor job (Outfit Designer, sewing, counter and till) is included. The radial menu's clothes on and off still works.
- **Scripts written for RINGOinventory or RINGOtailor** work on MULTIcore without changes.

### Changed
- **Ammo:** spare ammo now sits on your gunbelt. Use an ammo box from the inventory to put its rounds on the belt.

### Updating an existing server
- In `server.cfg`, replace `ensure MULTIclothing` with `ensure MULTItailor`, after `ensure MULTIstores`. Then delete the `MULTIclothing` folder.
- On the first start, MULTIinventory copies every satchel, stash, saddlebag, wagon trunk and gun from the old inventory into its own tables. It only does this once, and it leaves the old data untouched.
- On each character's first load, the clothes they were wearing become clothing items, so nobody turns up without clothes.

## 2026-11-20 (more fixes)

- **Ammo:** reloading takes one round from the satchel for every round loaded into the gun. Each shot takes one round from the gun. The rounds in a gun stay in it when you put it away.
- **Horse saddlebags and wagon storage:** Left Alt now finds horses, wagons, people and objects even when grass or bushes are in the way, and from further away when the camera is pulled back. The **Saddlebags** option shows on your horse and **Open storage** at the back of your wagon. New setting: `Config.EntityRayFlags` in MULTItarget.

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
  `https://raw.githubusercontent.com/MULTIcore-RedM/MULTIcore-Server/main/recipe/multicore.yaml`.
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
