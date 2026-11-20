# MULTIvorpchar (optional)

A small, **optional** stand-in for **vorp_character** so unchanged VORP scripts that read or change clothes keep working on **MULTIcore** when the character creator is MULTIcreator. Part of the MULTIcore base set. Licence: GPL v3.

It has no creator, store or menu of its own. Characters are made in MULTIcreator, clothes are bought in MULTIclothing, and looks are stored by MULTIcore. MULTIvorpchar only answers the `vorp_character` exports and events that VORP scripts use, translating vorp_character's data shapes to MULTIcore's look format and back.

**When to run it:** only on a server that uses MULTIcreator / MULTIcharacter. Without it, VORP scripts that check `GetResourceState('vorp_character')` see it missing and usually fall back to their RSG path (MULTIappearance answers rsg-appearance). Scripts that call `exports.vorp_character` without checking need it.

**Do not run it together with the real vorp_character.** If you use vorp_character as your creator, leave MULTIvorpchar out.

## Setup

1. Put the folder in `resources/[multicore]/`.
2. Start it after MULTIcore and MULTIclothing, before any VORP scripts:
   `oxmysql, ox_lib, MULTIcore, ..., MULTIclothing, MULTIappearance, MULTIvorpchar, ...`

Needs: `ox_lib`, `MULTIcore` (client: `GetLook`, `ReloadLook`, the `MULTIcore:look:save` callback and the `MULTIcore:client:lookApplied` event; `data/clothes.lua`, `data/appearance.lua`). `OpenOutfitsMenu` needs MULTIclothing.

## Config (`config.lua`)

| Option | Default | What it does |
|---|---|---|
| `Config.Debug` | `false` | Prints every call that is translated or ignored |
| `Config.ReloadCommand` | `'rc'` | vorp_character's reload command (scripts run it after changing clothes). Puts the saved look back on. `''` = no command |
| `Config.SaveWaitMs` | `3000` | Longest wait for a save to reach the server before a reload |
| `Config.Keys` | see file | vorp_character clothing key (`Hat`, `Shirt`, `Pant` ...) -> MULTIcore category (`hats`, `shirts_full`, `pants` ...) |

## How shapes are translated

- **Clothes.** vorp_character keeps `{ [Key] = { comp = hash, palette, tint0, tint1, tint2 } }`; `comp = -1` (or 0) means nothing worn there. MULTIcore keeps `{ [category] = { index, palette, tint0, tint1, tint2 } }`. A piece is found by its hash (first in the key's own category, then in any category) and the palette hash becomes a palette index (and back again).
- **Skin.** Only `Hair` and `Beard` (piece hash, -1 = none) have a MULTIcore meaning. Other skin keys (face overlays such as `scars_*`, body sizes) are ignored. Use MULTIcreator's barber for the rest.

## Supported calls

| Call | Side | What it does now |
|---|---|---|
| `exports.vorp_character:GetAllPlayerComponents()` | client | The saved clothes as `{ [Key] = { comp, palette?, tint0?, tint1?, tint2? } }` (keys with nothing worn are left out) |
| `exports.vorp_character:GetPlayerComponent(key)` | client | One entry of the table above, or `nil` when nothing is worn there. A MULTIcore category name works too |
| `exports.vorp_character:OpenOutfitsMenu(source)` | server | Opens MULTIclothing's outfit list for that player. `true` when it was opened, `false` when the player has no character or MULTIclothing is not running |
| `TriggerEvent('vorpcharacter:updateCache', nil, comps)` | client | Merges the clothes into the saved look. Seen after a reload (`rc`), as on VORP |
| `TriggerEvent('vorpcharacter:savenew', nil, skinKeys)` | client | Saves `Hair` / `Beard` into the saved look; other keys are ignored |
| `vorpcharacter:reloadedskinlistener` | fired, server | Sent by the client each time MULTIcore has put the saved look on (first spawn, `rc`, respawn, revive) |
| `vorpcharacter:reloadafterdeath` | fired, client | Fired locally after the look is back on after a respawn or revive |
| `/rc` | client command | Puts the saved look back on (`exports.MULTIcore:ReloadLook()`) |

Anything else of vorp_character (its creator, its own clothing stores and menus, `vorp:initNewCharacter`, the loading scene) is not answered. MULTIcharacter, MULTIcreator and MULTIclothing do those jobs.

Clothes changed through `updateCache` are saved the same way MULTIcore's own `MULTIcore:look:save` callback saves them: the client decides, with no charge, as on VORP.

## Credits
Argument shapes come from VORP's public documentation and from how VORP scripts call vorp_character. No VORP code was used.
