# MULTIloading

The MULTIcore loading screen: the server name, a line under it, rotating tips and a progress bar driven by the game's own load messages. Same look as the other MULTI scripts (dark worn paper, serif titles).

Licence: GPL v3, like MULTIcore.

## Setup
```
ensure MULTIloading
```
Start it before MULTIcharacter. The fxmanifest sets `loadscreen_manual_shutdown 'yes'`, so the screen stays up until MULTIcharacter has the character select scene ready and closes it. Without MULTIcharacter (or another script that calls `ShutdownLoadingScreenNui`) the screen does not go away on its own.

Only one loading screen resource can run on a server.

## Config (`html/config.js`)
The loading screen runs before any Lua, so its settings and texts are in `html/config.js`, not in `config.lua` / `locales/`.

| Option | Meaning |
|---|---|
| `language` | `en`, `de`, `fr`, `es`, `pt-br`, `it`, `pl`, `ru`, `nl`, `tr` (`ru` switches to Cyrillic fonts) |
| `serverName` | big title |
| `useHandoverName` | use the name a server script passes with `deferrals.handover({ name = '...' })`, if any |
| `logo` | logo above the server name, in `html/img/` (default `'img/mc-logo.png'`, the MULTIcore logo); empty = no logo |
| `background` | optional image in `html/img/`, e.g. `'img/background.jpg'`; empty = plain black |
| `backgroundShade` | darkening over the image, 0 to 1 |
| `tipSeconds`, `tipFadeMs`, `tipMinSeconds` | tip timing |
| `texts.<lang>` | `subtitle`, `tipLabel`, `loadingLabel`, `readyLabel`, `mapLabel`, `tips` for each language (same keys everywhere; English fills gaps) |

## Restyling
`html/custom.css` loads last and is empty; put your own CSS there.

The MULTIcore logo (`html/img/mc-logo.png`, about 0.2 MB) is the only image shipped; its size is set with `--ml-logo-size` in `custom.css`. Any file put in `html/img/` is sent to players with the loading screen, so keep it small (a 1920x1080 JPG of a few hundred KB).

## Notes
- The theme values are copied into `html/style.css` instead of linking `nui://MULTIcore/html/theme/multi.css`, because the loading screen shows before that link can be relied on. If you restyle the theme, change both.
- Fonts: the game-style fonts are used when their files are in `html/fonts/` (see the README there); otherwise close free fonts load from Google Fonts, and without internet the browser's own fonts are used.
- Progress uses the CitizenFX loading-screen messages `loadProgress`, `startInitFunctionOrder`, `initFunctionInvoking`, `startDataFileEntries`, `onDataFileEntry`, `performMapLoadFunction`, `endDataFileEntries`, `endInitFunction` and `onLogLine`.

## Commands / exports
None.
