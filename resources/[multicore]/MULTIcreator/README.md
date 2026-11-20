# MULTIcreator

Character creator and barber for **MULTIcore** (free, GPL v3).

- **Creator** (`Open('create', cb)`): sex, skin tone, head, eye colour, teeth, body build, waist, torso and legs, height, body proportion sliders (arms, forearms, shoulders, back, chest, waist, hips, thighs, calves, neck; chest height and seat for women), every face slider (grouped: head, eyes, brows, ears, cheeks, jaw and chin, nose, mouth and lips), hair and beard with colours, skin overlays and make-up (pattern, variant, strength, palette and three tints), starting clothes with palette and tints, a Randomise button, and the identity form (first and last name, nickname, birth date, age, nationality, description).
- **Barber** (`Open('barber', cb)`): hair, beard, eyebrows, stubble and make-up only. The player pays cash, then the new look is saved.
- Camera per section (face / body / legs buttons), mouse wheel zoom, turn the character with A / D (or Q / E) or by dragging the mouse.
- A lit creator room and three barber shops with blips, a barber NPC and MULTItarget on the barber and his spot (hold Left Alt), or a hold-key prompt when MULTItarget is not running. `/mcinteract` (MULTIcore) prints what was placed to the server console.

Looks are stored in MULTIcore's `multi` format (see MULTIcore `docs/BASE_SET.md`) and put on the ped by MULTIcore's look library.

## Setup
1. Needs `ox_lib` and `MULTIcore`. `MULTItarget` recommended (used automatically when it runs).
2. In `server.cfg`, after MULTIcore and before MULTIcharacter:
   ```
   ensure MULTIcreator
   ```
3. MULTIcharacter opens the creator for new characters. Nothing else to set up.

## Config (`config.lua`)
Every option has a comment. The main ones:
- `Config.Locale`: language for this script ('' = the server-wide `setr multicore_locale`).
- `Config.Room`: where the creator ped stands, the light on it (rsg-appearance's spot and strength) and the screen look (`timecycle`).
- `Config.Cameras`: distance, height and field of view for the face / body / legs cameras.
- `Config.Height`: height limits. `Config.BodySliders`: show the body proportion sliders. Builds and waists come from MULTIcore's data.
- `Config.Overlays`: which skin overlays and make-up the creator offers (the ones rsg-appearance uses by default).
- `Config.CreatorClothing`, `Config.StartingClothes`: which clothing categories show in the creator and what a new character wears.
- `Config.OverlayVariants`: how many variants an overlay pattern has.
- `Config.Identity`: age limits, game year (the age follows the birth date), nationalities.
- `Config.Barber`: price, `interact` (`'auto'` = MULTItarget when it runs, else prompts; `'target'`; `'prompt'`), `promptKey` / `promptDistance` (2.0 m), `targetRadius` / `targetDistance` (2.0 m) / `targetIcon`, NPC, blips, which overlays the barber may change.
- `Config.BarberShops`: shop positions.
- `Config.Timing`: fades and waits.

## Languages
`locales/en.lua` is the master; `de`, `fr`, `es`, `pt-br`, `it`, `pl`, `ru`, `nl`, `tr` ship with the same keys. Overlay, clothing, feature and nationality names are locale keys too (`overlay_<name>`, `cloth_<category>`, `feat_<feature>`, `nation_<key>`, `shop_<id>`).

## Styling
The page uses MULTIcore's theme (`nui://MULTIcore/html/theme/multi.css`). Put your own CSS in `html/custom.css`; it loads last.

## Exports (client)
```lua
-- Full creator. cb(look, info) when finished, cb(nil) on cancel.
-- info = { firstname, lastname, gender, birthdate ('YYYY-MM-DD'), nationality, age, nickname, description }
exports.MULTIcreator:Open('create', function(look, info) end)

-- Barber. cb(true) when paid and saved, cb(false) on cancel or failure.
-- Optional third argument: a shop entry from Config.BarberShops (light, seat).
exports.MULTIcreator:Open('barber', function(saved) end)

exports.MULTIcreator:IsOpen() -- true while the page is open
```
`Open('create')` only builds the look and the identity; the caller creates the character (MULTIcharacter calls `MULTIcore:chars:create`).

## Server callbacks
- `MULTIcreator:barber:pay`: takes `Config.Barber.price` cash (player must be near a barber when `requireShop` is on).
- `MULTIcreator:barber:refund`: gives the money back once if the save failed within `refundWindowSec`.

## How skin tone and head are chosen
Heads in the game data are named `HEAD_<shape>_V_<tone>`: each head shape comes in six tones, and the bodies follow the same pattern (`BODIES_UPPER_<build>_V_<tone>`, `BODIES_LOWER_<build>_V_<tone>`). The menu shows **skin tone** and **head** separately and stores the matching head, upper body and lower body indexes, so face and body always share one tone. Tones are shown light to dark (rsg-appearance's order). Heads, bodies and eyes without a name in the game data are not offered (they draw white eyes and odd faces). Hair and beards are `<style>_<colour>` (17 colours) and show as a style stepper with colour swatches; unnamed hair pieces come after the named styles.

## Credits
- Barber shop positions: `rsg-barbers` config; creator room position, light and screen look, tone order: `rsg-appearance` (RSG v2 framework, GPL v3).
- The way the character is drawn (MULTIcore's look library) is ported from `rsg-appearance` (GPL v3); body sliders use femga's MetaPedExpression ids.
- Game data (clothes, overlays, face sliders, natives): femga's rdr3_discoveries.
- Licence: GPL v3 (see LICENSE).
