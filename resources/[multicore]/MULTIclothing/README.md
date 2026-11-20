# MULTIclothing

Clothing stores, wardrobes, saved outfits and quick clothing toggles for **MULTIcore**. Part of the MULTIcore base set. Licence: GPL v3.

MULTIclothing edits a character's **clothing (`comps`) only**. Face, body, hair and beard belong to MULTIcreator (creator and barber).

## What it does

- **Clothing stores** in Valentine, Rhodes, Saint Denis, Blackwater, Strawberry, Armadillo and Tumbleweed, with map blips.
  - Every clothing category in the look data for the character's sex (body pieces are never sold).
  - Browse pieces by number, jump to a number, take a piece off, go back to what you own.
  - Palette and three tint sliders per piece.
  - Live preview on your own character. The camera frames the head, torso, legs or feet for the category you pick, and you can turn the character.
  - Basket with a price per category and a running total. The server works the price out again from the saved look and takes it in **cash**. Taking a piece off is free, and a colour change on a piece you already own costs part of the price.
  - Leave (or `Esc`) puts your saved look back.
- **Outfits**: save what you are wearing under a name, then wear, rename or delete it. You can use outfits at any store and at the wardrobe points. `/outfits` can be switched on in the config to open them anywhere.
- **Quick toggles**: `/clothes` opens a menu to take off and put back on your hat, mask, coat, gloves, neckwear and eyewear. Pieces come back from your saved look and nothing is saved.
- **rsg-wardrobe stand-in**: RSG v2 scripts that call `exports['rsg-wardrobe']` keep working (see below).

## Setup

1. Put the folder in `resources/[multicore]/`.
2. Start it after MULTIcore. The base-set order is `oxmysql, ox_lib, MULTIcore, MULTIhelpers, MULTIloading, MULTIcreator, MULTIcharacter, MULTIclothing, ...`.
3. Do **not** run `rsg-wardrobe` or `rsg-appearance` alongside it. MULTIclothing `provide`s `rsg-wardrobe`.
4. The `multicore_outfits` table is created on start (`CREATE TABLE IF NOT EXISTS`). No SQL file is needed.
5. Stores and wardrobes use MULTItarget (hold Left Alt, look at the spot) when it runs (`Config.Interact = 'auto'`); without it a hold-key prompt shows within `Config.PromptDistance`. `/mcinteract` (MULTIcore) prints how many targets and prompts were placed to the server console.

Needs: `oxmysql`, `ox_lib`, `MULTIcore` (its look library: `ApplyComp`, `RemoveComp`, `ApplyComps`, `ApplyLook`, `ReloadLook`, `GetLook`, `GetData`; its server exports `GetLook` and `SaveLook`; `Notify`; `shared/i18n.lua`; `data/clothes.lua` and `data/appearance.lua`, which the server loads to check what clients send).

## Config (`config.lua`)

| Option | What it does |
|---|---|
| `Interact`, `PromptKey`, `PromptDistance`, `TargetRadius`, `TargetDistance` | `'auto'` (MULTItarget when it runs, else prompts), `'target'` or `'prompt'`; the prompt key and show distance (2.0 m), the MULTItarget sphere size and reach (2.0 m) |
| `UseRange` | How close the server requires a player to be to a store or wardrobe |
| `Blips` | Store and wardrobe blips on or off, their sprite, size and name |
| `Stores` | Each store's name (a locale key), prompt position, fitting spot (`fitting`), exit spot (`exit`) and whether it has a blip |
| `Wardrobes` | Wardrobe points (positions) where outfits can be used |
| `Outfits` | Most outfits a character can keep, longest name, and the optional `/outfits` command |
| `Toggles` | The `/clothes` command, and for each toggle its icon and the categories it switches (its label is the locale key `toggle_<id>`) |
| `Categories` | Shop order, side-menu group, camera framing and price for each category (labels are the locale keys `cat_<key>` and `group_<group>`) |
| `DefaultPrice` | Price for any category not listed in `Categories` |
| `RecolourFactor` | Share of the price charged for a colour change only |
| `NotSold` | Body categories that are never sold |
| `Camera` | Camera height, distance and field of view for each framing, the starting framing, how far one turn rotates, and the camera type |
| `AllowColours` | Show the palette and tint pickers |
| `Locale` | Language for this script (empty = the server-wide `multicore_locale` convar, else English) |
| `Currency`, `MoneyReason` | Money sign on the store page, and the reason written to the money log |
| `OtherGroup`, `OtherCam` | Group and camera for categories that `Categories` does not list |
| `Icons`, `TargetIconStore`, `TargetIconWardrobe` | Font Awesome icons for menus and MULTItarget |
| `Timing` | Fades, camera blend, settle pause, death check and preview delay, in milliseconds |

