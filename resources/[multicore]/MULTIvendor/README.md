# MULTIvendor

Vendor NPCs who buy goods from your satchel, for MULTIcore.
Made by Mack for MULTIcore. MULTIcore was founded and created by RINGO (RINGOscripting).

- **Vendors** in their own spots (produce, herbs, jewelry, pawn broker, guns, Guarma, mining, fossils, witch doctor),
  each with a clerk, a map blip and a hold-key prompt (`Config.Keybind`, default **J**). Clerks appear when you come
  near (`Config.DistanceSpawn`) and fade in and out (`Config.FadeIn`).
- **The sell menu** (MULTIcore's black and white look): the items this vendor buys that you carry, with picture,
  price each and how many you have; on the right Sell All, quick amounts (1 / 5 / 10 / 25 / 50) and your own amount.
- **Sell Everything:** one sale of every item the vendor buys, after a confirm.
- **Category tabs** when you fill `Config.SellMenu.Categories`.
- Paid in cash; MULTIcore notifications confirm each sale.
- 10 languages, nothing drawn in the world (no markers, no floating text, no dots).

Every sale is checked on the server: the vendor must buy that item, you must stand at the vendor
(`Config.SellDistance`), you must carry the amount, and you are paid only for what was taken from the satchel.

## Setup
1. Put `MULTIvendor` in your resources.
2. `server.cfg`, after MULTIcore and MULTIinventory: `ensure MULTIvendor`.
3. The items in each vendor's `ItemPrices` must exist in your item list; items that do not exist are simply never shown.
   Pictures come from MULTIimages (the folders MULTIinventory uses).

## Config
`config.lua`:

| Setting | Default | What it does |
|---|---|---|
| `Locale` | `'en'` | de, en, es, fr, it, nl, pl, pt-br, ru, tr |
| `Keybind` | `'J'` | key of the vendor prompt |
| `DistanceSpawn` | `20.0` | metres at which the clerk appears and goes |
| `SellDistance` | `10.0` | metres from the vendor or its prompt spot within which a sale is accepted |
| `FadeIn` | `true` | clerks fade in and out |
| `DefaultPed` | `U_M_M_ValGunSmith_01` | clerk model and scenario (each vendor may set its own `ped`) |
| `Blip` | on | blip sprite and size |
| `Notification.DefaultDuration` | `4000` | how long sale messages stay (ms) |
| `SellMenu.Currency` | `'$'` | money sign in the menu |
| `SellMenu.QuickSellAmounts` | `{1, 5, 10, 25, 50}` | quick amounts (only those below what you carry are shown) |
| `SellMenu.Categories` | `{}` | `item = 'Category'` for the menu tabs; empty = no tabs |
| `SellMenu.ShowSellEverything` | `true` | show the Sell Everything button |

### Vendors
Each entry in `Config.Vendors`:

```lua
{
    name         = 'Produce Buyer',                    -- prompt, blip and menu title
    coords       = vector3(-281.31, 654.52, 113.56),   -- where the clerk stands
    heading      = 131.26,                             -- clerk heading
    promptCoords = vector3(-282.89, 653.02, 113.56),   -- where the player stands
    blipName     = 'Produce Buyer',                    -- blip label
    -- ped = { model = 'OTHER_MODEL', scenario = 'OTHER_SCENARIO' },
    ItemPrices = {
        ["corn"]  = 2,   -- item name = price for one
        ["wheat"] = 2,
    },
},
```

A vendor buys only the items in its `ItemPrices`. Copy a block to add a vendor.

Text: `locales/<lang>.lua`. Change the look in `html/custom.css`.

## Server events
| Event | Arguments | What it does |
|---|---|---|
| `MULTIvendor:server:sellItem` | `vendorIndex, itemName, amount` | sell an amount of one item |
| `MULTIvendor:server:sellAll` | `vendorIndex` | sell every item that vendor buys |

## With MULTIstores
Both can run together: the vendors stand in other spots than the stores, and names, prompts and events are separate.
Prices follow the MULTIstores rule: a vendor never pays more than half of what a store sells the item for, so nothing can be bought and sold again for profit. Keep to that when you change prices.
