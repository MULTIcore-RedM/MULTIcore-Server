# MULTIcrafting

Basic crafting for MULTIcore. GPL v3.

- **Stations:**
  - **Satchel:** hand crafting anywhere (`/craft` when no station is near).
  - **Campfires:** any campfire prop that is part of the map, and the campfire a player puts down by using the
    `campfire` item (sold at general stores; it burns for 20 minutes, one per character, the owner can put it out).
  - **Kitchens:** in the saloons.
  - **Workbenches:** the gunsmith benches, and every anvil and forge in the world for blacksmiths.
  - Kitchens and benches are fixed spots in `config/stations.lua`; any spot can be locked to MULTIcore jobs.
- **Recipes:** inputs, an output, the station types, a time, an optional job and grade, and an optional
  tool that is kept (`config/recipes.lua`).
- **The screen:** in the base-game look. It lists the recipes of the station by category and shows what you
  have and what you need. You choose an amount and craft. The station's animation then plays with a progress
  bar. X stops; nothing is lost.
- **The server decides everything:**
  - it checks the station distance (OneSync), the job, the inputs, the tool and the room in the satchel;
  - when crafting finishes it takes the inputs and gives the output in one step;
  - a crafted weapon gets its own serial;
  - requests are rate-limited.

## Setup
1. Put `MULTIcrafting` in `resources/[multicore]`.
2. In `server.cfg`, after MULTIinventory: `ensure MULTIcrafting`.
3. Item pictures: add `cloth.png` and `gunpowder.png` to your item image folder (none are shipped).

## How crafting works
- Open a station with MULTItarget (Left Alt, "Open ..." on the station, campfire, anvil or forge) or, when MULTItarget
  is not running, with its hold-key prompt (hold **G**); `Config.Interact` (`'auto'` by default). You can also
  type `/craft`, which opens the nearest station, or hand crafting when no station is near.
- **Enter** crafts, the arrow keys choose the recipe and the amount, **Tab** changes the category, **Esc** closes.
- Several of a recipe can be made at once (up to `Config.Craft.MaxBatch`); the time adds up.
- **Inputs are taken only when crafting finishes.** Stopping early (X, walking away, dying) costs nothing.
- At the finish the server checks everything again. If the satchel has no room for the output, nothing is taken.
- Only one craft at a time. The satchel is marked busy (`LocalPlayer.state.inv_busy`) while crafting.

## Stations
| Type | Where | Default animation (redm-info Scenarios.lua) |
|---|---|---|
| hand | anywhere | WORLD_HUMAN_CROUCH_INSPECT |
| campfire | world campfire props (`p_campfire01x` ... see config) and placed campfires (`p_campfire02x`) | WORLD_HUMAN_FIRE_TEND_KNEEL |
| cooking | saloon bar counters (config/stations.lua) | WORLD_HUMAN_CLEAN_TABLE |
| gunsmith | gunsmith counters (config/stations.lua) | WORLD_HUMAN_HAMMER_TABLE |
| blacksmith | world anvils / forges (`p_anvil01x`, `p_forge01x`) or your own spots | WORLD_HUMAN_HAMMER_TABLE |

The server cannot see props that are part of the map. For a world campfire or anvil it trusts the client that
the prop is there, and only checks that the player stands near the coordinates sent. To allow only fixed stations
and placed campfires, set `Config.AllowWorldProps = false`.

## Starter recipes
| Recipe | Station | Inputs | Output | Job |
|---|---|---|---|---|
| cooked_meat | campfire, kitchen | raw_meat | cooked_meat | |
| cooked_fish | campfire, kitchen | raw_fish | cooked_fish | |
| stew | campfire, kitchen | raw_meat, 2 herb_wild_carrot, water | stew | |
| bread | kitchen | flour_wheat, egg, water | 2 bread | |
| bandage | satchel, campfire | 2 cloth | bandage | |
| arrows | satchel, campfire | feather, wood (tool: knife, kept) | 2 ammo_arrow_single | |
| campfire_kit | satchel | 4 wood | campfire | |
| gunpowder | gunsmith bench | resource_sulfur, resource_nitrate, resource_coal | 2 gunpowder | gunsmith |
| ammo_revolver / pistol / repeater | gunsmith bench | gunpowder, resource_lead_bar | 12 rounds | gunsmith |
| ammo_rifle / shotgun | gunsmith bench | 2 gunpowder, resource_lead_bar | 12 rounds | gunsmith |
| knife | anvil | resource_iron_bar, resource_coal, wood | weapon_melee_knife | blacksmith |
| axe / pickaxe | anvil | 2 resource_iron_bar, resource_coal, 2 wood | axe / pickaxe | blacksmith |
| shovel | anvil | resource_iron_bar, resource_coal, 2 wood | shovel | blacksmith |

New items (registered at start when your registry lacks them): `cloth`, `gunpowder`.

## Config
Everything is in `config.lua` and `config/*.lua`, every option commented:
- `config.lua`: how stations open (`Interact` `'auto'` / `'target'` / `'prompt'`, `PromptKey`, `PromptDistance` 2.0 m, `TargetDistance` 2.0 m), crafting times and checks, the station types (distance, animation, world props, job),
  placed campfires, duty, blips.
- `config/recipes.lua`: the recipes. A recipe whose items are unknown is skipped with a warning at start.
- `config/stations.lua`: the fixed kitchens and benches.
- `config/items.lua`: the items this resource adds.

Text is in `locales/` (en, de, fr, es, pt-br, it, pl, ru, nl, tr). Notifications use MULTIcore's own.
Restyle the screen in `html/custom.css`.

## Commands
- `/craft` (`Config.Command`): opens the nearest station, or hand crafting.
- `/mcinteract` (MULTIcore, anyone): prints this script's interaction mode, MULTItarget targets and prompts to the server console.

## Exports
Server (`exports.MULTIcrafting:...`):
| Export | Returns |
|---|---|
| `GetRecipes()` / `GetRecipe(id)` | the recipes / one recipe |
| `AddRecipe(def)` | adds or replaces a recipe (same shape as config/recipes.lua) → `true` or `false, why` |
| `RemoveRecipe(id)` | bool |
| `CanCraft(src, id, count?, stationRef?)` | `true` or `false, err` (stationRef defaults to `{ type = 'hand' }`) |
| `OpenMenu(src, stationRef)` | opens the screen for a player → bool |
| `IsCrafting(src)`, `IsReady()` | bool |
| `GetCampfires()` / `RemoveCampfire(id)` | list of placed fires `{ id, x, y, z, h }` / bool |

A station ref is `{ type = 'hand' }`, `{ id = '<config station id>' }`, `{ type = 'campfire' }` (nearest placed fire) or
`{ type = '<type>', coords = { x, y, z } }` (a world prop).

Server event: `MULTIcrafting:crafted (src, recipeId, count, outputItem, outputAmount)`.

Client: `IsOpen()`, `IsCrafting()`, `Close()`, `OpenNearest()`, `OpenHand()`.

## RSG and VORP scripts
Neither RSG v2 nor the VORP scripts surveyed here call a crafting resource, so MULTIcrafting answers no other
resource's name. Premium crafting scripts can run instead of it, or next to it.

## Self-test
`test/crafting_selftest` (needs `setr multicore_selftest true`): prints `[crafttest] DONE: n passed, m failed`.
