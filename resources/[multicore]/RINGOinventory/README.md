# RINGOinventory (MULTIcore stand-in)

Scripts written for RINGOinventory look for a resource called `RINGOinventory`: they call its exports, check that it is started, list it as a dependency and show item pictures from `nui://RINGOinventory/html/img/items/<item>.png`. This small resource carries that name on MULTIcore.

- It is **not** an inventory: its one small script only copies pictures. MULTIinventory answers every `RINGOinventory` export and event.
- It serves MULTIcore's item pictures at `nui://RINGOinventory/html/img/items/`. A `nui://` address only reaches a resource with exactly that name, so MULTIinventory alone cannot serve them there.
- The pictures come from `MULTIimages/images`. This resource copies them into `html/img/items/` each time it starts (new, changed and removed pictures). After adding pictures, restart the server (or `restart RINGOinventory`).
- Add or change pictures in `MULTIimages/images` only. Anything put in `html/img/items/` by hand is replaced or removed at the next start.

Start it right after MULTIinventory:

```
ensure MULTIimages
ensure MULTIinventory
ensure RINGOinventory
```

Do not run it next to the real RINGOinventory: two resources with the same name cannot run together.

GPL-3.0-or-later, part of MULTIcore by RINGO (RINGOscripting).
