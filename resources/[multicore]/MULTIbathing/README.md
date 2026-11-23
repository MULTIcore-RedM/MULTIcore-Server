# MULTIbathing

Bath houses for MULTIcore. GPL v3 (see `LICENSE`).
MULTIcore was founded and created by RINGO (RINGOscripting).

- **7 bath houses:** Saint Denis, Valentine, Annesburg, Strawberry, Blackwater, Van Horn and Rhodes, each with a map
  blip.
- **Taking a bath:** hold **Left Alt** (MULTItarget) at the bath house counter and pick **Take a bath**
  (`Config.NormalBathPrice`, $1 by default). The game's own bathing scene plays: you undress, get in the tub and scrub
  with the game's prompts.
- **Luxury service:** in the tub, order the luxury service (`Config.DeluxeBathPrice`, $5 by default). Someone comes in
  and scrubs you.
- **Getting out:** your look and worn clothes are put back on (MULTIcore and MULTItailor), and your cleanliness is set
  to `Config.Cleanliness` (100) in MULTIhud.
- One player per bath house at a time. The bath room doors stay shut (`Config.LockDoors`).
- 32 languages, following MULTIcore's language (`MULTIConfig.Language`). Nothing is drawn in the world.

Payments are taken on the server, only near the counter, and only one bath per player at a time.

## Install

1. Put `MULTIbathing` in your resources (it ships in `resources/[multicore]`).
2. Add `ensure MULTIbathing` to `server.cfg` after MULTIcore and MULTItarget.

## Settings (`config.lua`)

| Setting | Default | What it does |
|---|---|---|
| `Config.Locale` | `''` | Language for this script; empty follows MULTIcore's language |
| `Config.Debug` | `false` | Extra prints in F8 |
| `Config.Currency` | `'cash'` | Money type players pay with |
| `Config.NormalBathPrice` | `1` | Price of a bath |
| `Config.DeluxeBathPrice` | `5` | Price of the luxury service |
| `Config.Cleanliness` | `100` | Cleanliness after a bath (0-100) |
| `Config.Interact` | `'auto'` | `'auto'`, `'target'` (MULTItarget) or `'prompt'` (hold-key prompts) |
| `Config.Key` | `'J'` | Prompt key (prompt mode only) |
| `Config.TargetRadius` / `Config.TargetDistance` | `1.0` / `2.0` | MULTItarget point size and reach |
| `Config.PromptDistance` | `1.5` | Prompt reach (prompt mode) |
| `Config.ServerDistance` | `6.0` | The server refuses a bath farther than this from the counter |
| `Config.ShowBlips` | `true` | Bath house blips |
| `Config.LockDoors` | `true` | Keep the bath room doors shut |
| `Config.BathingZones` | 7 bath houses | Scene, rag, counter, luxury service ped and door per bath house |
| `Config.BathingModes` | 5 parts | Scrubbing order and speed |

## For script makers

- `LocalPlayer.state.isBathingActive` (client): `true` while the player is in a bath.
- `exports.MULTIbathing:IsBathingActive()` (client): the same.

## Needs

MULTIcore, MULTItarget, ox_lib. MULTIhud (cleanliness) and MULTItailor (worn clothes) are used when they run.