Prices are in 1899 dollars, for example hats $5, boots $8 and coats $12.

## Languages

Every word players see comes from `locales/<lang>.lua`: menus, prompts, blips, notifications and the whole store page, category names included. The page gets the table from Lua. Shipped languages: `en` (the master), `de`, `fr`, `es`, `pt-br`, `it`, `pl`, `ru`, `nl` and `tr`, all with the same keys. Pick one server-wide with `setr multicore_locale de`, or for this script only with `Config.Locale`. With `ru` the page switches to the theme's Cyrillic fonts.

Clothing piece names (for example "Hat 011 Tint 002") are made from the game's own item names. Pieces with no known name show the locale line `ui_style_n`.

## Notifications

All messages go through MULTIcore's `exports.MULTIcore:Notify`, so they look like every other MULTI, RSG and VORP message on the server.

## Restyling

`html/custom.css` is empty and loads last, after the MULTIcore theme and the store layout. Put your own CSS there.

## Commands

| Command | What it does |
|---|---|
| `/clothes` | Quick toggles (`Config.Toggles.Command`, can be turned off) |
| `/outfits` | Outfit list anywhere (off by default, `Config.Outfits.Command`) |

## Exports and events

### rsg-wardrobe compatibility
MULTIclothing registers these under both `MULTIclothing` and `rsg-wardrobe`, so `exports['rsg-wardrobe']:X()` reaches it. It uses the same export-alias technique as MULTIcore's `shared/alias.lua`. The names and arguments match RSG v2 rsg-wardrobe.

**Server**
- `DressPlayer(source)` puts the character's saved clothing back on.
- `RemovePlayerClothing(source)` takes every clothing piece off (body stays).
- `TogglePlayerClothing(source, name)` takes one piece off or puts it back on.

**Client**
- `ToggleClothing(name)` takes one piece off or puts it back on.
- `RemoveAllClothing()` takes every clothing piece off.
- `IsWearing(name)` returns `true` if the piece is owned and currently on.
- `DressPlayer()` and `RemovePlayerClothing()` are client-side versions of the server exports.

`name` is an rsg-wardrobe clothing name: `hat`, `glove`, `shirt`, `vest`, `closedcoats`, `buckles`, `holster_left`, `coats`, `boots`, `pants`, and so on. A MULTIcore category name (`hats`, `gloves`, ...) also works. rsg-wardrobe's `sleeve`, `collar1` and `collar2` have no equivalent in the look format and do nothing.

The net events `rsg-wardrobe:client:OnOffClothing (name)` and `rsg-wardrobe:client:removeAllClothing` are also handled.

### Server callbacks (ox_lib)
- `MULTIclothing:buy (storeId, comps)` returns `ok, total | reason`.
- `MULTIclothing:outfits:list` returns `{ id, name }[]`.
- `MULTIclothing:outfits:save (name)`.
- `MULTIclothing:outfits:rename (id, name)`.
- `MULTIclothing:outfits:delete (id)`.
- `MULTIclothing:outfits:wear (id)`.

## Database

`multicore_outfits (id, citizenid, name, comps LONGTEXT, created)`. `comps` uses the MULTIcore look format: category to `{ index, palette, tint0, tint1, tint2 }`.

## Credits

- Store positions, fitting and exit spots, wardrobe (cloakroom) positions, blip sprites and style, and the rsg-wardrobe export names come from the **RSG v2 framework** (`rsg-appearance` and `rsg-wardrobe` configs and exports, GPL v3, by the RSG team). No RSG code is copied.
- Clothing data: MULTIcore `data/clothes.lua` (from femga/rdr3_discoveries).
