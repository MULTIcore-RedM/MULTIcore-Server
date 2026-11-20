# MULTIappearance

A small stand-in for **rsg-appearance** so unchanged RSG v2 scripts keep working on **MULTIcore**. Part of the MULTIcore base set. Licence: GPL v3.

It has no creator, store or menu of its own. Characters are made in MULTIcreator, clothes are bought in MULTItailor (clothing items), and looks are stored by MULTIcore. MULTIappearance only answers the `rsg-appearance` exports and events, translating RSG's data shapes to MULTIcore's look format and back.

## Setup

1. Put the folder in `resources/[multicore]/`.
2. Start it after MULTIcore, MULTIinventory and MULTItailor, before any RSG scripts:
   `oxmysql, ox_lib, MULTIcore, ..., MULTIinventory, MULTItailor, MULTIappearance, ...`
3. Do **not** run `rsg-appearance` as well. MULTIappearance `provide`s `rsg-appearance`.

Needs: `oxmysql`, `ox_lib`, `MULTIcore` (client: `GetLook`, `ApplyLook`, `ApplyComps`, `ReloadLook`; server: `GetLook`, `SaveLook`; `data/clothes.lua` and `data/appearance.lua`). Saved outfits are MULTIinventory's (lists of clothing items) and only work while MULTIinventory is running.

## How shapes are translated

- **Clothes.** RSG keeps `{ [category] = { hash, palette, tint0, tint1, tint2 } }`. MULTIcore keeps `{ [category] = { index, palette, tint0, tint1, tint2 } }`, where `index` points into `MULTIData.Clothes[sex][category]`. RSG's categories are the game's own names (`hats`, `shirts_full` ...), the same ones MULTIcore uses. A piece is found by its hash, and the palette hash becomes a palette index (and back again).
- **Skin.** RSG's skin table (its own head, skin tone, body size, face slider and overlay numbering) has **no** MULTIcore mapping. Skin calls load or save the MULTIcore look instead (see the table below).
- An RSG clothes entry in the old `{ model, texture }` form, or a hash MULTIcore does not know, is skipped. With `Config.Debug = true` the skipped categories are printed.

## Supported calls

### Client exports (`exports['rsg-appearance']` and `exports.MULTIappearance`)

| Call | What it does now |
|---|---|
| `GetClothesCache()` | The saved clothing in RSG shape: `{ [category] = { hash, palette?, tint0?, tint1?, tint2? } }` |
| `GetClothesComponentId(category)` | One entry of the cache above, or nil |
| `GetClothesCurrentComponentHash(category)` | Hash of the saved piece in that category, `0` when none (rsg-appearance had a bug here and always returned nil) |
| `GetClothesComponents()` | `{ male, female }`, each `{ [category] = { hash, ... } }` for every clothing piece MULTIcore knows |
| `IsCothingActive()` | `LocalPlayer.state.inClothingStore == true` (deprecated in RSG too) |
| `GetComponentId(name)` | `sex` gives 1 or 2, `head` gives the index, `height` gives the scale. `hair`, `beard`, `eyes` and `teeth` give `{ hash }` (hash `0` when none). Anything else gives nil |
| `GetBodyComponents()` | `{ male, female }`, each with `BODIES_UPPER`, `BODIES_LOWER`, `heads`, `eyes`, `teeth`, `hair` and `beard` hash lists |
| `GetBodyCurrentComponentHash(name)` | Hash of the worn `hair`, `beard`, `BODIES_UPPER`, `BODIES_LOWER`, `heads`, `eyes` or `teeth`. Nil when none |
| `GetComponentsMax(name)` | Number of pieces in that category or body part |
| `GetMaxTexturesForModel(category, model)` | Always `1`. MULTIcore pieces have no model / texture split |
| `ApplySkin()` | Loads the character's saved look (`exports.MULTIcore:ReloadLook()`) and keeps health if the model changes. Waits until done, like RSG |
| `ApplySkinMultiChar(skin, ped, clothes)` | A MULTIcore-format skin gets the full look (`ApplyLook`). For an RSG-format skin, only the clothes are put on |
| `SetFaceOverlays`, `SetHair`, `SetBeard` | Accepted and ignored (RSG creator data). Use MULTIcreator |

### Client events

