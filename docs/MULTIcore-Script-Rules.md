# Making a MULTIcore script: the rules

*MULTIcore was founded and created by RINGO (RINGOscripting).*

Follow these and your script will look and behave like every other MULTI script, and it will be safe on a live server. The API itself is in `MULTIcore-API.md`, the target system in `MULTItarget-API.md`, and a working example in `MULTIstarter.zip`.

## The manifest

```lua
shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/lib/api.lua',      -- MC.*
    '@MULTIcore/shared/i18n.lua',  -- _L('key')
    'config.lua',
    'locales/*.lua',
}
client_scripts { '@MULTIcore/lib/ui.lua', '@MULTIcore/lib/interact.lua', 'client/main.lua' }   -- ox_lib menus in the MULTI look, MCI.*
server_scripts { 'server/main.lua' }
dependencies { 'MULTIcore', 'MULTItarget', 'MULTIinventory', 'ox_lib' }
```

**Every MULTI script lists `MULTItarget` in `dependencies`.** It is MULTIcore's own target system; do not use ox_target, rsg-target or qb-target directly.

## Look

The full UI rules, every theme class and a working example menu are in `MULTIcore-UI-Guide.md` and `MULTIcore-UI-Kit.zip`.

- **Base-game look:** black see-through panels, white text, a white frame on the selected row, game-style key prompts.
- For your own NUI page, link `nui://MULTIcore/html/theme/multi.css` first and use its classes and variables. Don't hard-code colours or fonts.
- Ship an empty, commented `html/custom.css`, loaded last, so server owners can restyle without touching your files.
- For small menus use ox_lib (`lib.registerContext`, `lib.inputDialog`, `lib.alertDialog`, `lib.progressBar`, `lib.showTextUI`) with `'@MULTIcore/lib/ui.lua'` loaded first: MULTIcore draws them in the base-game look.
- **No white marker dots, markers or sprites** on interaction points, ever. No floating 3D text.
- World interaction goes through MULTItarget (hold Left Alt). Use `MCI.AddZone` / `MCI.AddEntity` from `@MULTIcore/lib/interact.lua`; it falls back to hold-key prompts by itself.
- Never bind PageDown.

## Text

- **No text in code.** Every line goes in `locales/en.lua` (the master) as `['key'] = "Sold %s nuggets"`, then `_L('key', 3)` in Lua and `_LT()` to send all lines to your NUI page.
- Ship all 10 languages with the same keys: `en, de, fr, es, pt-br, it, pl, ru, nl, tr`. A missing line falls back to English.
- Put the class `mc-cyrillic` on your NUI root when the language is `ru`.

## Settings

- Everything a server owner might change goes in a commented `config.lua`, one line and one comment each. No magic numbers in code.
- Long lists (coordinates, shop stock) may go in `config/*.lua`.

## Notifications

Only through MULTIcore: `exports.MULTIcore:Notify({ text, title, type })` on the client, `exports.MULTIcore:Notify(src, { ... })` on the server. Types: `info`, `success`, `error`, `warning`.

## Items and money

- Register your items at start with `MC.RegisterItem(...)` (or `exports.MULTIinventory:RegisterItem(def)`). No SQL file is needed.
- Items in and out only through the API (`MC.GiveItem`, `MC.TakeItem`, `MC.CountItem`, `MC.CanCarry`) or MULTIinventory's exports.
- Money only through `MC.AddMoney` / `MC.RemoveMoney`. Check the return value before giving anything.
- **Prices are 1899-level** (RDR2's in-game prices, or historical 1899 prices). Keep cents. A buy-back price must be at most half the lowest sale price, so there are no money loops.

## Safety

1. **The server decides.** Never let the client say how much money or how many items. On the server, check distance (`GetEntityCoords(GetPlayerPed(src))`), job, amount and a cooldown.
2. **Check every return value** of `RemoveMoney` and `TakeItem` before giving anything.
3. Client calls (`MC.GetMoney()`, `MC.CountItem()` on the client) are for display only.

## Game names

Never invent a native, hash, animation, scenario, model, prop or control name. Check each one against a game data reference (native lists, animation and object lists) or working scripts before using it. Mark anything you could not check with `-- UNVERIFIED` and test it in game.

## Before you share it

- Every Lua file passes `luac -p` (swap backtick hashes for `joaat("...")` in a copy first).
- Look at every NUI screen with test data.
- Start it on a test server with MULTIcore and check the console for errors.
- A README with setup, every config option, commands and exports.
- GPL-3.0 is welcome but not required; say your licence in the README.
