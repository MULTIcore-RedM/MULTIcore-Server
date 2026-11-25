# MULTIrobberies

Store and bank robberies for MULTIcore.

- **Store tills:** pick the cash register in any general store and empty the till. Every town pays its own amount: Saint Denis pays the most, then Blackwater, Rhodes, Valentine and the smaller towns.
- **Banks:**
  1. Pick the lock of the bank's gate (MULTIdoors).
  2. At the vault door, set a **pipe charge** and get clear. The blast swings the vault door open.
  3. Crack and empty the safes inside: cash, gold bars, silver bars, bank bonds, jewellery boxes and jewellery. Each bank pays differently: Saint Denis, then Blackwater, Rhodes and Valentine.
- **Reset:** after a set time the vault is fixed and locked again, and the bank can be robbed once more.

GPL v3, part of MULTIcore by RINGO (RINGOscripting).

## Needs

`MULTIcore`, `MULTIinventory`, `MULTItarget`, `MULTIdoors` and `ox_lib`. MULTIlaw is optional: when it runs, its law count and alerts are used.

```
ensure MULTIdoors
ensure MULTIrobberies
add_ace group.admin multirobberies.admin allow
```

## How a bank robbery goes

1. **The gate.** Bring a `lockpick` and pick the bank's gate. MULTIdoors already has the bank gates as lockpickable doors.
   - With `Config.Bank.GateMustBePicked = true`, only a picked gate opens the bank to robbery. A gate a banker unlocked with a key does not count.
2. **The vault door.** Look at the vault door and choose **Set a pipe charge**. This takes one `pipe_charge` item.
   - The fuse burns for `Config.Bank.FuseSeconds`, then the charge blows.
   - Anyone standing at the door gets hurt.
   - The law is told.
3. **The safes.** Look at a safe and choose **Crack the safe**: a skill check, then emptying it. Every safe is rolled on its own from `Config.SafeLoot`, multiplied by the bank's `pay`. What does not fit in the pockets is lost.
4. **Reset.** After `Config.Bank.ResetMinutes` the vault is fixed and locked, and the gates are locked again.

### Where the safes are

Safe spots are taken from the first source that has any:

1. Spots an admin set in game: stand at a safe in the vault and type `/robsafe`. One spot is added to the nearest bank and saved in `data/safes.json`. `/robsafe clear` removes that bank's spots.
2. Safe props the game placed within `Config.Bank.SafeScanRadius` of the vault door (`Config.Bank.SafeModels`).
3. One spot just inside the vault door. Each search there empties the next of the bank's `safes`.

## Minigames

- **Lockpick** (tills, and every lockpickable MULTIdoors door, bank gates too): a pin lock seen from the side. Move the mouse left and right to slide the pick under a pin, up and down to lift it. One pin at a time binds: it feels stiff and trembles. Hold it at the shear line until it clicks. Forcing it far past the line bends the pick until it snaps.
- **Safe dial**: a combination dial 0 - 99. Turn LEFT until the heavy click, turn back RIGHT to the next click, then LEFT again. Every number ticks softly; the right number clicks hard. Turning back anywhere else lets the tumblers fall. Drag with the mouse, scroll, or hold A / D (Shift for slow).
- Levels in `Config.Minigames` (pins, tolerance, time; numbers in the combination). `Config.Minigames.Enabled = false` uses ox_lib skill checks instead.
- Other scripts can use them: `exports.MULTIrobberies:Lockpick(level, label)` and `exports.MULTIrobberies:SafeCrack(level, label)` return true or false.

## Store tills

Every cash register prop (`Config.Registers.Models`) can be picked. You need a `lockpick`, and a failed pick may break it.

- One till can be emptied again after `CooldownMinutes`.
- One player waits `PlayerCooldownSeconds` between two tills.
- The cash is a random amount between `Min` and `Max`, times the town's `pay` (`Config.Towns`), or `OtherTowns` outside every town.
- The clerk gets word to the law with `AlertChance`.

## Items

These items are added to the item list when the inventory does not know them (`Config.NewItems`):

| Item | What it is |
|---|---|
| `pipe_charge` | Pipe charge dynamite, used on a vault door |
| `bank_bond` | Bearer bond, for a fence |
| `jewelry_box` | Use it to open it (`Config.JewelryBox`) |
| `gold_ring`, `pearl_necklace`, `gold_watch`, `diamond_brooch` | Jewellery |

`goldbar`, `silverbar` and `lockpick` are already in MULTIcore and MULTIdoors. The pictures are stand-ins from MULTIimages until the items get their own.

Give the pipe charge a source: a store, crafting or a gang job.

## Settings

All settings are in `config.lua`, each with a comment:

- `Config.Law`: who counts as law, alerts, and whether lawmen on duty may rob.
- `Config.Registers` and `Config.Towns`: tills and town pay.
- `Config.Banks`: per bank:
  - the MULTIdoors gate and vault rule ids;
  - how many safes;
  - `pay`;
  - `minLaw`.
- `Config.Bank`: the charge, fuse, blast, safes and reset.
- `Config.SafeLoot` and `Config.JewelryBox`: what safes and boxes hold.
- `Config.Interaction`: `'auto'`, `'target'` or `'prompt'`.

## Commands

| Command | Who | What |
|---|---|---|
| `/robsafe` | admin | Add a safe spot where you stand to the nearest bank |
| `/robsafe clear` | admin | Remove that bank's safe spots |
| `/robreset [bank id]` | admin, console | Fix and lock a vault now (all banks when no id) |

## Languages

32 languages in `locales/`. The language follows MULTIcore's setting, or `Config.Locale`.
