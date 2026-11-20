# MULTIradial

The MULTIcore quick menu. Press **F6** (or type `/radial`): the MC crest in the middle, buttons on both sides, Cancel underneath. Buttons with a › open a sub menu; Cancel turns into Back there (Esc, Backspace or a right click go back too).

Standard buttons (each one only shows when its script runs):
- **Clothing**: hat, mask, neckwear, eyewear, coat, vest, gloves, gun belt, shirt, trousers, boots, satchel (take off / put back on, the menu stays open), dress fully, take all off (MULTIclothing)
- **Emotes**, **Walk style** (MULTIemotes)
- **Satchel** (MULTIinventory)
- **Horse & wagon**: find my horse, send horse away, my wagons (MULTIhorses, MULTIwagons)
- **Telegrams** (MULTItelegram), **Crafting** (MULTIcrafting)
- **Settings**: show / hide HUD, move the HUD, reset the HUD, stop emote

## Setup
`ensure MULTIradial` after MULTIcore and the scripts it opens. Do not run rsg-radialmenu as well: MULTIradial answers in its place.

## Config (`config.lua`)
- `Config.Keybind` key name from MULTIcore `shared/keybinds.lua` (default `F6`), `Config.HoldToOpen` hold instead of tap, `Config.Command`, `Config.Scale` (size), `Config.PerPage` (buttons per page, more go under "More").
- `Config.Menu`: the buttons. Each has a `label` (locale key) and an `icon` (Font Awesome name) and one of `items` (sub menu), `command`, `event` (+ `server = true`), `clothing` (rsg-wardrobe name), `dress` / `undress`. Optional `resource` (only shown while that script runs) and `job` (only for these jobs).

Texts are in `locales/<lang>.lua` (en, de, es, fr, it, nl, pl, pt-br, ru, tr). Restyle in `html/custom.css`.

## rsg-radialmenu compatibility
RSG v2 scripts that add buttons keep working: `exports['rsg-radialmenu']:AddOption(data, id)` / `RemoveOption(id)` with RSG's option format (`title`, `icon`, `items`, `type` = client / server / command / rsgcommand, `event`, `action`, `canOpen`, `shouldClose`), and the `rsg-radialmenu:client:onRadialmenuOpen` / `onRadialmenuClose` events.

## Licence
GPL v3. The option format and exports follow RSG v2's rsg-radialmenu (GPL v3); no code was copied. Icons: Font Awesome Free (loaded from cdnjs).
