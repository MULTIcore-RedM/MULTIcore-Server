# Changelog

*MULTIcore was founded and created by RINGO (RINGOscripting).*

## 2026-11-23 (UI presets)

### New
- **Three looks for every MULTI menu, picked with one line** in `MULTIcore/config_multi.lua`:
  ```lua
  MULTIConfig.UIPreset = 'classic'   -- 'classic', 'parchment' or 'modern'
  ```
  - `classic`: the base game's black menus with white lettering (as before, the default).
  - `parchment`: old paper with dark ink and a brush stroke under the picked row.
  - `modern`: a dark card with a silver frame and rounded corners.
  
  Every MULTI menu follows it: the target (eye and options card), notifications, menus and dialogs, inventory, stores, bank, chat, radial menu, tailor, stables, wagons, housing, hotel, jobs, admin, character select and creator. Only the HUD gauges and the loading screen keep their own look. In `classic` everything looks exactly as before. Notification colours set in `config_notify.lua` still win over the preset. `''` uses `setr multicore_ui_preset <name>` in server.cfg instead. Pages of your own can follow it too: link `nui://MULTIcore/html/theme/multi.css` and add `<script src="nui://MULTIcore/html/theme/preset.js"></script>`.

### Updating
Copy the updated `MULTIcore` folder and the other MULTI folders from `resources/[multicore]` (their pages load the new preset script; keep a copy of your own config changes first), then set `MULTIConfig.UIPreset` if you want a different look.

## 2026-11-23 (hotels, bath houses, last location fix)

### New
- **MULTIhotel: hotels** in Valentine, Strawberry, Rhodes, Saint Denis, Blackwater, Tumbleweed and Annesburg. Hold **Left Alt** at the front desk to rent a room (`Config.StartCredit`, $10, becomes the room credit) and check in. Every room is its own private copy. The room menu has add / take out credit, a room locker (MULTIinventory), guests (invite players close to you, take invitations back), throw guests out, and telegrams. Rent comes out of the credit every hour; a telegram warns when it runs low and the room is given up when it runs out. Every action is checked on the server.
- **MULTIbathing: bath houses** in Saint Denis, Valentine, Annesburg, Strawberry, Blackwater, Van Horn and Rhodes with the game's own bathing scene. Hold **Left Alt** at the counter to take a bath ($1), scrub, or order the luxury service ($5). You get out clean (cleanliness 100 in MULTIhud) with your clothes back on.

### Fixed
- **Last location spawn:** your game now sends your real position to the server every few seconds, so "last location" puts you back where you logged out. Loading a character no longer overwrites the saved spot with the character select spot. How often it sends is `MULTIConfig.PositionSyncMs` in `MULTIcore/config_multi.lua` (default 5000 ms).

### Updating
- Copy `resources/[multicore]/MULTIhotel`, `resources/[multicore]/MULTIbathing` and the updated `MULTIcore` into your server and add `ensure MULTIhotel` and `ensure MULTIbathing` after `ensure MULTIhouses` in `server.cfg`. MULTIhotel makes its tables on the first start.

## 2026-11-22 (32 languages)

### New
- **One line picks the language of every MULTI script:** `MULTIConfig.Language` at the top of `MULTIcore/config_multi.lua`. Menus, notifications, prompts and the loading screen all follow it. A script can still use its own language with `Config.Locale` in its config. Set it to `''` to keep using `setr multicore_locale` in server.cfg.
- **22 new languages**, so there are now 32: English, German, French, Spanish, Portuguese (Brazil and Portugal), Italian, Polish, Russian, Dutch, Turkish, Romanian, Czech, Hungarian, Ukrainian, Bulgarian, Greek, Swedish, Danish, Norwegian, Finnish, Slovak, Croatian, Serbian (Latin), Slovenian, Chinese (Simplified), Japanese, Korean, Arabic, Indonesian, Vietnamese and Thai.
- Languages with letters the game fonts don't have (Cyrillic, Greek, Chinese, Japanese, Korean, Arabic, Thai, Vietnamese) switch the menus to the plain fonts so every letter shows.
- **Character creation: Undress / Dress button** next to the camera buttons. It shows the character without clothes while you shape the body; the chosen clothes are kept and saved as normal. Changing a piece of clothing puts the clothes back on.

