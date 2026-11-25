# Changelog

*MULTIcore was founded and created by RINGO (RINGOscripting).*

## 2026-11-25 (MULTItailor 1.3.0: share outfits, how clothes sit, tobacco)

### New
- **MULTItailor:** **Give a copy** of one of your saved outfits to a player standing next to you. If they accept, it joins their saved outfits; wearing it puts on the matching clothes they own. No clothes change hands. Settings: `Config.Share`.
- **MULTItailor:** `/clothes` -> **How it sits** steps a worn piece through the ways the game lets it be worn: bandana up over the face, open collar, rolled sleeves, an open coat and more. Only the ways the game lists for that piece are offered, and the choice stays with the character. `/bandana` pulls the worn bandana up or down. Settings: `Config.Styles`.
- **MULTItailor:** `/clothes` -> **Tobacco** lists the cigarettes, cigars, pipe tobacco and chewing tobacco you carry; picking one uses it the same way as from the satchel. Settings: `Config.Tobacco`.
- **MULTIinventory:** `ImportOutfit(src, name, pieces)` adds a copy of another player's outfit to a player's saved outfits.

### Changed
- **MULTItailor:** notices go through MULTIcore's own notifications.

## 2026-11-25 (winter weather)

### New
- **MULTIweather:** a winter season. From 21 November to 31 January the weather changes by itself only between light snow, snow and the odd blizzard, then the normal pattern takes over again. Admins can still set any weather. Dates and the pattern are in `config.lua` (`Config.Weather.Season`); `Enabled = false` switches it off.
- **MULTIcore:** `GetRegisteredJobs()` on the VORP side lists every job with its grades, for VORP scripts that show a job board or job menu.

### Fixed
- **MULTIcore:** a character's face no longer turns black when several scripts reload their look at the same moment; if the face texture can't load, the plain head stays instead.

### Changed
- **MULTIinventory:** code comments no longer name other scripts.

## 2026-11-25 (starting cash setting)

### New
- **MULTIcore:** set how much cash a new character starts with in `server.cfg`: `setr multicore_startcash 5000`. Without it a new character gets 50, as before.

### Changed
- **MULTIinventory:** a code comment no longer names another script.

## 2026-11-24 (no more game award cards)

### Changed
- **MULTIcore:** the base game's award and challenge cards on the left of the screen ("Survivalist Award - Hold F1 for details") are cleared the moment they appear. `MULTIConfig.HideGameAwards = false` in `config_multi.lua` brings them back.
- **MULTIcore:** pressing Left Alt (the target key) no longer flashes the base game HUD; the game's own "reveal HUD" on that key is switched off. `MULTIConfig.BlockHudReveal = false` brings it back.

## 2026-11-24 (VORP menus work exactly like vorp_menu)

MULTIhelpers' menu was checked against vorp_menu behaviour by behaviour, and every difference a script could notice is fixed.

### Fixed
- **Sliders:** moving a slider left or right now calls the script's submit, as vorp_menu does (gunsmith and clothing scripts apply the choice there; before, nothing happened until Enter). Text sliders update `value` and `currentTextLabel`. Sliders with `options` show the option text; a slider with no `max` does not move right.
- **Menu buttons:** both the confirm and cancel buttons go to submit with `{ buttonType, buttonValue, selectedElement, selectedIndex, value }`; the cancel button no longer counts as the player leaving.
- **Removing rows:** `removeElementByValue(v, stop)` removes every match unless `stop`; `removeElementByIndex(i)` removes one row.
- **Closing:** `MenuData.Close` takes `showRadar, closeSound, triggerCloseEvent`; the close sound plays only when asked for.
- **Enter on a tick box** calls submit only. Backspace back to `lastmenu` also passes `elements`. Every row carries `selected`.
- **Yes/No boxes** (`menu.displayInput`): "No" calls `onSubmit(false)`.
- **Held keys** (`MenuData.RegisterControls`): `onPress` runs every frame while the key is held, so rotate / zoom feel smooth.
- **Game input:** the game keeps keyboard input while a menu is open (`Config.Menu.KeepGameInput = true`), so scripts' own key loops keep working.
- **Text boxes:** an empty answer skips the pattern check; `required` is honoured.

