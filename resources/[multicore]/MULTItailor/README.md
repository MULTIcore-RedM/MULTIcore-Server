# MULTItailor

MULTIcore's clothing system. GPL v3. Stands in for **rsg-wardrobe** (`provide 'rsg-wardrobe'`).

Every garment is an **inventory item**. What a character wears sits in MULTIinventory's equipment slots
(`clothing_hat`, `clothing_shirt`, `clothing_boots` ... one slot per category; `clothing_outfit` is a bundle of pieces).
MULTItailor sells, makes and manages those items and keeps the character's MULTIcore look in step with them.

- **Clothes stores** in Valentine, Saint Denis, Blackwater, Rhodes, Strawberry, Tumbleweed, Armadillo, Annesburg and
  Van Horn. Talk to the clerk (MULTItarget, Left Alt): try clothes on with the camera on yourself, pick a colour, buy.
  The garment goes into your satchel; use it (or drag it to the equipment panel) to put it on.
- **Wearing:** put on and take off pieces in the inventory's equipment panel. The change shows at once and is saved
  in your MULTIcore look, so the character select screen, respawn, revive and every look reload show the same clothes.
- **Saved outfits:** "My outfits" at any store clerk, at a wardrobe point, or `/outfits`. An outfit is a named list of
  the items you wear; wearing it puts on the pieces you still own. Rename and delete too.
- **Quick toggles:** `/clothes` takes your hat, mask, coat, vest, gloves, neckwear, spectacles, gunbelt or satchel off
  for the moment and puts it back. The item stays in its slot. The radial menu's clothing buttons do the same.
- **The tailor job:** a player-run tailor shop in each town. Outfit Designer with the full game catalogue on a fitting
  dummy, sewing of cloth and notions (a short needlework minigame sets the quality), a pattern book, the counter
  shelf with written customer orders, a till and a stockroom. A cut outfit is a `clothing_outfit` bundle.
- **First load:** a character who already has clothes in their MULTIcore look (made in the creator, or before
  MULTItailor ran) gets them as items in their equipment slots once. Nobody turns up naked.

Base-game look: black panels, white text, MULTIcore's fonts. No floating 3D text, no marker dots.

## Setup
1. Put `MULTItailor` in `resources/[multicore]`.
2. `server.cfg`, after MULTIcore, MULTItarget and MULTIinventory:
   ```
   ensure MULTIinventory
   ensure MULTItailor
   ```
3. Do **not** run `rsg-wardrobe` as well (MULTItailor answers its calls).
4. Tables are made on start (`sql/install.sql` has the same statements).
5. The tailor jobs and the tailoring items come with MULTIcore (`shared/jobs.lua`, `shared/items.lua`). The clothing
   items (`clothing_*`) come with MULTIinventory. Item pictures: put them in MULTIimages (`fabric.png`, `cloth.png` ...).
6. Language: `setr multicore_locale de` (all MULTI scripts), or `Config.Locale`. Ten languages:
   en, de, es, fr, it, nl, pl, pt-br, ru, tr (`locales/*.json`).

Needs: `oxmysql`, `ox_lib`, `MULTIcore`, `MULTIinventory`, `MULTItarget`.

## Jobs and items
| Jobs | |
|---|---|
| `tailor` | works at every tailor shop |
| `valtailor`, `blacktailor`, `strawtailor`, `rhodestailor`, `stdentailor`, `tumbletailor`, `armadtailor`, `vantailor`, `annetailor` | the town's own shop only |

Grades 0-4: Apprentice, Journeyman, Senior Journeyman, Cutter, Master Tailor. Grade 4 (or any `isboss` grade) runs
the till and the office.

Items: `fabric`, `cloth`, `brass_button` (sewn at the cutting table from `cotton`, `wool`, `twine`, `copper`), and
`leather`, `tanned_fur` for hats, boots, belts and cloaks; `tailor_licence`. Players get the raw materials from farms,
ranches, mines and trade stores (add them to your stores as you like).

