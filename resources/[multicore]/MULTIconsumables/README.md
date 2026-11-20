# MULTIconsumables

Food, drink, tobacco and medicine for MULTIcore, with a drunk system and addictions. GPL v3.

- Every food and drink item in MULTIcore's items becomes usable, with an animation and a hand prop
  (eat, eat from a can, stew with a spoon, coffee mug, drink from a bottle, cigarette, cigar, pipe, chewing tobacco).
- New items: whiskey, rum, gin, moonshine, wine, cigarettes, cigar, pipe, pipe tobacco, chewing tobacco,
  laudanum, temperance tonic.
- Effects on hunger, thirst and stress (through MULTIhud), health, stamina and the game's cores.
- **Drunk system:** drinks raise a drunk level that wears off with time. Coffee and water sober you up.
  Tipsy, drunk, very drunk and wasted bring the game's drunk walk, screen effects, camera sway, shaky aim,
  no aim lock-on and stumbling. At the top you throw up and black out, and wake up later with a hangover.
- **Addiction:** drink, tobacco and laudanum build a habit. An addicted character gets cravings, then
  withdrawal (stress, drained cores, shaky hands, messages) when going without. Long abstinence breaks the
  habit. Tolerance weakens the good effects. The temperance tonic eases the habit.

## Setup
1. Put `MULTIconsumables` in `resources/[multicore]`.
2. In `server.cfg`, after MULTIinventory and MULTIhud: `ensure MULTIconsumables`.
3. Item pictures: add `whiskey.png`, `rum.png`, `gin.png`, `moonshine.png`, `wine.png`, `cigarettes.png`,
   `cigar.png`, `pipe.png`, `pipe_tobacco.png`, `chewing_tobacco.png`, `laudanum.png`, `tonic_temperance.png`
   to your item image folder (none are shipped).

## How using works
- Using an item in the satchel (or `exports.MULTIconsumables:Consume`) takes the item on the server first,
  then the effects apply and the client plays the animation. **X** (`Config.Use.CancelKey`) stops early; the
  item is never given back. With `Config.Use.ApplyOnStart = false` the effects only apply when the animation
  finishes.
- **Other scripts keep their items.** The usables are registered with MULTIinventory as built-in handlers
  (`RegisterUsable(name, fn, { builtin = true })`). MULTIinventory runs a built-in handler only when no other
  script handles the item: an RSG `CreateUseableItem` (rsg-consume, rsg-herbalist ...), a VORP
  `registerUsableItem`, or a normal `RegisterUsable`. So running rsg-consume keeps its bread, beer and coffee,
  and nothing runs twice.
- Pipe tobacco needs a pipe in the satchel (the pipe is kept).
- Nothing can be used while dead, passed out, or during another use.

## Config
Everything is in `config.lua` and `config/*.lua`, every option commented:
- `config.lua`: using items, the drunk levels and their effects, blackout, the addiction substances and their times.
- `config/consumables.lua`: what each item does (hunger, thirst, stress, health, cores, alcohol, sobering,
  substance, cure). Add a line to make another item usable.
- `config/anims.lua`: the animations and props.
- `config/items.lua`: the items this resource adds (registered at start if your registry lacks them).

Text is in `locales/` (en, de, fr, es, pt-br, it, pl, ru, nl, tr). Notifications use MULTIcore's own (game look).
There is no NUI page.

## Items and effects (defaults)
Needs are 0-100. Stress: negative relieves it.

| Item | Animation | Effects |
|---|---|---|
| bread | eat | hunger +20, thirst -2, stress -2 |
| bread_sour | eat | hunger +30, thirst -2, stress -3 |
| canned_apricots | eat from can | hunger +20, thirst +15, stress -2 |
| cooked_meat / cooked_fish | eat | hunger +35 / +30, thirst -3, stress -3, health core +5 |
| stew | bowl and spoon | hunger +50, thirst +15, stress -8, health core +10, stamina core +10 |
| sugarcube | eat | hunger +2, stamina core +3 |
| water | bottle | thirst +30, sober 3 |
| milk | bottle | thirst +20, hunger +5, stress -2 |
| coffee | mug | thirst +10, stress -5, sober 8, stamina core +10, stamina +20 |
| beer | bottle | thirst +10, hunger +2, stress -5, drunk +6, alcohol habit |
| wine | bottle | thirst +5, stress -8, drunk +10, alcohol habit |
| whiskey / rum | bottle | thirst -5, stress -12, drunk +18, alcohol habit |
| gin | bottle | thirst -5, stress -10, drunk +17, alcohol habit |
| moonshine | jug | thirst -8, stress -15, drunk +30, health core -5, alcohol habit +5 |
| cigarettes | smoking scenario | stress -8, stamina core -2, tobacco habit |
| cigar | cigar scenario | stress -12, stamina core -3, tobacco habit +5 |
| pipe_tobacco (needs pipe) | pipe | stress -10, stamina core -2, tobacco habit |
| chewing_tobacco | chew | stress -6, tobacco habit |
| laudanum | medicine bottle | stress -20, health +40, health core +15, drunk +4, laudanum habit |
| tonic_healing | medicine bottle | health +50, health core +25 |
| tonic_stamina | medicine bottle | stamina +100, stamina core +40 |
| tonic_energy | medicine bottle | stamina core +25, health core +10, stress -5 |
| tonic_antidote | medicine bottle | health +25, health core +15 |
| tonic_temperance | medicine bottle | alcohol habit -25, laudanum habit -20, 30 min without cravings, sober 15, stress -5 |