### New
- `menu.update(query, data)`, `menu.setElements(t)`, `menu.removeElement(query)`, `menu.isInputActive()`, `MenuData.IsInputActive()`, `MenuData.Opened`, `MenuData.LastSelectedIndex`; `MenuData.ReOpen(oldMenu)` opens a closed menu again.

### What to do
- Update `MULTIhelpers`, then restart the server. If you copy your old `config.lua` over it, set `KeepGameInput = true` in `Config.Menu`.

## 2026-11-24 (syn_weapons customising works)

### Fixed
- **Menus closed by a script no longer count as the player leaving:** `menuapi:closemenu` now fires only when the player closes a menu (Backspace / Esc), as in vorp_menu. Before, it also fired when a script swapped one menu for the next, and scripts such as syn_weapons ended the whole session there: the gun preview vanished and the customise menu came up empty.
- **The gun's identifier in `loadout`** is now the one VORP scripts get (the Steam id when the player has one), so gunsmith scripts find the player's guns.

### New
- **syn_inputs:** `syn_inputs:sendinputs` opens the MULTI text box (amounts, custom names and serials in syn scripts).
- **vorp_inventory `useWeapon` (client):** equips a gun by its id, as gunsmith scripts do after customising it.

### What to do
- Update `MULTIhelpers` and `MULTIinventory`, then restart the server.

## 2026-11-24 (gunsmith scripts see your guns)

### Fixed
- **Empty weapon list at gunsmiths:** VORP gunsmith and weapon customisation scripts (such as syn_weapons) that read a player's guns straight from VORP's `loadout` table showed an empty list, because MULTIcore keeps weapons in MULTIinventory. MULTIinventory now keeps `loadout` filled with the guns of every online character.
- A script's change to a gun's `comps`, `custom_label` or `custom_desc` in `loadout` is applied to the gun, so bought customisations stay on it.
- New settings in MULTIinventory `config.lua` (`Config.Compat`): `vorpLoadout` (on by default) and `vorpLoadoutSeconds`.

### What to do
- Update `MULTIinventory`, then restart the server.

## 2026-11-24 (new characters keep their clothes)

### Fixed
- **Naked after relog:** a new character's clothes from the creator did not become clothing items (the clothing items were missing from the item list), and after a relog the character was naked. The 36 clothing items (`clothing_hat` ... `clothing_outfit`) are now in MULTIcore's item list, so the creator clothes go straight into the equipment slots and stay on.
- **MULTItailor:** when no clothing item can be created, the saved look is kept and tried again on the next load instead of being emptied.

### What to do
- Update `MULTIcore` and `MULTItailor`, then restart the server.
- A character made before this update that is already naked lost its creator clothes: delete it and make it again, or buy clothes at a clothes store.

## 2026-11-23 (more RedEM:RP scripts work)

Tested with the official RedEM:RP scripts on MULTIcore: redemrp_shops, redemrp_banking, redemrp_clothes_store, redemrp_blueberry, redemrp_farmerjob, redemrp_infection, redemrp_properties, redemrp_propplacer, redemrp_witness, redemrp_dialog and redemrp_quests all start without errors.

### New
- **XP:** `addXP`, `removeXP` and `getXp` on the RedEM:RP player (the farmer job and quests pay XP). It is kept with the character.
- **Older RedEM:RP calls:** the server export `getPlayerFromId` and the client export `DisplayTip` (used by redemrp_properties).
- **Your RedEM:RP script's own use of an item:** list the item in `Config.Redem.ScriptItems` in `MULTIinventory/config.lua` (e.g. `{ 'blueberry' }` with redemrp_blueberry) and the script's `RegisterUsableItem:<name>` runs instead of MULTIcore's own use.
- **Items:** `stick` and `planks`.
- **playerSpawned** is fired when your character is in the world, for scripts that wait for it (redemrp_propplacer). Skipped when spawnmanager runs, because it fires it itself.
- **Creator calls from RedEM:RP scripts:** `GetBodyCurrentComponentHash` answers as `rdr_creator` / `redemrp_creator`, and `RedEM:server:LoadSkin` / `redemrp_skin:LoadSkinClient` put your saved look back on.