| Event | What it does now |
|---|---|
| `rsg-appearance:client:ApplyClothes (clothes, ped?)` | Translates the clothes and puts them on with `ApplyComps(ped, comps, true)`. It adds pieces and does not take others off, like RSG. MULTIcore `{ index }` pieces are accepted too. A ped handle is used only when the event is fired locally |
| `rsg-appearance:client:ApplySkin` | Loads the saved MULTIcore look. The RSG data sent with the event is ignored |
| `rsg-appearance:client:outfits` | Opens MULTItailor's outfit list (only while MULTItailor is running) |
| `rsg-appearance:client:OpenCreator` | Ignored. MULTIcharacter and MULTIcreator handle character creation |

### Server events and callbacks

| Event / callback | What it does now |
|---|---|
| `rsg-appearance:server:LoadSkin` | Tells the client to load its saved look. If there is no look yet, nothing happens (RSG opened its creator) |
| `rsg-appearance:server:LoadClothes` (ox_lib callback) | Returns the saved clothing in RSG shape |
| `rsg-appearance:server:LoadClothes` (plain event, as rsg-multicharacter fires it) | Ignored. `LoadSkin` already applies the clothes |
| `rsg-appearance:server:SaveSkin (skin, clothes, oldplayer)` | Off by default (`Config.AllowClientSaves`). When it is on, a MULTIcore-format skin is saved, an RSG skin is skipped, and the clothes are translated and saved (merged into the saved clothes when `oldplayer`) |
| `rsg-appearance:server:saveOutfit (clothes, isMale, name)` | Saves a named outfit in MULTIinventory: the clothing items the character wears now. The clothes sent never become items; with `AllowClientSaves` on they only change the saved look, with no charge |
| `rsg-appearance:server:saveUseOutfit (clothes)` | Wears the character's saved outfit whose pieces match the clothes sent (only pieces the character owns go on) |
| `rsg-appearance:server:DeleteOutfit (name)` | Deletes the character's saved outfit with that name |
| `rsg-appearance:server:getOutfits` (ox_lib callback) | `{ { id, citizenid, name, clothes } }`, with the clothes in RSG shape |
| `rsg-appearance:server:SetPlayerBucket (bucket, random)` | A random private bucket (`Config.Bucket.AllowRandom`), or bucket 0. Other numbers only with `Config.Bucket.AllowAny` |
| `rsg-appearance:server:deleteSkin`, `rsg-appearance:server:updategender` | Ignored. MULTIcore handles character deletion and sex |

## Not supported

- RSG's skin format (`skin_tone`, `body_size`, `body_waist`, `chest_size`, face sliders, `*_t / *_op / *_c1` overlays, `hair` / `beard` as `{ model, texture }`). It cannot be translated, so it is never saved, and scripts get the MULTIcore look instead.
- RSG clothes given as `{ model, texture }` (the creator's numbering before it converts them to hashes).
- rsg-appearance's store prices. No money is taken by any of these events, so clothing changes from clients are off by default.
- `onClientResourceStart` checks for the name `rsg-appearance` (rsg-radialmenu re-applies walk styles on it). The resource is called MULTIappearance, so that check never fires. Walk styles still re-apply on `RSGCore:Client:OnPlayerLoaded`.

## Config (`config.lua`)

| Option | Default | What it does |
|---|---|---|
| `Debug` | `false` | Prints each translated or ignored call |
| `AllowClientSaves` | `false` | Lets `SaveSkin` and `saveOutfit` change the saved look with whatever the client sends (never creates clothing items) |
| `Bucket.AllowRandom` / `AllowAny` / `RandomMin` / `RandomMax` | `true` / `false` / `1000` / `9999` | Which routing buckets `SetPlayerBucket` may move a player to |
| `Outfits.UseInventoryOutfits` / `NameMax` | `true` / `40` | rsg-appearance outfit calls use MULTIinventory's saved outfits. Keep `NameMax` equal to MULTItailor's `Config.Outfits.nameMax` |
| `KeepHealthOnApplySkin` | `true` | `ApplySkin()` restores health when the model is reloaded |

## Credits

Export and event names, and their argument and return shapes, come from **rsg-appearance** in the RSG v2 framework (GPL v3, by the RSG team). No RSG code is copied.
