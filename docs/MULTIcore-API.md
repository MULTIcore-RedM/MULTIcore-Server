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
- **Settings:** everything a server owner might change goes in a commented `config.lua`, one line each.
- **Look:** for your own NUI page, link `nui://MULTIcore/html/theme/multi.css` first and an empty `custom.css` last. For small menus use ox_lib (`lib.registerContext`, `lib.inputDialog`).

## Rules that keep servers safe
1. **The server decides.** Never let the client say how much money or how many items. Check distance (`GetEntityCoords(GetPlayerPed(src))`), job, amount and a cooldown on the server.
2. **Check the return value** of `RemoveMoney` and `TakeItem` before giving anything.
3. **Prices are 1899-level.** A buy-back price must be at most half the lowest sale price, so there are no money loops.
4. **Never invent game names.** Every native, model, animation or prop must be real; check it before using it.

## Versions
`MC.GetApiVersion()` returns `1`. Functions are only ever added; existing ones keep their shape.
