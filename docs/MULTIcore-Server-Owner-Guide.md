# MULTIcore server owner guide

*MULTIcore was founded and created by RINGO (RINGOscripting).*

How to set up the everyday things on a MULTIcore server: item pictures, items, jobs, gangs, stores, staff and money. No coding needed: everything is in commented files you edit with any text editor.

**After editing a file in `MULTIcore/shared/` (items, jobs, gangs), do a full server restart.** Every script reads those lists when it starts, so restarting one script on its own is not enough.

All paths below are inside `resources/[multicore]/`.

---

## 1. Item pictures

No pictures are included (the game's item art belongs to its owners), so items show a plain icon until you add your own.

1. Put one picture per item in **`MULTIimages/images/`**.
2. Name each file exactly as the item's `image` field: bread is `image = 'bread.png'`, so the file is `bread.png`. Weapons use their item name, e.g. `weapon_revolver_cattleman.png`.
3. Use PNG (or WEBP), square, about 100 x 100 pixels or larger, with a transparent background.
4. Make sure `ensure MULTIimages` is in `server.cfg` (it is in `server.cfg.example`). Restart and reconnect.

The inventory, the stores, trading and drops all use the same pictures.

**Scripts made for VORP, RSG, RedEM:RP or RINGOinventory** show item pictures from their own inventory's folder, for example `nui://vorp_inventory/html/img/items/bread.png`. MULTIcore's stand-ins `vorp_inventory`, `rsg-inventory`, `redemrp_inventory` and `RINGOinventory` (in `resources/[multicore]`, started in `server.cfg.example` right after MULTIinventory) show the same pictures there. Each copies `MULTIimages/images/` into itself when it starts, so you still only add pictures in `MULTIimages/images/`. After adding pictures, restart the server.

**Already have a picture folder in another script?** Add its address to `Config.ImagePaths` in `MULTIinventory/config.lua`. The folders are tried in order:

```lua
Config.ImagePaths = {
    'nui://MULTIimages/images/',
    'nui://my_images/html/img/',   -- any STARTED resource that lists the files in its fxmanifest files {}
}
```

Many servers already have a set of RDR2 item pictures from an older inventory script. Copy those `.png` files into `MULTIimages/images/`. Do not start the real rsg-inventory or vorp_inventory just to use their pictures: MULTIinventory replaces both, and MULTIcore's stand-ins of the same names already show your pictures to scripts made for them.

---

## 2. Items

### Add an item

Open **`MULTIcore/shared/items.lua`** and add a line in the same shape as the others:

```lua
pocket_watch = { name = 'pocket_watch', label = 'Pocket Watch', weight = 120, type = 'item', image = 'pocket_watch.png',
                 unique = false, useable = false, shouldClose = true, description = 'A silver watch on a chain.', category = 'valuables' },
```

| Field | What it means |
|---|---|
| `name` | The item's id. Lower case, no spaces, the same as the key in front of `=`. **Never change it once players have the item** |
| `label` | The name players see |
| `weight` | **Grams** (1000 = 1 kg) |
| `type` | `'item'`, or `'weapon'` for weapons |
| `image` | The picture file in `MULTIimages/images/` |
| `unique` | `true` = never stacks (each one is separate, e.g. a letter with its own text) |
| `useable` | `true` = it can be used from the satchel. Something must handle the use (see below) |
| `shouldClose` | `true` = the satchel closes when it is used |
| `description` | The line under the name |
| `category` | Groups items on the store screen (food, tools, ammo, ...) |

Restart the server and the item exists for every script: RSG scripts, VORP scripts and MULTI scripts.

**Other ways items arrive (all end up in the same list):**
- VORP scripts that add rows to the `items` table: they are picked up by themselves. VORP weights are kilograms.
- MULTI scripts register their own items when they start (`exports.MULTIinventory:RegisterItem`).

### Make it do something when used

| The item is ... | Where |
|---|---|
| Food, drink, tobacco, medicine, alcohol | `MULTIconsumables/config/consumables.lua`: one line per item with hunger, thirst, stress, health, the animation and the prop. The top of the file explains every field |
| Used by another script | That script handles it. An RSG `CreateUseableItem` or a VORP `registerUsableItem` always wins over MULTIconsumables |
| Something new | A small script: `MC.RegisterUsableItem('pocket_watch', function(src, item) ... end)` (see `MULTIcore-API.md` and `MULTIstarter.zip`) |

### Sell it in a store

Open **`MULTIstores/config/products.lua`** and add the item to a store type's list:

```lua
{ name = 'pocket_watch', price = 4.50, amount = 5, buyPrice = 1.50, category = 'valuables' },
```

| Field | What it means |
|---|---|
| `price` | What the player pays, dollars with cents. 1899 prices: bread $0.10, coffee $0.25, a lantern $1.50 |
| `amount` | Stock. Leave it out for stock that never runs out |
| `buyPrice` | What the store pays the player for one. Leave it out if the store does not buy it. **Never more than half the lowest sale price**, or players can loop money (a warning is printed at start) |
| `restock`, `maxStock`, `minQuality`, `info` | Explained at the top of the file |

**New store spot:** add a line to `MULTIstores/config/stores.lua` with a `name`, a `type` (general, gunsmith, butcher, ...), `town`, `coords`, `npc` (x, y, z, heading) and the clerk `model`.

### Give an item (testing and staff)

```
/giveitem [player id] [item] [amount]
```

For example `/giveitem 1 bread 5` or `/giveitem 1 weapon_revolver_cattleman 1`. Admins only.

---

## 3. Jobs

### Add or change a job

Open **`MULTIcore/shared/jobs.lua`**:

```lua
doctor_rhodes = {
    name = 'doctor_rhodes',
    label = 'Rhodes Doctor',
    type = 'medic',               -- 'leo' (law), 'medic', 'doj' (court) or leave it out
    defaultDuty = false,          -- on duty right after login
    offDutyPay = false,           -- keep false: no pay for idling
    grades = {
        ['0'] = { name = 'Nurse',  payment = 0.30 },
        ['1'] = { name = 'Doctor', payment = 0.40 },
        ['2'] = { name = 'Head Doctor', payment = 0.50, isboss = true },
    },
},
```

- **`payment`** is dollars per paycheck. A paycheck comes every 10 minutes, so $0.30 is $1.80 an hour, an honest 1899 wage. Trade jobs (farmer, miner, hunter) are 0: they earn by selling what they make.
- **`isboss = true`** lets that grade hire, fire, promote and set pay in the boss menu.
- **Who pays wages:**
  - law (`leo`), medics (`medic`) and the court (`doj`) are paid by the server;
  - every other job is paid from its own business account in MULTIbank;
  - to make another job server-paid, add it to `MULTIConfig.ServerPaid.Jobs` in `MULTIcore/config_multi.lua`.
- **`type = 'leo'`** gives the job law powers in MULTIlaw (cuffs, search, jail, fines). Which powers each type has is in `MULTIlaw/config.lua`.
- **Never rename a job's key** once players hold it.

### Let anyone take it at the job centre

Add it to `Config.PublicJobs` in **`MULTIjobs/config.lua`**:

```lua
doctor_rhodes = { desc = 'desc_doctor_rhodes' },
```

Then add the line `['desc_doctor_rhodes'] = "Treat the sick and wounded of Rhodes."` to `MULTIjobs/locales/en.lua` (and the other languages if you use them). Jobs not listed there (law, doctors, judges) are only given by their boss or by an admin.

### Boss desks and duty points

These are in `MULTIjobs/config.lua`:
- **`Config.BossPoints`:** where a job's boss menu opens (`{ job = 'doctor_rhodes', coords = vector3(...) }`). Bosses can also use `/bossmenu`; see `Config.BossMenu.Anywhere`.
- **`Config.DutyPoints`:** where a job goes on and off duty. `/duty` works anywhere unless `Config.Duty.CommandAnywhere = false`.
- **`Config.JobCentres`:** the town hall clerks.

To get coordinates, stand on the spot and use the admin menu's copy-coords option (`/admin`).

### Commands

| Command | Who | What |
|---|---|---|
| `/setjob [id] [job] [grade]` | admin | Give a player a job |
| `/job` | everyone | Show your job |
| `/jobs` | everyone | My jobs: switch the active job, go on or off duty, quit |
| `/bossmenu` | bosses | Staff, pay and the business account |
| `/duty` | job holders | On / off duty |

A character can hold several jobs at once (`Config.MultiJob` in MULTIjobs).

---

## 4. Gangs

Open **`MULTIcore/shared/gangs.lua`**. Keep `none`. The other gangs are made-up examples: rename, remove or add your own.

```lua
lemoyne_riders = {
    label = 'Lemoyne Riders',
    grades = {
        ['0'] = { name = 'Recruit' },
        ['1'] = { name = 'Rider' },
        ['2'] = { name = 'Boss', isboss = true },
    },
},
```

| Command | Who | What |
|---|---|---|
| `/setgang [id] [gang] [grade]` | admin | Put a player in a gang (`none` takes them out) |
| `/gang` | everyone | Show your gang |
| `/gangmenu` | members | Members see the gang; the boss runs it (invite, ranks, gang money) |

Gang money lives in the MULTIbank account `gang_<name>`.

---

## 5. Staff and permissions

In `server.cfg`, one line per admin (their licence is on their txAdmin player page):

```
add_principal identifier.license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx group.admin
```

Moderators: use `group.mod` instead. The `add_ace` lines in `server.cfg.example` give each group its rights.

| Command | What |
|---|---|
| `/admin` | The admin menu: players, teleport, noclip, revive, kick, ban, coords, ... |
| `/giveitem [id] [item] [amount]` | Give an item |
| `/givemoney [id] [cash/bank/gold] [amount]` | Give money |
| `/setmoney [id] [cash/bank/gold] [amount]` | Set money |
| `/setjob`, `/setgang` | Jobs and gangs |
| `/tp [x] [y] [z]` or `/tp [id]`, `/tpm` | Teleport (`/tpm` goes to your map marker) |
| `/weather [type]`, `/weather auto` | Hold a weather, or let it change by itself again |
| `/time [hour] [minute]`, `/freezetime` | Set the time, stop or restart the clock |

---

## 6. Other settings

| What | Where |
|---|---|
| Language for every MULTI script | `MULTIConfig.Language = 'en'` in `MULTIcore/config_multi.lua` (32 languages, codes listed there) |
| Starting money | `RSGConfig.Money.MoneyTypes` in `MULTIcore/config.lua` |
| Paycheck interval | `RSGConfig.Money.PayCheckTimeOut` in `MULTIcore/config.lua` |
| Day length, night length, real-time clock, how often the weather changes | `MULTIweather/config.lua` |
| Voice ranges (whisper, talk, shout) and the range key | `MULTIvoice/config.lua` |
| Notifications: where each kind sits, size, look, sounds, colours (see below) | `MULTIcore/config_notify.lua` |
| Discord logs, whitelist, connect queue | `MULTIserver/config.lua` and its README |
| Doors and locks | `MULTIdoors/config/locks.lua`, or in game with `/doors` |
| Crafting recipes | `MULTIcrafting/config.lua` |
| Horses and stables | `MULTIhorses/config.lua` |
| Wagons | `MULTIwagons/config.lua` |
| Text of any script | That script's `locales/` folder |
| Colours and sizes of any screen | That script's `html/custom.css` |

Every script has a README with all of its settings and commands.

### Notifications

All notifications are drawn by MULTIcore, whether they come from MULTI, RSG or VORP scripts. There are four kinds:
- **toast:** messages stacked in a corner;
- **tip:** a hint line;
- **objective;**
- **banner:** a big centred title.

In `MULTIcore/config_notify.lua`:
- **Where and how big**, per kind in `NotifyConfig.Styles`:
  - `position`: `top-left`, `top-center`, `top-right`, `middle-left`, `center`, `middle-right`, `bottom-left`, `bottom-center` or `bottom-right`;
  - `offsetX`, `offsetY` (px in from that edge);
  - `width` (px);
  - `scale` (1 = normal, 1.3 = bigger);
  - `align`, `duration`, `max`.
- **The look** in `NotifyConfig.Look`. Pick a `Preset`:
  - `game`: the game's own look, the default;
  - `box`: solid boxes with a thin border;
  - `card`: rounded boxes with the type's colour along the top;
  - `minimal`: words only.

  Then change single things on top of it: background colour, faded or solid edges, border, rounded corners, padding, the coloured edge, text and title colours, fonts, text sizes, icons, spacing and the animation.
- **Colours, signs and sounds** of each type (info, success, error, money ...) in `NotifyConfig.Types`.
- Anything else: `MULTIcore/html/notify/custom.css`.

**In game:** type `/notifylayout`. It shows one of each kind:
- drag them where you want;
- use the mouse wheel to make them bigger or smaller, and Shift + wheel to make them wider or narrower;
- press **Save**.

How it is saved:
- It is saved on that player's own PC, so every player can have their own layout. `/notifyreset` goes back to the server's.
- Saving also prints the positions to the F8 console in the `NotifyConfig.Styles` form. To set the default for everyone, lay it out yourself, save, and copy those values into `config_notify.lua`.
- `NotifyConfig.Editor.Players = false` keeps the editor for admins only.

---

## 7. Adding RSG, VORP and RedEM:RP scripts

Put them in `resources/` and `ensure` them **below** the MULTI scripts.

Do not start the real versions of these: MULTIcore and its scripts already answer as them (or do the same job). The `vorp_inventory`, `rsg-inventory`, `redemrp_inventory` and `RINGOinventory` folders in `resources/[multicore]` are MULTIcore's own stand-ins: keep them started.

| Framework | Do not start |
|---|---|
| RSG v2 | `rsg-core`, `rsg-inventory`, `rsg-target`, `rsg-hud`, `rsg-medic`, `rsg-bossmenu` |
| VORP | `vorp_core`, `vorp_inventory`, `vorp_menu`, `vorp_inputs`, `vorp_progressbar`, `vorp_metabolism` |
| RedEM:RP | `redem_roleplay`, `redemrp_inventory`, `redemrp_status`, `redemrp_respawn`, `redemrp_bossmenu`, `redemrp_menu_base`, `redemrp_progressbars`, `redemrp_charselect`, `redemrp_creator` |
| Other | `ox_target`, `chat`, `pma-voice`, `weathersync`, a second IPL or interiors script (`redm-ipls` is already included) |

If a script needs items:
- **RSG scripts** usually ship an items block: paste it into `MULTIcore/shared/items.lua`.
- **VORP scripts** usually ship SQL for the `items` table: run it as it is. MULTIcore reads that table too.
- **RedEM:RP scripts** usually ship lines for `Config.Items` in `redemrp_inventory/config.lua`. Add each one to `MULTIcore/shared/items.lua` instead, in that file's shape:
  - `weight` there is kilograms; here it is grams (0.25 becomes 250);
  - `canBeUsed = true` becomes `useable = true`;
  - `imgsrc = 'items/bread.png'` becomes `image = 'bread.png'`.

  A RedEM:RP weapon such as `WEAPON_REVOLVER_CATTLEMAN` is already there in lower case: names are matched without case.

**RedEM:RP scripts that read or write the `characters` table with their own SQL will not work.** That table belongs to VORP's layout on MULTIcore. Scripts that use the RedEM:RP functions (`RedEM.GetPlayer`, the inventory API, the events) work.

Pictures go in `MULTIimages/images/`.