## Drunk levels (defaults)
Drunk level 0-100, -1.5 a minute (also while logged out). Kept in the metadata as `multi_drunk`.

| Level | From | Effects |
|---|---|---|
| tipsy | 10 | slight drunk walk (0.25), `PlayerDrunk01`, slight aim shake |
| drunk | 30 | drunk walk (0.5), `PlayerDrunk01`, camera sway, aim shake |
| very drunk | 55 | very drunk walk (1.0), `PlayerDrunkSaloon1`, more sway, no aim lock-on, 4% stumble |
| wasted | 75 | as above, strong sway and aim shake, 10% stumble |
| blackout | 95 | vomit, fade to black, 20 s out, wake at level 45 with hunger -10, thirst -20, stress +10 |

## Addiction (defaults)
Kept in the metadata as `multi_addiction`. Times are real time (logged out counts).

| Substance | Per use | Addicted at | Craving after | Withdrawal after | Recovery | Tolerance at 100 | Withdrawal each minute |
|---|---|---|---|---|---|---|---|
| alcohol | 3 | 40 | 30 min | 90 min | after 6 h clean, -4 an hour | -50 % | stress +2, health core -2, stamina core -3, shaky aim, screen effect |
| tobacco | 4 | 35 | 20 min | 60 min | after 4 h clean, -5 an hour | -40 % | stress +3, stamina core -2, slight shake |
| laudanum | 8 | 30 | 30 min | 90 min | after 12 h clean, -3 an hour | -60 % | stress +4, health core -4, stamina core -4, strong shake, screen effect |

Using the substance ends the withdrawal at once. Tolerance cuts the good effects (stress relief, healing,
stamina) and, for alcohol, how drunk a drink makes you.

## Exports (server)
| Export | Returns |
|---|---|
| `GetDrunk(src)` | drunk level or nil |
| `SetDrunk(src, n)`, `AddDrunk(src, delta)` | new level |
| `IsBlackedOut(src)` | bool |
| `GetAddiction(src, substance)` | 0-100 or nil |
| `SetAddiction(src, substance, level, lastUseSecondsAgo?)` | bool |
| `GetAddictionStatus(src, substance)` | `'none'`, `'ok'`, `'craving'`, `'withdrawal'` |
| `IsInWithdrawal(src, substance?)` | bool (any substance when none is given) |
| `Consume(src, itemName, opts?)` | `true` or `false, err`; uses one from the satchel like the player did. `opts.free` = no item taken, `opts.noAnim` = no animation |
| `GetConsumable(itemName)` | the item's effect table or nil |

Errors: `not_consumable`, `no_player`, `busy`, `blackout`, `dead`, `requires`, `no_item`, `not_enough`.

Server event: `MULTIconsumables:consumed (src, itemName)`, fired when an item is used (the item has been taken).

## RSG and VORP scripts
- rsg-consume, rsg-herbalist and VORP food scripts keep working: they keep the items they register (see above).
- MULTIhud stands in for rsg-hud and vorp_metabolism, so their effects still reach the HUD.
- No RSG v2 script, and no script on the test server, calls a drunk or addiction event of another resource,
  so there are no other names to answer.

## Where the game names come from
- rsg-consume (RSG v2, GPL v3, a working script): the eat, eat-from-can, drink, stew and coffee animations,
  their props and bone offsets, the item interaction hashes, the vomit and sleep animations, and the screen
  effects `PlayerDrunk01`, `PlayerDrunk01_PassOut`, `PlayerWakeUpDrunk`, `PlayerHealthPoorCS`.
- redm-info: the dicts `amb_rest@world_human_smoking@male_b@idle_a`, `amb_misc@world_human_vomit@male_a@idle_b`,
  `amb_rest@world_human_sleep_ground@arm@male_b@idle_b`; the scenarios `WORLD_HUMAN_SMOKE`,
  `WORLD_HUMAN_SMOKE_CIGAR`; the props `p_bread_14_ab_s_a`, `p_meatchunk_sm02x`, `s_canrigapricots01x`,
  `p_bottlebeer01a`, `p_bottle003x`, `p_bottlewine01x`, `p_bottlejd01x`, `p_bottlenavyrum01x`, `p_bottleslim01x`,
  `p_jug01x`, `p_bottlemedicine01x/02x/03x`, `p_pipe01x`, `s_tobaccotin01x`, `p_bowl04x_stew`, `p_spoon01x`,
  `p_mugcoffee01x`.
- natives.json: every native called by hash, the shake names `DRUNK_SHAKE` and `HAND_SHAKE`, and the drunkness levels.
- Not in redm-info (check in game): the mech_inventory eating / drinking dicts (they work in rsg-consume); the
  pipe clip `idle_a`; the chewing tobacco dict `amb_misc@world_human_chew_tobacco@male_a@stand_enter` / `enter_back`;
  the pipe and tin bone offsets; the screen effect `PlayerDrunkSaloon1` (used by working scripts on the test server).

## Self-test
`test/consumables_selftest` (needs `setr multicore_selftest true`): prints `[constest] DONE: n passed, m failed`.
