# MULTIhud

The HUD and needs system for MULTIcore. GPL v3.

- Compact gauges (rings or bars) for health, stamina, hunger, thirst, stress, cleanliness and the temperature where the player stands.
- Horse health and stamina while riding.
- Cash, gold and bank: always, while the game's "reveal HUD" key is held, or off. It also shows for a moment when money changes.
- Voice indicator when MULTIvoice (or pma-voice) is running (talking, voice range, radio).
- Hidden in the pause menu, in cutscenes, during fades and loading screens, and before a character is loaded. `/hud` hides or shows it for that player.
- Server-side needs: hunger, thirst and cleanliness drop over time, faster when running, sprinting or swimming, and faster in cold or heat. At 0 hunger or thirst the player loses health. Shooting raises stress, which goes down again after a quiet spell.
- Stands in for **vorp_metabolism** (`provide 'vorp_metabolism'`), so VORP food and drink scripts work.
- Answers the **rsg-hud** events RSG scripts send (`provide 'rsg-hud'`), so rsg-consume, rsg-canteen, rsg-bathing, rsg-essentials and rsg-medic work.

Needs are stored in the character's RSGCore metadata (`hunger`, `thirst`, `cleanliness`, `stress`, 0-100) and mirrored to the player's state bag (`LocalPlayer.state.hunger` ...), the same as rsg-core does.

## Setup
1. Put `MULTIhud` in `resources/[multicore]`.
2. In `server.cfg`, start it after MULTIcore (see MULTIcore's base set order): `ensure MULTIhud`.
3. Do **not** run `vorp_metabolism` or `rsg-hud` as well; MULTIhud takes their place.
4. Optional: `setr multicore_locale de` picks the language for all MULTI scripts.

## Config
Everything is in `config.lua`, one comment per option:
- `Config.TickSeconds`, `Config.Decay` (per minute), `Config.ActivityMultiplier`, `Config.Defaults`.
- `Config.Starving`: damage at 0 hunger / thirst, whether it can kill, notification.
- `Config.Stress`: stress from shooting, cooldown, exempt jobs, recovery.
- `Config.Temperature`: units, cold / hot limits and their effect on decay.
- `Config.Hud`: style (`ring` / `bar`), position and offsets, scale, gauge size, colours, which gauges show and their order.
- `Config.Money`: when the money panel shows.
- `Config.Vorp`, `Config.Rsg`: turn the compatibility layers on or off.

Text is in `locales/<lang>.lua` (en, de, fr, es, pt-br, it, pl, ru, nl, tr). Extra styling goes in `html/custom.css`.

## Commands
- `/hud` (name in `Config.Hud.Command`): hide / show the HUD. Remembered on the player's PC.
- `/hudedit` (`Config.Hud.EditCommand`): move the HUD. Drag it with the mouse, mouse wheel = size, then Save (Enter), Standard place (R) or Cancel (Esc). Saved on the player's PC.
- `/hudreset` (`Config.Hud.ResetCommand`): put the HUD back in its standard place (`Config.Hud.Position`, centre bottom by default).

## Events it answers
VORP (client, from the vorp_metabolism docs; Hunger and Thirst 0-1000, Metabolism -10000..10000):
- `vorpmetabolism:changeValue (status, amount)`, `vorpmetabolism:setValue (status, value)`
- `vorpmetabolism:getValue (status, cb)` (local only)
- `vorpmetabolism:setHud (visible)`
- Besides `Hunger`, `Thirst` and `Metabolism`, it also accepts `InnerCoreHealth`, `InnerCoreStamina`, `OuterCoreHealth`, `OuterCoreStamina` and `Stamina` and applies them to the player's own cores.

RSG (as RSG v2 scripts send them; values 0-100):
- client: `hud:client:UpdateHunger (v)`, `hud:client:UpdateThirst (v)`, `hud:client:UpdateCleanliness (v)`, `hud:client:UpdateStress (v)`, `hud:client:UpdateNeeds (hunger, thirst, cleanliness)`, `hud:client:RelieveStress (amount)`, `hud:client:GainStress (amount)`, `hud:client:OnMoneyChange`
- server: `hud:server:GainStress (amount)`, `hud:server:RelieveStress (amount)`

## Exports
Server:
- `exports.MULTIhud:GetNeeds(src)` returns `{ hunger, thirst, cleanliness, stress, metabolism }`
- `exports.MULTIhud:GetNeed(src, key)`
- `exports.MULTIhud:SetNeed(src, key, value)` / `AddNeed(src, key, delta)` / `SetNeeds(src, { hunger = 100 })`

Client:
- `exports.MULTIhud:GetNeeds()`
- `exports.MULTIhud:SetVisible(bool)`: hide the HUD from another script (for example while a menu is open)
- `exports.MULTIhud:ShowMoney(seconds)`

## Credits
Event names and argument orders for the RSG side come from how the RSG v2 framework scripts (GPL v3) call them; no code was copied. The VORP side follows the public vorp_metabolism documentation; no VORP code was used.
