# MULTItarget

*MULTIcore was founded and created by RINGO (RINGOscripting).*

MULTIcore's own target system. Hold **Left Alt**, look at a person, animal, wagon, object or counter, and its options are listed beside the middle of the screen. Every MULTI script uses it and lists it as a dependency.

It answers **ox_target**, **rsg-target** and **qb-target** calls, so scripts written for any of them work unchanged. No other target script is needed.

## Install

```
ensure ox_lib
ensure MULTIcore
ensure MULTItarget     # straight after MULTIcore, before every other MULTI script
```

Do **not** start `ox_target`, `rsg-target` or `qb-target` as well. MULTItarget `provide`s those names, so scripts that depend on them still start.

## Controls

| | |
|---|---|
| Hold **Left Alt** | Four thin corner brackets show in the middle of the screen. Look at something and its options appear beside them |
| **Mouse wheel** / arrow keys | Move through the options |
| **Left mouse** / **E** / **Enter** | Pick the highlighted option |
| **Right mouse** | Free the cursor to click an option instead. Esc or right mouse gives the camera back |

`Config.Mode = 'toggle'` makes Left Alt switch targeting on and off instead of being held. All keys are in `config.lua` (`Config.Keys`).

MULTItarget never draws a dot, marker or sprite in the world.

## Config

| Option | Default | What it does |
|---|---|---|
| `Config.Debug` | `false` | Print rsg-target calls, failed `canInteract` checks and unsupported calls (F8) |
| `Config.Mode` | `'hold'` | `'hold'` = hold Left Alt, `'toggle'` = press to switch on / off |
| `Config.DefaultDistance` | `2.5` | Reach (metres) when neither the option nor its zone sets one |
| `Config.RayDistance` | `8.0` | How far the look ray reaches |
| `Config.RayIntervalMs` | `60` | How often the look ray is cast while targeting |
| `Config.RayFlags` | `511` | What the ray can hit (511 = everything) |
| `Config.BoneDistance` | `1.2` | Options tied to bones show within this distance of the bone |
| `Config.Scale` | `1.0` | Size of the brackets and the list |
| `Config.Keys` | see file | Control hashes for target, select, up / down, cursor and the controls turned off while targeting |
| `Config.Zone` | see file | Heights for PolyZone-style boxes and polys made through rsg-target / qb-target calls |

Colours and sizes: `html/custom.css` (loaded last). Text: `locales/` (10 languages).

## API (same calls as ox_target)

```lua
local id = exports.MULTItarget:addSphereZone({ coords = vec3(...), radius = 1.5, label = 'Sheriff desk', options = {
    { name = 'duty', label = 'Go on duty', icon = 'fa-solid fa-star', groups = { police = 0 }, distance = 2.0,
      canInteract = function(entity, distance, coords, name, bone) return true end,
      onSelect = function(data) --[[ data.entity, data.coords, data.distance, data.zone ]] end },
} })
exports.MULTItarget:removeZone(id)                     -- id or the zone's name

exports.MULTItarget:addBoxZone({ coords = ..., size = vec3(2, 1, 2), rotation = 90.0, options = { ... } })
exports.MULTItarget:addPolyZone({ points = { vec3(...), ... }, thickness = 4.0, options = { ... } })
exports.MULTItarget:addLocalEntity(entity, options)    exports.MULTItarget:removeLocalEntity(entity, names)
exports.MULTItarget:addEntity(netId, options)          exports.MULTItarget:removeEntity(netId, names)
exports.MULTItarget:addModel('p_chair04x', options)    exports.MULTItarget:removeModel(model, names)
exports.MULTItarget:addGlobalPed(options)      -- also Player, Vehicle, Object, Option (+ removeGlobal...)
exports.MULTItarget:disableTargeting(true)     exports.MULTItarget:isActive()
```

The same calls work on `exports.ox_target`.

An option runs `onSelect(data)`, `export` (`'resource.function'`), `event`, `serverEvent` (the entity is sent as a network id) or `command`. It can also have:
- `items` / `anyItem`;
- `groups` (job, gang or citizenid, with a lowest grade);
- `bones`;
- `distance`;
- `description` (a grey line under the label) and `iconColor`;
- `openMenu` / `menuName` for sub menus (a Back row is added).

A new option with the same `name` replaces the old one. When a script stops, its targets go with it.

MULTItarget-only calls set the heading above the list:

```lua
exports.MULTItarget:setEntityLabel(ped, 'Doc Hale', 'Doctor')
exports.MULTItarget:setModelLabel('u_m_m_valdoctor_01', 'Doctor')
exports.MULTItarget:hasEntityOptions(entity)   -- true when a script put options on this entity
```

### rsg-target / qb-target calls

`AddTargetEntity`, `AddTargetModel`, `AddCircleZone`, `AddBoxZone`, `AddPolyZone`, `AddGlobalPed` / `Vehicle` / `Object` / `Player`, `AddTargetBone`, the matching `Remove...` calls, `AllowTargeting`, `IsTargetActive` and `IsTargetSuccess` work on `exports['rsg-target']`, `exports['qb-target']` and `exports.MULTItarget`. qb options (`type`, `event`, `action`, `job`, `gang`, `citizenid`, `item`, `canInteract(entity, distance, data)`) are translated.

## For MULTI script writers

Load `'@MULTIcore/lib/interact.lua'` and use `MCI.AddZone` / `MCI.AddEntity` (see the main README). Add `'MULTItarget'` to your `dependencies`.

## Checks

- **groups:** read from the player's RSG data (job, gang, citizenid).
- **items:** counts come from the server when targeting starts. The script that owns the option still checks again on its own server.

## Restarting

Do a full server restart after changing MULTItarget. Scripts add their targets when they start, so restarting MULTItarget on its own leaves them without targets until they restart too.

## Licence

GPL-3.0-or-later, part of MULTIcore.