## Config
| File | What |
|---|---|
| `config.lua` | language, target, admin ACE, MULTIcore look (mirror, first-load import, re-apply delay), quick toggles, outfits, rate limits |
| `config/stores.lua` | clothes stores (clerk spots, prices per category, stock, the ready-made lines, try-on camera), wardrobe points |
| `config/tailor.lua` | jobs and towns, boss grade, stockroom, the 31 designer categories and their materials, dye lots, camera, sewing, counter, orders, till |
| `config/locations.lua` | tailor shop points per town job (cutting table, counter, office, stockroom, fitting room) |
| `html/fonts.css` | text sizes for this script (fonts and colours come from MULTIcore's theme) |

Store, shop and wardrobe positions are default positions: check them in game and adjust to your map.

## Commands
| Command | Who | What |
|---|---|---|
| `/clothes` | everyone | quick toggles (`Config.Toggles.command`) |
| `/outfits` | everyone | saved outfits anywhere (`Config.Outfits.command`; set `''` to allow them only at stores and wardrobes) |
| `/tailorstores` | admin (ACE `multitailor.admin`, or group admin / god) | add a store where you stand, move the clerk, rename, open / close, map blip, price level, clerk model, remove / restore. Saved in `multitailor_stores`, live for everyone |

## How wearing works
1. Buying, cutting or unpacking makes clothing items (`exports.MULTIinventory:CreateClothingItem` / `CreateOutfitBundle`).
2. Equipping one puts it in its equipment slot; MULTIinventory puts it on the ped.
3. MULTItailor copies the worn pieces into the MULTIcore look (`exports.MULTIcore:SaveLook(src, 'comps', ...)`); hair,
   body and anything outside the equipment slots stays as it was.
4. Whenever MULTIcore puts the saved look back on (`MULTIcore:client:lookApplied`), MULTItailor puts the worn items on
   again, and toggled-off pieces stay off.

## rsg-wardrobe calls (RSG v2 names and arguments)
| Call | Side | What |
|---|---|---|
| `exports['rsg-wardrobe']:ToggleClothing(name)` | client | takes that piece off / puts it back (`hat`, `masks`, `coats`, `vest`, `glove`, `shirt`, `pants`, `boots` ...) |
| `exports['rsg-wardrobe']:RemoveAllClothing()` / `RemovePlayerClothing()` | client | takes everything off for the moment |
| `exports['rsg-wardrobe']:DressPlayer()` | client | puts everything back on |
| `exports['rsg-wardrobe']:IsWearing(name)` | client | boolean |
| `exports['rsg-wardrobe']:TogglePlayerClothing(source, name)` / `RemovePlayerClothing(source)` / `DressPlayer(source)` | server | the same for a player |
| `rsg-wardrobe:client:OnOffClothing (name)`, `rsg-wardrobe:client:removeAllClothing`, `MULTItailor:client:dress` | client events | the same |
| `MULTItailor:client:openOutfits` | client event | opens the outfit list |

## Exports (server: `exports.MULTItailor:<Name>`)
| Export | Returns |
|---|---|
| `CreateGarment(src, { cat, hash, sex, label, description?, palette?, tints? })` | `ok, err` - hands one garment over as a clothing item |
| `OpenOutfits(src)` | opens the outfit list for that player |
| `MirrorLook(src)` / `SeedClothing(src)` | write the worn items into the look now / run the first-load check now |
| `GetTailoringCategories()` | `{ { id, label, vorp, tag, group, keep } }` |
| `GetClothesStores()` / `GetStoreCatalogue()` | stores / the ready-made lines |
| `GetTillBalance(businessId)` | number |
| `GetOutfitComponents(metadata)` / `IsTailoredOutfit(itemName)` | for old `tailored_outfit` items (using one turns it into a `clothing_outfit` bundle) |
| `RegisterDynamicLocation(def)` / `UpdateDynamicLocation` / `RemoveDynamicLocation(id)` / `ReloadDynamicLocations(list)` / `GetDynamicLocations(owner?)` / `GetStationTemplates()` / `GetJobSetupInfo()` / `GetDynamicLocationsApi()` | place tailor points live (trade `tailor`; kinds craft / boss / store / storage) |

Server events (`AddEventHandler`): `MULTItailor:cut`, `MULTItailor:sewn`, `MULTItailor:sale`, `MULTItailor:order`,
`MULTItailor:storePurchase`, `MULTItailor:lookMirrored`, `MULTItailor:outfitWorn`.

## Optional extras
Nothing here is needed; each is used only while the resource runs.
- **Licence office** (`Config.Licence`): a resource with a `CanUseJobFeature` export (e.g. RINGOjobsandcrafting) can
  require a valid tailor licence for counter sales.
- **NPC clothing** (`Config.NpcClothing`): with an NPC clothing resource that has the same API (RINGOnpcclothing),
  the Outfit Designer gets an NPC clothing section (`npc_garment` / `npc_outfit` items).

## Database
`multitailor_patterns`, `multitailor_till`, `multitailor_till_log`, `multitailor_shelf`, `multitailor_orders`,
`multitailor_stores`, `multitailor_meta` (also holds the per-character first-load flag `seed:<citizenid>`).
Saved outfits are MULTIinventory's (`multiinv_outfits`).

## Licence
GPL-3.0, part of MULTIcore by RINGO (RINGOscripting). Clothing data: femga's rdr3_discoveries (through MULTIcore's game data).