### Changed
- `GetSessionVar(name)` also returns the player's own field when nothing was set under that name, as RedEM:RP does (`GetSessionVar('charid')`).

### Good to know
- redemrp_clothes_store keeps clothes in its own table and MULTIcore does not put them back on after a relog. Use MULTItailor's clothes stores instead.
- Some of these older scripts trust the player's game too much: redemrp_farmerjob and redemrp_quests let a player pick their own pay or job. Only run them on a server you trust.

### Updating
Copy `MULTIcore`, `MULTIinventory/config.lua`, `MULTIinventory/server/core/usables.lua` and `MULTIappearance` from `resources/[multicore]`. Keep a copy of your own config changes first and add the new `ScriptItems` line to `Config.Redem`.

## 2026-11-23 (clothes stores: the full catalogue)

### Changed
- **MULTItailor clothes stores sell every piece the game has,** not just a short list of ready-made lines. That is 31 categories: hats, spectacles, masks, neckerchiefs, ties, shirts, vests, suspenders, coats, ponchos, cloaks, dresses, trousers, skirts, chaps, spats, boots, spurs, gloves, gauntlets, bracelets, rings, belts, buckles, gunbelts, holsters, bandoliers, satchels and accessories.
  - Pick a style and a colour with the arrows. It is tried on you at once.
  - Buy one piece, or **Buy everything picked** in one go.
  - One price per category, set in `Config.Stores.prices` in `config/stores.lua`. Remove a category from that list to keep it off the shelves.
  - `Config.Stores.fullCatalogue = false` goes back to the ready-made lines.

### Fixed
- **Clothes store clerks** no longer vanish or end up under the store floor. `/tailorclerks` shows each clerk near you in F8.

### Updating
Copy `MULTItailor/config/stores.lua`, `MULTItailor/server/70_stores.lua`, `MULTItailor/client/70_stores.lua`, `MULTItailor/html/app.js` and the `MULTItailor/locales` folder from `resources/[multicore]`. Keep a copy of your own `config/stores.lua` changes first.

## 2026-11-23 (update guide and small fixes)

### Update guide: everything since 2026-11-22
If your server is from before 2026-11-23, do all of this once instead of following each entry below.

1. **Keep your settings.** Copy every `config.lua`, the `config` folders, `MULTIcore/config_multi.lua` and `MULTIcore/config_notify.lua` somewhere safe.
2. **Copy every folder in `resources/[multicore]`** over yours. New folders: `MULTIfarming`, `MULTIhotel`, `MULTIbathing` and `uiprompt`.
3. **Put your settings back,** then add the new settings from the new files:
   - `MULTIcore/config_multi.lua`: `MULTIConfig.UIPreset` (`'classic'`, `'parchment'` or `'modern'`) and `MULTIConfig.PositionSyncMs`.
   - `MULTIadmin/config.lua`: the `Config.ChatCommands` block.
   - `MULTIgathering/config.lua`: `ChopsPerTree`, `TreeRegrowMinutes` and `TreeReach` under Lumber.
   - `MULTIstores/config/products.lua`: take the new file, or copy its seeds, hoe, watering can and crop lines into yours.
   - `MULTIinventory/config/aliases.lua` is new; take it as it is.
4. **server.cfg:**
   - after `ensure MULTIhelpers` add `ensure uiprompt`;
   - after `ensure MULTIgathering` add `ensure MULTIfarming`;
   - after `ensure MULTIhouses` add `ensure MULTIhotel` and `ensure MULTIbathing`;
   - remove any `ensure` line for a resource MULTIhelpers now stands in for: `menuapi`, `gum_menu`, `tpz_menu_base`, `rsg-menu`, `qb-menu`, `qbr-menu`, `feather-menu`, `rsg-input`, `qb-input`, `qbr-input`, `fx-input`, `gum_inputs`, `progressbar`, `feather-progressbar`, `redemrp_notification`, `gum_notify`, `rsg_notify`, `pNotify`, `bln_notify`, `syn_minigame`, `fx-minigame`, `bcc-minigames`. Keeping one is fine too: MULTIhelpers steps aside for it.