### Fixed
- MULTIvendor now follows the server language; before, it always used its own setting.

### Updating an existing server
- Copy every folder in `resources/[multicore]` over yours, keeping your own config changes (the new language files are in each script's `locales` folder). New files: `MULTIcore/server/multi/language.lua` and `MULTIloading/server.lua`.
- In `MULTIcore/config_multi.lua` add the `MULTIConfig.Language` line (copy it from the new file) and set your language there.

## 2026-11-22 (vendors)

### New
- **MULTIvendor: vendor NPCs who buy your goods**, made by **Mack**. Vendors around the map each buy their own kind of goods: produce, pelts, herbs, jewellery, fossils and more. Walk up and use the prompt, pick what to sell and how many, or sell everything that vendor buys at once.
- Sales are checked on the server: you must stand at the vendor, you are paid only for items actually taken from your satchel, and amounts must be whole numbers.
- Vendor prices follow the store rule: no vendor pays more than half of what a store sells the item for, so nothing can be bought and sold again for profit.
- 10 languages, the black and white MULTIcore look.

### Updating an existing server
- Copy `resources/[multicore]/MULTIvendor` into your server and add `ensure MULTIvendor` after `ensure MULTIhouses` in `server.cfg`.

## 2026-11-22 (give items from the admin menu)

### New
- **Admin menu: give and take items.** On a player's card, type to search every item, set the amount, then press Give or Take. Weapons are given with their own serial.
- **Admin menu: item kits.** One button gives a whole set of items. Two kits come with it, for tailor materials: a full outfit, and the raw materials. Add your own in `Config.ItemKits` in MULTIadmin.

### Fixed
- The wild horse seller's menu: a long seller name no longer runs under the back and close buttons. The buttons and the line under the title now show the right signs.
- **Horse holster:** every rifle, sniper rifle, repeater, shotgun and bow now fits the horse holster. Some had wrong names before (Rolling Block, Carcano, Henry, Sawed-off ...) and were refused as "not a long arm".
- **Permissions:** "set account group" in the admin menu now really changes a player's rights. MULTIcore was not allowed to set up permission groups, so the server log showed "Access denied for command add_ace". The same fix lets mod-level commands work.

### Updating an existing server
- Copy `resources/[multicore]/MULTIadmin` into your server, keeping your own config changes. Then copy these from MULTIhorses:
  - `html/index.html`;
  - `html/horses.css`;
  - `client/client.lua`.
- In `server.cfg`, under `add_ace group.admin command allow`, add:
  ```
  add_ace resource.MULTIcore command.add_ace allow
  add_ace resource.MULTIcore command.add_principal allow
  add_ace resource.MULTIcore command.remove_principal allow
  ```

## 2026-11-22 (notifications your way)

### New
- **Notifications can be put anywhere, any size, in any look.** In `MULTIcore/config_notify.lua`:
  - each kind (messages, tips, objective, banner) gets a position (any corner, any edge or the middle), offsets, width and size;
  - `NotifyConfig.Look` changes how they are drawn. Pick a preset (`game`, `box`, `card`, `minimal`), then change the background, border, rounded corners, coloured edge, text colours, fonts, text sizes, icons, spacing and animation.
- **`/notifylayout`:** players drag the notifications where they want them, then press Save:
  - the mouse wheel makes them bigger or smaller, Shift + wheel wider or narrower;
  - it is kept on their own PC, and `/notifyreset` puts it back;
  - saving also prints the positions for `config_notify.lua`, so an owner can set everyone's default the same way.
- How to set it all up is in the server owner guide, section 6.

### Updating an existing server
- Copy these from `resources/[multicore]/MULTIcore` into your server:
  - `config_notify.lua`;
  - `client/multi/notify.lua`;
  - `html/notify/notify.js` and `notify.css`;
  - `locales/notify_*.lua`.

  Your `html/notify/custom.css` keeps working. An older `config_notify.lua` also keeps working, but the new settings are only in the new one.

## 2026-11-22 (houses)

### New
- **MULTIhouses: houses.** 50 houses across the map, each with a map blip. Hold **Left Alt** at a house to view and buy it:
  - pay a 20% deposit in cash and pay off the rest over time;
  - one house per character;
  - give guest keys to other characters;
  - a storage chest and a wardrobe for your outfits in every house;
  - lock and unlock the doors;
  - optional land tax, paid from the house's own credit, with telegram reminders;
  - break-ins with a `lockpick`, with an alert to the law.
- New item: `lockpick` (added by itself on the first start).

### Updating an existing server
- Copy `resources/[multicore]/MULTIhouses` into your server and add `ensure MULTIhouses` after `ensure MULTItelegram` in `server.cfg`. Its tables are made on the first start.

## 2026-11-21 (character creator fix)

### Fixed
- **Two players making a character at the same time no longer see each other.** Each player now picks and creates their character in a world of their own and joins everyone else when they spawn. Thanks to bula1918 for the report.
- Settings: `Config.PrivateScene` and `Config.PrivateBucketBase` in MULTIcharacter.

### Updating an existing server
- Copy `resources/[multicore]/MULTIcharacter` into your server. Keep a copy of your own config changes first.

## 2026-11-21 (wardrobes)

### Changed
- **Outfits are changed at a wardrobe, not anywhere.** `/outfits` is gone. You change into a saved outfit:
  - at a clothes store;
  - at a wardrobe point;
  - at a wardrobe in another script, like a house.

  The inventory's outfit list follows the same rule.
- **Wardrobes in housing scripts work by themselves.** A housing script that opens rsg-appearance's or VORP's outfits gets MULTIcore's outfit list, and the player can change outfits there.
- **Using an outfit item puts the outfit on.** What you were wearing goes into your satchel. It used to only unpack the pieces.
- Single clothing pieces can still be put on and taken off anywhere from the inventory.
- Server owners who want the old way back: set `Config.Outfits.command = 'outfits'` in MULTItailor.

### Updating an existing server
- Copy `MULTItailor`, `MULTIinventory`, `MULTIappearance` and `MULTIvorpchar` into your server. Keep a copy of your own config changes first.

## 2026-11-21 (new horses and wagons)

### New
- **MULTIhorses is a new horse script**, based on **rsg-horses by Phil**:
  - buy, name, customise and move horses between stables;
  - horses level up, age and can be bred (horse breeder job);
  - tame wild horses and sell them;
  - saddlebags, a lantern and a holster on the horse;
  - a stable shop.
- **MULTIwagons is a new wagon script**, based on **rsg-wagons by Phil**, with wagon work by **Mack**:
  - about 50 wagons to buy, with liveries, extras and cargo;
  - store hunted animals on a wagon;
  - a chop shop for wood.
  - Other players can ask the owner for the wagon's storage.
- Both use MULTIcore's black and white look, Left Alt targeting and all 10 languages. Scripts written for rsg-horses and rsg-wagons still work.
- New items: `hay`, `horsecarrot`, `horseapple` and `horse_holster`, with pictures.
- The game's own cash, gold and honor display no longer pops up when you hold Left Alt (`Config.HideGameMoneyHonor` in MULTIhud).

### Changed
- A horse that isn't revived in time goes back to its stable (`Config.DeleteDeadHorse = true` in MULTIhorses makes it gone for good).
- Horses grow old and die of old age (see `Config.HorseDieAge` in MULTIhorses; 0 = never).
- Saddlebags need a saddle and saddlebags on the horse. Horses you already had get saddlebags.
- Wagon repair and renaming a wagon are gone, and so is the `wagon_repair_kit` item.

### Updating an existing server
- Replace `resources/[multicore]/MULTIhorses` and `MULTIwagons` with the new folders. Copy MULTIcore's `shared/items.lua`, MULTIhud and `MULTIimages/images` too. Keep a copy of your own changes first.
- Your players' horses, wagons, saddlebags and wagon storage carry over. The new columns are added on the first start.

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
