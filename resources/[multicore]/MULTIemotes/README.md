# MULTIemotes

A basic emote menu for MULTIcore servers: the game's own emotes, scenarios and a few animations, a search box, favourites, and walk styles saved per character. Answers as RSG v2 `rsg-animations`.

GPL v3, like MULTIcore. See `CREDITS.md`.

## What it does

- **Emote menu** in the base-game look (black panel on the right of the screen, so you can watch your character). Pick a category with `‹ ›` (or the arrow keys): Favourites, Greetings, Gestures, Dances, Sitting and Lying, Smoking and Drinking, Work, Poses, Walk Styles. Enter or a click plays the selected row.
- **151 emotes**, every name checked against the game's data:
  - 75 **game emotes** (the kit emotes from the emote wheel: waves, hat tips, bows, taunts, reactions, dances). They play once. On horseback or in a wagon they play upper body only.
  - 70 **scenarios** (sit, lie down, smoke, drink, sweep, hammer, lean, stand guard ...). They loop until stopped; the game brings its own props.
  - 6 **animations** (dictionary + clip pairs that RSG v2 rsg-animations plays).
- **Search** across every category, by name in the player's language.
- **Favourites:** the star on a row. Kept on the player's own PC (client KVP), so they follow the player across characters on that server.
- **Stop:** the cancel key (default X), `/emotecancel`, or X while the menu is open.
- **Hands up (X)** and **point (B):** hold the key; let go to stop. Upper body only, so the player can still walk. Hands up puts the weapon away and blocks shooting; lawmen running MULTIlaw can search a player with hands up. While an emote, eating or crafting is running, X stops that instead. Settings: `Config.HandsUp` and `Config.Point` (key, hold or press-to-toggle, animation). B is also the game's own satchel key; MULTIemotes keeps that shut. Exports for other scripts: `exports.MULTIemotes:IsHandsUp()`, `exports.MULTIemotes:IsPointing()`.
- **Walk styles:** 20 styles (7 from RSG v2 rsg-radialmenu with the same ids, 13 locomotion archetypes the game's own scripts use). The choice is saved in the character's metadata (`walkstyle`, the same key rsg-radialmenu uses), shared through the player's `walkstyle` state bag so everyone nearby sees it, and put back on after spawn, respawn and every look reload. "Reset walk style" goes back to the game's own walk.
- No two-player (shared) emotes: no proven pair of animations is available in the reference data, so none are shipped.

## Setup

1. Put `MULTIemotes` in `resources/[multicore]/`.
2. `server.cfg`, after MULTIcore:
   ```
   ensure MULTIemotes
   ```
3. Remove `rsg-animations` from the server (`provide 'rsg-animations'`). rsg-radialmenu can stay: both use the same walk style key and ids.
4. Needs `ox_lib` and `MULTIcore`. No database table (walk styles live in the character's metadata).

## Commands

| Command | What it does |
|---|---|
| `/emotes` | opens the menu (also the key in the game's key settings, default F5) |
| `/e <name>` | plays an emote by id (`/e wave`) or by its name in any shipped language (`/e tip hat`); `/e` alone opens the menu |
| `/emotecancel` | stops the current emote |
| `/walk <style>` | sets a walk style by id or name (`/walk cowboy`); `/walk reset` clears it; `/walk` alone opens the walk styles |
| `/anim` | rsg-animations' command, opens the same menu |

Every command name is in `Config.Commands` (empty = off). PageDown is never bound.

## Settings (`config.lua`)

Commands, the open key, the cancel key, close-on-play, upper body on a horse, when emotes are blocked (dead, swimming, falling), animation load tries, the favourites KVP key and limit, the walk style key, cooldown and re-apply timing, notification time. Every option has a one-line comment.

- **Emotes:** `config/emotes.lua`. One line per emote: `id`, category, and `emote` (kit emote name), `scenario`, or `dict` + `clip` + `flag`. Remove a line to take an emote out; reorder lines to reorder the menu. Labels are `emote_<id>` in `locales/*.lua`.
- **Walk styles:** `config/walkstyles.lua`: `id`, `loco` (archetype), `motion` (`normal` / `angry`). Labels are `walk_<id>`.
- **Look:** `html/custom.css` (loaded last). For example `#em { justify-content: center; padding-right: 0; }` puts the menu in the middle.

## Exports

Client:

| Export | Returns |
|---|---|
| `PlayEmote(idOrName, body?)` | `true` or `false, reason`; `body` = `'full'` / `'upper'` |
| `PlayAnimation(idOrName, body?)` | `true` or `false, message` (rsg-animations' shape) |
| `StopEmote()` | `true` |
| `IsPlaying()` | `true` while an emote started here runs |
| `OpenMenu(tab?)` / `CloseMenu()` | `tab` = `'favourites'`, a category, or `'walk'` |
| `GetWalkstyle()` | the local player's walk style id or `nil` |
| `SetWalkstyle(id or nil)` | asks the server; `true` or `false, reason` |
| `GetFavourites()` | list of emote ids |

Server:

| Export | Returns |
|---|---|
| `GetWalkstyle(src)` | the character's walk style id or `nil` |
| `SetWalkstyle(src, id or nil)` | `true` or `false, reason` (`err_walk_unknown`, `err_not_loaded`); no cooldown |
| `GetWalkstyles()` | list of walk style ids |
| `GetEmotes()` | list of `{ id, cat, kind }` |

## rsg-animations compatibility

| Call | Behaviour |
|---|---|
| `exports['rsg-animations']:PlayAnimation(name, body)` (client) | looks `name` up by id or label in any shipped language (many rsg-animations labels such as `Tip hat`, `Applause`, `Flex` match ours; the rest are not found), plays it full or upper body; returns `true` or `false, message` |
| `rsg-animations:client:Open` (client event) | opens the menu |
| `rsg-animations:server:Open` (server event) | opens the menu for that player |
| `rsg-animations:server:Favorite (animation, favorite)` (server event) | sets or clears that emote as a favourite on the player's PC when its label matches |
| `/anim` | opens the menu |

Not carried over: the `favorites_animations` table (favourites are client KVP here).

## Languages

`en` (master), `de`, `fr`, `es`, `pt-br`, `it`, `pl`, `ru`, `nl`, `tr`. `Config.Locale`, or `setr multicore_locale <code>` for every MULTI script.
