# MULTIcore API: making scripts for MULTIcore

*MULTIcore was founded and created by RINGO (RINGOscripting).*

MULTIcore runs RSG and VORP scripts unchanged. It also has its own short API for scripts made **only for MULTIcore**. A MULTIcore script:

- needs no SQL file (items register themselves at start),
- speaks 32 languages through `_L('key')`,
- matches every other MULTI script's look (black panels, white text, game fonts),
- uses MULTItarget (MULTIcore's target system) for world interaction, with hold-key prompts as fallback.

The quickest start is to copy MULTIstarter (`MULTIstarter.zip`). It's a small working script: sell an item at a counter. Rename it and build from there.

## Setup

```lua
-- fxmanifest.lua
shared_scripts {
    '@ox_lib/init.lua',
    '@MULTIcore/lib/api.lua',      -- gives MC.*
    '@MULTIcore/shared/i18n.lua',  -- gives _L('key')
    'config.lua',
    'locales/*.lua',
}
client_scripts { '@MULTIcore/lib/interact.lua', 'client/main.lua' }  -- gives MCI.*
server_scripts { 'server/main.lua' }
dependencies { 'MULTIcore', 'MULTItarget', 'MULTIinventory', 'ox_lib' }  -- every MULTI script lists MULTItarget
```

`MC.Name(...)` is shorthand for `exports.MULTIcore:Name(...)`; both work. Everything goes by player **source**, so no player objects are copied between resources.

## Server

### Players
| Call | Returns |
|---|---|
| `MC.IsLoggedIn(src)` | `true` when the player has a character loaded |
| `MC.GetPlayers()` | list of sources with a character loaded |
| `MC.GetCharacter(src)` | `{ source, citizenid, firstname, lastname, name, gender, job, gang, money }` or `nil` |
| `MC.GetSourceByCitizenId(citizenid)` | the source of an online character, or `nil` |
| `MC.IsAdmin(src)` | `true` for admin or god permission, or the `command` ace |

### Money
`account` is `'cash'` (default), `'bank'`, `'gold'` or any money type in MULTIcore's config.lua. Amounts keep cents.

| Call | Returns |
|---|---|
| `MC.GetMoney(src, account)` | balance (0 when not logged in) |
| `MC.AddMoney(src, amount, account, reason)` | `true` when added |
| `MC.RemoveMoney(src, amount, account, reason)` | `true` when taken; `false`, with nothing taken, when the player has too little |

### Jobs and gangs
`job` and `gang` come back as `{ name, label, grade, gradeLabel, isBoss, onDuty }`.

| Call | Returns |
|---|---|
| `MC.GetJob(src)` / `MC.GetGang(src)` | the table above |
| `MC.SetJob(src, job, grade)` / `MC.SetGang(src, gang, grade)` | `true` when set (the name must be in MULTIcore's shared/jobs.lua or gangs.lua) |
| `MC.HasJob(src, job or {jobs}, minGrade, onDutyOnly)` | `true` or `false` |
| `MC.SetDuty(src, onDuty)` | `true` |

### Saved data
Saved data stays with the character after logout. Start keys with your script's name, for example `mymod_level`.

| Call | Returns |
|---|---|
| `MC.GetMeta(src, key)` | the value, or `nil` |
| `MC.SetMeta(src, key, value)` | `true` |

### Items
| Call | Returns |
|---|---|
| `MC.RegisterItem({ name, label, weight, description, image, stack })` | registers the item at start; no SQL needed |
| `MC.RegisterUsableItem(name, function(src, item) end)` | runs when a player uses the item; removed again when your script stops |
| `MC.GiveItem(src, name, amount, info)` | `true` when it fitted |
| `MC.TakeItem(src, name, amount)` | `true` when taken; `false`, with nothing taken, when the player has too few |
| `MC.CountItem(src, name)` / `MC.HasItem(src, name, amount)` | count / `true` or `false` |
| `MC.CanCarry(src, name, amount)` | `true` when it would fit (weight and slots) |

### Events
```lua
MC.OnCharacterLoaded(function(src, citizenid, isNew) end)  -- picked or made a character
MC.OnCharacterUnloaded(function(src) end)                  -- logged out or left
MC.OnJobChanged(function(src, job) end)
```

### Notifications
```lua
exports.MULTIcore:Notify(src, { text = _L('sold', 3), title = _L('title'), type = 'success' })  -- 'info' | 'success' | 'error' | 'warning'
```

## Client
These are for display only. Always check again on the server before changing money or items.

| Call | Returns |
|---|---|
| `MC.IsLoggedIn()` | `true` once a character is loaded |
| `MC.GetCharacter()` | same shape as the server's |
| `MC.GetJob()`, `MC.GetGang()`, `MC.GetMoney(account)`, `MC.GetMeta(key)` | as on the server |
| `MC.CountItem(name)`, `MC.HasItem(name, amount)` | from the local inventory |
| `MC.OnCharacterLoaded(function(isNew) end)`, `MC.OnCharacterUnloaded(fn)`, `MC.OnJobChanged(function(job) end)` | events |
| `exports.MULTIcore:Notify({ text, title, type })` | notification |
| `exports.MULTIcore:SetDensity('Peds', 0.3)` or `SetDensity({ Vehicles = 0.0, Animals = 0.5 })` | changes how busy the world is for this player, 0.0 to 1.0. Keys: `Peds`, `ScenarioPeds`, `Animals`, `Vehicles`, `RandomVehicles`, `ParkedVehicles` (the server's starting values are `MULTIConfig.Density`) |
| `exports.MULTIcore:ResetDensity()`, `exports.MULTIcore:GetDensity()` | back to the server's value (`MULTIConfig.Density`, or what an admin set in game); the values in use |
| `exports.MULTIcore:GetSetting('MULTIcore.Density.Peds')` | the value in use of an in-game setting registered with `client = true` (see below) |

### World interaction (`@MULTIcore/lib/interact.lua`)
```lua
MCI.Run(Config.Interact, function(mode)          -- 'auto' | 'target' | 'prompt'
    if mode == 'target' then
        zone = MCI.AddZone({ coords = Config.Counter, radius = 1.2, options = { { name = 'my_counter', label = _L('use'), onSelect = open } } })
    else
        MCI.AddPrompt('my_counter', Config.Counter, 'J', _L('use'), { type = 'client', event = 'my:client:open' }, 2.0)
    end
end, function() if zone then MCI.RemoveZone(zone) end MCI.RemovePrompt('my_counter') end)
```

## Text and settings
- **No text in code.** Every line goes in `locales/en.lua` (the master) as `['key'] = 'Sold %s nuggets'`, then `_L('key', 3)`. Ship `de, fr, es, pt-br, it, pl, ru, nl, tr` with the same keys; a missing line falls back to English.
- **Language:** `Config.Locale = 'de'` for one script, or `MULTIConfig.Language = 'de'` in `MULTIcore/config_multi.lua` for all (32 languages, codes listed there). `_LPlainFont()` says whether NUI should use the plain font preset.
- **Settings:** everything a server owner might change goes in a commented `config.lua`, one line each. Values an owner may want to change while the server runs (prices, wages, timers) can also be registered as in-game settings (below).
- **Look:** for your own NUI page, link `nui://MULTIcore/html/theme/multi.css` first and an empty `custom.css` last. For small menus use ox_lib (`lib.registerContext`, `lib.inputDialog`).

## In-game settings (`@MULTIcore/lib/settings.lua`)
An admin changes these in MULTIadmin (Settings page) while the server runs: no file edit, no restart. The value in your `config.lua` stays the default ("file value"); a value changed in game is saved in the table `multicore_settings` (made by MULTIcore), wins on every start, and can be put back to the file value.

```lua
-- fxmanifest.lua
shared_scripts { '@MULTIcore/shared/i18n.lua', 'config.lua', 'locales/*.lua', '@MULTIcore/lib/settings.lua', 'settings.lua' }

-- settings.lua (runs on the server and on the client)
MCSettings.Register({
    { key = 'MyScript.PriceMultiplier', type = 'number', default = Config.PriceMultiplier, min = 0.1, max = 10, step = 0.05, unit = 'x',
      label = 'set_price_multiplier', category = 'setcat_prices',
      apply = function(v) Config.PriceMultiplier = v end },
    { key = 'MyScript.OpenAtNight', type = 'bool', default = Config.OpenAtNight, client = true,
      label = 'set_open_at_night', category = 'setcat_hours',
      apply = function(v) Config.OpenAtNight = v end },
})
```
| Field | Meaning |
|---|---|
| `key` | unique on the server: start it with your resource name |
| `type` | `'number'` (`min`, `max`, `step`, `integer = true`), `'bool'`, `'string'` (`maxLength`), `'choice'` (`choices = { { value = 'a', label = 'locale_key' } }`) |
| `default` | the config file value (it must fit its own limits, or the setting is skipped) |
| `label`, `category`, `help`, `unit` | locale keys of your script (the helper translates them with `_L`) |
| `client = true` | the value also reaches every player (also those who join later); `apply` then runs on the client too |
| `apply(value)` | runs at once with the value in use, then on every change and reset. Read `Config.X` where you use it (not once at start), so a change works live |

Server exports (any script may use them; the helper calls them for you):

| Call | What it does |
|---|---|
| `exports.MULTIcore:RegisterSettings(defs)` | registers (labels as plain text); returns `{ [key] = value in use }` |
| `exports.MULTIcore:GetSetting(key)` | value in use |
| `exports.MULTIcore:SetSetting(key, value, by)` | `true` or `false, error` (`unknown`, `not_allowed`, `not_number`, `too_low`, `too_high`, `not_bool`, `not_text`, `too_short`, `not_choice`, `db`). `by` = a player source (must be a MULTIcore admin or have ace `multicore.settings`) or a text naming who changed it when your script checked the permission itself |
| `exports.MULTIcore:ResetSetting(key, by)` | back to the file value (the saved row is deleted) |
| `exports.MULTIcore:GetSettings()` | every registered setting with `value`, `default`, `changed`, `changedBy`, `changedAt`, limits and labels (what MULTIadmin shows) |
| `exports.MULTIcore:CanChangeSettings(src)` | the permission check above |
| `AddEventHandler('MULTIcore:settings:changed', function(key, value, by) end)` | server event on every change and reset (the helper uses it) |

Clients read `GlobalState['mcset:<key>']` (the helper follows it with a state bag handler). Settings of a script that stops leave the list; their saved values stay. MULTIcore registers its own: `MULTIcore.Density.*` (all players follow them live), `MULTIcore.PayCheckMinutes`, `MULTIcore.WageMultiplier`, `MULTIcore.PayCheckSociety`.

## Rules that keep servers safe
1. **The server decides.** Never let the client say how much money or how many items. Check distance (`GetEntityCoords(GetPlayerPed(src))`), job, amount and a cooldown on the server.
2. **Check the return value** of `RemoveMoney` and `TakeItem` before giving anything.
3. **Prices are 1899-level.** A buy-back price must be at most half the lowest sale price, so there are no money loops.
4. **Never invent game names.** Every native, model, animation or prop must be real; check it before using it.

## Versions
`MC.GetApiVersion()` returns `1`. Functions are only ever added; existing ones keep their shape.
