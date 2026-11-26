# redemrp_inventory (MULTIcore stand-in)

Scripts written for RedEM:RP look for a resource called `redemrp_inventory`: they call its exports, check that it is started, list it as a dependency and show item pictures from `nui://redemrp_inventory/html/items/<item>.png`. This small resource carries that name on MULTIcore.

- It is **not** an inventory: its one small script only copies pictures. MULTIinventory answers every `redemrp_inventory` export and event.
- It serves MULTIcore's item pictures at `nui://redemrp_inventory/html/items/`. A `nui://` address only reaches a resource with exactly that name, so MULTIinventory alone cannot serve them there.
- The pictures come from `MULTIimages/images`. This resource copies them into `html/items/` each time it starts (new, changed and removed pictures). After adding pictures, restart the server (or `restart redemrp_inventory`).
- Add or change pictures in `MULTIimages/images` only. Anything put in `html/items/` by hand is replaced or removed at the next start.

Start it right after MULTIinventory:

```
ensure MULTIimages
ensure MULTIinventory
ensure redemrp_inventory
```

Do not run it next to the real redemrp_inventory: two resources with the same name cannot run together.

GPL-3.0-or-later, part of MULTIcore by RINGO (RINGOscripting).
