# MULTIcharacter

Character select for MULTIcore: up to 5 characters per account, a preview of each one wearing its look, new character (through MULTIcreator), delete with typed-name confirmation, a spawn picker (last location plus towns) and the first spawn of a new character.

Licence: GPL v3, like MULTIcore.

## What it does
1. When the player joins (and after `/logout`), the player is hidden and frozen, a camera is set up at the select scene and the loading screen (MULTIloading) is closed.
2. The panel lists the account's characters: name, job, cash, gold, birth date. Clicking a card shows that character in the scene, dressed with its stored look. Drag on the screen to turn it.
3. **Play** logs the character in, then the spawn picker offers the last saved position and the configured towns. The player model and look are loaded, the player is placed once collision has loaded, and the screen fades in.
4. **New character** opens MULTIcreator. When it returns a look and details, the character is created and spawned at `Config.NewPlayerSpawn`. Cancelling returns to select.
5. **Delete** asks for the character's full name to be typed before it is removed.

## Setup
Start order (server.cfg):
```
ensure oxmysql
ensure ox_lib
ensure MULTIcore
ensure MULTIhelpers
ensure MULTIloading
ensure MULTIcreator
ensure MULTIcharacter
```
Do not run `rsg-multicharacter`, `rsg-spawn` or `vorp_character` alongside it.

## RSG v2 compatibility
The fxmanifest has `provide 'rsg-multicharacter'` and `provide 'rsg-spawn'`, so RSG scripts that list those as dependencies start. Their client events are handled with the same meaning:

| Event | What MULTIcharacter does |
|---|---|
| `rsg-multicharacter:client:chooseChar` | back to character select (logs out first if a character is still loaded) |
| `rsg-multicharacter:client:closeNUI` | closes the select panel |
| `rsg-spawn:client:newplayer` | first spawn of a just-created, logged-in character (`Config.NewPlayerSpawn`, or the town picker with `Config.NewPlayerPicker = true`) |
| `rsg-spawn:client:setupSpawnUI (cData, new)` | `new == false`: spawn picker for the logged-in character; otherwise as `newplayer` |

## Config (`config.lua`)
| Option | Meaning |
|---|---|
| `Locale` | language for this script; nil = `setr multicore_locale` in server.cfg, else English |
| `MaxCharacters` | most characters per account (the account's own slot count also applies) |
| `Scene` | where the preview character stands, the camera, idle scenario, turn speed, collision wait |
| `DefaultLook` | look for characters that have none stored |
| `NewPlayerSpawn` | first spawn of a new character |
| `NewPlayerPicker` | RSG `newplayer` event: town picker instead of the fixed spawn |
| `AllowLastLocation` | offer the last saved position |
| `SpawnLocations` | towns in the spawn picker (`id` + coords; names in the locale files as `loc_<id>` / `loc_<id>_desc`) |
| `SpawnCollisionTimeout` | longest wait for collision at the spawn point |
| `Timing` | fades and waits |
| `Logout` | command name, ACE, cooldown, allowed while dead |
| `NotifyError`, `NotifySuccess` | MULTIcore notify types used |

## Languages
Every text is in `locales/<lang>.lua`: `en` (master), `de`, `fr`, `es`, `pt-br`, `it`, `pl`, `ru`, `nl`, `tr`, all with the same keys. Pick one server-wide with `setr multicore_locale de`, or for this script only with `Config.Locale`. For `ru` the page switches to the theme's Cyrillic fonts. Adding a town to `SpawnLocations` means adding its `loc_<id>` and `loc_<id>_desc` lines to each locale (English is used where a line is missing).

## Restyling
`html/custom.css` loads last and is empty; put your own CSS there. Colours, fonts and sizes come from MULTIcore's theme variables.

## Notifications
All messages go through `exports.MULTIcore:Notify`, so they look like the rest of the server.

## Commands
- `/logout` (name in `Config.Logout.command`): saves and returns to character select.

## Events
- Client, fired: `MULTIcharacter:client:spawned (isNew)` after the player is placed and the screen fades in.
- Client, listened (local): `MULTIcharacter:client:logout` asks the server to log the player out.
- Server, listened: `MULTIcharacter:server:logout`.
- Server callback: `MULTIcharacter:slots` returns this account's slot count.

## Uses
- MULTIcore callbacks `MULTIcore:chars:list / create / select / delete` and client exports `ApplyLook`, `SetPlayerModel`, `ReloadLook`.
- `exports.MULTIcreator:Open('create', cb)`.
- UI theme `nui://MULTIcore/html/theme/multi.css`.

## Credits
Coordinates from the RSG v2 framework (GPL v3; RSG / Rexshack-RedM and contributors): the select scene and camera from rsg-multicharacter, Valentine and Saint Denis spawns from rsg-spawn, the other town spawns from rsg-medic's respawn points. No RSG code is copied.