5. **Restart the server.** New tables (farming, hotel) are made on the first start. Nothing else needs SQL.

What players get: farming, hotels, bath houses, felled trees, every clothing piece in the creator, admin chat commands with help in the chat box, three UI looks, and scripts from other developers that just work.

### Fixed
- **MULTIwagons:** upgrades now work for wagons whose model names have capital letters (`Huntercart01` ...).
- **MULTIhelpers:** the `vorp_menu`, `vorp_inputs` and `vorp_progressbar` stand-ins now always switch on when the real resource isn't running.

### New for script developers
- **MULTIinventory `MoveStack`** moves weapons too (stack id `w<weaponId>`), so a script such as an item placer can put a gun down and hand the same gun back.
- **MULTItarget `hasZoneNear(coords, radius, ignore)`** returns true when another script's zone is close, so your script can keep out of its way.

## 2026-11-23 (other developers' item, weapon and ammo names)

### New
- **MULTIinventory understands other developers' names.** Scripts spell items, weapons and ammo their own way. MULTIinventory now turns those names into the item your server has, so giving, taking, counting, finding and using all land on the same item:
  - any capitalisation: `AMMO_BOX_REVOLVER` → `ammo_box_revolver`
  - `_`, `-`, `.` and spaces are ignored: `ammo-box-revolver` → `ammo_box_revolver`
  - common spellings: `ammo_revolver_normal` → `ammo_revolver`, `ammo_varmint` → `ammo_22`, `ammo_box_rifle_highvelocity` → `ammo_box_rifle_velocity`, `splitpoint` / `split_point`
  - ammo types: `AMMO_REVOLVER_NORMAL` → `AMMO_REVOLVER`, `AMMO_VARMINT` → `AMMO_22`
- VORP ammo item names (`ammorevolvernormal` ...) and the loose-round names RSG v1 scripts use (`ammo_revolver` ...) already worked and still do.
- **Your own aliases:** for a script that uses a name none of these catch, add a line to `MULTIinventory/config/aliases.lua` (`Config.ItemAliases`, `Config.WeaponAliases`, `Config.AmmoAliases`). With `Config.Debug = true` the console shows each name it turned into another.

### Updating
Copy `MULTIinventory` from `resources/[multicore]`. Keep a copy of your own config changes first. `config/aliases.lua` is a new file.

## 2026-11-23 (drop-in scripts: menu, input, progress, notification and minigame stand-ins)

### New
- **MULTIhelpers 0.2.0** now stands in for the menu and helper resources that RedM scripts from many developers depend on. Scripts that need one of these work without it: just drop the script in. Everything is drawn in the MULTI look and follows the three UI presets.
  - **Menus:**
    - `menuapi`, `gum_menu` and `tpz_menu_base` (the same MenuData as `vorp_menu`).
    - `rsg-menu`, `qb-menu` and `qbr-menu`.
    - `feather-menu` (v1, used by Feather and BCC scripts).
  - **Input boxes:** `rsg-input`, `qb-input`, `qbr-input`, `fx-input` and `gum_inputs`.
  - **Progress bars:** `progressbar` (needed by RSG v1 and QBR scripts) and `feather-progressbar`.
  - **Notifications:** `redemrp_notification`, `gum_notify`, `rsg_notify`, `pNotify` and `bln_notify`. All are shown as MULTIcore notifications.
  - **Minigames:** `syn_minigame` / `fx-minigame` (skill bar) and `bcc-minigames` (skill check, lockpick, rock-paper-scissors, hammertime, cow milker, dice).
- **uiprompt:** a new resource for scripts that include `@uiprompt/uiprompt.lua`.
- **syn_ scripts:** the `MenuData` error is fixed. The older `menuapi:getData` event is answered now.

### Updating
- Copy `MULTIhelpers` and `uiprompt` from `resources/[multicore]`.
- Add `ensure uiprompt` after `ensure MULTIhelpers` in server.cfg. Both must start before your other scripts.
- Remove any `ensure` lines for the resources listed above. If one of them does run, MULTIhelpers steps aside for it.

## 2026-11-23 (admin chat commands)

### New
- **Admin chat commands (MULTIadmin):** `/heal [id]`, `/revive [id]`, `/kill [id]`, `/goto [id]`, `/bring [id]`, `/freeze [id]`, `/spectate [id]`, `/kick [id] [reason]`, `/ban [id] [hours] [reason]`, `/warn [id] [reason]`, `/kit [id] [kit]`, `/announce [message]`, `/weather [type]`, `/time [hour] [minute] [freeze]`.
  - Leave out the id to heal, revive or kill yourself.
  - They use the same mod/admin levels, rank protection and logging as the admin menu.
  - Rename any command, or switch it off, in `Config.ChatCommands`.

### Changed
- **Chat command list:** as you type `/`, the chat box lists every command you may use with its arguments in `[brackets]`. While you type an argument it shows what goes there, for example `id: player ID, e.g. 5 (empty = yourself)`. Before, the help and arguments only arrived after a permission change, so most players saw bare names. This covers MULTIcore's own commands too (`/tp`, `/setjob`, `/givemoney`, `/giveitem` ...).
- **Mod commands for staff set in server.cfg:** players given `group.mod` in server.cfg can now use mod-level commands.

### Updating
Copy `MULTIadmin`, `MULTIchat/html/chat.js` and `MULTIcore/server/commands.lua` from `resources/[multicore]`. Keep a copy of your own `MULTIadmin/config.lua` changes first, and add the new `Config.ChatCommands` block to it.

## 2026-11-23 (farming, gathering 0.2.0, creator clothing)

### New
- **MULTIfarming (free).** Buy seeds, a hoe and a watering can at the general store. Use a seed outdoors with the hoe in your satchel to plant it. Planting isn't allowed in towns, indoors, in water, on roads or right next to another plant, and each player has a plant limit. Fill the can at a river or lake and water your crops: dry crops stop growing, and crops left dry or unharvested too long wither. Look at a crop with Left Alt to see its stage and water, and to water it, harvest it or dig it up.
  - Crops: corn, potatoes, tomatoes, carrots, onions, wheat, pumpkins and tobacco. The general store buys the harvest.
  - Growth is saved in the database (`multi_farming_plants`, made on start), so crops keep growing across restarts.
  - Admin command: `/farmclear`.
  - Settings are in `config.lua` and `config/crops.lua`. You can limit planting to farm zones with `Config.FarmZones`.

### Changed
- **MULTIgathering 0.2.0.**
  - Every tree now gives a few chops (`ChopsPerTree`, default 3) and is then felled for a while (`TreeRegrowMinutes`, default 20), so players have to move from tree to tree.
  - Admins can add a mining rock face where they stand with `/minespot add <coal|desert> [radius]`. It works at once with no restart, is saved in `data/mining_spots.json`, and `/minespot remove` deletes it again. Use this to fix the default mine positions on your map.
  - All 32 languages are included.
- **MULTIcreator:** the clothing tab now offers every piece the game has: spurs, chaps, belts, buckles, gunbelts, holsters, bandoliers, satchels, suspenders, neckties, glasses, masks, cloaks, ponchos, closed coats, gauntlets, rings, bracelets, hair accessories, spats, badges, armour and accessories.

### Updating
Copy `MULTIfarming`, `MULTIgathering`, `MULTIcreator` and `MULTIstores/config/products.lua` from `resources/[multicore]`. Keep a copy of your own config changes first. Add `ensure MULTIfarming` after `ensure MULTIgathering` in server.cfg.

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
